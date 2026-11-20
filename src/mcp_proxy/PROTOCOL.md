# Forge MCP airlock: wire protocol

Status: NATIVE CHECK and FINITE TEST. Nothing in this document or in `src/mcp_proxy/` is proved.
Code: `main.rs` (command line), `proxy.rs` (framing, routing, upstream process), `jsonw.rs` (JSON output).
The ledger, the policy and the evidence formats are documented at the top of `ledger.rs`, `policy.rs` and
`evidence.rs`.

## 1. Place in the pipe

    MCP client  --stdin-->  mcp-proxy  --child stdin-->   upstream MCP server (a real child process)
    MCP client  <--stdout-- mcp-proxy  <--child stdout--  upstream MCP server
                                       (child stderr is inherited)

The proxy starts the upstream server as a child process with piped stdin and stdout. The client sees the
proxy as its MCP server. The upstream server sees the proxy as its MCP client.

    mcp-proxy mcp --policy P.json --agent-id ID --store DIR --key KEYFILE [--facts F.json]
              [--session k=v]... [--sign-mode sync|async] [--test-clock N] -- <server-cmd> [args...]
    mcp-proxy verify-evidence <evidence.wal> --allowed-signers FILE [--identity NAME]
    mcp-proxy state DIR

Exit codes: `2` usage error. `1` start-up fault (policy, ledger, evidence key or log, spawn). Otherwise `mcp`
exits with the exit code of the upstream server (`128 + signal` if a signal ended it). If `evidence.finish()`
fails at the end, the exit code is `1` when the upstream code was `0`, else the upstream code.
`state DIR` prints `epoch=<n> state=<32 hex>`. It is a read-only replay of `DIR/ledger.wal` with no lock, so it
works while a proxy runs on the same store.

## 2. Framing

- MCP stdio transport: one JSON-RPC 2.0 message per line, UTF-8, the line ends with `\n`. The proxy does not
  remove a `\r`; the strict JSON parser reads it as white space.
- A line that has only spaces, tabs or `\r` is ignored (not forwarded, no answer, no receipt).
- A last line with no `\n` at end of input is handled like a line.
- Client line cap: 65,536 bytes, `\n` excluded. Upstream line cap: 1,048,576 bytes, `\n` excluded.
- Memory: each reader has one fixed 64 KiB read buffer and one line buffer that is allocated once at its cap and
  never grows. A longer line is discarded chunk by chunk until its `\n`; its bytes are never kept. The upstream
  reader thread has a 256 KiB stack.
  Measured (macOS, M1, finite test): a 10 GiB client line with no newline, peak RSS of the proxy process
  2,336 KiB (ps samples every 20 ms). See the report of the run for the exact numbers.
- The client stdout has one writer lock. Each message is one `write` of the line, one `\n`, one flush, under
  that lock. Lines of the two threads never interleave.

## 3. Client to upstream: every case

The proxy parses every client line with the strict parser (`src/airlock/json.rs`: duplicate keys, lone
surrogates, raw control bytes, trailing bytes and nesting deeper than 64 are refused; keys and strings are
compared after unescaping, so `"tools\/call"` is `tools/call`). A line that is forwarded is forwarded as its
ORIGINAL bytes plus `\n`. The proxy never re-serializes a forwarded message.

| # | Input | Action | Receipt |
| --- | --- | --- | --- |
| C1 | line over 65,536 bytes | `-32700` `Parse error`, `id: null`, detail `LINE_TOO_LONG`; 0 bytes upstream | `BlockedMalformed` |
| C2 | not UTF-8 / not strict JSON | `-32700`, `id: null`, detail `NOT_UTF8` or the parser code; 0 bytes upstream | `BlockedMalformed` |
| C3 | JSON array (batch) | `-32600` `Invalid Request`, `id: null`, `BATCH_NOT_SUPPORTED`; 0 bytes upstream | `BlockedMalformed` |
| C4 | other non-object | `-32600`, `id: null`, `NOT_AN_OBJECT` | `BlockedMalformed` |
| C5 | object with no `method` (a client response to a server request) | forward unchanged | none |
| C6 | `method` not a string | `-32600`, `id: null`, `METHOD_NOT_A_STRING` | `BlockedMalformed` |
| C7 | `id` present but not a string and not a canonical integer (see 3.1) | `-32600`, `id: null`, `BAD_ID` | `BlockedMalformed` |
| C8 | `method` = `forge-airlock/state` with an id | answered by the proxy (section 6); not forwarded | none |
| C9 | notification (no `id`), method != `tools/call` | forward unchanged | none |
| C10 | `tools/call` with no `id` | `-32600`, `id: null`, `TOOLS_CALL_WITHOUT_ID`; not forwarded | `BlockedMalformed` |
| C11 | request whose id is in flight (3.1), or 4,096 requests in flight | `-32001`, verdict `BLOCKED_MALFORMED`, detail `ID_IN_FLIGHT` / `TOO_MANY_IN_FLIGHT` | `BlockedMalformed` |
| C12 | request after the upstream output closed | `-32001`, verdict `UPSTREAM_GONE`; not forwarded | none |
| C13 | request, method != `tools/call` | forward unchanged; track the id until the upstream response | none |
| C14 | `tools/call`: `params` not an object, `name` not a string, `arguments` not an object | `-32001`, `BLOCKED_MALFORMED` | `BlockedMalformed` |
| C15 | `tools/call`, tool not in the policy | `-32001`, `BLOCKED_MALFORMED`, `TOOL_NOT_IN_POLICY` (default deny) | `BlockedMalformed` |
| C16 | `tools/call`, kind `passthrough` | forward unchanged | none |
| C17 | `tools/call`, kind `sensitive_read` | remember the id, then forward unchanged; result filter in section 4 | at the response |
| C18 | `tools/call`, kind `mutating` | section 3.2 | section 3.2 |

A missing `arguments` counts as `{}`. Every receipt of a refusal records `pre_hash == post_hash ==` the current
head and `epoch =` the current head epoch. The receipt `tool` field holds the tool name, the method name (C11),
or `-` when no name is known.

### 3.1 Request ids

- MCP request ids are strings or integers. The proxy accepts a string, or an integer in the form
  `0 | -?[1-9][0-9]{0,14}` (at most 15 digits). Other numbers (`1.0`, `1e2`, `-0`, 16 digits) are refused (C7),
  because a server library can echo them in another form and the proxy could then not match the response.
- An answer that the proxy creates echoes the id: a number with its exact source text, a string with the same
  value (re-escaped by `jsonw.rs`).
- Ids are matched by a key: the string value, or the integer text. A string `"5"` and a number `5` have the same
  key ON PURPOSE. A second request with the key of a request in flight is refused (C11). So an upstream server
  that changes the type of an id cannot swap two responses.
- An upstream response id is matched by its exact integer value: `5`, `5.0`, `5e0`, `500e-2` all match `5`.

### 3.2 Mutating calls: exact order

The client puts two fields in `params._meta`:
`"forge-airlock/request_id"` (string, 1 to 128 bytes of `[A-Za-z0-9._:-]`) and
`"forge-airlock/pre_state_hash"` (32 lowercase hex digits). Missing or bad: `-32001`, `BLOCKED_MALFORMED`,
receipt `BlockedMalformed`, 0 bytes upstream.

1. `policy.check_mutation(tool, arguments)`. Deny: `BLOCKED_SUBCAP` (fact-bound sub-cap) or `BLOCKED_POLICY`
   (rule), receipt of the same verdict, 0 bytes upstream. Detail: `<CODE>: <text of policy.rs>`.
2. If the upstream output is closed: `UPSTREAM_GONE`, no receipt, no epoch used, 0 bytes upstream.
3. `ledger.commit(request_id, tool, args_canon, pre)`. `args_canon` = the raw bytes of the request line (no
   canonical JSON form is claimed). The ledger checks the duplicate id BEFORE the CAS.
   - `Duplicate`: `BLOCKED_DUPLICATE`, receipt `BlockedDuplicate`, 0 bytes upstream.
   - `Mismatch`: `BLOCKED_CAS`, receipt `BlockedCas`, 0 bytes upstream.
   - `Err` (I/O fault): `LEDGER_FAULT`, NO receipt, 0 bytes upstream.
   - `Committed`: the record is in `ledger.wal` and synced to disk (`ledger.rs` states the sync call).
4. `evidence.append(epoch, tool, pre, post, Committed)`. `Err`: `EVIDENCE_FAULT`; the epoch is consumed;
   0 bytes upstream.
5. Only now: forward the ORIGINAL line bytes. If the write fails (the upstream is gone):
   `COMMITTED_NOT_FORWARDED` (the epoch is consumed, the receipt says `Committed`).

Steps 3 and 4 run under one lock, so receipts follow the epoch order. The upstream success response of a
committed call passes to the client unchanged. The client learns the new head from `forge-airlock/state`, from
`mcp-proxy state DIR`, or from `data.state` of a refusal.

## 4. Upstream to client: every case

| # | Upstream line | Action |
| --- | --- | --- |
| U1 | has a `method` (server request or notification) | pass unchanged |
| U2 | response, id matches a pending sensitive read, `result` present and no `error`, `policy.check_read_result` = Ok, receipt `ReadAllowed` written | pass the ORIGINAL bytes |
| U3 | response to a pending sensitive read: filter deny, an `error` member, no `result` | 0 upstream bytes to the client; the dropped-read answer (section 5) with the deny code; receipt `ReadDropped` |
| U4 | response to a pending sensitive read, filter Ok, but the `ReadAllowed` receipt fails | dropped-read answer, reason `EVIDENCE_FAULT` |
| U5 | line over 1 MiB, not UTF-8, not strict JSON, not an object | DISCARDED (0 bytes to the client). Every pending sensitive read gets the dropped-read answer (the discarded line may have been its response) and receipt `ReadDropped`; its id is tombstoned |
| U6 | response with a missing, `null` or non-integer id while a sensitive read is pending | as U5 |
| U7 | response with a missing or `null` id, nothing pending | pass unchanged |
| U8 | response whose id is tombstoned | discarded (a late answer to a read that was already dropped) |
| U9 | any other response | pass unchanged; the id leaves the in-flight set |
| U10 | end of the upstream output | every pending sensitive read: dropped-read answer, reason `UPSTREAM_EOF`, receipt `ReadDropped`. Every other request in flight: `-32001` `UPSTREAM_GONE`. Later requests: C12 |

Departure from the base contract: U5 discards an unparseable upstream line even when no sensitive read is
pending (fail closed; a JSON-RPC stream has no valid non-JSON line).

## 5. Shapes

Refusal (every `-32001`; the framing errors C1 to C10 use the same `data` with code `-32700` or `-32600` and
`"id": null`):

    {"jsonrpc":"2.0","id":<id>,"error":{"code":-32001,"message":"Airlock Invariant Breach",
     "data":{"verdict":"<WORD>","detail":"<text>","epoch":<n>,"state":"<32 hex>"}}}

`<WORD>` with a receipt: `BLOCKED_CAS`, `BLOCKED_DUPLICATE`, `BLOCKED_POLICY`, `BLOCKED_SUBCAP`,
`BLOCKED_MALFORMED`. Without a receipt: `UPSTREAM_GONE`, `LEDGER_FAULT`. After a committed epoch:
`EVIDENCE_FAULT`, `COMMITTED_NOT_FORWARDED`. `epoch` and `state` are the head after the event.

Dropped sensitive read (a valid MCP `CallToolResult` with an empty set):

    {"jsonrpc":"2.0","id":<id>,"result":{"content":[],"isError":true,
     "_meta":{"forge-airlock/verdict":"READ_DROPPED","forge-airlock/reason":"<CODE>"}}}

`<CODE>` is a fixed word (`SCOPE`, `UNLABELLED`, `SHAPE`, `NO_RESULT`, `UPSTREAM_LINE_TOO_LONG`,
`UPSTREAM_LINE_NOT_A_JSON_OBJECT`, `UPSTREAM_RESPONSE_WITHOUT_USABLE_ID`, `UPSTREAM_EOF`, `EVIDENCE_FAULT`, ...).
No byte of the upstream response is copied into it.

## 6. Extension method `forge-airlock/state`

Not part of MCP. The proxy answers it and never forwards it:

    -> {"jsonrpc":"2.0","id":7,"method":"forge-airlock/state"}
    <- {"jsonrpc":"2.0","id":7,"result":{"epoch":<n>,"state":"<32 hex>"}}

As a notification (no id) it is ignored. Genesis: epoch 0, the genesis hash of `ledger.rs`.

## 7. End of input and upstream death

- End of client input: close the upstream stdin, read the upstream output to its end (U10 applies), wait for
  the upstream process, `evidence.finish()`, exit with the upstream exit code (section 1).
- Upstream death: the reader thread marks the upstream as gone (U10). Later requests are refused (C12) with no
  epoch used. Client notifications and responses are still written while the pipe accepts them.

## 8. Honest limits (what is NOT done and NOT proved)

- NOT proved. The routing, the ordering and the filters are a native check with finite tests.
- Crash window: a crash or power loss after the ledger sync (step 3) and before the forward (step 5) consumes
  the epoch and the call is NOT forwarded. A retry with the same request id is then `BLOCKED_DUPLICATE`. So a
  call is forwarded at most once, never twice; it can be forwarded zero times after a commit. The same holds for
  `EVIDENCE_FAULT` and `COMMITTED_NOT_FORWARDED`.
- A commit says the call was forwarded, not that the upstream executed it or succeeded. The proxy does not read
  the upstream result of a mutating call.
- One proxy per store: `ledger.wal` and `evidence.wal` take an exclusive advisory lock. A process that ignores
  the lock is not stopped.
- `args_canon` is the raw line bytes. Two lines with the same meaning but other bytes give other state hashes.
  No canonical JSON form is claimed.
- Parser difference: the proxy forwards the original bytes after its own strict parse. The upstream server
  parses them again with its own parser. The proxy assumes the upstream splits lines on `\n` only and reads
  JSON by RFC 8259. A server that also splits on U+2028, U+0085 or `\r` may see other messages.
- The scoped-read filter covers only the response to a `sensitive_read` call. Server notifications, server
  requests (for example `sampling/createMessage`), responses to `passthrough` tools and progress messages pass
  unchanged. A hostile upstream server can leak through them. The filter limits are listed in `policy.rs`.
- A request that the upstream never answers (for example after `notifications/cancelled`) keeps its in-flight
  slot until the upstream output closes. At 4,096 slots new requests are refused (C11).
- If the upstream server keeps its stdout open after its stdin closes, the proxy waits for it.
- `UPSTREAM_GONE` and `LEDGER_FAULT` write no receipt: no enforcement decision was made. Policy refusals after
  the upstream death are reported as `UPSTREAM_GONE`, not as `BLOCKED_*`.
- `/usr/bin/time -l` on macOS reports the largest RSS of the proxy AND the child processes it waited for
  (`ssh-keygen -Y sign` alone: 6,750,208 bytes measured). The RSS of the proxy process alone comes from `ps` samples.

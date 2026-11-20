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

Exit codes: `2` usage error. `1` start-up fault (policy, ledger, evidence key or log, spawn, or the start-up
reconciliation of section 7.1 refused). Otherwise `mcp` exits with the exit code of the upstream server
(`128 + signal` if a signal ended it), EXCEPT: the exit code is `1`, whatever the upstream code was, when a
receipt could not be written in this run (the sticky receipt fault, section 3.3), when `evidence.finish()` fails
at the end, or when the upstream reader thread panicked. A poisoned state lock (a thread panicked while it held
the airlock state) ends the process at once with exit code `1`.
`state DIR` prints `epoch=<n> state=<32 hex>`. It is a read-only replay of `DIR/ledger.wal` with no lock, so it
works while a proxy runs on the same store.

## 2. Framing

- MCP stdio transport: one JSON-RPC 2.0 message per line, UTF-8, the line ends with `\n`.
- Raw control bytes. A client line with any raw byte below 0x20 or the byte 0x7f is REFUSED before anything
  is forwarded (C2a). This includes `\t` and `\r` between tokens, and a `\r` directly before the `\n`: a
  client that ends its lines with `\r\n` is refused on every line. Reason: a reader that also splits lines on
  `\r` (for example Python text mode with universal newlines) could see other messages than this proxy
  (finding R1). An upstream line with a raw control byte is discarded (U5).
- A line that is empty or has only spaces (0x20) is ignored (not forwarded, no answer, no receipt).
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
| C2a | a raw byte below 0x20 or 0x7f anywhere in the line (also `\r` before the `\n`, also `\t`) | `-32700`, `id: null`, `CONTROL_BYTE`; 0 bytes upstream | `BlockedMalformed` |
| C3 | JSON array (batch) | `-32600` `Invalid Request`, `id: null`, `BATCH_NOT_SUPPORTED`; 0 bytes upstream | `BlockedMalformed` |
| C4 | other non-object | `-32600`, `id: null`, `NOT_AN_OBJECT` | `BlockedMalformed` |
| C4a | a number token longer than 64 bytes anywhere in the message | `-32600`, `id: null`, `NUMBER_TOO_LONG`; 0 bytes upstream | `BlockedMalformed` |
| C4b | `jsonrpc` member missing or not exactly the string `"2.0"` (every client message: request, notification, response) | `-32600`, the id echoed when it is usable (3.1), else `null`; `BAD_JSONRPC_VERSION`; 0 bytes upstream | `BlockedMalformed` |
| C5 | object with no `method` (a client response to a server request) | forward unchanged | none |
| C6 | `method` not a string | `-32600`, `id: null`, `METHOD_NOT_A_STRING` | `BlockedMalformed` |
| C7 | `id` present but not a string and not a canonical integer (see 3.1) | `-32600`, `id: null`, `BAD_ID` | `BlockedMalformed` |
| C8 | `method` = `forge-airlock/state` with an id | answered by the proxy (section 6); not forwarded | none |
| C9 | notification (no `id`), method != `tools/call` | forward unchanged | none |
| C10 | `tools/call` with no `id` | `-32600`, `id: null`, `TOOLS_CALL_WITHOUT_ID`; not forwarded | `BlockedMalformed` |
| C11 | request whose id is in flight (3.1), or 4,096 requests in flight | `-32001`, verdict `BLOCKED_MALFORMED`, detail `ID_IN_FLIGHT` / `TOO_MANY_IN_FLIGHT` | `BlockedMalformed` |
| C11a | `tools/call` (any kind) after the sticky receipt fault (3.3) | `-32001`, verdict `EVIDENCE_FAULT`; 0 bytes upstream | none |
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
   (rule, scope bind, closed arguments), receipt of the same verdict, 0 bytes upstream. The client gets ONLY the
   fixed code of `policy.rs` as `detail` (for example `SUBCAP`, `SCOPE_BIND`, `RULE`). The longer text of
   `policy.rs` names facts and values; it goes to the proxy's stderr only (finding B3).
2. If the upstream output is closed: `UPSTREAM_GONE`, no receipt, no epoch used, 0 bytes upstream.
3. `ledger.commit(request_id, tool, args_canon, pre)`. `args_canon` = the raw bytes of the request line (no
   canonical JSON form is claimed). The ledger checks the duplicate id BEFORE the CAS.
   - `Duplicate`: `BLOCKED_DUPLICATE`, receipt `BlockedDuplicate`, 0 bytes upstream.
   - `Mismatch`: `BLOCKED_CAS`, receipt `BlockedCas`, 0 bytes upstream.
   - `Err` (I/O fault): `LEDGER_FAULT`, NO receipt, 0 bytes upstream.
   - `Committed`: the record is in `ledger.wal` and synced to disk (`ledger.rs` states the sync call).
4. `evidence.append(epoch, tool, pre, post, Committed)`. It returns only after the record AND its signature
   are synced to disk, in both sign modes (`evidence.rs`). `Err`: `EVIDENCE_FAULT`; the epoch is consumed;
   0 bytes upstream; the sticky receipt fault is set (3.3); the next start writes this receipt from
   `ledger.wal` (7.1).
5. If the tool has a result filter (`policy.filters_result`: a `mutating` tool with a `scope` list), the call is
   remembered for the filter (section 4). Only now: forward the ORIGINAL line bytes. If the write fails (the
   upstream is gone): `COMMITTED_NOT_FORWARDED` (the epoch is consumed, the receipt says `Committed`).

Steps 3 and 4 run under one lock, so receipts follow the epoch order. The sticky fault is checked under the
same lock before step 3, so no epoch is consumed after a receipt fault. The upstream response of a committed
call without a result filter passes to the client unchanged (U9). The client learns the new head from `forge-airlock/state`, from
`mcp-proxy state DIR`, or from `data.state` of a refusal.

### 3.3 Sticky receipt fault

The first receipt that cannot be written (any verdict: a sign error, a write or sync error, a closed log) sets a
fault that stays for the rest of the run (findings R4, B6). After it:
- no receipt is attempted (a later receipt could break the epoch order of `evidence.wal`);
- every `tools/call`, of any kind, is refused with `EVIDENCE_FAULT` and 0 bytes upstream (C11a); no epoch is
  consumed;
- other requests and notifications are still forwarded (they are not enforcement decisions);
- the refusal that met the fault says `receipt not written (EVIDENCE_FAULT)` in its detail; the error text goes
  to stderr;
- the process exits `1` at the end, whatever the upstream exit code is.

## 4. Upstream to client: every case

| # | Upstream line | Action |
| --- | --- | --- |
A "filtered call" is a forwarded `tools/call` whose tool has `policy.filters_result(tool)` = true: every
`sensitive_read` tool, and every `mutating` tool with a `scope` list. A "response" is a line with no `method`.

| # | Upstream line | Action |
| --- | --- | --- |
| U0 | both a `method` and a `result` or `error` member | DISCARDED (finding D1); a pending call stays pending (its real response is still filtered; U10 drops it if none comes) |
| U1 | has a `method`, no `result`/`error` (server request or notification) | pass unchanged (**NOT filtered**, section 8) |
| U2 | response to a pending filtered read, exactly the members `jsonrpc` (= `"2.0"`), `id`, `result`, `policy.check_read_result` = Ok, receipt `ReadAllowed` written | pass the ORIGINAL bytes |
| U2m | response to a pending filtered MUTATING call, same shape and filter Ok | pass the ORIGINAL bytes (its `Committed` receipt exists; no second receipt) |
| U3 | response to a pending filtered call: any other member set (an `error`, no `result`, an extra member such as `"leak"`), or filter deny | 0 upstream bytes to the client; read: the dropped-read answer (section 5), reason `NO_RESULT` (no `result`), `RESPONSE_SHAPE` (other members) or the deny code; mutating call: the dropped-result answer (section 5), verdict `RESULT_DROPPED`; receipt `ReadDropped` |
| U4 | response to a pending filtered read, filter Ok, but the `ReadAllowed` receipt fails | dropped-read answer, reason `EVIDENCE_FAULT`; sticky fault (3.3) |
| U5 | line over 1 MiB, with a raw control byte (below 0x20 or 0x7f, for example `\r`), not UTF-8, not strict JSON, not an object | DISCARDED (0 bytes to the client). Every pending filtered call gets its dropped answer (the discarded line may have been its response) and receipt `ReadDropped`; its id is tombstoned. Every other request in flight is marked (U10) |
| U6 | response with a missing, `null` or non-integer id while a filtered call is pending | as U5 |
| U7 | response with a missing or `null` id, nothing pending | DISCARDED (stderr line) |
| U8 | response whose id is tombstoned | DISCARDED (a late answer to a call that was already dropped) |
| U9 | response whose id is in flight, not a filtered call | pass unchanged; the id leaves the in-flight set |
| U9a | response whose id is NOT in flight (never forwarded, or already answered: a second answer) | DISCARDED (findings T1 and R1) |
| U10 | end of the upstream output | every pending filtered call: dropped answer, reason `UPSTREAM_EOF`, receipt `ReadDropped`. Every other request in flight: `-32001`, verdict `UPSTREAM_LINE_DISCARDED` when an upstream line was discarded under U5 or U6 while it was in flight (that line may have been its response; finding R7), else `UPSTREAM_GONE`. Later requests: C12 |

Departure from the base contract: U5 discards an unparseable upstream line even when no filtered call is
pending (fail closed; a JSON-RPC stream has no valid non-JSON line).

## 5. Shapes

Refusal (every `-32001`; the framing errors C1 to C10 use the same `data` with code `-32700` or `-32600` and
`"id": null`):

    {"jsonrpc":"2.0","id":<id>,"error":{"code":-32001,"message":"Airlock Invariant Breach",
     "data":{"verdict":"<WORD>","detail":"<text>","epoch":<n>,"state":"<32 hex>"}}}

`<WORD>` with a receipt: `BLOCKED_CAS`, `BLOCKED_DUPLICATE`, `BLOCKED_POLICY`, `BLOCKED_SUBCAP`,
`BLOCKED_MALFORMED`. Without a receipt: `UPSTREAM_GONE`, `UPSTREAM_LINE_DISCARDED`, `LEDGER_FAULT`,
`EVIDENCE_FAULT` (C11a). After a committed epoch: `EVIDENCE_FAULT`, `COMMITTED_NOT_FORWARDED`. `epoch` and
`state` are the head after the event. For `BLOCKED_POLICY` and `BLOCKED_SUBCAP`, `detail` is only the fixed
code of `policy.rs`.

Dropped sensitive read (a valid MCP `CallToolResult` with an empty set):

    {"jsonrpc":"2.0","id":<id>,"result":{"content":[],"isError":true,
     "_meta":{"forge-airlock/verdict":"READ_DROPPED","forge-airlock/reason":"<CODE>"}}}

`<CODE>` is a fixed word (`SCOPE`, `UNLABELLED`, `SHAPE`, `NO_RESULT`, `RESPONSE_SHAPE`,
`UPSTREAM_LINE_TOO_LONG`, `UPSTREAM_CONTROL_BYTE`, `UPSTREAM_LINE_NOT_A_JSON_OBJECT`,
`UPSTREAM_RESPONSE_WITHOUT_USABLE_ID`, `UPSTREAM_EOF`, `EVIDENCE_FAULT`, or a
code of `policy.rs`). No byte of the upstream response is copied into it.

Dropped result of a filtered MUTATING call (the call was committed at `<epoch>` and forwarded, so its effect may
have happened upstream; the answer says so):

    {"jsonrpc":"2.0","id":<id>,"result":{"content":[],"isError":true,
     "_meta":{"forge-airlock/verdict":"RESULT_DROPPED","forge-airlock/reason":"<CODE>","forge-airlock/epoch":<epoch>,
     "forge-airlock/effect":"the call was committed and forwarded; the upstream may have applied its effect; its result was withheld"}}}

## 6. Extension method `forge-airlock/state`

Not part of MCP. The proxy answers it and never forwards it:

    -> {"jsonrpc":"2.0","id":7,"method":"forge-airlock/state"}
    <- {"jsonrpc":"2.0","id":7,"result":{"epoch":<n>,"state":"<32 hex>"}}

As a notification (no id) it is ignored. Genesis: epoch 0, the genesis hash of `ledger.rs`.

## 7. Start, end of input and upstream death

### 7.1 Start-up reconciliation of `ledger.wal` and `evidence.wal`

After both files are open and checked, and before any client byte is read (finding R2). `L` = the ledger head
epoch; `E` = the epoch of the last `Committed` receipt in `evidence.wal` (0 when there is none; its post is then
the ledger genesis hash).
- `E > L`, or `E == L` with another state hash: start refused, exit 1 (the ledger was rolled back, removed or
  replaced).
- `L > E`: the documented crash window between the ledger sync and the receipt (3.2 step 4). For each ledger
  record after `E`, in order, one `Committed` receipt is appended from the ledger record (epoch, tool, pre,
  post; the timestamp is the recovery time, not the commit time), and one line per recovered receipt goes to
  stderr. The first recovered `pre` must equal the post of the last receipt, and each record must follow the one
  before; otherwise the start is refused.
- Limit: a coordinated cut of BOTH files at matching record boundaries (the last commits and their receipts
  removed together) gives two consistent, shorter files and is NOT detected here. Nothing outside the store
  anchors either chain.

### 7.2 End of input and upstream death

- End of client input: close the upstream stdin, read the upstream output to its end (U10 applies), wait for
  the upstream process, `evidence.finish()`, exit with the upstream exit code (section 1).
- Upstream death: the reader thread marks the upstream as gone (U10). Later requests are refused (C12) with no
  epoch used. Client notifications and responses are still written while the pipe accepts them.

## 8. Honest limits (what is NOT done and NOT proved)

- NOT proved. The routing, the ordering and the filters are a native check with finite tests.
- Crash window: a crash or power loss after the ledger sync (step 3) and before the forward (step 5) consumes
  the epoch and the call is NOT forwarded. A retry with the same request id is then `BLOCKED_DUPLICATE`. So a
  call is forwarded at most once, never twice, ONLY WHILE `ledger.wal` and `evidence.wal` are intact and
  consistent: it can be forwarded zero times after a commit. The same holds for `EVIDENCE_FAULT` and
  `COMMITTED_NOT_FORWARDED`. A ledger that was removed, rolled back or replaced is refused at start when
  `evidence.wal` still holds a later or different commit (7.1); a coordinated cut of both files is not detected.
  Neither hash chain has a key: anyone who can write the store folder can write a valid `ledger.wal` chain and
  a valid `evidence.wal` record chain. Only the signatures in `evidence.wal` need the key, and the
  allowed-signers file is the trust root of the verifier.
- A commit says the call was forwarded, not that the upstream executed it or succeeded. The proxy does not read
  the upstream result of a mutating call.
- One proxy per store: `ledger.wal` and `evidence.wal` take an exclusive advisory lock. A process that ignores
  the lock is not stopped.
- `args_canon` is the raw line bytes. Two lines with the same meaning but other bytes give other state hashes.
  No canonical JSON form is claimed.
- Parser difference: the proxy forwards the original bytes after its own strict parse. The upstream server
  parses them again with its own parser. Raw `\r` and every other raw control byte are refused (C2a), numbers
  are at most 64 bytes (C4a), and `jsonrpc` must be `"2.0"` (C4b). The proxy still assumes the upstream reads
  JSON by RFC 8259 and splits lines on `\n` and `\r` only. A server that also splits on the UTF-8 characters
  U+2028, U+2029 or U+0085 (they can stand raw inside a JSON string) may see other messages. Not checked.
- **Server notifications and server requests are NOT filtered.** A line with a `method` and no
  `result`/`error` (for example `notifications/progress`, `notifications/message`, `sampling/createMessage`)
  passes unchanged (U1). A hostile upstream server can send foreign-tenant data to the client through them.
  The result filter covers only the responses to filtered calls (`sensitive_read` tools and `mutating` tools
  with a `scope`); responses to `passthrough` tools and to mutating tools without a `scope` pass unchanged. The
  filter limits are listed in `policy.rs`.
- A filtered mutating call whose result is dropped has still been committed and forwarded: the upstream may have
  applied its effect. The dropped-result answer says so; it does not undo anything.
- A request that the upstream never answers (for example after `notifications/cancelled`) keeps its in-flight
  slot until the upstream output closes. At 4,096 slots new requests are refused (C11).
- If the upstream server keeps its stdout open after its stdin closes, the proxy waits for it.
- R6, a stalled upstream stalls the proxy (NOT repaired): the main thread writes to the upstream stdin with a
  blocking write. An upstream that keeps its pipes open and does not read its stdin stops the proxy: measured by
  REVIEW-A (`a7_stall.py`, macOS): after about 480 KB of client notifications the client thread blocked in the
  upstream write, and a later `forge-airlock/state` and a payout got no answer for 12.1 s (until the upstream
  exited). It fails closed (nothing passes), but the airlock is as slow as its upstream.
- R5, one signature per malformed line (NOT repaired): every refused line (C1 to C11) writes one signed receipt,
  and the signature (`ssh-keygen -Y sign`, about 17 ms each) runs while the airlock state lock is held, so the
  upstream reader waits too. Measured by REVIEW-A (`a6_receipt_flood.py 1000`): 1,000 lines `x\n` (2,000 bytes)
  gave 1,000 signed receipts, `evidence.wal` 505,030 bytes (about 252 times the input), and a
  `forge-airlock/state` probe queued behind them was answered after 17.09 s. A client can slow the proxy and
  grow `evidence.wal` this way.
- A request that the upstream answers with `"id": null` (for example a parse error of the upstream) keeps its
  in-flight slot until the upstream output closes; the `null` answer is discarded (U7).
- `UPSTREAM_GONE` and `LEDGER_FAULT` write no receipt: no enforcement decision was made. Policy refusals after
  the upstream death are reported as `UPSTREAM_GONE`, not as `BLOCKED_*`.
- `/usr/bin/time -l` on macOS reports the largest RSS of the proxy AND the child processes it waited for
  (`ssh-keygen -Y sign` alone: 6,750,208 bytes measured). The RSS of the proxy process alone comes from `ps` samples.

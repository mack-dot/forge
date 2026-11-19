# h-sink hardening notes (night shift 2026-11-19, Orchestrator B, task h-sink)

Base: the v6 sink (p-adopt2/adoption-v6.diff). Diff: `h-sink.diff` (sha256 in `h-sink.diff.sha256`). Nothing is applied
to the repository. Store format: `forge-sink-h1`. The final DDL is `DDL_STATEMENTS` in `ts/refund-finality/core/store.ts`
(the only source; the sink's schema check compares the file with what that text makes).

## 1. Schema (summary of the DDL; table names `state`, `settled`, `outbox` kept; `meta` changed to one row)
- `meta(id=1, format, charge_id, initial_state, initial_state_sha256, genesis)`. genesis = h_0 of the anchor design.
- `state(id=1, blob, seq INTEGER, refunded INTEGER)`; `refunded` = running sum of outbox amounts.
- `settled(seq PK, request_id UNIQUE, token, token_sha256, prev, self)`; `outbox(seq PK, request_id UNIQUE, intent, prev, self)`.
- Column CHECKs: every TEXT column `typeof = 'text'`, no U+0000 (`instr(CAST(x AS BLOB), x'00') = 0`), length bound;
  hashes 64 lower-case hex; INTEGER columns `typeof = 'integer'`; `request_id = json_extract(token|intent, ...)`.
- 18 statements in ONE transaction (C-ATT-02). Triggers (all `RAISE(ABORT, 'h-sink Sx: ...')`):
  `h_meta_bi` (once, into an empty store; valid canonical charge: S3/S7), `h_meta_ai` (makes the state row),
  `h_meta_bu`, `h_meta_bd` (immutable), `h_state_bi` (only from meta), `h_state_bu` (S2/S4: one commit step),
  `h_state_bd`, `h_settled_bi` (S1/S2/S3/S6: next seq, new request id, bindings, prev = last self),
  `h_settled_ai` (writes the outbox row and the state row: the ONE-statement commit), `h_settled_bu`, `h_settled_bd`,
  `h_outbox_bi` (only from its settled row; S4 limit), `h_outbox_bu`, `h_outbox_bd` (S5).

## 2. What each safeguard stops, and what it does not
| | stops (a writer that keeps the schema; buggy or old code; partial failure) | does NOT stop |
|---|---|---|
| S1 | a second row per request id (incl. `INSERT OR REPLACE`, which deletes without a delete trigger); request-id columns that differ from the token or intent | a corrupted UNIQUE index b-tree: that is integrity_check (C-ATT-10) |
| S2 | an outbox row without its settled row; a state change without a commit; any partial commit (the commit IS one statement) | a writer who disables triggers |
| S3 | a second meta row; meta UPDATE/DELETE; a token, intent or post state of another charge | a new file with another meta row (needs the anchor: h_0) |
| S4 | amount > remaining; cumulative amounts > original; non-canonical money text (sign, leading zero, >19 digits, > 2^63-1); a post state that changes anything but `remaining` | a key holder who signs authorized rows (a legitimate writer) |
| S5 | UPDATE/DELETE of settled, outbox; DELETE of state, meta (zero-row deletion Z1, swap Z2, erase Z3, prefix delete P1) | DROP TRIGGER; `.dbconfig enable_trigger off` in the sqlite3 shell (tested: triggers off, schema unchanged); `PRAGMA ignore_check_constraints`; a replaced file |
| S6 | an append whose prev is not the last self | a recomputed chain (it is UNKEYED): only the external anchor (`expectedHead`) |
| S7 | an invalid configured initial charge (F4): compiled `Refund.ValidContext(ContextOf(init,"init"))` and the meta trigger | an authentic-looking but wrong charge (authentic initial charge is an assumption) |
No-overflow argument (S4): in `core/store.ts` above the DDL. Every subtraction has operands in [0, 2^63-1]; the one
addition is bounded by `amount <= original - refunded`; SQLite turns an overflowing +/- into REAL, never wraps, and the
guards are conjuncts of the same condition, so a false guard raises.

Below the database: the start-up audit (and the dispatcher, before every run) checks the schema TEXT, runs the FULL
`PRAGMA integrity_check` (index b-trees agree with tables; also re-checks CHECK constraints), reads every column as
typeof + hex (exact bytes; U+0000 and BLOB refused), replays every commit with the compiled ShellCoreV5 `AuditStep`
(signature, ids, bindings, replayed pre-state, approved relation), recomputes the chain, and applies `AuditEnd` with
row counts and distinct counts computed `NOT INDEXED`. A hostile writer who drops the triggers, edits, and restores
the same trigger text passes the schema text check; the audit then refuses every edit that a row check, a count, the
`refunded` column or the chain sees. It ACCEPTS a rewrite that keeps every row authorized and recomputes the unkeyed
chain (tested: Z1 deletion with a recomputed chain starts without an anchor; it is refused with `expectedHead`).

## 3. Row-log head and anchor (aligned with orch-B/h-anchor)
h_0 = `genesisHash(initial text, specLock, checker, issuer key PEM)`, h_{i+1} = `linkHash(h_i, token text, intent text)`:
the same bytes as h-anchor/witness_file.ts. Difference: the head is not stored in meta keys; it is (max seq, `self` of
the last outbox row), written by the same one-statement commit. `head()` = the audited head in memory.
`cfg.expectedHead = {count, chainHash}` ("extends, not equals"): the store must have row `count` with that hash.
Dispatcher (witness): ledger lines carry `n` and `rowHead`; the store must extend the ledger's last rowHead, else the
run STOPS with a thrown alarm; a missing or empty ledger with committed rows is an ERROR unless `cfg.newLedgerH0` = h_0.
Without an external anchor (a ledger or witness on a different host or medium that is never rolled back: assumption
ANCHOR-MONOTONE) NO rollback resistance and NO forged-initial-database resistance is claimed.

## 4. Running sink (review F2/F3, C-ATT-12)
The sink keeps (fold state, count, chain). A foreign change (data_version or guard values) triggers: schema text,
integrity_check, meta, the head row re-hashed, then AuditStep over the NEW rows only (FoldResume is proved for the
in-memory fold; this loop is TESTED-UNPROVED). Anything else HALTS (every later commit: "sink halted"). Remaining
window: a corruption made and undone between two transactions of this sink is not seen.

## 5. Assumptions (by name)
SQLITE-SEMANTICS (triggers, CHECK, UNIQUE, integrity_check, IMMEDIATE transactions, data_version as documented);
SCHEMA-KEPT (a writer who alters the schema is detected at start or at the next foreign-change check only);
ANCHOR-MONOTONE (no rollback of the file without the external anchor); AUTHENTIC-INITIAL (cfg.initialState);
OPEN-IS-UNSETTLED; POST-RULE; the Dafny-to-JavaScript compiler and runtime; the TypeScript shell (sink.ts,
core/store.ts, dispatcher.ts: TESTED-UNPROVED); Node, OpenSSL, SHA-256, Ed25519; the issuer key is not leaked.

## 6. Migration of an existing store (DESIGN; not implemented; not run on real data)
The hardened sink REFUSES a store of the present or the v6 sink (other schema text). One-time import, offline, sink stopped:
1. Open the old file read-only; run the v6 audit (AuditV5) with the authentic initial charge; refuse on false.
2. Create a NEW file with the h1 DDL; `init(initial)`; for each old commit in seq order call the hardened `commit()`
   with the stored token text (each must return `committed`; the compiled StepQ6 re-decides every row).
3. Compare: same request ids, intents and final state; record (old file sha256, new head) for the anchor; keep the old
   file read-only. A row that the v6 sink accepted but StepQ6 refuses stops the import (owner decision).
The dispatcher ledger is NOT compatible (no n/rowHead): start a new ledger with `newLedgerH0` only after reconciling
the old ledger against the imported rows.

## 7. Performance (light single runs under memory pressure, HOL running; logs/perf-*.log)
| store | start-up audit | commit median / p90 (200 commits) | commit after a foreign append |
|---|---|---|---|
| 200 rows (small) | - | 3.4 ms / 9.0 ms | - |
| 5,000 rows | 3.33 s | 2.8 ms / 7.8 ms | 118 ms (integrity_check + counts; F3 v6: 640 ms) |
| 1,000 rows, dispatcher | first flush of 1,202 rows: 9.4 s (one fsync per ledger line); idle flush 0.33 s (full audit) | | |
20,000 rows: NOT RUN (the light run timed out at 60 s: load + audit exceed the light limit); prepared in heavy_h.sh (perf).
The dispatcher runs the full audit on every flush: O(n) per run.

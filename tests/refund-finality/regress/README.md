# Refund-finality regressions (night shift 2026-11-19, task h-regress)

Permanent, executable regressions for the counterexamples that the night shift confirmed against the refund
finality sink, and for the judge blind spots that the red team found (C-JUDGE-01..03). A TEST, not a proof. Each attack regression asserts the SAFE outcome on durable state (outbox rows,
stored state) and on effects (dispatcher emissions). It does not assert error texts.

## How to run

From a tree with `node_modules` (the repository root), with the pinned Node 24.3.0 first in `PATH`:

```
node --import tsx tests/refund-finality/regress/run.ts <sinkModulePath> <dispatcherModulePath> [expectedHeadMode] [--expect-fail <id,id,...>] [--only <id,id,...>]
```

Baseline commands (night shift 2026-11-19; the known sets of the table below):

```
# merged sink (branch head): exactly the eight known attack ids fail -> exit 0
node --import tsx tests/refund-finality/regress/run.ts ts/refund-finality/sink.ts ts/refund-finality/dispatcher.ts \
  --expect-fail X1-reqid-mismatch,X2-cross-charge,X2b-foreign-post-locks-store,X3-upgrade-legacy-gap,X4-signed-unauthorized,X5a-hostile-balance-reset,X5b-hostile-outbox-rewrite,X6-Z1-zero-row-deleted-recommitted
# v6 draft: exactly X6-Z1 fails -> exit 0
node --import tsx tests/refund-finality/regress/run.ts <v6 tree>/ts/refund-finality/sink.ts <v6 tree>/ts/refund-finality/dispatcher.ts --expect-fail X6-Z1-zero-row-deleted-recommitted
# hardened sink (h-sink): nothing fails -> exit 0
node --import tsx tests/refund-finality/regress/run.ts <h-sink tree>/ts/refund-finality/sink.ts <h-sink tree>/ts/refund-finality/dispatcher.ts
```

### Process model (red-team finding C-JUDGE-03)
- `run.ts` is the JUDGE (parent). It never loads the sink or the dispatcher. Each regression starts its own CHILD
  process (`worker.ts`, through `remote.ts`) that loads the two modules BY PATH and runs only the operations that
  the parent sends over the Node IPC channel: `new Sink(path, cfg)`, `init`, `commit(tokenText)`, `close`,
  `new Dispatcher(db, ledger, dcfg, emit).flush()`.
- The parent holds the keys, builds and signs every token, reads the DATABASE FILES ITSELF (node:sqlite,
  read-only), reads the dispatcher ledger file itself, and decides every verdict. The child's stdout, stderr and
  exit code are never a verdict. A child that exits, is killed, or does not answer in time makes that regression
  FAIL. A "restart" in a regression is a new child process (`Harness.restart()`).
- The parent prints exactly one verdict line per expected id and checks the count at the end.
- EFFECT RECEIVER (task h-judges2; red-team evasion `e_emit_twice_hidden2`). The PARENT holds the receiver. For each
  child it creates one extra pipe (child fd 4). The emit function that the child gives to the dispatcher under test
  writes one record per call into that pipe and BLOCKS until the parent ACKs it (an HMAC under a per-child secret
  that the parent sends on the pipe before any module under test loads). So the parent observes every emit call
  before it returns; at that moment it reads the ledger file itself (tolerant parser: any line, JSON or with a JSON
  object inside, that names the request id at any depth) and decides whether that emit fails (failure injection,
  D3). DEFINITION: an EFFECT is a record that the parent's receiver got. Every well-formed record on the pipe counts,
  whoever wrote it (a module that writes into the pipe, also through a duplicated descriptor, SENDS an effect). A
  record cannot be taken back. A module that does not call emit did not send; the liveness parts see the effect as
  MISSING. A flush ends with a BARRIER (a random nonce written by the worker after the dispatcher returned; the pipe
  keeps order). The regression FAILS (whatever its own outcome) on a CHANNEL FAULT: a record outside a flush (after
  its barrier), a line that is not a record or an asked barrier, or a pipe that some process still holds open 5 s
  after the child was killed (a forked process that could send late). The child no longer reports effects at all.
- MODULE GRAPH (task h-judges2; red-team evasion `enc_unsigned_body`). The worker records every file that Node's
  module resolver returns (a wrapper around `Module._resolveFilename`, installed before the modules under test load)
  and joins `require.cache`. The runner prints each loaded file with the SHA-256 that the PARENT computes; lines
  `# loaded ENCODING ...` mark the encoding modules (basename `encoding.*`, or a module that exports its own
  `signedBytes`, not a re-export).
- Exit codes: 0 when every id is `PASS` or `KNOWN-LIMIT` and every expected id has exactly one verdict. With
  `--expect-fail`: 0 when exactly the listed ids are `FAIL` and all others are `PASS` or `KNOWN-LIMIT` (an
  unexpected FAIL or an unexpected non-FAIL gives 1). 1 otherwise. 2 on a usage error (also an unknown id).
- The last lines: `# verdicts=…`, `# unexpected FAIL=[…] unexpected non-FAIL=[…] missing verdicts=[…]`,
  `# JUDGE RESULT OK|NOT OK`.

### Trusted encoding
Tokens are signed and decoded with the `encoding.ts` of the tree that the judge lives in
(`../../../ts/refund-finality/encoding`). The encoding of the code under test is found in its LOADED MODULE GRAPH,
never by a path next to the sink: case E0 FAILS when an encoding module of that graph has another SHA-256, or when
the graph has none. The verdicts on signed bytes are by BEHAVIOUR (E1, E2, D5): the trusted key signs candidate byte
strings (the trusted signedBytes; every bytes function exported by a loaded encoding module, where it maps the honest
and the altered body to the same bytes; canon of subsets of the body), and a token whose signed field changed while
the signature was kept must not commit and must not be emitted.

### Configuration and capabilities
- `cfg` always carries `initialState`. The dispatcher config carries `newLedgerH0` when the sink module exports
  `genesisOf` (checked in the child; the hardened sink needs it to start a new ledger).
- `expectedHeadMode`: `none` (default) or the path of an anchor adapter module that exports `capture(h, dbPath)`
  and `apply(cfg, head)` (see `harness.ts`). Only X6-P1 uses it.
- Durable state is read with raw SQL from the tables `state` (blob), `settled` (request_id) and `outbox`
  (request_id, intent). No assumption on the number of statements of a commit.

### Hostile writer: two strengths
A hostile-writer case (X5a, X5b, X6-Z1, X6-P1, D1, D2) runs first with a writer that KEEPS the schema. If the
database aborts that write (triggers, CHECK), the abort is the SAFE outcome for that writer ("write refused by the
database"), and the case runs again (fresh directory, fresh child) with a writer that DROPS every trigger, sets
`PRAGMA ignore_check_constraints`, writes, and restores the trigger text. The second run gives the verdict. A write
that fails even then (for example NOT NULL) is also safe. D1 and D2 do NOT recompute the hardened sink's unkeyed
chain. D4 and D5 DO (task h-judges2, `Harness.appendRow`): the row-log chain is recomputed with the trusted chain
function of the judge's tree (`genesisOf`, `linkOf` in `ts/refund-finality/core/store.ts`), so only the signature
(D4) or the signed bytes (D5) can stop the row. Each has a CALIBRATION: the same writer stores a VALIDLY signed row,
and the dispatcher must emit it once (else the case FAILS as "calibration": the judge cannot build a chain-valid row
for that store, and it does not claim to have tested the signature).

### Status words
`PASS` (the safe outcome holds), `FAIL` (the unsafe outcome happened, a control or a liveness part failed, or the
child died), `KNOWN-LIMIT` (only for kind `limit`: an unsafe outcome that is a stated limit, for example a rollback
of the database without an outside anchor; it is not a pass and it does not count as a failure).
A regression of kind `limit` has three outcomes: SAFE (the sink refuses the unsafe thing) = `PASS`; the stated
limit still holds = `KNOWN-LIMIT`; anything else = `FAIL` (red-team finding C-JUDGE-02).

Other details: each regression uses a fresh directory under the system temp directory (removed at its end); fixed
ids and amounts; no clock; no network; test keys generated in the parent (no result depends on them). A faulty
signer is modelled by the trusted test key signing an arbitrary body.

## Table

| id | attack class (assumption) | unsafe outcome on the merged sink | expected safe outcome | evidence |
|---|---|---|---|---|
| C1–C5 | positive controls (none) | none: all PASS | honest refund, zero-amount refund, two zero refunds, replay (no second effect), amount == remaining: each intent once in the outbox and emitted once | spec/refund/protocol.md (zero is legitimate) |
| X1 | request-id mismatch (faulty signer) | 2 outbox intents and 2 effects for `rq_victim` | at most 1 intent and 1 effect for `rq_victim`; the honest one is emitted once | U530, U534; d-reqid Contrast.dfy, single_runs.ts |
| X2 | cross-charge (faulty signer) | 2 effects for (`ch_2`, `rq_x`), 100 for a charge of 50 | at most 1 effect for (`ch_2`, `rq_x`), at most 50 for `ch_2`; no `ch_2` intent in `ch_1`'s outbox | U534; r-reqid Attack.dfy CrossChargeWithReqIdPatch |
| X2b | foreign post-state (faulty signer) | `ch_1`'s store holds `ch_2`; no `ch_1` refund commits again | store keeps `ch_1`; a later honest `ch_1` refund is emitted once | Attack.dfy ForeignPostLocksStore |
| X3 | upgrade from a legacy gap store (faulty signer before the upgrade) | 1 effect before + 1 after for `rq_victim` | at most 1 effect in total for `rq_victim` | U534; r-reqid upgrade_run.ts (mode flushed) |
| X4 | signed but unauthorized token (faulty signer; B-10; POST-RULE open) | all 5 cases commit and are emitted (case a: 1001 of 1000) | no outbox row, no effect, state unchanged; a later honest refund is emitted once | U555, U557; d-v6sink conformance_v6.ts; r-v6 rv6_cases.ts |
| X5a | balance reset (database writer without key) | outbox total 2000 for a charge of 1000 (the dispatcher still emits only 1000) | outbox total and emitted total at most 1000 | U554; r-repairs attack_v4.ts S1 |
| X5b | outbox amount rewrite (database writer without key) | `rq_2` settled on the tampered store | no unsigned intent emitted; no new settlement while the rewritten row is present | U554; r-repairs attack_v4.ts S2 |
| X6-Z1 | zero-row deletion, then re-commit (database writer without key) | `rq_z1` settled again (also on the v6 draft: finding F1) | `rq_z1` not settled again; emitted at most once | U565; r-v5 attack_rv5.ts Z1 |
| X6-P1 | prefix rollback (database writer; a STATED LIMIT) | KNOWN-LIMIT: the store starts and settles `rq_2` again | without an anchor: refusing = PASS, settling again = KNOWN-LIMIT; with an anchor adapter: refusing = PASS, settling again = FAIL; `rq_2` emitted at most once in every mode | U565; r-v5 attack_rv5.ts P1; C-JUDGE-02 |

A reject-all sink passes most "at most" assertions. The positive controls, and the liveness parts of X1, X2, X2b
and X4 and the setup checks of X5 and X6, make it FAIL.

## Judge blind-spot regressions (red-team finding C-JUDGE-01; task h-judges)

Source of each expected outcome: the Slice 1 finality design (`ts/refund-finality/sink.ts` checks 1-4,
`ts/refund-finality/dispatcher.ts` checks 1-5 and the ledger order); the approved refund text is SILENT on tokens.
Status words asserted by K4 are the ones that the merged sink documents (`CommitResult`): `committed`,
`replayed`, `rejected`. File: `k_judge_blindspots.ts`.

| id | class | expected safe outcome (durable state and effects) | liveness part | red-team mutant it catches |
|---|---|---|---|---|
| K1 | foreign-key signature | no outbox row, state unchanged | same body, pinned key: committed, emitted once | m_accept_bad_sig |
| K2 | non-canonical token text (indentation, key order, escaped letter) | none commits | the canonical text commits, emitted once | m_accept_noncanon |
| K3 | stale pre-state (zero amount, post = stored state) | does not commit | current pre-state: committed, emitted once | m_skip_prestate |
| K4 | replay answer | identical retry: `replayed`, no second row or effect; another token for the settled id: `rejected`, no change | one effect | m_replay_says_rejected, m_replayed_any |
| K5 | request ids of 33, 64, 256 units; BMP, non-BMP, combining marks | foreign-key and stale tokens for the id do not commit | the authorized token for the id commits, emitted once | m_id_gt32_or_nonascii |
| K6 | 37 + 1 honest commits on one store, two PROCESS restarts | unauthorized tokens after 37 commits do not commit; state, settled and outbox survive each restart | 38 effects, each once | m_late20, m_wipe_on_open |
| K7 | reopen (same process) and process restart | the store is unchanged after each open; the first token again is no new row | the next honest refund commits; four effects | m_wipe_on_open |
| D1 | dispatcher: chain-continuing row signed by a foreign key (database writer) | not emitted | rq_1 emitted once | md_ignore_sig |
| D2 | dispatcher: validly signed row that does not continue the chain (database writer) | not emitted | rq_1 emitted once | md_ignore_chain |
| D3 | dispatcher: order of ledger line and effect; a failed effect | at every emit the ledger already holds the line (documented order: line appended and synced BEFORE the effect, at most once); after a failed emit the ledger records rq_1, rq_2 (rq_2 is a lost effect for a person to reconcile, never re-sent); no id emitted twice | the second flush emits rq_3 | md_emit_before_ledger |
| E0 | encoding identity (h-judges2: from the LOADED module graph) | every encoding module that the code under test loaded has the trusted SHA-256; at least one is loaded | - | enc_unsigned_body |
| E1 | post and intent altered after signing | no commit with the trusted signed bytes; probe: every bytes function of the LOADED encoding modules that gives the same bytes for the original and the altered body: the trusted key signs those bytes, and the altered token must still not commit | honest token committed, emitted once | enc_unsigned_body |
| E2 | one signed field changed, signature kept (h-judges2) | for post, amount, reason, amount+post, request id, charge id, pre-state hash: no commit for any candidate signed bytes (trusted signedBytes; colliding loaded bytes functions; canon of every subset of the top-level keys without the changed ones; canon with the changed nested keys deleted): 365 deliveries on the branch head | honest token committed, emitted once | enc_unsigned_body, own_enc_no_reason |
| D4 | dispatcher: CHAIN-RECOMPUTED writer row with a foreign-key, zero-byte or other-body signature, amounts 50 and 0 (h-judges2) | not emitted | calibration: the same writer's validly signed row (50 and 0) emitted once; rq_1 emitted once per store | md_ignore_sig, own_d_sig_nonzero_only |
| D5 | dispatcher: CHAIN-RECOMPUTED writer row whose reason, or amount and post, changed while a trusted signature over candidate bytes was kept (h-judges2) | not emitted | calibration: the honest stored row emitted once | enc_unsigned_body, md_ignore_sig |

Note on D3: the task text asked also that "after a failed emit the ledger must not claim the effect was sent".
The merged dispatcher documents the opposite order on purpose (at most once: ledger first; a crash loses the
effect, a person reconciles it). D3 asserts the DOCUMENTED order.

## Remaining trust in a hostile child (task h-judges2; named, not tested away)
- OUT-OF-BAND-EFFECT: a module can send an effect through a side channel that the parent does not own (a network
  socket, a file, another process). Out of scope for a test harness; in production the receiver is the provider.
- IN-PROCESS-TAMPER: code in the child can read the worker's closure (for example through `node:inspector`) and forge
  ACKs or barriers. It can then hide its OWN failure injection or move records between flush windows; it cannot take
  a record back (every record on the pipe counts, and a late record is a channel fault).
- HIDDEN-LOAD: a module can load code without Node's resolver (fs + vm) or delete `require.cache` entries; E0 then
  does not see that encoding. E1, E2 and D5 still judge by behaviour, but only for the candidate byte definitions
  they try (SIGNED-BYTES-OUTSIDE-FAMILY: a private byte definition that is not a bytes function of a loaded encoding
  module and not a canon projection of the body, for example a hash of selected fields, is not tried).
- TRUSTED-CHAIN-FORMULA: D4 and D5 recompute the chain with the judge tree's `linkOf`; a store with another chain
  makes their calibration FAIL (reported as such, not as a pass).

## Known sets (night shift 2026-11-19, actual runs; logs in results/night-shift-20261119/orch-B/h-judges/logs)

| tree | FAIL | KNOWN-LIMIT | baseline command exit |
|---|---|---|---|
| merged (branch head) | X1, X2, X2b, X3, X4, X5a, X5b, X6-Z1 | X6-P1 | 0 with the eight ids in `--expect-fail` |
| v6 draft | X6-Z1 | X6-P1 | 0 with `--expect-fail X6-Z1-zero-row-deleted-recommitted` |
| hardened (h-sink) | none | none (X6-P1 SAFE: refused at start) | 0 with no `--expect-fail` |

h-judges2 (29 cases: E2, D4, D5 added; logs in results/night-shift-20261119/orch-B/h-judges2/logs): the branch head
74fb70eb with no `--expect-fail`: 29 PASS, exit 0; see the h-judges2 report for the merged and v6 runs.

## Red-team regressions (Orchestrator C), added by Orchestrator B

| id | attack class | unsafe outcome before the fix | safe outcome | how to run |
|---|---|---|---|---|
| C-ATT-01 | malformed input: an id with U+2028 or U+2029 | the proposer client cut the issuer's answer in two (node:readline); the mint never got its answer (liveness; no safety loss) | the client splits lines at the byte 0x0A only; the answer arrives whole | `node --import tsx tests/refund-finality/regress/c_att_01_line_separator.ts` (stands alone; exit 0 = pass) |
| C-ATT-16 | identity substitution in the untrusted proposer client | a body key `id` replaced the client's counter: one caller got another caller's answer | the client's own counter is always the message id | `node --import tsx tests/refund-finality/regress/c_att_16_client_id_override.ts` (stands alone; exit 0 = pass) |

The status words are described in "How to run" above.

# Spec conformance of refund sinks

These files test a REAL sink against an oracle built only from the APPROVED refund specification
(`spec/refund/RefundSpec.dfy`, `spec/refund/protocol.md`) and the compiled approved `Refund.Assess`.
They do not compare one model with another model. The property list with its sources is `SPEC_ORACLE.md`.
Status: TESTED-UNPROVED. Nothing here is a proof.

| Id | Property (short) | Source | Responsible |
|----|------------------|--------|-------------|
| P1 | every effect is the one intent that Assess authorizes on the persisted charge | RS 33-36, 48-58; PR 22-24, 68-70 | sink |
| P2 | at most one effect per (charge id, request id) | PR 61, 63-65 | sink |
| P3 | state evolves by POST-RULE (unratified); 0 <= remaining <= original <= MaxMoney | RS 27-31; PR 18; evolution SILENT | sink |
| P4 | sum of effects of a charge <= its original | derived (R1 + POST-RULE); PR 89-92; sum rule SILENT | sink |
| P5 | no extra rejection of a valid, fresh, current, authorized token (zero included) | PR 22-27, 79; RS 50-52; token checks SILENT | sink |
| P6 | a rejected or replayed delivery changes no durable state | PR 28-30, 63-64 | sink |
| P7 | effects carry the persisted charge id | RS 53, 59-63; PR 15-17 | sink |
| P6R | an identical repeat of a committed token answers `replayed`; another token for a settled id answers `rejected` | PR 63-65 | sink |
| P8 | AUTHENTICITY OF COMMITS: a commit is the canonical text of a token that verifies under the PINNED key with the pinned ids over the TRUSTED signed bytes, with the current pre-state hash; the store records its signed request id, intent and post | Slice 1 finality design (sink.ts checks 1-4); the approved protocol.md is SILENT on tokens | sink |
| P9 | a restart of the sink changes no durable state | Slice 1 design (durable store); PR 89-90 "durable" | sink |
| P1/P2/P4 on emissions | every emitted effect is an outbox intent; at most one per (charge id, request id); emitted sum <= original | as P1, P2, P4 | dispatcher (with `--dispatcher`) |

Unratified choices that the oracle uses: OPEN-IS-UNSETTLED, POST-RULE.

## Files
- `oracle.ts`: replays a history (initial charge, deliveries with outcomes, restarts, snapshot after each, and
  optionally the dispatcher's emitted effects) and checks P1-P9. Imports only the TRUSTED
  `ts/refund-finality/encoding.ts` of its own tree and the compiled approved module (by path).
- `run.ts`: seeded generator and driver. The sink (and with `--dispatcher` the dispatcher) runs in ONE CHILD
  process (`../regress/worker.ts`) for the whole run; the driver never loads it. The driver delivers sequences
  over IPC, reads the durable state through its own read-only SQLite connection, calls the oracle, prints one
  JSON line. A child that exits or stops answering ends the run with exit 1 (field `childGone`).
  With `--dispatcher`, the EFFECT RECEIVER is held by the driver (task h-judges2; `../regress/remote.ts`): each emit
  call of the dispatcher under test is a record on a pipe that the driver created, ACKed by the driver before the call
  returns; the emitted effects that the oracle checks are the records that the driver got, never a child report. A
  channel fault (a record outside a flush, a line that is not a record, a pipe held open after the child died) makes
  the run NOT OK (field `effectChannelProblems`). Remaining trust: OUT-OF-BAND-EFFECT, IN-PROCESS-TAMPER (see
  `../regress/README.md`).
- `selftest.ts`: hand-made histories with a known violation of P1-P9 and of the emission checks, a start
  refusal, and clean histories (21 cases).
- `heavy_spec.sh`: the heavy run (5,000 sequences per mode per sink). It refuses while hol.lock exists or a
  HOL process runs. It does not take heavy.lock.

## Build the compiled approved module
As in `scripts/exit_slice1.py` (`sink_controls`):
`dafny build impl/RefundFinality.dfy --target js --output <dir>/model <gate options>`, then
`<dir>/model.cjs` = `<dir>/model.js` + `\nmodule.exports = { RefundFinality, Refund, runtime: _dafny };\n`.
The oracle uses only `Refund` (`Refund.__default.Assess`, `Refund.Context`, `Refund.ModelResponse`).

## Run (pinned Node 24.3.0 first in PATH; from the repository root)
- `node --import tsx tests/refund-finality/spec-conformance/selftest.ts <model.cjs>` (exit 0 = all cases pass)
- `node --import tsx tests/refund-finality/spec-conformance/run.ts <sink.ts> <seq|fault|interleave> <count> <seed> <model.cjs> [workDir] [--dispatcher <dispatcher.ts>] [--expect-violations P1,P2,...]`
  - EXIT CODE: 0 only when all sequences ran, the child stayed alive, and the set of violated properties
    (P5-SILENT excluded: a question for the owner, not a verdict) is empty, or equals `--expect-violations`.
    1 otherwise. 2 on a usage error.
  - Baseline for the merged sink (branch head): `--expect-violations P1,P2,P3,P4,P7` (seq 200 1 with the merged
    dispatcher: exit 0). The v6 draft and the hardened sink: no flag (seq 200 1: exit 0).
  - Also generated: restarts of the sink (6 % of steps), stores with 21-35 deliveries (10 %), request ids with
    40 extra units, non-ASCII BMP, non-BMP and combining characters, and non-canonical token texts (kind noncanon).
  - A sink that refuses to start on a valid initial charge (an approved ValidContext) is a P5 violation; a refusal
    of a charge with refundEnabled false is not (no token for it can be authorized; RS 27-31).
  - delivery kinds: honest (random, zero, amount = remaining), replay, stale, wrong signature, wrong pinned
    spec lock, reused request id, and FAULTY-SIGNER tokens signed by the trusted test key: request-id mismatch,
    foreign charge in the intent, foreign post-state, amount above remaining (post remaining 0, or post
    unchanged), unapproved reason, refund while refundEnabled is false, post original above MaxMoney; probes:
    request id of 300+ units, request id with U+0000.
  - fault: a storage write throws inside the sink's transaction (30 % of deliveries). P5 is not demanded there.
  - interleave: two sink instances on one database file in one process (alternation, not concurrency).
  - Output fields: `sequencesWithViolation` (per property), `violated`, `verdict`, `childGone`, `sequencesDone`,
    `violationsByKind`, `smallest` (shortest prefix that shows each property), `kindOutcome`, input SHA-256 values
    (sink, dispatcher, trusted encoding, core).
- `bash tests/refund-finality/spec-conformance/heavy_spec.sh <model.cjs> <outDir> <sink>...` (a nonzero status now
  means: some property is violated or a run did not complete; read results.jsonl).

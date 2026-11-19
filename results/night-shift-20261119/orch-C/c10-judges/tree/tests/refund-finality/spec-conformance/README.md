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

Unratified choices that the oracle uses: OPEN-IS-UNSETTLED, POST-RULE.

## Files
- `oracle.ts`: replays a history (initial charge, deliveries with outcomes, snapshot after each delivery) and
  checks P1-P7. Imports only `ts/refund-finality/encoding.ts` and the compiled approved module (by path).
- `run.ts`: seeded generator and driver. Loads a sink module by path, delivers sequences, reads the durable
  state through its own read-only SQLite connection, calls the oracle, prints one JSON line.
- `selftest.ts`: hand-made histories with a known violation of P1, P2, P3, P4, P5, P6, P7 and one clean history.
- `heavy_spec.sh`: the heavy run (5,000 sequences per mode per sink). It refuses while hol.lock exists or a
  HOL process runs. It does not take heavy.lock.

## Build the compiled approved module
As in `scripts/exit_slice1.py` (`sink_controls`):
`dafny build impl/RefundFinality.dfy --target js --output <dir>/model <gate options>`, then
`<dir>/model.cjs` = `<dir>/model.js` + `\nmodule.exports = { RefundFinality, Refund, runtime: _dafny };\n`.
The oracle uses only `Refund` (`Refund.__default.Assess`, `Refund.Context`, `Refund.ModelResponse`).

## Run (pinned Node 24.3.0 first in PATH; from the repository root)
- `node --import tsx tests/refund-finality/spec-conformance/selftest.ts <model.cjs>` (exit 0 = all cases pass)
- `node --import tsx tests/refund-finality/spec-conformance/run.ts <sink.ts> <seq|fault|interleave> <count> <seed> <model.cjs> [workDir]`
  - delivery kinds: honest (random, zero, amount = remaining), replay, stale, wrong signature, wrong pinned
    spec lock, reused request id, and FAULTY-SIGNER tokens signed by the trusted test key: request-id mismatch,
    foreign charge in the intent, foreign post-state, amount above remaining (post remaining 0, or post
    unchanged), unapproved reason, refund while refundEnabled is false, post original above MaxMoney; probes:
    request id of 300+ units, request id with U+0000.
  - fault: a storage write throws inside the sink's transaction (30 % of deliveries). P5 is not demanded there.
  - interleave: two sink instances on one database file in one process (alternation, not concurrency).
  - Output fields: `sequencesWithViolation` (per property), `violationsByKind`, `smallest` (shortest prefix
    that shows each property), `kindOutcome`, input SHA-256 values.
- `bash tests/refund-finality/spec-conformance/heavy_spec.sh <model.cjs> <outDir> <sink>...`

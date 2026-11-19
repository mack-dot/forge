# Orchestrator B (trust track) — INTERIM morning report, written 2026-11-19T09:04:51Z

INTERIM: the harness required B to hand back at this time. Five workers were still assigned (b-ser, x-issuer-bridge,
b-export-bridge, r-integrate, e-totality); their results are NOT in this report and NOT re-checked. Resume from
`orch-B/STATE.md`. M1-B OPEN. `end_to_end=false`. No stage CURRENT. Nothing merged, pushed, signed, deployed or applied.
Branch `nightshift/B-trust`, commits 865730fd, fa5d74d7, d3090093 (+ this file). unsure entries U530–U536.

## New proofs (Dafny model level; pinned Dafny 4.11.0, gate options; B's own runs, exit 0)
| File (orch-B/…) | Verified | Statement |
|---|---|---|
| b-signing/SliceSafetyV2OnBytes.dfy | 1632 | composed lemma WITHOUT the impossible IdealMac: from H1 (step-local, claim-level unforgeability), A2 (issuance), A5, A6b (flat contract on byte strings) |
| b-signing/TotalReading.dfy | 34 | a model instance whose verifier is total (non-vacuity of the reading) |
| d-reqid/…/SinkCoreReqId.dfy; Contrast.dfy | 73; 106 | request-id check: one effect per request id with no signature assumption; counterexample on the unchanged core |
| d-corebacked/…/ShellCoreReqId.dfy | 77 | core with a boolean pre-state input agrees with the patched core (for a draft sink) |
| b-integrate/SinkCoreV3.dfy | 70 | both checks (request id, charge id); exact acceptance; executable start audit |
| b-integrate/SliceSafetyV3.dfy | 1633 | layered: L0 no hypothesis; L2 H1+A2+A5; L3 +A6b — REVIEW PENDING |
| b-integrate/MultiCharge.dfy; MultiChargeLayered.dfy | 141; 1730 | several charges — REVIEW PENDING |
| f-records (six stored records, rerun) | 1489, 1486, 56, 60, 67, 1570 | reproduced from `git archive 985f5eaf` by one runner; B's rerun: same |
Reviews done by separate workers: d-reqid (confirmed, narrower start condition), SliceSafetyV2 (claim level confirmed).

## New counterexamples
- Unchanged sink core: two effects for one request id (proved); also shown on a copy of the MERGED ts/refund-finality/sink.ts with test keys.
- Request-id patch alone: false after an upgrade from a store the unpatched sink wrote; cross-charge double refund without a charge-id check (proved).
- Byte layer of V2: "serializer injective on claims" is false for the real token (it holds a SHA-256 of the pre-state); a collision commits an unapproved effect (proved, conditional on a collision).
- Gate: four submissions with no `expect` verify, audit clean and would halt or hang on one keyed amount; no tier refuses them.
- Admission: `main` unprotected; an agent session holds the owner's admin credential (read by GET).

## Composed guarantee
Ledger orch-B/f-binding (verifier exit 0, 29 of 29 controls; identity and record consistency only): 33 chain edges:
6 MACHINE-CHECKED, 8 ASSUMPTION, 4 TESTED-UNPROVED, 9 MISSING, 6 without a log of this night. It predates V3 and A's
later HOL results: refresh with make_ledger.py. No MACHINE-CHECKED edge is about sink.ts, minter.ts, compiled JavaScript
or the running process. Edge X16: the issuer calls the compiled Dafny checker, not the M1 binary: the two chains do not meet.

## Remaining gaps and security
Assumed: H1 (EUF-CMA + key only in the issuer + collision resistance), A2 (issuer glue), A5, A6b, the Dafny-to-HOL bridge,
exporter identity, launcher integrity, strict single-frame parse, atomic commit (SQLite), the Dafny-to-JavaScript compiler.
Tested only: sink.ts against any core. Missing: enforced admission; memory bound in the gate; executable totality.

## Reproducibility
`orch-B/f-records/reproduce_dafny_proofs.py` and `check_records.py [--rerun]`; `orch-B/tools/dafny_locked.sh`;
`orch-B/f-binding/verify_ledger.py`. The f-records verify logs are not in the branch copy (home paths); they are in the main checkout.

## NOT RUN
Every heavy step: the 5,500-sequence differentials (d-reqid, d-corebacked), the hostile gate controls (e-expect). Orchestrator A held hol.lock.

## Next critical obligation
Close edge X16/U5b: make the proved decision the deployed decision. Input: d-corebacked/sink_core_backed.ts with SinkCoreV3;
command: the prepared heavy differential under heavy.lock; acceptance: 0 divergences except the intended refusals, then the owner's B-1/B-2 decision.

## Owner decisions
`OWNER_REQUIRED.md` items B-1 to B-5 (exact diffs with SHA-256; none applied).

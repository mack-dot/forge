# Forge Round 2 plan and status (tracked)

Owner's text, verbatim: [proposals/round2-20261117/OWNER_ROUND2_TEXT.md](proposals/round2-20261117/OWNER_ROUND2_TEXT.md)
(sent 2026-11-17; then: "make this an md we track and then /goal track
the md and do it"). This file is the working plan. It is updated after
every step with real exits. Master idea: [FORGE_MASTER_IDEA.md](FORGE_MASTER_IDEA.md).

Goal condition (short form for `/goal`): "Every row in the status table
of FORGE_ROUND2_PLAN.md is DONE with a recorded exit, or BLOCKED with
the exact blocker recorded in unsure.md; the final report table is in
the file."

## Standing rules for the round

- Stage 12 UNAUTHORIZED. `end_to_end=false`. No profile approval.
- Checker exit, gate exit and scenario exit are recorded separately.
- `unsure.md` is append-only; new entries start at U417.
- Protected paths (`gate/`, `policy/`, `spec/`, `spec.lock`,
  `toolchain/`, `schemas/`, `.github/`, `AGENTS.md`): the ONLY approved
  change is `proposals/forge2-pillar1-print-effects/candidate.diff`
  (Decision 1). Everything else is built under `proposals/` and offered
  as a candidate diff.
- Commit at checkpoints on the backup branch. NO push until the owner
  has seen the final table. Never force-push. `main` untouched.
- Failed attempts, exit 4 records and `unsure.md` history are never
  scrubbed. Only machine-identifying local paths in newly committed
  files may be replaced.
- At most five attempts per failing proof; then record the blocker.
- No global resource-limit increase to make a proof pass.

## Owner decisions (2026-11-17)

1. `candidate.diff` (print effects, three files): APPROVED. Commit the
   U413–U416 round first; apply the diff as a separate step; regenerate
   evidence with fresh checker runs; re-run Stage 0–8 EXIT commands and
   the print-effects control. `--enforce-determinism` stays OFF.
   Prepare, do not apply, a companion diff for Booking and Refund.
2. HOL/PolyML/CakeML rebuild: APPROVED with a lock marker and a budget
   of 90 minutes wall-clock for rebuild plus replay of the committed M1
   chain. Replay and SHA-256 check first; then `fs-0001`/`fs-0002`. On
   budget overrun or fetch/pin blocker: stop, record, continue with the
   other tasks.
3. Pillar II: Ed25519 signatures (sink holds only the public key);
   Refund first.
4. Commit at verified checkpoints; no push before the final table.

## Status table

Status words: TODO, RUNNING, DONE (exit recorded), BLOCKED (blocker
recorded), PARTIAL.

| # | Step | Status | Exits / record |
| --- | --- | --- | --- |
| 1A | Commit the U413–U416 round (paths in new files scrubbed) | DONE | commit `93712d2c`; one path scrubbed; U417 |
| 1B | Apply `candidate.diff`; regenerate evidence; Stage 0–8 EXITs; print control | BLOCKED | applied, measured, REVERTED: Stages 5, 6, 8 regress (refund spec lock pins `toolchain/pins.json`). Ledger gate rejects both planted print bugs with the change (exit 1) and accepts them without it (exit 0). Needs a complete version 2 with further protected files. U419; [record](proposals/forge2-pillar1-print-effects/REGRESSION.md) |
| 1C | Companion candidate diff for Booking and Refund gates (not applied) | TODO | |
| T1a | W2 proved without a higher resource limit | DONE | attempt-0013 exit 0; 61 batches, largest 707,136; U418 |
| T1b | Spec-pair diff harness on two pairs (Ledger fee; Refund variant) | PARTIAL | both pairs proved (attempt-0014 exit 0, 13 cases); witnesses generated from tables; general lemmas hand-written; U418 |
| T2 | Split-edit control against the existing PR gate | TODO | |
| T3 | Refund minter (Ed25519) + SQLite sink + ≥ 30 attacks | DONE (finite test) | suite exit 0 twice; 38 of 38 attacks as expected; 0 unauthorized settlements; U420; [report](proposals/forge2-pillar2-refund-finality/REPORT.md) |
| T4 | Pillar III: checker (done as F3.1) + 25-version solver benchmark | DONE (finite benchmark) | bench exit 0; 2,300 checks; 0 accepted overbookings; 0 Dafny runs per version; U421; [report](proposals/forge2-pillar3-dual-certificate/benchmark/REPORT.md) |
| T5a | Toolchain rebuild and M1 replay within 90 minutes | RUNNING | started 12:42:33 local; hard stop at 5,400 s; `results/round2-m1-rebuild-20261117/attempt-0001/commands.json` |
| T5b | `fs-0001`/`fs-0002` witness | TODO | |
| F | Final report table; `FORGE_MASTER_IDEA.md` and `unsure.md` updated | TODO | |

## Notes that bind the execution

- T5a feasibility is measured before any long build starts. The
  original chain used prebuilt heaps (CakeML basis and compiler proofs).
  If the records show that a rebuild cannot fit in 90 minutes, the
  step is recorded as BLOCKED by budget with the measured numbers; a
  partial build is kept under the lock marker only if it can be
  resumed.
- T3 results are tests (finite). The Dafny protocol model is a proof
  about a model. Neither changes `end_to_end=false`.
- T4: the Dafny checker exists (`proposals/forge2-pillar3-dual-certificate`,
  F3.1). "0.000 s re-verification" means only that the checker file
  does not change between solver versions.

## Final report table

(filled at the end of the round)

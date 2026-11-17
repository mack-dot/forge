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
| 1B | Apply `candidate.diff`; regenerate evidence; Stage 0–8 EXITs; print control | BLOCKED (owner decision) | Approved diff applied, measured, reverted (U419). Complete version 2 built and measured in a scratch worktree: Stages 1, 2, 3, 5, 8 exit 0; Stage 6 `report` exit 1 after ANY gate change (record pins the old gate bytes); Stage 4 and 7 fail in the baseline too (GitHub 403, Docker). Not applied. [PROPOSAL-V2](proposals/forge2-pillar1-print-effects/v2/PROPOSAL-V2.md); U423 |
| 1C | Companion candidate diff for Booking and Refund gates (not applied) | DONE | no extra diff needed: existing gate inputs already call the methods; `check_booking_refund.py` scenario exit 0 (8 rows); U423 |
| T1a | W2 proved without a higher resource limit | DONE | attempt-0013 exit 0; 61 batches, largest 707,136; U418 |
| T1b | Spec-pair diff harness on two pairs (Ledger fee; Refund variant) | PARTIAL | both pairs proved (attempt-0014 exit 0, 13 cases); witnesses generated from tables; general lemmas hand-written; U418 |
| T2 | Split-edit control against the existing PR gate | DONE | `run_control.py` attempt-0001 scenario exit 0; 16 cases; 0 evasions; no new gate module; U422 |
| T3 | Refund minter (Ed25519) + SQLite sink + ≥ 30 attacks | DONE (finite test) | suite exit 0 twice; 38 of 38 attacks as expected; 0 unauthorized settlements; U420; [report](proposals/forge2-pillar2-refund-finality/REPORT.md) |
| T4 | Pillar III: checker (done as F3.1) + 25-version solver benchmark | DONE (finite benchmark) | bench exit 0; 2,300 checks; 0 accepted overbookings; 0 Dafny runs per version; U421; [report](proposals/forge2-pillar3-dual-certificate/benchmark/REPORT.md) |
| T5a | Toolchain rebuild and M1 replay within 90 minutes | BLOCKED by budget | tools rebuilt as far as CakeML `basis` (exit 0); compiler proofs killed at 5,400 s; replay NOT RUN; U424; [report](proposals/round2-20261117/m1-rebuild/REPORT.md) |
| T5b | `fs-0001`/`fs-0002` witness | BLOCKED | gated on the replay by decision 2; NOT RUN; U424 |
| F | Final report table; `FORGE_MASTER_IDEA.md` and `unsure.md` updated | DONE | table below; U417–U424 |

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

"—" means that the kind of exit does not exist for that row. Checker =
Dafny or HOL; gate = `gate/gate.py` or `gate/incremental.py`; scenario =
the runner or suite that judges the case.

| EXIT command/check | Checker exit | Gate exit | Scenario/Actual exit | Result & exact scope |
| --- | --- | --- | --- | --- |
| **1. Decision 1** | | | | |
| `git apply candidate.diff` then `gate/gate.py --impl impl/Ledger.dfy` | 0 | 0 | — | accepted; evidence differs in five expected fields. Then REVERTED |
| changed gate on `bugs/print_effect.dfy`, `bugs/print_effect_marked.dfy` | 2; 2 | 1; 1 | — | both rejected. Unchanged gate: gate exit 0 for both (accepted) |
| 28 EXIT cases, baseline `93712d2c` | — | — | 22 × 0; Stage 4 × 3 = 1; Stage 7 × 3 = 1 | Stage 4: GitHub API HTTP 403. Stage 7: Docker not available. Both without any change |
| Stage 4, three cases, rerun with read-only GitHub authentication (`GH_TOKEN` from the `gh` login; prior failed reports preserved) | — | — | 0; 0; 0 | passed: the first failure was an unauthenticated API limit. Baseline is 25 of 28; only Stage 7 (Docker image store removed) fails |
| 28 EXIT cases, approved diff alone | — | — | Stages 1–3 = 0; 5 mutations, 6 report, 8 × 3 = 1 | regression; diff reverted (U419) |
| 28 EXIT cases, version 2 in a scratch worktree | — | — | Stages 1, 2, 3, 5, 8 = 0 (19 cases); 6 report = 1; 4 and 7 as baseline | NOT APPLIED. Stage 6 `report` cannot pass after any gate change (U423) |
| `check_booking_refund.py` | 0 (approved, with option); 2 (print-marked mutants, with option); 0 (mutants, without option) | — | 0 | booking and refund need no extra caller |
| print-effects `run_checks.py` (attempt-0005, round 1) | 0 / 2 as expected | — | 0 | unchanged |
| **2. Pillar I** | | | | |
| `forge2-pillar1-spec-determinism/run_checks.py`, attempt-0014 | 0 for ten positive files; 4 for three negative controls | — | 0 | 13 cases: three spec determinism lemmas; planted spec (5-account witness, 4-account blindness); two spec pairs with witnesses and false-claim controls. Diagnostics outside the gate |
| W2 (fee change, both accept) | 0 | — | 0 | proved with `{:isolate_assertions}` on W2 only: 61 batches, largest 707,136 of 1,000,000. Five earlier attempts: exit 4 |
| **3. Split-edit** | | | | |
| `forge2-pillar1-anchor-diff/run_control.py`, attempt-0001 | — | 0 for two legitimate cases; 1 for fourteen attack cases | 0 | 0 evasions; no new gate module. Local profile; GitHub wrapper not run |
| **4. Pillar II** | | | | |
| `forge2-pillar2-finality-protocol/run_checks.py` (round 1) | 0 model; 4 for four weakened variants | — | 0 | a MODEL: 22 verified under assumptions A1–A4 |
| `node --import tsx forge2-pillar2-refund-finality/run_suite.ts`, attempts 0001 and 0002 | — | — | 0; 0 | FINITE TEST: 38 of 38 attacks as expected; 0 unauthorized settlements; valid sequence settles; 4 of 4 database-tamper cases detected by audit (not prevented). Ed25519; sink holds only the public key. Nothing proved about the minter or the sink |
| **5. Pillar III** | | | | |
| `benchmark/build_checker.py` | 0 (46 verified, 3.1 s); build 0 | — | 0 | the checker is the only proved part |
| `node --import tsx benchmark/bench.ts`, attempt-0001 | — | — | 0 | FINITE BENCHMARK: 25 solver functions, 46 instances, 2,300 checks (mean 91 µs), 0 accepted overbookings, 0 Dafny runs per solver version. Stage 6 numbers measure a different quantity |
| **6. M1** | | | | |
| tracked executable SHA-256 | — | — | 0 | file identity `b8ed5ec2…7bb8` (checked after the cleanup). Not a rebuild of the executable |
| `m1-rebuild/rebuild.py 5400` | — | — | stopped by the budget (script crashed in its kill path at the deadline; addendum written) | TOOL BUILD only: pins match; Poly/ML exit 0; HOL build exit 0 (685 s); CakeML `basis` exit 0 (3,685 s); `compiler/backend/proofs` killed at the deadline. 147 CakeML theories built |
| replay of the M1 chain; `fs-0001`/`fs-0002` | NOT RUN | — | NOT RUN | BLOCKED by the budget: the CakeML compiler proofs alone need hours. The `fs` step is gated on the replay by the decision. [report](proposals/round2-20261117/m1-rebuild/REPORT.md) |

Not met against the round's conditions: "100% green Stage 0–8" (Stage
6 structural; Stages 4 and 7 environment); a generator for arbitrary
spec pairs; M1 replay within the budget.

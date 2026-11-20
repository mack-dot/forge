# Forge Round 3 plan and status (tracked)

Owner's text, verbatim: [proposals/round3-20261117/OWNER_ROUND3_TEXT.md](../../proposals/round3-20261117/OWNER_ROUND3_TEXT.md)
(pasted 2026-11-17). Previous round: [FORGE_ROUND2_PLAN.md](FORGE_ROUND2_PLAN.md).
Master idea: [FORGE_MASTER_IDEA.md](../../FORGE_MASTER_IDEA.md). This file is
updated after every step with real exits.

## Standing rules

- Stage 12 UNAUTHORIZED. `end_to_end=false`. No profile approval.
- Checker, gate and scenario exits are recorded separately.
- `unsure.md` is append-only; Round 3 entries start at U426.
- Pushes go to the backup branch only. Never `main`, never `--force`.
- `gh` credential: approved for read-only Stage 4 EXIT checks only. Any
  write API call or other credential use is asked first.
- Proposal version 3 is built and measured in a scratch worktree. The
  owner's rule for applying it: ALL Stage 0–10 EXIT cases and the
  PR-gate controls exit 0 together in the scratch worktree. If that
  condition is not met, version 3 is NOT applied and the exact blocker
  is recorded.
- A ratification record must come from the trusted side of the gate,
  never from the candidate. A design that lets a pull request approve
  its own gate change is a defect, not a feature.
- M1: do not clean or rebuild Poly/ML, HOL or CakeML `basis`. Budget
  for the incremental compiler-proof build: 10,800 s.
- Security note (U425): the owner reported a malicious force-push on
  another repository on 2026-11-17. No hosted workflow, release or
  signing action is started from this session.

## Owner decisions (Round 3)

1. One "gate epoch transition" (version 3): print-effect tracking,
   gate ratification records for `gate/` and `toolchain/` changes, a
   fresh Stage 6 experiment with the new gate (old report kept as a
   historical record), renewed Stage 9 and 10 pins. Scratch worktree
   first; apply only when everything is green.
2. M1: input-premise lemma first (approved now); then the incremental
   build with 10,800 s; then replay and the `fs` witness.
3. Docker for Stage 7 approved. Read-only `gh` for Stage 4 approved.
   Push the backup branch before long runs and at the end.

## Status table

Status words: TODO, RUNNING, DONE (exit recorded), BLOCKED (blocker
recorded), PARTIAL. Later owner texts of 2026-11-17: a read-only
security triage (U429); then "the screenshot was external", hold
cleared, order of work: 1 gate (version 3), 2 Pillar II and III, 3 M1.

| # | Step | Status | Exits / record |
| --- | --- | --- | --- |
| P0 | Push the backup branch | DONE | `f4485466..f63042e2` at the start; later pushes at each checkpoint, all exit 0; never `main`, never force |
| S | Read-only security triage of the Mac and the repository | DONE | six checks exit 0; 0 implant indicators; plaintext `~/.git-credentials` reported; U429 |
| T5a | M1 input-premise lemma on the rebuilt `basis` | DONE | hol exit 0, 4.8 s, 13 theorems; U427 |
| T5b | Incremental compiler-proof build, 10,800 s; M1 replay; `fs` joint witness | RUNNING | started 15:10; see final table |
| T1 | Stage 7 Docker restored; 28 of 28 baseline | RUNNING | Docker Desktop was hung since the disk-full event; restarted; images and volume recreated by pinned digests; cases run in a scratch worktree (attempt cap) |
| T2 | Version 3 in scratch worktrees; PR-gate controls; apply only if all green | PARTIAL, NOT APPLIED | PR controls exit 0 (18 cases, 0 evasions); Stages 1–5, 8: 24 cases exit 0; Stage 10 exit 0 on restored records; Stage 9 BLOCKED (hosted signing not approved); U432; [report](../../proposals/forge2-pillar1-print-effects/v3/REPORT-V3.md) |
| T3a | Pillar II: dispatcher check before the effect; raw-database attacks | DONE (finite test) | `run_suite_v2.ts` exit 0 twice; 12 raw-database cases, 0 unauthorized effects; limit D14; U428 |
| T3b | Pillar II: minter decision core proved in Dafny | DONE | `build_core.py` exit 0; 7 verified; two wrong cores exit 4; U428 |
| T3c | Pillar I: shared audit skeleton; W2 cost | DONE | `run_round3.py` exit 0; 39 verified; W2 below 300,000: NOT met (307,402 after a split); U430 |
| T4 | Pillar III + II: booking certificates with signed finality | DONE (finite test) | `run_integrated.ts` exit 0 twice; 1,227 receipts; 0 overbookings; U431 |
| F | Final table; records; push | TODO | |

## Final report table

(filled at the end of the round)

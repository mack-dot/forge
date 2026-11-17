# Forge Round 3 plan and status (tracked)

Owner's text, verbatim: [proposals/round3-20261117/OWNER_ROUND3_TEXT.md](proposals/round3-20261117/OWNER_ROUND3_TEXT.md)
(pasted 2026-11-17). Previous round: [FORGE_ROUND2_PLAN.md](FORGE_ROUND2_PLAN.md).
Master idea: [FORGE_MASTER_IDEA.md](FORGE_MASTER_IDEA.md). This file is
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

| # | Step | Status | Exits / record |
| --- | --- | --- | --- |
| P0 | Push the backup branch (Round 2 commits) | TODO | |
| T5a | M1 input-premise lemma on the rebuilt `basis` | TODO | |
| T5b | Incremental compiler-proof build, 10,800 s; M1 replay; `fs` witness | TODO | |
| T1 | Stage 7 Docker restored; 28 of 28 baseline | TODO | |
| T2 | Version 3 in a scratch worktree; PR-gate controls; apply only if all green | TODO | |
| T3a | Pillar II: dispatcher check before the effect; 4 raw-database attacks | TODO | |
| T3b | Pillar II: minter decision core proved in Dafny | TODO | |
| T3c | Pillar I: shared Dafny audit skeleton; W2 resource experiment | TODO | |
| T4 | Pillar III + II: booking certificates with signed finality | TODO | |
| F | Final table; records; push | TODO | |

## Final report table

(filled at the end of the round)

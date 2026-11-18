# Decision 1, step 1B: the approved diff was applied, measured and REVERTED (U419)

Date: 2026-11-17. `candidate.diff` SHA-256 `5b1fd91d…6436` (approved by
the owner in Round 2). Working tree after this step: no protected file
differs from `HEAD`.

## What happened

1. Baseline at `93712d2c` (28 EXIT cases, `run_stage_exits.py`): Stages
   1, 2, 3, 5, 6, 8 pass (22 cases). Stage 4 fails with HTTP 403 from
   the GitHub API (3 cases). Stage 7 fails because Docker is not
   available (`container=125`; the Docker image store was removed on
   2026-11-17) (3 cases). These six failures exist without any change.
2. `git apply candidate.diff`: the three files got exactly the candidate
   hashes of the proposal. `gate/gate.py` on `impl/Ledger.dfy`: exit 0,
   ACCEPTED. The new evidence differs from the committed one in five
   fields only (option list, obligation list, three trusted-input
   hashes).
3. Real gate on the two planted print bugs (now in `candidate-bugs/`):
   with the change, gate exit 1 for both (`VERIFICATION_REJECTED … Dafny
   exit 2`). With the unchanged gate (scratch worktree at `93712d2c`),
   gate exit 0 for both: ACCEPTED. So the change closes the hole for
   the ledger gate.
4. Regression after the change (28 cases): Stages 1, 2, 3 and Stage 5
   `vacuity` pass. NEW failures:
   - Stage 8, all three cases: the refund gate rejects
     (`APPROVED_DEPENDENCY`): `spec/refund/spec.lock` pins the digest of
     `toolchain/pins.json`.
   - Stage 6 `report`: `REPORT_REJECTED: TRUSTED_INPUTS`: the stored
     benchmark report pins the old trusted input digests.
   - Stage 5 `mutations`: the driver stops on `print_effect` with
     "unexpected verify exit 2". It has no class for a tool rejection.
5. Because the approved diff alone does not give a green Stage 0–8, and
   the fixes need protected files that the approval does not cover, I
   reverted it (`git apply -R`), restored `evidence.json`, and checked
   that the gate output equals the committed evidence again.

## What a complete change needs (NOT applied; needs approval of exact bytes)

| Item | Path | Protected |
| --- | --- | --- |
| the three files of `candidate.diff` | `gate/backends/dafny.py`, `gate/ContractBinding.dfy`, `toolchain/pins.json` | yes |
| new dependency digest | `spec/refund/spec.lock` | yes (approval record) |
| new digest of that lock | `gate/refund.py` (`APPROVED`) | yes |
| booking lock, if it pins the pins file | `spec/booking/spec.lock`, `gate/booking.py` | yes |
| Linux option list | `toolchain/linux-pins.json` | yes |
| planted bugs | `bugs/print_effect.dfy`, `bugs/print_effect_marked.dfy` | no |
| a class for tool-rejected mutants | `scripts/exit_stage_5.py`, `docs/spec-quality.md` | no |
| regenerated records | `evidence.json`, Stage 5 results, Stage 6 benchmark re-run, refund and booking evidence | no |

A complete candidate (version 2) must be built and run in a scratch
copy first, so that its regression result is measured before the owner
approves it. NOT DONE in this step.

Records: `records/regression/baseline-93712d2c.json`,
`records/regression/after-candidate-diff.json` (home directory replaced
by `<HOME>`).

# Version 3: measured results and open points (Round 3, U432)

Date: 2026-11-17. Status: NOT APPLIED. Everything below ran in scratch
git worktrees at `fd8b9608`. The real tree has no protected change.
`end_to_end=false`. Stage 12 unauthorized.

## 1. What version 3 is

| Step | Files | Purpose |
| --- | --- | --- |
| A | `gate/approval.py` (rewritten), `gate/ratification.py` (new), `gate/incremental.py` (four edits), `.github/CODEOWNERS` (one line) | Tier-0 gate ratification in the PR gate |
| B | the six protected files of version 2, `scripts/exit_stage_5.py`, two planted print bugs, regenerated `evidence.json` and Stage 5 records | print-effect tracking |

Exact bytes: `build_v3.py <worktree> ab`. Diff of the nine modified
protected files: `candidate-v3-protected-modified-files.diff`
(300 lines). New protected file: `files/gate/ratification.py`.
`git apply --check` on the real tree: exit 0.

## 2. The ratification rule (step A)

A change of protected files passes the PR gate only if the TRUSTED
base checkout holds a record `governance/gate-ratifications/<id>.json`
that names EVERY changed protected file with its old and its new
SHA-256, and both sets of digests are the real ones. Then:

1. Scope. Each file is under `gate/` or `toolchain/`. One exception: a
   file named `spec.lock` whose new bytes are its old bytes with the
   digests of ratified `toolchain/` files replaced. Nothing else.
2. Binding. The record names a proposal text in the trusted base and
   its SHA-256.
3. Controls. The gate builds a tree from the trusted checkout plus
   exactly the ratified bytes. In that tree the ratified gate must
   reject every planted bug of the trusted base and every control file
   that the record names (with digest), and must accept the trusted
   `impl/Ledger.dfy`.
4. After that the normal check of the candidate's sources runs.

A record in the candidate is never read. Without a matching record the
answer stays `UNAPPROVED_PROTECTED_CHANGE`, exit 1.

**Flow.** Pull request 1 adds the record and the proposal text. It
changes no protected file, so the gate passes; the owner reviews it
(`/governance/` gets a code-owner line). Pull request 2 carries the
exact bytes.

**Bootstrap.** Step A changes the gate, and the present gate has no
ratification path. So step A itself is rejected by the PR gate (exit
1), as every unratified gate change is. It can enter `main` only by
the owner's explicit merge, recorded like ratification 0001. Step B is
the first change that the new path can carry.

## 3. PR-gate controls: `run_pr_controls.py`

Trusted tree: `fd8b9608` plus step A. Gate command: the command of
`gate/pr_check.py`, with `--profile local`. Attempt 0001: 17 cases,
scenario exit 0. Attempt 0002: 18 cases, scenario exit 0, 0 evasions.

| Owner's control | Cases | Gate exit |
| --- | --- | --- |
| (a) unratified `gate/` or `toolchain/` edit | gate code; toolchain pins; all of step B without a record; step B with a record written by the candidate | 1, 1, 1, 1 |
| (b) split edit | ratified step B plus a schema edit; plus a policy edit and a buggy implementation; plus one more line in a ratified file | 1, 1, 1 |
| (c) tampered record | one wrong digest; wrong proposal digest; not tier 0; control outside `bugs/` | 1, 1, 1, 1 |
| (d) ratified step B, exact bytes | controls ran: 4 trusted planted bugs rejected, 2 print bugs rejected, baseline accepted | 0 |
| ratified, but the gate is weaker | resource limit 1 (baseline no longer accepted); audit result ignored (a planted bug would be accepted) | 1, 1 |
| ratified, but out of scope | policy edit; another field of `spec/refund/spec.lock` | 1, 1 |
| other | benign implementation edit (0); ratified step B with a buggy implementation (1) | 0, 1 |

NOT RUN: the wrapper `gate/pr_check.py` itself. It needs a pull-request
event and the Linux toolchain profile. The authorization code does not
depend on the profile.

## 4. Stage EXIT cases with version 3 (same worktree, A and B applied)

| Stage | Cases | Exit |
| --- | --- | --- |
| 1, 2, 3 | 5, 5, 6 | 0 each |
| 4 | 3 (read-only GitHub token from the `gh` login; not printed, not stored) | 0 each |
| 5 | vacuity; mutations | 0; 0 |
| 6 `report` before the fresh run | 1 | 1: `TRUSTED_INPUTS` (the record pins the old gate bytes) |
| 6 `report` after the fresh run | see section 5 | see section 5 |
| 7 | 3 | see section 6 |
| 8 | 3 | 0 each |
| 9 | 6 | NOT RUN: see section 7 |
| 10 `report --run results/stage10/run-0002` | 1 | 0 (a report of the frozen run of 2026-10-30; not a new benchmark) |

Record: `records/exits-in-v3-worktree.json`.

## 5. Stage 6, fresh run with the version 3 gate

PENDING at the time of writing (Round 3). Results: `records/stage6-epoch2.json`
(backup lineage, U433) and section 9 (main's lineage, final commits).

## 6. Stage 7

PENDING at the time of writing (Round 3). Result: section 9.

## 7. Why version 3 is not applied

The owner's rule: apply only when ALL Stage 0–10 EXIT cases and the
PR-gate controls exit 0 together in the scratch worktree. Not met:

1. Stage 9. `gate/provenance/implementation.lock` pins four files that
   step B changes. A renewal needs a new lock, a new controller
   request, and a new signed release from the hosted workflow. That
   writes public Sigstore log entries that cannot be removed. No
   approval for a hosted signing run exists. Also,
   `.toolchain/stage9/controller.json` and the per-case folders
   `results/stage9/<case>/` are not on this machine now, so the Stage 9
   EXIT cannot run here even without any change.
2. Stage 7 and Stage 6: see sections 5 and 6.

## 8. Open points for the owner

1. The controls of the rule use the ledger gate only. The booking and
   refund gates and the Stage 5 mutation suite do not run inside the PR
   gate.
2. A Tier-0 record can cover `gate/approvals/` and `gate/provenance/`.
   Should those two folders be outside Tier-0?
3. The ratified gate bytes run inside the PR job (`pull_request_target`).
   They are the bytes that the owner ratified, but they run with the
   job's rights.
4. Where the fresh Stage 6 records live: in `results/stage6` with the
   old ones moved to `results/stage6-epoch1` (links in old text then
   point to new files), or in a new folder with a small parameter in
   the two Stage 6 scripts.
5. Stage 9: approve a hosted signing run, or keep Stage 9 as a record
   of the old gate bytes.

## 9. Round 4 closeout: results on the final bytes (U437, U438)

Date: 2026-11-18 UTC. All runs are local (macOS, local profile) unless
a row says "hosted". Final commits on `main` at `4143f4b2`: A
`801777ea`, A2 `26410d46`, B `f54e2507`, C not built yet (see the last rows). Nothing is merged.

| Check | Actual exit | Result |
| --- | --- | --- |
| `run_pr_controls.py`, attempt 6 (older local gate, 26 cases) | 0 | 0 evasions; gate exits 3 × 0, 23 × 1 |
| `run_pr_controls_main.py`, attempt 7 (`main`'s gate, trusted `801777ea`, 22 cases) | 0 | 0 evasions; gate exits 2 × 0, 18 × 1, 1 × 2, 1 × 3; ratified reduced step B VERIFIED, replay byte-identical |
| attempts 5 (both gates) and attempt 6 (`main`'s gate) | 1, 1, Python error | my defects: forced `PYTHONNOUSERSITE`; harness links. No acceptance. Fixed (U437) |
| real gate, A2 against present `main` | 1 | REJECTED, three gate files |
| real gate, unchanged candidate after the bootstrap | 0 | VERIFIED; replay byte-identical |
| real gate, B after the bootstrap | 3 | UNSUPPORTED; record 0001 matched; 8 of 8 floor controls as expected |
| hosted `gate/pr_check.py`, pull request 39 (run 44213967396) | 1 | REJECTED, equal to the local result; job `report` success |
| Stage EXIT cases 1, 2, 3, 4, 5, 8 at A2 (24 cases) | 0 each | passed |
| Stage 6 `report` at unchanged `main` and at A2 | 1; 1 | `TRUSTED_INPUTS`; not caused by step A |
| fresh Stage 6 run at `main`'s tree (`stage6_epoch2.py`): benchmark; controls; identity check; report EXIT twice | 0; 0; 0; 0, 0 | 75 pairs; 450 files; report byte-identical; solver resource counts equal the earlier run; local records commit `0b3fb727` |
| Stage 6 `report` in a clean clone at `0b3fb727`; at A2 plus `0b3fb727` | 0; 0 | the red record on `main` is repaired by these records, before and after action 1 |
| `exit_stage_11.py`, three cases at `4143f4b2`: with the records from the verified backup; clean checkout | 0, 0, 0; 1, 1, 1 | the evaluation records are not on `main` |
| `check_links.py origin/main FORGE_MASTER_IDEA.md` | 1 | 10 of 13 relative links have no target on `main` |
| `check_frozen_pr_gate.py 26410d46`; `... origin/main` | 0; 1 | the eight modules equal the recorded digests at A2; not yet on `main` |
| step B `f54e2507`: `gate/gate.py --impl impl/Ledger.dfy` | 0 | ACCEPTED |
| step B `f54e2507`: stage EXIT cases, fresh Stage 6 run, commit C | NOT RUN | stopped: the Mac was on battery power (U438) |
| Stage 7 (scratch worktree, Docker): `own-proof` | 0 | attempt 2, 2,285 s |
| Stage 7: `upstream-replay`; `invalid-proof` | NOT FINISHED; NOT RUN | replay attempt 4 was running when this section was written; the Mac slept about two hours during it |
| M1 build window `rebuild.py 10800` | stopped by budget | 45 of 71 compiler-proof theories built; the proof build was killed at the deadline; no M1 replay possible yet |
| Stage 9, six EXIT cases | NOT RUN | deferred; after action 1 two lock entries are stale |

Third independent review (`REVIEW-3.md`): 0 fail-opens; 0 HIGH or
MEDIUM accidental defects; F1 MEDIUM (needs an owner-written record):
four more modules load in the PR-gate process and stay ratifiable; F2
to F5 LOW. By the owner's stop rule no gate byte changed after it.

NOT RUN: the hosted wrapper with a record on the trusted side (possible
only after action 1); every local check on Linux; the six Stage 9 EXIT
cases (deferred). Section 8, point 2 is answered: `gate/approvals/` and
`gate/provenance/` are outside Tier-0 in the final bytes.

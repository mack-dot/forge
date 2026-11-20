# Review fix PR-2: a CI job for the airlock engine and the SDKs (macOS arm64)

Status: 2026-11-20. Entries U884 to U886 in [`unsure.md`](../../unsure.md). Branch `ci/airlock-macos` from `main`
`33055a59`. Pull request 71. NOT merged by the agent. It waits for the owner's squash-merge.

This is a FINITE TEST in CI. It proves nothing about the engine, the helpers or the SDKs. `end_to_end=false`.
M1-B stays OPEN. The job is not part of the proof gate and it gives no gate evidence.

The one fresh review of head `b98a06cf` and the repairs: [REVIEW.md](REVIEW.md). Saved outputs:
[local-dry-run.txt](local-dry-run.txt) and [checks.txt](checks.txt).

## The review finding

The review (verdict 3, section "Developer experience", recommendation 2) says: no workflow builds or tests
`src/airlock`, `sdk/` or `src/silicon_sink`. A grep for airlock, rustc and silicon in `.github/workflows` gives zero
hits.

Check on `33055a59`: `grep -n -i -E "airlock|rustc|silicon" .github/workflows/*` gave exit 1 (no match) over the 12
workflow files. The finding is CONFIRMED.

## What the new workflow does

One file: [`.github/workflows/airlock-ci.yml`](../../.github/workflows/airlock-ci.yml). One job `airlock` on
`macos-15` (an arm64 label; the hosted log says `Image: macos-15-arm64`). No existing workflow uses macOS; they use
`ubuntu-22.04` and `ubuntu-24.04`.

1. Checkout with `persist-credentials: false` (the pinned `actions/checkout` SHA of the existing workflows, v4.2.2).
2. A toolchain report. It fails unless the machine is Darwin arm64. It takes the highest Node 24.x of the image tool
   cache (`sort -V`), else a `node` 24.x on PATH, else it fails. It installs nothing.
3. A case selector and a count check (a short Python file written into `$RUNNER_TEMP`). The selector loads the
   `CASES` list of a suite, prints every case as RUN or SKIP, writes the RUN names, and gives `--case NAME` for every
   case that is not on the skip list. It fails if a skip name is not a case of the suite, or if no case is left (an
   empty `--case` list would run every case). After each suite (output through `tee`, under `set -o pipefail`), the
   check fails unless the PASS lines name exactly the RUN set and the RUN count is at least `MIN_RUN_*` (engine 24,
   node helpers 74, SDK 17, diff-policy 6: the counts of this commit).
4. `python3 -I -B bin/forge-airlock build`: two `rustc` builds (production and `kill_points`) and the 0700 copy of the
   TRACKED CakeML refund binary (`proposals/forge2-m1-conformance/artifacts/refund-arm64-macho`, SHA-256 pinned). No
   CakeML toolchain is needed.
5. `tests/airlock/test_engine.py`, `test_node_helpers.py`, `test_sdk.py` (Python SDK, and the TypeScript SDK through
   the built-in type stripping of Node 24; no npm, no `node_modules`), `test_diff_policy.py`, each with its selection.

Rules kept: `permissions: contents: read`; no secrets; no `pull_request_target`; no cache; `timeout-minutes: 10`;
`concurrency` with `cancel-in-progress` for pull requests only (a run on `main` is not cancelled); no new action (only the `actions/checkout` SHA that the existing workflows already pin); no
test file changed.

Triggers (cost): `pull_request` to `main` and `push` to `main`, both limited by `paths:` to `src/airlock/**`,
`sdk/**`, `bin/forge-airlock`, `tests/airlock/**` and the workflow file. No schedule, no matrix, one job. A stacked
pull request to another base (for example one on `apex1/native-cosign`) does not start the job.

Threat model of the job: a `pull_request` run uses the PR's own copy of the workflow, so the cost limits are advisory
for a branch of this repository. The PR code runs on an ephemeral VM with network access; it can read the checkout
and write `$GITHUB_ENV` and `$GITHUB_PATH` for later steps. It gets no secret, and the token is not persisted
(`persist-credentials: false`; `permissions: contents: read`).

## What is skipped, and why

The hosted image has no Dafny, and this workflow installs nothing from the network. So every case that needs the
Dafny-compiled booking checker `build/airlock/checker/model.cjs` (made by `forge-airlock build --checker`: pinned
Dafny 4.11 and `node_modules`) is skipped, and so is every diff-policy case that starts Dafny.

| Suite | Cases | Run | Skipped | Skipped names | Reason |
| --- | --- | --- | --- | --- | --- |
| `test_engine.py` | 26 | 24 | 2 | `inventory`, `pin` | need `model.cjs` |
| `test_node_helpers.py` | 137 | 74 | 63 | the 63 names in `SKIP_NODE_HELPERS` of the workflow (every `booking_*` case that loads the default model) | need `model.cjs` |
| `test_sdk.py` | 19 | 17 | 2 | `py_saga_inventory`, `ts_typed` | need `model.cjs` |
| `test_diff_policy.py` | 11 | 6 | 5 | `demo`, `choice`, `fault`, `refused`, `identical` | the first four start Dafny; `identical` without Dafny compares two equal failure outputs (0 bytes, exit 1) and passes without checking anything |

Total: 72 skipped, 121 run. The 63 node-helper names are the cases that a local run without the model reported as
`NOT RUN` ("model file missing"; 74 PASS, 0 FAIL, 63 NOT RUN, exit 1). The skip lists come from local runs in a
worktree with no `build/`, no `.toolchain/` and no `node_modules`.

Coverage that the skips lose (each case checks the model before its other steps, so the whole case is lost):
- `ts_typed`: the only TypeScript case for 14 expected typed verdicts and one unknown-key refusal. Only its last
  step `book` needs the model.
- `py_saga_inventory`: its saga half (a commit `IN_FLIGHT`, a refused failover) needs no model.
- engine `inventory`: its `OPEN_INVENTORY` lines and the refusals before the first booking need no model.
To keep those parts in CI, the cases must be split. That is a later change to the test files. It is not done here,
because the test files collide with `apex1/native-cosign`.

A test weakness seen here, not changed: `booking_model_substituted_always_true` passes on any exit 2 with a
`booking_check: ` message; it does not need the pin reason.

Also not covered: `src/silicon_sink` (the review names it; this job does not build it), `scripts/exit_goal20_sdk.py`
(it needs Dafny and runs mutations), the demo and the fuzz pass, and Linux (the review asks for Linux too; the refund
binary is Mach-O arm64, so a Linux job can run only a smaller subset; deferred).

## Runs

Local dry runs (2026-11-20, this machine, macOS arm64, worktree with no build products): the seven `run:` scripts
were taken from the workflow with Ruby YAML and run in order. Local difference: `race` was also skipped (a 50-process
case is a heavy step and the heavy lock was held by another team), so the local engine minimum was 23. First bytes
(`d4fe0580…`): all seven exit 0 (engine 23, node helpers 74, SDK 17, diff-policy 6 PASS). Repaired bytes
(`b190ba53…`): all seven exit 0, the four count checks pass, and six negative controls fail as they must. Output:
[local-dry-run.txt](local-dry-run.txt). Local tools: rustc 1.92.0, Python 3.10.11, Node v24.3.0.

Hosted runs on pull request 71:

| Run | Workflow | Commit | Conclusion | Notes |
| --- | --- | --- | --- | --- |
| [44692795822](https://github.com/mack-dot/forge/actions/runs/44692795822) | airlock-ci | `0846e403` | success | job `airlock` 1m23s (07:08:45Z to 07:10:08Z); engine 24 PASS, node helpers 74 PASS, SDK 17 PASS, diff-policy 6 PASS, 0 FAIL |
| [44692795915](https://github.com/mack-dot/forge/actions/runs/44692795915) | Forge proof gate | `0846e403` | failure | `UNAPPROVED_PROTECTED_CHANGE: .github/workflows/airlock-ci.yml`, as expected |
| [44693275108](https://github.com/mack-dot/forge/actions/runs/44693275108) | airlock-ci | `b98a06cf` | success | job 1m20s (07:12:40Z to 07:14:00Z); same counts |
| [44693272518](https://github.com/mack-dot/forge/actions/runs/44693272518) | Forge proof gate | `b98a06cf` | failure | as expected |

The repair push (one commit set) starts both again. Its results are in the pull request and in the hand-back, not
here.

Hosted tools (from the logs; the image is NOT monotonic, run 2 used an older image than run 1):

| Run | Image version | macOS | rustc | Python | Tool cache Node | Selected Node |
| --- | --- | --- | --- | --- | --- | --- |
| 44692795822 | 20261118.0550.1 | 15.8.2 | 1.100.0 | 3.15.2 | 22.23.5, 24.22.3 | v24.22.3 |
| 44693275108 | 20261104.0514.1 | 15.8.2 | 1.99.1 | 3.15.2 | 22.23.4, 24.22.2 | v24.22.2 |

None of these equal the repository pins (rustc 1.92, Node 24.3.0); the job uses what the image has.

## Exact bytes for approval

```text
b190ba53a3e97254786fbad1315ef462be0322371c7efe3c2477c25bf9f5e946  .github/workflows/airlock-ci.yml
```

The first bytes (`d4fe0580d0c8f273fde92745aefbd72ee26d47d1c235b7b4df45eacf53ebf770`, commit `0846e403`) are replaced
by the repair; do not approve them.

## After `apex1/native-cosign` merges

That branch (local only, head `e3322303`; read with `git show`, not checked out) changes the suites. Then:

- `bin/forge-airlock build` writes the kill-points engine to `build/silicon/test/airlock-engine-kill`, not
  `build/airlock/`. The second argument of `test_engine.py` in the workflow MUST change to that path, or the engine
  suite stops with exit 2. `test_sdk.py` gets `--kill-engine` with that default, so its line can stay.
- Add a `test_cosign.py` step IN THE SAME CHANGE: `python3 -I -B tests/airlock/test_cosign.py
  build/airlock/airlock-engine`, with its own count check and minimum. Without it the cosign key-file and sign cases
  have no CI at all (they move out of `test_node_helpers.py`). It uses `/usr/bin/ssh-keygen`; this job did not check
  that tool on the image.
- `test_node_helpers.py` then has 68 cases. All 63 skip names are still cases there (checked against
  `git show e3322303:tests/airlock/test_node_helpers.py`), so 5 cases run: `booking_missing_model_file`,
  `booking_model_throws`, `booking_model_substituted_always_true`, `booking_model_directory_refused`,
  `booking_no_args`. All five are exit-2 error paths, so that step is then nearly vacuous. `MIN_RUN_NODE_HELPERS`
  must change from 74 to 5 in the same change, or the count check fails the job (this is intended).
- `MIN_RUN_ENGINE` and `MIN_RUN_SDK` can then rise: `cosign_faults` (engine), `py_no_node` and
  `py_build_separation` (SDK) run by default. `py_build_separation` runs `bin/forge-airlock build` again: two more
  `rustc` builds in the job. Not run here.
- The new file `src/airlock/py/cosign_tool.py` is inside `src/airlock/**`; no `paths:` change is needed.

## Weak points

- The toolchains float with the image. rustc 1.100.0 and Node 24.22.3 are not the pinned versions. A pass here says
  nothing about rustc 1.92 or Node 24.3.0, and a new image can change the result without a repository change.
- 72 cases do not run. The Dafny-compiled booking checker and the diff-policy clearing have no CI. The lost
  non-Dafny parts are listed above.
- `MIN_RUN_*` are constants of this commit. A change that removes cases must lower them in the same change.
- The `paths:` filter leaves out files that the suites read: `examples/unbreakable_store/ts_part.ts`,
  `tests/m1-conformance/recorded-m1-cases.json` and the tracked refund binary. A change to those alone does not
  start the job.
- The selector imports each test file to read `CASES`, so the top-level code of a test file runs once more.
- The job is not a required check. Only the owner's branch rules can make it one.
- `actions/checkout` v4.2.2 gives a warning: it targets Node 20 and runs on Node 24.

## Update after pull requests 72 and 73 merged (`main` = `7e5842d0`)

The owner asked for this update. The branch merges `main` `7e5842d0` (records only), then changes the workflow.
The bytes `b190ba53…e946` are replaced: do not approve them.

```text
b10831fe97ca4c546ca74aafc1b0d5ef84ff3aaa24d9e3453cd74a0227aeade8  .github/workflows/airlock-ci.yml
```

What changed in the workflow:

- The engine suite gets the kill-points build at `build/silicon/test/airlock-engine-kill` (its new place).
- A new step runs `tests/airlock/test_cosign.py` with the built engine and the `/usr/bin/ssh-keygen` of the image.
- `pin_window` joins the engine skips: it needs `build/airlock/checker/model.cjs` (no Dafny on the image).
- New `TOTAL_*` values: the selector fails if a suite file has fewer cases than at this commit.
- New `MIN_RUN_*` values. Nothing in the workflow named the deleted `cosign.cjs`.

Case counts of the suite files on this head, each from one local run of the file (macOS arm64, Node 24.3.0, a
worktree with a fresh engine build and NO checker model; one suite at a time; no heavy lock):

| Suite | Cases in the file | Run without the model | Local result of that run |
| --- | --- | --- | --- |
| `test_engine.py` | 33 | 30 (skips: `inventory`, `pin`, `pin_window`) | 29 PASS; the 3 skips answered NOT RUN (model missing); `race` (50 processes) was NOT RUN locally |
| `test_cosign.py` | 56 | 56 | 56 PASS, exit 0 |
| `test_node_helpers.py` | 68 | 5 | 5 PASS; 63 NOT RUN (model missing); the 63 names equal `SKIP_NODE_HELPERS` |
| `test_sdk.py` | 21 | 19 (skips: `py_saga_inventory`, `ts_typed`) | 19 PASS; the 2 skips answered NOT RUN (model missing) |
| `test_diff_policy.py` | 11 | 6 | 6 PASS, exit 0 (file unchanged since `33055a59`) |

So `TOTAL_*` = 33, 56, 68, 21, 11 and `MIN_RUN_*` = 30, 56, 5, 19, 6. The full counts (33, 56, 68, 21) cannot be
the run minimums on the hosted image: 68 cases need the Dafny-built model. The node helper step now runs 5
error-path cases only; it checks little. The count checks ran locally on the saved outputs (exit 0 each), with
three negative controls (a higher total, a higher minimum, an unknown skip name: exit 1 each).

The hosted run of these bytes is in the pull request; it is not recorded in this file (one push, one run).
`cosign_faults` and `race` have no local result under the workflow's exact conditions; the hosted run decides.

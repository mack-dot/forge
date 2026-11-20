# Review fix PR-2: a CI job for the airlock engine and the SDKs (macOS arm64)

Status: 2026-11-20. Entries U884 and U885 in [`unsure.md`](../../unsure.md). Branch `ci/airlock-macos` from `main`
`33055a59`. Pull request 71. NOT merged by the agent. It waits for the owner's squash-merge.

This is a FINITE TEST in CI. It proves nothing about the engine, the helpers or the SDKs. `end_to_end=false`.
M1-B stays OPEN. The job is not part of the proof gate and it gives no gate evidence.

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
2. A toolchain report. It fails unless the machine is Darwin arm64. It takes Node 24.x from the image tool cache
   (`$RUNNER_TOOL_CACHE/node/24.*/arm64/bin/node`), else a `node` 24.x on PATH, else it fails. It installs nothing.
3. A case selector (a short Python file written into `$RUNNER_TEMP`). It loads the `CASES` list of a suite, prints
   every case as RUN or SKIP, and gives `--case NAME` for every case that is not on the skip list. It fails if a skip
   name is not a case of the suite, or if no case is left (an empty `--case` list would run every case).
4. `python3 -I -B bin/forge-airlock build`: two `rustc` builds (production and `kill_points`) and the 0700 copy of the
   TRACKED CakeML refund binary (`proposals/forge2-m1-conformance/artifacts/refund-arm64-macho`, SHA-256 pinned). No
   CakeML toolchain is needed.
5. `tests/airlock/test_engine.py`, `test_node_helpers.py`, `test_sdk.py` (Python SDK, and the TypeScript SDK through
   the built-in type stripping of Node 24; no npm, no `node_modules`), `test_diff_policy.py`, each with its selection.

Rules kept: `permissions: contents: read`; no secrets; no `pull_request_target`; no cache; `timeout-minutes: 30`;
`concurrency` with `cancel-in-progress`; no new action (only the `actions/checkout` SHA that the existing workflows already pin); no
test file changed.

Triggers (cost): `pull_request`, and `push` to `main` only, both limited by `paths:` to `src/airlock/**`, `sdk/**`,
`bin/forge-airlock`, `tests/airlock/**` and the workflow file. No schedule, no matrix, one job.

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

Also not covered: `src/silicon_sink` (the review names it; this job does not build it), `scripts/exit_goal20_sdk.py`
(it needs Dafny and runs mutations), the demo and the fuzz pass, and Linux (the review asks for Linux too; the refund
binary is Mach-O arm64, so a Linux job can run only a smaller subset; deferred).

## Runs

Local dry run (2026-11-20, this machine, macOS arm64, worktree with no build products): the seven `run:` scripts were
taken from the workflow with Ruby YAML and run in order. Local difference: `race` was also skipped (a 50-process
case is a heavy step and the heavy lock was held by another team). Exits: toolchain 0, selector 0, build 0, engine 0
(23 PASS), node helpers 0 (74 PASS), SDK 0 (17 PASS), diff-policy 0 (6 PASS). Local tools: rustc 1.92.0, Python
3.10.11, Node v24.3.0. After the dry run only the triggers, the comments and the quoting of the `on` key changed; the
seven `run:` scripts are byte-identical (`cmp`).

Hosted runs on pull request 71:

| Run | Workflow | Commit | Conclusion | Notes |
| --- | --- | --- | --- | --- |
| [44692795822](https://github.com/mack-dot/forge/actions/runs/44692795822) | airlock-ci | `0846e403` | success | job `airlock` 1m23s (07:08:45Z to 07:10:08Z); engine 24 PASS, node helpers 74 PASS, SDK 17 PASS, diff-policy 6 PASS, 0 FAIL |
| [44692795915](https://github.com/mack-dot/forge/actions/runs/44692795915) | Forge proof gate | `0846e403` | failure | `UNAPPROVED_PROTECTED_CHANGE: .github/workflows/airlock-ci.yml`, as expected |

The commit that adds these records starts airlock-ci once more (a `pull_request` run checks the paths of the whole
pull request). Its result is in the pull request, not here.

Hosted tools in run 44692795822: image `macos-15-arm64` version 20261118.0550.1, macOS 15.8.2, rustc 1.100.0,
Python 3.15.2, Apple clang 17.0.0, tool cache Node 22.23.5 and 24.22.3 (default `node` v22.23.5), selected Node
v24.22.3. None of these equal the repository pins (rustc 1.92, Node 24.3.0); the job uses what the image has.

## Exact bytes for approval

```text
d4fe0580d0c8f273fde92745aefbd72ee26d47d1c235b7b4df45eacf53ebf770  .github/workflows/airlock-ci.yml
```

## After `apex1/native-cosign` merges

That branch (local only, head `e3322303`; read with `git show`, not checked out) changes the suites. Then:

- `bin/forge-airlock build` writes the kill-points engine to `build/silicon/test/airlock-engine-kill`, not
  `build/airlock/`. The second argument of `test_engine.py` in the workflow MUST change to that path, or the engine
  suite stops with exit 2. `test_sdk.py` gets `--kill-engine` with that default, so its line can stay.
- Add one step: `python3 -I -B tests/airlock/test_cosign.py build/airlock/airlock-engine` (the new suite; it uses
  `/usr/bin/ssh-keygen`, which is on the image but was not checked by this job).
- `test_node_helpers.py` then has 68 cases (the cosign cases move out). All 63 skip names are still cases there
  (checked against `git show e3322303:tests/airlock/test_node_helpers.py`), so 5 cases run. No change needed.
- New cases `cosign_faults` (engine), `py_no_node` and `py_build_separation` (SDK) run by default. Not run here.
- The new file `src/airlock/py/cosign_tool.py` is inside `src/airlock/**`; no `paths:` change is needed.

## Weak points

- The toolchains float with the image. rustc 1.100.0 and Node 24.22.3 are not the pinned versions. A pass here says
  nothing about rustc 1.92 or Node 24.3.0, and a new image can change the result without a repository change.
- 72 cases do not run. The Dafny-compiled booking checker and the diff-policy clearing have no CI.
- The `paths:` filter leaves out files that the suites read: `examples/unbreakable_store/ts_part.ts`,
  `tests/m1-conformance/recorded-m1-cases.json` and the tracked refund binary. A change to those alone does not
  start the job.
- The selector imports each test file to read `CASES`, so the top-level code of a test file runs once more.
- The job is not a required check. Only the owner's branch rules can make it one.
- `actions/checkout` v4.2.2 gives a warning: it targets Node 20 and runs on Node 24.

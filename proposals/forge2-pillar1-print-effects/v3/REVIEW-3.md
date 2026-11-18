# Review 3: step A, V2 to V3 diff (commit 801777ea, parent 4143f4b2)

Record note (not part of the review): this is the final report of the
third independent review, by a fresh agent, 33 tool calls, 2026-11-18
UTC. The text below is the reviewer's text. Two changes only: the home
folder is written `<HOME>` and the reviewer's scratch folder is written
`<R3>`. The reviewer's scripts and logs are in `records/review-3/`
(`f1/demo.py` is saved as `f1-demo.py`). The reviewer could not write
its own report file; this copy was saved by the coordinating agent.
Stop rule of the owner: 0 fail-opens and 0 HIGH or MEDIUM accidental
defects end Round 4. No gate byte was changed after this review.

---

Host: macOS arm64, APFS (ignores letter case), Python 3.10.11, local profile.
`<R3>` = the reviewer's scratch folder.

## Result in short

- Fail-opens found: **0**.
- HIGH or MEDIUM accidental defects found: **0**.
- One MEDIUM finding (F1) is not accidental: it needs an owner-written record. It answers "is the list of eight modules complete?". The answer is no.
- Limits: nothing ran on Linux or on a file system that keeps letter case apart. I made no run that ends with exit 0. `gate/pr_check.py` and the replay step did not run.

## 1. Findings

| ID | Severity | Class | Status | File:line at 801777ea | Accident or intent |
| --- | --- | --- | --- | --- | --- |
| F1 | MEDIUM | bypass (scope list incomplete) | Facts CONFIRMED at unit level. Exit 0 NOT reproduced by me. | `gate/approval.py:23-24`, `:29-32`; `gate/incremental.py:34`, `:35`, `:45`, `:230`; `gate/post_pr_report.py:11` | Needs an owner-written record. Not accidental by itself. |
| F2 | LOW | other (wrong exit class) | CONFIRMED by a gate run, with the time limit patched from 1800 s to 3 s | `gate/ratification.py:106`, `:127`; `gate/incremental.py:427`, `:439` | Accident class (slow or hung checker) |
| F3 | LOW | bypass (shadow names) | CONFIRMED by a gate run: exit 3 | `gate/approval.py:29-32` | Needs intent and an owner-written record |
| F4 | LOW | path-normalization | Facts CONFIRMED at unit level. No gate run. | `gate/approval.py:30` | Needs intent |
| F5 | LOW | path-normalization (mixed file systems) | PLAUSIBLE. The Linux part is reasoned only. | `gate/incremental.py:38`, `:59-74` | Needs intent and an owner merge |

### F1. Four modules of the PR-gate process are still inside Tier-0

- Measured, `python3 -B <R3>/unit1.py`: after `import incremental`, these files load from `gate/` in the trusted process and `_ratifiable` returns True for each: `gate/core.py`, `gate/dependencies.py`, `gate/backends/__init__.py`, `gate/backends/dafny.py`. All four are obligation inputs, so the coverage rule does not stop them.
- Measured, `python3 -B <R3>/f1/demo.py base` and `... demo.py f1`: in a scratch copy with `REQUIRED_RESULTS = set()` in `gate/backends/dafny.py`, `incremental.OBLIGATIONS` falls from 12 to 4 members and `trace_coverage` accepts a trace without `Ledger.Apply (correctness)`. The trusted bytes reject that trace (PROOF_COVERAGE). So a decision constant of the PR gate lives in a ratifiable file.
- Read, not run by me: the author's log `results/round3-pr-controls-main-20261117/attempt-0007/case-06.log` ends with VERIFIED for a change set that includes `gate/backends/dafny.py`. I did not verify which trusted commit that attempt used.
- Not measured: whether the floor controls pass with the emptied constant. I expect yes, but I did not run it.
- Same class, read only: `gate/post_pr_report.py:11` imports `backends.dafny` in the job that holds `GH_TOKEN` (`.github/workflows/proof-gate.yml:84-85`). `toolchain/install_ci.py` runs in the verify job (`proof-gate.yml:44`), is ratifiable, and no control runs it.
- Scenario: the owner ratifies a change of one of the four files. The floor controls exercise only the `gate.py` paths. After the merge the changed bytes run inside the PR gate. The module text "the changed PR gate itself never runs: its modules are outside Tier-0" is false for these four files.

### F2. A control that reaches the time limit ends with exit 1 and no receipt

- Command, run from `<R3>/tT` (trusted clone of 801777ea plus a scratch record; candidate `<R3>/tC` has a `gate.py` that never answers):
  `python3 -B -c "import os, sys, runpy; sys.path.insert(0, os.path.abspath('gate')); import ratification; ratification.TIMEOUT_SECONDS = 3; sys.argv = ['gate/incremental.py', '--profile', 'local', '--candidate', '<R3>/tC', '--evidence', 'build/r3-timeout-evidence.json', '--work', 'build/r3-timeout']; runpy.run_path('gate/incremental.py', run_name='__main__')"`
- Real exit code: **1**. Last line: `subprocess.TimeoutExpired: ... timed out after 3 seconds`. No `operation.json`. No evidence file. Log: `<R3>/timeout-run.log`.
- Cause, measured: `subprocess.TimeoutExpired` is not a subclass of any exception that `main()` catches.
- Wrong result: a tool error must be exit 2 (NOT_ESTABLISHED). The gate gives exit 1 (the REJECTED class) and writes no receipt. It is NOT an acceptance.
- Reasoned only: on the hosted path `gate/pr_check.py` then fails on the missing `operation.json` and ends with exit 2 without a report. `subprocess.run` kills only the direct child; Dafny and Z3 processes of that child can stay alive.
- Limit of this test: the shipped value is 1800 s. I changed only that number, in memory.

### F3. A ratifiable file can take the place of an excluded module

- Command, run from `<R3>/sT` (trusted clone plus a scratch record that names the ADDED file `gate/common/__init__.py`; candidate `<R3>/sC` adds it):
  `python3 gate/incremental.py --profile local --candidate <R3>/sC --evidence build/r3-shadow-evidence.json --work build/r3-shadow`
- Real exit code: **3** (UNSUPPORTED), 101 s. Last line: `UNCOVERED_CHANGE gate/common/__init__.py`. No evidence file. Log: `<R3>/shadow-run.log`.
- Measured in the same run: the scope test did NOT reject the file. All 5 controls and the function probe passed. A mark file shows 6 imports of the package as `common` (5 controls and the probe). So the excluded `gate/common.py` was not the module in use.
- The stop came from main's coverage rule, not from the Tier-0 scope rule.
- Unit level (`unit1.py`, `unit2.py` rows 15): `gate/approval/__init__.py`, `gate/common.so` and `gate/json.py` also pass the scope test. A toy run shows that a package folder wins over a module file and that `json.py` in the script folder wins over the standard library. The `.so` case is reasoned only.
- Not tested: the backup-lineage gate. Entry U433 says that lineage has no `coverage.py`. Without that rule I do not know that this case stops at exit 3.

### F4. `lower()` is not the file system's letter-case rule

- Measured on this APFS volume: `obligationſ.py`, `ratiﬁcation.py` and `poﬆ_pr_report.py` name the same file as `obligations.py`, `ratification.py` and `post_pr_report.py`. `_ratifiable` returns True for the three odd names. `casefold()` gives the plain name; `lower()` does not.
- Unit level: `authorize` returned a ratification for a record that names the added file `gate/obligationſ.py`.
- No path to exit 0 found. Reasoned only: a new name is an uncovered change (exit 3, as in F3), and a checkout that maps two tracked names to one file is not clean (REVISION_ERROR, exit 2).

### F5. The protected folder name is exact on Linux

- Measured here: a candidate folder `GOVERNANCE/` is seen as `governance/` and the gate logic rejects it (exit 1 at unit level, `unit3.py` case n).
- Reasoned only, Linux: `GOVERNANCE/gate-ratifications/x.json` is not a protected path and the Linux gate does not read it. The result would be exit 3 from the coverage rule, not exit 1. If the owner merged it, a macOS checkout would read it as a record. Change (3) says such a pull request "is rejected"; on Linux that holds only for the exact spelling.

## 2. The two numbers

- Fail-opens found: **0**.
- HIGH or MEDIUM accidental defects found: **0**. (F1 is MEDIUM and needs an owner-written record.)

## 3. What held, and what I did not check

Held:
- Record path, unit level (`unit3.py`, 17 cases): a record only in the candidate, a removed record, an edited record, a record alone, any other file under `governance/`, `governance` as a file, link variants. All exit 1.
- Record location, unit level: subfolder, `.JSON` suffix, wrong folder. Not read. Exit 1.
- The eight modules and their letter-case variants: RATIFICATION_SCOPE, exit 1, unit level.
- About 60 malformed-record cases (`unit2.py`): none authorized. Invalid JSON gives exit 2. No uncaught exception.
- Digest binding, unit level: record keys with `./`, `//`, a trailing slash, `..` or other letter case never match. A wrong, uppercase or null digest gives exit 1.
- Environment allow-list, measured in a real control process: the ratified `gate.py` saw `HOME`, `LANG`, `PATH`, `TMPDIR` (and `__CF_USER_TEXT_ENCODING`, which macOS adds). Two marker variables of the caller did not reach it.
- The time limit does not become an acceptance (F2).

Not checked:
- Linux, the hosted runner, `gate/pr_check.py`, `gate/post_pr_report.py`, the replay step.
- A run of my own that ends with exit 0.
- `PYTHONNOUSERSITE` when the caller sets it. My run with it set ended with exit 2 in the TRUSTED process (`TOOLCHAIN_ERROR: attrs version differs from pin`; `attrs` is in the user site on this host) before any control. Only the unset side is measured: the control saw no such variable.
- The `spec.lock` re-bind (unchanged from V2).
- The backup-lineage gate.
- Changes of files during a run, links inside `impl/` of the trusted tree, file names that are not UTF-8.
- A letter-case rename of a ratified file. I expect the control tree loses the file and the gate ends with exit 2; not run.

Notes on my own tests:
- Three flags in the first table (`unit2.py`) were errors in my expectations, not gate defects: `tier: -0` is the integer 0; `gate/Approvals2/` is another folder name; rows 19 and 20 were built wrong and I repeated them as `unit3.py` cases c and d (both exit 1).
- One order effect on the trusted side: a directory named `x.json` in the record folder is rejected only if the loop reaches it before a matching record (`unit3.py` case m).
- Gate runs of mine: 3, one at a time (two short time-limit runs, one 101 s shadow run). No process of mine is left.
- All scratch files are under `<R3>` (clones `base`, `tT`, `tC`, `sT`, `sC`; scripts `unit1.py`, `unit2.py`, `unit3.py`, `f1/demo.py`; logs `timeout-run.log`, `timeout-run2.log`, `shadow-run.log`). `<HOME>/forge` is unchanged: HEAD 042eedff, the same 12 modified tracked files as at the start.

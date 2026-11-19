# Night shift 2026-11-19: the consolidated record (integrator)

CURRENT none. Stage 9 deferred. Stage 12 unauthorized. M1-B OPEN.
`end_to_end=false`. Nothing here is merged, signed, deployed or applied
by the integrator. The owner reviews and merges.

This folder joins the final records of three orchestrators: A (proof,
HOL), B (hardening, Dafny), C (red team). The integrator READ their
records, copied verified content by path, and ran the checks of
section 7. A worker report is not a result: where the integrator did
not run a thing itself, the row says whose run it is.

Classes: MACHINE-CHECKED (MC), ASSUMPTION, TESTED-UNPROVED (TU),
MISSING. Exit codes are ACTUAL. A command that did not run is NOT RUN.

## 1. What this pull request holds, and what it does NOT change

| Part | Path | Status |
| --- | --- | --- |
| A's records after pull request 59 (HOL cases, reproduction, launch-path prototype, final record) | `../orch-A/`, `../hol-runs/` | records; model-level MC results |
| Nine Dafny model files | `impl/finality-core/` (new folder; in no recorded bundle; not a protected path) | MC at source level (model); integrator re-run exit 0 |
| B's curated evidence: the sources, commands and logs of 47 recorded verify runs; reports; B's unapplied diffs | `../orch-B/` (1,125 files of 11,869) | records |
| C's final record, attack log, scripts and logs of the re-tests | `../orch-C/` (210 files of 1,909) | records |
| The hardening (sink, minter, dispatcher, provider adapter, regressions, changed suite) | `../unapplied/` as two UNAPPLIED diffs | TU; NOT applied (owner items B-15, B-16) |
| Refresh of the 45-link graph | `../../m1b-mission-20261119/TOP_LEVEL_GRAPH_REFRESH_20261119.md` | a join of records; proves nothing |
| Owner decisions D-1 to D-6, launcher checks | `../OWNER_REQUIRED.md`, `../LAUNCHER_CHECKS.md` | records |

NOT changed: any file under `gate/`, `policy/`, `spec/`, `toolchain/`,
`schemas/`, `.github/`, `governance/`, `clearing/`, `ts/`, `tests/`,
`scripts/`, `interop/`; `AGENTS.md`; `package.json`;
`TOP_LEVEL_GRAPH.md`. The merged sink on `main` is still the one with
two shown duplicate-effect defects (graph row U3).

The full evidence trees stay on the branches `nightshift/A-proof`
(`1a53594d`), `nightshift/B-trust` (`12d634f6`) and
`nightshift/C-redteam` (`94a1ebe1`). Paths written as
`results/night-shift-20261119/...` in the records (also in `unsure.md`
entries U481 to U631) are `proposals/night-shift-20261119/...` here,
where the file is carried.

## 2. Attack classes closed (all TESTED-UNPROVED; all in the UNAPPLIED hardening, except row 10)

"B" = B's own run with a stored log. "RT" = the red team's own re-run
(exit 0 = the attack fails). "L" = the launcher's independent re-run.
"I" = the integrator's re-run on a scratch clone with both diffs
applied (section 6).

| # | Class | Findings | Fix commit (branch B) | B | RT | L | I |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Proposer: line splitter, client id | C-ATT-01, 16 | `de71cf4d`, `216dfbe2` | c_att_01 exit 0; c_att_16: NO STORED LOG of B | 0; 0 | — | — |
| 2 | Duplicate effects; request identity, charge binding, cumulative limit, one-statement commit in the database schema | E1, E2; C-ATT-02, 04, 06, 10, 11, 12, 20 | `b7fd6be8` | db_safeguards 69 rows, exit 0; runner 26 of 26, exit 0 (the merged sink FAILS the eight known ids) | E1, E2: 1 on the merged sink, 0 with the v6 draft; 02, 06: 0 at `608b5165`. 04, 10, 11, 12: "closed" in ONE summary sentence of the log, no exit line per item (UNVERIFIED). 20: UNVERIFIED, and its two stored worker logs disagree (exit 1 and exit 0) | — | x1, x2 through `run.ts`: 0 |
| 3 | Dispatcher: claim rule, owned lock, in-doubt records | C-ATT-17, 18 | `f08a21c1` (re-tested at `88ae6cbf`) | 10 of 10 `d_*`, exit 0 | 0; 0 | L-CHK-01: fix tree 0, control tree 1 (three tests) | d_att17_lock_theft 0; d_att17_claim_race 0; d_att18_throwing_emit 0 |
| 4 | Sink: old-row check while running, hard links, intent bound | C-ATT-23, 24, 26 | `88ae6cbf` | 8 of 8 `s_*`, exit 0 (one first attempt of s_att21 exit 1 before a TEST fix; kept) | 0; 0, 0; 0 | — | — |
| 5 | Sink and dispatcher: journal classifier, recover rule, ledger hash chain, identity by inode | C-ATT-33, 34, 35, 36, 37 | `f67c5c16` | 6 of 6, exit 0; real kill 24 rounds, 0 failures | 0 each (33 and 35: "for the tested cases") | L-CHK-02 (36): fix tree 0, tree before 1 | d3_att36_retry_restore 0; s3_att33_crash_journal 0 |
| 6 | Provider adapter (decision D-3) | C-ATT-41, 42, 44 | `e9c79928` | old adapter 1, new adapter 0 (four tests) | 0, 0, 0, 0; old adapter 1, 1, 1 | — | p3_scope_collide 0; p3_key_squat 0; p3_rollback_rebind `first full` 0 |
| 7 | Minter: a refusal closes only the attempt (decision D-2); earlier freeze and decode defects | C-ATT-38, 39, 40; 03, 15, 29 (NoStore), 30 (invented state) | `219bf0ca` (`608b5165`, `370ff65c`) | five `m3_*`, all `m_`, `m2_`: exit 0 | 0 each | — | m3_refusal_does_not_close 0; m3_one_effect_per_request_id 0 |
| 8 | Persistent minter key from a checked file; key id; allowlist (decision D-1) | C-ATT-05 | `b22b6b34` | 13 of 13 `kf_*`, exit 0 | 0 in 2 runs; B's 13 tests 0 in RT's runs | — | kf_symlink_refused 0; kf_mode_refused 0; kf_no_env_no_bypass 0; kf_restart_one_token 0 |
| 9 | Test judges | C-JUDGE-02, 03 | `cf242303` | runner 29 of 29, exit 0 | closed at `cf242303` | — | — |
| 10 | Launcher authorizes an aborted child when the caller ignores SIGCHLD | C-LAUNCH-01 | A's prototype `orch-A/launch/launcher_v2.py` (NOT deployed) | — | 0 in 5 of 5 runs (24 tests); version 1: 1 in 2 of 2 | — | — |

Closed only under a named condition, or not re-tested by the red team:

| Findings | State |
| --- | --- |
| C-ATT-25, 32, 07 | closed WITH the dispatcher's expected head (0); without it 1 (stated limit) |
| C-ATT-12 | "closed with an anchor" per the red team's summary sentence; UNVERIFIED per item |
| C-ATT-21, 22; C-HOST-01 to 05, 07 | repaired by B (B's tests exit 0); NOT RUN by the red team on the repair |
| C-JUDGE-01 | PARTLY closed: 3 defective inputs passed both judges at `cf242303`; the rebuild `7667574c` was NOT re-tested by the red team |
| C-ATT-29 | closed in NoStore mode; Store mode keeps the refusal as specified behaviour |

Trust assumptions of every row: the tests are finite; the code under
test is TypeScript and SQLite that no proof covers; "red team" and
"launcher" are the same model family on the same machine; SINGLE-WRITER,
DIR-EXCLUSIVE, SAME-UID (a same-uid attacker is out of the claims);
ANCHOR-OUTSIDE and ANCHOR-FRESH for every rollback row; a FAKE provider.

## 3. Proofs

### 3.1 Dafny (B). Command for every row

    dafny verify --solver-path <z3 4.12.1> --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects FILE.dfy

Pinned Dafny 4.11.0. Every row: exit 0 in B's stored log. All 47
recorded runs were found with their count and exit by the inventory
(`dafny-proofs.tsv`: 47 FOUND, 0 mismatch). All are source-level results
about MODELS.

| File | Verified | Exit | What it says | Hypotheses / assumptions |
| --- | --- | --- | --- | --- |
| `impl/finality-core/IssueAuth.dfy` | 194 | 0 (B); 0 (integrator re-run) | one byte string per (charge id, request id); a refusal changes nothing; a settled id is not issued again | stored state, settled flag, pre-state hash and memory are FREE inputs (STORE-READ, G-H); KEYID-GLUE outside the model |
| `impl/finality-core/IssueOnce.dfy` | 160 | 0 (B); 0 (integrator re-run) | first per-request rule; SUPERSEDED by IssueAuth | the same class |
| `impl/finality-core/ShellCoreV6.dfy` (with V5, V4, V3, `SinkCoreV3.dfy`) | 192 | 0 (B, on the evidence copy); 0 (integrator re-run, on the copy in `impl/`) | a committed step satisfies the approved relation on the stored charge | reading CTX-SINK (owner decision B-10) |
| `orch-B/b-v6bytes/src/{ControlsBytesV6,TopV6Export,KeyedV6}.dfy` | 2352 (one run) | 0 | byte-level composed lemma: approval of committed effects with NO signing hypothesis at layer 0 | H1B and B5 at layer 1; A6b or A6x; hash glue G-H |
| `orch-B/b-ser2/{ControlsBytesV3,RefineHashV3}.dfy` | 1871 (one run) | 0 | byte-level lemma over a hash-comparing core | A2p, H1B, B5, A4 |
| `orch-B/b-top/src/{TopFromExport,IssuerLink,KeyedHash,RefineTraceV3}.dfy` | 2185, 2236, 2325, 1889 | 0 each | top-level composition from the export bytes | A2q, H1B, B5, A4, A6x |
| `orch-B/b-export-bridge/{ExportBridge,SliceSafetyFromExport}.dfy` | 1823, 1892 | 0 each | the exported contract equals the flat contract | A6x |
| `orch-B/b-restart/{Restart,KeyedStore}.dfy`, `orch-B/r-restart/work/AttackRestart.dfy` | 1686, 1820, 1831 | 0 each | NEGATIVE result: a rollback and a forged initial state pass any database audit | none |
| `orch-B/h-anchor/dafny/Anchor.dfy` | 61 | 0 | a rollback to a prefix is detected against an outside head | ANCHOR-MONOTONE; a model only |
| 27 more rows (phase 1 chain, reviewers' files) | see `dafny-proofs.tsv` | 0 each | see `ROADMAP.md`, trust track parts 1 to 3 | listed there per row |

Corrections that stand: a global IdealMac assumption cannot be met by a
real signature scheme (U478); byte-layer injectivity is false for the
real token; IssueAuth does not say "signs only on the state the sink
stores" (U624). One source (`b-ser/SerModel.dfy`) was committed after
its log: its run-time content cannot be checked from history.

### 3.2 HOL (A)

Every row: MODEL level (CakeML/HOL machine semantics), same machine,
stored older parent theories, NOT a clean replay, NOT an
independent-machine replay. Command: `nightshift-run.sh <case> <cpu>
<deps>` (route A) or `bash go.sh <ID>` (link cases); exit = `actual_exit`
of each `command.json`. Statements: `../orch-A/FINAL_STATEMENTS.txt`.
Full table with digests: `../orch-A/FINAL.md` section 2.

| Cases (exit 0) | Reproduced from the branch (same machine, objects byte-equal) |
| --- | --- |
| L1-0001, L2-0003, L2b-0003, L2c-0001, L2d-0001, E1-0003, EF-0001, EE-0001, PF-0004, PX-0001, LO-0006, LE-0004, MF-0002, MG-0001, R6base-0001, R6ffi-0002, R6w-0004, link H1 (contract-0001) | YES: 18 of 18 (two failed attempts kept as rows: exit 1 "Run out of store"; exit −15 watchdog after a system sleep) |
| L1imp-0001, L2r-0001, E1r-0001, LE-0003, MF-0001, MT-0001, R6r-0004, R6t-0004, NV-0003, NN-0002, TR1-0001, TR2-0001; link H0, R1, R2, R3, I1, H2, H4, E0, PC1 | NO: not in the reproduction set |

Counts in the route A folder: proof or control cases exit 0: 29; exit 1:
18; exit −24: 1. Link folder: 10 cases exit 0; 12 negative controls exit
1 as required; 5 first tries exit 1 (setup errors). 20 source files have
no run (NOT RUN). Explorations store nothing and are never theorems.

Note on digests: this pull request replaces the local user name in the
evidence files (section 5). The SHA-256 values in A's records are those
of the files BEFORE that change. `SANITIZE_MAP.tsv` gives both values
per file. The theory objects (`.sig`, `.dat`) are not changed; 132
`.sml` sources are.

## 4. Known limits and NOT RUN

Known limits: section 4 of the graph refresh (money safety 1 to 8; gate;
judges; proof track). Unproven transitions to `end_to_end=true`:
section 3 there (T2b to T24).

NOT RUN:

- C-1: the red team's tests with the real refund program against code
  injected at load, and tests of the FFI C code. A safety classifier
  stopped seven commands or responses. None was retried or rephrased.
  By owner decision D-6 this stays permanently NOT RUN.
- The red team's re-runs of: the minter closed-launch tests; the two
  gate modules of C-GATE-07, 08 (the worker's runs stand); C-ATT-21, 22
  and C-HOST-01 to 05, 07 on the repair; the judges rebuild `7667574c`.
- Gate candidates U04 to U11 and K17; the full gate with the B-17 diff.
- B's real-kill regression by anyone but B; any power-loss test.
- The differential against the V6 core (harness error: no result).
- HOL: 20 staged sources; the x8glue case; any clean or
  independent-machine replay.
- By the integrator: HOL; the changed Slice 1 suite; the full regression
  set; Stage 7, 9, 10 EXIT scripts (by convention of the runner).

## 5. The local user name in the records (fix forward)

Pull request 59 put 761 files with the local user name in absolute
paths under this folder on `main`; A's later records had 209 more. B's
record names a temporary path with that name in two earlier commits of
its branch (the inventory found 1,941 files in commit `10611550`, fixed
forward on the branch). This pull request merges NO branch history. In
every file of `proposals/night-shift-20261119/` the byte string of the
name is replaced by `USER` (959 files; map with SHA-256 before and
after: `SANITIZE_MAP.tsv`). The history of `main` before this pull
request still holds the name: that cannot be fixed forward. Other
folders of `main` (about 610 files, mostly `results/stage*`) and 13
existing lines of `unsure.md` hold it too and are NOT changed
(`unsure.md` is append-only; the red team's branch rewrote those 13
lines, and that rewrite is NOT taken).

## 6. The integrator's own runs

All runs by the integrator or its workers, 2026-11-19, on this machine.
Logs: `dafny-rerun/`, `rerun-logs/` (each ends with `exit N`).

Dafny, on the files as this pull request adds them (cwd
`impl/finality-core`, the command of section 3.1, serial, `dafny.lock`
held and removed):

| File | Verified | Actual exit |
| --- | --- | --- |
| `IssueAuth.dfy` (with `IssueBytes2.dfy`, `SerModel.dfy`, `../RefundFinality.dfy`) | 194 | 0 |
| `IssueOnce.dfy` | 160 | 0 |
| `ShellCoreV6.dfy` (with V5, V4, V3, `SinkCoreV3.dfy`, `FinalityProtocol.dfy`) | 192 | 0 |

Regressions on a scratch clone of commit `77f8ec2d` with BOTH unapplied
diffs applied (worker's runs; pinned Node 24.3.0; empty environment):

| Step | Actual exit | Expected | Note |
| --- | --- | --- | --- |
| `git apply --check` of both diffs; `git apply` | 0; 0 | 0; 0 | |
| `diff -r` of `ts`, `scripts`, `tests` against `git archive 12d634f6` | 0; 0; 1 | 0; 0; 1 | ONE differing line: `heavy_spec.sh` line 14, the replaced user name |
| `dafny build impl/finality-core/IssueAuth.dfy --target js` (gate options) plus the export footer of `scripts/exit_slice1.py` | 0 | 0 | 194 verified; module SHA-256 `fa855506da13…44e6`: EQUAL to the module digest in the red team's D-2 record |
| `run.ts <sink> <dispatcher> --only X1,X2` (both duplicate-effect regressions) | 0 | 0 | X1 PASS, X2 PASS |
| `d_att17_lock_theft`, `d_att17_claim_race`, `d_att18_throwing_emit` | 0; 0; 0 | 0 | |
| `d3_att36_retry_restore`, `s3_att33_crash_journal` | 0; 0 | 0 | |
| `m3_refusal_does_not_close`, `m3_one_effect_per_request_id` | 0; 0 | 0 | |
| `m3_zero_squat_limit` | 1 | 1 | the stated known limit is present |
| `kf_symlink_refused`, `kf_mode_refused`, `kf_no_env_no_bypass`, `kf_restart_one_token` | 0; 0; 0; 0 | 0 | temporary test keys, made by the tests |
| `p3_scope_collide`, `p3_key_squat`, `p3_rollback_rebind first full` | 0; 0; 0 | 0 | fake provider |
| `p3_rollback_rebind first none` | 1 | 1 | the stated known limit B-20 is present |
| control: `run.ts` with the MERGED sink and dispatcher, `--only X1,X2` | 1 | 1 | **NOT a valid control for the duplicate effect**: the merged sink refused the faulty token AND the honest token (0 effects). Likely cause (not checked): the judge signs with the patched `encoding.ts`, the merged sink loads its own. The duplicate effect on the merged sink is shown by the red team's E1, E2 and B's runs only, not by the integrator |

Setup errors of the worker (not results; logs set aside): a shell
variable that was not split (nothing ran); the issuer module placed
where `bignumber.js` did not resolve (exits 3 and 1). After a
byte-identical copy of the module inside the tree, the rows above ran.

NOT RUN by the integrator: the changed 126-row suite; spec-conformance;
kill loops; any HOL case.

## 7. Checks (actual exit codes)

Run 1 is recorded here. It ran on commit `75f70919` (the content
commits). The later commits of the branch add records only (`ROADMAP.md`,
`unsure.md`, this folder). The pull request text gives the checks on its
final head.

Scratch-clone check: `git clone --single-branch --branch
nightshift/consolidated-20261119 https://github.com/mack-dot/forge.git`
into an empty folder (HEAD `75f70919`, clean); the pinned tool folders
`.toolchain` and `node_modules` linked in (the repository's convention;
the stage scripts check the Node, Python and package content digests);
pinned Node 24.3.0 first in PATH; then the repository's runner
`python3 proposals/forge2-m1-conformance/run_regression.py <new clone> <record>`
(it clones again and runs every row below in that second clone).
Record: `checks/regression-75f70919.json`, `.log`.

| Check | Command | Actual exit | Result |
| --- | --- | --- | --- |
| scratch clone: 28 Stage EXIT cases (Stages 1, 2, 3, 5, 6, 8, 4, 11) | `python3 scripts/exit_stage_<N>.py --case <case>` | 0 each (28 of 28) | as on `main` |
| scratch clone: Slice 1, 2, 3 and M1 conformance evidence | `python3 scripts/exit_slice1.py --case evidence` (and `exit_slice2.py`, `exit_slice3.py`, `exit_m1_conformance.py`) | 0; 0; 0; 0 | bundle SHA-256 `c7f2f41c…`, `2721a293…`, `3cdfebfc…`, `f55391da…`: EQUAL to the recorded bundles (no bundle input changed) |
| frozen-gate check | `python3 -I -B proposals/round4-20261117/check_frozen_pr_gate.py HEAD` (in the clone; also on the branch head) | 0 | the 8 frozen PR-gate modules equal the recorded digests |
| frozen-gate check: protected paths in the diff | `git diff --name-only origin/main HEAD` against `PROTECTED_DIRS` and `PROTECTED_FILES` of `gate/incremental.py`, and `clearing/`, `ts/`, `tests/`, `scripts/` | 0 paths | changed paths: `proposals/night-shift-20261119/**`, one new file in `proposals/m1b-mission-20261119/`, `impl/finality-core/*.dfy` (new), `ROADMAP.md`, `unsure.md` |
| link check | `python3 -I -B proposals/round4-20261117/check_links.py HEAD <file>` for `FORGE_MASTER_IDEA.md`, `ROADMAP.md`, `unsure.md`, `proposals/forge2-m1-conformance/REPORT.md` | 0 each | no link without a target |
| link check, all Markdown files outside `results/` (318) | the same script | 1 | EXPECTED 1: the two older Stage 9 dead links that `main` has (`docs/stage9-history-audit.md`, `proposals/provenance-receipt-repair.md`); 0 new. On `main` (238 files): 1, the same two |
| `unsure.md` append-only | `git diff origin/main HEAD -- unsure.md`, removed lines | 0 removed | entries appended only; no duplicate ID |
| scan of the diff before each push | added lines with the local user name; private keys; token patterns; `.env`, key and database files | 0; 0; 0; 0 | see section 5 |
| runner as a whole | `run_regression.py` | 0 | 5 result files changed by the stage runs in the throwaway clone only |
| hosted `gate/pr_check.py` | on the pull request | see the pull request | expected 3 (UNSUPPORTED) |
| Stage 7, 9, 10; `npm ci` | — | NOT RUN | left out by the runner; no install script exists |

### Rebase note

After run 1 the owner merged pull request 62 (Goal 19); `main` moved
from `b9f2831c` to `6d66a558`. The branch was rebased onto `6d66a558`
as a NEW branch `nightshift/consolidated-20261119-r1` (no forced push).
`ROADMAP.md` and `unsure.md` were joined as pure appends: both sides'
text is kept verbatim (checked: the added lines of `ROADMAP.md` are the
same 173 lines; the appended entries of `unsure.md` are the same text
after the entries U700 to U706 of `main`). No other file of this pull
request differs from the first branch. Run 1 above is for the tree
BEFORE the rebase. The checks on the rebased head are in the pull
request text.

## 8. Files in this folder

| File | Made by | Content |
| --- | --- | --- |
| `dafny-proofs.tsv` | worker, by reading | 47 recorded Dafny runs: path, blob, count, log line, exit, command, includes |
| `fixes.tsv` | worker, by reading | B's fix rows with their stored logs |
| `unapplied.tsv` | worker, by reading | every unapplied diff of B with its owner item and touched protected paths |
| `redteam-retests.tsv` | worker, by reading | 70 red-team findings: status, script, log line, consistency |
| `B-code-notes.md`, `C-scan.md` | workers, by reading | how the tests load code; build recipes; scans |
| `dafny-rerun/` | integrator | logs of the three Dafny re-runs |
| `SANITIZE_MAP.tsv` | integrator | section 5 |
| `checks/` | integrator | records of section 7 |

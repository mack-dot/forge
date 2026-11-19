# M1 clean replay: plan (DRAFT, W4, step I.4c, 2026-11-19)

Status: PLAN ONLY. Nothing in this file has run. No command here may start
before the owner approves the limits, the commands and the evidence
destinations (owner question Q6). `end_to_end=false`. A pass does not
prove M1. It shows that the committed scripts build the recorded theories
again from an empty tool tree.

Values come from tracked records. Each number names its record. A value
marked "estimate" is not a record.

Abbreviations:
- `RP` = `proposals/refund-executable-feasibility/m1-chain-replay-20261118/records`
  (tracked on `main` 8e772b55 and on the backup branch).
- `BK` = branch `origin/backup/forge-local-2026-11-11`, commit `c003a982`
  (`c003a9827c6bdfb73c220eb15a40b87e8ce3ba60`).
- `CLEAN` = the root folder of the clean clone (proposal:
  `<HOME>/forge-clean-m1-20261119`; owner to confirm).
- `TC` = `CLEAN/.toolchain/experiments/refund-cakeml-20261104`.
- `OUTC` = `CLEAN/results/m1-clean-replay-<date>/` (untracked evidence).

## 1. What "clean" means here

All of these must hold. If one does not hold, the result is not clean.

1. Sources: a fresh `git clone` of the public repository into a new,
   empty folder `CLEAN`, checked out at ONE commit that the owner names
   (Q-C1). The M1 sources are NOT on `main`: 0 of the 259 source, runner
   and list files that `RP/plan.json` restores are on `main` 8e772b55;
   259 of 259 are on `BK` (measured by W4 with `git ls-tree`). The 
   replay records `RP` are on both. Proposal: check out `BK` `c003a982`.
2. Tools: a new, empty tool tree `TC`, built from the pinned commits:
   Poly/ML `4557554077078decce4ce5f90da00a713cfc32e4` (5.9.2), HOL
   `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`, CakeML
   `cd9155694c16831373ab695a670794f23282ed62` (U258; `rebuild.py` on `BK`).
   The clone of each comes from the upstream URL in `rebuild.py`. The
   identity check is `git rev-parse HEAD` equal to the pin (as in
   `rebuild.py`). "Recorded digests" of upstream are these commit hashes;
   no tarball digest is recorded.
3. No reuse: no file from the present tree
   `<HOME>/forge/.toolchain/experiments/refund-cakeml-20261104`
   and no file from the present `results/` is read, copied, linked or put
   on a path. In particular no `.dat`, `.sig`, `.sml` theory file, `.uo`,
   `.ui`, heap, `hol.state`, `.hol/` folder or Holmake cache.
4. Inputs from tracked files only: every restored source comes from the
   clean clone and must equal its SHA-256 in `RP/plan.json` and
   `RP/plan-phase2.json` (the restore rule of `RP/scripts/restore.py`).
5. Separate working folder: `CLEAN` is not inside
   `<HOME>/forge`. All writes go under `CLEAN`.
6. Same discipline as 2026-11-18: one HOL process at a time; Holmake
   `-j1`; `nice -n 15`; `caffeinate -i -s`; a `-n` dry run before each
   Holmake command; every command recorded with its real exit.

## 2. The path problem (must be decided before the run)

The packet files hold the absolute home path. Measured by W4 on `BK`:
121 of the 301 restore and step sources contain `<HOME>`
(67 `.txt` dependency lists, 51 `.py` runners, 2 `.sml`, 1 `.json`). The
two `.sml` files are
`m1-reject-startup-20261115/records/rej/reject-0009.sml` (theory
`forge_refundRejectNonFail`) and
`native-error-instructions-20261105/records/inspect-arm8-steps/preload.sml`
(the preload of the 9 ARMv8-step cases). The replay copies of
`run_case.py`, `driver.py`, `restore.py`, `upstream_build.py` in `RP`
have `<HOME>` in place of the home path, so they do not run unchanged.

Two options (owner decision Q-C2):

- Option M (proposed): path map. A new script `clean_restore.py`
  (derived from `RP/scripts/restore.py`) copies each source, checks its
  recorded SHA-256 first, then replaces the literal prefix
  `<HOME>/forge` with `CLEAN` in the 121 listed files only. It
  records, per file, the SHA-256 before and after the map and the line
  count changed. The 2026-11-18 replay used the same kind of map for the
  S3 copy folder and still got equal `.dat`/`.sig` hashes for the cases
  that ran there (`RP/../REPORT.md`, section 4). Risk: no record shows
  equal hashes when the TOOL TREE path changes.
- Option P: same absolute path. Run the clean replay at
  `<HOME>/forge` itself, after the present checkout is moved
  aside. This touches the owner's working repository and the locked tool
  tree (`.toolchain/experiments/DO-NOT-DELETE.md`). Not proposed.

## 3. Steps, commands, limits, evidence

Global guard (checked before each command; a refusal waits 60 s and tries
again; never bypassed): free disk >= 20 GiB; `memory_pressure` free >= 25
percent (the 2026-11-18 rule in `RP/scripts/runcmd.py`); swap used <= 6
GiB; no other `poly`/`hol`/`Holmake` process; Mac on mains power. Global
stop: free disk < 15 GiB, or a HOL child RSS > 7,168 MiB, or swap used >
7.5 GiB. The 2026-11-18 guard used disk >= 3 GiB; this plan uses a larger
margin because of the earlier incident (parallel HOL jobs filled swap
and disk). The memory numbers are proposals (estimates), set above the
largest recorded peak of 4,768 MiB (`forge_refundImage`, REPORT.md).

Per-command time limit for HOL cases: max(3 x recorded wall, recorded
wall + 600 s). For tool-build steps the limit is given in the table.

Times in the "recorded" column are awake seconds from the named record.
Interrupted builds (backend proofs ran in three windows) may contain
repeated work, so the sum is an upper estimate for one run.

| # | Step | Command (run in) | Recorded wall s (record) | Time limit s | Evidence (under `OUTC`) |
| --- | --- | --- | --- | --- | --- |
| P0 | Preconditions, no build | `df -g`, `sysctl vm.swapusage`, `memory_pressure`, `pmset -g batt`, `ps` for HOL; list `TC` (must not exist) | — | 120 | `pre/conditions.json` |
| P1 | Clone the repository | `git clone <public URL> CLEAN`; `git -C CLEAN checkout --detach <commit>`; `git -C CLEAN rev-parse HEAD`; `git -C CLEAN status --porcelain` (must be empty) | not recorded | 1,800 | `pre/clone.json` |
| P2 | Source check | `python3 -I -B clean_check_sources.py` (new, reviewed): SHA-256 of each source in `RP/plan.json`, `RP/plan-phase2.json` (`B.restore`, `B.steps`, `C.cases`) against the recorded value | — | 600 | `pre/source-check.json` |
| T1 | Clone and pin tools | `caffeinate -i -s python3 -I -B CLEAN/proposals/round2-20261117/m1-rebuild/rebuild.py 41400 m1-clean-tools-<date>` (one budget for T1–T7; the script kills the running command at its deadline) (from `BK`; `FORGE` = parents[3] of the script, so it builds in `TC`) | 89.4 (`results/round2-m1-rebuild-20261117/attempt-0001/commands.json`) | 1,800 | `rebuild.py` writes `CLEAN/results/m1-clean-tools-<date>/attempt-0001/commands.json` and logs |
| T2 | Poly/ML configure, make, compiler, install | inside `rebuild.py`: `./configure --prefix=TC/poly-install --enable-intinf-as-int --with-gmp`; `make -j2`; `make compiler`; `make install` | 228.3 (same record) | 1,800 | same |
| T3 | HOL configure and build | `poly --script tools/smart-configure.sml`; `bin/build` | 711.2 (same record) | 3,600 | same |
| T4 | CakeML basis | `nice -n 15 TC/HOL/bin/Holmake -j1` in `TC/cakeml/basis` | 3,685.2 (same record) | 9,000 | same |
| T5 | CakeML compiler proofs | same, in `TC/cakeml/compiler/backend/proofs` | about 15,284 in three windows: about 686 (killed, round 2 REPORT.md), 10,794.6 (killed, `results/round3-m1-build-20261117/attempt-0001/commands.json`), 3,803.8 (exit 0, `results/round4-m1-build-20261118/attempt-0001/commands.json`) | 25,200 | same |
| T6 | `cv_translator` (`cake_compile_heap`) | same, in `TC/cakeml/cv_translator` | 2,433.6 (round 4 record) | 7,200 | same |
| T7 | HOL ARMv8 step heap | same, in `TC/HOL/examples/l3-machine-code/arm8/step` | NOT RECORDED: the 2026-11-18 window skipped it because `arm8-heap` existed (round 4 record) | 7,200 (estimate) | same |
| T8 | Upstream objects that `rebuild.py` does not list | for each: `nice -n 15 TC/HOL/bin/Holmake --no-cache -j1 -n <target>`, then without `-n`. (a) `TC/cakeml/compiler/dafny/proofs`, `dafny_to_cakemlProofTheory.uo`; (b) `TC/cakeml/compiler/dafny`, `sexp_to_dafnyTheory.uo`; (c) `TC/cakeml/compiler/backend/arm8/proofs`, `arm8_configProofTheory.uo`; (d) `TC/HOL/examples/l3-machine-code/arm8/step`, `arm8_stepLib.uo` (dry run only if (c) built it) | 108.4; 14.0; 1,174.1; 0 (`RP/../REPORT.md` section 3) | 1,200; 600; 4,800; 600 | `tools/upstream/*.json` (dry-run check, real run) |
| T9 | Tool identity | SHA-256 of `TC/HOL/bin/hol`, the four heaps, every `.dat`/`.sig`/`.sml` under `TC` (listing like `RP/scripts/listing.py`) | — | 1,800 | `tools/tooltree-listing.json`, `tools/heaps.json` |
| R1 | Restore sources | `python3 -I -B clean_restore.py results` then `tooltree` (Option M map) | — | 600 | `restore-record-results.json`, `restore-record-tooltree.json`, `path-map.json` |
| R2 | Executable identity | SHA-256 of `CLEAN/proposals/refund-executable-feasibility/native-execution-20261104/records/native-build-0001/refund` and of its restored copy = `b8ed5ec2…7bb8`; size 238,776 | — | 60 | `executable.json` |
| C1 | Chain phase 1, 71 theories + `imp4-0001` (72 steps) | `python3 -I -B OUTC/scripts/driver.py run 1 72` (a copy of `RP/scripts/driver.py` with `ROOT = CLEAN`; nothing else changed) | 7,034 incl. T8 builds (1,296.5), so about 5,738 for the chain (`RP/../REPORT.md`); original runs 7,515.4 (`RP/plan.json`) | per step 3 x recorded or + 600; inside W-chain (12,600) | `commands.json`, `status.json`, `logs/`, case folders |
| C2 | Chain phase 2, 24 theories | `FORGE_PLAN=phase2 FORGE_BUDGET_FILE=budget-phase2.json python3 -I -B OUTC/scripts/driver.py run 101 124` | 1,389 (REPORT.md addendum); originals 1,743.7 (`RP/plan-phase2.json`) | per step as C1; inside W-chain | same |
| C3 | Joint-premise run `fs` | `python3 -I -B OUTC/scripts/driver.py fs fs-c-0001 fs-c-0001.sml 600`, where `fs-c-0001.sml` is a byte copy of `m1-slide-s4-s6-20261117/records/fs-0002.sml` (SHA-256 `e69e2753…fe46`) | 84.3 (`RP/fs/attempts.json`) | 900 | `fs/attempts.json`, case folder |
| C4 | Import checks of the chain | `driver.py check fs-imp-c-0001 fs-imp-c-0001.sml fs-c-0001` (copy of `RP/final-cases/fs-imp-r4-0001.sml`); `imp4-0001` runs in C1 | 72.2; 78.3 (`RP/commands.json`) | 900 each | same |
| C5 | The 158 recorded cases (55 controls, 61 repeats, 42 import checks) | the runner that step I.4a uses now, with `ROOT = CLEAN`; one case at a time, in packet order | 11,144.0 (sum of `recorded_wall_seconds`, `RP/plan-phase2.json` C.cases); largest one 663.3 | W-cases (18,000); per case max(3 x recorded, recorded + 600) | `cases/<packet>/<case>/command.json`, `cases/summary.json` |
| V1 | Recheck | `recheck.py`, `recheck_phase2.py` copies: fresh `.dat`/`.sig`/`.sml` SHA-256 against the recorded values | — | 600 | `comparison.json`, `comparison-phase2.json` |
| V2 | Slices | a new script, written apart from the proof scripts: SHA-256 of bytes [16384, +108), [16592, +130436), [180248, +20248) of the executable | — | 60 | `slices.json` |
| V3 | Final theorem tags | import check `imp4-0001` output: `CLOSURE_AXIOM` lines, `IMPORTED_ORACLES`, hypothesis count | — | (in C1) | `final-theorem.json` |
| V4 | Postflight | tracked files changed in `CLEAN` (`git -C CLEAN status --porcelain` limited to tracked files: must be 0); old tree untouched (its listing before = after; read-only `find`/`stat`, no git inside it) | — | 900 | `post/postflight.json` |

Note: `rebuild.py` enforces only its total budget. The per-step limits of
T2–T7 need a watch process (new, reviewed) that stops the step at its
limit; or the owner accepts the total budget only (Q-C3).

Memory per step (from records): HOL cases 0.45 to 4.8 GiB (REPORT.md:
typical 2.3 to 3.5 GiB; peak 4,768 MiB); the 158 cases: median 1,941 MiB,
largest 4,337 MiB (`loader-0003`) (W4, from the 158 packet
`command.json` records on `BK`). Tool-build peaks: NOT RECORDED.

Disk (measured by W4 on 2026-11-19 with `du -sk`, not a record): present
tool tree about 2.1 GiB (polyml 153 MiB, poly-install 11 MiB, HOL 868
MiB, cakeml 1,080 MiB); replay results folder 377 MiB; repository `.git`
374 MiB. Free disk today 87 GiB (`df -g`). Estimate for the clean run:
under 8 GiB including logs, if Holmake writes no large debug heaps.

## 4. Small records copied into a tracked packet

Proposed packet: `proposals/refund-executable-feasibility/m1-clean-replay-<date>/`
(new folder; never under `clearing/`). It holds: `REPORT.md`,
`MANIFEST.json` (SHA-256 of every file), and copies of
`pre/*.json`, `tools/upstream/*.json`, the tool `commands.json`,
`tools/heaps.json`, `restore-record-*.json`, `path-map.json`,
`executable.json`, `commands.json`, `status.json`, `comparison*.json`,
`fs/attempts.json`, `cases/summary.json`, `slices.json`,
`final-theorem.json`, `post/postflight.json`, the scripts, and the
`stdout.log` of `e4-0001`, `imp4-0001`, the fs run and its check.
Home prefix written `<HOME>` in text files (as on 2026-11-18). Large
logs, built theories and heaps stay in `OUTC` (untracked).

## 5. Acceptance criteria (all must hold)

1. P1: `rev-parse HEAD` = the named commit; clean status.
2. P2: every planned source equals its recorded SHA-256 (0 differences).
3. T1: each tool `HEAD` = its pin (3 of 3). T2 to T8: exit 0 each.
4. C1, C2: 95 of 95 theories exit 0; each fresh `.dat`, `.sig` and
   `.sml` SHA-256 equals the value in `MANIFEST_DRAFT.json`
   (`theories[].expected`; 95 rows with recorded hashes). Example: 
   `forge_refundSlideProfileA` `.dat` = `4ff2a7e2821a9a36fe84cc85bac2b61a7544bc45cd87a83623a2386a9c8212a1`.
5. `imp4-0001`: exit 0; `IMPORTED_COUNT 15`, `MISMATCH_COUNT 0`; stdout
   equal to the packet except timing lines.
6. Final theorem `refund_profile_a_sl`: closure axioms exactly
   `bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX`,
   `bool.BOOL_CASES_AX`; oracle tags exactly `DISK_THM`; 0 explicit
   hypotheses; `CLOSURE_NODES 542`; `STORED_THEOREMS 17`; marker
   `EXACT_COMPLETE` (`RP/final-cases/e4-0001/stdout.log`).
7. fs: exit 0, `EXACT_COMPLETE`, 13 theorems and 1 definition, 0 lemma
   failures; `.dat`/`.sig`/`.sml` equal to `d70d1a65…44bd`,
   `cb127ba1…2c1e`, `21e2bb17…52ad` (one earlier run only:
   `RP/fs/attempts.json`). Its check: `IMPORTED_COUNT 8 MISMATCH_COUNT 0`.
8. C5: each of the 158 cases ends with its recorded exit AND its
   recorded reason: for a failing control, the same failing check (the
   last `stderr` line of the record, path prefix ignored) or the same
   marker lines; for exit-0 cases, the recorded markers and, where the
   case exports a theory, equal `.dat`/`.sig` hashes. Recorded classes:
   61 repeats exit 0; 45 controls non-zero; 10 controls exit 0; 41 import
   checks exit 0; 1 import check non-zero (`RP/plan-phase2.json`). A case
   with the right exit and another reason is NOT a pass (I.4a found one
   such case at 04:56Z; see TRACKER.md).
9. V2: the three slices equal `9e010ce3…7f86`, `3c67983c…5deb`,
   `68d3f080…fb76`; the executable equals `b8ed5ec2…7bb8`; 238,776 bytes.
   `refund.S` from `forge_refundArm8Compile` equals `4c750e4f…1757`.
10. V4: 0 tracked files changed; old tree and old `results/` unchanged.
11. Guard: 0 bypassed refusals; peak RSS, swap and disk recorded.

A failure is recorded with its real exit and kept. The classes of the
2026-11-18 driver apply (`FAILED_UNCLASSIFIED`, `MEMORY_FAILURE`, …). No
proof script is edited. A proof failure ends the clean replay as
"clean replay: FAILED at <step>"; it is not repaired inside this run.

## 6. Budget

Recorded sums (awake seconds): tool build 23,728.6 (T1 89.4 + T2 228.3
+ T3 711.2 + T4 3,685.2 + T5 about 15,284 + T6 2,433.6 + T8 1,296.5),
T7 not recorded; chain 7,127 (C1 about 5,738 + C2 1,389); fs and check
156.5; 158 cases 11,144.0. Total about 42,156 s (11.7 h) plus T7.

Proposed hard budget (estimate: recorded sums x 1.5, T7 taken as 7,200
s): 77,400 s (21.5 h) of awake time, in three windows. Each window stops
at its own deadline:

| Window | Steps | Base (records + T7 estimate) | Limit (estimate) |
| --- | --- | --- | --- |
| W-tools | P0–P2, T1–T9 | 30,929 s | 46,800 s |
| W-chain | R1–R2, C1–C4, V1–V3 | 7,284 s | 12,600 s |
| W-cases | C5, V4 | 11,144 s | 18,000 s |
| Total | | 49,357 s | 77,400 s |

Windows, because the tool build is incremental and a stop loses no
finished theory. A window may start only when the earlier one ended
with all its acceptance items met. Sleep time does not count; it is
measured and recorded (as in `RP/budget.json`).

## 7. Forbidden shortcuts (each one makes the result NOT clean)

- Reuse of any file of the old tool tree or old `results/` (copy, link,
  `INCLUDES`, `HOLHEAP`, `PATH`, `--holstate`).
- A Holmake cache or `--cache`; omitting `--no-cache`.
- Copying a built theory file (`*Theory.dat/.sig/.sml/.uo/.ui`), a heap
  or a `.hol/` folder from anywhere.
- Using a tool checkout whose `HEAD` is not the pin, or with local edits.
- Editing a proof script, a statement, a Holmakefile text, a dependency
  list (other than the recorded path map), or a control.
- Skipping a theory, control or check, or marking a case passed without
  its real exit and reason.
- Running more than one HOL process at a time; `-j` above 1.
- Running in the present `<HOME>/forge` tree (Option P aside).
- Network after T1 (no download during the proof steps).

## 8. Risks from the records

- Missing upstream objects: `rebuild.py` did not list 16 theories and 3
  library objects that the chain needs (T8). There may be more for the
  158 cases; they are not known until their dry runs. Rule: an extra
  upstream build only with a `-n` dry run, only new files, recorded.
- Empty folder: `forge_refundCertifiedProg` has
  `INCLUDES = ../forge_refundProg_experiment`; the 2026-11-18 replay had
  to create that folder empty (`RP/environment-changes.json`). The clean
  restore must create it too, and record it.
- The ARMv8-step runner `run_arm8_case.py` refuses after a rebuild (4 of
  15 tool files differ: `RP/arm8-tool-identity.json`). The 9 ARMv8 cases
  and `bridge-0005` must run in "direct mode" as on 2026-11-18.
- Path dependence (section 2). Unknown whether a changed tool-tree path
  changes any `.dat`. If a hash differs, the step is recorded as
  "different", then a statement comparison decides the cause; the result
  is not accepted as equal.
- Preload reconstruction: one preload file is in no packet; it is
  rebuilt from the first two lines of a stored file; SHA-256 must equal
  `c3cbcccc…de5e` (`RP/plan.json` `restore_generated`).
- `bridge-0005/command.json`: an old packet record that every
  `run_case.py` reads; it must be restored from the packet.
- Disk and swap: the earlier incident (parallel HOL jobs). Swap was 6.9
  of 8 GiB at one moment today, so the swap guard may refuse at the
  start; close other heavy programs or restart first (owner).
- Sleep and battery: U438 and U440 record battery incidents during M1
  builds. Run on mains power under `caffeinate -i -s`.
- gmp: `rebuild.py` uses Homebrew gmp; its version is not recorded.
- Network for T1 (GitHub). If the upstream history were rewritten, the
  pin check fails; that is a stop, not a reason to change the pin.
- I.4a (the 158 cases) runs now on the old tree; the clean run must not
  start until it ends (one HOL process at a time).

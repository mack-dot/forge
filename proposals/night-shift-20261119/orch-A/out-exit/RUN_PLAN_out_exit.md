# Run plan: L-OUT v3 and L-EXIT-0 v3 (worker A3). NOTHING HERE HAS RUN.

Every command below is NOT RUN. Every exit code below is EXPECTED, not actual.
Worker A3 started no HOL process. Run one HOL process at a time, only when the HOL slot is free.

## 0. Inputs (SHA-256 at hand-off)

| Item | Path | SHA-256 |
|---|---|---|
| L-OUT script | `results/night-shift-20261119/orch-A/out-exit/L_OUT_v3.sml` | `553233ceb0754c9a499d9c992a5b503310d4e9152e1bf7724a8d896190a19a61` |
| L-EXIT script | `results/night-shift-20261119/orch-A/out-exit/L_EXIT_v3.sml` | `af413707696589f759aaff1933923cbd37dbe0796c1300142e42327f67bd5935` |
| runner | `results/round4-m1-replay-20261118/slide-s3-copy/attempt-0001/run_case.py` | `9c1064bde75415a0a592a5d4dc5c40f8554a223335eed261cd29ac4128823c3b` |
| deps (base) | `results/round4-m1-replay-20261118/slide-s3-copy/attempt-0001/deps-imp4.txt` (125 lines; ends with the e4-0001 theory `forge_refundSlideProfileA`) | `76bcd4909e81f7fc9a11144996e5b2f530e240afdb0cf62096aeff2e0209cc90` |
| wrapper | `proposals/m1b-mission-20261119/drafts/route-a/go-routeA.sh` | `8b6bf896f9da81f2eabdfc78330b8ad5408037d9111f89933aa68162182c7289` |
| hash helper | `proposals/m1b-mission-20261119/drafts/route-a/hash_parents.py` | `39be0107d84cc74f93758741d27faa118774e0e694a1135e35247f2cb9ff5644` |

Do NOT run `L_OUT_v2.sml`. It cannot pass: `refund_profile_a_sl_fd1` fails on `INST` (defect D1 in
`the A3 report (handback text)`), and the `FD1-ext` control then fails too. v3 replaces it.

## 1. Order and limits

| # | Case | Source | Deps file | CPU limit (s) | Depends on |
|---|---|---|---|---|---|
| O | `LO-0001` | `L_OUT_v3.sml` | `deps-LO.txt` = copy of `deps-imp4.txt` | 900 | nothing new |
| E | `LE-0001` | `L_EXIT_v3.sml` | `deps-LE.txt` = `deps-LO.txt` + 2 lines for `LO-0001` | 1200 | a PASSING run O |

Basis for the limits: e4-0001 used 127 s CPU and 3.3 GiB max RSS only to load the same parents
(`e4-0001/command.json`). O has 31 lemmas, most of them small. E has the case explosion over
`evaluate_def` (up to five alternatives for `evaluate_Halt_reg`). The limits are guesses.
Order relative to other jobs: the orchestrator's queue (STATE.md: L1, link theorem, prefix lemma,
then L-OUT, then L-EXIT-0). E needs the exported theory of O.

## 2. Before each run (resource check, memory first)

```zsh
test -f /Users/USER/forge/results/round4-m1-replay-20261118/phase3/ALL_DONE && echo "replay done"
pgrep -fl 'cake_compile_heap|arm8-heap|cakeml-heap|poly|hol' || echo "no HOL process"
memory_pressure | tail -1            # need >= 25 % free (run_case.py refuses below 25 %)
sysctl vm.swapusage                  # record it; replay case 005 stopped with "Run out of store"
df -h /System/Volumes/Data           # need >= 3 GiB free
```
If any HOL process runs: stop. `run_case.py` also refuses (exit 3, `resource_guard_refused`; not an attempt).

## 3. Set up the attempt folder (once)

```zsh
W=/Users/USER/forge/results/night-shift-20261119/orch-A/out-exit
S=/Users/USER/forge/results/round4-m1-replay-20261118/slide-s3-copy/attempt-0001
D=/Users/USER/forge/proposals/m1b-mission-20261119/drafts/route-a
A=/Users/USER/forge/results/m1b-out-exit-20261119/attempt-0001
mkdir -p $A
cp $S/run_case.py $A/run_case.py
cp $S/deps-imp4.txt $A/deps-LO.txt
cp $D/go-routeA.sh $D/hash_parents.py $A/ && chmod +x $A/go-routeA.sh
cp $W/L_OUT_v3.sml $A/LO-0001.sml
shasum -a 256 $A/run_case.py $S/run_case.py $A/deps-LO.txt $S/deps-imp4.txt $W/L_OUT_v3.sml $A/LO-0001.sml \
  $A/go-routeA.sh $A/hash_parents.py
```
Expected: each copy has the hash of its source (table in section 0).

## 4. Case O: L-OUT

```zsh
cd $A
FORGE_CPU_SECONDS=900 ./go-routeA.sh LO-0001 LO-0001.sml deps-LO.txt ; echo "go exit $?"
grep -n "^CHECKED \|^DEFINITION \|^CONTROL_OK\|^UNEXPECTED_CONTROL_ACCEPTANCE\|^LEMMA_FAILED\|^DEFINITION_FAILED\|^NOEXT\|^SPE_NOEXT_FAILED\|^EXT_VARIABLE\|^CLOSURE_AXIOM\|^STORED_\|^EXACT_COMPLETE\|^USED " LO-0001/stdout.log | cut -c1-200
```

Pass criteria for O (ALL; otherwise the run is a finding, not a pass):
1. `LO-0001/command.json`: `actual_exit` 0, `markers` contains `EXACT_COMPLETE`, `inputs_unchanged_after` true,
   `source_sha256` = SHA-256 of `L_OUT_v3.sml`.
2. No line starts with `LEMMA_FAILED`, `UNEXPECTED_CONTROL_ACCEPTANCE`, `DEFINITION_FAILED`, `NOEXT_FAILED`,
   `SPE_NOEXT_FAILED`. (`run_case.py` matches markers only as whole lines; grep the log.)
3. Exactly these 31 `CHECKED <name>` lines: `fd1_written_APPEND`, `fd1_written_prefix`, `STD_streams_facts`,
   `STD_streams_File_fd`, `w22n_lt`, `w22n_n2w2_bytes`, `write_stdout`, `ffi_write_cases`,
   `ffi_write_stdout_step`, `read_stdout`, `ffi_read_stdout_step`, `openFile_stdout`,
   `openFile_truncate_stdout`, `ffi_open_in_stdout_step`, `ffi_open_out_stdout_step`,
   `STD_streams_ADELKEY_File`, `closeFD_stdout`, `ffi_close_stdout_step`, `ALOOKUP_fs_ffi_part`,
   `fs_ffi_part_stdout_step`, `extract_no_ext_ExtCall`, `extract_no_ext_stdout`, `extract_fs_inode_tbl`,
   `refund_L_OUT`, `refund_L_OUT_prefix`, `refund_profile_a_sl_fd1`, `STD_streams_fs0`,
   `N_O1_free_ext_breaks`, `N_O2_failed_write_counted_without_success_test`,
   `N_O3_fd2_write_counted_without_fd_test`, `P_O4_partial_write_counts_nw`.
4. Six `DEFINITION` lines: `write_chunk`, `fd1_written`, `fs0`, `ext_bad`, `write_chunk_nosucc`,
   `write_chunk_nofd`.
5. Exactly three `CONTROL_OK` lines:
   `CONTROL_OK refund_L_OUT statement is the literal planned statement`,
   `CONTROL_OK refund_profile_a_sl_fd1 premise is the stored premise term`,
   `CONTROL_OK refund_profile_a_sl_fd1 is at ext := no_ext (no free ext)`.
6. `NOEXT_TERM no_ext : ...` shows the type `ffiname -> mlstring list # IO_fs -> word8 list -> word8 list ->
   (mlstring list # IO_fs) oracle_result` (the type printed on the `EXT_VARIABLE` line, no type variable).
7. Exactly four `CLOSURE_AXIOM` lines: `bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX`, `bool.BOOL_CASES_AX`.
8. `STORED_DEFINITIONS 6`. `STORED_THEOREMS` is 31, or 32 if `Define` also stores `fd1_written_ind`
   (TFL does this for non-primitive recursion; not determined). Record the number; it is not a criterion.
9. Read the printed statement after `CHECKED refund_profile_a_sl_fd1` and confirm by eye: no free `ext`;
   the premise equals the e4-0001 premise (e4-0001/stdout.log 297-331); the conclusion is as in the A3 report (handback text).
10. Produced objects exist: `LO-0001/.hol/objs/forge_refundLOutTheory.{sig,sml,dat}`.

## 5. Case E: L-EXIT-0 (only after O passes)

```zsh
cd $A
cp deps-LO.txt deps-LE.txt
print -l $A/LO-0001/forge_refundLOutTheory.sig $A/LO-0001/forge_refundLOutTheory.sml >> deps-LE.txt
cp $W/L_EXIT_v3.sml $A/LE-0001.sml
shasum -a 256 $W/L_EXIT_v3.sml $A/LE-0001.sml deps-LE.txt
FORGE_CPU_SECONDS=1200 ./go-routeA.sh LE-0001 LE-0001.sml deps-LE.txt ; echo "go exit $?"
grep -n "^CHECKED \|^DEFINITION \|^CONTROL_OK\|^UNEXPECTED_CONTROL_ACCEPTANCE\|^LEMMA_FAILED\|^DEFINITION_FAILED\|^OPEN_STATEMENT\|^CLOSURE_AXIOM\|^STORED_\|^EXACT_COMPLETE\|^USED " LE-0001/stdout.log | cut -c1-200
```
(`run_case.py` resolves `<dir>/forge_refundLOutTheory.sig` to `<dir>/.hol/objs/...`.)

Pass criteria for E (ALL):
1. `actual_exit` 0, `EXACT_COMPLETE`, `inputs_unchanged_after` true, `source_sha256` = SHA-256 of `L_EXIT_v3.sml`.
2. No `LEMMA_FAILED`, `UNEXPECTED_CONTROL_ACCEPTANCE`, `DEFINITION_FAILED` line.
3. Exactly these 6 `CHECKED` lines: `evaluate_Halt_reg`, `refund_halt_address`, `refund_profile_a_sl_halt`,
   `N_E1_status_collision`, `N_E2_silent_stop`, `N_E3_success_with_zero_register`.
4. Two `DEFINITION` lines: `cml_exit_status`, `cml_exit_stderr`.
5. One line that starts `OPEN_STATEMENT L-EXIT-V (type-checked only; not a theorem)`.
6. Exactly two `CONTROL_OK` lines: `CONTROL_OK refund_profile_a_sl_halt premise is the stored premise term`,
   `CONTROL_OK L-EXIT-V is not stored as a theorem`.
7. Four `CLOSURE_AXIOM` lines (bool's four). `STORED_THEOREMS 6`, `STORED_DEFINITIONS 2`.
8. `USED refund_profile_a_sl_fd1` prints the statement exported by LO-0001 (term-identical to its `CHECKED` text).

## 6. Negative and positive controls (inside the scripts)

| Control | What a pass shows | What it does NOT show |
|---|---|---|
| N-O1 | with a free `ext`, one non-basis event rewrites stdout and `fd1_written` sees nothing: the X1 form of L-OUT is false | nothing about `no_ext` |
| N-O2 | without the success test, a FAILED write (`numchars = LNIL`) counts "a" | — |
| N-O3 | without the fd test, an fd-2 write counts "a" | — |
| P-O4 (new) | a partial write (nw = 1 of n = 2) counts exactly "a"; nw = 2 counts "ab" | that the real kernel returns the right nw |
| N-E1 | status map is not injective at 0: x0 = 256 and x0 = 2^32 give status 0 | which x0 values occur |
| N-E2 | x0 = 2^32 has no stderr line | — |
| N-E3 | the swapped L-EXIT-0 (Success iff reg ≠ 0) is false: Success happens with reg 0 | — |
| structural | literal L-OUT statement; FD1 / HALT premise = stored premise term; FD1 has no free `ext`; L-EXIT-V not stored; 4 closure axioms; tag check | — |

A control that fails to PROVE means the control could not be established. It does not mean that the
weakened claim holds.

## 7. What a failure means

- `LEMMA_FAILED <name>` with `SHOW REMAINING <name>` goals: a tactic failed. It is a finding about the tactic,
  not evidence that the statement is false. Later lemmas that use it fail too (they get `TRUTH`); fix the
  first one. No theory is exported (the script raises `Fail` before `export_theory`).
- A static SML error (an unbound name; stderr shows it; no `LEMMA_FAILED`): every theorem name in the two
  scripts was checked against the pinned `.sig` files (the A3 report (handback text) section 1), but nothing was compiled.
- `NOEXT_FAILED`: `mk_thy_const` could not build `no_ext` at the type of `ext`. Record the printed type.
- CPU limit (no `EXACT_COMPLETE`, negative `actual_exit` or SIGXCPU): record CPU used and the last `SHOW`.
- Each new attempt: new case name (`LO-0002`, ...), new source copy, record the diff. At most five attempts per
  proof. Tactic-only changes only; any statement change needs old text, new text and the reason.
- Never add `cheat`, `mk_thm`, `new_axiom` or an oracle.

## 8. What to record (for ROADMAP.md / TRACKER.md; the orchestrator writes those files)

Actual exit, wall and CPU seconds, max RSS, markers (from `command.json`); every `CHECKED` statement as
printed; the `DEFINITION` lines; the four `CLOSURE_AXIOM` lines; `hash_parents.py` output
(`<case>.hashes.json`); `source_sha256` against the hash in the A3 report (handback text). Classify a pass as MACHINE-CHECKED
(MODEL). Nothing here is NATIVE; the native relations named in the A3 report (handback text) stay ASSUMPTION.

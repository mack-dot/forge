# Run plan: L-EXIT-0 v5, case LE-0001 (worker A14). NOTHING HERE HAS RUN.

Every command below is NOT RUN. Every exit code and marker below is EXPECTED, not actual.
Worker A14 started no HOL, Holmake or poly process. The orchestrator runs the case in the single HOL slot.

## 0. Inputs (SHA-256 at hand-off)

| Item | Path | SHA-256 |
|---|---|---|
| script | `results/night-shift-20261119/orch-A/exit/L_EXIT_v5.sml` | `2e2fbb423391b63fd7a2229c6f5296eaed1e0178d43ba799cffd6dcf9903f870` |
| base (v4) | `results/night-shift-20261119/orch-A/out-exit/L_EXIT_v4.sml` | `c7ea9aa13307e03b004ad11ddad4996fdcc3fba46477a7ea49f9190cd14f947f` |
| diff v4 to v5 | `results/night-shift-20261119/orch-A/exit/L_EXIT_v4_to_v5.diff` | `7bd4e15ba9d7e41892fd054a33b9b906953ec5b8df43074dd82ab2a0688f0a7d` |
| deps | `results/m1b-routeA-20261119/attempt-0001/deps-LO.txt` (125 lines) | `76bcd4909e81f7fc9a11144996e5b2f530e240afdb0cf62096aeff2e0209cc90` |
| runner | `results/m1b-routeA-20261119/attempt-0001/run_case.py` | `9c1064bde75415a0a592a5d4dc5c40f8554a223335eed261cd29ac4128823c3b` |
| wrapper | `results/m1b-routeA-20261119/attempt-0001/nightshift-run.sh` | `d253fb8d0acd7bd0b15841e9ace2154779503dac517028540f61e27f90fd2438` |

Name collision: `attempt-0001/LE-0001.sml` exists already and is the v3 copy (SHA-256 `af4137…5935`). No `LE-0001/`
folder exists. Step 2 overwrites the `.sml`. If the orchestrator wants to keep the v3 copy, use case `LE-0002`.

## 1. Mode

The script chooses the mode at run time: `DB.fetch "forge_refundLOut" "refund_profile_a_sl_fd1"`.
- `absent` (expected now): LO-0005 ended with `actual_exit` 1 and a static SML error (`LO-0005.go.log`;
  `LO-0005/stdout.log:262-265`). No `forge_refundLOut` theory exists. Deps = `deps-LO.txt` unchanged.
  New theory `forge_refundLExitGen`.
- `imported`: only after a PASSING L-OUT case `LO-xxxx`. Deps = `deps-LO.txt` + these two lines (in this order):
  `/Users/mackianni/forge/results/m1b-routeA-20261119/attempt-0001/LO-xxxx/forge_refundLOutTheory.sig`
  `/Users/mackianni/forge/results/m1b-routeA-20261119/attempt-0001/LO-xxxx/forge_refundLOutTheory.sml`
  New theory `forge_refundLExit`.

## 2. Commands (NOT RUN)

```zsh
A=/Users/mackianni/forge/results/m1b-routeA-20261119/attempt-0001
W=/Users/mackianni/forge/results/night-shift-20261119/orch-A/exit
cp $W/L_EXIT_v5.sml $A/LE-0001.sml
shasum -a 256 $W/L_EXIT_v5.sml $A/LE-0001.sml $A/deps-LO.txt
# absent mode:
cd $A && ./queue.sh le "LE-0001 1200 deps-LO.txt"
# imported mode (only after a passing L-OUT case): cp deps-LO.txt deps-LE.txt; append the two lines; use deps-LE.txt
grep -n "^LOUT_MODE\|^THEORY_NAME\|^CHECKED \|^AUX_OK\|^DEFINITION \|^CONTROL\|^UNEXPECTED_CONTROL_ACCEPTANCE\|^LEMMA_FAILED\|^DIAG_OK_UNDER\|^FAILED_LIST\|^STATEMENT_\|^FD1_WRITTEN_KIND\|^ARM8_RUN_IN\|^OPEN_STATEMENT\|^CLOSURE_AXIOM\|^STORED_\|^EXACT_COMPLETE\|^TIMEOUT\|^SHOW " $A/LE-0001/stdout.log | cut -c1-220
```
CPU limit 1200 s. Budget: loading the parents ~100–130 s (LO-0004: 81.7 s CPU, LO-0005: 100.5 s, total runs);
`evaluate_Halt_reg` at most 660 s (3 alternatives x 150 s, plus one 150 s diagnostic replay); others at most 240 s each.

## 3. Pass markers, mode `absent` (ALL required)

1. `command.json`: `actual_exit` 0; `markers` contains `EXACT_COMPLETE`; `inputs_unchanged_after` true;
   `source_sha256` = `2e2fbb42…f870`.
2. Lines `LOUT_MODE absent`, `THEORY_NAME forge_refundLExitGen`, `EXACT_COMPLETE_MODE absent`, `EXACT_COMPLETE`.
3. `FAILED_LIST ` empty; no line starts with `LEMMA_FAILED`, `UNEXPECTED_CONTROL_ACCEPTANCE`, `DEFINITION_FAILED`,
   `STATEMENT_TYPECHECK_FAILED`, `TIMEOUT_LOAD_FAILED`, `HALTPC_FAILED`.
4. Exactly 6 `CHECKED` lines: `evaluate_Halt_reg`, `machine_sem_of_evaluate_Halt`, `refund_halt_address`,
   `N_E1_status_collision`, `N_E2_silent_stop`, `N_E3_success_with_zero_register`. One `AUX_OK arm8_target_pc_reg`.
5. Two `DEFINITION` lines: `cml_exit_status`, `cml_exit_stderr`.
6. `STATEMENT_EVALUATE targetSem evaluate_Halt_reg`; `STATEMENT_ARM8_RUN <thy> refund_profile_a_sl_halt` (record
   `<thy>`; either value passes); `FD1_WRITTEN_KIND free variable (L-OUT absent)`;
   one line starting `STATEMENT_TYPECHECKS refund_profile_a_sl_halt (not attempted: L-OUT absent)`;
   one line starting `OPEN_STATEMENT L-EXIT-V`.
7. `CONTROL` lines, exactly: `CONTROL_OK evaluate_Halt_reg uses targetSem$evaluate`,
   `CONTROL_SKIPPED refund_profile_a_sl_halt (L-OUT absent)`, `CONTROL_OK L-EXIT-V is not stored as a theorem`,
   `CONTROL_OK stored theorems are the planned set (6)`.
8. Four `CLOSURE_AXIOM` lines (bool: SELECT_AX, INFINITY_AX, ETA_AX, BOOL_CASES_AX). `STORED_THEOREMS 6`,
   `STORED_DEFINITIONS 2`.
9. Object files `LE-0001/.hol/objs/forge_refundLExitGenTheory.{sig,sml,dat}` exist.
What an absent pass gives: L-EXIT-0 generic (MACHINE-CHECKED, MODEL). It does NOT give the refund instance.

## 4. Pass markers, mode `imported` (ALL required)

Items 1, 3, 5, 8 (with `STORED_THEOREMS 7`), plus:
2'. `LOUT_MODE imported`, `THEORY_NAME forge_refundLExit`, `EXACT_COMPLETE_MODE imported`, `EXACT_COMPLETE`.
4'. Exactly 7 `CHECKED` lines: the six of item 4 and `refund_profile_a_sl_halt`; `AUX_OK arm8_target_pc_reg`.
6'. `STATEMENT_EVALUATE targetSem evaluate_Halt_reg`; `ARM8_RUN_IN_STORED forge_refundCmlMainStep`;
   `ARM8_RUN_IN_FD1 <thy>` and `STATEMENT_ARM8_RUN <thy> refund_profile_a_sl_halt` (record both); `OPEN_STATEMENT L-EXIT-V`.
7'. `CONTROL_OK evaluate_Halt_reg uses targetSem$evaluate`,
   `CONTROL_OK refund_profile_a_sl_halt premise is the stored premise term`,
   `CONTROL_OK refund_profile_a_sl_halt uses forge_refundLOut$fd1_written`,
   `CONTROL_OK L-EXIT-V is not stored as a theorem`, `CONTROL_OK stored theorems are the planned set (7)`.
9'. `LE-0001/.hol/objs/forge_refundLExitTheory.{sig,sml,dat}` exist.

## 5. Failure reading

- `LEMMA_FAILED evaluate_Halt_reg`: read `SHOW TRY_ALL_ENTRY`, `STAGE_FAILED ehrA_*`, `SHOW EHR_LEAF_LEFT` (the leaf
  that no finisher closed). A tactic finding, not evidence against the statement. No export.
- `DIAG_OK_UNDER <name> assumed: <names>`: <name> closes only under the failed lemmas; it is NOT stored.
- Static SML error (stderr `Static Errors`): nothing was compiled by A14; fix and re-run as a new attempt.
- CPU limit: record CPU and the last `BEGIN`.

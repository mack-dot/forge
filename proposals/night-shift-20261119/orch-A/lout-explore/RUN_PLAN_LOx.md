# RUN PLAN LOx-0001 (L-OUT exploration; worker A16). NOT RUN.

This is an EXPLORATION run, not a proof attempt. It does not count as an L-OUT attempt.
It calls no `export_theory`. It stores no theorem of an open lemma. It proves nothing.

## Inputs
- Source: `/Users/USER/forge/results/night-shift-20261119/orch-A/lout-explore/LOx-0001.sml`
  SHA-256 `5ef71604873048d3b4e4f5e815406a87815a48f8d529232c05b574b031331d7d` (842 lines).
- Part 1 = `LO-0005.sml` lines 1-404 (SHA-256 `9db45d73…71bb30`). One line differs: `new_theory` name.
  Diff: `LOx-0001.vs-LO-0005.diff` (same folder).
- Deps: `deps-LO.txt` (unchanged, the LO-0005 deps).

## Command (orchestrator only, in the single HOL slot)
```
cd /Users/USER/forge/results/m1b-routeA-20261119/attempt-0001
cp /Users/USER/forge/results/night-shift-20261119/orch-A/lout-explore/LOx-0001.sml LOx-0001.sml
shasum -a 256 LOx-0001.sml   # must be 5ef71604…331d7d
./nightshift-run.sh LOx-0001 900 deps-LO.txt
```
Success of the RUN = `actual_exit 0` and marker `EXPLORE_COMPLETE` in `LOx-0001/command.json`.
That only means the exploration finished. It says nothing about the lemmas.

## What to read in `LOx-0001/stdout.log`
1. Part 1: 21 `CHECKED` lines (LO-0005 stdout has 21), as in LO-0005 (through `extract_no_ext_ExtCall`). Any `LEMMA_FAILED` here = regression.
2. `grep -n "^EXPLORE_\|^STEP\|^ALT_\|^VALIDATION\|CONST_IN_\(UNQ\|QUAL\|AGREE\|SPE\|FD1\)" stdout.log`
   - `STEP <lemma> <i> <label> goals N`, then the full goals (`GOAL_BEGIN … ASM j … CONCL … CONST_IN_… FREE_VARS … GOAL_END`).
   - `STEP_FAILED` + `GOALS_BEFORE_STEP` (goals before the failing step), then `ALT_WORKS` / `ALT_FAILED`, or `STEP_STUCK`.
   - `EXPLORE_CLOSED <lemma>` + `VALIDATION … concl_aconv_goal true hyps N`. N > 0: closed ONLY under the ASSUMEd
     statements listed as `VALIDATION_HYP`. `EXPLORE_OPEN` = goals left. `EXPLORE_ERROR` = parse or other error.
3. Explorations, in order (16):
   - `extract_no_ext_stdout_step/A3_path` - diagnostic: which unwrapped step of the LO-0005 tactic raises the
     FIRST_ASSUM error (expected candidates: `rename_event` or `pat_extract_mp`).
   - `…_step/ExtCall_fs_ffi_part`, `…_step/ExtCall_basis_other`, `…_step/SharedMem` - the three real cases.
   - `…_step/ExtCall` (cases A, B ASSUMEd), `…_step/event` (ExtCall, SharedMem ASSUMEd), `extract_no_ext_stdout_step`.
   - `extract_no_ext_stdout/nil`, `extract_no_ext_stdout/cons` (step lemma ASSUMEd), `extract_no_ext_stdout`.
   - `refund_profile_a_sl_fd1/ms_first_assum_ACCEPT`, `/ms_ASM_REWRITE_AGREE`, `/ms_ASM_REWRITE_GSYM_AGREE`:
     which ONE closes `arm8_run 27 s = SOME ms` (goal count 0 after the last step).
   - `refund_profile_a_sl_fd1/Success` (refund_L_OUT ASSUMEd), `/Resource_limit_hit` (refund_L_OUT_prefix ASSUMEd),
     `refund_profile_a_sl_fd1` (both cases ASSUMEd).
4. `CONST_IN_UNQUALIFIED_PARSE`, `CONST_IN_QUALIFIED_*`, `CONST_IN_AGREE_THEOREM`, `CONST_IN_SPE_NOEXT_THEOREM`,
   `CONST_IN_FD1_STATEMENT`: the theory of every `arm8_run` (and `no_ext`) constant.

## Next step (decision rule)
Only if every leaf exploration closes (`EXPLORE_CLOSED`) does a proof run LO-0006 make sense: it assembles the
working step sequences into real lemmas (no ASSUME). Otherwise record the first `STEP_STUCK` goal as the blocker.

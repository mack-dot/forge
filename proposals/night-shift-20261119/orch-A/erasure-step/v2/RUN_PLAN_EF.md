# RUN PLAN EFx-0001 (exploration) then EF-0001 (erasure frame v2). Worker A20. NOTHING HERE HAS RUN.

Every command and exit code below is PLANNED. No line in this file is a result.
Run only in the single HOL slot, by the orchestrator. `nightshift-run.sh` does the resource pre-check.

V = `/Users/USER/forge/results/night-shift-20261119/orch-A/erasure-step/v2`
A = `/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001`

## Inputs (SHA-256 measured by A20 with `shasum -a 256`, exit 0)
| File | SHA-256 |
|---|---|
| `V/EFx-0001.sml` (455 lines) | `68ba84150617582d39a55522b88f949b982ea389c2500a2ad2b9c5d7eddc1161` |
| `V/erasure_frame_v2.sml` (311 lines, DRAFT) | `06e8304d27cd9087a4b4ad1d3f6937d6c1bc4eec2ac3332f2981bd1a3d7c09ca` |
| `A/deps-ES.txt` (127 lines, unchanged; ends with the E1-0003 theory .sig/.sml) | `7b46255aac314b9d3da4f7d0a7b85a20337583ae8248f896fd3390d23865d3d4` |
| `A/ES-0002.sml` (base) | `7c0c3c512561709394eb9d55d03e89a571e61ea58585aacac3c10b69aa02a7e5` |
Diffs: `V/erasure_frame_v2.vs-ES-0002.diff`, `V/EFx-0001.vs-v2.diff`.

## Step 1: exploration (CPU 900 s)
```zsh
cd /Users/USER/forge/results/m1b-routeA-20261119/attempt-0001
cp /Users/USER/forge/results/night-shift-20261119/orch-A/erasure-step/v2/EFx-0001.sml EFx-0001.sml
shasum -a 256 EFx-0001.sml        # must be 68ba8415...1161
./nightshift-run.sh EFx-0001 900 deps-ES.txt ; echo "go exit $?"
```
Run success = `actual_exit 0` and marker `EXPLORE_COMPLETE` in `EFx-0001/command.json`. That only means the
exploration finished. It proves nothing and stores nothing (no save_thm, no export_theory).
Guess, not a result: load about 110 s; script 60-400 s (Run exploration is the largest part).

### What to read in `EFx-0001/stdout.log`
```zsh
grep -n "^ARB_IN_DEF\|^LITERAL_CASE\|^TYVAR_PROBE\|^EXPLORE_\|^STEP\|^ALT_\|^VALIDATION\|^PROVED_NOT_STORED\|^DIAG_OK_UNDER\|^LEMMA_FAILED\|^LEFT_GOALS\|^WOULD_FAIL_LIST\|^FAILED_SO_FAR\|_LITERAL \|^CPU" EFx-0001/stdout.log | cut -c1-300
```
1. Diagnosis D1: `ARB_IN_DEF write'SP true` and `ARB_IN_DEF BranchTo true` support D1; `false` refutes it
   (then read `DEF_TEXT` and `X1/X2 .../A_generic_steps` goals).
2. Diagnosis D2: `TYVAR_PROBE poly_assume closes false` and `inst64_assume closes true` confirm D2.
   Any other pair refutes D2.
3. For each of the 5 lemmas: `EXPLORE_CLOSED <lemma>/<plan>` with `VALIDATION ... concl_aconv_goal true hyps 0`
   names a plan that works; `STEP_STUCK` / `EXPLORE_OPEN` shows the first goal that blocks.
4. `PROVED_NOT_STORED frame_write_SP` etc.: the exact v2 tactic list worked (it is the v2 text).
   `WOULD_FAIL_LIST` empty and `W_STATEMENT_LITERAL true hyps 0`, `NF_STATEMENT_LITERAL true hyps 0`,
   `NSF_HYPS 0` = v2 is expected to pass as written (still UNCHECKED until EF-0001 runs).

## Step 2: proof run EF-0001 (only after A20 finalises v2 from the Step 1 log; CPU 600 s)
```zsh
cd /Users/USER/forge/results/m1b-routeA-20261119/attempt-0001
cp /Users/USER/forge/results/night-shift-20261119/orch-A/erasure-step/v2/erasure_frame_v2.sml EF-0001.sml
shasum -a 256 EF-0001.sml         # must equal the finalised digest that A20 reports
./nightshift-run.sh EF-0001 600 deps-ES.txt ; echo "go exit $?"
```
Theory: `forge_m1bErasureFrame` (parent `forge_m1bErasureV2`, case E1-0003). The script stops proof work at 420 s
script CPU so the summary is always reached.

### Pass markers (all required; none is a result until it is in `EF-0001/stdout.log`)
- actual exit 0 and `EXACT_COMPLETE`;
- no `REQUIRED_FAILED_LIST`, no `UNEXPECTED_CONTROL_ACCEPTANCE`, no `DIAG_OK_UNDER_LIST`;
- `PROVED W_nonvacuous`, `PROVED Next_frame`, `PROVED NextStateARM8_frame`, `PROVED frame_Run`;
- `CONTROL_OK Next_frame is the literal E1-0003 statement`, `CONTROL_OK W is the requested statement`,
  `CONTROL_OK W, Next_frame, NextStateARM8_frame have no hypotheses`, `CONTROL_OK frame_Run stored`;
- exactly four `CLOSURE_AXIOM bool.*` lines.

## Scope
Required results only: W and F (`Next_frame`, `NextStateARM8_frame`, through per-definition frame lemmas).
All erase lemmas, the branch class, the SP class, controls C1/C2 and the optional E3 stage of ES-0002 are dropped.

# RUN PLAN L2c (worker A19). NOT RUN. Every tactic UNCHECKED.

Case: `L2c-0001`. Theory: `forge_refundRouteA2c`. CPU limit: 1500 s (`FORGE_CPU_SECONDS=1500`).
Source: `routeA-L2c.sml`, SHA-256 `ca624cc50a313a318aea19cfa528b503a9df4cd297fc48e880662fab79818dc0`.

## Deps recipe
`deps-L2c.txt` = `deps-L2b2.txt` (129 lines, SHA-256 `4d7708dd…580c`) plus two lines:
```
/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001/L2b-0003/forge_refundRouteA2bTheory.sig
/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001/L2b-0003/forge_refundRouteA2bTheory.sml
```
A ready copy is in this folder: `deps-L2c.txt` (131 lines, SHA-256 `17d737f2…d054`).

## Commands (orchestrator only, single HOL slot; NOT RUN)
```
A=/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001
cp /Users/USER/forge/results/night-shift-20261119/orch-A/l2c/routeA-L2c.sml $A/L2c-0001.sml
cp /Users/USER/forge/results/night-shift-20261119/orch-A/l2c/deps-L2c.txt   $A/deps-L2c.txt
cd $A && ./nightshift-run.sh L2c-0001 1500 deps-L2c.txt
```

## Pass markers (all required)
- `actual_exit` 0 in `L2c-0001/command.json`; `EXACT_COMPLETE` in `markers`.
- stdout: `FAILED_LIST ` (empty), `DIAG_OK_UNDER_LIST ` (empty), no `LEMMA_FAILED`, no `UNEXPECTED_CONTROL_ACCEPTANCE`.
- stdout `CHECKED refund_profile_a_sl_events` and `CHECKED refund_events_premise_gives_l2r_third_premise`.
- stdout `CHECKED refund_valid_event_gives_VokY3` and `CHECKED refund_calls_premise_VokY3`.
- CONTROL_OK lines (9): R5 instance conclusion; R4 instance = R5 hypothesis 3; names instance = R5 hypothesis 1;
  ASSEMBLY conclusion identical; conclusion has no Vok; premise count; exactly premise 3 replaced by R6;
  no ffi_calls_ok in premises; R4 scope; R4 literal; event controls; one contract premise; closure has A2 and A2b.
- `REMAINING_PREMISE_R6 …` and `REMAINING_PREMISE_CONTRACT …` printed once each.
- `CLOSURE_AXIOM` exactly 4 (bool); `STORED_DEFINITIONS 2`; `.hol/objs/forge_refundRouteA2cTheory.{sig,sml,dat}` exist.
- OPTIONAL lines (`OPTIONAL_FAILED R4_L2b_literal`, `OPTIONAL_FAILED VokY3_rejects_close_and_open_in`) do not block.

## On failure
The harness never stores a failed lemma; dependants print `DIAG_OK_UNDER`. Read `TACTIC_ATTEMPT_FAILED`,
`STAGE_FAILED`, `UNSOLVED` and `SHOW` lines for the first failed lemma in this order: CFLEN, ZIPEQ, DIST, EVC/EVO,
EVR/EVW, EVI, WEQ, RBEL, RBEL2, RBA, TK, R4R/R4W, R4M, RMF2, NAMES, R4G, P3L, ASM, controls.

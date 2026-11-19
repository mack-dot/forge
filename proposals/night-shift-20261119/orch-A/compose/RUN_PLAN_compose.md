# Run plan: case MF-0001 (theory forge_refundModelFrame)

Status: NOT RUN. Every tactic is UNCHECKED. Worker A21 started no HOL process.

## Files

| File | SHA-256 |
|---|---|
| `compose/compose_v1.sml` | `30ad1d66299033d7cf8618c33666930d45b990a18a7cc681bd14b35dc4e33c66` |
| `compose/deps-MF.txt` (135 lines) | `953051bdb2352bececb3226b1085f363862f76c9f7f934a301d502641e9e7d9b` |

## Deps recipe (exact)

`deps-MF.txt` = `attempt-0001/deps-LO.txt` (125 lines, SHA-256 `76bcd490...cc90`), then these 10 lines, in this order:

```
/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001/PF-0004/forge_refundPrefixFreeTheory.sig
/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001/PF-0004/forge_refundPrefixFreeTheory.sml
/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001/PX-0001/forge_refundPrefixExactTheory.sig
/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001/PX-0001/forge_refundPrefixExactTheory.sml
/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001/L1-0001/forge_refundRouteA1Theory.sig
/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001/L1-0001/forge_refundRouteA1Theory.sml
/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001/L2-0003/forge_refundRouteA2Theory.sig
/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001/L2-0003/forge_refundRouteA2Theory.sml
/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001/LO-0006/forge_refundLOutTheory.sig
/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001/LO-0006/forge_refundLOutTheory.sml
```

The RouteA1 and RouteA2 lines are ADDED to the requested recipe (deps-LO + PF + PX + LO) for M1b.
RouteA1 is needed because L2-0003 was built on `deps-L2.txt` = `deps-LO.txt` + RouteA1 (same lines).
The contract theory is NOT a deps line. The script tries to load it at run time (see M3).

## Command (orchestrator, single HOL slot, after the slot is free)

```
cp /Users/USER/forge/results/night-shift-20261119/orch-A/compose/compose_v1.sml  /Users/USER/forge/results/m1b-routeA-20261119/attempt-0001/MF-0001.sml
cp /Users/USER/forge/results/night-shift-20261119/orch-A/compose/deps-MF.txt     /Users/USER/forge/results/m1b-routeA-20261119/attempt-0001/deps-MF.txt
cd /Users/USER/forge/results/m1b-routeA-20261119/attempt-0001
FORGE_CPU_SECONDS=900 ./go-routeA.sh MF-0001 MF-0001.sml deps-MF.txt
```

Heap: default `cake_compile_heap` (do not set FORGE_HEAP). CPU limit 900 s, wall 1200 s (run_case.py).
Fallback if the run fails ONLY in M3 or in the contract load: rerun as `MF-0002` with
`FORGE_MF_NO_CONTRACT=1` in the environment (forces CONTRACT_MODE absent; same file).

## Pass markers (all required)

- actual exit 0; marker `EXACT_COMPLETE`; `inputs_unchanged_after true`.
- `FAILED_LIST ` empty; `DIAG_OK_UNDER_LIST ` empty; no `LEMMA_FAILED`; no `UNEXPECTED_CONTROL_ACCEPTANCE`.
- `CHECKED refund_model_frame_decision`, `CHECKED refund_model_success_gives_frame`,
  `CHECKED refund_model_frame_decision_reach`, `CHECKED refund_strict_parse_empty_rejected`.
- `CONTROL_OK c1 ...`, `CONTROL_OK M1b premise ...`, `CONTROL_OK M1b conclusion ...`,
  `CONTROL_OK c2 ...`, `NOTE PREMISE_STILL_FALSE_FOR_REAL_FFI refund_env_ok_sl ...`,
  `NOTE M1B_PREMISE_UNPROVED ...`.
- exactly four `CLOSURE_AXIOM bool.*` lines.
- One `CONTRACT_MODE imported|absent` line. If imported: also `CHECKED refund_model_frame_meets_exported_contract`
  and `CONTROL_OK M3 premise ...`. If absent: `M3_NOT_ATTEMPTED` and `STATEMENT_TEXT_ONLY`.
- Record from stdout: the `CONST ...` lines (refund_fields must be `forge_refundCertifiedProg`),
  `ARM8_RUN_IN_FD1`, `PIECE L2R ms`, `PARENTS`.

## Expected (NOT actual) outcome

CONTRACT_MODE absent is the more probable mode: `load` needs `.ui/.uo` files, and contract-0001/.hol/objs
has only `.sig/.sml/.dat`. The `use` fallback is UNCHECKED.

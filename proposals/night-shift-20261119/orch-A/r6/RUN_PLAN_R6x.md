# RUN PLAN R6x-0001 (R6 exploration; worker A25). NOT RUN.

EXPLORATION run, not a proof attempt. No `export_theory`, no `save_thm`, no `new_definition`. It proves nothing.

## Inputs
- `/Users/mackianni/forge/results/night-shift-20261119/orch-A/r6/R6x-0001.sml` — SHA-256 `5b4a9809de417f90ee198c9f0081a51f8ec39642ef1fa46a38d43a5243136074` (465 lines).
  Stepper = `LOx-0001.sml` lines 420–525, byte-identical except `NAMED_CONSTS` (checked with `diff`).
- `/Users/mackianni/forge/results/night-shift-20261119/orch-A/r6/R6x-0001-cf.sml` — SHA-256 `0ebcea32cae9523a6333f198d3da2dc88d489242a6220212bbc72ca687a07b7e`.
  The main script reads it by ABSOLUTE path with `use`, inside a handler (it needs cfLib). Do not move it.
- `/Users/mackianni/forge/results/night-shift-20261119/orch-A/r6/deps-R6x.txt` — SHA-256 `ce8ebac18f6c3f8cef976274c2a7ceaa78e0c310f5ecc27ed330bcef75e18b0d`
  = `deps-L2c.txt` (131 lines, unchanged) + the two files of `forge_refundRouteA2c` (L2c-0001 export).

## Command (orchestrator only, single HOL slot)
```
cd /Users/mackianni/forge/results/m1b-routeA-20261119/attempt-0001
cp /Users/mackianni/forge/results/night-shift-20261119/orch-A/r6/R6x-0001.sml R6x-0001.sml
cp /Users/mackianni/forge/results/night-shift-20261119/orch-A/r6/deps-R6x.txt deps-R6x.txt
shasum -a 256 R6x-0001.sml deps-R6x.txt   # 5b4a9809…6074 and ce8ebac1…b0d
./nightshift-run.sh R6x-0001 1200 deps-R6x.txt
```
Run success = `actual_exit 0` and marker `EXPLORE_COMPLETE`. That says nothing about the lemmas.
Expected cost (guess): LOx-0001 took 117 s / 3.9 GB RSS; loading cfLib and basis_ffiLib can add minutes.

## What to read in `R6x-0001/stdout.log`
1. `grep -n "^LOAD_\|^FETCH_FAILED\|^THEORY_NAMES" stdout.log` — is `cfLib` (and `basis_ffiLib`) loadable in this session?
   `LOAD_FAILED cfLib` = the R-CF re-proof cannot run in the runner session; it then needs a Holmake build in a new
   directory (owner/orchestrator decision).
2. `STORED …` blocks: exact statements of the start points (refund_semantics, refund_main_valid, whole_prog_spec_IMP,
   call_main_thm2, parts_ok_def, ffi2heap_def, IO_def, IOFS_def, writei_spec, read_into_spec, refund_compile_correct_no_handler,
   refund_installed_from_entry_reduced_sl, refund_env_ok_sl_iff_installed_residual, refund_env_ok_sl_of_contract_on, …).
3. `CONST_IN …`: theory of every `evaluate`, `arm8_run`, `machine_sem`, `Success`, `encode`, … in the key statements.
4. `TYPECHECK_OK|FAILED P0…P5`: the route statements (P0 weaker predicate, P1 SRC-EV, P1w, P2 BEH-EV, P3 R6 discharge
   target with `R6_CONJUNCTS_FOUND 1 OTHER_PREMISES 12` expected, P4 L-CLK, P5 IOxV, P5b IOFS_V).
5. `grep -n "^EXPLORE_\|^STEP\|^ALT_\|^VALIDATION\|^STATEMENT_PARSE_FAILED\|^CF_PART\|^XSIMPL" stdout.log`
   - X1, X2 must close with `hyps 0`; X3 closes only `hyps 2` (X1, X2 ASSUMEd). X1+X2+X3 = L-CLK.
   - X4 `hyps 0`, X5 `hyps 1`, X6 `hyps 0`: the REPLAY COUNTEREXAMPLE (a read event with empty conf is replay-neutral
     and not valid). If all three close, R-REPLAY is refuted in HOL (model level).
   - X6w, X6c: the proposed weaker predicate rejects the same event and is implied by the stored one.
   - X7a `hyps 0`, X7 `hyps 1`: final source assembly lemma. X9: FFI_part_hprop of IOFS_V.
   - X8 (cf file): IOxV ==>> IOx with xsimpl.

## Decision rule
- If X1–X3 close: write `R6c-0001` (proof run) with L-CLK as stored lemmas (cheap, independent of the rest).
- If X4–X6 close: record R-REPLAY as refuted (new `unsure.md` entry by the orchestrator, not by this worker).
- If `cfLib` loads and X8/X9 close: next exploration `R6x-0002` = first steps of `read_into_spec_V` and `writei_spec_V`
  up to and through `xffi` (the step where the event list grows; the only real new proof obligation per FFI site).

## Statement change proposed (needs owner/orchestrator decision; NOT applied)
Old (L2c, `refund_valid_event_def`, read clause; L2c stdout lines 23–44):
`LENGTH ab = 4100 ∧ LENGTH nb = LENGTH ab ∧ TAKE 2 ab = n2w2 4096 ∧ HD nb = 0w`
New (P0): `LENGTH nb = LENGTH ab ∧ 4 ≤ LENGTH ab ∧ LENGTH ab < 65536 ∧ w22n [ab❲0❳; ab❲1❳] + 4 ≤ LENGTH ab ∧ HD nb = 0w`
Why: the CF layer knows the stdin buffer only by `instream_buffered_inv` (TextIOProofScript.sml 956–968:
`1028 ≤ LENGTH bcontent < 256²`), not as 4100. The exact form forces a new INSTREAM predicate through every
INSTREAM_STR spec on the path (+1–2 days). The new clause still gives VokY3 (x1 = 8 from conf length 8; bound;
¬msb x3 from x3 < 2^16). It weakens premise R6 (stronger theorem). Cost: L2c R4 and controls re-run (~7 min).
The write clause stays as is; IOFS_V then pins the iobuff length to 2052.

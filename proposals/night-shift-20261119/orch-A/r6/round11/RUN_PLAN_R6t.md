# RUN PLAN R6t (worker A36, round 11). NOT RUN.

Top and bottom glue of R6: (c) the initial heap satisfies the V-predicates; (d) the event link from a
characteristic-formula specification of `main` with `STDIO_V Inv` to `EVERY Inv io_events` of every behaviour of
`semantics_dec_list`. Two-file method of round 9. Every tactic is UNCHECKED. No file outside `round11/` was changed.

## Inputs (all in `/Users/USER/forge/results/night-shift-20261119/orch-A/r6/round11/`)
| file | role | SHA-256 |
|---|---|---|
| `R6tx-0001.sml` | EXPLORATION main (scratch theory, no export) | `6277ebceebff23bf638747eaf76ac3ca946044cd80232ffb6526fd9f09cbfa69` |
| `R6t-0001.sml` | PROOF main, theory `forge_refundR6Top` | `306ed6581e1c2edc3c5150b2aea96935b87494775d96902a69a0907912867e40` |
| `r6t_common.sml` | grammar fix, shortcuts, TH table, replay, statements | `b0229081410b4502526a0233cd47fdf24f26cdff1fbaa0a97f3b9aa6ee7a7054` |
| `r6t_steps.sml` | the ONE shared step-list file | `cd6c5fcf6045453f54abe84508587ceece6c1d8d63d1254fa5bdf7ca242f213d` |
| `r6t_explore_calls.sml` | exploration calls | `887e8c6296979efd656c1f56327056e3a1202c140efaee0487690abf60aee4a2` |
| `r6t_prove.sml` | proof calls | `2f34209a3db24e0a26d5cdc92036483f801941a7ea437ab24bc400d69386c9f3` |
| `deps-R6t.txt` | `deps-R6w.txt` (attempt folder, 137 lines, unchanged) + 2 lines `R6w-0004/forge_refundR6WriteTheory.{sig,sml}` | `37017fc87d46d9216ff959b3492b888de1a20e95ce7cbf3c69b7954d408cf279` |

The main files read the four `r6t_*.sml` files with `use` from the directory named once as a quoted string ending in
"/" (`R6TDIR`). `nightshift-run.sh` hashes them before and after.

## Commands (orchestrator only, single HOL slot)
```
cd /Users/USER/forge/results/m1b-routeA-20261119/attempt-0001
R=/Users/USER/forge/results/night-shift-20261119/orch-A/r6/round11
cp $R/R6tx-0001.sml R6tx-0001.sml; cp $R/deps-R6t.txt deps-R6t.txt
shasum -a 256 R6tx-0001.sml deps-R6t.txt     # 6277ebce...fa69, 37017fc8...f279
./nightshift-run.sh R6tx-0001 1800 deps-R6t.txt
# only if every REQUIRED lemma shows EXPLORE_HEAD_CLOSED (or TRY_HELPER_CLOSED):
cp $R/R6t-0001.sml R6t-0001.sml; shasum -a 256 R6t-0001.sml   # 306ed658...7e40
./nightshift-run.sh R6t-0001 1800 deps-R6t.txt
```
Run success of the exploration = `actual_exit 0` and marker `EXPLORE_COMPLETE`; it proves nothing.
Proof success = `actual_exit 0`, marker `EXACT_COMPLETE`, `CONTROL_OK stored init_heap_V`,
`CONTROL_OK stored whole_prog_spec_V_events`, `CONTROL_OK statement <name>` for each stored lemma, 4 closure axioms.
Cost guess (not measured): R6w-0004 took 153 s wall / 2.8 GB RSS; this adds EVAL on FLOOKUP and one xsimpl.

## What to read in `R6tx-0001/stdout.log`
1. `grep -n "^SURGERY_\|^STATEMENT_PARSE_FAILED\|^CONST " stdout.log` - the main-call text taken from the stored
   `basis_ffi.whole_prog_spec_semantics_prog`; each statement parses; theory of `encode`, `app`, `Terminate`, `Success`.
2. `grep -n "^TRY_HELPER_\|^EXPLORE_HEAD_\|^STEP_FAILED\|^ALT_\|^STEP_STUCK\|^DIAG_" stdout.log`.
3. For a stuck step: the goals printed after `GOALS_BEFORE_STEP`; repair only that step in `r6t_steps.sml`.
4. `IOFS_V_init_precond_copy`: second route for `IOFS_V_init` (copy of `IOFS_precond`, basis_ffiScript.sml 495-505).

## Lemma order (true = required)
parts_ok_basis_ffi, init_fs_part_IN, init_cl_part_IN, init_rt_part_IN, init_iobuff_IN, IOFS_V_init, STDIO_V_of_IOFS_V,
**init_heap_V** (deliverable c), FFI_part_IN_st2heap_FILTER, basis_proj2_names, every_basis_events, sem_satisfies_imp_V,
STDIO_V_FFI_part_hprop, IOxV_events_IN, STDIO_V_events, final_heap_events, **whole_prog_spec_V_events** (deliverable d)
- all required; whole_prog_spec_V_init (c + d composite) optional.

## Design decision (no COMMANDLINE_0 / RUNTIME_0 needed)
`call_main_thm2` (cfMainScript.sml 260-285) keeps the frame: `SPLIT3 (st2heap p st3) (h3,h2,h4)`. The two other FFI
parts of the initial heap (command line, runtime; events `[]`) are put in the FRAME `h2`, not in the precondition.
They stay in `st2heap` of the final state, so `ffi2heap_def` (cfStoreScript.sml 49-59) gives `FILTER` of their names
= `[]`. Condition: the main V-spec has precondition exactly `STDIO_V Inv fs` (as `refund_main_valid`,
forge_refundStdioProgScript.sml 20-24, has `STDIO fs`). The standard `whole_prog_spec` puts `COMMANDLINE cl` in the
precondition and drops it in the postcondition, so its event list is not controlled there.

## NOT covered
- The refund main V-spec (`refund_main_valid` with `STDIO_V refund_valid_event`): needs the read side (worker A35).
- The concrete refs fact for `refund_prog`: `res_st.refs = W8array bs1 :: W8array bs2 :: rest` with `LENGTH bs2 = 2052`
  (`is_refs_basis` gives only `2052 <=`; the allocation is `REPLICATE 2052 0w`, TextIOProgScript.sml 99-102).
  Recipe: the `EVAL_TAC` step of `prove_sem_thm` (basis_ffiLib.sml 81-91) on the refund Decls state.
- `init_state ... with eval_state := es` versus plain `init_state` (whole_prog_spec_IMP, basis_ffiScript.sml 1098-1101).
- The step from source `semantics_dec_list` to the machine-level R6 premise (compiler correctness, every_clock_events).

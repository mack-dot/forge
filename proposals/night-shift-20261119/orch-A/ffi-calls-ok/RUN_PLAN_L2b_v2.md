# Run plan: Route A L2b v2. Worker A8. NOTHING HERE HAS RUN. Supersedes sections 1, 3 and 5 of RUN_PLAN_L2b.md.

Every command is PLANNED; no exit code here is actual. One HOL process at a time.
F = `<HOME>/forge/results/night-shift-20261119/orch-A/ffi-calls-ok`, A = `<HOME>/forge/results/m1b-routeA-20261119/attempt-0001`.

Inputs: `F/routeA-L2b_v2.sml` (636 lines) sha256 ec2b72f67db0d2147e1f6b50df49c34df7eb7db3372119b53dc8f40c8c6ded2b;
`F/deps-L2b-v2.txt` (129 lines = `A/deps-L2.txt` + `A/L2-0003/.hol/objs/forge_refundRouteA2Theory.{sig,sml}`)
sha256 e913d11af601ee3af346244db7d804de1416175f4ebee6e633ec64e4e917f728.

```zsh
cd $A
cp $F/routeA-L2b_v2.sml L2b-0002.sml; cp $F/deps-L2b-v2.txt deps-L2b-v2.txt
shasum -a 256 L2b-0002.sml deps-L2b-v2.txt
FORGE_CPU_SECONDS=1500 ./go-routeA.sh L2b-0002 L2b-0002.sml deps-L2b-v2.txt ; echo "go exit $?"
grep -n "^BEGIN\|^D3_\|^CHECKED\|^TACTIC_\|^OPTIONAL_\|^CONTROL\|^UNEXPECTED\|^LEMMA_FAILED\|^DIAG\|^FAILED_LIST\|^STAGE_FAILED\|^SHOW UNSOLVED\|^TIMEOUT\|^L2R_THIRD\|^F_\|^STATEMENT\|^CLOSURE\|^STORED\|COMPLETE" L2b-0002/stdout.log | cut -c1-260
```
CPU limit 1500 s (L2b-0001 is the reference for load and the 19 lemmas that passed; v2 adds per-alternative limits of 180 s).

Pass criteria (ALL): `actual_exit` 0; `EXACT_COMPLETE`; `inputs_unchanged_after` true; `TIMEOUT_HELPER` line;
`D3_SOURCE imported forge_refundRouteA2.ffi_calls_ok_def` and `D3_MODE imported`; `FAILED_LIST` empty; `DIAG_OK_UNDER_LIST`
empty; no `LEMMA_FAILED`, no `UNEXPECTED_CONTROL_ACCEPTANCE`;
`CHECKED` for 22 required theorems = the 19 of RUN_PLAN_L2b.md §3 + `ffi_calls_ok_conj` + `refund_l2r_third_premise_close`
+ `refund_l2r_third_premise_close_and_rest`; one `L2R_THIRD_PREMISE` line (must be the premise printed in
`A/L2-0003/stdout.log` 139-144); `F_THEOREMS 2`; seven `CONTROL_OK` lines (G literal; G without oracle; close scope;
RC one premise; negations; F1 is the premise; F2 conclusion is the premise); eight `STATEMENT_TYPECHECKS`, `STATEMENTS_BAD 0`;
four `CLOSURE_AXIOM`; `STORED_DEFINITIONS 0`; `STORED_THEOREMS` = 22 + optional `CHECKED`.
Optional (an `OPTIONAL_FAILED` is a finding only): `ffi_calls_ok_mono`, `evaluate_clock_zero`,
`call_FFI_return_appends_its_event`, `returning_call_with_valid_event_gives_P`, `ffi_calls_ok_of_valid_events`,
`y3_event_predicate_admits_a_two_byte_read_array`.

Pass estimates (GUESSES, by reading only): G about 60 % (the disjunctive leaves of L2b-0001 are handled two ways, but the
other leaves of the new split order are unseen); CLOSE_OK given G about 70 %; RC, RCT, F1 given CLOSE_OK about 85 %; F2 given
CONJ (CHECKED in L2b-0001) about 70 % (higher-order match of the conjunction lambda); whole run exit 0 about 30-35 %.
If G fails, CL prints every unsolved leaf (`SHOW UNSOLVED G-leaf-<n>`): that is the input for v3.

Mutants (optional; each must FAIL): A: `sed '268s#EL 2 mc.ffi_names = ExtCall «close» /\\ ffi.oracle = basis_ffi_oracle ext ==>#EL 2 mc.ffi_names = ExtCall «close» ==>#'`
(expected `LEMMA_FAILED close_returning_calls_have_valid_lengths`); B: `sed '196d'` (premise 1 of G; expected
`LEMMA_FAILED ffi_calls_ok_of_returning_calls`). Check each with `diff` (one line) before the run.

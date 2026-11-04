Theory forge_refund_heap
Ancestors
  forge_refund_call
Libs
  preamble evaluateComputeLib

Theorem refund_caller_heap_returns:
  let result = evaluate_decs
      ((FST (THE (prim_sem_env ffi))) with <| clock := 32; refs := prior_refs |>)
      (refund_argument_env ffi charge request original remaining enabled opened candidate amount reason)
      refund_program
  in
    case SND result of
      Rval env =>
        nsLookup env.v (Short «answer») =
          SOME (refund_expected_tuple charge request original remaining enabled opened candidate amount reason) ∧
        (FST result).ffi = ffi
    | Rerr err => F
Proof
  EVAL_TAC >> gvs [concrete_bool_tests]
  >> rpt (IF_CASES_TAC >> gvs [concrete_bool_tests] >> EVAL_TAC)
  >> simp [concrete_bool_tests]
QED


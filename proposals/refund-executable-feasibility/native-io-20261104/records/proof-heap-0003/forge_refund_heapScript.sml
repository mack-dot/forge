Theory forge_refund_heap
Ancestors
  forge_refund_call rich_list
Libs
  preamble evaluateComputeLib

Theorem store_lookup_prefix:
  store_lookup (LENGTH prefix + n) (prefix ++ suffix) = store_lookup n suffix
Proof
  simp [store_lookup_def,EL_APPEND_EQN]
QED

Theorem store_assign_prefix:
  store_assign (LENGTH prefix + n) value (prefix ++ suffix) =
    OPTION_MAP (APPEND prefix) (store_assign n value suffix)
Proof
  rw [store_assign_def,EL_APPEND_EQN,rich_listTheory.LUPDATE_APPEND2]
QED

Theorem store_lookup_prefix_zero:
  store_lookup (LENGTH prefix) (prefix ++ suffix) = store_lookup 0 suffix
Proof
  mp_tac (Q.SPECL [‘prefix’,‘0’,‘suffix’] store_lookup_prefix) >> simp []
QED

Theorem store_assign_prefix_zero:
  store_assign (LENGTH prefix) value (prefix ++ suffix) =
    OPTION_MAP (APPEND prefix) (store_assign 0 value suffix)
Proof
  simp [store_assign_def,EL_APPEND_EQN,rich_listTheory.LUPDATE_APPEND2]
QED

val _ = computeLib.add_funs [listTheory.LENGTH_APPEND,
  listTheory.APPEND_ASSOC,store_lookup_prefix,store_assign_prefix,
  store_lookup_prefix_zero,store_assign_prefix_zero];

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


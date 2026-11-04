(* Bind the guard to the actual closure/prefix environment. Parser and stream
   execution are still premises, not established by this local theorem. *)
Theory forge_refundEntry
Ancestors
  forge_refundGuard
Libs
  preamble ml_progLib

Theorem refund_tail_rejects_in_env:
  rest ≠ «» ∧
  nsLookup env.v (Short «rest») = SOME (Litv (StrLit rest)) ∧
  nsLookup env.v (Short «=») = SOME eq_v ∧
  nsLookup env.c (Short «Fail») = SOME (1,ExnStamp 4) ⇒
  case evaluate ((initial:'ffi state) with clock := 32)
                env [refund_tail_expr] of
    (final, Rerr (Rraise exn)) =>
      Fail_exn «refund: trailing input» exn ∧
      final.refs = initial.refs ∧ final.ffi = initial.ffi
  | _ => F
Proof
  strip_tac >>
  simp [refund_tail_expr_def,
        evaluateTheory.evaluate_def, evaluateTheory.fix_clock_def,
        evaluateTheory.dec_clock_def, evaluateTheory.list_result_def,
        semanticPrimitivesTheory.getOpClass_def, semanticPrimitivesTheory.do_opapp_def,
        semanticPrimitivesTheory.do_app_def, semanticPrimitivesTheory.do_eq_def,
        semanticPrimitivesTheory.lit_same_type_def, semanticPrimitivesTheory.Boolv_def,
        semanticPrimitivesTheory.do_if_def, semanticPrimitivesTheory.do_con_check_def,
        semanticPrimitivesTheory.build_conv_def, namespaceTheory.nsOptBind_def,
        namespacePropsTheory.nsLookup_nsBind, mlbasicsProgTheory.eq_v_def,
        mlbasicsProgTheory.Fail_exn_def, ml_translatorTheory.STRING_TYPE_def]
QED

Definition refund_main_call_env_def:
  refund_main_call_env = FST (THE (do_opapp [refund_main_v;Conv NONE []]))
End

Theorem refund_actual_main_prefix:
  do_opapp [refund_main_v;Conv NONE []] =
  SOME (refund_main_call_env,
    Let (SOME « v0») (Con NONE [])
      (Let (SOME «stream»)
        (App Opapp [Var (Long «TextIO» (Short «openStdIn»)); Var (Short « v0»)])
        (Let (SOME «se»)
          (App Opapp [Var (Long «Sexp» (Short «inputSexp»)); Var (Short «stream»)])
          (Let (SOME «rest»)
            (App Opapp [Var (Long «TextIO» (Short «inputAll»)); Var (Short «stream»)])
            refund_tail_expr))))
Proof
  simp [refund_main_call_env_def, forge_refundProgTheory.refund_main_v_def,
        refund_tail_expr_def, semanticPrimitivesTheory.do_opapp_def,
        semanticPrimitivesTheory.find_recfun_def]
QED

Definition refund_actual_prefix_env_def:
  refund_actual_prefix_env stream se rest = refund_main_call_env with v :=
    nsBind «rest» (Litv (StrLit rest))
      (nsBind «se» se
        (nsBind «stream» stream
          (nsBind « v0» (Conv NONE []) refund_main_call_env.v)))
End

val main_value = rhs (concl forge_refundProgTheory.refund_main_v_def);
val main_env = hd (snd (strip_comb main_value));
val eq_lookup = ml_progLib.nsLookup_conv “nsLookup (^main_env).v (Short «=»)”;
val fail_lookup = ml_progLib.nsLookup_conv “nsLookup (^main_env).c (Short «Fail»)”;

Theorem refund_actual_prefix_lookups:
  nsLookup (refund_actual_prefix_env stream se rest).v (Short «rest») =
    SOME (Litv (StrLit rest)) ∧
  nsLookup (refund_actual_prefix_env stream se rest).v (Short «=») = SOME eq_v ∧
  nsLookup (refund_actual_prefix_env stream se rest).c (Short «Fail») =
    SOME (1,ExnStamp 4)
Proof
  simp [refund_actual_prefix_env_def, refund_main_call_env_def,
        forge_refundProgTheory.refund_main_v_def,
        semanticPrimitivesTheory.do_opapp_def, semanticPrimitivesTheory.find_recfun_def,
        semanticPrimitivesTheory.build_rec_env_def,
        namespacePropsTheory.nsLookup_nsBind, eq_lookup, fail_lookup]
QED

Theorem refund_actual_prefix_rejects:
  rest ≠ «» ⇒
  case evaluate ((initial:'ffi state) with clock := 32)
                (refund_actual_prefix_env stream se rest) [refund_tail_expr] of
    (final, Rerr (Rraise exn)) =>
      Fail_exn «refund: trailing input» exn ∧
      final.refs = initial.refs ∧ final.ffi = initial.ffi
  | _ => F
Proof
  strip_tac >> irule refund_tail_rejects_in_env >>
  simp [refund_actual_prefix_lookups]
QED

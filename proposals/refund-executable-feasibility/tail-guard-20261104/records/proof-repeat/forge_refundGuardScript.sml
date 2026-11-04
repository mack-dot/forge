(* Conditional behavior of the actual post-input continuation. This does not
   prove that stdin reaches this state or that accepted inputs produce output. *)
Theory forge_refundGuard
Ancestors
  forge_refundProg
Libs
  preamble ml_progLib

val main_value = rhs (concl (fetch "forge_refundProg" "refund_main_v_def"));
val main_env = hd (snd (strip_comb main_value));
val tail_let = find_term
  (can (match_term “Let (SOME «rest») input continuation”)) main_value;
val tail_expr = List.nth (snd (strip_comb tail_let), 2);
val eq_lookup = ml_progLib.nsLookup_conv
  “nsLookup (^main_env).v (Short «=»)”;
val fail_lookup = ml_progLib.nsLookup_conv
  “nsLookup (^main_env).c (Short «Fail»)”;

Definition refund_tail_expr_def:
  refund_tail_expr = ^tail_expr
End

Definition refund_tail_env_def:
  refund_tail_env rest se = ^main_env with v :=
    nsBind «rest» (Litv (StrLit rest))
      (nsBind «se» se (^main_env).v)
End

Theorem refund_tail_rejects:
  rest ≠ «» ⇒
  case evaluate ((initial:'ffi state) with clock := 32)
                (refund_tail_env rest se) [refund_tail_expr] of
    (final, Rerr (Rraise exn)) =>
      Fail_exn «refund: trailing input» exn ∧
      final.refs = initial.refs ∧ final.ffi = initial.ffi
  | _ => F
Proof
  strip_tac >>
  simp [refund_tail_expr_def, refund_tail_env_def,
        evaluateTheory.evaluate_def, evaluateTheory.fix_clock_def,
        evaluateTheory.dec_clock_def, evaluateTheory.list_result_def,
        semanticPrimitivesTheory.getOpClass_def, semanticPrimitivesTheory.do_opapp_def,
        semanticPrimitivesTheory.do_app_def, semanticPrimitivesTheory.do_eq_def,
        semanticPrimitivesTheory.lit_same_type_def, semanticPrimitivesTheory.Boolv_def,
        semanticPrimitivesTheory.do_if_def, semanticPrimitivesTheory.do_con_check_def,
        semanticPrimitivesTheory.build_conv_def, namespaceTheory.nsOptBind_def,
        namespacePropsTheory.nsLookup_nsBind, mlbasicsProgTheory.eq_v_def,
        mlbasicsProgTheory.Fail_exn_def, ml_translatorTheory.STRING_TYPE_def,
        eq_lookup, fail_lookup]
QED

val _ = print ("FORGE_SCOPE: conditional actual tail continuation only\n");

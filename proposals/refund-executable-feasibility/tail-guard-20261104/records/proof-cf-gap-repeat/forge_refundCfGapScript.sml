(* Check why the raw generated method cannot directly use the CF match rule.
   This is an applicability finding, not a theorem of refund correctness. *)
Theory forge_refundCfGap
Ancestors
  forge_refund_call cfNormalise
Libs
  preamble

val method_ast = rhs (concl (EVAL “refund_method_cml”));
val actual_match = find_term (can (match_term “Mat discriminant rows”)) method_ast;
val actual_discriminant = hd (snd (strip_comb actual_match));

Definition refund_raw_discriminant_def:
  refund_raw_discriminant = ^actual_discriminant
End

Theorem refund_raw_discriminant_not_a_cf_value:
  exp2v env refund_raw_discriminant = NONE
Proof
  simp [refund_raw_discriminant_def, exp2v_def]
QED

Theorem refund_raw_match_value_premise_impossible:
  ¬∃v. exp2v env refund_raw_discriminant = SOME v
Proof
  simp [refund_raw_discriminant_not_a_cf_value]
QED

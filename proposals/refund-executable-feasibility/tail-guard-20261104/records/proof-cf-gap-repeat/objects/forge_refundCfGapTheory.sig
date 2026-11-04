signature forge_refundCfGapTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val refund_raw_discriminant_def : thm
  
  (*  Theorems  *)
    val refund_raw_discriminant_not_a_cf_value : thm
    val refund_raw_match_value_premise_impossible : thm
end

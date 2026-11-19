signature forge_refundNonNegTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_fields_ints_bounded : thm
    val refund_fields_ints_bounded_proj : thm
    val refund_fields_negative_amount_rejected : thm
    val refund_fields_positive_witness : thm
    val refund_frame_decision_nonneg : thm
    val refund_model_frame_decision_nonneg : thm
    val refund_model_frame_decision_reach_nonneg : thm
    val refund_run_wire_output_nonneg : thm
    val refund_strict_parse_accepts_negative_frame : thm
end

signature forge_refundModelFrameTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val extend_with_resource_limit_single_success : thm
    val refund_fd1_frame_of_run : thm
    val refund_frame_accept_of_outcome : thm
    val refund_frame_accept_of_prefix : thm
    val refund_frame_contract_key : thm
    val refund_model_frame_decision : thm
    val refund_model_frame_decision_reach : thm
    val refund_model_frame_meets_exported_contract : thm
    val refund_model_success_gives_frame : thm
    val refund_outcome_prefix : thm
    val refund_strict_parse_common_prefix_rejected : thm
    val refund_strict_parse_empty_rejected : thm
    val refund_success_accept : thm
end

signature forge_refundModelFrameEventsTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_frame_contract_upgrade : thm
    val refund_model_frame_contract_of_reach : thm
    val refund_model_frame_decision_events : thm
    val refund_model_success_gives_frame_events : thm
    val refund_success_accept_of_run : thm
end

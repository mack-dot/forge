signature forge_refundSourceNonFailTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_behavior_valid_request_no_handler : thm
    val refund_source_nonfail : thm
    val refund_u298_exclusion_valid_request : thm
    val semantics_prog_Fail_expanded : thm
end

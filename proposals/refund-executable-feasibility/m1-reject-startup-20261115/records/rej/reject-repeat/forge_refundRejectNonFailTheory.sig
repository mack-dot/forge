signature forge_refundRejectNonFailTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val call_main_exn1 : thm
    val call_main_exn2 : thm
    val exn_spec_IMP : thm
    val refund_accept_semantics : thm
    val refund_behavior_stdin_no_handler : thm
    val refund_reject_semantics : thm
    val refund_source_nonfail_reject : thm
    val refund_source_nonfail_stdin : thm
    val refund_stdin_semantics : thm
    val refund_u298_exclusion_stdin : thm
    val sem_sat_weaken : thm
    val star_split_lemma : thm
end

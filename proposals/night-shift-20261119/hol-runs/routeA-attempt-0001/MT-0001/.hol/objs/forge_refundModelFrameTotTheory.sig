signature forge_refundModelFrameTotTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_ffi_contract_on_empty_predicate : thm
    val refund_ffi_tot_classification_ignores_counter : thm
    val refund_ffi_tot_empty_predicate_is_abstract : thm
    val refund_ffi_tot_observed_set : thm
    val refund_model_frame_totalised : thm
    val refund_model_success_totalised : thm
end

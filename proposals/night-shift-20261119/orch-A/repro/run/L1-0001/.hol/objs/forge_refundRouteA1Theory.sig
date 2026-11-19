signature forge_refundRouteA1Theory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val refund_close_abort_model_ffi_def : thm
    val refund_close_call_valid_def : thm
    val refund_ffi_contract_on_def : thm
    val refund_ffi_tot_def : thm
  
  (*  Theorems  *)
    val bad_return_ffi_totalised_with_empty_predicate_meets_contract : thm
    val close_abort_model_fails_stored_contract : thm
    val close_abort_model_satisfies_contract_on : thm
    val close_abort_model_totalised_meets_stored_contract : thm
    val contract_on_without_totalisation_is_not_the_stored_contract : thm
    val refund_close_call_valid_excludes_zero_alen : thm
    val refund_close_call_valid_rejects_u393_witness : thm
    val refund_env_ok_sl_of_contract_on : thm
    val refund_env_with_ffi_interfer_fields : thm
    val refund_ffi_contract_on_all_valid_is_the_stored_contract : thm
    val refund_ffi_contract_on_totalises : thm
    val refund_ffi_tot_all_valid_is_identity : thm
    val refund_ffi_tot_invalid : thm
    val refund_ffi_tot_shift_seq : thm
    val refund_ffi_tot_valid : thm
    val stored_contract_demands_return_at_u393_close_state : thm
end

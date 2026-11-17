signature forge_refundCallSiteTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val machine_reach_def : thm
    val machine_reach_n_def : thm
    val machine_step_def : thm
    val mc_static_eq_def : thm
    val refund_static_def : thm
  
  (*  Theorems  *)
    val call_FFI_return_keeps_oracle : thm
    val close_call_final_halts : thm
    val close_call_read_lengths : thm
    val close_call_return_lengths : thm
    val close_call_site_arguments : thm
    val close_call_unreadable_errors : thm
    val extcall_step_is_machine_step : thm
    val fail_not_in_success_limit : thm
    val ffi_outcome_not_in_success_limit : thm
    val machine_reach_n_compute : thm
    val machine_reach_n_evaluate : thm
    val machine_reach_refl : thm
    val normal_step_is_machine_step : thm
    val resource_limit_is_in_success_limit : thm
end

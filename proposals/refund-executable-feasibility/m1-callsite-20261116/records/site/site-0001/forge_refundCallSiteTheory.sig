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
    val machine_reach_n_compute : thm
    val machine_reach_n_evaluate : thm
    val normal_step_is_machine_step : thm
end

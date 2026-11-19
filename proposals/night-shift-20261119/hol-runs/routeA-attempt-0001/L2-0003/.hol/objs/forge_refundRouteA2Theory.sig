signature forge_refundRouteA2Theory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val ffi_calls_ok_def : thm
  
  (*  Theorems  *)
    val ffi_calls_ok_compute : thm
    val ffi_calls_ok_false_at_a_returning_call : thm
    val read_ffi_bytearray_ffi_interfer_update : thm
    val read_ffi_bytearrays_ffi_interfer_update : thm
    val refund_ffi_tot_evaluate_agree : thm
    val refund_ffi_tot_machine_sem_agree : thm
    val refund_mc_totalised_record : thm
    val refund_mc_totalised_record_fields : thm
    val refund_profile_a_sl_reach : thm
end

signature forge_refundShapeSatTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_abs_env_fields : thm
    val refund_ffi_contract_at_imp_on : thm
    val refund_shape_premises_hold_at_a_constructed_state : thm
    val refund_shape_premises_satisfiable : thm
    val refund_shape_premises_satisfiable_for_every_request : thm
    val refund_shape_run_is_accepted : thm
end

signature forge_refundSlideProfileATheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val refund_env_ok_sl_def : thm
    val refund_ffi_contract_at_def : thm
    val refund_stub_guard_ffi_def : thm
  
  (*  Theorems  *)
    val ffi_interfer_ok_iff_contract_sl : thm
    val pc_changing_environment_is_not_ok_sl : thm
    val refund_abs_env_is_ok_sl : thm
    val refund_abs_ffi_contract_at : thm
    val refund_env_ok_sl_at_slide_zero : thm
    val refund_env_ok_sl_iff_installed_residual : thm
    val refund_ffi_contract_at_link_base_is_the_old_contract : thm
    val refund_mc_environment_fields_sl : thm
    val refund_mc_register_fields_sl : thm
    val refund_profile_a_sl : thm
    val refund_profile_a_sl_abstract_env : thm
    val refund_profile_a_sl_every_machine_run : thm
    val refund_profile_a_sl_machine_premises_satisfiable_at_0x4000 : thm
    val slide_zero_instance_is_refund_profile_a_slide0 : thm
    val slide_zero_instance_is_refund_profile_a_slide0_every_machine_run : thm
    val slide_zero_stub_guard_ffi_fails_contract_at_slide_0x4000 : thm
    val stub_guard_ffi_satisfies_contract_at_its_base : thm
end

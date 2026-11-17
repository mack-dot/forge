signature forge_refundEnvModelTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val refund_abs_env_def : thm
    val refund_abs_ffi_def : thm
    val refund_bad_memory_ffi_def : thm
    val refund_bad_register_ffi_def : thm
    val refund_bad_return_ffi_def : thm
    val refund_ffi_contract_def : thm
    val refund_ffi_witness_state_def : thm
    val refund_id_interfer_def : thm
    val refund_outside_interfer_def : thm
  
  (*  Theorems  *)
    val arm8_target_state_rel_facts : thm
    val asm_write_bytearray_agree_on_domain : thm
    val clobbered_callee_saved_register_ffi_rejected : thm
    val ffi_interfer_ok_iff_contract : thm
    val interference_ok_arm8_iff : thm
    val pc_change_breaks_interference : thm
    val protected_memory_write_ffi_rejected : thm
    val protected_write_breaks_interference : thm
    val refund_abs_env_rest2 : thm
    val refund_abs_ffi_contract : thm
    val refund_behavior_abstract_env : thm
    val refund_ffi_contract_at_witness : thm
    val refund_ffi_names_list : thm
    val refund_id_interfer_ok : thm
    val refund_installed_abstract_env : thm
    val refund_mc_register_fields : thm
    val refund_outside_interfer_not_identity : thm
    val refund_outside_interfer_ok : thm
    val refund_u298_exclusion_abstract_env : thm
    val wrong_return_address_ffi_rejected : thm
end

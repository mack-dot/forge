structure forge_refundEnvModelTheory :> forge_refundEnvModelTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundEnvModelTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundResidualTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundEnvModel",
        hash = "ad0e87ad8e38659fd2f1eb71dce77f3a04eada68",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundEnvModel" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op wrong_return_address_ffi_rejected _ = ()
  val op wrong_return_address_ffi_rejected = TDB.find
    "wrong_return_address_ffi_rejected"
  fun op refund_u298_exclusion_abstract_env _ = ()
  val op refund_u298_exclusion_abstract_env = TDB.find
    "refund_u298_exclusion_abstract_env"
  fun op refund_outside_interfer_ok _ = ()
  val op refund_outside_interfer_ok = TDB.find "refund_outside_interfer_ok"
  fun op refund_outside_interfer_not_identity _ = ()
  val op refund_outside_interfer_not_identity = TDB.find
    "refund_outside_interfer_not_identity"
  fun op refund_outside_interfer_def _ = ()
  val op refund_outside_interfer_def = TDB.find
    "refund_outside_interfer_def"
  fun op refund_mc_register_fields _ = ()
  val op refund_mc_register_fields = TDB.find "refund_mc_register_fields"
  fun op refund_installed_abstract_env _ = ()
  val op refund_installed_abstract_env = TDB.find
    "refund_installed_abstract_env"
  fun op refund_id_interfer_ok _ = ()
  val op refund_id_interfer_ok = TDB.find "refund_id_interfer_ok"
  fun op refund_id_interfer_def _ = ()
  val op refund_id_interfer_def = TDB.find "refund_id_interfer_def"
  fun op refund_ffi_witness_state_def _ = ()
  val op refund_ffi_witness_state_def = TDB.find
    "refund_ffi_witness_state_def"
  fun op refund_ffi_names_list _ = ()
  val op refund_ffi_names_list = TDB.find "refund_ffi_names_list"
  fun op refund_ffi_contract_def _ = ()
  val op refund_ffi_contract_def = TDB.find "refund_ffi_contract_def"
  fun op refund_ffi_contract_at_witness _ = ()
  val op refund_ffi_contract_at_witness = TDB.find
    "refund_ffi_contract_at_witness"
  fun op refund_behavior_abstract_env _ = ()
  val op refund_behavior_abstract_env = TDB.find
    "refund_behavior_abstract_env"
  fun op refund_bad_return_ffi_def _ = ()
  val op refund_bad_return_ffi_def = TDB.find "refund_bad_return_ffi_def"
  fun op refund_bad_register_ffi_def _ = ()
  val op refund_bad_register_ffi_def = TDB.find
    "refund_bad_register_ffi_def"
  fun op refund_bad_memory_ffi_def _ = ()
  val op refund_bad_memory_ffi_def = TDB.find "refund_bad_memory_ffi_def"
  fun op refund_abs_ffi_def _ = ()
  val op refund_abs_ffi_def = TDB.find "refund_abs_ffi_def"
  fun op refund_abs_ffi_contract _ = ()
  val op refund_abs_ffi_contract = TDB.find "refund_abs_ffi_contract"
  fun op refund_abs_env_rest2 _ = ()
  val op refund_abs_env_rest2 = TDB.find "refund_abs_env_rest2"
  fun op refund_abs_env_def _ = ()
  val op refund_abs_env_def = TDB.find "refund_abs_env_def"
  fun op protected_write_breaks_interference _ = ()
  val op protected_write_breaks_interference = TDB.find
    "protected_write_breaks_interference"
  fun op protected_memory_write_ffi_rejected _ = ()
  val op protected_memory_write_ffi_rejected = TDB.find
    "protected_memory_write_ffi_rejected"
  fun op pc_change_breaks_interference _ = ()
  val op pc_change_breaks_interference = TDB.find
    "pc_change_breaks_interference"
  fun op interference_ok_arm8_iff _ = ()
  val op interference_ok_arm8_iff = TDB.find "interference_ok_arm8_iff"
  fun op ffi_interfer_ok_iff_contract _ = ()
  val op ffi_interfer_ok_iff_contract = TDB.find
    "ffi_interfer_ok_iff_contract"
  fun op clobbered_callee_saved_register_ffi_rejected _ = ()
  val op clobbered_callee_saved_register_ffi_rejected = TDB.find
    "clobbered_callee_saved_register_ffi_rejected"
  fun op asm_write_bytearray_agree_on_domain _ = ()
  val op asm_write_bytearray_agree_on_domain = TDB.find
    "asm_write_bytearray_agree_on_domain"
  fun op arm8_target_state_rel_facts _ = ()
  val op arm8_target_state_rel_facts = TDB.find
    "arm8_target_state_rel_facts"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundEnvModel"

end

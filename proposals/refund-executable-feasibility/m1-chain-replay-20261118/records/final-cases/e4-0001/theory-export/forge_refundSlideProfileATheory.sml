structure forge_refundSlideProfileATheory :> forge_refundSlideProfileATheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundSlideProfileATheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundProfileATheory forge_refundSlideSatTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundSlideProfileA",
        hash = "a8f4f9beaeac47cc975d23d89a8fb7f97497052e",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundSlideProfileA" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op stub_guard_ffi_satisfies_contract_at_its_base _ = ()
  val op stub_guard_ffi_satisfies_contract_at_its_base = TDB.find
    "stub_guard_ffi_satisfies_contract_at_its_base"
  fun op slide_zero_stub_guard_ffi_fails_contract_at_slide_0x4000 _ = ()
  val op slide_zero_stub_guard_ffi_fails_contract_at_slide_0x4000 =
    TDB.find "slide_zero_stub_guard_ffi_fails_contract_at_slide_0x4000"
  fun op slide_zero_instance_is_refund_profile_a_slide0_every_machine_run _
    = ()
  val op slide_zero_instance_is_refund_profile_a_slide0_every_machine_run =
    TDB.find
    "slide_zero_instance_is_refund_profile_a_slide0_every_machine_run"
  fun op slide_zero_instance_is_refund_profile_a_slide0 _ = ()
  val op slide_zero_instance_is_refund_profile_a_slide0 = TDB.find
    "slide_zero_instance_is_refund_profile_a_slide0"
  fun op refund_stub_guard_ffi_def _ = ()
  val op refund_stub_guard_ffi_def = TDB.find "refund_stub_guard_ffi_def"
  fun op refund_profile_a_sl_machine_premises_satisfiable_at_0x4000 _ = ()
  val op refund_profile_a_sl_machine_premises_satisfiable_at_0x4000 =
    TDB.find "refund_profile_a_sl_machine_premises_satisfiable_at_0x4000"
  fun op refund_profile_a_sl_every_machine_run _ = ()
  val op refund_profile_a_sl_every_machine_run = TDB.find
    "refund_profile_a_sl_every_machine_run"
  fun op refund_profile_a_sl_abstract_env _ = ()
  val op refund_profile_a_sl_abstract_env = TDB.find
    "refund_profile_a_sl_abstract_env"
  fun op refund_profile_a_sl _ = ()
  val op refund_profile_a_sl = TDB.find "refund_profile_a_sl"
  fun op refund_mc_register_fields_sl _ = ()
  val op refund_mc_register_fields_sl = TDB.find
    "refund_mc_register_fields_sl"
  fun op refund_mc_environment_fields_sl _ = ()
  val op refund_mc_environment_fields_sl = TDB.find
    "refund_mc_environment_fields_sl"
  fun op refund_ffi_contract_at_link_base_is_the_old_contract _ = ()
  val op refund_ffi_contract_at_link_base_is_the_old_contract = TDB.find
    "refund_ffi_contract_at_link_base_is_the_old_contract"
  fun op refund_ffi_contract_at_def _ = ()
  val op refund_ffi_contract_at_def = TDB.find "refund_ffi_contract_at_def"
  fun op refund_env_ok_sl_iff_installed_residual _ = ()
  val op refund_env_ok_sl_iff_installed_residual = TDB.find
    "refund_env_ok_sl_iff_installed_residual"
  fun op refund_env_ok_sl_def _ = ()
  val op refund_env_ok_sl_def = TDB.find "refund_env_ok_sl_def"
  fun op refund_env_ok_sl_at_slide_zero _ = ()
  val op refund_env_ok_sl_at_slide_zero = TDB.find
    "refund_env_ok_sl_at_slide_zero"
  fun op refund_abs_ffi_contract_at _ = ()
  val op refund_abs_ffi_contract_at = TDB.find "refund_abs_ffi_contract_at"
  fun op refund_abs_env_is_ok_sl _ = ()
  val op refund_abs_env_is_ok_sl = TDB.find "refund_abs_env_is_ok_sl"
  fun op pc_changing_environment_is_not_ok_sl _ = ()
  val op pc_changing_environment_is_not_ok_sl = TDB.find
    "pc_changing_environment_is_not_ok_sl"
  fun op ffi_interfer_ok_iff_contract_sl _ = ()
  val op ffi_interfer_ok_iff_contract_sl = TDB.find
    "ffi_interfer_ok_iff_contract_sl"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundSlideProfileA"

end

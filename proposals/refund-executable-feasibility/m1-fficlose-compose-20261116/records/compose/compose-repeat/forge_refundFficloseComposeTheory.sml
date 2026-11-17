structure forge_refundFficloseComposeTheory :> forge_refundFficloseComposeTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundFficloseComposeTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundFficloseAssertTheory
  forge_refundFficloseBridgeTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundFficloseCompose",
        hash = "f4cc2134b750c74ce0baf5ecc8bb42aa4d5a386b",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundFficloseCompose" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op zero_alen_reaches_assert_block _ = ()
  val op zero_alen_reaches_assert_block = TDB.find
    "zero_alen_reaches_assert_block"
  fun op refund_image_mem_agree _ = ()
  val op refund_image_mem_agree = TDB.find "refund_image_mem_agree"
  fun op read_bytearray_nonempty _ = ()
  val op read_bytearray_nonempty = TDB.find "read_bytearray_nonempty"
  fun op prefix_writes_the_frame _ = ()
  val op prefix_writes_the_frame = TDB.find "prefix_writes_the_frame"
  fun op overlapping_configuration_is_vacuous_case _ = ()
  val op overlapping_configuration_is_vacuous_case = TDB.find
    "overlapping_configuration_is_vacuous_case"
  fun op mem_dword_frame_agree _ = ()
  val op mem_dword_frame_agree = TDB.find "mem_dword_frame_agree"
  fun op invalid_clen_reaches_assert_block _ = ()
  val op invalid_clen_reaches_assert_block = TDB.find
    "invalid_clen_reaches_assert_block"
  fun op invalid_arguments_not_covered _ = ()
  val op invalid_arguments_not_covered = TDB.find
    "invalid_arguments_not_covered"
  fun op frame_in_protected_domain_not_covered _ = ()
  val op frame_in_protected_domain_not_covered = TDB.find
    "frame_in_protected_domain_not_covered"
  fun op fficlose_path_def _ = ()
  val op fficlose_path_def = TDB.find "fficlose_path_def"
  fun op fficlose_call_pre_witness _ = ()
  val op fficlose_call_pre_witness = TDB.find "fficlose_call_pre_witness"
  fun op fficlose_call_pre_satisfiable _ = ()
  val op fficlose_call_pre_satisfiable = TDB.find
    "fficlose_call_pre_satisfiable"
  fun op fficlose_call_pre_def _ = ()
  val op fficlose_call_pre_def = TDB.find "fficlose_call_pre_def"
  fun op fficlose_at_call_def _ = ()
  val op fficlose_at_call_def = TDB.find "fficlose_at_call_def"
  fun op fficlose_after_call _ = ()
  val op fficlose_after_call = TDB.find "fficlose_after_call"
  fun op ffi_close_accepts_only_valid_lengths _ = ()
  val op ffi_close_accepts_only_valid_lengths = TDB.find
    "ffi_close_accepts_only_valid_lengths"
  fun op corrupted_return_state_not_in_relation _ = ()
  val op corrupted_return_state_not_in_relation = TDB.find
    "corrupted_return_state_not_in_relation"
  fun op close_result_byte_def _ = ()
  val op close_result_byte_def = TDB.find "close_result_byte_def"
  fun op close_call_rel_inhabited _ = ()
  val op close_call_rel_inhabited = TDB.find "close_call_rel_inhabited"
  fun op close_call_rel_gives_return_state _ = ()
  val op close_call_rel_gives_return_state = TDB.find
    "close_call_rel_gives_return_state"
  fun op close_call_rel_def _ = ()
  val op close_call_rel_def = TDB.find "close_call_rel_def"
  fun op cake_fficlose_reaches_call _ = ()
  val op cake_fficlose_reaches_call = TDB.find "cake_fficlose_reaches_call"
  fun op cake_fficlose_path_inhabited _ = ()
  val op cake_fficlose_path_inhabited = TDB.find
    "cake_fficlose_path_inhabited"
  fun op cake_fficlose_path_contract_instance _ = ()
  val op cake_fficlose_path_contract_instance = TDB.find
    "cake_fficlose_path_contract_instance"
  fun op cake_fficlose_path _ = ()
  val op cake_fficlose_path = TDB.find "cake_fficlose_path"
  fun op asm_write_bytearray_same_content _ = ()
  val op asm_write_bytearray_same_content = TDB.find
    "asm_write_bytearray_same_content"
  fun op asm_write_bytearray_first_byte _ = ()
  val op asm_write_bytearray_first_byte = TDB.find
    "asm_write_bytearray_first_byte"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundFficloseCompose"

end

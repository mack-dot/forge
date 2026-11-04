structure forge_refundProgTheory :> forge_refundProgTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundProgTheory ... "
    else ()
  
  open Type Term Thm
  local open SexpProgTheory forge_refund_ioTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundProg",
        hash = "f2a45ed5c5185765c19d80f4b51e27207b57d073",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundProg" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op to_mlstring_v_thm _ = ()
  val op to_mlstring_v_thm = TDB.find "to_mlstring_v_thm"
  fun op to_mlstring_v_def _ = ()
  val op to_mlstring_v_def = TDB.find "to_mlstring_v_def"
  fun op to_int_v_thm _ = () val op to_int_v_thm = TDB.find "to_int_v_thm"
  fun op to_int_v_def _ = () val op to_int_v_def = TDB.find "to_int_v_def"
  fun op to_bool_v_thm _ = ()
  val op to_bool_v_thm = TDB.find "to_bool_v_thm"
  fun op to_bool_v_def _ = ()
  val op to_bool_v_def = TDB.find "to_bool_v_def"
  fun op refund_sum_constructors_bound _ = ()
  val op refund_sum_constructors_bound = TDB.find
    "refund_sum_constructors_bound"
  fun op refund_result_bindings _ = ()
  val op refund_result_bindings = TDB.find "refund_result_bindings"
  fun op refund_response_v_thm _ = ()
  val op refund_response_v_thm = TDB.find "refund_response_v_thm"
  fun op refund_response_v_def _ = ()
  val op refund_response_v_def = TDB.find "refund_response_v_def"
  fun op refund_method_native_v_def _ = ()
  val op refund_method_native_v_def = TDB.find "refund_method_native_v_def"
  fun op refund_main_v_def _ = ()
  val op refund_main_v_def = TDB.find "refund_main_v_def"
  fun op refund_library_program_def _ = ()
  val op refund_library_program_def = TDB.find "refund_library_program_def"
  fun op refund_handler_output_pattern_def _ = ()
  val op refund_handler_output_pattern_def = TDB.find
    "refund_handler_output_pattern_def"
  fun op refund_handler_input_pattern_def _ = ()
  val op refund_handler_input_pattern_def = TDB.find
    "refund_handler_input_pattern_def"
  fun op refund_handle_v_def _ = ()
  val op refund_handle_v_def = TDB.find "refund_handle_v_def"
  fun op refund_executable_program_def _ = ()
  val op refund_executable_program_def = TDB.find
    "refund_executable_program_def"
  fun op refund_entry_call _ = ()
  val op refund_entry_call = TDB.find "refund_entry_call"
  fun op refund_decoder_bindings _ = ()
  val op refund_decoder_bindings = TDB.find "refund_decoder_bindings"
  fun op refund_decode_v_thm _ = ()
  val op refund_decode_v_thm = TDB.find "refund_decode_v_thm"
  fun op refund_decode_v_def _ = ()
  val op refund_decode_v_def = TDB.find "refund_decode_v_def"
  fun op nsLookup_forge_refundProg_env_pfun_eqs _ = ()
  val op nsLookup_forge_refundProg_env_pfun_eqs = TDB.find
    "nsLookup_forge_refundProg_env_pfun_eqs"
  fun op nsLookup_forge_refundProg_env_9_pfun_eqs _ = ()
  val op nsLookup_forge_refundProg_env_9_pfun_eqs = TDB.find
    "nsLookup_forge_refundProg_env_9_pfun_eqs"
  fun op nsLookup_forge_refundProg_env_8_pfun_eqs _ = ()
  val op nsLookup_forge_refundProg_env_8_pfun_eqs = TDB.find
    "nsLookup_forge_refundProg_env_8_pfun_eqs"
  fun op nsLookup_forge_refundProg_env_7_pfun_eqs _ = ()
  val op nsLookup_forge_refundProg_env_7_pfun_eqs = TDB.find
    "nsLookup_forge_refundProg_env_7_pfun_eqs"
  fun op nsLookup_forge_refundProg_env_6_pfun_eqs _ = ()
  val op nsLookup_forge_refundProg_env_6_pfun_eqs = TDB.find
    "nsLookup_forge_refundProg_env_6_pfun_eqs"
  fun op nsLookup_forge_refundProg_env_5_pfun_eqs _ = ()
  val op nsLookup_forge_refundProg_env_5_pfun_eqs = TDB.find
    "nsLookup_forge_refundProg_env_5_pfun_eqs"
  fun op nsLookup_forge_refundProg_env_4_pfun_eqs _ = ()
  val op nsLookup_forge_refundProg_env_4_pfun_eqs = TDB.find
    "nsLookup_forge_refundProg_env_4_pfun_eqs"
  fun op nsLookup_forge_refundProg_env_3_pfun_eqs _ = ()
  val op nsLookup_forge_refundProg_env_3_pfun_eqs = TDB.find
    "nsLookup_forge_refundProg_env_3_pfun_eqs"
  fun op nsLookup_forge_refundProg_env_2_pfun_eqs _ = ()
  val op nsLookup_forge_refundProg_env_2_pfun_eqs = TDB.find
    "nsLookup_forge_refundProg_env_2_pfun_eqs"
  fun op nsLookup_forge_refundProg_env_1_pfun_eqs _ = ()
  val op nsLookup_forge_refundProg_env_1_pfun_eqs = TDB.find
    "nsLookup_forge_refundProg_env_1_pfun_eqs"
  fun op nsLookup_forge_refundProg_env_11_pfun_eqs _ = ()
  val op nsLookup_forge_refundProg_env_11_pfun_eqs = TDB.find
    "nsLookup_forge_refundProg_env_11_pfun_eqs"
  fun op nsLookup_forge_refundProg_env_10_pfun_eqs _ = ()
  val op nsLookup_forge_refundProg_env_10_pfun_eqs = TDB.find
    "nsLookup_forge_refundProg_env_10_pfun_eqs"
  fun op nsLookup_forge_refundProg_env_0_pfun_eqs _ = ()
  val op nsLookup_forge_refundProg_env_0_pfun_eqs = TDB.find
    "nsLookup_forge_refundProg_env_0_pfun_eqs"
  fun op forge_refundProg_st_def _ = ()
  val op forge_refundProg_st_def = TDB.find "forge_refundProg_st_def"
  fun op forge_refundProg_env_def _ = ()
  val op forge_refundProg_env_def = TDB.find "forge_refundProg_env_def"
  fun op forge_refundProg_env_9_def _ = ()
  val op forge_refundProg_env_9_def = TDB.find "forge_refundProg_env_9_def"
  fun op forge_refundProg_env_8_def _ = ()
  val op forge_refundProg_env_8_def = TDB.find "forge_refundProg_env_8_def"
  fun op forge_refundProg_env_7_def _ = ()
  val op forge_refundProg_env_7_def = TDB.find "forge_refundProg_env_7_def"
  fun op forge_refundProg_env_6_def _ = ()
  val op forge_refundProg_env_6_def = TDB.find "forge_refundProg_env_6_def"
  fun op forge_refundProg_env_5_def _ = ()
  val op forge_refundProg_env_5_def = TDB.find "forge_refundProg_env_5_def"
  fun op forge_refundProg_env_4_def _ = ()
  val op forge_refundProg_env_4_def = TDB.find "forge_refundProg_env_4_def"
  fun op forge_refundProg_env_3_def _ = ()
  val op forge_refundProg_env_3_def = TDB.find "forge_refundProg_env_3_def"
  fun op forge_refundProg_env_2_def _ = ()
  val op forge_refundProg_env_2_def = TDB.find "forge_refundProg_env_2_def"
  fun op forge_refundProg_env_1_def _ = ()
  val op forge_refundProg_env_1_def = TDB.find "forge_refundProg_env_1_def"
  fun op forge_refundProg_env_11_def _ = ()
  val op forge_refundProg_env_11_def = TDB.find
    "forge_refundProg_env_11_def"
  fun op forge_refundProg_env_10_def _ = ()
  val op forge_refundProg_env_10_def = TDB.find
    "forge_refundProg_env_10_def"
  fun op forge_refundProg_env_0_def _ = ()
  val op forge_refundProg_env_0_def = TDB.find "forge_refundProg_env_0_def"
  fun op dest_fail_v_thm _ = ()
  val op dest_fail_v_thm = TDB.find "dest_fail_v_thm"
  fun op dest_fail_v_def _ = ()
  val op dest_fail_v_def = TDB.find "dest_fail_v_def"
  fun op dest_expr_v_thm _ = ()
  val op dest_expr_v_thm = TDB.find "dest_expr_v_thm"
  fun op dest_expr_v_def _ = ()
  val op dest_expr_v_def = TDB.find "dest_expr_v_def"
  fun op dest9_v_thm _ = () val op dest9_v_thm = TDB.find "dest9_v_thm"
  fun op dest9_v_def _ = () val op dest9_v_def = TDB.find "dest9_v_def"
  fun op bind_v_thm _ = () val op bind_v_thm = TDB.find "bind_v_thm"
  fun op bind_v_def _ = () val op bind_v_def = TDB.find "bind_v_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundProg"

end

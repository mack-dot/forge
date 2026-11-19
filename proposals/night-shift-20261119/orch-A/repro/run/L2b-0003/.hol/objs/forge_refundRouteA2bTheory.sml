structure forge_refundRouteA2bTheory :> forge_refundRouteA2bTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundRouteA2bTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundRouteA2Theory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundRouteA2b",
        hash = "e461aaa044790e6f9830c9dd9673187ba8ce0a3a",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundRouteA2b" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op y3_event_predicate_admits_a_two_byte_read_array _ = ()
  val op y3_event_predicate_admits_a_two_byte_read_array = TDB.find
    "y3_event_predicate_admits_a_two_byte_read_array"
  fun op three_names_are_ExtCall _ = ()
  val op three_names_are_ExtCall = TDB.find "three_names_are_ExtCall"
  fun op rfb2_next_interfer_update _ = ()
  val op rfb2_next_interfer_update = TDB.find "rfb2_next_interfer_update"
  fun op rfb2_install_interfer_update _ = ()
  val op rfb2_install_interfer_update = TDB.find
    "rfb2_install_interfer_update"
  fun op rfb2_ffi_interfer_update _ = ()
  val op rfb2_ffi_interfer_update = TDB.find "rfb2_ffi_interfer_update"
  fun op returning_call_with_valid_event_gives_P _ = ()
  val op returning_call_with_valid_event_gives_P = TDB.find
    "returning_call_with_valid_event_gives_P"
  fun op returning_call_premise_is_needed _ = ()
  val op returning_call_premise_is_needed = TDB.find
    "returning_call_premise_is_needed"
  fun op refund_names_are_ExtCall _ = ()
  val op refund_names_are_ExtCall = TDB.find "refund_names_are_ExtCall"
  fun op refund_mc_close_fields _ = ()
  val op refund_mc_close_fields = TDB.find "refund_mc_close_fields"
  fun op refund_l2r_third_premise_close_and_rest _ = ()
  val op refund_l2r_third_premise_close_and_rest = TDB.find
    "refund_l2r_third_premise_close_and_rest"
  fun op refund_l2r_third_premise_close _ = ()
  val op refund_l2r_third_premise_close = TDB.find
    "refund_l2r_third_premise_close"
  fun op refund_ffi_calls_ok_close_totalised _ = ()
  val op refund_ffi_calls_ok_close_totalised = TDB.find
    "refund_ffi_calls_ok_close_totalised"
  fun op refund_ffi_calls_ok_close _ = ()
  val op refund_ffi_calls_ok_close = TDB.find "refund_ffi_calls_ok_close"
  fun op refund_close_premises_hold _ = ()
  val op refund_close_premises_hold = TDB.find "refund_close_premises_hold"
  fun op ffi_close_return_lengths _ = ()
  val op ffi_close_return_lengths = TDB.find "ffi_close_return_lengths"
  fun op ffi_calls_ok_of_valid_events _ = ()
  val op ffi_calls_ok_of_valid_events = TDB.find
    "ffi_calls_ok_of_valid_events"
  fun op ffi_calls_ok_of_returning_calls _ = ()
  val op ffi_calls_ok_of_returning_calls = TDB.find
    "ffi_calls_ok_of_returning_calls"
  fun op ffi_calls_ok_mono _ = ()
  val op ffi_calls_ok_mono = TDB.find "ffi_calls_ok_mono"
  fun op ffi_calls_ok_conj _ = ()
  val op ffi_calls_ok_conj = TDB.find "ffi_calls_ok_conj"
  fun op evaluate_clock_zero _ = ()
  val op evaluate_clock_zero = TDB.find "evaluate_clock_zero"
  fun op close_returning_calls_have_valid_lengths _ = ()
  val op close_returning_calls_have_valid_lengths = TDB.find
    "close_returning_calls_have_valid_lengths"
  fun op close_predicate_rejects_zero_alen _ = ()
  val op close_predicate_rejects_zero_alen = TDB.find
    "close_predicate_rejects_zero_alen"
  fun op close_predicate_fails_for_a_returning_zero_length_call _ = ()
  val op close_predicate_fails_for_a_returning_zero_length_call = TDB.find
    "close_predicate_fails_for_a_returning_zero_length_call"
  fun op close_instance_needs_the_basis_oracle _ = ()
  val op close_instance_needs_the_basis_oracle = TDB.find
    "close_instance_needs_the_basis_oracle"
  fun op call_FFI_return_keeps_oracle _ = ()
  val op call_FFI_return_keeps_oracle = TDB.find
    "call_FFI_return_keeps_oracle"
  fun op call_FFI_return_appends_its_event _ = ()
  val op call_FFI_return_appends_its_event = TDB.find
    "call_FFI_return_appends_its_event"
  fun op basis_close_return_lengths _ = ()
  val op basis_close_return_lengths = TDB.find "basis_close_return_lengths"
  fun op basis_close_call_returns_at_a_concrete_state _ = ()
  val op basis_close_call_returns_at_a_concrete_state = TDB.find
    "basis_close_call_returns_at_a_concrete_state"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundRouteA2b"

end

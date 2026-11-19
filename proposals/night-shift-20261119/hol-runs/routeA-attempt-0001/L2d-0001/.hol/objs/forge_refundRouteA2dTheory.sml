structure forge_refundRouteA2dTheory :> forge_refundRouteA2dTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundRouteA2dTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundModelFrameTheory forge_refundRouteA2cTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundRouteA2d",
        hash = "de804f507b5e087715dc506b95f03fffba9f847d",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundRouteA2d" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op shape_predicate_rejects_u393_and_zero_length_states _ = ()
  val op shape_predicate_rejects_u393_and_zero_length_states = TDB.find
    "shape_predicate_rejects_u393_and_zero_length_states"
  fun op shape_predicate_needs_the_basis_oracle _ = ()
  val op shape_predicate_needs_the_basis_oracle = TDB.find
    "shape_predicate_needs_the_basis_oracle"
  fun op shape_predicate_holds_at_the_concrete_write_call _ = ()
  val op shape_predicate_holds_at_the_concrete_write_call = TDB.find
    "shape_predicate_holds_at_the_concrete_write_call"
  fun op shape_predicate_holds_at_the_concrete_read_call _ = ()
  val op shape_predicate_holds_at_the_concrete_read_call = TDB.find
    "shape_predicate_holds_at_the_concrete_read_call"
  fun op remaining_premise_met_by_the_abstract_effect _ = ()
  val op remaining_premise_met_by_the_abstract_effect = TDB.find
    "remaining_premise_met_by_the_abstract_effect"
  fun op refund_profile_a_sl_shape _ = ()
  val op refund_profile_a_sl_shape = TDB.find "refund_profile_a_sl_shape"
  fun op refund_model_frame_decision_shape _ = ()
  val op refund_model_frame_decision_shape = TDB.find
    "refund_model_frame_decision_shape"
  fun op refund_l2r_third_premise_shape _ = ()
  val op refund_l2r_third_premise_shape = TDB.find
    "refund_l2r_third_premise_shape"
  fun op refund_ffi_calls_ok_shape_totalised _ = ()
  val op refund_ffi_calls_ok_shape_totalised = TDB.find
    "refund_ffi_calls_ok_shape_totalised"
  fun op refund_ffi_calls_ok_shape _ = ()
  val op refund_ffi_calls_ok_shape = TDB.find "refund_ffi_calls_ok_shape"
  fun op l2d_model_frame_contract_of_reach _ = ()
  val op l2d_model_frame_contract_of_reach = TDB.find
    "l2d_model_frame_contract_of_reach"
  fun op l2d_frame_contract_upgrade _ = ()
  val op l2d_frame_contract_upgrade = TDB.find "l2d_frame_contract_upgrade"
  fun op ffi_write_return_length _ = ()
  val op ffi_write_return_length = TDB.find "ffi_write_return_length"
  fun op ffi_write_conf_length_0_returns_error_byte _ = ()
  val op ffi_write_conf_length_0_returns_error_byte = TDB.find
    "ffi_write_conf_length_0_returns_error_byte"
  fun op ffi_read_short_array_returns_error_byte _ = ()
  val op ffi_read_short_array_returns_error_byte = TDB.find
    "ffi_read_short_array_returns_error_byte"
  fun op ffi_read_return_length _ = ()
  val op ffi_read_return_length = TDB.find "ffi_read_return_length"
  fun op ffi_read_conf_length_0_returns_error_byte _ = ()
  val op ffi_read_conf_length_0_returns_error_byte = TDB.find
    "ffi_read_conf_length_0_returns_error_byte"
  fun op ffi_open_in_return_length _ = ()
  val op ffi_open_in_return_length = TDB.find "ffi_open_in_return_length"
  fun op ffi_open_in_one_byte_array_returns_error_byte _ = ()
  val op ffi_open_in_one_byte_array_returns_error_byte = TDB.find
    "ffi_open_in_one_byte_array_returns_error_byte"
  fun op basis_write_return_length _ = ()
  val op basis_write_return_length = TDB.find "basis_write_return_length"
  fun op basis_write_call_returns_at_a_concrete_state _ = ()
  val op basis_write_call_returns_at_a_concrete_state = TDB.find
    "basis_write_call_returns_at_a_concrete_state"
  fun op basis_returning_calls_have_valid_shapes _ = ()
  val op basis_returning_calls_have_valid_shapes = TDB.find
    "basis_returning_calls_have_valid_shapes"
  fun op basis_returning_call_has_valid_shape _ = ()
  val op basis_returning_call_has_valid_shape = TDB.find
    "basis_returning_call_has_valid_shape"
  fun op basis_read_return_length _ = ()
  val op basis_read_return_length = TDB.find "basis_read_return_length"
  fun op basis_read_call_with_conf_length_0_returns _ = ()
  val op basis_read_call_with_conf_length_0_returns = TDB.find
    "basis_read_call_with_conf_length_0_returns"
  fun op basis_read_call_returns_at_a_concrete_state _ = ()
  val op basis_read_call_returns_at_a_concrete_state = TDB.find
    "basis_read_call_returns_at_a_concrete_state"
  fun op basis_oracle_fails_at_zero_length_read_and_u393_close _ = ()
  val op basis_oracle_fails_at_zero_length_read_and_u393_close = TDB.find
    "basis_oracle_fails_at_zero_length_read_and_u393_close"
  fun op basis_open_in_return_length _ = ()
  val op basis_open_in_return_length = TDB.find
    "basis_open_in_return_length"
  fun op arm8_ffi_bytearrays_lengths _ = ()
  val op arm8_ffi_bytearrays_lengths = TDB.find
    "arm8_ffi_bytearrays_lengths"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundRouteA2d"

end

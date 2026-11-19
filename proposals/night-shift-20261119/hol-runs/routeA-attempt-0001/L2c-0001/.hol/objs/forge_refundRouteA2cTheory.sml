structure forge_refundRouteA2cTheory :> forge_refundRouteA2cTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundRouteA2cTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundRouteA2bTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundRouteA2c",
        hash = "0048bb868998d3352423f87f18e4dc8458a88d68",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundRouteA2c" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op zip_equal_lengths_injective _ = ()
  val op zip_equal_lengths_injective = TDB.find
    "zip_equal_lengths_injective"
  fun op word_add_n2w_suc _ = ()
  val op word_add_n2w_suc = TDB.find "word_add_n2w_suc"
  fun op valid_write_event_shape _ = ()
  val op valid_write_event_shape = TDB.find "valid_write_event_shape"
  fun op valid_write_event_gives_VokY3 _ = ()
  val op valid_write_event_gives_VokY3 = TDB.find
    "valid_write_event_gives_VokY3"
  fun op valid_read_event_shape _ = ()
  val op valid_read_event_shape = TDB.find "valid_read_event_shape"
  fun op valid_read_event_gives_VokY3 _ = ()
  val op valid_read_event_gives_VokY3 = TDB.find
    "valid_read_event_gives_VokY3"
  fun op valid_event_rejects_the_N4_short_read_event _ = ()
  val op valid_event_rejects_the_N4_short_read_event = TDB.find
    "valid_event_rejects_the_N4_short_read_event"
  fun op valid_event_rejects_a_close_event _ = ()
  val op valid_event_rejects_a_close_event = TDB.find
    "valid_event_rejects_a_close_event"
  fun op valid_event_index_and_shape _ = ()
  val op valid_event_index_and_shape = TDB.find
    "valid_event_index_and_shape"
  fun op valid_event_accepts_a_write_event _ = ()
  val op valid_event_accepts_a_write_event = TDB.find
    "valid_event_accepts_a_write_event"
  fun op valid_event_accepts_a_read_event _ = ()
  val op valid_event_accepts_a_read_event = TDB.find
    "valid_event_accepts_a_read_event"
  fun op refund_valid_event_is_the_L2b_EVc_lambda _ = ()
  val op refund_valid_event_is_the_L2b_EVc_lambda = TDB.find
    "refund_valid_event_is_the_L2b_EVc_lambda"
  fun op refund_valid_event_gives_VokY3 _ = ()
  val op refund_valid_event_gives_VokY3 = TDB.find
    "refund_valid_event_gives_VokY3"
  fun op refund_valid_event_def _ = ()
  val op refund_valid_event_def = TDB.find "refund_valid_event_def"
  fun op refund_record_bytearrays _ = ()
  val op refund_record_bytearrays = TDB.find "refund_record_bytearrays"
  fun op refund_profile_a_sl_events _ = ()
  val op refund_profile_a_sl_events = TDB.find "refund_profile_a_sl_events"
  fun op refund_names_are_nonempty_ExtCall _ = ()
  val op refund_names_are_nonempty_ExtCall = TDB.find
    "refund_names_are_nonempty_ExtCall"
  fun op refund_mc_pointer_fields _ = ()
  val op refund_mc_pointer_fields = TDB.find "refund_mc_pointer_fields"
  fun op refund_ffi_names_distinct _ = ()
  val op refund_ffi_names_distinct = TDB.find "refund_ffi_names_distinct"
  fun op refund_events_premise_gives_l2r_third_premise _ = ()
  val op refund_events_premise_gives_l2r_third_premise = TDB.find
    "refund_events_premise_gives_l2r_third_premise"
  fun op refund_calls_premise_VokY3 _ = ()
  val op refund_calls_premise_VokY3 = TDB.find "refund_calls_premise_VokY3"
  fun op read_bytearray_EL_domain _ = ()
  val op read_bytearray_EL_domain = TDB.find "read_bytearray_EL_domain"
  fun op read_bytearray_EL _ = ()
  val op read_bytearray_EL = TDB.find "read_bytearray_EL"
  fun op open_in_event_is_not_valid _ = ()
  val op open_in_event_is_not_valid = TDB.find "open_in_event_is_not_valid"
  fun op first_two_elements_are_take_two _ = ()
  val op first_two_elements_are_take_two = TDB.find
    "first_two_elements_are_take_two"
  fun op close_event_is_not_valid _ = ()
  val op close_event_is_not_valid = TDB.find "close_event_is_not_valid"
  fun op call_FFI_return_keeps_length _ = ()
  val op call_FFI_return_keeps_length = TDB.find
    "call_FFI_return_keeps_length"
  fun op VokY3_rejects_close_and_open_in _ = ()
  val op VokY3_rejects_close_and_open_in = TDB.find
    "VokY3_rejects_close_and_open_in"
  fun op VokY3_is_the_L2b_lambda _ = ()
  val op VokY3_is_the_L2b_lambda = TDB.find "VokY3_is_the_L2b_lambda"
  fun op VokY3_def _ = () val op VokY3_def = TDB.find "VokY3_def"
  fun op R4_L2b_literal _ = ()
  val op R4_L2b_literal = TDB.find "R4_L2b_literal"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundRouteA2c"

end

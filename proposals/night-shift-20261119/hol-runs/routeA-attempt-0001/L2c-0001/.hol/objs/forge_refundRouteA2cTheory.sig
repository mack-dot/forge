signature forge_refundRouteA2cTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val VokY3_def : thm
    val refund_valid_event_def : thm
  
  (*  Theorems  *)
    val R4_L2b_literal : thm
    val VokY3_is_the_L2b_lambda : thm
    val VokY3_rejects_close_and_open_in : thm
    val call_FFI_return_keeps_length : thm
    val close_event_is_not_valid : thm
    val first_two_elements_are_take_two : thm
    val open_in_event_is_not_valid : thm
    val read_bytearray_EL : thm
    val read_bytearray_EL_domain : thm
    val refund_calls_premise_VokY3 : thm
    val refund_events_premise_gives_l2r_third_premise : thm
    val refund_ffi_names_distinct : thm
    val refund_mc_pointer_fields : thm
    val refund_names_are_nonempty_ExtCall : thm
    val refund_profile_a_sl_events : thm
    val refund_record_bytearrays : thm
    val refund_valid_event_gives_VokY3 : thm
    val refund_valid_event_is_the_L2b_EVc_lambda : thm
    val valid_event_accepts_a_read_event : thm
    val valid_event_accepts_a_write_event : thm
    val valid_event_index_and_shape : thm
    val valid_event_rejects_a_close_event : thm
    val valid_event_rejects_the_N4_short_read_event : thm
    val valid_read_event_gives_VokY3 : thm
    val valid_read_event_shape : thm
    val valid_write_event_gives_VokY3 : thm
    val valid_write_event_shape : thm
    val word_add_n2w_suc : thm
    val zip_equal_lengths_injective : thm
end

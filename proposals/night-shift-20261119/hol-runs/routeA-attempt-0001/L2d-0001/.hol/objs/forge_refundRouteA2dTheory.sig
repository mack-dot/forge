signature forge_refundRouteA2dTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val arm8_ffi_bytearrays_lengths : thm
    val basis_open_in_return_length : thm
    val basis_oracle_fails_at_zero_length_read_and_u393_close : thm
    val basis_read_call_returns_at_a_concrete_state : thm
    val basis_read_call_with_conf_length_0_returns : thm
    val basis_read_return_length : thm
    val basis_returning_call_has_valid_shape : thm
    val basis_returning_calls_have_valid_shapes : thm
    val basis_write_call_returns_at_a_concrete_state : thm
    val basis_write_return_length : thm
    val ffi_open_in_one_byte_array_returns_error_byte : thm
    val ffi_open_in_return_length : thm
    val ffi_read_conf_length_0_returns_error_byte : thm
    val ffi_read_return_length : thm
    val ffi_read_short_array_returns_error_byte : thm
    val ffi_write_conf_length_0_returns_error_byte : thm
    val ffi_write_return_length : thm
    val l2d_frame_contract_upgrade : thm
    val l2d_model_frame_contract_of_reach : thm
    val refund_ffi_calls_ok_shape : thm
    val refund_ffi_calls_ok_shape_totalised : thm
    val refund_l2r_third_premise_shape : thm
    val refund_model_frame_decision_shape : thm
    val refund_profile_a_sl_shape : thm
    val remaining_premise_met_by_the_abstract_effect : thm
    val shape_predicate_holds_at_the_concrete_read_call : thm
    val shape_predicate_holds_at_the_concrete_write_call : thm
    val shape_predicate_needs_the_basis_oracle : thm
    val shape_predicate_rejects_u393_and_zero_length_states : thm
end

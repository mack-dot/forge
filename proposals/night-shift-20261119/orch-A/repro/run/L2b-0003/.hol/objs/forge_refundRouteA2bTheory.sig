signature forge_refundRouteA2bTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val basis_close_call_returns_at_a_concrete_state : thm
    val basis_close_return_lengths : thm
    val call_FFI_return_appends_its_event : thm
    val call_FFI_return_keeps_oracle : thm
    val close_instance_needs_the_basis_oracle : thm
    val close_predicate_fails_for_a_returning_zero_length_call : thm
    val close_predicate_rejects_zero_alen : thm
    val close_returning_calls_have_valid_lengths : thm
    val evaluate_clock_zero : thm
    val ffi_calls_ok_conj : thm
    val ffi_calls_ok_mono : thm
    val ffi_calls_ok_of_returning_calls : thm
    val ffi_calls_ok_of_valid_events : thm
    val ffi_close_return_lengths : thm
    val refund_close_premises_hold : thm
    val refund_ffi_calls_ok_close : thm
    val refund_ffi_calls_ok_close_totalised : thm
    val refund_l2r_third_premise_close : thm
    val refund_l2r_third_premise_close_and_rest : thm
    val refund_mc_close_fields : thm
    val refund_names_are_ExtCall : thm
    val returning_call_premise_is_needed : thm
    val returning_call_with_valid_event_gives_P : thm
    val rfb2_ffi_interfer_update : thm
    val rfb2_install_interfer_update : thm
    val rfb2_next_interfer_update : thm
    val three_names_are_ExtCall : thm
    val y3_event_predicate_admits_a_two_byte_read_array : thm
end

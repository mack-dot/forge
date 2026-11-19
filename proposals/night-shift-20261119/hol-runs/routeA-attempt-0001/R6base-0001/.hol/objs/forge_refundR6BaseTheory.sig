signature forge_refundR6BaseTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val bad_read_event_is_not_valid : thm
    val bad_read_event_is_not_valid_w : thm
    val bad_read_event_replays_to_the_same_state : thm
    val clock_prefix_of_terminate : thm
    val every_clock_events : thm
    val every_of_three_parts : thm
    val every_prefix : thm
    val extract_fs_ignores_bad_read_event : thm
    val ffi_has_index_in_APPEND : thm
    val refund_valid_event_implies_weak : thm
    val replay_cannot_exclude_error_return_events : thm
end

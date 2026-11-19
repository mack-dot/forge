(* tr_part1.sml (worker W-trace, round 3). NOT RUN. Read after tr_common2.sml and tr_steps2.sml.
   PART1_NAMES = the 37 lemmas that closed in TRx-0003 (attempt-0001/TRx-0003/stdout.log 386-628, TRY_HELPER_CLOSED):
   the 31 required lemmas shift_seq_shift_seq ... fail_after, div_after, and the five toy controls. The entries of
   TR_LEMMAS1 are the UNCHANGED entries of tr_steps2.sml (same statements, same step lists; only the filter and the
   flag differ). Toy entries are kept only if TOY_DEFS_OK. Every kept entry is REQUIRED in part 1. *)
val PART1_NAMES =
  ["shift_seq_shift_seq", "shift_seq_0", "shift_seq_1_pred", "trace_next_interfer_ffi", "trace_next_interfer_shift",
   "trace_ffi_interfer_nil", "trace_ffi_interfer_step", "trace_ffi_interfer_shift", "trace_next_interfer_proj",
   "trace_next_interfer_ok", "trace_ffi_interfer_guard", "trace_ffi_interfer_off", "step_event_ok_upd",
   "ffi_event_ok_upd", "ffi_post_st_upd", "trace_ok_upd", "trace_st_upd", "evaluate_cong", "evaluate_zero",
   "evaluate_one_step_event", "evaluate_one_ffi_event", "trace_gen", "evaluate_follows_trace", "call_FFI_return_io",
   "ffi_post_st_io", "trace_io", "add_clock_swap", "prefix_of_halt", "fst_error", "term_after", "fail_after",
   "div_after", "toy_target_fields", "toy_encoded", "toy_trace_ok", "toy_trace_events", "toy_bad_rejected"];
val TR_LEMMAS1 =
  map (fn (n, t, s, _) => (n, t, s, true))
    (List.filter (fn (n, _, _, _) => Lib.mem n PART1_NAMES andalso
                                     (not (String.isPrefix "toy_" n) orelse !TOY_DEFS_OK)) TR_LEMMAS0);
val _ = pr ("PART1_SELECTED " ^ Int.toString (length TR_LEMMAS1) ^ " " ^ String.concatWith " " (map #1 TR_LEMMAS1));

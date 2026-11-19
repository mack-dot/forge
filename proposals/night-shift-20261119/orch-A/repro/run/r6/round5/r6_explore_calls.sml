(* r6_explore_calls.sml (worker A30, round 4). Read by R6x-0004.sml only, after r6_common.sml and r6_steps.sml.
   Head-goal exploration of the four lemmas with the shared step lists. NOT RUN. *)
val _ = explore_head "X9r_FFI_part_hprop_IOFS_V" (fn () => X9_STMT) X9_STEPS;
val _ = explore_head "X8r_IOxV_weakens_to_IOx" (fn () => X8_STMT) X8_STEPS;
val _ = explore_head "WRITEI_V_all_branches" (fn () => WRITEI_V) WRITEI_STEPS;
val _ = explore_head "READ_INTO_V_success_and_zero" (fn () => READ_INTO_V) READ_INTO_STEPS;

(* tr_select_fix.sml: TRx-0004 only. The list that tr_explore_calls.sml tries = part 1 (re-proved here, so the four have
   real prerequisites) followed by the four repaired lemmas (tr_steps_fix.sml). Toy entry dropped if TOY_DEFS_OK is false. *)
val TR_LEMMAS = TR_LEMMAS1 @
  List.filter (fn (n, _, _, _) => not (String.isPrefix "toy_" n) orelse !TOY_DEFS_OK) FIX_LEMMAS;
val _ = pr ("FIX_SELECTED " ^ Int.toString (length TR_LEMMAS));

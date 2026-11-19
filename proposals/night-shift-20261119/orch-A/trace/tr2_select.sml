(* tr2_select.sml: TR2-0001 only. The four repaired lemmas; the toy entry needs the toy definitions and the parent's
   toy lemmas (toy_target_fields, toy_encoded). trace_terminate and trace_fail are required. *)
val TR_LEMMAS =
  List.filter (fn (n, _, _, _) => not (String.isPrefix "toy_" n) orelse
                 (!TOY_DEFS_OK andalso List.all (fn m => can TH m) ["toy_target_fields", "toy_encoded"])) FIX_LEMMAS;
val _ = pr ("TR2_SELECTED " ^ String.concatWith " " (map #1 TR_LEMMAS));

(* tr_explore_calls.sml (worker W-trace, 2026-11-19). Read by TRx-0001.sml only, after tr_common.sml and tr_steps.sml.
   NOT RUN. = round13/r6r_explore_calls.sml reduced: (1) every statement is ASSUMEd into the table TH; (2) every lemma is
   tried in dependency order as a real proof; a closed, hypothesis-free lemma replaces its ASSUME in TH and is saved in
   the scratch theory (never exported); (3) explore_head prints every step of every lemma that did not close.
   Every tactic UNCHECKED. *)
val _ = List.app (fn (nm, t, _, _) => set_TH nm (ASSUME t)) TR_LEMMAS;
val _ = pr "TH_ASSUMED all statements";
val closed_names = ref ([] : string list);
fun try_helper ((nm, t, steps, _) : string * term * step list * bool) : unit =
  (pr ("TRY_HELPER_BEGIN " ^ nm);
   let val th = Tactical.TAC_PROOF (([], t), head_replay nm steps)
   in if null (hyp th) andalso aconv (concl th) t
      then (set_TH nm (save_thm (nm, th));
            closed_names := nm :: !closed_names;
            pr ("TRY_HELPER_CLOSED " ^ nm ^ " hyps 0"))
      else pr ("TRY_HELPER_HYPS " ^ nm ^ " " ^ Int.toString (length (hyp th)))
   end)
  handle e => pr ("TRY_HELPER_FAILED " ^ nm ^ " " ^ trunc 600 (General.exnMessage e));
val _ = List.app try_helper TR_LEMMAS;
val _ = List.app (fn (nm, t, steps, req) =>
          if Lib.mem nm (!closed_names) then ()
          else (pr ("EXPLORE_LEMMA " ^ nm ^ (if req then " required" else " optional"));
                explore_head nm (fn () => t) steps))
        TR_LEMMAS;
val _ = pr ("CLOSED_NAMES " ^ String.concatWith " " (rev (!closed_names)));
val _ = pr ("CLOSED_COUNT " ^ Int.toString (length (!closed_names)) ^ " of " ^ Int.toString (length TR_LEMMAS));

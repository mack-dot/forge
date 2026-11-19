(* r6t_explore_calls.sml (worker A36, round 11). Read by R6tx-0001.sml only, after r6t_common.sml and r6t_steps.sml.
   NOT RUN. = round9/r6w_explore_calls.sml with names R6W -> R6T and without the hprop_inj frame registration
   (this theory has no HPROP_INJ lemma). (1) Every statement is ASSUMEd into the table TH (closed statements, so
   later irule/drule see no free variable in a hypothesis), so each lemma is explored on its own. (2) All lemmas are
   then tried in dependency order as real proofs (head_replay, the same replay as the proof run); a closed,
   hypothesis-free lemma replaces its ASSUME in TH and is saved in the scratch theory (never exported).
   (3) explore_head prints every step of every lemma. (4) One extra exploration: the IOFS_precond copy for IOFS_V_init. *)
val _ = List.app (fn (nm, t, _, _) => set_TH nm (ASSUME t)) R6T_LEMMAS;
val _ = pr "TH_ASSUMED all statements";
fun diag_validation (nm : string) (t : term) (steps : step list) : unit =
  (let val (gs, vf) = head_replay nm steps ([], t) (Context.snapshot ())
       val d = !Globals.max_print_depth
   in if null gs
      then (Globals.max_print_depth := ~1;
            (let val th = vf []
             in pr ("DIAG_VALIDATION " ^ nm ^ " aconv " ^ Bool.toString (aconv (concl th) t) ^
                    " hyps " ^ Int.toString (length (hyp th)));
                pr ("DIAG_STATEMENT " ^ term_to_string t);
                pr ("DIAG_THEOREM " ^ term_to_string (concl th));
                List.app (fn h => pr ("DIAG_HYP " ^ trunc 3000 (term_to_string h))) (hyp th)
             end handle e => pr ("DIAG_VALIDATION_RAISED " ^ nm ^ " " ^ trunc 600 (General.exnMessage e)));
            Globals.max_print_depth := d)
      else pr ("DIAG_OPEN_GOALS " ^ nm ^ " " ^ Int.toString (length gs))
   end)
  handle e => pr ("DIAG_FAILED " ^ nm ^ " " ^ trunc 300 (General.exnMessage e));
fun try_helper ((nm, t, steps, _) : string * term * step list * bool) : unit =
  (pr ("TRY_HELPER_BEGIN " ^ nm);
   let val th = Tactical.TAC_PROOF (([], t), head_replay nm steps)
   in if null (hyp th) andalso aconv (concl th) t
      then (set_TH nm (save_thm (nm, th)); pr ("TRY_HELPER_CLOSED " ^ nm ^ " hyps 0"))
      else pr ("TRY_HELPER_HYPS " ^ nm ^ " " ^ Int.toString (length (hyp th)))
   end)
  handle e => (pr ("TRY_HELPER_FAILED " ^ nm ^ " " ^ trunc 600 (General.exnMessage e));
               diag_validation nm t steps);
val _ = List.app try_helper R6T_LEMMAS;
val _ = List.app (fn (nm, t, steps, req) =>
          (pr ("EXPLORE_LEMMA " ^ nm ^ (if req then " required" else " optional"));
           explore_head nm (fn () => t) steps))
        R6T_LEMMAS;
val _ = pr "EXPLORE_LEMMA IOFS_V_init_precond_copy extra";
val _ = explore_head "IOFS_V_init_precond_copy" (fn () => IOFSI) [("all", IOFSI_PRECOND_COPY, [])];

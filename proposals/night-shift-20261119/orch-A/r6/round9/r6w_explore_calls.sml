(* r6w_explore_calls.sml (worker A33, round 7; round 6 + all lemmas tried in order). Read by R6wx-0001.sml only, after r6w_common.sml and r6w_steps.sml.
   NOT RUN. (1) Every statement is ASSUMEd into the table TH, so each lemma is explored on its own.
   (2) The ten helper lemmas are then tried as real proofs (head_replay, the same replay as the proof run); a closed,
   hypothesis-free helper replaces its ASSUME in TH, is saved in the scratch theory (never exported), and the two
   HPROP_INJ helpers are registered as frame theorems (as the [hprop_inj] attribute does in TextIOProofScript.sml).
   (3) explore_head prints every step of every lemma. *)
val _ = List.app (fn (nm, t, _, _) => set_TH nm (ASSUME t)) R6W_LEMMAS;
val _ = pr "TH_ASSUMED all statements";
(* round8: after a failed TAC_PROOF, replay once outside TAC_PROOF; if no goal is left, print the theorem the
   validation builds next to the statement (R6wx-0002 print_spec_V: "Can't alpha convert"). *)
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
      then (set_TH nm (save_thm (nm, th));
            pr ("TRY_HELPER_CLOSED " ^ nm ^ " hyps 0");
            if Lib.mem nm R6W_HPROP_INJ
            then ((cfLetAutoLib.export_frame_thms [nm]; pr ("FRAME_THM_REGISTERED " ^ nm))
                  handle e => pr ("FRAME_THM_FAILED " ^ nm ^ " " ^ trunc 300 (General.exnMessage e)))
            else ())
      else pr ("TRY_HELPER_HYPS " ^ nm ^ " " ^ Int.toString (length (hyp th)))
   end)
  handle e => (pr ("TRY_HELPER_FAILED " ^ nm ^ " " ^ trunc 600 (General.exnMessage e));
               diag_validation nm t steps);
(* round7: try ALL lemmas in dependency order (not only the 10 helpers). Reason (R6wx-0001): xlet_auto_spec
   (cfLetAutoLib MP_ASSUML, line 326) fails on a spec with a hypothesis ("Could not find the hypothesis"), and
   irule/GEN_ALL cannot instantiate Inv and p when they are free in the ASSUME hypothesis. A real (closed)
   prerequisite removes both artifacts. *)
val _ = List.app try_helper R6W_LEMMAS;
val _ = List.app (fn (nm, t, steps, req) =>
          (pr ("EXPLORE_LEMMA " ^ nm ^ (if req then " required" else " optional"));
           explore_head nm (fn () => t) steps))
        R6W_LEMMAS;

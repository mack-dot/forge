(* nv_explore_calls.sml (worker W-nv). Read by NVx-0001.sml only, after nv_common.sml and nv_steps.sml. NOT RUN.
   UNCHECKED. Method of round13 r6r_explore_calls.sml: (1) every statement is ASSUMEd into the table TH; (2) for each
   lemma in dependency order: a WALK applies the steps one by one to the head goal and prints the goals after each
   step (each candidate under guarded_apply), then TRY_HELPER runs the SAME replay as the proof (head_replay) inside
   TAC_PROOF; a closed, hypothesis-free result replaces its ASSUME in TH and is saved in the scratch theory (never
   exported). *)
val _ = List.app (fn (nm, t, _, _) => set_TH nm (ASSUME t)) NV_LEMMAS;
val _ = pr "TH_ASSUMED all statements";
val WALK_SECS = 120;
fun show_goal_list (lemma : string) (gs : goal list) : unit =
  (pr ("  GOAL_COUNT " ^ Int.toString (length gs));
   List.app (fn g => showg ("GOAL " ^ lemma) g) (List.take (gs, Int.min (2, length gs))));
fun walk (lemma : string) (stmt : term) (steps : step list) : unit =
  let
    fun app1 (tac : tactic) (gs : goal list) : goal list =
      case gs of
        [] => raise mk_HOL_ERR "W-nv" "walk" "no goal left"
      | g :: rest =>
          let val ctxt = Context.snapshot ()
              val (gs1, _) = guarded_apply WALK_SECS (fn () => tac g ctxt)
          in gs1 @ rest end
    fun attempt (tac : tactic) (gs : goal list) : goal list option * string =
      (SOME (app1 tac gs), "")
      handle Timeout.TIMEOUT _ => (NONE, "TIMEOUT after " ^ Int.toString WALK_SECS ^ " s")
           | e => (NONE, General.exnMessage e)
    fun loop (i : int) (gs : goal list) (rest : step list) : unit =
      case rest of
        [] => if null gs then pr ("WALK_CLOSED " ^ lemma ^ " after_steps " ^ Int.toString (i - 1))
              else (pr ("WALK_OPEN " ^ lemma ^ " goals " ^ Int.toString (length gs)); show_goal_list lemma gs)
      | ((label, tac, alts) :: more) =>
          if null gs
          then pr ("WALK_CLOSED " ^ lemma ^ " after_steps " ^ Int.toString (i - 1) ^ " (" ^
                   Int.toString (length rest) ^ " later steps not needed)")
          else cands i label 0 (tac :: alts) gs more
    and cands (i : int) (label : string) (k : int) (cs : tactic list) (gs : goal list) (more : step list) : unit =
      case cs of
        [] => (pr ("WALK_STUCK " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label); show_goal_list lemma gs)
      | c :: others =>
          (case attempt c gs of
             (SOME gs1, _) =>
               (pr ("WALK_STEP " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " candidate " ^ Int.toString k ^
                    " goals " ^ Int.toString (length gs1));
                show_goal_list lemma gs1;
                loop (i + 1) gs1 more)
           | (NONE, msg) =>
               (pr ("WALK_CANDIDATE_FAILED " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " candidate " ^
                    Int.toString k ^ " " ^ trunc 800 msg);
                cands i label (k + 1) others gs more))
  in
    pr ("WALK_BEGIN " ^ lemma ^ " steps " ^ Int.toString (length steps));
    show_goal_list lemma [([], stmt)];
    loop 1 [([], stmt)] steps
  end
  handle e => pr ("WALK_ERROR " ^ lemma ^ " " ^ trunc 800 (General.exnMessage e));
val closed_names = ref ([] : string list);
fun try_helper ((nm, t, steps, req) : string * term * step list * bool) : unit =
  (pr ("TRY_HELPER_BEGIN " ^ nm ^ (if req then " required" else " optional"));
   let val th = Tactical.TAC_PROOF (([], t), head_replay nm steps)
   in if null (hyp th) andalso aconv (concl th) t
      then (set_TH nm (save_thm (nm, th));
            closed_names := nm :: !closed_names;
            pr ("TRY_HELPER_CLOSED " ^ nm ^ " hyps 0");
            tags nm th; pr ("TAGS_OK " ^ nm))
      else (pr ("TRY_HELPER_HYPS " ^ nm ^ " " ^ Int.toString (length (hyp th)));
            List.app (fn h => pr ("  HYP " ^ trunc 400 (term_to_string h))) (hyp th))
   end)
  handle e => pr ("TRY_HELPER_FAILED " ^ nm ^ " " ^ trunc 800 (General.exnMessage e));
val _ = List.app (fn (l as (nm, t, steps, _)) => (pr ("EXPLORE_LEMMA " ^ nm); walk nm t steps; try_helper l)) NV_LEMMAS;
val _ = pr ("CLOSED_NAMES " ^ String.concatWith " " (rev (!closed_names)));
val _ = pr ("REQUIRED_NOT_CLOSED " ^ String.concatWith " "
          (List.mapPartial (fn (nm, _, _, req) => if req andalso not (Lib.mem nm (!closed_names)) then SOME nm else NONE)
             NV_LEMMAS));

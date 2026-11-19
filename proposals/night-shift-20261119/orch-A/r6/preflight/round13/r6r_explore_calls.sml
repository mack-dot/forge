(* r6r_explore_calls.sml round13 (worker W-pre, static, UNCHECKED): = round12 copy with block (E) moved before (C).
   New order: (A) (B) (E) (C) (D) (F). No tactic changed. *)
(* r6r_explore_calls.sml (worker A37, round 12; base: worker A35, round 10). Read by R6rx-0001.sml only, after r6r_common.sml and r6r_steps.sml.
   NOT RUN. = round9/r6w_explore_calls.sml (ran in R6wx-0004: exit 0) with R6W_LEMMAS -> R6R_LEMMAS,
   R6W_HPROP_INJ -> R6R_HPROP_INJ, plus one NEW last block: the exploration-only head-goal walks R6R_EXPLORE_EXTRA
   (r6r_steps.sml), which cut the copied chains after each read_into/xapp call and print the goals there.
   (1) Every statement is ASSUMEd into the table TH. (2) Every lemma is tried in dependency order as a real proof;
   a closed, hypothesis-free lemma replaces its ASSUME in TH and is saved in the scratch theory (never exported).
   (3) explore_head prints every step of every lemma. *)
val _ = List.app (fn (nm, t, _, _) => set_TH nm (ASSUME t)) R6R_LEMMAS;
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
val closed_names = ref ([] : string list);
fun try_helper ((nm, t, steps, _) : string * term * step list * bool) : unit =
  (pr ("TRY_HELPER_BEGIN " ^ nm);
   let val th = Tactical.TAC_PROOF (([], t), head_replay nm steps)
   in if null (hyp th) andalso aconv (concl th) t
      then (set_TH nm (save_thm (nm, th));
            closed_names := nm :: !closed_names;
            pr ("TRY_HELPER_CLOSED " ^ nm ^ " hyps 0");
            if Lib.mem nm R6R_HPROP_INJ
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
(* round12 (worker A37): the order of the exploration is changed. Reason: in R6rx-0001 the V split walk ran past 13 min
   in one step without a STEP or TIMEOUT line (stdout.log ends at line 1096, mtime 07:38; still running at 07:53), so a
   step can outlast the 240 s limit and a hang loses every later walk. The walks with the most new information and the
   least risk come first; the V attempts come after them; the walk that needs the REAL V-spec comes last.
   (A) try_helper for every lemma except R6R_LATE_LEMMAS; (B) STR_V walk with the V statement ASSUMEd as a closed term;
   (C) V split walk; (D) try_helper for R6R_LATE_LEMMAS; (E) explore_head for each lemma of (A) that did not close;
   (F) STR_V split walk with the REAL V-spec, only if V closed in (D). *)
val _ = List.app try_helper (List.filter (fn (nm, _, _, _) => not (Lib.mem nm R6R_LATE_LEMMAS)) R6R_LEMMAS);
fun walk ((nm, t, steps) : string * term * step list) : unit =
  (pr ("EXPLORE_EXTRA " ^ nm); explore_head nm (fn () => t) steps);
val _ = walk R6R_EXPLORE_STR_CA;
(* round13 (worker W-pre): block (E) moved before (C); (C) and (D) can hang (R6rx-0001), (E) does not depend on them *)
val _ = List.app (fn (nm, t, steps, req) =>
          if Lib.mem nm (!closed_names) orelse Lib.mem nm R6R_LATE_LEMMAS then ()
          else (pr ("EXPLORE_LEMMA " ^ nm ^ (if req then " required" else " optional"));
                explore_head nm (fn () => t) steps))
        R6R_LEMMAS;
val _ = walk R6R_EXPLORE_V_SPLIT;
val _ = List.app try_helper (List.filter (fn (nm, _, _, _) => Lib.mem nm R6R_LATE_LEMMAS) R6R_LEMMAS);
val _ = if Lib.mem "refillBuffer_with_read_spec_V" (!closed_names) then walk R6R_EXPLORE_STR_SPLIT
        else pr "EXPLORE_EXTRA_SKIPPED refillBuffer_with_read_spec_STR_V__split (V-spec not closed)";
val _ = pr ("CLOSED_NAMES " ^ String.concatWith " " (rev (!closed_names)));

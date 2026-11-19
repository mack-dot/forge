(* round14 (worker W-top): order and flow changed (CHANGES.txt C5): lemmas run in R6T_EXPLORE_ORDER (cheap and
   independent first; the lemmas whose steps unfold the FFI oracle or run xsimpl/SPLIT_TAC last); for each lemma
   try_helper runs and, only when it does not close, explore_head runs at once (so a hang later loses no earlier output);
   diag_validation (a second full replay) runs only when the failure is not "all candidates failed". UNCHECKED. *)
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
fun is_step_failure (msg : string) : bool = String.isSubstring "all candidates failed" msg;
(* try_helper returns true when the lemma closed without hypotheses *)
fun try_helper ((nm, t, steps, _) : string * term * step list * bool) : bool =
  (pr ("TRY_HELPER_BEGIN " ^ nm);
   let val th = Tactical.TAC_PROOF (([], t), head_replay nm steps)
   in if null (hyp th) andalso aconv (concl th) t
      then (set_TH nm (save_thm (nm, th)); pr ("TRY_HELPER_CLOSED " ^ nm ^ " hyps 0"); true)
      else (pr ("TRY_HELPER_HYPS " ^ nm ^ " " ^ Int.toString (length (hyp th))); false)
   end)
  handle e => (let val msg = General.exnMessage e
               in pr ("TRY_HELPER_FAILED " ^ nm ^ " " ^ trunc 600 msg);
                  (if is_step_failure msg then pr ("DIAG_SKIPPED " ^ nm ^ " (a step failed; explore_head shows it)")
                   else diag_validation nm t steps);
                  false
               end);
(* topological order (every prerequisite read with TH comes earlier); cheap and independent lemmas first *)
val R6T_EXPLORE_ORDER =
  ["basis_proj2_names", "sem_satisfies_imp_V", "FFI_part_IN_st2heap_FILTER", "init_iobuff_IN", "STDIO_V_of_IOFS_V",
   "IOxV_events_IN", "STDIO_V_FFI_part_hprop", "STDIO_V_events", "every_basis_events", "final_heap_events",
   "whole_prog_spec_V_events", "parts_ok_basis_ffi", "init_fs_part_IN", "init_cl_part_IN", "init_rt_part_IN",
   "IOFS_V_init", "init_heap_V", "whole_prog_spec_V_init"];
val _ = if length R6T_EXPLORE_ORDER = length R6T_LEMMAS andalso
           List.all (fn (n, _, _, _) => Lib.mem n R6T_EXPLORE_ORDER) R6T_LEMMAS
        then pr "EXPLORE_ORDER_OK" else pr "EXPLORE_ORDER_MISMATCH (R6T_LEMMAS order is used)";
val R6T_RUN_LIST =
  if length R6T_EXPLORE_ORDER = length R6T_LEMMAS andalso
     List.all (fn (n, _, _, _) => Lib.mem n R6T_EXPLORE_ORDER) R6T_LEMMAS
  then map (fn n => valOf (List.find (fn (m, _, _, _) => m = n) R6T_LEMMAS)) R6T_EXPLORE_ORDER
  else R6T_LEMMAS;
val _ = List.app (fn (lem as (nm, t, steps, req)) =>
          if try_helper lem then ()
          else (pr ("EXPLORE_LEMMA " ^ nm ^ (if req then " required" else " optional"));
                explore_head nm (fn () => t) steps))
        R6T_RUN_LIST;
val _ = pr "EXPLORE_LEMMA IOFS_V_init_precond_copy extra";
val _ = explore_head "IOFS_V_init_precond_copy" (fn () => IOFSI) [("all", IOFSI_PRECOND_COPY, [])];

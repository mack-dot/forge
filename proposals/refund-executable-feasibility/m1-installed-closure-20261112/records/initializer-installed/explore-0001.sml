(* Exploration only: (1) explicit machine-model instance of the predicate;
   (2) memory_assumption from the published installed predicate.
   It stores no theorem and exports no theory. *)
use (valOf (OS.Process.getEnv "FORGE_PRELUDE"));
open proofManagerLib;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _ = new_theory "forge_refundInitializerInstalledExplore";
val _ = pr ("MODEL_GOAL " ^ term_to_string model_goal);
val _ = pr ("INSTALLED_TERM " ^ term_to_string installed_tm);
val _ = pr ("HEAP_REGS_DEF " ^ thm_to_string heap_regs_def);
fun goals_now () = (top_goals ()) handle _ => [];
fun proved () = ((top_thm (); true) handle _ => false);
fun clip t = let val s = term_to_string t in String.substring (s, 0, Int.min (900, size s)) end;
fun show label =
  (pr ("STATE " ^ label ^ " goals=" ^ Int.toString (length (goals_now ())));
   case goals_now () of
     [] => pr "NO_OPEN_GOAL"
   | (asms,gl)::_ => (List.app (fn t => pr ("ASSUMPTION " ^ clip t)) asms; pr ("GOAL " ^ clip gl); pr "END_GOAL"));
fun step label mk =
  ((e (mk ()); pr ("STEP_OK " ^ label); show label; true)
   handle ex => (pr ("STEP_FAIL " ^ label ^ " :: " ^ exn_to_string ex); false));
(* 1. machine model *)
val _ = set_goal ([], model_goal);
val _ = step "model:simp" (fn () => simp [is_arm8_machine_config_def]);
val _ = pr ("MODEL proved=" ^ Bool.toString (proved ()));
(* 2. installed ==> exists witnesses. good_init_state /\ conclusion *)
val _ = set_goal ([], installed_goal);
val _ = step "strip" (fn () => strip_tac);
val _ = step "unfold-installed" (fn () => fs [installed_def, heap_regs_def, LET_THM]);
val _ = step "abbrev" (fn () => qmatch_asmsub_abbrev_tac `good_init_state mc ms bytes cbspace t0 m0 dm0 sdm0`);
val _ = step "witnesses" (fn () => map_every qexists_tac [`t0`,`m0`,`dm0`,`sdm0`]);
val _ = step "good" (fn () => conj_tac >- (first_assum ACCEPT_TAC));
val _ = step "match-base" (fn () => match_mp_tac base_gen);
val _ = step "pred" (fn () => conj_tac >- (first_assum ACCEPT_TAC));
val _ = step "unfold-mem" (fn () => simp [memory_assumption_def, read_reg_def]);
val _ = step "bitmap-witness" (fn () => qexists_tac `bitmap_ptr`);
val _ = step "easy-conjuncts" (fn () => fs [MAP_MAP_o, AC WORD_ADD_ASSOC WORD_ADD_COMM]);
val _ = pr ("INSTALLED proved=" ^ Bool.toString (proved ()));
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

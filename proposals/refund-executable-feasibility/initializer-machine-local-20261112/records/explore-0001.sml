(* Exploration only: can the published ARM8 machine-config predicate discharge
   the configuration conditions of refund_initialization_code?  It stores no
   theorem and exports no theory. *)
load "forge_refundArm8ProofTheory";
open preamble backendProofTheory arm8_configProofTheory forge_refundSuccessfulInitializationTheory
     forge_refundInitializationStaticTheory forge_refundInitialStackCodeTheory;
open proofManagerLib;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _ = new_theory "forge_refundInitializerMachineExplore";
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
val base = forge_refundInitialStackCodeTheory.refund_initialization_code;
val pred = ``arm8_configProof$is_arm8_machine_config``;
val mc0 = hd (List.filter (fn v => fst (dest_var v) = "mc") (free_vars (concl base)));
val _ = pr ("MC_TYPE " ^ type_to_string (type_of mc0));
val _ = pr ("PRED_TYPE " ^ type_to_string (type_of pred));
val theta = match_type (type_of mc0) (fst (dom_rng (type_of pred)));
val base1 = INST_TYPE theta base;
val mc = inst theta mc0;
val save = hd (List.filter (fn v => fst (dest_var v) = "save_regs") (free_vars (concl base1)));
val base2 = INST [save |-> ``set (^mc).callee_saved_regs``] base1;
val (ante, conclusion) = dest_imp (concl base2);
val conds = strip_conj ante;
val _ = pr ("CONDITION_COUNT " ^ Int.toString (length conds));
fun only_mc t = List.all (fn v => aconv v mc) (free_vars t);
val indexed = Lib.enumerate 0 conds;
val _ = List.app (fn (i, c) => pr ("CONDITION " ^ Int.toString i ^ " config_only=" ^ Bool.toString (only_mc c) ^
   " free=" ^ String.concatWith "," (map (fst o dest_var) (free_vars c)) ^ "\n  " ^
   (if only_mc c then term_to_string c else String.substring (term_to_string c, 0, Int.min (160, size (term_to_string c)))))) indexed;
val kept = List.filter (not o only_mc) conds;
val goal = mk_imp (list_mk_conj (mk_comb (pred, mc) :: kept), conclusion);
val _ = pr ("KEPT_COUNT " ^ Int.toString (length kept));
fun goals_now () = (top_goals ()) handle _ => [];
fun proved () = ((top_thm (); true) handle _ => false);
fun show label =
  (pr ("STATE " ^ label ^ " goals=" ^ Int.toString (length (goals_now ())));
   List.app (fn (asms,gl) => pr ("OPEN_GOAL " ^
     String.substring (term_to_string gl, 0, Int.min (400, size (term_to_string gl))))) (goals_now ()));
fun step label mk =
  ((e (mk ()); pr ("STEP_OK " ^ label); show label; true)
   handle ex => (pr ("STEP_FAIL " ^ label ^ " :: " ^ exn_to_string ex); false));
val _ = set_goal ([], goal);
val _ = step "strip" (fn () => strip_tac);
val _ = step "match" (fn () => match_mp_tac base2);
val _ = step "split-accept" (fn () => rpt conj_tac >> TRY (first_assum ACCEPT_TAC));
val _ = step "config" (fn () => fs [is_arm8_machine_config_def] >> EVAL_TAC);
val _ = if proved () then true else step "config-all" (fn () => rpt (fs [is_arm8_machine_config_def] >> EVAL_TAC));
val _ = pr ("FINAL proved=" ^ Bool.toString (proved ()));
val _ = (let val th = top_thm (); val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  pr ("EXPLORE_TAGS oracles=" ^ String.concatWith "," ors ^ " axioms=" ^ Int.toString (length axs) ^
      " hyps=" ^ Int.toString (length (hyp th)));
  pr ("EXPLORE_ANTECEDENTS " ^ Int.toString (length (strip_conj (fst (dest_imp (concl th)))))) end) handle _ => ();
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

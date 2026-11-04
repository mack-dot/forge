open preamble proofManagerLib;
open forge_refundWholeProgTheory forge_refundStdioProgTheory cfMainTheory
     semanticPrimitivesTheory ml_translatorTheory ml_progTheory cfHeapsTheory
     cfTheory cfAppTheory evaluatePropsTheory evaluateTheory evaluate_decTheory
     namespaceTheory cfHeapsBaseTheory;
(* Check the frozen repaired tactic against the exact original saved goal.
   Direct pinned HOL interface, as established in U272. No Holmake retry. *)
val _ = Globals.max_print_depth := 1000;
val (assumptions, expected) = top_goal ();
val _ = if null assumptions then () else raise Fail "Saved goal has hypotheses";
val checked_refund_call_main_exception = prove (expected,
  rw [app_def,app_basic_def] >>
  first_x_assum drule >> fs [] >> strip_tac >> fs [] >>
  fs [cfHeapsBaseTheory.POSTe_def,cfHeapsBaseTheory.POST_def] >>
  Cases_on ‘r’ >> fs [cond_STAR] >> fs [cond_def] >>
  fs [Decls_def,evaluate_to_heap_def,evaluate_ck_def] >>
  drule evaluate_add_to_clock >>
  disch_then (qspec_then ‘ck2’ mp_tac) >> simp [] >>
  qpat_x_assum ‘_ env1 prog = _’ assume_tac >>
  drule evaluate_dec_list_add_to_clock >>
  disch_then (qspec_then ‘ck + 1’ mp_tac) >> simp [] >>
  rpt strip_tac >>
  qexists_tac ‘st'’ >> qexists_tac ‘v’ >> conj_tac
  >- (MAP_EVERY qexists_tac [‘ck + (ck1 + 1)’, ‘ck2 + st'.clock’] >>
      simp [SNOC_APPEND,evaluate_dec_list_append,extend_dec_env_def] >>
      simp [evaluate_dec_list_def,astTheory.pat_bindings_def] >>
      NTAC 3 (simp [Once evaluate_def]) >>
      simp [do_con_check_def,build_conv_def] >>
      fs [Once evaluate_def,lookup_var_def,nsLookup_nsAppend_Short] >>
      simp [dec_clock_def,pmatch_def,combine_dec_result_def,
            merge_env_def,empty_env_def] >>
      qpat_x_assum ‘SOME _ = do_opapp _’ (SUBST1_TAC o SYM) >>
      fs []) >>
  fs [] >> asm_exists_tac >> fs []);
val _ = if aconv (concl checked_refund_call_main_exception) expected then ()
        else raise Fail "Required statement changed";
val (ors,axs) = Tag.dest_tag (Thm.tag checked_refund_call_main_exception);
val _ = if null (hyp checked_refund_call_main_exception) andalso null axs andalso
  List.all (fn s => s = "DISK_THM") ors then ()
  else raise Fail "Unexpected theorem dependencies";
val _ = print ("CHECKED_REFUND_CALL_MAIN_EXCEPTION\n" ^ Parse.thm_to_string checked_refund_call_main_exception ^ "\n");
val _ = print ("CHECKED_ORACLES " ^ String.concatWith "," ors ^ "\n");
val _ = print "CHECKED_HYPOTHESES 0\nCHECKED_TAGGED_AXIOMS 0\nEXACT_SAVED_STATEMENT true\nDIRECT_PROOF_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

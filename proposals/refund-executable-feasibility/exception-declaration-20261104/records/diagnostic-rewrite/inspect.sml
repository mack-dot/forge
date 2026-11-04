(* PREPARED ONLY. NOT RUN. No theorem export. *)
val _ = Globals.max_print_depth := 1000;
fun showgoals () = List.app (fn (hs,tm) =>
  (List.app (fn h => print ("DIAG_HYP " ^ Parse.term_to_string h ^ "\n")) hs;
   print ("DIAG_GOAL " ^ Parse.term_to_string tm ^ "\n"))) (top_goals ());
fun finish label = (print ("DIAG_STOP " ^ label ^ "\n"); showgoals ();
  print "DIAG_INSPECTION_ONLY_NO_THEOREM_EXPORT\n";
  OS.Process.exit OS.Process.success);
fun step name tac =
  (print ("DIAG_STEP " ^ name ^ "\n"); e tac;
   print ("DIAG_STEP_OK " ^ name ^ "\n"))
  handle ex => (print ("DIAG_EXCEPTION " ^ General.exnMessage ex ^ "\n"); finish name);
step "app" (rw [app_def,app_basic_def]);
step "heap" (first_x_assum drule >> fs [] >> strip_tac >> fs []);
step "post" (fs [cfHeapsBaseTheory.POSTe_def,cfHeapsBaseTheory.POST_def]);
step "result" (Cases_on ‘r’ >> fs [cond_STAR] >> fs [cond_def]);
step "eval" (fs [Decls_def,evaluate_to_heap_def,evaluate_ck_def]);
step "clock-app" (drule evaluate_add_to_clock >> disch_then (qspec_then ‘ck2’ mp_tac) >> simp []);
step "clock-prefix" (qpat_x_assum ‘_ env1 prog = _’ assume_tac >> drule evaluate_dec_list_add_to_clock >> disch_then (qspec_then ‘ck + 1’ mp_tac) >> simp []);
step "strip" (rpt strip_tac);
step "state-witness" (qexists_tac ‘st'’);
step "exception-witness" (qexists_tac ‘v’);
step "conjunction" conj_tac;
step "branch-clock-witnesses" (MAP_EVERY qexists_tac [‘ck + (ck1 + 1)’, ‘ck2 + st'.clock’]);
step "branch-append" (simp [SNOC_APPEND,evaluate_dec_list_append,extend_dec_env_def]);
val _ = showgoals ();
step "branch-declaration" (simp [evaluate_dec_list_def,astTheory.pat_bindings_def]);
val _ = showgoals ();
step "branch-evaluate-1" (simp [Once evaluate_def]);
val _ = showgoals ();
step "branch-evaluate-2" (simp [Once evaluate_def]);
val _ = showgoals ();
step "branch-evaluate-3" (simp [Once evaluate_def]);
val _ = showgoals ();
step "branch-constructor" (simp [do_con_check_def,build_conv_def]);
val _ = showgoals ();
step "branch-lookup" (fs [Once evaluate_def,lookup_var_def,nsLookup_nsAppend_Short]);
val _ = showgoals ();
step "branch-result" (simp [dec_clock_def,pmatch_def,combine_dec_result_def,merge_env_def,empty_env_def]);
step "explicit-SYM-assumption" (qpat_x_assum ‘SOME _ = do_opapp _’ (assume_tac o SYM));
val _ = showgoals ();
step "after-SYM-fs" (fs []);
val _ = showgoals ();
val _ = finish "after-proposed-repair";

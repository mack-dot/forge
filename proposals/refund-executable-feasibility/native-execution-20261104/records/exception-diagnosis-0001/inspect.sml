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
val _ = finish "before-main-call-branch";

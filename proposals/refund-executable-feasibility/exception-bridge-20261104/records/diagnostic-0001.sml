val _ = Globals.max_print_depth := 200;
fun showgoals () = List.app (fn (_,tm) => print ("FORGE_OPEN_GOAL " ^ Parse.term_to_string tm ^ "\n")) (top_goals ());
fun step name tac = (print ("FORGE_STEP " ^ name ^ "\n"); e tac; print ("FORGE_STEP_OK " ^ name ^ "\n"))
  handle ex => (print ("FORGE_STEP_FAILED " ^ name ^ "\n"); showgoals (); OS.Process.exit OS.Process.failure);
step "app" (rw [app_def,app_basic_def]);
step "heap" (first_x_assum drule >> fs [] >> strip_tac >> fs []);
step "post" (fs [cfHeapsBaseTheory.POSTe_def,cfHeapsBaseTheory.POST_def]);
step "result" (Cases_on ‘r’ >> fs [cond_STAR] >> fs [cond_def]);
step "name" (rename1 ‘Q exn heap’);
step "eval" (fs [Decls_def,evaluate_to_heap_def,evaluate_ck_def]);
step "clock-app" (drule evaluate_add_to_clock >> disch_then (qspec_then ‘ck2’ mp_tac) >> simp []);
step "clock-prefix" (qpat_x_assum ‘_ env1 prog = _’ assume_tac >> drule evaluate_dec_list_add_to_clock >> disch_then (qspec_then ‘ck + 1’ mp_tac) >> simp []);
step "witness" (rpt strip_tac >> qexists_tac ‘st'’ >> qexists_tac ‘exn’ >> conj_tac);
step "main-call" (MAP_EVERY qexists_tac [‘ck + (ck1 + 1)’, ‘ck2 + st'.clock’] >>
 simp [SNOC_APPEND,evaluate_dec_list_append,extend_dec_env_def] >>
 simp [evaluate_dec_list_def,astTheory.pat_bindings_def] >>
 NTAC 3 (simp [Once evaluate_def]) >> simp [do_con_check_def,build_conv_def] >>
 fs [Once evaluate_def,lookup_var_def,nsLookup_nsAppend_Short] >>
 simp [dec_clock_def,pmatch_def,combine_dec_result_def,merge_env_def,empty_env_def]);
step "post-heap" (fs [] >> asm_exists_tac >> fs []);
val _ = if can top_goal () then (showgoals (); OS.Process.exit OS.Process.failure)
        else (print "FORGE_DIAGNOSTIC_GOAL_SOLVED\n"; OS.Process.exit OS.Process.success);

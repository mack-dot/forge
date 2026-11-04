val _ = Globals.max_print_depth := 200;
fun showgoals () = List.app (fn (_,tm) => print ("FORGE_OPEN_GOAL " ^ Parse.term_to_string tm ^ "\n")) (top_goals ());
fun step name tac = (print ("FORGE_STEP " ^ name ^ "\n"); e tac; print ("FORGE_STEP_OK " ^ name ^ "\n"))
  handle ex => (print ("FORGE_STEP_FAILED " ^ name ^ " " ^ "\n"); showgoals (); OS.Process.exit OS.Process.failure);
step "enter" (rw [] >> xcf "refund_main" st);
step "none" (xlet ‘POSTv v. &OPTION_TYPE FILENAME NONE v * STDIO fs’ >- (xcon >> xsimpl >> simp [std_preludeTheory.OPTION_TYPE_def]));
step "read" (xlet ‘POSTv v. &OPTION_TYPE STRING_TYPE (SOME (implode text)) v * STDIO (fastForwardFD fs 0)’ >- (xapp_spec inputAllFrom_NONE_spec >> xsimpl >> fs [std_preludeTheory.OPTION_TYPE_def]));
step "representations" (gvs [std_preludeTheory.OPTION_TYPE_def,ml_translatorTheory.STRING_TYPE_def]);
step "match" (xmatch >>
 cfTacticsLib.eval_pat_tac “v_of_pat_norest _ _ _ _” >>
 cfTacticsLib.eval_pat_tac “validate_pat _ _ _ _ _” >> simp []);
step "dispatch-let" (xlet ‘POSTv v. &STRING_TYPE output v * STDIO (fastForwardFD fs 0)’);
step "dispatch-app" (xapp_spec refund_dispatch_valid >> xsimpl);
step "print" (xapp_spec print_spec >> xsimpl);
showgoals ();
print ("FORGE_REMAINING_GOALS " ^ Int.toString (length (top_goals ())) ^ "\n");
OS.Process.exit OS.Process.success;

val _ = Globals.max_print_depth := 200;
fun showgoals () = List.app (fn (_,tm) => print ("FORGE_OPEN_GOAL " ^ Parse.term_to_string tm ^ "\n")) (top_goals ());
fun step name tac = (print ("FORGE_STEP " ^ name ^ "\n"); e tac; print ("FORGE_STEP_OK " ^ name ^ "\n"))
  handle ex => (print ("FORGE_STEP_FAILED " ^ name ^ " " ^ "\n"); showgoals (); OS.Process.exit OS.Process.failure);
step "enter" (rw [] >> xcf "refund_main" st);
step "none" (xlet ‘POSTv v. &OPTION_TYPE FILENAME NONE v * STDIO fs’ >- (xcon >> xsimpl >> simp [std_preludeTheory.OPTION_TYPE_def]));
step "read" (xlet ‘POSTv v. &OPTION_TYPE STRING_TYPE (SOME (implode text)) v * STDIO (fastForwardFD fs 0)’ >- (xapp_spec inputAllFrom_NONE_spec >> xsimpl >> fs [std_preludeTheory.OPTION_TYPE_def]));
step "representations" (gvs [std_preludeTheory.OPTION_TYPE_def,ml_translatorTheory.STRING_TYPE_def]);
step "match" xmatch;
val _ = print ("FORGE_NONE_LOOKUP " ^ Parse.thm_to_string (EVAL “nsLookup (^(get_env st)).c (Short «None»)” ) ^ "\n");
val _ = print ("FORGE_SOME_LOOKUP " ^ Parse.thm_to_string (EVAL “nsLookup (^(get_env st)).c (Short «Some»)” ) ^ "\n");
val residual = find_term (can (match_term “v_of_pat_norest _ _ _ _”)) (snd (hd (top_goals ())));
val _ = print ("FORGE_PATTERN_EVAL " ^ Parse.thm_to_string (cfTacticsLib.eval residual) ^ "\n");
step "pattern-definitions" (simp [cfTheory.v_of_pat_norest_def,cfTheory.v_of_pat_def,cfTheory.validate_pat_def,cfTheory.pat_typechecks_def]);
showgoals ();
OS.Process.exit OS.Process.success;

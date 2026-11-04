val _ = Globals.max_print_depth := 200;
val steps = [
("enter", rw [] >> xcf "refund_main" st),
("none", xlet ‘POSTv v. &OPTION_TYPE FILENAME NONE v * STDIO fs’ >- (xcon >> xsimpl >> simp [std_preludeTheory.OPTION_TYPE_def])),
("read", xlet ‘POSTv v. &OPTION_TYPE STRING_TYPE (SOME (implode text)) v * STDIO (fastForwardFD fs 0)’ >- (xapp_spec inputAllFrom_NONE_spec >> xsimpl)),
("match", gvs [std_preludeTheory.OPTION_TYPE_def] >> xmatch),
("dispatch", xlet ‘POSTv v. &STRING_TYPE output v * STDIO (fastForwardFD fs 0)’ >- (xapp_spec refund_dispatch_valid >> xsimpl)),
("print", xapp_spec print_spec >> xsimpl)];
val _ = (List.app (fn (label,t) => (print ("FORGE_STEP " ^ label ^ "\n"); e t; ())) steps)
  handle exn => (print ("FORGE_DIAGNOSTIC_ERROR " ^ General.exnMessage exn ^ "\n");
                print (Parse.term_to_string (snd (top_goal ())) ^ "\n");
                OS.Process.exit OS.Process.failure);
val _ = print ("FORGE_REMAINING_GOALS " ^ Int.toString (length (top_goals ())) ^ "\n");
OS.Process.exit OS.Process.success;

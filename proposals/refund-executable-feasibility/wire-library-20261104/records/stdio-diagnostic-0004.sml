val _ = Globals.max_print_depth := 200;
e (rw [] >> xcf "refund_main" st);
e (xlet ‘POSTv v. &OPTION_TYPE FILENAME NONE v * STDIO fs’ >- (xcon >> xsimpl >> simp [std_preludeTheory.OPTION_TYPE_def]));
e (xlet ‘POSTv v. &OPTION_TYPE STRING_TYPE (SOME (implode text)) v * STDIO (fastForwardFD fs 0)’);
e (xapp_spec inputAllFrom_NONE_spec >> xsimpl);
val _ = List.app (fn (_,tm) => print ("FORGE_OPEN_GOAL " ^ Parse.term_to_string tm ^ "\n")) (top_goals ());
OS.Process.exit OS.Process.success;

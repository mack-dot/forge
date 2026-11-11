open preamble fsFFITheory fsFFIPropsTheory;
val _ = Globals.max_print_depth := 1000;
val _ = g ``wfFS fs ∧ ALOOKUP fs.infds fd = SOME (ino,ReadMode,off) ⇒
  ∃content quota. ALOOKUP fs.inode_tbl ino = SOME content ∧
  LHD fs.numchars = SOME quota``;
val _ = e (rw [wfFS_def,liveFS_def,live_numchars_def]);
val _ = e (`MEM fd (MAP FST fs.infds)` by metis_tac [ALOOKUP_NONE]);
val (asms,goal) = top_goal ();
val _ = List.app (fn t => print ("RESIDUAL_ASSUMPTION " ^ term_to_string t ^ "\n")) asms;
val _ = print ("RESIDUAL_GOAL " ^ term_to_string goal ^ "\n");
val _ = print "STDIN_DOMAIN_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

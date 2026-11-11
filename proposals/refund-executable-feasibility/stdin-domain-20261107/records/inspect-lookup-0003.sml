open preamble fsFFITheory fsFFIPropsTheory;
val _ = Globals.max_print_depth := 1000;
val goal = ``wfFS fs ∧ ALOOKUP fs.infds fd = SOME (ino,ReadMode,off) ⇒
  ∃content quota. ALOOKUP fs.inode_tbl ino = SOME content ∧
  LHD fs.numchars = SOME quota``;
val (goals,_) = (rw [wfFS_def,liveFS_def,live_numchars_def] >>
  (`MEM fd (MAP FST fs.infds)` by metis_tac [ALOOKUP_NONE])) ([],goal) (Context.snapshot ());
val _ = List.app (fn (asms,g) => (
  List.app (fn t => print ("RESIDUAL_ASSUMPTION " ^ term_to_string t ^ "\n")) asms;
  print ("RESIDUAL_GOAL " ^ term_to_string g ^ "\n"))) goals;
val _ = print "STDIN_DOMAIN_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

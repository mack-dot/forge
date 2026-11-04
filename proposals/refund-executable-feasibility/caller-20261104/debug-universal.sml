val _ = e (EVAL_TAC >> rpt (IF_CASES_TAC >> gvs [] >> EVAL_TAC) >> simp []);
val (asl,g) = top_goal();
val _ = print "FORGE_DEBUG_BEGIN\n";
val _ = List.app (fn t => print ("ASSUMPTION " ^ Parse.term_to_string t ^ "\n")) asl;
val _ = print ("GOAL " ^ Parse.term_to_string g ^ "\n");
OS.Process.exit OS.Process.success;

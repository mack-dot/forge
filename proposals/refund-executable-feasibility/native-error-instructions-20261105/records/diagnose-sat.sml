open HolKernel Parse boolLib bossLib;
val _ = Globals.max_print_depth := 1000;
val p = Term.mk_var ("probe",bool);
val tm = boolSyntax.mk_disj (p,boolSyntax.mk_neg p);
val _ = print ("DIAGNOSTIC_SAT_TERM " ^ Parse.term_to_string tm ^ "\n");
val _ = print ("DIAGNOSTIC_SOLVER " ^ SatSolvers.getSolverExe SatSolvers.minisatp ^ "\n");
val _ = ((let val th = HolSatLib.SAT_PROVE tm in
  print ("DIAGNOSTIC_SAT_THEOREM " ^ Parse.thm_to_string th ^ "\n");
  print "NATIVE_STEP_COMPLETE\n";
  OS.Process.exit OS.Process.success
 end) handle ex =>
 (print ("DIAGNOSTIC_DEPENDENCY_FAILURE\n" ^ Feedback.exn_to_string ex ^ "\n");
  OS.Process.exit OS.Process.failure));

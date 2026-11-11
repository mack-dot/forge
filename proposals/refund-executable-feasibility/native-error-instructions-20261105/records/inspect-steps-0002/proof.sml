open preamble arm8Theory arm8_stepTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
val words = ["37f800c0","52800028","39000268","a9417bfd","a8c24ff4","d65f03c0"];
val _ = List.app (fn hex =>
 let val ths = arm8_stepLib.arm8_step_hex hex in
  print ("STEP_WORD " ^ hex ^ " COUNT " ^ Int.toString (length ths) ^ "\n");
  List.app (fn th => (print ("STEP_THEOREM " ^ Parse.thm_to_string th ^ "\n");
    List.app (fn h => print ("STEP_HYP " ^ Parse.term_to_string h ^ "\n")) (hyp th))) ths
 end) words;
val _ = print "NATIVE_STEP_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

open preamble;
val _ = Globals.max_print_depth := 1000;
val inputs = [
  ("initialized_error",forge_refundRejectBasisTheory.refund_error_initialized_semantics),
  ("exact_compilation",forge_refundArm8CompileTheory.refund_arm8_compiled),
  ("compiler_precise",backendProofTheory.compile_correct_is_safe_for_space),
  ("source_nonfailure",ml_progTheory.sem_satisfies_IMP_Terminate),
  ("precise_composition",forge_refundPreciseBehaviorTheory.precise_sem_satisfies_IMP_Terminate),
  ("arm8_init",arm8_configProofTheory.arm8_init_ok),
  ("arm8_config",arm8_configProofTheory.arm8_machine_config_ok)];
val _ = List.app (fn (name,th) =>
  (print ("INPUT_THEOREM " ^ name ^ "\n" ^ Parse.thm_to_string th ^ "\n");
   List.app (fn tm => print ("INPUT_HYP " ^ Parse.term_to_string tm ^ "\n")) (hyp th))) inputs;
val _ = print "ERROR_COMPILER_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

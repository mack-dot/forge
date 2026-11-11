load "forge_refundArm8ProofTheory";
open preamble backendProofTheory forge_refundWholeProgTheory forge_refundArm8CompileTheory;
val _=Globals.max_print_depth:=1000;
val st = UNDISCH_ALL refund_semantics |> HO_MATCH_MP ml_progTheory.sem_satisfies_IMP_Terminate |> SRULE[refund_arm8_compiled];
val _=print("SOURCE\n"^Parse.thm_to_string st^"\n");
val _=print("COMPILE\n"^Parse.thm_to_string (cj 1 refund_arm8_compiled)^"\n");
val _=print("CONFIG\n"^Parse.thm_to_string arm8_configProofTheory.arm8_backend_config_ok^"\n");
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

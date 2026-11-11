load "forge_refundArm8ProofTheory";
open preamble backendProofTheory arm8_configProofTheory forge_refundArm8CompileTheory;
open forge_refundWholeProgTheory;
val _=Globals.max_print_depth:=1000;
val generic = MATCH_MP compile_correct_is_safe_for_space (cj 1 refund_arm8_compiled)
  |> SIMP_RULE (srw_ss()) [LET_THM,ml_progTheory.init_state_env_thm,GSYM AND_IMP_INTRO];
val specialised = generic |> Q.GEN `mc` |> ISPEC(arm8_init_ok |> concl |> rand |> rand);
val _=print("PRECISE_SPECIALISATION\n"^Parse.thm_to_string specialised^"\n");
val terminate = UNDISCH_ALL refund_semantics
  |> HO_MATCH_MP ml_progTheory.sem_satisfies_IMP_Terminate |> SRULE[refund_arm8_compiled];
val _=print("NO_FAIL\n"^Parse.thm_to_string(cj 1 terminate)^"\n");
val _=print("SOURCE_SEMANTICS\n"^Parse.thm_to_string refund_semantics^"\n");
val _=OS.Process.exit OS.Process.success;

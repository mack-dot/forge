(* Compose existing source, compilation and arm8 correctness theorems.
   Preserve installation, environment and resource-limit premises. *)
Theory forge_refundArm8Proof
Ancestors
  semanticsProps backendProof arm8_configProof
  forge_refundWholeProg forge_refundArm8Compile
Libs
  preamble

val refund_terminate = UNDISCH_ALL refund_semantics
  |> HO_MATCH_MP ml_progTheory.sem_satisfies_IMP_Terminate
  |> SRULE [refund_arm8_compiled];

Theorem refund_compiled_behavior =
  MATCH_MP compile_correct (cj 1 refund_arm8_compiled)
  |> SIMP_RULE (srw_ss())
       [LET_THM, ml_progTheory.init_state_env_thm, GSYM AND_IMP_INTRO]
  |> C MATCH_MP (cj 1 refund_terminate)
  |> C MATCH_MP arm8_backend_config_ok
  |> Q.GEN ‘mc’
  |> ISPEC (arm8_init_ok |> concl |> rand |> rand)
  |> UNDISCH_ALL
  |> MATCH_MP (cj 2 refund_terminate)
  |> REWRITE_RULE [targetPropsTheory.machine_sem_sing]
  |> DISCH_ALL
  |> CONJ (CONJ (UNDISCH arm8_machine_config_ok) (UNDISCH arm8_init_ok))
  |> SRULE [SF CONJ_ss]
  |> CONJUNCT2
  |> DISCH_ALL
  |> REWRITE_RULE [AND_IMP_INTRO, GSYM CONJ_ASSOC]
  |> check_thm;

val _ = Globals.max_print_depth := 1000;
val _ =
  let val th = refund_compiled_behavior;
      val (oracles,axioms) = Tag.dest_tag (Thm.tag th) in
    print ("FORGE_THEOREM refund_compiled_behavior\n");
    print ("FORGE_ORACLES " ^ String.concatWith "," oracles ^ "\n");
    print ("FORGE_AXIOMS " ^ String.concatWith "," axioms ^ "\n");
    print ("FORGE_HYPOTHESES " ^ Int.toString (length (hyp th)) ^ "\n");
    print ("FORGE_STATEMENT " ^ Parse.thm_to_string th ^ "\n")
  end;

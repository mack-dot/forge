open preamble boolSyntax;
open forge_refundRejectBasisTheory forge_refundPreciseBehaviorTheory
     forge_refundArm8CompileTheory forge_refundWholeProgTheory
     backendProofTheory arm8_configProofTheory targetPropsTheory
     semanticsPropsTheory;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_ERROR_OUT"));
val _ = Globals.max_print_depth := 1000;
val _ = new_theory "forge_refundRejectCompiled";

(* Repack only the event projection. The predicate P is retained verbatim. *)
val exception_event_witness = store_thm ("exception_event_witness", ``
  sem_satisfies source_behaviors
    (λb. ∃x y. b = Terminate outcome (event_of x) ∧ P x y) ⇒
  sem_satisfies source_behaviors
    (λb. ∃io. b = Terminate outcome io ∧
      ∃x y. io = event_of x ∧ P x y)``,
  rw [sem_satisfies_def] >> metis_tac []);

(* Keep the initial h1/h2 witnesses outside the machine behavior. Kernel
   CHOOSE below discharges these temporary existential-body hypotheses. *)
val initialized = UNDISCH refund_error_initialized_semantics;
val (h1,inner_exists) = dest_exists (concl initialized);
val (h2,initial_and_source) = dest_exists inner_exists;
val body_assumption = ASSUME initial_and_source;
val initial_heap = CONJUNCT1 body_assumption;
val source_original = CONJUNCT2 body_assumption;
val source_events = HO_MATCH_MP exception_event_witness source_original;
val _ = print ("ALIGNED_SOURCE_WITH_TEMPORARY_FRAME\n" ^ Parse.thm_to_string source_events ^ "\n");

val source_terminate = source_events
  |> HO_MATCH_MP ml_progTheory.sem_satisfies_IMP_Terminate
  |> SRULE [refund_arm8_compiled];
val precise_subset = MATCH_MP compile_correct_is_safe_for_space (cj 1 refund_arm8_compiled)
  |> SIMP_RULE (srw_ss()) [LET_THM,ml_progTheory.init_state_env_thm,GSYM AND_IMP_INTRO]
  |> Q.GEN `mc` |> ISPEC (arm8_init_ok |> concl |> rand |> rand)
  |> Q.GEN `ffi` |> ISPEC ``basis_ffi$basis_ffi ext cl fs``
  |> UNDISCH_ALL
  |> PROVE_HYP (cj 1 source_terminate)
  |> PROVE_HYP arm8_backend_config_ok
  |> PROVE_HYP (UNDISCH arm8_machine_config_ok)
  |> PROVE_HYP (UNDISCH arm8_init_ok);
val source_precise = source_events
  |> HO_MATCH_MP precise_sem_satisfies_IMP_Terminate
  |> SRULE [refund_arm8_compiled];
val compiled_events = MATCH_MP source_precise precise_subset
  |> REWRITE_RULE [machine_sem_sing];
val joined = CONJ initial_heap compiled_events;
val inner_packed = EXISTS (mk_exists (h2,concl joined),h2) joined;
val outer_packed = EXISTS (mk_exists (h1,concl inner_packed),h1) inner_packed;
val inner_eliminated = CHOOSE (h2,ASSUME inner_exists) outer_packed;
val final_eliminated = CHOOSE (h1,initialized) inner_eliminated;
val refund_error_compiled_precise = final_eliminated
  |> DISCH_ALL
  |> REWRITE_RULE [AND_IMP_INTRO,GSYM CONJ_ASSOC]
  |> (fn th => save_thm ("refund_error_compiled_precise",th));

val checked = [("exception_event_witness",exception_event_witness),
               ("refund_error_compiled_precise",refund_error_compiled_precise)];
val _ = List.app (fn (name,th) =>
  let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
    if null (hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
    then () else raise Fail ("Unexpected open assumption: " ^ name);
    print ("CHECKED_THEOREM " ^ name ^ "\n" ^ Parse.thm_to_string th ^ "\n");
    print ("CHECKED_ORACLES " ^ String.concatWith "," ors ^ "\n");
    print "CHECKED_HYPOTHESES 0\nCHECKED_TAGGED_AXIOMS 0\n"
  end) checked;
val _ = export_theory ();
val _ = print "ERROR_COMPILER_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

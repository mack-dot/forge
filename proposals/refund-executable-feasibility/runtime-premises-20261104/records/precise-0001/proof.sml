load "forge_refundArm8ProofTheory";
open preamble backendProofTheory arm8_configProofTheory forge_refundArm8CompileTheory;
open forge_refundWholeProgTheory semanticsPropsTheory targetPropsTheory;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_refundPreciseBehavior";
val precise_sem_satisfies_IMP_Terminate = store_thm("precise_sem_satisfies_IMP_Terminate", ``
  sem_satisfies (semantics_dec_list s init_env prog)
    (\b. ?io. b = Terminate outcome io /\ p io) ==>
  prog_syntax_ok prog ==>
  sem SUBSET semantics_prog s init_env prog ==>
  (?b. sem = {b}) ==>
  ?io. sem = {Terminate outcome io} /\ p io``,
  rpt strip_tac >> fs[ml_progTheory.semantics_dec_list_eq,sem_satisfies_def,SUBSET_DEF] >>
  metis_tac[IN_SING]);
val source_terminate = UNDISCH_ALL refund_semantics
  |> HO_MATCH_MP ml_progTheory.sem_satisfies_IMP_Terminate |> SRULE[refund_arm8_compiled];
val precise_subset = MATCH_MP compile_correct_is_safe_for_space (cj 1 refund_arm8_compiled)
  |> SIMP_RULE (srw_ss()) [LET_THM,ml_progTheory.init_state_env_thm,GSYM AND_IMP_INTRO]
  |> Q.GEN `mc` |> ISPEC(arm8_init_ok |> concl |> rand |> rand)
  |> Q.GEN `ffi` |> ISPEC ``basis_ffi$basis_ffi ext cl fs``
  |> UNDISCH_ALL
  |> PROVE_HYP (cj 1 source_terminate)
  |> PROVE_HYP arm8_backend_config_ok
  |> PROVE_HYP (UNDISCH arm8_machine_config_ok)
  |> PROVE_HYP (UNDISCH arm8_init_ok);
val source_precise = UNDISCH_ALL refund_semantics
  |> HO_MATCH_MP precise_sem_satisfies_IMP_Terminate |> SRULE[refund_arm8_compiled];
val refund_compiled_precise = MATCH_MP source_precise precise_subset
  |> C MATCH_MP machine_sem_sing |> DISCH_ALL
  |> REWRITE_RULE [AND_IMP_INTRO,GSYM CONJ_ASSOC]
  |> (fn th=>save_thm("refund_compiled_precise",th));
val empty_resource_prefix_allowed = store_thm("empty_resource_prefix_allowed", ``
  Terminate Resource_limit_hit [] IN extend_with_resource_limit {Terminate Success io}``,
  simp[extend_with_resource_limit_def]);
val _=Globals.max_print_depth:=1000;
val _=List.app(fn(name,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("CHECKED "^name^"\n"^Parse.thm_to_string th^"\n") end)
 [("precise_sem_satisfies_IMP_Terminate",precise_sem_satisfies_IMP_Terminate),
  ("refund_compiled_precise",refund_compiled_precise),
  ("empty_resource_prefix_allowed",empty_resource_prefix_allowed)];
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

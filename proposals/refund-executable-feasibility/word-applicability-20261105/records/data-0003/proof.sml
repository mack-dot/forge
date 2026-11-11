load "forge_refundArm8ProofTheory";
open preamble backendProofTheory forge_refundWholeProgTheory forge_refundArm8CompileTheory;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_refundDataBehavior";
val compiled_source_data = store_thm("compiled_source_data",``
 backend$compile asm_conf cfg prog = SOME(bytes,bitmaps,cfg') ==>
 let (s0,env) = THE(primTypes$prim_sem_env ffi) in
 ~semantics$semantics_prog s0 env prog ffi$Fail /\
 backendProof$backend_config_ok asm_conf cfg ==>
 semantics$semantics_determ (s0 with ptr_eq_oracle := po) env prog =
 {dataSem$semantics ffi (sptree$fromAList(SND(backend$to_data cfg prog)))
   (backendProof$cake_orac (:'a) asm_conf cfg' syn
     (SND o SND o SND o SND o SND o backendProof$config_tuple2) (\ps. ps.data_prog))
   (backendProof$backend_from_data_tuple_cc (:'a) asm_conf cfg) po
   dataProps$zero_limits sptree$LN bvl_to_bvi$InitGlobals_location}``,
 strip_tac >> pairarg_tac >> strip_tac >>
 `~semantics$semantics_determ (s0 with ptr_eq_oracle := po) env prog ffi$Fail` by
   metis_tac[semanticsTheory.semantics_prog_def] >>
 `cfg.stack_conf.perf_calls = F /\ cfg.source_conf = backend$prim_src_config` by
   fs[backendProofTheory.backend_config_ok_def] >>
 Cases_on `source_to_flat$compile backend$prim_src_config (source_to_source$compile prog)` >>
 `semantics$semantics_determ (s0 with ptr_eq_oracle := po) env prog
   (flatSem$semantics
     (flatProps$mk_flat_install_conf
       (backendProof$backend_from_flat_tuple_cc (:'a) asm_conf cfg)
       (backendProof$cake_orac (:'a) asm_conf cfg' syn (SND o backendProof$config_tuple1)
         (\ps. ps.flat_prog))) s0.ffi po r)` by
   metis_tac[backendProofTheory.source_to_flat_semantics_no_eval] >>
 metis_tac[backendProofTheory.flat_to_data_semantics]);
val source_terminate = UNDISCH_ALL refund_semantics
 |> HO_MATCH_MP ml_progTheory.sem_satisfies_IMP_Terminate |> SRULE[refund_arm8_compiled];
val exact_data = MATCH_MP compiled_source_data (cj 1 refund_arm8_compiled)
 |> SIMP_RULE (srw_ss()) [LET_THM,ml_progTheory.init_state_env_thm,GSYM AND_IMP_INTRO]
 |> Q.GEN `ffi` |> ISPEC ``basis_ffi$basis_ffi ext cl fs``
 |> UNDISCH_ALL
 |> PROVE_HYP (cj 1 source_terminate)
 |> PROVE_HYP arm8_configProofTheory.arm8_backend_config_ok;
val refund_data_behavior = exact_data |> DISCH_ALL
 |> REWRITE_RULE[AND_IMP_INTRO,GSYM CONJ_ASSOC]
 |> (fn th=>save_thm("refund_data_behavior",th));
val _=Globals.max_print_depth:=1000;
val _=List.app(fn(name,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("CHECKED "^name^"\n"^Parse.thm_to_string th^"\n") end)
 [("compiled_source_data",compiled_source_data),("refund_data_behavior",refund_data_behavior)];
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

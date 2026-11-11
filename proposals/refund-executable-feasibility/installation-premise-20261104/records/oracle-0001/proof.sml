load "forge_refundArm8ProofTheory";
open preamble;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_refundDataOracle";
val initial_oracle_relation = store_thm("initial_oracle_relation",``
  dataProps$cc_co_only_diff
    ((dataSem$initial_state ffi dcode ARB ARB pe T lims ss k):(unit,'ffi) dataSem$state)
    (dataSem$initial_state ffi dcode coracle cc pe T lims ss k)``,
  simp[dataPropsTheory.cc_co_only_diff_def,dataSemTheory.initial_state_def]);
val safe_data_execution = store_thm("safe_data_execution",``
  dataSem$data_lang_safe_for_space ffi pe dcode lims ss start /\
  dataSem$evaluate
    (dataLang$Call NONE (SOME start) [] NONE,
     ((dataSem$initial_state ffi dcode ARB ARB pe T lims ss k):(unit,'ffi) dataSem$state)) = (res,s1)
  ==> ?t1.
    dataSem$evaluate
      (dataLang$Call NONE (SOME start) [] NONE,
       dataSem$initial_state ffi dcode coracle cc pe T lims ss k) = (res,t1) /\
    dataProps$cc_co_only_diff s1 t1``,
  strip_tac >>
  `s1.safe_for_space` by
    (qpat_x_assum `dataSem$data_lang_safe_for_space _ _ _ _ _ _`
       (mp_tac o REWRITE_RULE [dataSemTheory.data_lang_safe_for_space_def]) >>
     simp[] >> disch_then(qspec_then `k` mp_tac) >> simp[]) >>
  metis_tac[dataPropsTheory.evaluate_cc_co_only_diff,initial_oracle_relation]);
val refund_data_oracle_independence = store_thm("refund_data_oracle_independence",``
  let cfg = backend$set_oracle arm8_config$arm8_backend_config oracle;
      dcode = sptree$fromAList (SND(backend$to_data cfg forge_refundWholeProg$refund_prog));
      lims = dataSem$compute_limits cfg.data_conf.len_size (backendProof$is_64_bits (:64))
        cfg.data_conf.has_fp_ops cfg.data_conf.has_fp_tern stack_heap_limit;
      frames = word_to_stack$compute_stack_frame_sizes arm8_target$arm8_config
        (SND(backend$to_word arm8_target$arm8_config cfg forge_refundWholeProg$refund_prog))
  in
    backendProof$is_safe_for_space (:64) ffi pe arm8_target$arm8_config cfg
      forge_refundWholeProg$refund_prog stack_heap_limit /\
    dataSem$evaluate
      (dataLang$Call NONE (SOME data_to_word$InitGlobals_location) [] NONE,
       ((dataSem$initial_state ffi dcode ARB ARB pe T lims frames k):(unit,'ffi) dataSem$state)) = (res,s1)
    ==> ?t1.
      dataSem$evaluate
        (dataLang$Call NONE (SOME data_to_word$InitGlobals_location) [] NONE,
         dataSem$initial_state ffi dcode coracle cc pe T lims frames k) = (res,t1) /\
      dataProps$cc_co_only_diff s1 t1``,
  rw[LET_THM,backendProofTheory.is_safe_for_space_def] >>
  metis_tac[safe_data_execution]);
val _=Globals.max_print_depth:=1000;
val _=List.app(fn(name,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("CHECKED "^name^"\n"^Parse.thm_to_string th^"\n") end)
 [("initial_oracle_relation",initial_oracle_relation),("safe_data_execution",safe_data_execution),
  ("refund_data_oracle_independence",refund_data_oracle_independence)];
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

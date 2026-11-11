load "forge_refundArm8ProofTheory";
open preamble backendProofTheory backendPropsTheory forge_refundInitializedEpochTheory;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_refundWordOracle";
val cfg=``backend$set_oracle arm8_config$arm8_backend_config forge_refundArm8Compile$oracle``;
val ac=``arm8_target$arm8_config``;
val dc=``backend$ensure_fp_conf_ok ^ac (^cfg).data_conf``;
val regcount=``(^ac).reg_count - (LENGTH (^ac).avoid_regs + 5)``;
val proj=``SND o SND o SND o SND o SND o backendProof$config_tuple2``;
val data_oracle=``backendProof$cake_orac (:64) ^ac forge_refundArm8Compile$info syn ^proj (\ps.ps.data_prog)``;
val word_oracle=``backendProof$cake_orac (:64) ^ac forge_refundArm8Compile$info syn ^proj (\ps.ps.word_prog)``;
val full=``MAP(\(p:num # num # wordLang$prog # backend_common$metadata).
 word_to_word$full_compile_single (dimindex(:64)) (^ac).two_reg_arith ^regcount
 (^cfg).word_to_word_conf.reg_alg ^ac (p,NONE))``;
val compiled=cj 1 forge_refundArm8CompileTheory.refund_arm8_compiled;
val up=SPEC_ALL backendProofTheory.data_to_word_orac_eq_std
 |> INST_TYPE[alpha|->``:64``]
 |> REWRITE_RULE[GSYM AND_IMP_INTRO];
val oracle_rule=MATCH_MP up compiled
 |> Q.INST[`dc`|->`^dc`,`tr_c`|->`(^ac).two_reg_arith`,
           `reg_c`|->`^regcount`,`reg_alg`|->`(^cfg).word_to_word_conf.reg_alg`,`src`|->`syn`]
 |> SIMP_RULE(srw_ss())[backendPropsTheory.pure_co_def];
val refund_word_oracle_binding = oracle_rule
 |> (fn th=>save_thm("refund_word_oracle_binding",th));
val _=print("ORACLE_BINDING "^Parse.thm_to_string refund_word_oracle_binding^"\n");
val bvi_data=List.nth(CONJUNCTS backendProofTheory.cake_orac_eqs,4);
val refund_data_oracle_labels = store_thm("refund_data_oracle_labels",``
 !n.EVERY ($<= backend_common$data_num_stubs)(MAP FST(SND(^data_oracle n)))``,
 assume_tac compiled >> gen_tac >>
 simp[GSYM bvi_data,backendPropsTheory.pure_co_def,o_DEF,
      bvi_to_dataProofTheory.MAP_FST_compile_prog] >>
 irule (listTheory.MONO_EVERY |> Q.GEN `P` |> Q.ISPEC `$<= backend_common$bvl_num_stubs`) >>
 irule_at Any backendProofTheory.bvl_num_stubs_LE_bvi_prog >>
 first_x_assum(irule_at Any) >> EVAL_TAC >> simp[]);
val wp=``sptree$fromAList(SND(backend$to_word ^ac ^cfg forge_refundWholeProg$refund_prog))``;
val init=``word_to_stackProof$make_init ^ac ^regcount
 (s:(64,lab_to_target$config,'ffi)stackSem$state) ^wp ^word_oracle
 (data_to_word_memoryProof$word_ptr_eq ^dc)``;
val tco_term=``(I ## MAP(data_to_word$compile_part ^dc)) o ^data_oracle``;
val tcc_term=``\conf progs.(^init).compile conf (^full progs)``;
val fixed0 = refund_initialized_single_epoch
 |> Q.INST[`co`|->`^word_oracle`,`tco`|->`^tco_term`,`tcc`|->`^tcc_term`,
           `frames`|->`(^init).stack_size`]
 |> SIMP_RULE(srw_ss())[word_to_stackProofTheory.make_init_def,
      markerTheory.Abbrev_def,refund_word_oracle_binding,refund_data_oracle_labels,
      EVERY_MAP,LAMBDA_PROD,backendPropsTheory.pure_co_def];
val normalized_oracle = SIMP_RULE(srw_ss())
 [refund_word_config_facts,LAMBDA_PROD] refund_word_oracle_binding;
val normalized_labels = SIMP_RULE(srw_ss())
 [EVERY_MAP,LAMBDA_PROD] refund_data_oracle_labels;
val fixed = SIMP_RULE(srw_ss())
 [GSYM normalized_oracle,normalized_labels] fixed0;
val _=if length(strip_conj(fst(dest_imp(concl fixed))))=11 then ()
 else raise Fail "Oracle or label premise not discharged";
val refund_exact_oracle_single_epoch=save_thm("refund_exact_oracle_single_epoch",fixed);
val _=Globals.max_print_depth:=1000;
val _=print("REMAINING_ANTECEDENTS "^Int.toString(length(strip_conj(fst(dest_imp(concl fixed)))))^"\n");
val _=List.app(fn(name,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("CHECKED "^name^"\n"^Parse.thm_to_string th^"\n") end)
 [("refund_word_oracle_binding",refund_word_oracle_binding),
  ("refund_data_oracle_labels",refund_data_oracle_labels),
  ("refund_exact_oracle_single_epoch",refund_exact_oracle_single_epoch)];
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

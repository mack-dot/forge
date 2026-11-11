load "forge_refundArm8ProofTheory";
open preamble forge_refundWordPremisesTheory forge_refundWordInitializationTheory;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_refundInitializedEpoch";
val cfg = ``backend$set_oracle arm8_config$arm8_backend_config forge_refundArm8Compile$oracle``;
val ac = ``arm8_target$arm8_config``;
val dc = ``backend$ensure_fp_conf_ok ^ac (^cfg).data_conf``;
val wp = ``sptree$fromAList(SND(backend$to_word ^ac ^cfg forge_refundWholeProg$refund_prog))``;
val regcount = ``(^ac).reg_count - (LENGTH (^ac).avoid_regs + 5)``;
val config_facts = store_thm("refund_word_config_facts",``
 data_to_word$conf_ok (dimindex(:64)) ^dc /\
 (^dc).gc_kind <> backend_common$None /\
 isa_bits ^ac = dimindex(:64) /\ misc$good_dimindex(:64)``, EVAL_TAC);
val init = ``word_to_stackProof$make_init ^ac ^regcount
 (s:(64,lab_to_target$config,'ffi)stackSem$state) ^wp co
 (data_to_word_memoryProof$word_ptr_eq ^dc)``;
val exact_code = SIMP_RULE (srw_ss()) [EVAL ``isa_bits ^ac``] refund_word_code_rel;
val (raw,witness) = dest_exists(concl exact_code);
val fixed = refund_word_single_epoch
 |> Q.INST [`c`|->`^dc`,`x1`|->`^raw`,`coo`|->`^ac`,
            `kk`|->`^regcount`,`tt`|->`(^ac).two_reg_arith`,`aa`|->`(^cfg).word_to_word_conf.reg_alg`]
 |> Q.GEN `t` |> ISPEC init
 |> SIMP_RULE (srw_ss()) [GSYM AND_IMP_INTRO,word_to_stackProofTheory.make_init_def,
      wordSemTheory.stack_size_def,config_facts]
 |> UNDISCH_ALL;
val _=print("BEFORE_CODE_DISCHARGE "^Int.toString(length(hyp fixed))^"\n");
val code_terms = CONJUNCTS(ASSUME witness);
val reduced = List.foldl (fn(th,acc)=>PROVE_HYP th acc) fixed code_terms;
val _=print("AFTER_CODE_DISCHARGE "^Int.toString(length(hyp reduced))^"\n");
val residual = List.filter(fn tm=>not(aconv tm witness))(hyp reduced);
val conditional = List.foldr (fn(tm,th)=>DISCH tm th) reduced residual;
val chosen = CHOOSE(raw,exact_code) conditional;
val refund_initialized_single_epoch = chosen
 |> REWRITE_RULE[AND_IMP_INTRO,GSYM CONJ_ASSOC]
 |> (fn th=>save_thm("refund_initialized_single_epoch",th));
val _=Globals.max_print_depth:=1000;
val _=List.app(fn(name,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("CHECKED "^name^"\n"^Parse.thm_to_string th^"\n") end)
 [("refund_word_config_facts",config_facts),("refund_initialized_single_epoch",refund_initialized_single_epoch)];
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

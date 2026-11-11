load "forge_refundArm8ProofTheory";
open preamble backendProofTheory forge_refundWordOracleTheory;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_refundStackInitialization";
val cfg=``backend$set_oracle arm8_config$arm8_backend_config forge_refundArm8Compile$oracle``;
val ac=``arm8_target$arm8_config``;
val dc=``backend$ensure_fp_conf_ok ^ac (^cfg).data_conf``;
val aw=``arch_wordsize (^ac).ISA``;
val regcount=``(^ac).reg_count - (LENGTH (^ac).avoid_regs + 5)``;
val stk=``(^ac).reg_count - (LENGTH (^ac).avoid_regs + 3)``;
val proj=``SND o SND o SND o SND o SND o backendProof$config_tuple2``;
val stackproj=``SND o ^proj``;
val labproj=stackproj;
val wo=``backendProof$cake_orac (:64) ^ac forge_refundArm8Compile$info syn ^proj (\ps.ps.word_prog)``;
val so=``backendProof$cake_orac (:64) ^ac forge_refundArm8Compile$info syn ^stackproj (\ps.(ps.stack_prog,(MAP n2w ps.cur_bm:64 word list)))``;
val lo=``backendProof$cake_orac (:64) ^ac forge_refundArm8Compile$info syn ^labproj (\ps.ps.lab_prog)``;
val labcode=``SND(SND(backend$to_lab ^ac ^cfg forge_refundWholeProg$refund_prog))``;
val stackcode=``SND(SND(backend$to_stack ^ac ^cfg forge_refundWholeProg$refund_prog))``;
val bitmaps=``MAP n2w (FST(backend$to_stack ^ac ^cfg forge_refundWholeProg$refund_prog)):64 word list``;
val lab=``lab_to_targetProof$make_init mc (basis_ffi$basis_ffi ext cl fs) tar m dm sdm ms
 ^labcode (lab_to_target$compile ^ac) (cbpos:64 word) cbspace ^lo``;
val initial=``stack_to_labProof$full_make_init ^aw (^cfg).stack_conf ^dc
 (2*data_to_word$max_heap_limit (dimindex(:64)) ^dc - 1) ^stk (^ac).addr_offset
 ^bitmaps ^stackcode ^lab save_regs data_sp ^so``;
val s=``FST ^initial``;
val wp=``sptree$fromAList(SND(backend$to_word ^ac ^cfg forge_refundWholeProg$refund_prog))``;
val w=``word_to_stackProof$make_init ^ac ^regcount ^s ^wp ^wo
 (data_to_word_memoryProof$word_ptr_eq ^dc)``;
val full=``MAP(\(p:num # num # wordLang$prog # backend_common$metadata).
 word_to_word$full_compile_single (dimindex(:64)) (^ac).two_reg_arith ^regcount
 (^cfg).word_to_word_conf.reg_alg ^ac (p,NONE))``;
val refund_stack_gc=store_thm("refund_stack_gc",``(^s).gc_fun=word_gcFunctions$word_gc_fun ^dc``,
 simp[stack_to_labProofTheory.full_make_init_def,stack_allocProofTheory.make_init_def]);
val refund_stack_store=store_thm("refund_stack_store",``
 data_to_word_gcProof$init_store_ok ^dc ((^s).store \\ stackLang$Handler)
  (^s).memory (^s).mdomain (^s).code_buffer (^s).data_buffer``,
 match_mp_tac(GEN_ALL stack_to_labProofTheory.IMP_init_store_ok) >> simp[] >> metis_tac[PAIR]);
val bitmap_base=SPEC_ALL backendProofTheory.MAP_upper_n2w_eq_upper_w2w;
val bitmap_imp=INST_TYPE(List.map(fn ty=>ty|->``:64``)(type_vars_in_term(concl bitmap_base))) bitmap_base
 |> Q.INST[`asm_conf`|->`^ac`];
val bitmap_map=MP bitmap_imp (EQT_ELIM(EVAL(fst(dest_imp(concl bitmap_imp)))));
val _=if is_eq(concl bitmap_map) then () else raise Fail "Bitmap conversion equality lost";
val _=print("BITMAP_SPECIALIZATION "^Parse.thm_to_string bitmap_map^"\n");
val refund_stack_compiler=store_thm("refund_stack_compiler",``
 backendProof$backend_from_data_tuple_cc (:64) ^ac ^cfg =
 (\cf.OPTION_MAP(backend_common$bytes_to_mlstring ## MAP wordSem$upper_w2w ## I) o
   (\ps.(^w).compile cf (^full ps)) o MAP(data_to_word$compile_part ^dc))``,
 simp[backendProofTheory.backend_from_data_tuple_cc_def,FUN_EQ_THM,
  word_to_stackProofTheory.make_init_def,stack_to_labProofTheory.full_make_init_compile,
  lab_to_targetProofTheory.make_init_def,EVAL ``isa_bits ^ac``] >>
 rpt gen_tac >> rpt(pairarg_tac >> fs[]) >>
 simp[bitmap_map,EVAL ``isa_bits ^ac``,
  OPTION_MAP_COMPOSE,o_DEF,LAMBDA_PROD,PAIR_MAP]);
val compiler_normalized=SIMP_RULE(srw_ss())[word_to_stackProofTheory.make_init_def] refund_stack_compiler;
val fixed=refund_exact_oracle_single_epoch |> Q.GEN `s` |> ISPEC s
 |> SIMP_RULE(srw_ss())[refund_stack_gc,refund_stack_store,compiler_normalized];
val _=print("REMAINING_ANTECEDENTS "^Int.toString(length(strip_conj(fst(dest_imp(concl fixed)))))^"\n");
val _=if length(strip_conj(fst(dest_imp(concl fixed))))=8 then ()
 else raise Fail "Three constructor premises not discharged";
val refund_stack_initialized_single_epoch=save_thm("refund_stack_initialized_single_epoch",fixed);
val _=Globals.max_print_depth:=1000;
val _=List.app(fn(name,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("CHECKED "^name^"\n"^Parse.thm_to_string th^"\n") end)
 [("refund_stack_gc",refund_stack_gc),("refund_stack_store",refund_stack_store),
  ("refund_stack_compiler",refund_stack_compiler),
  ("refund_stack_initialized_single_epoch",refund_stack_initialized_single_epoch)];
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

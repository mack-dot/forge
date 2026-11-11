load "forge_refundArm8ProofTheory";
open preamble backendProofTheory forge_refundSuccessfulInitializationTheory forge_refundInitializationStaticTheory;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_refundInitialStackCode";
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

val wordprog=``SND(backend$to_word ^ac ^cfg forge_refundWholeProg$refund_prog)``;
val datapair=``backend$to_data ^cfg forge_refundWholeProg$refund_prog``;
val data_compile=``data_to_word$compile (FST ^datapair).data_conf
 (FST ^datapair).word_to_word_conf ^ac (SND ^datapair)``;
val word_output=prove(``^wordprog=SND ^data_compile``,
 simp[backendTheory.to_word_def] >> rpt(pairarg_tac >> fs[]));
val raw_conventions=MATCH_MP
 (INST_TYPE[alpha|->``:64``]data_to_word_syntaxProofTheory.data_to_word_compile_conventions)
 (EQT_ELIM(EVAL ``good_dimindex(:64)``));
val exact_conventions=raw_conventions |> Q.GENL[`data_conf`,`wc`,`ac`,`prog`]
 |> ISPECL[``(FST ^datapair).data_conf``,``(FST ^datapair).word_to_word_conf``,ac,``SND ^datapair``];
val refund_word_postalloc=store_thm("refund_word_postalloc",``
 EVERY (wordConvs$post_alloc_conventions (isa_bits ^ac)
  ((^ac).reg_count-(5+LENGTH(^ac).avoid_regs)))
  (MAP (FST o SND o SND) ^wordprog)``,
 mp_tac exact_conventions >> simp[LET_THM,UNCURRY,word_output,EVERY_MAP,EVERY_MEM,FORALL_PROD] >>
 metis_tac[]);
val raw_labels=MATCH_MP to_word_labels_ok
 (CONJ(cj 1 forge_refundArm8CompileTheory.refund_arm8_compiled)refund_config_ok);
val refund_word_labels=store_thm("refund_word_labels",``
 ALL_DISTINCT(MAP FST ^wordprog) /\ EVERY(\n.6<n)(MAP FST ^wordprog) /\
 EVERY (\(n,m,p,md).EVERY(\(l1,l2).l1=n /\ l2<>0 /\ l2<>1)(wordConvs$extract_labels p) /\
 ALL_DISTINCT(wordConvs$extract_labels p)) ^wordprog``,
 mp_tac raw_labels >> simp[LET_THM,UNCURRY,arithmeticTheory.GREATER_DEF,EVAL ``wordLang$store_consts_stub_location``]);
val refund_stack_lowering=store_thm("refund_stack_lowering",``
 ^stackcode=SND(SND(SND(word_to_stack$compile ^ac F ^wordprog)))``,
 simp[backendTheory.to_stack_def] >> rpt(pairarg_tac >> fs[]) >>
 imp_res_tac to_word_perf_calls >> fs[EVAL ``(^cfg).stack_conf.perf_calls``]);
val _=print "WORD_CONVENTIONS_LABELS_AND_LOWERING_CHECKED\n";
val specialized_convs=word_to_stackProofTheory.word_to_stack_stack_convs
 |> INST_TYPE[alpha|->``:64``] |> Q.GEN `k` |> ISPEC regcount;
val specialized_labels=word_to_stackProofTheory.word_to_stack_compile_lab_pres
 |> Q.GEN `asm_conf` |> ISPEC ac
 |> SIMP_RULE(srw_ss())[EVAL ``wordLang$raise_stub_location``,EVAL ``wordLang$store_consts_stub_location``];
val static_numbers=[EVAL ``isa_bits ^ac``,EVAL ``dimindex(:64)``,
 EVAL ``^regcount``,EVAL ``^stk``,EVAL ``backend_common$stack_num_stubs``];
val stack_good_from_word=prove(``
 word_to_stack$compile ^ac F wprog=(bm,cc,frames,stack_prg) /\
 ALL_DISTINCT(MAP FST wprog) /\ EVERY(\n.6<n)(MAP FST wprog) /\
 EVERY(\(n,m,p,md).EVERY(\(l1,l2).l1=n /\ l2<>0 /\ l2<>1)(wordConvs$extract_labels p) /\
 ALL_DISTINCT(wordConvs$extract_labels p)) wprog /\
 EVERY (wordConvs$post_alloc_conventions (isa_bits ^ac)
  ((^ac).reg_count-(5+LENGTH(^ac).avoid_regs))) (MAP(FST o SND o SND)wprog) ==>
 stack_to_labProof$good_code ^stk stack_prg``,
 strip_tac >> drule specialized_convs >> simp static_numbers >>
 impl_tac >- fs static_numbers >> strip_tac >>
 drule specialized_labels >> simp[] >> strip_tac >>
 `ALL_DISTINCT(MAP FST stack_prg)` by
  (fs[EVERY_MEM] >> metis_tac[DECIDE ``~((6:num)<5)``,DECIDE ``~((6:num)<6)``]) >>
 `EVERY(\n.5<=n)(MAP FST stack_prg)` by
  (fs[EVERY_MEM] >> metis_tac[DECIDE ``(6:num)<n ==> 5<=n``]) >>
 fs(stack_to_labProofTheory.good_code_def::static_numbers) >>
 fs[EVERY_MAP,EVERY_MEM,FORALL_PROD] >> metis_tac[]);
val sc=``word_to_stack$compile ^ac F ^wordprog``;
val exact_stack=stack_good_from_word |> Q.GENL[`wprog`,`bm`,`cc`,`frames`,`stack_prg`]
 |> ISPECL[wordprog,``FST ^sc``,``FST(SND ^sc)``,``FST(SND(SND ^sc))``,``SND(SND(SND ^sc))``]
 |> SIMP_RULE(srw_ss())[refund_word_labels,refund_word_postalloc];
val refund_initial_stack_good=store_thm("refund_initial_stack_good",``stack_to_labProof$good_code ^stk ^stackcode``,
 simp[refund_stack_lowering] >> MATCH_ACCEPT_TAC exact_stack);
val reduced=SIMP_RULE(srw_ss())[refund_initial_stack_good]refund_initialization_static
 |> REWRITE_RULE[AND_IMP_INTRO,GSYM CONJ_ASSOC];
val refund_initialization_code=save_thm("refund_initialization_code",reduced);
val _=print("REMAINING_ANTECEDENTS "^Int.toString(length(strip_conj(fst(dest_imp(concl reduced)))))^"\n");
val _=Globals.max_print_depth:=1000;
val _=List.app(fn(name,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th)in
 if null(hyp th)andalso null axs andalso List.all(fn s=>s="DISK_THM")ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("CHECKED "^name^"\n"^Parse.thm_to_string th^"\n")end)
 [("refund_word_postalloc",refund_word_postalloc),("refund_word_labels",refund_word_labels),
  ("refund_stack_lowering",refund_stack_lowering),("refund_initial_stack_good",refund_initial_stack_good),
  ("refund_initialization_code",refund_initialization_code)];
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

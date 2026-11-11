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
 mp_tac raw_labels >> simp[LET_THM,UNCURRY,EVAL ``wordLang$store_consts_stub_location``]);
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
  (fs[EVERY_MEM] >> metis_tac[DECIDE ``~(6<5)``,DECIDE ``~(6<6)``]) >>
 `EVERY(\n.5<=n)(MAP FST stack_prg)` by
  (fs[EVERY_MEM] >> metis_tac[DECIDE ``6<n ==> 5<=n``]) >>
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

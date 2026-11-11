load "forge_refundArm8ProofTheory";
open preamble backendProofTheory;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_refundSuccessfulInitialization";
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

val to_stack_config_preservation=prove(``
 backend$to_stack ac c prg=(bm,c',stack_prg) ==>
 c'.stack_conf=c.stack_conf /\ c'.data_conf=c.data_conf``,
 simp[backendTheory.to_stack_def,backendTheory.to_word_def] >>
 rpt(pairarg_tac >> fs[]) >> rw[] >>
 imp_res_tac backendTheory.to_data_conf_inv >> fs[]);
val to_lab_code_identity=prove(``
 SND(SND(backend$to_lab ac c prg)) =
 stack_to_lab$compile (arch_wordsize ac.ISA) c.stack_conf c.data_conf
  (&(2*data_to_word$max_heap_limit (isa_bits ac)c.data_conf-1))
  (ac.reg_count-(LENGTH ac.avoid_regs+3)) ac.addr_offset
  (SND(SND(backend$to_stack ac c prg)))``,
 simp[backendTheory.to_lab_def] >> rpt(pairarg_tac >> fs[]) >>
 imp_res_tac to_stack_config_preservation >> fs[]);
val gc_stubs=EQT_ELIM(EVAL ``stack_alloc$stubs ^aw ^dc=stack_alloc$stubs ^aw (^cfg).data_conf``);
val gc_kind=EQT_ELIM(EVAL ``(^dc).gc_kind=(^cfg).data_conf.gc_kind``);
val heap_limit=EQT_ELIM(EVAL ``data_to_word$max_heap_limit (isa_bits ^ac)(^cfg).data_conf =
 data_to_word$max_heap_limit (dimindex(:64)) ^dc``);
val refund_lab_code=store_thm("refund_lab_code",``
 (^lab).code=stack_to_lab$compile ^aw (^cfg).stack_conf ^dc
  (2*data_to_word$max_heap_limit (dimindex(:64)) ^dc-1) ^stk (^ac).addr_offset ^stackcode``,
 simp[lab_to_targetProofTheory.make_init_def,to_lab_code_identity,heap_limit,
  stack_to_labTheory.compile_def,stack_allocTheory.compile_def,gc_stubs,gc_kind]);
val synv=find_term(fn tm=>is_var tm andalso fst(dest_var tm)="syn")so;
val oracle_raw=MATCH_MP (INST_TYPE[alpha|->``:64``] stack_to_lab_orac_eq_std_sym)
 (cj 1 forge_refundArm8CompileTheory.refund_arm8_compiled);
val refund_lab_oracle=oracle_raw |> Q.GENL[`src`,`f5`] |> ISPECL[synv,labproj]
 |> (fn th=>save_thm("refund_lab_oracle",th));
val initial_eq=prove(``^initial=(FST ^initial,SND ^initial)``,simp[]);
val connected=MATCH_MP(REWRITE_RULE[GSYM AND_IMP_INTRO] full_make_init_semantics2)initial_eq;
val reduced=SIMP_RULE(srw_ss())
 [refund_lab_code,refund_lab_oracle,lab_to_targetProofTheory.make_init_def,
  EVAL ``good_dimindex(:64)``,EVAL ``arch_width_bits ^aw=dimindex(:64)``,
  EVAL ``stack_remove$max_stack_alloc<=2*data_to_word$max_heap_limit (dimindex(:64))^dc-1``,
  EVAL ``10<=^stk``]
 connected |> REWRITE_RULE[AND_IMP_INTRO,GSYM CONJ_ASSOC];
val refund_initialization_sufficient=save_thm("refund_initialization_sufficient",reduced);
val _=print("REMAINING_ANTECEDENTS "^Int.toString(length(strip_conj(fst(dest_imp(concl reduced)))))^"\n");
val _=Globals.max_print_depth:=1000;
val _=List.app(fn(name,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM")ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("CHECKED "^name^"\n"^Parse.thm_to_string th^"\n")end)
 [("refund_lab_code",refund_lab_code),("refund_lab_oracle",refund_lab_oracle),
  ("refund_initialization_sufficient",refund_initialization_sufficient)];
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

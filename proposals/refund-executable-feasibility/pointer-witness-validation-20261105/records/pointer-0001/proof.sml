load "forge_refundArm8ProofTheory";
open preamble backendProofTheory forge_refundStackInitializationTheory;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_refundPointerWitness";
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

val synv=find_term(fn tm=>is_var tm andalso fst(dest_var tm)="syn") w;
val synprime=mk_var("syn'",type_of synv);
fun prime t=subst[synv|->synprime]t;
val labprime=prime lab;
val wprime=prime w;
val base_congruence=prove(``^w = ^wprime with compile_oracle:=^wo``,
 `^lab = ^labprime with compile_oracle:=^lo` by
   MATCH_ACCEPT_TAC lab_to_targetProofTheory.make_init_compile_oracle >>
 pop_assum(fn th=>rewrite_tac[th]) >>
 rewrite_tac[stack_to_labProofTheory.full_make_init_lab_oracle] >>
 irule word_to_stackProofTheory.make_init_oracle_cong >>
 qexists_tac `^so` >>
 MATCH_ACCEPT_TAC stack_to_labProofTheory.full_make_init_compile_oracle);
val st=``^w with ffi:=basis_ffi$basis_ffi ext cl fs``;
val stprime=prime st;
val refund_initializer_oracle_independence=store_thm("refund_initializer_oracle_independence",
 ``^st = ^stprime with compile_oracle:=^wo``,
 mp_tac base_congruence >> simp[]);
val wst=mk_abs(synv,st);
val mkco=mk_abs(synv,wo);
val pointer=``wordProps$ptr_eq_fix Syn ^wst bvl_to_bvi$InitGlobals_location``;
val synfun=find_term(fn tm=>is_var tm andalso fst(dest_var tm)="Syn") pointer;
val fixed_state=``^wst (^synfun ^pointer)``;
val refund_pointer_fixed_point=store_thm("refund_pointer_fixed_point",``
 (!po po' i. (!j.j<=i ==> po j=po' j) ==> ^synfun po i=^synfun po' i) ==>
 !k.?rest.wordSem$evaluate(wordLang$Call NONE (SOME bvl_to_bvi$InitGlobals_location)[0]NONE,
   ^fixed_state with <|clock:=k;ptr_eq_oracle:=SOME ^pointer|>) =
 (I ## (\t.t with ptr_eq_oracle:=SOME rest))
  (wordSem$evaluate(wordLang$Call NONE (SOME bvl_to_bvi$InitGlobals_location)[0]NONE,
   ^fixed_state with clock:=k))``,
 strip_tac >> irule wordPropsTheory.ptr_eq_fix_thm >>
 conj_tac >- simp[] >>
 qexists_tac `^mkco` >> qexists_tac `^wst (K ((0,0),[]))` >>
 rpt conj_tac
 >- simp[word_to_stackProofTheory.make_init_def,data_to_word_memoryProofTheory.word_ptr_eq_def]
 >- (rpt strip_tac >> BETA_TAC >> irule cake_configs_prefix >> simp[])
 >- (rpt strip_tac >> BETA_TAC >> irule cake_orac_prefix >> simp[])
 >- (gen_tac >> BETA_TAC >> MATCH_ACCEPT_TAC refund_initializer_oracle_independence)
 >> simp[word_to_stackProofTheory.make_init_def]);
val fixed_syn=mk_abs(mk_var("po",type_of pointer),synv);
val fixed_pointer=subst[synfun|->fixed_syn]pointer;
val refund_fixed_syntax_pointer_witness=save_thm("refund_fixed_syntax_pointer_witness",
 INST[synfun|->fixed_syn]refund_pointer_fixed_point |> SIMP_RULE(srw_ss())[]);
val normalized_witness=SIMP_RULE(srw_ss())
 [word_to_stackProofTheory.make_init_def,LAMBDA_PROD]refund_fixed_syntax_pointer_witness;
val unbound=refund_stack_initialized_single_epoch |> Q.INST[`po`|->`^fixed_pointer`]
 |> SIMP_RULE(srw_ss())[LAMBDA_PROD] |> REWRITE_RULE[GSYM AND_IMP_INTRO] |> UNDISCH_ALL;
val _=if List.exists(fn p=>aconv p(concl normalized_witness))(hyp unbound) then () else
 (Globals.max_print_depth:=1000;
 print("NORMALIZED_POINTER "^Parse.thm_to_string normalized_witness^"\n");
 List.app(fn p=>if is_forall p then print("REQUIRED_POINTER "^Parse.term_to_string p^"\n") else ())(hyp unbound);
 raise Fail "Pointer premise shape mismatch");
val combined=PROVE_HYP normalized_witness unbound |> DISCH_ALL
 |> REWRITE_RULE[AND_IMP_INTRO,GSYM CONJ_ASSOC];
val _=print("REMAINING_ANTECEDENTS "^Int.toString(length(strip_conj(fst(dest_imp(concl combined)))))^"\n");
val _=if length(strip_conj(fst(dest_imp(concl combined))))=7 then () else raise Fail "Pointer premise not discharged";
val refund_witnessed_single_epoch=save_thm("refund_witnessed_single_epoch",combined);
val _=Globals.max_print_depth:=1000;
val _=List.app(fn(name,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM")ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("CHECKED "^name^"\n"^Parse.thm_to_string th^"\n")end)
 [("refund_initializer_oracle_independence",refund_initializer_oracle_independence),
  ("refund_pointer_fixed_point",refund_pointer_fixed_point),
  ("refund_fixed_syntax_pointer_witness",refund_fixed_syntax_pointer_witness),
  ("refund_witnessed_single_epoch",refund_witnessed_single_epoch)];
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

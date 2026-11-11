load "forge_refundArm8ProofTheory";
open preamble backendProofTheory forge_refundStackInitializationTheory forge_refundPointerWitnessTheory;
val _=new_theory "forge_pointerWitnessImport";
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
val st=``^w with ffi:=basis_ffi$basis_ffi ext cl fs``;
val stprime=subst[synv|->synprime]st;
val wst=mk_abs(synv,st);
val pointer=``wordProps$ptr_eq_fix Syn ^wst bvl_to_bvi$InitGlobals_location``;
val synfun=find_term(fn tm=>is_var tm andalso fst(dest_var tm)="Syn")pointer;
val fixed_state=``^wst (^synfun ^pointer)``;
val fixed_syn=mk_abs(mk_var("po",type_of pointer),synv);
val fixed_pointer=subst[synfun|->fixed_syn]pointer;
val expected_independence=``^st = ^stprime with compile_oracle:=^wo``;
val expected_general=``
 (!po po' i. (!j.j<=i ==> po j=po' j) ==> ^synfun po i=^synfun po' i) ==>
 !k.?rest.wordSem$evaluate(wordLang$Call NONE (SOME bvl_to_bvi$InitGlobals_location)[0]NONE,
   ^fixed_state with <|clock:=k;ptr_eq_oracle:=SOME ^pointer|>) =
 (I ## (\t.t with ptr_eq_oracle:=SOME rest))
  (wordSem$evaluate(wordLang$Call NONE (SOME bvl_to_bvi$InitGlobals_location)[0]NONE,
   ^fixed_state with clock:=k))``;
val expected_fixed=``
 !k.?rest.wordSem$evaluate(wordLang$Call NONE (SOME bvl_to_bvi$InitGlobals_location)[0]NONE,
   ^st with <|clock:=k;ptr_eq_oracle:=SOME ^fixed_pointer|>) =
 (I ## (\t.t with ptr_eq_oracle:=SOME rest))
  (wordSem$evaluate(wordLang$Call NONE (SOME bvl_to_bvi$InitGlobals_location)[0]NONE,
   ^st with clock:=k))``;
val expected_epoch=``
 STD_streams fs /\ wfFS fs /\ wfcl cl /\ (^s).stack<>[] /\ (^s).be=(^dc).be /\
 stdin_content fs=SOME(explode(sexp_to_string(refund_request charge request original
   remaining enabled opened candidate amount reason))) /\
 dataSem$data_lang_safe_for_space (basis_ffi$basis_ffi ext cl fs) ^fixed_pointer
  (sptree$fromAList(SND(backend$to_data ^cfg forge_refundWholeProg$refund_prog)))
  (data_to_wordProof$get_limits ^dc ^st)
  (^w).stack_size bvl_to_bvi$InitGlobals_location ==>
 !k.LENGTH(wordProps$ptr_eq_trace(wordLang$Call NONE (SOME bvl_to_bvi$InitGlobals_location)[0]NONE)
  (^st with clock:=k))=1``;
val _=Globals.max_print_depth:=1000;
fun assumptions name th=let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM")ors then ()
 else raise Fail("Unexpected assumptions: "^name)end;
val basic=[LET_THM,word_to_stackProofTheory.make_init_def,wordSemTheory.stack_size_def,LAMBDA_PROD];
fun norm rs t=rhs(concl(QCONV(SIMP_CONV(srw_ss())rs)t));
fun exact name e th=(if aconv(norm basic e)(norm basic(concl th)) then () else
 (print("EXPECTED "^Parse.term_to_string(norm basic e)^"\nACTUAL "^Parse.term_to_string(norm basic(concl th))^"\n");
 raise Fail("Exact statement mismatch: "^name));
 assumptions name th;print("IMPORTED "^name^" KERNEL_NORMALIZED_EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0\n"));
val _=exact "refund_initializer_oracle_independence" expected_independence refund_initializer_oracle_independence;
val _=exact "refund_pointer_fixed_point" expected_general refund_pointer_fixed_point;
val _=exact "refund_fixed_syntax_pointer_witness" expected_fixed refund_fixed_syntax_pointer_witness;
val oracle64=SIMP_RULE(srw_ss())[EVAL ``isa_bits ^ac``,LAMBDA_PROD]
 forge_refundWordOracleTheory.refund_word_oracle_binding;
val gc_normalized=SIMP_RULE(srw_ss())[LAMBDA_PROD]refund_stack_gc;
val norms=GSYM oracle64::gc_normalized::basic;
val(ep,ec)=dest_imp(norm norms expected_epoch);
val(ap,ac)=dest_imp(norm norms(concl refund_witnessed_single_epoch));
val _=if length(strip_conj ap)=7 andalso length(strip_conj ep)=7 then ()
 else raise Fail "Wrong complete premise count";
val _=if aconv ec ac then () else
 (print("EXPECTED_CONCLUSION "^Parse.term_to_string ec^"\nACTUAL_CONCLUSION "^Parse.term_to_string ac^"\n");
 raise Fail "Exact conclusion mismatch");
val eq=prove(mk_eq(ap,ep),EQ_TAC >> strip_tac >> fs[]);
val _=assumptions "refund_witnessed_single_epoch" refund_witnessed_single_epoch;
val _=print "IMPORTED refund_witnessed_single_epoch KERNEL_NORMALIZED_CONCLUSION true KERNEL_PREMISES_EQUIVALENT true HYPOTHESES 0 TAGGED_AXIOMS 0\n";
val _=if length(DB.theorems "forge_refundPointerWitness")=4 then () else raise Fail "Unexpected theorem count";

val substituted=subst[fixed_pointer|->mk_var("untrusted_po",type_of fixed_pointer)]expected_fixed;
val _=if aconv substituted expected_fixed then raise Fail "Control made no pointer substitution" else ();
val _=print "CONTROL substituted_pointer AFTER_POSITIVE_AUDIT\n";
val _=exact "refund_fixed_syntax_pointer_witness" substituted refund_fixed_syntax_pointer_witness;
val _=raise Fail "UNEXPECTED_CONTROL_ACCEPTANCE";

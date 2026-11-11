open preamble backendProofTheory forge_refundWordOracleTheory forge_refundStackInitializationTheory;
val _=new_theory "forge_stackInitializationImport";
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
val expected_gc=``(^s).gc_fun=word_gcFunctions$word_gc_fun ^dc``;
val expected_store=``data_to_word_gcProof$init_store_ok ^dc
 ((^s).store \\ stackLang$Handler) (^s).memory (^s).mdomain (^s).code_buffer (^s).data_buffer``;
val expected_compiler=``backendProof$backend_from_data_tuple_cc (:64) ^ac ^cfg =
 (\cf.OPTION_MAP(backend_common$bytes_to_mlstring ## MAP wordSem$upper_w2w ## I) o
  (\ps.(^w).compile cf (^full ps)) o MAP(data_to_word$compile_part ^dc))``;
val expected_epoch=``
 (!k.?rest.wordSem$evaluate(wordLang$Call NONE (SOME bvl_to_bvi$InitGlobals_location)[0]NONE,
   ^w with <|clock:=k;ptr_eq_oracle:=SOME po;ffi:=basis_ffi$basis_ffi ext cl fs|>) =
  (I ## (\s.s with ptr_eq_oracle:=SOME rest))
   (wordSem$evaluate(wordLang$Call NONE (SOME bvl_to_bvi$InitGlobals_location)[0]NONE,
    ^w with <|clock:=k;ffi:=basis_ffi$basis_ffi ext cl fs|>))) /\
 STD_streams fs /\ wfFS fs /\ wfcl cl /\ (^s).stack<>[] /\ (^s).be=(^dc).be /\
 stdin_content fs=SOME(explode(sexp_to_string(refund_request charge request original
   remaining enabled opened candidate amount reason))) /\
 dataSem$data_lang_safe_for_space (basis_ffi$basis_ffi ext cl fs) po
  (sptree$fromAList(SND(backend$to_data ^cfg forge_refundWholeProg$refund_prog)))
  (data_to_wordProof$get_limits ^dc (^w with ffi:=basis_ffi$basis_ffi ext cl fs))
  (^w).stack_size bvl_to_bvi$InitGlobals_location ==>
 !k.LENGTH(wordProps$ptr_eq_trace(wordLang$Call NONE (SOME bvl_to_bvi$InitGlobals_location)[0]NONE)
   (^w with <|clock:=k;ffi:=basis_ffi$basis_ffi ext cl fs|>))=1``;
val _=Globals.max_print_depth:=1000;
fun assumptions name th=let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name) end;
val basic=[LET_THM,word_to_stackProofTheory.make_init_def,LAMBDA_PROD];
fun norm rs t=rhs(concl(QCONV(SIMP_CONV(srw_ss())rs)t));
fun exact name e th=(if aconv(norm basic e)(norm basic(concl th)) then () else
 (print("EXPECTED "^Parse.term_to_string(norm basic e)^"\nACTUAL "^Parse.term_to_string(norm basic(concl th))^"\n");raise Fail("Exact statement mismatch: "^name));
 assumptions name th;print("IMPORTED "^name^" KERNEL_NORMALIZED_EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0\n"));
val _=exact "refund_stack_gc" expected_gc refund_stack_gc;
val _=exact "refund_stack_store" expected_store refund_stack_store;
val _=exact "refund_stack_compiler" expected_compiler refund_stack_compiler;
val oracle64=SIMP_RULE(srw_ss())[EVAL ``isa_bits ^ac``,LAMBDA_PROD] refund_word_oracle_binding;
val norms=GSYM oracle64::refund_stack_gc::wordSemTheory.stack_size_def::basic;
val (ep,ec)=dest_imp(norm norms expected_epoch);
val (ap,ac)=dest_imp(norm norms(concl refund_stack_initialized_single_epoch));
val _=if length(strip_conj ap)=8 andalso length(strip_conj ep)=8 then () else raise Fail "Wrong complete premise count";
val _=if aconv ec ac then () else
 (print("EXPECTED_CONCLUSION "^Parse.term_to_string ec^"\nACTUAL_CONCLUSION "^Parse.term_to_string ac^"\n");raise Fail "Exact conclusion mismatch");
val eq=prove(mk_eq(ap,ep),EQ_TAC >> strip_tac >> fs[]);
val _=assumptions "refund_stack_initialized_single_epoch" refund_stack_initialized_single_epoch;
val _=print "IMPORTED refund_stack_initialized_single_epoch KERNEL_NORMALIZED_CONCLUSION true KERNEL_PREMISES_EQUIVALENT true HYPOTHESES 0 TAGGED_AXIOMS 0\n";
val _=if length(DB.theorems "forge_refundStackInitialization")=4 then () else raise Fail "Unexpected theorem count";

val claimed_success=``IS_SOME(SND ^initial)``;
val stronger=mk_conj(ec,claimed_success);
val _=print "CONTROL unsupported_initializer_success AFTER_POSITIVE_AUDIT\n";
val _=if aconv (norm norms stronger) ac then () else
 raise Fail "Exact conclusion mismatch: unsupported_initializer_success";
val _=raise Fail "UNEXPECTED_CONTROL_ACCEPTANCE";

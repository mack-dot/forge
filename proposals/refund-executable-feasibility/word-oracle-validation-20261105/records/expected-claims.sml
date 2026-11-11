open preamble backendTheory backendProofTheory data_to_wordTheory
 forge_refundWordOracleTheory forge_refundInitializedEpochTheory;
val _=new_theory "forge_wordOracleImport";
val _=Globals.max_print_depth:=1000;
val cfg=``backend$set_oracle arm8_config$arm8_backend_config forge_refundArm8Compile$oracle``;
val ac=``arm8_target$arm8_config``;
val dc=``backend$ensure_fp_conf_ok ^ac (^cfg).data_conf``;
val dp=``sptree$fromAList(SND(backend$to_data ^cfg forge_refundWholeProg$refund_prog))``;
val wp=``sptree$fromAList(SND(backend$to_word ^ac ^cfg forge_refundWholeProg$refund_prog))``;
val regcount=``(^ac).reg_count - (LENGTH (^ac).avoid_regs + 5)``;
val proj=``SND o SND o SND o SND o SND o backendProof$config_tuple2``;
val data_oracle=``backendProof$cake_orac (:64) ^ac forge_refundArm8Compile$info syn ^proj (\ps.ps.data_prog)``;
val word_oracle=``backendProof$cake_orac (:64) ^ac forge_refundArm8Compile$info syn ^proj (\ps.ps.word_prog)``;
val full=``MAP(\(p:num # num # wordLang$prog # backend_common$metadata).
 word_to_word$full_compile_single (dimindex(:64)) (^ac).two_reg_arith ^regcount
 (^cfg).word_to_word_conf.reg_alg ^ac (p,NONE))``;
val init=``word_to_stackProof$make_init ^ac ^regcount
 (s:(64,lab_to_target$config,'ffi)stackSem$state) ^wp ^word_oracle
 (data_to_word_memoryProof$word_ptr_eq ^dc)``;
val tcc=``\conf progs.(^init).compile conf (^full progs)``;
val expected_oracle=``(I ## ^full) o (I ## MAP(data_to_word$compile_part ^dc)) o ^data_oracle = ^word_oracle``;
val expected_labels=``!n.EVERY ($<= backend_common$data_num_stubs)(MAP FST(SND(^data_oracle n)))``;
val expected_epoch=``
 let w=^init in
 (!k.?rest.wordSem$evaluate(wordLang$Call NONE (SOME bvl_to_bvi$InitGlobals_location)[0]NONE,
      w with <|clock:=k;ptr_eq_oracle:=SOME po;ffi:=basis_ffi$basis_ffi ext cl fs|>) =
  (I ## (\s.s with ptr_eq_oracle:=SOME rest))
   (wordSem$evaluate(wordLang$Call NONE (SOME bvl_to_bvi$InitGlobals_location)[0]NONE,
      w with <|clock:=k;ffi:=basis_ffi$basis_ffi ext cl fs|>))) /\
 STD_streams fs /\ wfFS fs /\ wfcl cl /\ s.stack<>[] /\ s.be=(^dc).be /\
 s.gc_fun=word_gcFunctions$word_gc_fun ^dc /\
 backendProof$backend_from_data_tuple_cc (:64) ^ac ^cfg =
  (\cfg.OPTION_MAP(backend_common$bytes_to_mlstring ## MAP wordSem$upper_w2w ## I) o
   ^tcc cfg o MAP(data_to_word$compile_part ^dc)) /\
 stdin_content fs=SOME(explode(sexp_to_string(refund_request charge request original
   remaining enabled opened candidate amount reason))) /\
 dataSem$data_lang_safe_for_space (basis_ffi$basis_ffi ext cl fs) po ^dp
  (data_to_wordProof$get_limits ^dc (w with ffi:=basis_ffi$basis_ffi ext cl fs))
  w.stack_size bvl_to_bvi$InitGlobals_location /\
 data_to_word_gcProof$init_store_ok ^dc (s.store \\ stackLang$Handler)
  s.memory s.mdomain s.code_buffer s.data_buffer ==>
 !k.LENGTH(wordProps$ptr_eq_trace(wordLang$Call NONE (SOME bvl_to_bvi$InitGlobals_location)[0]NONE)
  (w with <|clock:=k;ffi:=basis_ffi$basis_ffi ext cl fs|>))=1``;
fun assumptions name th=let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name) end;
val norms=[LET_THM,word_to_stackProofTheory.make_init_def,wordSemTheory.stack_size_def,
 EVAL ``isa_bits ^ac``,LAMBDA_PROD];
fun normalize t=rhs(concl(SIMP_CONV(srw_ss())norms t));
fun exact name e th=(
 if aconv(normalize e)(normalize(concl th)) then () else
 (print("EXPECTED "^Parse.term_to_string(normalize e)^"\nACTUAL "^Parse.term_to_string(normalize(concl th))^"\n");
  raise Fail("Exact statement mismatch: "^name));
 assumptions name th;print("IMPORTED "^name^" KERNEL_NORMALIZED_EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0\n"));

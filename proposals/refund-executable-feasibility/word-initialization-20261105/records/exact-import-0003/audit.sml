open preamble backendTheory backendProofTheory data_to_wordTheory
 data_to_word_gcProofTheory data_to_word_syntaxProofTheory word_to_wordProofTheory
 forge_refundWordInitializationTheory forge_refundInitializedEpochTheory;
val _=new_theory "forge_wordInitializationImport";
val cfg = ``backend$set_oracle arm8_config$arm8_backend_config forge_refundArm8Compile$oracle``;
val ac = ``arm8_target$arm8_config``;
val dc = ``backend$ensure_fp_conf_ok ^ac (^cfg).data_conf``;
val dp = ``sptree$fromAList(SND(backend$to_data ^cfg forge_refundWholeProg$refund_prog))``;
val wp = ``sptree$fromAList(SND(backend$to_word ^ac ^cfg forge_refundWholeProg$refund_prog))``;
val regcount = ``(^ac).reg_count - (LENGTH (^ac).avoid_regs + 5)``;
val init = ``word_to_stackProof$make_init ^ac ^regcount
 (s:(64,lab_to_target$config,'ffi)stackSem$state) ^wp co
 (data_to_word_memoryProof$word_ptr_eq ^dc)``;
val data_oracle = ``backendProof$cake_orac (:64) ^ac forge_refundArm8Compile$info syn
 (SND o SND o SND o SND o SND o backendProof$config_tuple2)(\ps.ps.data_prog)``;
val full = ``MAP(\(p:num # num # wordLang$prog # backend_common$metadata).word_to_word$full_compile_single (dimindex(:64)) (^ac).two_reg_arith
 ^regcount (^cfg).word_to_word_conf.reg_alg ^ac (p,NONE))``;
val expected_labels = ``EVERY (\n.backend_common$data_num_stubs <= n)
 (MAP FST(SND(backend$to_data ^cfg forge_refundWholeProg$refund_prog))) /\
 ALL_DISTINCT(MAP FST(SND(backend$to_data ^cfg forge_refundWholeProg$refund_prog)))``;
val expected_code = ``?rawcode.
 data_to_word_gcProof$code_rel ^dc ^dp rawcode /\
 word_to_wordProof$code_rel_ext (isa_bits ^ac) rawcode ^wp /\
 sptree$domain rawcode = sptree$domain ^wp``;
val expected_config = ``data_to_word$conf_ok (dimindex(:64)) ^dc /\
 (^dc).gc_kind <> data_to_word$None /\ isa_bits ^ac = dimindex(:64) /\
 misc$good_dimindex(:64)``;
val expected_epoch = ``
 let w = ^init in
 (!k. ?rest. wordSem$evaluate(wordLang$Call NONE (SOME bvl_to_bvi$InitGlobals_location)[0]NONE,
       w with <|clock:=k;ptr_eq_oracle:=SOME po;ffi:=basis_ffi$basis_ffi ext cl fs|>) =
   (I ## (\s.s with ptr_eq_oracle:=SOME rest))
    (wordSem$evaluate(wordLang$Call NONE (SOME bvl_to_bvi$InitGlobals_location)[0]NONE,
       w with <|clock:=k;ffi:=basis_ffi$basis_ffi ext cl fs|>))) /\
 (!n.EVERY (\(n,_).backend_common$data_num_stubs<=n)(SND(^data_oracle n))) /\
 Abbrev(tco=(I ## MAP(data_to_word$compile_part ^dc)) o ^data_oracle) /\
 Abbrev(tcc=(\conf progs.w.compile conf (^full progs))) /\
 STD_streams fs /\ wfFS fs /\ wfcl cl /\ s.stack <> [] /\ s.be=(^dc).be /\
 co=(I ## ^full) o tco /\ s.gc_fun=word_gcFunctions$word_gc_fun ^dc /\
 backendProof$backend_from_data_tuple_cc (:64) ^ac ^cfg =
  (\cfg.OPTION_MAP (backend_common$bytes_to_mlstring ## MAP wordSem$upper_w2w ## I) o
    tcc cfg o MAP(data_to_word$compile_part ^dc)) /\
 stdin_content fs=SOME(explode(sexp_to_string(refund_request charge request original
   remaining enabled opened candidate amount reason))) /\
 frames=w.stack_size /\
 dataSem$data_lang_safe_for_space (basis_ffi$basis_ffi ext cl fs) po ^dp
   (data_to_wordProof$get_limits ^dc (w with ffi:=basis_ffi$basis_ffi ext cl fs))
   frames bvl_to_bvi$InitGlobals_location /\
 data_to_word_gcProof$init_store_ok ^dc (s.store \\ stackLang$Handler)
   s.memory s.mdomain s.code_buffer s.data_buffer ==>
 !k.LENGTH(wordProps$ptr_eq_trace(wordLang$Call NONE (SOME bvl_to_bvi$InitGlobals_location)[0]NONE)
   (w with <|clock:=k;ffi:=basis_ffi$basis_ffi ext cl fs|>))=1``;
val expected_compiled_raw_code_rel = ``
 ALL_DISTINCT(MAP FST dp) /\
 EVERY (\n. backend_common$data_num_stubs <= n)(MAP FST dp) ==>
 data_to_word_gcProof$code_rel c (sptree$fromAList dp)
   (sptree$fromAList(data_to_word$stubs_md c ++ MAP(data_to_word$compile_part c)dp))``;
val expected_make_init_static = ``
 let w = word_to_stackProof$make_init ac k
  (s:('a,'c,'ffi)stackSem$state) wcode co pe in
 sptree$lookup 0 w.locals = SOME(wordSem$Loc 1 0) /\
 w.stack = [] /\ w.handler = 0 /\ w.termdep = 0 /\
 w.stack_max = SOME 1 /\ w.locals_size = SOME 0 /\
 w.ptr_eq_oracle = NONE /\ w.ptr_eq_rel = pe /\ w.code = wcode /\
 w.compile_oracle = co /\ w.stack_limit = LENGTH s.stack /\
 w.gc_fun = s.gc_fun /\ w.be = s.be /\ w.ffi = s.ffi``;
val expected_compiled_word_code_rel = ``
 data_to_word$compile dc wc ac dp = (col,wp) /\
 ALL_DISTINCT(MAP FST dp) /\
 EVERY (\n. backend_common$data_num_stubs <= n)(MAP FST dp) ==>
 ?rawcode.
 data_to_word_gcProof$code_rel (backend$ensure_fp_conf_ok ac dc)
   (sptree$fromAList dp) rawcode /\
 word_to_wordProof$code_rel_ext (isa_bits ac) rawcode (sptree$fromAList wp) /\
 sptree$domain rawcode = sptree$domain(sptree$fromAList wp)``;
val expected_to_word_code_rel = ``
 ALL_DISTINCT(MAP FST(SND(backend$to_data cfg prg))) /\
 EVERY (\n. backend_common$data_num_stubs <= n)(MAP FST(SND(backend$to_data cfg prg))) ==>
 ?rawcode.
 data_to_word_gcProof$code_rel (backend$ensure_fp_conf_ok ac cfg.data_conf)
   (sptree$fromAList(SND(backend$to_data cfg prg))) rawcode /\
 word_to_wordProof$code_rel_ext (isa_bits ac) rawcode
   (sptree$fromAList(SND(backend$to_word ac cfg prg))) /\
 sptree$domain rawcode = sptree$domain(sptree$fromAList(SND(backend$to_word ac cfg prg)))``;
val checks = [
 ("compiled_raw_code_rel",expected_compiled_raw_code_rel,compiled_raw_code_rel),
 ("make_init_static",expected_make_init_static,make_init_static),
 ("compiled_word_code_rel",expected_compiled_word_code_rel,compiled_word_code_rel),
 ("to_word_code_rel",expected_to_word_code_rel,to_word_code_rel),
 ("refund_data_labels",expected_labels,refund_data_labels),
 ("refund_word_code_rel",expected_code,refund_word_code_rel),
 ("refund_word_config_facts",expected_config,refund_word_config_facts)];
fun assumptions name th = let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name) end;
val _=List.app(fn(name,expected,th)=>
 (if aconv expected(concl th) then () else raise Fail("Exact statement mismatch: "^name);
 assumptions name th;
 print("IMPORTED "^name^" EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0\n")))checks;
val normalized = rhs(concl(SIMP_CONV (srw_ss())
 [LET_THM,word_to_stackProofTheory.make_init_def,wordSemTheory.stack_size_def] expected_epoch));
val (ep,ec)=dest_imp normalized;
val audited = SIMP_RULE bool_ss [LET_THM] refund_initialized_single_epoch;
val (ap,ac)=dest_imp(concl audited);
val _=if aconv ec ac then () else
 (print("EXPECTED_CONCLUSION "^Parse.term_to_string ec^"\nACTUAL_CONCLUSION "^Parse.term_to_string ac^"\n");
  raise Fail "Exact conclusion mismatch: refund_initialized_single_epoch");
val eq=prove(mk_eq(ap,ep),EQ_TAC >> strip_tac >> asm_simp_tac bool_ss [markerTheory.Abbrev_def]);
val _=assumptions "refund_initialized_single_epoch" refund_initialized_single_epoch;
val _=print "IMPORTED refund_initialized_single_epoch KERNEL_NORMALIZED_CONCLUSION true KERNEL_PREMISES_EQUIVALENT true HYPOTHESES 0 TAGGED_AXIOMS 0\n";
val _=if length(DB.theorems "forge_refundWordInitialization")=6 andalso
 length(DB.theorems "forge_refundInitializedEpoch")=2 then () else raise Fail "Unexpected theorem count";
val closure=Lib.mk_set("forge_refundInitializedEpoch"::Theory.ancestry "forge_refundInitializedEpoch");
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith ","(Theory.parents n)^"\n"))closure;
val _=List.app(fn n=>List.app(fn(a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"\n"))(DB.axioms n))closure;
val _=print "TRACE_IMPORT_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

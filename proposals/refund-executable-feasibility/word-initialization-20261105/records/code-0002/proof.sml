load "forge_refundArm8ProofTheory";
open preamble backendTheory backendProofTheory data_to_wordTheory
 data_to_word_gcProofTheory data_to_word_syntaxProofTheory word_to_wordProofTheory;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_refundWordInitialization";
val compiled_raw_code_rel = store_thm("compiled_raw_code_rel",``
 ALL_DISTINCT(MAP FST dp) /\
 EVERY (\n. backend_common$data_num_stubs <= n)(MAP FST dp) ==>
 data_to_word_gcProof$code_rel c (sptree$fromAList dp)
   (sptree$fromAList(data_to_word$stubs_md c ++ MAP(data_to_word$compile_part c)dp))``,
 strip_tac >> simp[data_to_word_gcProofTheory.code_rel_def] >>
 simp[lookup_fromAList,ALOOKUP_APPEND,EVERY_MEM,FORALL_PROD] >>
 conj_tac >-
  (fs[domain_fromAList] >> simp[Once UNION_COMM,SimpRHS] >> AP_TERM_TAC >>
   simp[data_to_wordTheory.compile_part_def,FST_triple,MAP_MAP_o,o_DEF,UNCURRY,ETA_AX]) >>
 conj_tac >-
  (rw[] >> metadata_drule(ONCE_REWRITE_RULE[CONJ_COMM] ALOOKUP_ALL_DISTINCT_MEM) >>
   impl_tac >- simp[data_to_wordTheory.stubs_md_def,MAP_MAP_o,o_DEF,UNCURRY,ETA_AX,
                   ALL_DISTINCT_MAP_FST_stubs] >> simp[]) >>
 rw[] >> reverse CASE_TAC >-
  (imp_res_tac ALOOKUP_MEM >> fs[data_to_wordTheory.stubs_md_def,MEM_MAP,EXISTS_PROD] >>
   fs[EVERY_MEM,EVERY_MAP,FORALL_PROD] >> res_tac >>
   imp_res_tac(SIMP_RULE(std_ss)[MEM_MAP,Once EXISTS_PROD,PULL_EXISTS]MAP_FST_stubs_bound) >> fs[]) >>
 match_mp_tac ALOOKUP_ALL_DISTINCT_MEM >>
 simp[MAP_MAP_o,o_DEF,UNCURRY,ETA_AX,data_to_wordTheory.compile_part_def,
      FST_triple,MEM_MAP,EXISTS_PROD] >> metis_tac[ALOOKUP_MEM]);
val exact_config_ok = prove(``
 backendProof$backend_config_ok arm8_target$arm8_config
  (backend$set_oracle arm8_config$arm8_backend_config forge_refundArm8Compile$oracle)``,
 simp[arm8_configProofTheory.arm8_backend_config_ok]);
val labels0 = MATCH_MP backendProofTheory.to_data_labels_ok
 (CONJ (cj 1 forge_refundArm8CompileTheory.refund_arm8_compiled) exact_config_ok);
val refund_data_labels = SIMP_RULE (srw_ss()) [LET_THM,UNCURRY] labels0
 |> (fn th=>save_thm("refund_data_labels",th));
val make_init_static = store_thm("make_init_static",``
 let w = word_to_stackProof$make_init ac k
  (s:('a,'c,'ffi)stackSem$state) wcode co pe in
 sptree$lookup 0 w.locals = SOME(wordSem$Loc 1 0) /\
 w.stack = [] /\ w.handler = 0 /\ w.termdep = 0 /\
 w.stack_max = SOME 1 /\ w.locals_size = SOME 0 /\
 w.ptr_eq_oracle = NONE /\ w.ptr_eq_rel = pe /\ w.code = wcode /\
 w.compile_oracle = co /\ w.stack_limit = LENGTH s.stack /\
 w.gc_fun = s.gc_fun /\ w.be = s.be /\ w.ffi = s.ffi``,
 simp[word_to_stackProofTheory.make_init_def,wordSemTheory.stack_size_def,
      lookup_insert,LET_THM]);
val compiled_word_code_rel = store_thm("compiled_word_code_rel",``
 data_to_word$compile dc wc ac dp = (col,wp) /\
 ALL_DISTINCT(MAP FST dp) /\
 EVERY (\n. backend_common$data_num_stubs <= n)(MAP FST dp) ==>
 ?rawcode.
 data_to_word_gcProof$code_rel (backend$ensure_fp_conf_ok ac dc)
   (sptree$fromAList dp) rawcode /\
 word_to_wordProof$code_rel_ext (asm$isa_bits ac) rawcode (sptree$fromAList wp) /\
 sptree$domain rawcode = sptree$domain(sptree$fromAList wp)``,
 strip_tac >> qabbrev_tac `dc' = backend$ensure_fp_conf_ok ac dc` >>
 `word_to_word$compile wc ac (data_to_word$stubs_md dc' ++
    MAP(data_to_word$compile_part dc')dp) = (col,wp)` by
   fs[data_to_wordTheory.compile_def,Abbr`dc'`,backendTheory.ensure_fp_conf_ok_def] >>
 qexists_tac `sptree$fromAList(data_to_word$stubs_md dc' ++ MAP(data_to_word$compile_part dc')dp)` >>
 conj_tac >- (irule compiled_raw_code_rel >> fs[Abbr`dc'`]) >>
 conj_tac >- metis_tac[word_to_wordProofTheory.code_rel_ext_word_to_word] >>
 `MAP FST wp = MAP FST(data_to_word$stubs_md dc') ++ MAP FST dp` by
  (mp_tac(Q.INST [`c`|->`(cfg:backend$config) with data_conf := dc'`,
    `c3`|->`dc'`,`c1`|->`wc`,`c2`|->`ac`,`prog`|->`dp`,`p`|->`wp`,`col`|->`col`]
    data_to_word_syntaxProofTheory.data_to_word_names) >> simp[]) >>
 simp[domain_fromAList,data_to_wordTheory.compile_part_def,FST_triple,
      MAP_MAP_o,o_DEF,UNCURRY,ETA_AX]);
val _=Globals.max_print_depth:=1000;
val _=List.app(fn(name,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("CHECKED "^name^"\n"^Parse.thm_to_string th^"\n") end)
 [("compiled_raw_code_rel",compiled_raw_code_rel),("refund_data_labels",refund_data_labels),
  ("make_init_static",make_init_static),("compiled_word_code_rel",compiled_word_code_rel)];
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

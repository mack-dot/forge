load "data_to_wordProofTheory";
open preamble;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_compilerWordTrace";
val error_implies_failure = store_thm("error_implies_failure",``
 FST(wordSem$evaluate(wordLang$Call NONE (SOME start) [0] NONE,
   s with clock := k)) = SOME wordSem$Error ==>
 wordSem$semantics s start = ffi$Fail``,
 strip_tac >> simp[wordSemTheory.semantics_def,LET_THM] >>
 IF_CASES_TAC >> simp[] >> fs[] >>
 first_x_assum(qspec_then `k` mp_tac) >> simp[]);
val semantics_nonerror = store_thm("semantics_nonerror",``
 wordSem$semantics s start <> ffi$Fail ==>
 !k. FST(wordSem$evaluate(wordLang$Call NONE (SOME start) [0] NONE,
   s with clock := k)) <> SOME wordSem$Error``,
 metis_tac[error_implies_failure]);
val extended_nonfailure = store_thm("extended_nonfailure",``
 x IN semanticsProps$extend_with_resource_limit' precise {y} /\
 y <> ffi$Fail ==> x <> ffi$Fail``,
 rw[semanticsPropsTheory.extend_with_resource_limit'_def] >> fs[] >>
 metis_tac[semanticsPropsTheory.extend_with_resource_limit_not_fail,IN_SING]);
val upstream = data_to_wordProofTheory.compile_semantics;
val (pre,_) = dest_imp(concl upstream);
val established = UNDISCH upstream;
val data_nonfail = List.last(CONJUNCTS(ASSUME pre)) |> ONCE_REWRITE_RULE[EQ_SYM_EQ];
val word_nonfail = MATCH_MP extended_nonfailure (CONJ (CONJUNCT2 established) data_nonfail);
val word_nonerror = MATCH_MP semantics_nonerror word_nonfail;
val compiled_word_nonerror = word_nonerror |> DISCH_ALL
 |> (fn th=>save_thm("compiled_word_nonerror",th));
val (space,_) = dest_imp(concl(CONJUNCT1 established));
val word_space = MP (CONJUNCT1 established) (ASSUME space);
val compiled_word_single_epoch =
 MATCH_MP forge_spaceInstallTraceTheory.safe_run_single_epoch (CONJ word_space word_nonerror)
 |> DISCH_ALL |> REWRITE_RULE[AND_IMP_INTRO,GSYM CONJ_ASSOC]
 |> (fn th=>save_thm("compiled_word_single_epoch",th));
val _=Globals.max_print_depth:=1000;
val _=List.app(fn(name,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("CHECKED "^name^"\n"^Parse.thm_to_string th^"\n") end)
 [("error_implies_failure",error_implies_failure),("semantics_nonerror",semantics_nonerror),
  ("extended_nonfailure",extended_nonfailure),("compiled_word_nonerror",compiled_word_nonerror),
  ("compiled_word_single_epoch",compiled_word_single_epoch)];
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

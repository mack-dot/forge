load "wordPropsTheory";
open preamble;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_installSpaceBarrier";
val install_outcomes = store_thm("install_outcomes",``
 wordSem$evaluate (wordLang$Install ptr len cptr dptr dend names,s) = (res,t) ==>
 (res = NONE /\ t.stack_max = NONE) \/
 (res = SOME wordSem$Error /\ t = s)``,
 rw[wordSemTheory.evaluate_def,AllCaseEqs()] >>
 rpt(pairarg_tac >> gvs[AllCaseEqs()]) >> gvs[AllCaseEqs()]);
val install_suffix_unbounded = store_thm("install_suffix_unbounded",``
 wordSem$evaluate (wordLang$Install ptr len cptr dptr dend names,s) = (NONE,t) /\
 wordSem$evaluate (suffix,t) = (res,u) ==> u.stack_max = NONE``,
 strip_tac >> imp_res_tac install_outcomes >> fs[] >>
 imp_res_tac wordPropsTheory.evaluate_stack_max >> fs[]);
val safe_run_excludes_install_suffix = store_thm("safe_run_excludes_install_suffix",``
 wordSem$word_lang_safe_for_space initial start /\
 wordSem$evaluate (wordLang$Call NONE (SOME start) [0] NONE,
   initial with clock := k) = (res,final) /\
 wordSem$evaluate (wordLang$Install ptr len cptr dptr dend names,s) = (NONE,t)
 ==> ~(?suffix r. wordSem$evaluate (suffix,t) = (r,final))``,
 rw[wordSemTheory.word_lang_safe_for_space_def,LET_THM] >>
 metis_tac[install_suffix_unbounded,optionTheory.NOT_SOME_NONE]);
val _=List.app(fn(name,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("CHECKED "^name^"\n"^Parse.thm_to_string th^"\n") end)
 [("install_outcomes",install_outcomes),("install_suffix_unbounded",install_suffix_unbounded),
  ("safe_run_excludes_install_suffix",safe_run_excludes_install_suffix)];
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

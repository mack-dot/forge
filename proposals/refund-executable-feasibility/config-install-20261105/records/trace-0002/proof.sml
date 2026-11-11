open preamble wordSemTheory wordPropsTheory forge_installSpaceBarrierTheory;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_spaceInstallTrace";
val epoch_single = store_thm("epoch_single",``
 LENGTH a = 1 /\ LENGTH b = 1 ==> LENGTH(wordProps$epoch_append a b) = 1``,
 Cases_on `a` >> Cases_on `b` >> simp[wordPropsTheory.epoch_append_def]);
fun show label (asl,w) = (print("UNSOLVED "^label^"\n"^String.concatWith "\n"(map term_to_string asl)^"\nGOAL "^term_to_string w^"\n"); ALL_TAC(asl,w));
val bounded_stack_single_epoch = store_thm("bounded_stack_single_epoch",``
 !p s res t. wordSem$evaluate(p,s) = (res,t) /\ IS_SOME t.stack_max ==>
 LENGTH(wordProps$ptr_eq_trace p s) = 1``,
 recInduct wordSemTheory.evaluate_ind >> rpt strip_tac
 >~ [`Install`] >-
   (imp_res_tac install_outcomes >> gvs[wordPropsTheory.ptr_eq_trace_def] >> show "Install")
 >~ [`MustTerminate`] >-
   (gvs[wordSemTheory.evaluate_def,wordPropsTheory.ptr_eq_trace_def,AllCaseEqs()] >>
    rpt(pairarg_tac >> gvs[AllCaseEqs()]) >> show "MustTerminate")
 >~ [`Seq`] >-
   (gvs[wordSemTheory.evaluate_def,wordPropsTheory.ptr_eq_trace_def,AllCaseEqs()] >>
    rpt(pairarg_tac >> gvs[AllCaseEqs()]) >>
    imp_res_tac wordPropsTheory.evaluate_stack_max_IS_SOME >> fs[] >>
    metis_tac[epoch_single] >> show "compound")
 >~ [`If`] >-
   (gvs[wordSemTheory.evaluate_def,wordPropsTheory.ptr_eq_trace_def,AllCaseEqs()] >> show "If")
 >~ [`Loop`] >-
   (gvs[wordSemTheory.evaluate_def,wordPropsTheory.ptr_eq_trace_def,AllCaseEqs(),UNCURRY_EQ] >>
    imp_res_tac wordPropsTheory.evaluate_stack_max_IS_SOME >>
    imp_res_tac wordPropsTheory.cut_state_const >> fs[STOP_def] >>
    metis_tac[epoch_single] >> show "compound")
 >~ [`Call`] >-
   (gvs[wordSemTheory.evaluate_def,wordPropsTheory.ptr_eq_trace_def,AllCaseEqs()] >>
    rpt(pairarg_tac >> gvs[AllCaseEqs()]) >>
    imp_res_tac wordPropsTheory.evaluate_stack_max_IS_SOME >>
    imp_res_tac wordPropsTheory.pop_env_const >> fs[] >>
    metis_tac[epoch_single] >> show "compound")
 >> rw[wordPropsTheory.ptr_eq_trace_def] >> every_case_tac >> fs[]);
val safe_run_single_epoch = store_thm("safe_run_single_epoch",``
 wordSem$word_lang_safe_for_space initial start ==>
 !k. LENGTH(wordProps$ptr_eq_trace (wordLang$Call NONE (SOME start) [0] NONE)
   (initial with clock := k)) = 1``,
 rw[wordSemTheory.word_lang_safe_for_space_def,LET_THM] >>
 Cases_on `wordSem$evaluate (wordLang$Call NONE (SOME start) [0] NONE,
   initial with clock := k)` >>
 metis_tac[bounded_stack_single_epoch,optionTheory.IS_SOME_DEF]);
val _=List.app(fn(name,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("CHECKED "^name^"\n"^Parse.thm_to_string th^"\n") end)
 [("epoch_single",epoch_single),("bounded_stack_single_epoch",bounded_stack_single_epoch),
  ("safe_run_single_epoch",safe_run_single_epoch)];
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

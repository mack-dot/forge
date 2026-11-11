load "forge_refundArm8ProofTheory";
open preamble forge_refundDataBehaviorTheory forge_compilerWordTraceTheory;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_refundWordPremises";
val determ_nonfailure = prove(``
 semantics$semantics_determ (s with ptr_eq_oracle := po) env prog = {d} /\
 ~semantics$semantics_prog s env prog ffi$Fail ==> d <> ffi$Fail``,
 strip_tac >>
 `~semantics$semantics_determ (s with ptr_eq_oracle := po) env prog ffi$Fail` by
   metis_tac[semanticsTheory.semantics_prog_def] >>
 metis_tac[IN_DEF,IN_SING]);
val source_nonfail = UNDISCH_ALL forge_refundWholeProgTheory.refund_semantics
 |> HO_MATCH_MP ml_progTheory.sem_satisfies_IMP_Terminate
 |> SRULE[forge_refundArm8CompileTheory.refund_arm8_compiled] |> CONJUNCT1;
val dn0 = MATCH_MP determ_nonfailure
 (CONJ (UNDISCH_ALL refund_data_behavior) source_nonfail);
val arbitrary_tracking = prove(``
 dataSem$semantics ffi dcode co cc po dataProps$zero_limits sptree$LN start <> ffi$Fail ==>
 dataSem$semantics ffi dcode co cc po lims frames start <> ffi$Fail``,
 simp[dataPropsTheory.semantics_zero_limits]);
val dn_general = MATCH_MP arbitrary_tracking dn0;
val dn = Q.INST [`lims` |-> `dataProps$zero_limits`] dn_general;
val refund_data_nonfailure = dn_general |> DISCH_ALL
 |> REWRITE_RULE[AND_IMP_INTRO,GSYM CONJ_ASSOC]
 |> (fn th=>save_thm("refund_data_nonfailure",th));
val _=print "EXACT_DATA_NONFAILURE_READY\n";
val word_base = compiled_word_single_epoch
 |> Q.INST [`fs` |-> `frames`]
 |> Q.GEN `t` |> ISPEC ``(t:(64,'c,'ffi)wordSem$state) with ffi := basis_ffi$basis_ffi ext cl fs``
 |> SIMP_RULE (srw_ss()) [GSYM AND_IMP_INTRO]
 |> UNDISCH_ALL;
val wanted = List.find (fn tm => can (find_term (fn t => same_const t ``dataSem$semantics``)) tm)
 (hyp word_base) |> valOf;
val _=print("MATCH_PREMISE "^Parse.term_to_string wanted^"\n");
val match_rule = DISCH wanted word_base;
val refund_word_single_epoch = MATCH_MP match_rule (ONCE_REWRITE_RULE[EQ_SYM_EQ] dn)
 |> DISCH_ALL |> REWRITE_RULE[AND_IMP_INTRO,GSYM CONJ_ASSOC]
 |> (fn th=>save_thm("refund_word_single_epoch",th));
val _=Globals.max_print_depth:=1000;
val _=List.app(fn(name,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("CHECKED "^name^"\n"^Parse.thm_to_string th^"\n") end)
 [("refund_data_nonfailure",refund_data_nonfailure),("refund_word_single_epoch",refund_word_single_epoch)];
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

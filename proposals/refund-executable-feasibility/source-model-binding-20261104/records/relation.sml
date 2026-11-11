open preamble forge_refundSourceBindingTheory forge_refundTheory;
open dafny_evaluateTheory dafny_semanticPrimitivesTheory;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_SOURCE_PROOF_OUT"));
val _=new_theory "forge_refundSourceRelation";
val source_model_result = store_thm("source_model_result", ``
  let source = evaluate_stmt
        (source_initial h charge request original remaining enabled opened candidate amount reason)
        env source_body;
      model = evaluate_stmt
        (refund_initial h charge request original remaining enabled opened candidate amount reason)
        env refund_body
  in SND source = SND model /\ (FST source).heap = (FST model).heap /\
     read_local (FST source).locals «authorized» = read_local (FST model).locals «v9» /\
     read_local (FST source).locals «outputAmount» = read_local (FST model).locals «v10» /\
     read_local (FST source).locals «outputReason» = read_local (FST model).locals «v11» /\
     read_local (FST source).locals «outputCharge» = read_local (FST model).locals «v12» /\
     read_local (FST source).locals «outputRequest» = read_local (FST model).locals «v13» /\
     read_local (FST source).locals «intentCount» = read_local (FST model).locals «v14»``,
  mp_tac(SPEC_ALL source_full_result) >> mp_tac(SPEC_ALL refund_full_result) >>
  simp[LET_THM] >> metis_tac[]);
val (ors,axs)=Tag.dest_tag(Thm.tag source_model_result);
val _=if null(hyp source_model_result) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors
      then () else raise Fail "Unexpected assumptions or oracle tags";
val _=print("CHECKED source_model_result "^Parse.thm_to_string source_model_result^"\n");
val _=export_theory();
val _=print "SOURCE_RELATION_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

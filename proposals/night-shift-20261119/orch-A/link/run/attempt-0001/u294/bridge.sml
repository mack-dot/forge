load "forge_refundCertifiedProgTheory";
open preamble forge_refundSourceBindingTheory forge_refundCertifiedProgTheory;
open dafny_evaluateTheory dafny_semanticPrimitivesTheory;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_SOURCE_PROOF_OUT"));
val _=new_theory "forge_refundCompiledInputBinding";
val source_compiled_fields = store_thm("source_compiled_fields", ``
  forge_refundCertifiedProg$refund_fields
    charge request original remaining enabled opened candidate amount reason = (ok,a,r,c,q,n) ==>
  let result = evaluate_stmt
        (source_initial h charge request original remaining enabled opened candidate amount reason)
        env source_body;
      final = FST result
  in SND result = Rstop Sret /\ final.heap = h /\
     read_local final.locals «authorized» = SOME(BoolV ok) /\
     read_local final.locals «outputAmount» = SOME(IntV a) /\
     read_local final.locals «outputReason» = SOME(StrV r) /\
     read_local final.locals «outputCharge» = SOME(StrV c) /\
     read_local final.locals «outputRequest» = SOME(StrV q) /\
     read_local final.locals «intentCount» = SOME(IntV n)``,
  strip_tac >> mp_tac(SPEC_ALL source_full_result) >> gvs[refund_fields_def,LET_THM]);
val (ors,axs)=Tag.dest_tag(Thm.tag source_compiled_fields);
val _=if null(hyp source_compiled_fields) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors
      then () else raise Fail "Unexpected assumptions or oracle tags";
val _=print("CHECKED source_compiled_fields "^Parse.thm_to_string source_compiled_fields^"\n");
val _=export_theory();
val _=print "SOURCE_BRIDGE_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

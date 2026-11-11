open preamble forge_refundSourceBindingTheory forge_refundTheory forge_refundSourceRelationTheory;
open dafny_evaluateTheory dafny_semanticPrimitivesTheory;
val expected = ``
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
     read_local (FST source).locals «intentCount» = read_local (FST model).locals «v14»``;
val th = forge_refundSourceRelationTheory.source_model_result;
val _=if aconv expected (concl th) then () else raise Fail "Exact source/model relation mismatch";
val (ors,axs)=Tag.dest_tag(Thm.tag th);
val _=if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then () else raise Fail "Unexpected relation assumption";
val _=if length(DB.theorems "forge_refundSourceRelation")=1 then () else raise Fail "Unexpected relation theorem count";
val _=print "IMPORTED source_model_result EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0\n";
val closure="forge_refundSourceRelation"::Theory.ancestry "forge_refundSourceRelation";
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith ","(Theory.parents n)^"\n")) closure;
val _=List.app(fn n=>List.app(fn(a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"\n"))(DB.axioms n)) closure;
val _=print "SOURCE_IMPORT_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

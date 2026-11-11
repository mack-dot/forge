load "forge_refundCertifiedProgTheory";
open preamble forge_refundSourceBindingTheory forge_refundCertifiedProgTheory forge_refundCompiledInputBindingTheory;
open dafny_evaluateTheory dafny_semanticPrimitivesTheory;
val expected = ``
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
     read_local final.locals «intentCount» = SOME(IntV n)``;
val th = forge_refundCompiledInputBindingTheory.source_compiled_fields;
val _=if aconv expected (concl th) then () else raise Fail "Exact compiled-field relation mismatch";
val (ors,axs)=Tag.dest_tag(Thm.tag th);
val _=if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then () else raise Fail "Unexpected bridge assumption";
val _=if length(DB.theorems "forge_refundCompiledInputBinding")=1 then () else raise Fail "Unexpected bridge theorem count";
val _=print "IMPORTED source_compiled_fields EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0\n";
val closure="forge_refundCompiledInputBinding"::Theory.ancestry "forge_refundCompiledInputBinding";
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith ","(Theory.parents n)^"\n")) closure;
val _=List.app(fn n=>List.app(fn(a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"\n"))(DB.axioms n)) closure;
val _=print "SOURCE_IMPORT_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

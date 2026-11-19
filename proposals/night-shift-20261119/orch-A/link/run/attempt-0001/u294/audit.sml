open preamble forge_refundSourceBindingTheory forge_refundTheory;
open dafny_astTheory dafny_evaluateTheory dafny_semanticPrimitivesTheory;
val expected_result = ``
  let initial = source_initial h charge request original remaining enabled opened candidate amount reason;
      result = evaluate_stmt initial env source_body;
      final = FST result;
      ok = eligible charge request original remaining enabled opened candidate amount reason
  in SND result = Rstop Sret /\ final.heap = h /\
     read_local final.locals «authorized» = SOME(BoolV ok) /\
     read_local final.locals «outputAmount» = SOME(IntV(if ok then amount else 0)) /\
     read_local final.locals «outputReason» = SOME(StrV(if ok then reason else «»)) /\
     read_local final.locals «outputCharge» = SOME(StrV(if ok then charge else «»)) /\
     read_local final.locals «outputRequest» = SOME(StrV(if ok then request else «»)) /\
     read_local final.locals «intentCount» = SOME(IntV(if ok then 1 else 0))``;
val expected_post = ``
  let initial = source_initial h charge request original remaining enabled opened candidate amount reason;
      final = FST(evaluate_stmt initial env source_body)
  in evaluate_exps final env source_ensures = (final,Rval[BoolV T;BoolV T;BoolV T])``;
val expected_decode = ``?se. mlsexp$parse source_export_text = INR(se,[]) /\
                             sexp_to_dafny$to_program se = INR source_program``;
val expected_signature = ``
  ?decrs. source_program = Program [Method «AssessFlat»
    [(«chargeId»,StrT);(«requestId»,StrT);(«original»,IntT);(«remaining»,IntT);
     («enabled»,BoolT);(«requestOpen»,BoolT);(«candidate»,BoolT);(«amount»,IntT);(«reason»,StrT)]
    [] source_ensures [] decrs
    [(«authorized»,BoolT);(«outputAmount»,IntT);(«outputReason»,StrT);
     («outputCharge»,StrT);(«outputRequest»,StrT);(«intentCount»,IntT)] [] source_body]``;
val expected_operators = ``
  do_bop Eq (BoolV a) (BoolV b) = SOME(BoolV(a <=> b)) /\
  do_bop Eq (StrV s) (StrV t) = SOME(BoolV(s=t)) /\
  do_bop Neq (StrV s) (StrV t) = SOME(BoolV(s<>t))``;
val expected_initial = ``
  source_initial h charge request original remaining enabled opened candidate amount reason =
    (init_state 0) with <|heap := h; locals :=
      [(«chargeId»,SOME(StrV charge));(«requestId»,SOME(StrV request));
       («original»,SOME(IntV original));(«remaining»,SOME(IntV remaining));
       («enabled»,SOME(BoolV enabled));(«requestOpen»,SOME(BoolV opened));
       («candidate»,SOME(BoolV candidate));(«amount»,SOME(IntV amount));(«reason»,SOME(StrV reason));
       («authorized»,NONE);(«outputAmount»,NONE);(«outputReason»,NONE);
       («outputCharge»,NONE);(«outputRequest»,NONE);(«intentCount»,NONE)]|>``;
val input = TextIO.openIn(valOf(OS.Process.getEnv "FORGE_SOURCE_SEXP"));
val text_tm = stringSyntax.fromMLstring(TextIO.inputAll input);
val _ = TextIO.closeIn input;
val expected_text = ``source_export_text = ^text_tm``;
val checks = [("source_full_result",expected_result,source_full_result),
              ("source_postconditions",expected_post,source_postconditions),
              ("source_decode",expected_decode,source_decode),
              ("source_signature",expected_signature,source_signature),
              ("mapped_operators",expected_operators,mapped_operators),
              ("source_initial_def",expected_initial,source_initial_def),
              ("source_export_text_def",expected_text,source_export_text_def)];
val _ = List.app(fn(name,expected,th)=>
  let val (ors,axs)=Tag.dest_tag(Thm.tag th) in
    if aconv expected (concl(SPEC_ALL th)) then () else raise Fail("Exact statement mismatch: "^name);
    if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
    else raise Fail("Unexpected assumption: "^name);
    print("IMPORTED "^name^" EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0 ORACLES "^String.concatWith "," ors^"\n")
  end) checks;
val _ = if length(DB.theorems "forge_refundSourceBinding")=5 then () else raise Fail "Unexpected theorem count";
val closure="forge_refundSourceBinding"::Theory.ancestry "forge_refundSourceBinding";
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith ","(Theory.parents n)^"\n")) closure;
val _=List.app(fn n=>List.app(fn(a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"\n"))(DB.axioms n)) closure;
val _=print "SOURCE_IMPORT_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

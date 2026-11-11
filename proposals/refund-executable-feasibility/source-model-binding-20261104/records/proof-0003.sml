load "sexp_to_dafnyTheory";
load "forge_refundTheory";
load "mlstringSyntax";
open preamble sexp_to_dafnyTheory forge_refundTheory;
open dafny_astTheory dafny_evaluateTheory dafny_semanticPrimitivesTheory;
val input = TextIO.openIn (valOf (OS.Process.getEnv "FORGE_SOURCE_SEXP"));
val source_bytes = TextIO.inputAll input;
val _ = TextIO.closeIn input;
val text_tm = stringSyntax.fromMLstring source_bytes;
val parse_th = EVAL ``mlsexp$parse ^text_tm``;
val (sexp_tm,rest_tm) = pairSyntax.dest_pair (#1 (sumSyntax.dest_inr (rhs (concl parse_th))));
val _ = if null (#1 (listSyntax.dest_list rest_tm)) then () else raise Fail "Trailing export bytes";
val ast_th = EVAL ``sexp_to_dafny$to_program ^sexp_tm``;
val program_tm = #1 (sumSyntax.dest_inr (rhs (concl ast_th)));
val (_, [members_tm]) = strip_comb program_tm;
val [member_tm] = #1 (listSyntax.dest_list members_tm);
val (method_con, args) = strip_comb member_tm;
val _ = if #Name (dest_thy_const method_con) = "Method" andalso length args = 9
        then () else raise Fail "Expected one Method";
val body_tm = List.nth(args,8);
val ensures_tm = List.nth(args,3);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_SOURCE_PROOF_OUT"));
val _ = new_theory "forge_refundSourceBinding";
val source_export_text_def = new_definition("source_export_text_def", ``source_export_text = ^text_tm``);
val source_program_def = new_definition("source_program_def", ``source_program = ^program_tm``);
val source_body_def = new_definition("source_body_def", ``source_body = ^body_tm``);
val source_ensures_def = new_definition("source_ensures_def", ``source_ensures = ^ensures_tm``);
val source_decode = store_thm("source_decode", ``
  ?se. mlsexp$parse source_export_text = INR(se,[]) /\
       sexp_to_dafny$to_program se = INR source_program``,
  EXISTS_TAC sexp_tm >> simp[source_export_text_def,source_program_def,parse_th,ast_th]);
val source_signature = store_thm("source_signature", ``
  ?decrs. source_program = Program [Method «AssessFlat»
    [(«chargeId»,StrT);(«requestId»,StrT);(«original»,IntT);(«remaining»,IntT);
     («enabled»,BoolT);(«requestOpen»,BoolT);(«candidate»,BoolT);(«amount»,IntT);(«reason»,StrT)]
    [] source_ensures [] decrs
    [(«authorized»,BoolT);(«outputAmount»,IntT);(«outputReason»,StrT);
     («outputCharge»,StrT);(«outputRequest»,StrT);(«intentCount»,IntT)] [] source_body]``,
  simp[source_program_def,source_ensures_def,source_body_def]);
val source_initial_def = new_definition("source_initial_def", ``
  source_initial h charge request original remaining enabled opened candidate amount reason =
    (init_state 0) with <|heap := h; locals :=
      [(«chargeId»,SOME(StrV charge));(«requestId»,SOME(StrV request));
       («original»,SOME(IntV original));(«remaining»,SOME(IntV remaining));
       («enabled»,SOME(BoolV enabled));(«requestOpen»,SOME(BoolV opened));
       («candidate»,SOME(BoolV candidate));(«amount»,SOME(IntV amount));(«reason»,SOME(StrV reason));
       («authorized»,NONE);(«outputAmount»,NONE);(«outputReason»,NONE);
       («outputCharge»,NONE);(«outputRequest»,NONE);(«intentCount»,NONE)]|>``);
val _ = computeLib.add_funs [assign_values_def,assign_value_def];
val source_full_result = store_thm("source_full_result", ``
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
     read_local final.locals «intentCount» = SOME(IntV(if ok then 1 else 0))``,
  EVAL_TAC >> rpt(IF_CASES_TAC >> fs[] >> EVAL_TAC));
val source_postconditions = store_thm("source_postconditions", ``
  let initial = source_initial h charge request original remaining enabled opened candidate amount reason;
      final = FST(evaluate_stmt initial env source_body)
  in evaluate_exps final env source_ensures = (final,Rval[BoolV T;BoolV T;BoolV T])``,
  EVAL_TAC >> rpt(IF_CASES_TAC >> fs[] >> EVAL_TAC));
val mapped_operators = store_thm("mapped_operators", ``
  do_bop Eq (BoolV a) (BoolV b) = SOME(BoolV(a <=> b)) /\
  do_bop Eq (StrV s) (StrV t) = SOME(BoolV(s=t)) /\
  do_bop Neq (StrV s) (StrV t) = SOME(BoolV(s<>t))``, EVAL_TAC);
val checked = [("source_decode",source_decode),("source_signature",source_signature),
               ("source_full_result",source_full_result),("source_postconditions",source_postconditions),
               ("mapped_operators",mapped_operators)];
val _ = List.app (fn (name,th) => let val (ors,axs)=Tag.dest_tag(Thm.tag th) in
  if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
  else raise Fail "Unexpected assumptions or oracle tags";
  print("CHECKED "^name^" "^Parse.thm_to_string th^"\n") end) checked;
val _ = export_theory();
val _ = print "SOURCE_BINDING_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

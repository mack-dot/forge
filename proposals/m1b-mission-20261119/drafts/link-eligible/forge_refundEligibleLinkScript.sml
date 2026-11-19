(* DRAFT (M1-B step I.1b, worker W2). NOT RUN. NOT CHECKED BY ANY TOOL.

   A `hol run` script in the style of the U294 source-binding proof
   (backup branch: proposals/refund-executable-feasibility/
    source-model-binding-20261104/records/proof-0004.sml, which ran exit 0).
   It is NOT a Holmake script, although the file name ends in Script.sml
   (the name was requested). Run it with `hol run --holstate=<cakeml-heap>`;
   see RUN_PLAN.md step H1.

   Input: the exact bytes of the real Dafny frontend export of FlatCore.dfy
   (3,621 bytes, SHA-256 58154ddffc3b54d875c51bcd9dd2f36a93334c5cc302c899987aec0d7333dd0d),
   given by the environment variable FORGE_ELIGIBLE_SEXP.
   Output folder: FORGE_P3_OUT (the variable that the recorded run_case.py sets).

   No axiom, no cheat, no mk_thm, no new_axiom, no oracle. The final check
   refuses any theorem with hypotheses, axiom tags or a tag other than DISK_THM.
   New semantics: none. The parser (mlsexp$parse, sexp_to_dafny$to_program) and
   the semantics (evaluate_exp) are the published CakeML definitions. *)

load "sexp_to_dafnyTheory";
load "forge_refundTheory";
load "mlstringSyntax";
open preamble sexp_to_dafnyTheory forge_refundTheory;
open dafny_astTheory dafny_evaluateTheory dafny_semanticPrimitivesTheory;

fun need name =
  case OS.Process.getEnv name of
    SOME v => v
  | NONE => raise Fail ("Missing environment variable " ^ name);

(* 1. Read the exact export bytes. The runner checks their SHA-256. *)
val input = TextIO.openIn (need "FORGE_ELIGIBLE_SEXP");
val source_bytes = TextIO.inputAll input;
val _ = TextIO.closeIn input;
val text_tm = stringSyntax.fromMLstring source_bytes;

(* 2. Parse with the published functions, by evaluation in the kernel. *)
val parse_th = EVAL ``mlsexp$parse ^text_tm``;
val (sexp_tm, rest_tm) =
  pairSyntax.dest_pair (#1 (sumSyntax.dest_inr (rhs (concl parse_th))));
val _ = if null (#1 (listSyntax.dest_list rest_tm)) then ()
        else raise Fail "Trailing export bytes";
val ast_th = EVAL ``sexp_to_dafny$to_program ^sexp_tm``;
val program_tm = #1 (sumSyntax.dest_inr (rhs (concl ast_th)));

(* 3. Locate subterms (ML only; the theorems below re-check the shape). *)
val (_, [members_tm]) = strip_comb program_tm;
val [member_tm] = #1 (listSyntax.dest_list members_tm);
val (method_con, margs) = strip_comb member_tm;
val _ = if #Name (dest_thy_const method_con) = "Method" andalso length margs = 9
        then () else raise Fail "Expected exactly one Method";
val ensures_tm = List.nth (margs, 3);
val decrs_tm = List.nth (margs, 5);
val body_tm = List.nth (margs, 8);
val (ens_list, _) = listSyntax.dest_list ensures_tm;
val first_ens = hd ens_list;
val ens_rest_tm = listSyntax.mk_list (tl ens_list, type_of first_ens);
val (binop_con, binop_args) = strip_comb first_ens;
val _ = if #Name (dest_thy_const binop_con) = "BinOp" andalso length binop_args = 3
        then () else raise Fail "First ensures clause is not a BinOp";
val [op_tm, lhs_tm, guard_tm] = binop_args;
val _ = if aconv op_tm ``dafny_ast$Eq`` andalso
           aconv lhs_tm ``dafny_ast$Var «authorized»``
        then () else raise Fail "First ensures clause is not (authorized == guard)";
val (_, [_, body_rest_tm]) = strip_comb body_tm;

val _ = OS.FileSys.chDir (need "FORGE_P3_OUT");
val _ = new_theory "forge_refundEligibleLink";

val eligible_link_text_def = new_definition ("eligible_link_text_def",
  ``eligible_link_text = ^text_tm``);
val eligible_link_program_def = new_definition ("eligible_link_program_def",
  ``eligible_link_program = ^program_tm``);
val eligible_link_guard_def = new_definition ("eligible_link_guard_def",
  ``eligible_link_guard = ^guard_tm``);

(* L1. The exact bytes parse completely to the stored program. *)
val eligible_link_decode = store_thm ("eligible_link_decode", ``
  ?se. mlsexp$parse eligible_link_text = INR (se, []) /\
       sexp_to_dafny$to_program se = INR eligible_link_program``,
  EXISTS_TAC sexp_tm >>
  simp [eligible_link_text_def, eligible_link_program_def, parse_th, ast_th]);

(* L2. The stored guard is BOTH the right-hand side of the first contract
   clause (authorized == guard) AND the expression that the method body
   assigns to `authorized` first. Signature: nine typed inputs, six typed
   outputs, no requires, no reads, no modifies. *)
val eligible_link_shape = store_thm ("eligible_link_shape", ``
  ?ens_rest decrs body_rest.
    eligible_link_program = Program [Method «AssessFlat»
      [(«chargeId»,StrT); («requestId»,StrT); («original»,IntT); («remaining»,IntT);
       («enabled»,BoolT); («requestOpen»,BoolT); («candidate»,BoolT);
       («amount»,IntT); («reason»,StrT)]
      []
      (BinOp dafny_ast$Eq (dafny_ast$Var «authorized») eligible_link_guard :: ens_rest)
      [] decrs
      [(«authorized»,BoolT); («outputAmount»,IntT); («outputReason»,StrT);
       («outputCharge»,StrT); («outputRequest»,StrT); («intentCount»,IntT)]
      []
      (Then (Assign [(VarLhs «authorized», ExpRhs eligible_link_guard)]) body_rest)]``,
  MAP_EVERY EXISTS_TAC [ens_rest_tm, decrs_tm, body_rest_tm] >>
  simp [eligible_link_program_def, eligible_link_guard_def]);

(* The state in which the guard is evaluated: the nine named, typed inputs,
   the six uninitialised outputs, an arbitrary heap h, and the other fields
   of the published init_state 0. Same shape as U294's source_initial. *)
val eligible_link_initial_def = new_definition ("eligible_link_initial_def", ``
  eligible_link_initial h charge request original remaining enabled opened
      candidate amount reason =
    (init_state 0) with <| heap := h; locals :=
      [(«chargeId», SOME (StrV charge)); («requestId», SOME (StrV request));
       («original», SOME (IntV original)); («remaining», SOME (IntV remaining));
       («enabled», SOME (BoolV enabled)); («requestOpen», SOME (BoolV opened));
       («candidate», SOME (BoolV candidate)); («amount», SOME (IntV amount));
       («reason», SOME (StrV reason));
       («authorized», NONE); («outputAmount», NONE); («outputReason», NONE);
       («outputCharge», NONE); («outputRequest», NONE); («intentCount», NONE)] |>``);

val _ = computeLib.add_funs [eligible_link_initial_def, eligible_link_guard_def];

(* L3 = THE FIRST THEOREM. For every heap, every environment and every
   typed input (all HOL integers, all booleans, all byte strings), the
   exported guard evaluates without error, leaves the state unchanged and
   returns BoolV of the HOL predicate `eligible` that the compiled-program
   theorems use (through refund_fields). *)
val eligible_link_guard_value = store_thm ("eligible_link_guard_value", ``
  evaluate_exp
    (eligible_link_initial h charge request original remaining enabled opened
       candidate amount reason) env eligible_link_guard =
  (eligible_link_initial h charge request original remaining enabled opened
     candidate amount reason,
   Rval (BoolV (eligible charge request original remaining enabled opened
     candidate amount reason)))``,
  EVAL_TAC >> rpt (IF_CASES_TAC >> fs [] >> EVAL_TAC));

(* L4. The exported guard and the constructed guard `refund_guard` (which
   the compiled method refund_method is built from) give the same result
   for every input. Only the variable names differ (chargeId.. vs v0..v8). *)
val eligible_link_matches_compiled_guard = store_thm (
  "eligible_link_matches_compiled_guard", ``
  SND (evaluate_exp
    (eligible_link_initial h charge request original remaining enabled opened
       candidate amount reason) env eligible_link_guard) =
  SND (evaluate_exp
    (refund_initial h' charge request original remaining enabled opened
       candidate amount reason) env' refund_guard)``,
  simp [eligible_link_guard_value, forge_refundTheory.refund_guard_value]);

(* L5. The meaning of the operators that the exported guard uses on strings
   and booleans: string Eq/Neq is equality of the byte lists; Boolean Eq is
   equivalence. *)
val eligible_link_operators = store_thm ("eligible_link_operators", ``
  (!s t. do_bop dafny_ast$Eq (StrV s) (StrV t) = SOME (BoolV (explode s = explode t))) /\
  (!s t. do_bop dafny_ast$Neq (StrV s) (StrV t) = SOME (BoolV (explode s <> explode t))) /\
  (!a b. do_bop dafny_ast$Eq (BoolV a) (BoolV b) = SOME (BoolV (a <=> b)))``,
  simp [do_bop_def, mlstringTheory.explode_11]);

val checked =
  [("eligible_link_decode", eligible_link_decode),
   ("eligible_link_shape", eligible_link_shape),
   ("eligible_link_guard_value", eligible_link_guard_value),
   ("eligible_link_matches_compiled_guard", eligible_link_matches_compiled_guard),
   ("eligible_link_operators", eligible_link_operators)];

val _ = List.app (fn (name, th) =>
  let val (ors, axs) = Tag.dest_tag (Thm.tag th) in
    if null (hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
    then ()
    else raise Fail ("Unexpected assumptions or tags: " ^ name);
    print ("FORGE_THEOREM " ^ name ^ "\n");
    print ("FORGE_ORACLES " ^ String.concatWith "," ors ^ "\n");
    print ("FORGE_AXIOMS " ^ String.concatWith "," axs ^ "\n");
    print ("FORGE_HYPOTHESES " ^ Int.toString (length (hyp th)) ^ "\n");
    print ("FORGE_STATEMENT " ^ Parse.thm_to_string th ^ "\n")
  end) checked;

val _ = export_theory ();
val _ = print "ELIGIBLE_LINK_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

(* DRAFT (M1-B wave 4, worker Y2, graph links S5 and S6). NOT RUN. NOT CHECKED BY ANY TOOL.

   A `hol run` script in the style of U294 proof-0004.sml (backup branch
   origin/backup/forge-local-2026-11-11, path
   proposals/refund-executable-feasibility/source-model-binding-20261104/records/proof-0004.sml,
   exit 0 on 2026-11-04). It is NOT a Holmake script. Run it only as RUN_PLAN.md says.

   Claim (S6): for every heap h, every environment env and every typed input
   (all HOL integers, all booleans, all mlstrings), the six outputs of the
   compiled HOL function forge_refundCertifiedProg$refund_fields satisfy ALL
   THREE ensures clauses of the EXPORTED flat contract (the real export of
   FlatCore.dfy, 3,621 bytes, SHA-256
   58154ddffc3b54d875c51bcd9dd2f36a93334c5cc302c899987aec0d7333dd0d),
   read by the published parser and evaluated by the published Dafny semantics.
   And the converse: a six-tuple satisfies the three clauses only if it IS
   the result of refund_fields (exported_contract_exact).

   The theorems do not read the method BODY of the export. The body is
   related to refund_fields separately by U294 (source_compiled_fields).

   Inputs (environment): FORGE_CONTRACT_SEXP (the export bytes; the runner
   checks the SHA-256), FORGE_P3_OUT (output folder; the runner sets it),
   CAKEMLDIR (the runner sets it).

   No axiom, no cheat, no mk_thm, no new_axiom, no oracle. The final check
   refuses any theorem with hypotheses, axiom tags or a tag other than DISK_THM. *)

fun need name =
  case OS.Process.getEnv name of
    SOME v => v
  | NONE => raise Fail ("Missing environment variable " ^ name);

(* Load path. The folder forge_refundProg_experiment that the CertifiedProg
   Holmakefile names is EMPTY since 2026-11-18 (environment-changes.json of
   the replay), so do not rely on Holmakefile INCLUDES. These lines only add
   folders; they change no file. *)
val dafny_dir = need "CAKEMLDIR" ^ "/compiler/dafny";
val _ = loadPath := dafny_dir :: (dafny_dir ^ "/forge_refund_experiment") ::
                    (dafny_dir ^ "/forge_refundCertifiedProg_experiment") :: !loadPath;

load "sexp_to_dafnyTheory";
load "forge_refundTheory";
load "forge_refundCertifiedProgTheory";
load "mlstringSyntax";
open preamble sexp_to_dafnyTheory forge_refundTheory;
open dafny_astTheory dafny_evaluateTheory dafny_semanticPrimitivesTheory;

(* 1. Read the exact export bytes. *)
val input = TextIO.openIn (need "FORGE_CONTRACT_SEXP");
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

(* 3. Locate subterms (ML only; theorem exported_contract_shape re-checks them). *)
val (_, [members_tm]) = strip_comb program_tm;
val member_tm = case #1 (listSyntax.dest_list members_tm) of
    [m] => m | _ => raise Fail "Expected exactly one member";
val (method_con, margs) = strip_comb member_tm;
val _ = if #Name (dest_thy_const method_con) = "Method" andalso length margs = 9
        then () else raise Fail "Expected exactly one Method";
val ensures_tm = List.nth (margs, 3);
val decrs_tm = List.nth (margs, 5);
val body_tm = List.nth (margs, 8);
val (ens1_tm, ens2_tm, ens3_tm) =
  case #1 (listSyntax.dest_list ensures_tm) of
    [e1, e2, e3] => (e1, e2, e3)
  | _ => raise Fail "Expected exactly three ensures clauses";

val _ = OS.FileSys.chDir (need "FORGE_P3_OUT");
val _ = new_theory "forge_refundExportedContract";

fun prove (name, tm, tac) =
  (print ("FORGE_BEGIN " ^ name ^ "\n"); store_thm (name, tm, tac));

val exported_contract_text_def = new_definition ("exported_contract_text_def",
  ``exported_contract_text = ^text_tm``);
val exported_contract_program_def = new_definition ("exported_contract_program_def",
  ``exported_contract_program = ^program_tm``);
val exported_ens1_def = new_definition ("exported_ens1_def", ``exported_ens1 = ^ens1_tm``);
val exported_ens2_def = new_definition ("exported_ens2_def", ``exported_ens2 = ^ens2_tm``);
val exported_ens3_def = new_definition ("exported_ens3_def", ``exported_ens3 = ^ens3_tm``);
val exported_ensures_def = new_definition ("exported_ensures_def",
  ``exported_ensures = [exported_ens1; exported_ens2; exported_ens3]``);

(* C1. The exact bytes parse completely to the stored program. *)
val exported_contract_decode = prove ("exported_contract_decode", ``
  ?se. mlsexp$parse exported_contract_text = INR (se, []) /\
       sexp_to_dafny$to_program se = INR exported_contract_program``,
  EXISTS_TAC sexp_tm >>
  simp [exported_contract_text_def, exported_contract_program_def, parse_th, ast_th]);

(* C2. The program is ONE method AssessFlat with the nine typed inputs in
   this order, no requires, no reads, no modifies, the six typed outputs in
   this order, and EXACTLY the three ensures clauses exported_ens1..3. *)
val exported_contract_shape = prove ("exported_contract_shape", ``
  ?decrs body.
    exported_contract_program = Program [Method «AssessFlat»
      [(«chargeId»,StrT); («requestId»,StrT); («original»,IntT); («remaining»,IntT);
       («enabled»,BoolT); («requestOpen»,BoolT); («candidate»,BoolT);
       («amount»,IntT); («reason»,StrT)]
      [] exported_ensures [] decrs
      [(«authorized»,BoolT); («outputAmount»,IntT); («outputReason»,StrT);
       («outputCharge»,StrT); («outputRequest»,StrT); («intentCount»,IntT)]
      [] body]``,
  (* simp, not REWRITE_TAC: the parser output and the «...» syntax may use
     different but equal mlstring forms; U294 source_signature closed the
     same kind of goal with simp. *)
  MAP_EVERY EXISTS_TAC [decrs_tm, body_tm] >>
  simp [exported_contract_program_def, exported_ensures_def,
        exported_ens1_def, exported_ens2_def, exported_ens3_def]);

(* The post-state in which an ensures clause is read: the nine named typed
   inputs and the six named typed outputs, all set; heap h; the other fields
   of the published init_state 0. Same names and order as U294 source_initial,
   with the outputs SOME instead of NONE. *)
val exported_contract_state_def = new_definition ("exported_contract_state_def", ``
  exported_contract_state h charge request original remaining enabled opened
      candidate amount reason ok a r c q n =
    (init_state 0) with <| heap := h; locals :=
      [(«chargeId», SOME (StrV charge)); («requestId», SOME (StrV request));
       («original», SOME (IntV original)); («remaining», SOME (IntV remaining));
       («enabled», SOME (BoolV enabled)); («requestOpen», SOME (BoolV opened));
       («candidate», SOME (BoolV candidate)); («amount», SOME (IntV amount));
       («reason», SOME (StrV reason));
       («authorized», SOME (BoolV ok)); («outputAmount», SOME (IntV a));
       («outputReason», SOME (StrV r)); («outputCharge», SOME (StrV c));
       («outputRequest», SOME (StrV q)); («intentCount», SOME (IntV n))] |>``);

val _ = computeLib.add_funs [exported_contract_state_def,
  exported_ens1_def, exported_ens2_def, exported_ens3_def];

(* C3-C5. The value of each clause, for ALL six output values (not only the
   values of refund_fields). No error; the state is unchanged. *)
val exported_ens1_value = prove ("exported_ens1_value", ``
  evaluate_exp (exported_contract_state h charge request original remaining enabled
      opened candidate amount reason ok a r c q n) env exported_ens1 =
  (exported_contract_state h charge request original remaining enabled opened
      candidate amount reason ok a r c q n,
   Rval (BoolV (ok <=> eligible charge request original remaining enabled opened
      candidate amount reason)))``,
  EVAL_TAC >> rpt (IF_CASES_TAC >> fs [] >> EVAL_TAC));

val exported_ens2_value = prove ("exported_ens2_value", ``
  evaluate_exp (exported_contract_state h charge request original remaining enabled
      opened candidate amount reason ok a r c q n) env exported_ens2 =
  (exported_contract_state h charge request original remaining enabled opened
      candidate amount reason ok a r c q n,
   Rval (BoolV (ok ==> a = amount /\ r = reason /\ c = charge /\ q = request /\ n = 1)))``,
  EVAL_TAC >> rpt (IF_CASES_TAC >> fs [] >> EVAL_TAC));

val exported_ens3_value = prove ("exported_ens3_value", ``
  evaluate_exp (exported_contract_state h charge request original remaining enabled
      opened candidate amount reason ok a r c q n) env exported_ens3 =
  (exported_contract_state h charge request original remaining enabled opened
      candidate amount reason ok a r c q n,
   Rval (BoolV (~ok ==> a = 0 /\ r = «» /\ c = «» /\ q = «» /\ n = 0)))``,
  EVAL_TAC >> rpt (IF_CASES_TAC >> fs [] >> EVAL_TAC));

(* C6. The value of the whole ensures list. *)
val exported_contract_value = prove ("exported_contract_value", ``
  evaluate_exps (exported_contract_state h charge request original remaining enabled
      opened candidate amount reason ok a r c q n) env exported_ensures =
  (exported_contract_state h charge request original remaining enabled opened
      candidate amount reason ok a r c q n,
   Rval [BoolV (ok <=> eligible charge request original remaining enabled opened
                         candidate amount reason);
         BoolV (ok ==> a = amount /\ r = reason /\ c = charge /\ q = request /\ n = 1);
         BoolV (~ok ==> a = 0 /\ r = «» /\ c = «» /\ q = «» /\ n = 0)])``,
  simp [exported_ensures_def, evaluate_exp_def,
        exported_ens1_value, exported_ens2_value, exported_ens3_value]);

(* C7 = THE S6 THEOREM. *)
val exported_contract_on_refund_fields = prove ("exported_contract_on_refund_fields", ``
  forge_refundCertifiedProg$refund_fields charge request original remaining enabled
      opened candidate amount reason = (ok,a,r,c,q,n) ==>
  evaluate_exps (exported_contract_state h charge request original remaining enabled
      opened candidate amount reason ok (a + 1) r c q n) env exported_ensures =
  (exported_contract_state h charge request original remaining enabled opened
      candidate amount reason ok (a + 1) r c q n,
   Rval [BoolV T; BoolV T; BoolV T])``,
  strip_tac >> simp [exported_contract_value] >>
  gvs [forge_refundCertifiedProgTheory.refund_fields_def, LET_THM] >> rw []);

(* C8. The converse: the exported contract leaves NO freedom. A six-tuple
   satisfies all three clauses if and only if it is the result of refund_fields. *)
val exported_contract_exact = prove ("exported_contract_exact", ``
  (evaluate_exps (exported_contract_state h charge request original remaining enabled
       opened candidate amount reason ok a r c q n) env exported_ensures =
   (exported_contract_state h charge request original remaining enabled opened
       candidate amount reason ok a r c q n,
    Rval [BoolV T; BoolV T; BoolV T])) <=>
  (forge_refundCertifiedProg$refund_fields charge request original remaining enabled
      opened candidate amount reason = (ok,a,r,c,q,n))``,
  simp [exported_contract_value, forge_refundCertifiedProgTheory.refund_fields_def, LET_THM] >>
  Cases_on `eligible charge request original remaining enabled opened candidate amount reason` >>
  Cases_on `ok` >> simp [] >> metis_tac []);

(* C9. Non-vacuity on the Dafny witnesses of LinkedRefund (WitnessAccepted,
   WitnessRejected), as bytes. *)
val exported_contract_witnesses = prove ("exported_contract_witnesses", ``
  forge_refundCertifiedProg$refund_fields «ch_1» «rq_1» 100 60 T T T 40 «duplicate_charge» =
    (T, 40, «duplicate_charge», «ch_1», «rq_1», 1) /\
  forge_refundCertifiedProg$refund_fields «ch_1» «rq_1» 100 60 T T T 61 «duplicate_charge» =
    (F, 0, «», «», «», 0)``,
  EVAL_TAC);

val checked =
  [("exported_contract_decode", exported_contract_decode),
   ("exported_contract_shape", exported_contract_shape),
   ("exported_ens1_value", exported_ens1_value),
   ("exported_ens2_value", exported_ens2_value),
   ("exported_ens3_value", exported_ens3_value),
   ("exported_contract_value", exported_contract_value),
   ("exported_contract_on_refund_fields", exported_contract_on_refund_fields),
   ("exported_contract_exact", exported_contract_exact),
   ("exported_contract_witnesses", exported_contract_witnesses)];

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
val _ = print "EXPORTED_CONTRACT_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

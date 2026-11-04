(* Proposed compiler relation for the exact refund body. No native claim.
   Unicode, calling/entry construction and native transfer remain open. *)
Theory forge_refund_compile
Ancestors
  forge_refund dafny_to_cakemlProof
Libs
  preamble

val generated = EVAL ``from_stmt refund_body 0``;
val generated_exp = rand (rhs (concl generated));

Definition refund_cml_def:
  refund_cml = ^generated_exp
End

val refund_compilation = save_thm ("refund_compilation",
  REWRITE_RULE [GSYM refund_cml_def] generated);

Theorem refund_static:
  is_fresh_stmt refund_body ∧
  (∀names. no_shadow names refund_body) ∧
  no_assert_stmt refund_body
Proof
  EVAL_TAC >> simp []
QED

Theorem refund_model_return:
  SND (evaluate_stmt
    (refund_initial h charge request original remaining enabled opened candidate amount reason)
    env refund_body) = Rstop Sret
Proof
  mp_tac refund_full_result >> simp []
QED

Theorem refund_statement_evaluation:
  evaluate_stmt
    (refund_initial h charge request original remaining enabled opened candidate amount reason)
    env refund_body =
  (FST (evaluate_stmt
    (refund_initial h charge request original remaining enabled opened candidate amount reason)
    env refund_body), Rstop Sret)
Proof
  metis_tac [PAIR, refund_model_return]
QED

val initial = ``refund_initial h charge request original remaining enabled opened candidate amount reason``;
val final = ``FST (evaluate_stmt ^initial env_dfy refund_body)``;
val instance = Q.SPECL
  [‘refund_initial h charge request original remaining enabled opened candidate amount reason’,
   ‘env_dfy’, ‘refund_body’, ‘FST (evaluate_stmt ^initial env_dfy refund_body)’,
   ‘Rstop Sret’, ‘0’, ‘t’, ‘env_cml’, ‘refund_cml’, ‘m’, ‘l’, ‘0’]
  correct_from_stmt;
val refund_compiler_relation = save_thm ("refund_compiler_relation",
  SIMP_RULE (srw_ss()) [refund_statement_evaluation, refund_compilation,
    refund_static, base_at_most_def] instance);

val _ = List.app
  (fn (name, th) =>
    let val (oracles, axioms) = Tag.dest_tag (Thm.tag th)
    in
      print ("FORGE_THEOREM " ^ name ^ "\n");
      print ("FORGE_ORACLES " ^ String.concatWith "," oracles ^ "\n");
      print ("FORGE_AXIOMS " ^ String.concatWith "," axioms ^ "\n");
      print ("FORGE_HYPOTHESES " ^ Int.toString (length (hyp th)) ^ "\n");
      print ("FORGE_STATEMENT " ^ Parse.thm_to_string th ^ "\n")
    end)
  [("refund_compilation", refund_compilation),
   ("refund_static", refund_static),
   ("refund_compiler_relation", refund_compiler_relation)];

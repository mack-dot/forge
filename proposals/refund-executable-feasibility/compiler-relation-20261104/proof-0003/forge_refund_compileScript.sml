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

Definition cml_has_local_def:
  cml_has_local l (t:'ffi semanticPrimitives$state) env name v ⇔
    ∃loc. FLOOKUP l name = SOME loc ∧
      store_lookup loc t.refs = SOME (Refv v) ∧
      nsLookup env.v (Short name) = SOME (Loc T loc)
End

(* Replays the published local projection lemma; no new state semantics. *)
Theorem related_local:
  read_local s.locals name = SOME dfy_v ∧
  state_rel m l s (t:'ffi semanticPrimitives$state) env ∧ is_fresh name ⇒
  ∃cml_v. val_rel m dfy_v cml_v ∧ cml_has_local l t env name cml_v
Proof
  gvs [state_rel_def, read_local_def, locals_rel_def, CaseEq "option",
       cml_has_local_def]
  >> rpt strip_tac >> first_x_assum drule_all >> rpt strip_tac >> gvs []
QED

Definition refund_cml_outputs_def:
  refund_cml_outputs l t env charge request original remaining enabled opened candidate amount reason ⇔
    let ok = eligible charge request original remaining enabled opened candidate amount reason in
    cml_has_local l t env «v9» (Boolv ok) ∧
    cml_has_local l t env «v10» (Litv (IntLit (if ok then amount else 0))) ∧
    cml_has_local l t env «v11» (Litv (StrLit (if ok then reason else «»))) ∧
    cml_has_local l t env «v12» (Litv (StrLit (if ok then charge else «»))) ∧
    cml_has_local l t env «v13» (Litv (StrLit (if ok then request else «»))) ∧
    cml_has_local l t env «v14» (Litv (IntLit (if ok then 1 else 0)))
End

Theorem refund_output_names_fresh:
  is_fresh «v9» ∧ is_fresh «v10» ∧ is_fresh «v11» ∧
  is_fresh «v12» ∧ is_fresh «v13» ∧ is_fresh «v14»
Proof
  EVAL_TAC
QED

Theorem refund_fields_transfer:
  state_rel m l
    (FST (evaluate_stmt
      (refund_initial h charge request original remaining enabled opened candidate amount reason)
      env refund_body)) t env_cml ⇒
  refund_cml_outputs l t env_cml charge request original remaining enabled opened candidate amount reason
Proof
  strip_tac
  >> mp_tac refund_full_result >> simp [] >> rpt strip_tac
  >> mp_tac refund_output_names_fresh >> rpt strip_tac
  >> imp_res_tac related_local
  >> fs [val_rel_simp, refund_cml_outputs_def]
QED

Theorem refund_compiled_behavior:
  state_rel m l
    (refund_initial h charge request original remaining enabled opened candidate amount reason)
    t env_cml ∧ env_rel env_dfy env_cml ⇒
  ∃ck t' m' r_cml.
    evaluate$evaluate (t with clock := t.clock + ck) env_cml [refund_cml] = (t',r_cml) ∧
    stmt_res_rel (Rstop Sret) r_cml ∧ cml_state_preserved t t' ∧
    refund_cml_outputs l t' env_cml charge request original remaining enabled opened candidate amount reason
Proof
  metis_tac [refund_compiler_relation, refund_fields_transfer]
QED

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
   ("refund_compiler_relation", refund_compiler_relation),
   ("refund_compiled_behavior", refund_compiled_behavior)];

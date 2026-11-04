(* Lift the existing refund exception contract through the actual main call.
   Use existing semantics only. This does not specify a native process status. *)
Theory forge_refundRejectProof
Ancestors
  forge_refundWholeProg forge_refundStdioProg cfMain
  semanticPrimitives ml_translator ml_prog cfHeaps cf cfApp
  evaluateProps evaluate evaluate_dec
Libs
  preamble cfLib

Theorem refund_call_main_exception:
  Decls env1 st1 prog env2 st2 ⇒
  lookup_var «refund_main» env2 = SOME refund_main_v ⇒
  app p refund_main_v [Conv NONE []] P (POSTe exn. Q exn) ⇒
  SPLIT (st2heap p st2) (h1,h2) ∧ P h1 ⇒
  ∃st3 exn.
    (∃ck1 ck2.
      evaluate_dec_list (st1 with clock := ck1) env1
        (SNOC (Dlet NoLocs (Pcon NONE [])
          (App Opapp [Var (Short «refund_main»); Con NONE []])) prog) =
        (st3 with clock := ck2, Rerr (Rraise exn))) ∧
    (∃h3 h4. SPLIT3 (st2heap p st3) (h3,h2,h4) ∧ Q exn h3)
Proof
  rw [app_def,app_basic_def] >>
  first_x_assum drule >> fs [] >> strip_tac >> fs [] >>
  fs [cfHeapsBaseTheory.POSTe_def,cfHeapsBaseTheory.POST_def] >>
  Cases_on ‘r’ >> fs [cond_STAR] >> fs [cond_def] >>
  rename1 ‘Q exn heap’ >>
  fs [Decls_def,evaluate_to_heap_def,evaluate_ck_def] >>
  drule evaluate_add_to_clock >>
  disch_then (qspec_then ‘ck2’ mp_tac) >> simp [] >>
  qpat_x_assum ‘_ env1 prog = _’ assume_tac >>
  drule evaluate_dec_list_add_to_clock >>
  disch_then (qspec_then ‘ck + 1’ mp_tac) >> simp [] >>
  rpt strip_tac >>
  qexists_tac ‘st'’ >> qexists_tac ‘exn’ >> conj_tac
  >- (MAP_EVERY qexists_tac [‘ck + (ck1 + 1)’, ‘ck2 + st'.clock’] >>
      simp [SNOC_APPEND,evaluate_dec_list_append,extend_dec_env_def] >>
      simp [evaluate_dec_list_def,astTheory.pat_bindings_def] >>
      NTAC 3 (simp [Once evaluate_def]) >>
      simp [do_con_check_def,build_conv_def] >>
      fs [Once evaluate_def,lookup_var_def,nsLookup_nsAppend_Short] >>
      simp [dec_clock_def,pmatch_def,combine_dec_result_def,
            merge_env_def,empty_env_def]) >>
  fs [] >> asm_exists_tac >> fs []
QED

val _ = Globals.max_print_depth := 1000;
val _ = List.app (fn (name,th) =>
  let val (oracles,axioms) = Tag.dest_tag (Thm.tag th) in
    print ("FORGE_THEOREM " ^ name ^ "\n");
    print ("FORGE_ORACLES " ^ String.concatWith "," oracles ^ "\n");
    print ("FORGE_AXIOMS " ^ String.concatWith "," axioms ^ "\n");
    print ("FORGE_HYPOTHESES " ^ Int.toString (length (hyp th)) ^ "\n");
    print ("FORGE_STATEMENT " ^ Parse.thm_to_string th ^ "\n")
  end) [("refund_call_main_exception",refund_call_main_exception)];

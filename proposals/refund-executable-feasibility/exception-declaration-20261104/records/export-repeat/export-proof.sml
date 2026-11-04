load "forge_refundWholeProgTheory";
load "cfMainTheory";
open preamble;
open forge_refundWholeProgTheory forge_refundStdioProgTheory cfMainTheory
     semanticPrimitivesTheory ml_translatorTheory ml_progTheory cfHeapsTheory
     cfTheory cfAppTheory evaluatePropsTheory evaluateTheory evaluate_decTheory
     namespaceTheory cfHeapsBaseTheory;
val _ = Globals.max_print_depth := 1000;
val _ = new_theory "forge_refundRejectDirect";
val expected = ``
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
    (∃h3 h4. SPLIT3 (st2heap p st3) (h3,h2,h4) ∧ Q exn h3)``;
val refund_call_main_exception = store_thm ("refund_call_main_exception", expected,
  rw [app_def,app_basic_def] >>
  first_x_assum drule >> fs [] >> strip_tac >> fs [] >>
  fs [cfHeapsBaseTheory.POSTe_def,cfHeapsBaseTheory.POST_def] >>
  Cases_on ‘r’ >> fs [set_sepTheory.cond_STAR] >> fs [set_sepTheory.cond_def] >>
  fs [Decls_def,evaluate_to_heap_def,evaluate_ck_def] >>
  drule evaluate_add_to_clock >>
  disch_then (qspec_then ‘ck2’ mp_tac) >> simp [] >>
  qpat_x_assum ‘_ env1 prog = _’ assume_tac >>
  drule evaluate_dec_list_add_to_clock >>
  disch_then (qspec_then ‘ck + 1’ mp_tac) >> simp [] >>
  rpt strip_tac >>
  qexists_tac ‘st'’ >> qexists_tac ‘v’ >> conj_tac
  >- (MAP_EVERY qexists_tac [‘ck + (ck1 + 1)’, ‘ck2 + st'.clock’] >>
      simp [SNOC_APPEND,evaluate_dec_list_append,extend_dec_env_def] >>
      simp [evaluate_dec_list_def,astTheory.pat_bindings_def] >>
      NTAC 3 (simp [Once evaluate_def]) >>
      simp [do_con_check_def,build_conv_def] >>
      fs [Once evaluate_def,lookup_var_def,nsLookup_nsAppend_Short] >>
      simp [dec_clock_def,pmatch_def,combine_dec_result_def,
            merge_env_def,empty_env_def] >>
      qpat_x_assum ‘SOME _ = do_opapp _’ (SUBST1_TAC o SYM) >>
      fs []) >>
  fs [] >> asm_exists_tac >> fs []);

val _ = if aconv (concl refund_call_main_exception) expected then ()
        else raise Fail "Required statement changed";
val (ors,axs) = Tag.dest_tag (Thm.tag refund_call_main_exception);
val _ = if null (hyp refund_call_main_exception) andalso null axs andalso
  List.all (fn s => s = "DISK_THM") ors then ()
  else raise Fail "Unexpected theorem dependencies";
val _ = print ("EXPORTED_REFUND_CALL_MAIN_EXCEPTION\n" ^ Parse.thm_to_string refund_call_main_exception ^ "\n");
val _ = print ("EXPORTED_ORACLES " ^ String.concatWith "," ors ^ "\n");
val _ = print "EXPORTED_HYPOTHESES 0\nEXPORTED_TAGGED_AXIOMS 0\n";
val _ = export_theory ();
val _ = print "DIRECT_EXPORT_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

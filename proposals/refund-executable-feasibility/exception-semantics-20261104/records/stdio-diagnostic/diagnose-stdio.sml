open preamble;
open forge_refundRejectDirectTheory forge_refundWholeProgTheory
     forge_refundStdioProgTheory forge_refundWireProgTheory cfMainTheory
     semanticPrimitivesTheory ml_translatorTheory ml_progTheory cfHeapsTheory
     cfTheory cfAppTheory evaluatePropsTheory evaluateTheory evaluate_decTheory
     namespaceTheory cfHeapsBaseTheory semanticsTheory;
val _ = Globals.max_print_depth := 1000;
val _ = new_theory "forge_refundRejectSemantics";

val refund_raise_determ = store_thm ("refund_raise_determ", ``
  evaluate_dec_list (st with clock := ck1) env prog =
    (st' with clock := ck2, Rerr (Rraise exn)) ⇒
  semantics_dec_list_determ st env prog
    (Terminate Success st'.ffi.io_events) ∧
  RTC call_FFI_rel st.ffi st'.ffi``,
  strip_tac >> conj_tac
  >- (simp [semantics_dec_list_determ_def,evaluate_dec_list_with_clock_def] >>
      qexists_tac ‘ck1’ >> simp []) >>
  drule evaluate_dec_list_call_FFI_rel_imp >> simp []);

val refund_exception_determ = store_thm ("refund_exception_determ", ``
  Decls env1 st1 prog env2 st2 ⇒
  lookup_var «refund_main» env2 = SOME refund_main_v ⇒
  app p refund_main_v [Conv NONE []] P (POSTe exn. Q exn) ⇒
  SPLIT (st2heap p st2) (h1,h2) ∧ P h1 ⇒
  ∃st3 exn.
    semantics_dec_list_determ st1 env1
      (SNOC (Dlet NoLocs (Pcon NONE [])
        (App Opapp [Var (Short «refund_main»); Con NONE []])) prog)
      (Terminate Success st3.ffi.io_events) ∧
    (∃h3 h4. SPLIT3 (st2heap p st3) (h3,h2,h4) ∧ Q exn h3) ∧
    RTC call_FFI_rel st1.ffi st3.ffi``,
  rpt strip_tac >>
  drule_all (GEN_ALL refund_call_main_exception) >>
  strip_tac >> drule refund_raise_determ >>
  strip_tac >> metis_tac []);

val refund_evaluate_dec_list_clock_result = store_thm ("refund_evaluate_dec_list_clock_result", ``
  evaluate_dec_list (st with clock := ck1) env prog = (s1,r1) ∧
  r1 ≠ Rerr (Rabort Rtimeout_error) ∧
  evaluate_dec_list (st with clock := ck2) env prog = (s2,r2) ∧
  r2 ≠ Rerr (Rabort Rtimeout_error) ⇒
  s1.ffi = s2.ffi ∧ r1 = r2``,
  strip_tac
  \\ qspecl_then [‘st with clock := ck1’,‘env’,‘prog’,‘s1’,‘r1’,‘ck2’]
       mp_tac evaluate_dec_list_add_to_clock
  \\ qspecl_then [‘st with clock := ck2’,‘env’,‘prog’,‘s2’,‘r2’,‘ck1’]
       mp_tac evaluate_dec_list_add_to_clock
  \\ simp [] \\ rpt strip_tac
  \\ gvs [AC arithmeticTheory.ADD_COMM arithmeticTheory.ADD_ASSOC,
          semanticPrimitivesTheory.state_component_equality]);

val refund_semantics_dec_list_determ_terminate_unique = store_thm ("refund_semantics_dec_list_determ_terminate_unique", ``
  semantics_dec_list_determ st env prog (Terminate outcome io) ∧
  semantics_dec_list_determ st env prog behavior ⇒
  behavior = Terminate outcome io``,
  strip_tac
  \\ Cases_on ‘behavior’
  \\ gvs [semantics_dec_list_determ_def,evaluate_dec_list_with_clock_def,
          pair_case_eq]
  >- (first_x_assum (qspec_then ‘k’ strip_assume_tac) \\ gvs [])
  \\ pairarg_tac \\ gvs []
  \\ pairarg_tac \\ gvs []
  \\ every_case_tac \\ gvs []
  \\ metis_tac [refund_evaluate_dec_list_clock_result, result_distinct,
                error_result_distinct, abort_distinct,
                result_11, error_result_11, abort_11]);

val refund_semantics_dec_list_all_terminate = store_thm ("refund_semantics_dec_list_all_terminate", ``
  (∀po. ∃outcome io.
    semantics_dec_list_determ (st with ptr_eq_oracle := po) env prog
      (Terminate outcome io) ∧ R (Terminate outcome io)) ⇒
  semantics_dec_list st env prog ≠ ∅ ∧
  ∀behavior. semantics_dec_list st env prog behavior ⇒ R behavior``,
  rw [semantics_dec_list_def,FUN_EQ_THM]
  \\ metis_tac [refund_semantics_dec_list_determ_terminate_unique]);

val refund_exception_semantics = store_thm ("refund_exception_semantics", ``
  Decls env1 st1 prog env2 st2 ⇒
  lookup_var «refund_main» env2 = SOME refund_main_v ⇒
  app p refund_main_v [Conv NONE []] P (POSTe exn. Q exn) ⇒
  SPLIT (st2heap p st2) (h1,h2) ∧ P h1 ⇒
  sem_satisfies (semantics_dec_list st1 env1
    (SNOC (Dlet NoLocs (Pcon NONE [])
      (App Opapp [Var (Short «refund_main»); Con NONE []])) prog))
    (λbehavior. ∃st3 exn.
      behavior = Terminate Success st3.ffi.io_events ∧
      (∃h3 h4. SPLIT3 (st2heap p st3) (h3,h2,h4) ∧ Q exn h3) ∧
      RTC call_FFI_rel st1.ffi st3.ffi)``,
  rpt strip_tac >>
  simp [semanticsPropsTheory.sem_satisfies_def, IN_DEF] >>
  ho_match_mp_tac refund_semantics_dec_list_all_terminate >> gen_tac >>
  ‘Decls env1 (st1 with ptr_eq_oracle := po) prog env2
     (st2 with ptr_eq_oracle := po)’ by metis_tac [Decls_with_oracle] >>
  ‘SPLIT (st2heap p (st2 with ptr_eq_oracle := po)) (h1,h2)’
     by fs [cfStoreTheory.st2heap_def] >>
  drule_all (GEN_ALL refund_exception_determ) >> simp [] >>
  strip_tac >> metis_tac []);

open proofManagerLib;
fun showgoals () = List.app (fn (hs,tm) =>
 (List.app (fn h => print ("DIAG_HYP " ^ Parse.term_to_string h ^ "\n")) hs;
  print ("DIAG_GOAL " ^ Parse.term_to_string tm ^ "\n"))) (top_goals ());
fun finish label = (print ("DIAG_STOP " ^ label ^ "\n");showgoals ();
 print "DIAGNOSTIC_COMPLETE\n";OS.Process.exit OS.Process.success);
fun step label tac = (print ("DIAG_STEP " ^ label ^ "\n"); e tac;showgoals ())
 handle ex => (print ("DIAG_EXCEPTION " ^ General.exnMessage ex ^ "\n");finish label);
val _ = print ("SOURCE_ERROR_CONTRACT " ^ Parse.thm_to_string refund_main_error ^ "\n");
val _ = g (`
  Decls env1 st1 prog env2 st2 ⇒
  lookup_var «refund_main» env2 = SOME refund_main_v ⇒
  stdin_content fs = SOME text ∧
  refund_run_wire (implode text) = INL err ⇒
  SPLIT (st2heap p st2) (h1,h2) ∧ STDIO fs h1 ⇒
  sem_satisfies (semantics_dec_list st1 env1
    (SNOC (Dlet NoLocs (Pcon NONE [])
      (App Opapp [Var (Short «refund_main»); Con NONE []])) prog))
    (λbehavior. ∃st3 exn.
      behavior = Terminate Success st3.ffi.io_events ∧
      (∃h3 h4. SPLIT3 (st2heap p st3) (h3,h2,h4) ∧
        (&Fail_exn err exn * STDIO (fastForwardFD fs 0)) h3) ∧
      RTC call_FFI_rel st1.ffi st3.ffi)`);
val _ = step "strip" (rpt strip_tac);
val _ = step "app-subgoal" (‘app p refund_main_v [Conv NONE []] (STDIO fs)
    (POSTe exn. &Fail_exn err exn * STDIO (fastForwardFD fs 0))’
    by (irule refund_main_error >> metis_tac []));
val _ = step "drule-all" (drule_all (GEN_ALL refund_exception_semantics));
val _ = step "simp" (simp []);
val _ = finish "end";

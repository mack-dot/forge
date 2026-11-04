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

val checked = [("refund_raise_determ",refund_raise_determ),
               ("refund_exception_determ",refund_exception_determ)];
val _ = List.app (fn (name,th) =>
  let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
    if null (hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
    then () else raise Fail ("Unexpected trust dependency: " ^ name);
    print ("CHECKED_THEOREM " ^ name ^ "\n" ^ Parse.thm_to_string th ^ "\n");
    print ("CHECKED_ORACLES " ^ String.concatWith "," ors ^ "\n");
    print "CHECKED_HYPOTHESES 0\nCHECKED_TAGGED_AXIOMS 0\n"
  end) checked;
val _ = export_theory ();
val _ = print "EXCEPTION_SEMANTICS_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

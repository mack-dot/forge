open HolKernel boolLib bossLib;
val _ = Globals.max_print_depth := 1000;
val expected = ``
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
      RTC call_FFI_rel st1.ffi st3.ffi)``;
val _ = if aconv expected (concl forge_refundRejectSemanticsTheory.refund_error_stdio_semantics)
 then () else raise Fail "Imported required statement differs";
val checked = [("refund_raise_determ",forge_refundRejectSemanticsTheory.refund_raise_determ),
("refund_exception_determ",forge_refundRejectSemanticsTheory.refund_exception_determ),
("refund_evaluate_dec_list_clock_result",forge_refundRejectSemanticsTheory.refund_evaluate_dec_list_clock_result),
("refund_semantics_dec_list_determ_terminate_unique",forge_refundRejectSemanticsTheory.refund_semantics_dec_list_determ_terminate_unique),
("refund_semantics_dec_list_all_terminate",forge_refundRejectSemanticsTheory.refund_semantics_dec_list_all_terminate),
("refund_exception_semantics",forge_refundRejectSemanticsTheory.refund_exception_semantics),
("refund_error_stdio_semantics",forge_refundRejectSemanticsTheory.refund_error_stdio_semantics)];
val _ = List.app (fn (name,th) =>
 let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
  then () else raise Fail ("Unexpected dependency: " ^ name);
  print ("IMPORTED_THEOREM " ^ name ^ "\n" ^ Parse.thm_to_string th ^ "\n");
  print ("IMPORTED_ORACLES " ^ String.concatWith "," ors ^ "\n");
  print "IMPORTED_HYPOTHESES 0\nIMPORTED_TAGGED_AXIOMS 0\n"
 end) checked;
val closure = "forge_refundRejectSemantics" :: Theory.ancestry "forge_refundRejectSemantics";
val _ = List.app (fn n => print ("CLOSURE_NODE " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n) ^ "\n")) closure;
val _ = List.app (fn n => List.app (fn (a,_) => print ("CLOSURE_AXIOM " ^ n ^ "." ^ a ^ "\n")) (DB.axioms n)) closure;
val _ = print "EXACT_EXPECTED_STATEMENT true\nIMPORT_AUDIT_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

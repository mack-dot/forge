open HolKernel boolLib bossLib;
val _ = Globals.max_print_depth := 1000;
val expected = ``
  Decls env1 (init_state (basis_ffi ext cl fs) with eval_state := es) prog env2 st2 ⇒
  lookup_var «refund_main» env2 = SOME refund_main_v ⇒
  stdin_content fs = SOME text ∧
  refund_run_wire (implode text) = INL err ⇒
  SPLIT (st2heap (basis_proj1,basis_proj2) st2) (h1,h2) ∧ STDIO fs h1 ⇒
  sem_satisfies
    (semantics_dec_list (init_state (basis_ffi ext cl fs) with eval_state := es) env1
      (SNOC (Dlet NoLocs (Pcon NONE [])
        (App Opapp [Var (Short «refund_main»); Con NONE []])) prog))
    (λbehavior. ∃st3 exn.
      behavior = Terminate Success st3.ffi.io_events ∧
      (∃h3 h4. SPLIT3 (st2heap (basis_proj1,basis_proj2) st3) (h3,h2,h4) ∧
        (&Fail_exn err exn * STDIO (fastForwardFD fs 0)) h3) ∧
      RTC call_FFI_rel (basis_ffi ext cl fs) st3.ffi ∧
      extract_fs ext (cl,fs) st3.ffi.io_events = SOME (fastForwardFD fs 0))``;
val _ = if aconv expected (concl forge_refundRejectBasisTheory.refund_error_basis_semantics)
 then () else raise Fail "Imported required statement differs";
val checked = [("refund_stdio_extract_fs",forge_refundRejectBasisTheory.refund_stdio_extract_fs),
("refund_sem_satisfies_imp",forge_refundRejectBasisTheory.refund_sem_satisfies_imp),
("refund_error_basis_semantics",forge_refundRejectBasisTheory.refund_error_basis_semantics)];
val _ = List.app (fn (name,th) =>
 let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
  then () else raise Fail ("Unexpected dependency: " ^ name);
  print ("IMPORTED_THEOREM " ^ name ^ "\n" ^ Parse.thm_to_string th ^ "\n");
  print ("IMPORTED_ORACLES " ^ String.concatWith "," ors ^ "\n");
  print "IMPORTED_HYPOTHESES 0\nIMPORTED_TAGGED_AXIOMS 0\n"
 end) checked;
val closure = "forge_refundRejectBasis" :: Theory.ancestry "forge_refundRejectBasis";
val _ = List.app (fn n => print ("CLOSURE_NODE " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n) ^ "\n")) closure;
val _ = List.app (fn n => List.app (fn (a,_) => print ("CLOSURE_AXIOM " ^ n ^ "." ^ a ^ "\n")) (DB.axioms n)) closure;
val _ = print "EXACT_EXPECTED_STATEMENT true\nIMPORT_AUDIT_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

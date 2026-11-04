open HolKernel boolLib bossLib;
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
val th = forge_refundRejectDirectTheory.refund_call_main_exception;
val _ = if aconv (concl th) expected then () else raise Fail "Imported statement differs";
val (ors,axs) = Tag.dest_tag (Thm.tag th);
val _ = if null (hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
  then () else raise Fail "Unexpected import dependency";
val closure = "forge_refundRejectDirect" :: Theory.ancestry "forge_refundRejectDirect";
val _ = List.app (fn n => print ("CLOSURE_NODE " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n) ^ "\n")) closure;
val _ = List.app (fn n => List.app (fn (a,_) => print ("CLOSURE_AXIOM " ^ n ^ "." ^ a ^ "\n")) (DB.axioms n)) closure;
val _ = print ("IMPORTED_THEOREM " ^ Parse.thm_to_string th ^ "\n");
val _ = print ("IMPORTED_ORACLES " ^ String.concatWith "," ors ^ "\n");
val _ = print "IMPORTED_HYPOTHESES 0\nIMPORTED_TAGGED_AXIOMS 0\nEXACT_EXPECTED_STATEMENT true\nIMPORT_AUDIT_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

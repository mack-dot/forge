open preamble forge_refundClosureInstallTheory;
val expected=``~closLang$has_install_list
  (SND(backend$to_clos arm8_config$arm8_backend_config
    forge_refundWholeProg$refund_prog))``;
val th=refund_closure_no_install;
val (ors,axs)=Tag.dest_tag(Thm.tag th);
val _=if aconv expected (concl th) then ()
      else raise Fail "Exact statement mismatch: refund_closure_no_install";
val _=if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors
      then () else raise Fail "Unexpected assumptions";
val _=print "IMPORTED refund_closure_no_install EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0\n";
val _=if length(DB.theorems "forge_refundClosureInstall")=1 then ()
      else raise Fail "Unexpected theorem count";
val closure=Lib.mk_set ("forge_refundClosureInstall"::Theory.ancestry "forge_refundClosureInstall");
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith ","(Theory.parents n)^"\n")) closure;
val _=List.app(fn n=>List.app(fn(a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"\n"))(DB.axioms n)) closure;
val _=print "CLOSURE_IMPORT_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

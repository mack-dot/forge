open preamble forge_refundClosureInstallTheory forge_refundConfigInstallTheory forge_installSpaceBarrierTheory;
val checks=[
 ("refund_closure_no_install",``~closLang$has_install_list
  (SND(backend$to_clos arm8_config$arm8_backend_config
    forge_refundWholeProg$refund_prog))``,refund_closure_no_install),
 ("to_clos_set_oracle",``
 !c p oracle.
   SND(backend$to_clos (backend$set_oracle c oracle) p) =
   SND(backend$to_clos c p)``,to_clos_set_oracle),
 ("refund_config_no_install",``
 !oracle. ~closLang$has_install_list
   (SND(backend$to_clos (backend$set_oracle arm8_config$arm8_backend_config oracle)
     forge_refundWholeProg$refund_prog))``,refund_config_no_install),
 ("install_outcomes",``
 wordSem$evaluate (wordLang$Install ptr len cptr dptr dend names,s) = (res,t) ==>
 (res = NONE /\ t.stack_max = NONE) \/
 (res = SOME wordSem$Error /\ t = s)``,install_outcomes),
 ("install_suffix_unbounded",``
 wordSem$evaluate (wordLang$Install ptr len cptr dptr dend names,s) = (NONE,t) /\
 wordSem$evaluate (suffix,t) = (res,u) ==> u.stack_max = NONE``,install_suffix_unbounded),
 ("safe_run_excludes_install_suffix",``
 T /\
 wordSem$evaluate (wordLang$Call NONE (SOME start) [0] NONE,
   initial with clock := k) = (res,final) /\
 wordSem$evaluate (wordLang$Install ptr len cptr dptr dend names,s) = (NONE,t)
 ==> ~(?suffix r. wordSem$evaluate (suffix,t) = (r,final))``,safe_run_excludes_install_suffix)];
val _=List.app(fn(name,expected,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if aconv expected (concl th) then () else raise Fail("Exact statement mismatch: "^name);
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("IMPORTED "^name^" EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0\n") end) checks;
val _=if length(DB.theorems "forge_refundClosureInstall")=1 andalso
         length(DB.theorems "forge_refundConfigInstall")=2 andalso
         length(DB.theorems "forge_installSpaceBarrier")=3
      then () else raise Fail "Unexpected theorem count";
val closure=Lib.mk_set (["forge_refundClosureInstall","forge_refundConfigInstall","forge_installSpaceBarrier"] @
 Theory.ancestry "forge_refundConfigInstall" @ Theory.ancestry "forge_installSpaceBarrier");
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith ","(Theory.parents n)^"\n")) closure;
val _=List.app(fn n=>List.app(fn(a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"\n"))(DB.axioms n)) closure;
val _=print "CONFIG_IMPORT_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

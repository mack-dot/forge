open preamble forge_spaceInstallTraceTheory;
val checks=[
 ("epoch_single",``
 LENGTH a = 1 /\ LENGTH b = 1 ==> LENGTH(wordProps$epoch_append a b) = 1``,epoch_single),
 ("bounded_stack_single_epoch",``
 !p s res t. wordSem$evaluate(p,s) = (res,t) /\ res <> SOME wordSem$Error /\ IS_SOME t.stack_max ==>
 LENGTH(wordProps$ptr_eq_trace p s) = 1``,bounded_stack_single_epoch),
 ("safe_run_single_epoch",``
 T /\
 (!k. FST(wordSem$evaluate (wordLang$Call NONE (SOME start) [0] NONE,
   initial with clock := k)) <> SOME wordSem$Error) ==>
 !k. LENGTH(wordProps$ptr_eq_trace (wordLang$Call NONE (SOME start) [0] NONE)
   (initial with clock := k)) = 1``,safe_run_single_epoch)];
val _=List.app(fn(name,expected,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if aconv expected (concl th) then () else raise Fail("Exact statement mismatch: "^name);
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("IMPORTED "^name^" EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0\n") end) checks;
val _=if length(DB.theorems "forge_spaceInstallTrace")=3 then ()
      else raise Fail "Unexpected theorem count";
val closure=Lib.mk_set ("forge_spaceInstallTrace"::Theory.ancestry "forge_spaceInstallTrace");
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith ","(Theory.parents n)^"\n")) closure;
val _=List.app(fn n=>List.app(fn(a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"\n"))(DB.axioms n)) closure;
val _=print "TRACE_IMPORT_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

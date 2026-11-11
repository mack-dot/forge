open preamble forge_compilerWordTraceTheory;
(* The compiler premises come from the pinned upstream theorem, not candidate exports. *)
val (pre,post)=dest_imp(concl data_to_wordProofTheory.compile_semantics);
val (space,_) = dest_imp(fst(dest_conj post));
val nonerror = ``!k. FST(wordSem$evaluate(wordLang$Call NONE (SOME start) [0] NONE,
 (t:(α,γ,'ffi)wordSem$state) with clock := k)) <> SOME wordSem$Error``;
val epoch = ``!k. LENGTH(wordProps$ptr_eq_trace (wordLang$Call NONE (SOME start) [0] NONE)
 ((t:(α,γ,'ffi)wordSem$state) with clock := k)) = 1``;
val expected_compiler_pre = pre;
val expected_epoch_pre = pre;
val checks=[
 ("error_implies_failure",``FST(wordSem$evaluate(wordLang$Call NONE (SOME start) [0] NONE,
 s with clock := k)) = SOME wordSem$Error ==> wordSem$semantics s start = ffi$Fail``,error_implies_failure),
 ("semantics_nonerror",``wordSem$semantics s start <> ffi$Fail ==>
 !k. FST(wordSem$evaluate(wordLang$Call NONE (SOME start) [0] NONE,
 s with clock := k)) <> SOME wordSem$Error``,semantics_nonerror),
 ("extended_nonfailure",``x IN semanticsProps$extend_with_resource_limit' precise {y} /\
 y <> ffi$Fail ==> x <> ffi$Fail``,extended_nonfailure),
 ("compiled_word_nonerror",mk_imp(expected_compiler_pre,nonerror),compiled_word_nonerror),
 ("compiled_word_single_epoch",mk_imp(expected_epoch_pre,epoch),compiled_word_single_epoch)];
val _=List.app(fn(name,expected,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if aconv expected (concl th) then () else raise Fail("Exact statement mismatch: "^name);
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("IMPORTED "^name^" EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0\n") end) checks;
val _=if length(DB.theorems "forge_compilerWordTrace")=5 then () else raise Fail "Unexpected theorem count";
val closure=Lib.mk_set("forge_compilerWordTrace"::Theory.ancestry "forge_compilerWordTrace");
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith ","(Theory.parents n)^"\n")) closure;
val _=List.app(fn n=>List.app(fn(a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"\n"))(DB.axioms n)) closure;
val _=print "TRACE_IMPORT_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

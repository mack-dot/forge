load "forge_refundArm8ProofTheory";
open preamble;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_badWordInitializer";
val wrong = prove(``
 sptree$lookup 0 (word_to_stackProof$make_init ac k
   (s:('a,'c,'ffi)stackSem$state) wcode co pe).locals = SOME(wordSem$Loc 1 1)``,
 simp[word_to_stackProofTheory.make_init_def,lookup_insert]);
val _=print "UNEXPECTED_CONTROL_ACCEPTANCE\n";
val _=OS.Process.exit OS.Process.success;

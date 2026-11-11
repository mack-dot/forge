load "forge_refundArm8ProofTheory";
open preamble;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_badWordInitializer";
val wrong = prove(``
 (word_to_stackProof$make_init ac k
   ((s:('a,'c,'ffi)stackSem$state) with stack := []) wcode co pe).stack_limit <> 0``,
 simp[word_to_stackProofTheory.make_init_def]);
val _=print "UNEXPECTED_CONTROL_ACCEPTANCE\n";
val _=OS.Process.exit OS.Process.success;

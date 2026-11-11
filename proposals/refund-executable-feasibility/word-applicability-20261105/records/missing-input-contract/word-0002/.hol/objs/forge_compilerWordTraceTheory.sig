signature forge_compilerWordTraceTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val compiled_word_nonerror : thm
    val compiled_word_single_epoch : thm
    val error_implies_failure : thm
    val extended_nonfailure : thm
    val semantics_nonerror : thm
end

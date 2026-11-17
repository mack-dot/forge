signature forge_compileCorrectControlTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val compile_correct' : thm
end

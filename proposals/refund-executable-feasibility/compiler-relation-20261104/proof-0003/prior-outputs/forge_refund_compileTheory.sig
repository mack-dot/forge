signature forge_refund_compileTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val refund_cml_def : thm
  
  (*  Theorems  *)
    val refund_compilation : thm
    val refund_compiler_relation : thm
    val refund_model_return : thm
    val refund_statement_evaluation : thm
    val refund_static : thm
end

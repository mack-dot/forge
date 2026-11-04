signature forge_refund_compileTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val cml_has_local_def : thm
    val refund_cml_def : thm
    val refund_cml_outputs_def : thm
  
  (*  Theorems  *)
    val refund_compilation : thm
    val refund_compiled_behavior : thm
    val refund_compiler_relation : thm
    val refund_fields_transfer : thm
    val refund_model_return : thm
    val refund_output_names_fresh : thm
    val refund_statement_evaluation : thm
    val refund_static : thm
    val related_local : thm
end

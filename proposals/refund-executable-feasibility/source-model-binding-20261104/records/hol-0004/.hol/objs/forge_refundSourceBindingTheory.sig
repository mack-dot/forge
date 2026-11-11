signature forge_refundSourceBindingTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val source_body_def : thm
    val source_ensures_def : thm
    val source_export_text_def : thm
    val source_initial_def : thm
    val source_program_def : thm
  
  (*  Theorems  *)
    val mapped_operators : thm
    val source_decode : thm
    val source_full_result : thm
    val source_postconditions : thm
    val source_signature : thm
end

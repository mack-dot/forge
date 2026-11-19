signature forge_refundEligibleLinkTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val eligible_link_guard_def : thm
    val eligible_link_initial_def : thm
    val eligible_link_program_def : thm
    val eligible_link_text_def : thm
  
  (*  Theorems  *)
    val eligible_link_decode : thm
    val eligible_link_guard_value : thm
    val eligible_link_matches_compiled_guard : thm
    val eligible_link_operators : thm
    val eligible_link_shape : thm
end

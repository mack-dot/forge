signature forge_refundExclusionRealTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val refund_installed_no_handler_def : thm
  
  (*  Theorems  *)
    val refund_compile_correct_no_handler : thm
    val refund_u298_exclusion_real : thm
end

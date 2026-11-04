signature forge_refundTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val eligible_def : thm
    val refund_body_def : thm
    val refund_guard_def : thm
    val refund_initial_def : thm
  
  (*  Theorems  *)
    val refund_full_result : thm
    val refund_guard_value : thm
end

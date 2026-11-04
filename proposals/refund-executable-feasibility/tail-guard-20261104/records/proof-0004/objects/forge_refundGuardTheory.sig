signature forge_refundGuardTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val refund_tail_env_def : thm
    val refund_tail_expr_def : thm
  
  (*  Theorems  *)
    val refund_tail_rejects : thm
end

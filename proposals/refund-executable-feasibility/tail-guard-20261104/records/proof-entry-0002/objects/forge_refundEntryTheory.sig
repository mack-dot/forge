signature forge_refundEntryTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val refund_actual_prefix_env_def : thm
    val refund_main_call_env_def : thm
  
  (*  Theorems  *)
    val refund_actual_main_prefix : thm
    val refund_actual_prefix_lookups : thm
    val refund_actual_prefix_rejects : thm
    val refund_tail_rejects_in_env : thm
    val single_recursive_call : thm
end

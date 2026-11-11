signature forge_refundStackInitializationTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_stack_compiler : thm
    val refund_stack_gc : thm
    val refund_stack_initialized_single_epoch : thm
    val refund_stack_store : thm
end

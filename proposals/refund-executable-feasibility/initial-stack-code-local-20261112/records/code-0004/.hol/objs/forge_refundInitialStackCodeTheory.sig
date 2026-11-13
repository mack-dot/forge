signature forge_refundInitialStackCodeTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_initial_stack_good : thm
    val refund_initialization_code : thm
    val refund_stack_lowering : thm
    val refund_word_labels : thm
    val refund_word_postalloc : thm
end

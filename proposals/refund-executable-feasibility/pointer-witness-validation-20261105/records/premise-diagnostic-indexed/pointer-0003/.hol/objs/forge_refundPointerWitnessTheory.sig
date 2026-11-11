signature forge_refundPointerWitnessTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_fixed_syntax_pointer_witness : thm
    val refund_initializer_oracle_independence : thm
    val refund_pointer_fixed_point : thm
    val refund_witnessed_single_epoch : thm
end

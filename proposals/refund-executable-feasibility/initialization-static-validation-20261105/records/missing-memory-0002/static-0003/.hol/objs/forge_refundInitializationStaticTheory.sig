signature forge_refundInitializationStaticTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_config_ok : thm
    val refund_initialization_static : thm
    val refund_name_permutation : thm
    val refund_stack_oracle_good : thm
end

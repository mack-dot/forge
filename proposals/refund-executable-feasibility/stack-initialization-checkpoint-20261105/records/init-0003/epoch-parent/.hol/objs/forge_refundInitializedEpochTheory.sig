signature forge_refundInitializedEpochTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_initialized_single_epoch : thm
    val refund_word_config_facts : thm
end

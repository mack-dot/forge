signature forge_refundWordOracleTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_data_oracle_labels : thm
    val refund_exact_oracle_single_epoch : thm
    val refund_word_oracle_binding : thm
end

signature forge_refundDataOracleTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val initial_oracle_relation : thm
    val refund_data_oracle_independence : thm
    val safe_data_execution : thm
end

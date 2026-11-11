signature forge_refundSuccessfulInitializationTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_initialization_sufficient : thm
    val refund_lab_code : thm
    val refund_lab_oracle : thm
end

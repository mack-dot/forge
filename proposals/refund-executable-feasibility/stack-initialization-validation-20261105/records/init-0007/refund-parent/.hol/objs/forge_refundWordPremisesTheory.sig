signature forge_refundWordPremisesTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_data_nonfailure : thm
    val refund_word_single_epoch : thm
end

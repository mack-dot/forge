signature forge_refundDataBehaviorTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val compiled_source_data : thm
    val refund_data_behavior : thm
end

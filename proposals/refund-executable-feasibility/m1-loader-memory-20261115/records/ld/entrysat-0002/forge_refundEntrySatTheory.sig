signature forge_refundEntrySatTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val sat_mem_def : thm
  
  (*  Theorems  *)
    val refund_entry_pre_satisfiable : thm
    val refund_entry_pre_witness : thm
    val sat_mem_image : thm
    val sat_separation : thm
    val sat_slot_0 : thm
    val sat_slot_16 : thm
    val sat_slot_8 : thm
end

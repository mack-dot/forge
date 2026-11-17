signature forge_refundSignedLenTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val addresses_below_half_def : thm
  
  (*  Theorems  *)
    val close_call_alen_below_half : thm
    val close_call_site_signed_alen : thm
    val heap_premises_admit_huge_heap : thm
    val read_bytearray_below_half_bound : thm
end

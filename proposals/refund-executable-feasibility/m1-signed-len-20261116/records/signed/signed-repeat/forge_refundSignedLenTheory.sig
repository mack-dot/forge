signature forge_refundSignedLenTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val addresses_below_half_def : thm
    val fficlose_call_pre_no_len_sign_def : thm
  
  (*  Theorems  *)
    val arbitrary_state_can_violate_arguments : thm
    val cake_fficlose_path_at_reachable_call_signed : thm
    val close_call_alen_below_half : thm
    val close_call_site_signed_alen : thm
    val close_call_site_signed_alen_model : thm
    val fficlose_call_pre_no_len_from_no_sign : thm
    val heap_premises_admit_huge_heap : thm
    val high_heap_end_not_below_half : thm
    val negative_alen_not_covered : thm
    val read_bytearray_below_half_bound : thm
    val refund_mem_dm_below_half : thm
    val universe_not_below_half : thm
end

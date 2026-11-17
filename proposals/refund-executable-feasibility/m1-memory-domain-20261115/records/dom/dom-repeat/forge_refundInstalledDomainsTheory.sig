signature forge_refundInstalledDomainsTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val refund_code_dm_def : thm
    val refund_end_state_def : thm
    val refund_heap_clear_def : thm
    val refund_mem_dm_def : thm
    val refund_t_def : thm
  
  (*  Theorems  *)
    val refund_bitmaps_dm_range : thm
    val refund_code_addr_in_dm : thm
    val refund_code_addr_not_excluded : thm
    val refund_code_buffer_in_dm : thm
    val refund_code_bytes_in_mem : thm
    val refund_code_loaded : thm
    val refund_end_state_established : thm
    val refund_heap_bitmaps_closed : thm
    val refund_heap_bitmaps_disjoint : thm
    val refund_heap_bitmaps_subset : thm
    val refund_heap_clear_IMP_header_separation : thm
    val refund_t_target_configured : thm
    val refund_t_target_state_rel : thm
end

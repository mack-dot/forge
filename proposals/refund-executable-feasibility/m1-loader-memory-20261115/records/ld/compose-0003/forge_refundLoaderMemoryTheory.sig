signature forge_refundLoaderMemoryTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val refund_bitmaps_dm_def : thm
    val refund_entry_pre_def : thm
  
  (*  Theorems  *)
    val bitmap_word_change_rejected : thm
    val bitmap_wrong_offset_rejected : thm
    val code_byte_change_rejected : thm
    val code_loaded_from_memory : thm
    val code_overlap_rejected : thm
    val code_wrong_offset_rejected : thm
    val header_on_bitmaps_refuted : thm
    val refund_bitmaps_dm_aligned : thm
    val refund_bitmaps_dm_closed : thm
    val refund_entry_pre_IMP_cml_main_pre : thm
    val refund_image_bitmap_clause : thm
    val refund_image_preserved : thm
    val refund_loader_startup : thm
end

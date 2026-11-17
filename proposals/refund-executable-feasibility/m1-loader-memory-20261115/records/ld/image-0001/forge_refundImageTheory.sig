signature forge_refundImageTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val le_num_def : thm
    val refund_file_def : thm
    val refund_image_mem_def : thm
  
  (*  Theorems  *)
    val layout_slices : thm
    val refund_code_data_samples : thm
    val refund_file_bitmap_length : thm
    val refund_file_bitmaps : thm
    val refund_file_cml_main : thm
    val refund_file_code : thm
    val refund_file_length : thm
    val refund_file_text_length : thm
    val refund_file_text_memory : thm
    val refund_image_bitmaps : thm
    val refund_image_cml_main : thm
    val refund_image_code : thm
    val refund_macho_fields : thm
end

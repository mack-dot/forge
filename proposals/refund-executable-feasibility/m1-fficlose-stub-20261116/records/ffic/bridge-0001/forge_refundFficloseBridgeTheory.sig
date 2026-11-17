signature forge_refundFficloseBridgeTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val refund_stub_only_ffi_def : thm
  
  (*  Theorems  *)
    val altered_stub_byte_rejected : thm
    val altered_stub_word_not_in_file : thm
    val arm8_run_add : thm
    val bytes_in_memory_slice : thm
    val cake_fficlose_stub_exact : thm
    val cake_fficlose_to_import_branch : thm
    val refund_file_fficlose_words : thm
    val refund_image_fficlose_code : thm
    val stub_only_ffi_rejected : thm
end

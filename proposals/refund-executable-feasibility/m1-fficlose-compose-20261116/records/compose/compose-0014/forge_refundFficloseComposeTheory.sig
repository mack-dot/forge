signature forge_refundFficloseComposeTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val close_call_rel_def : thm
    val close_result_byte_def : thm
    val fficlose_at_call_def : thm
    val fficlose_call_pre_def : thm
    val fficlose_path_def : thm
  
  (*  Theorems  *)
    val asm_write_bytearray_first_byte : thm
    val asm_write_bytearray_same_content : thm
    val cake_fficlose_path : thm
    val cake_fficlose_path_contract_instance : thm
    val cake_fficlose_reaches_call : thm
    val close_call_rel_gives_return_state : thm
    val fficlose_after_call : thm
    val mem_dword_frame_agree : thm
    val read_bytearray_nonempty : thm
    val refund_image_mem_agree : thm
end

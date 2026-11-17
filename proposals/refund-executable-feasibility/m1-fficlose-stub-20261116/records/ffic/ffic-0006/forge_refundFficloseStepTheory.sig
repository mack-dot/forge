signature forge_refundFficloseStepTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val arm8_user_def : thm
    val fficlose_code_bytes_def : thm
    val fficlose_entry_pre_def : thm
    val fficlose_return_pre_def : thm
    val fficlose_stub_pre_def : thm
  
  (*  Theorems  *)
    val cake_fficlose_stub_does_not_return : thm
    val cake_fficlose_stub_run : thm
    val cake_fficlose_stub_wrong_target_refuted : thm
    val fficlose_corrupted_frame_slot_clobbers_x19 : thm
    val fficlose_prefix_run : thm
    val fficlose_suffix_run : thm
    val fficlose_suffix_wrong_return_refuted : thm
end

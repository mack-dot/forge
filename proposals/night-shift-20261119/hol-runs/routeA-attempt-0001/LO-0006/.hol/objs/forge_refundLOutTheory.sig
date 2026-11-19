signature forge_refundLOutTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val ext_bad_def : thm
    val fd1_written_def_primitive : thm
    val fs0_def : thm
    val write_chunk_def : thm
    val write_chunk_nofd_def : thm
    val write_chunk_nosucc_def : thm
  
  (*  Theorems  *)
    val ALOOKUP_fs_ffi_part : thm
    val N_O1_free_ext_breaks : thm
    val N_O2_failed_write_counted_without_success_test : thm
    val N_O3_fd2_write_counted_without_fd_test : thm
    val P_O4_partial_write_counts_nw : thm
    val STD_streams_ADELKEY_File : thm
    val STD_streams_File_fd : thm
    val STD_streams_facts : thm
    val STD_streams_fs0 : thm
    val closeFD_stdout : thm
    val extract_fs_inode_tbl : thm
    val extract_no_ext_ExtCall : thm
    val extract_no_ext_stdout : thm
    val extract_no_ext_stdout_cons : thm
    val extract_no_ext_stdout_nil : thm
    val extract_no_ext_stdout_step : thm
    val extract_no_ext_stdout_step_ExtCall : thm
    val extract_no_ext_stdout_step_SharedMem : thm
    val extract_no_ext_stdout_step_basis_other : thm
    val extract_no_ext_stdout_step_event : thm
    val extract_no_ext_stdout_step_fs_ffi_part : thm
    val fd1_written_APPEND : thm
    val fd1_written_def : thm
    val fd1_written_ind : thm
    val fd1_written_prefix : thm
    val ffi_close_stdout_step : thm
    val ffi_open_in_stdout_step : thm
    val ffi_open_out_stdout_step : thm
    val ffi_read_stdout_step : thm
    val ffi_write_cases : thm
    val ffi_write_stdout_step : thm
    val fs_ffi_part_stdout_step : thm
    val openFile_stdout : thm
    val openFile_truncate_stdout : thm
    val read_stdout : thm
    val refund_L_OUT : thm
    val refund_L_OUT_prefix : thm
    val refund_profile_a_sl_fd1 : thm
    val refund_profile_a_sl_fd1_Resource_limit_hit : thm
    val refund_profile_a_sl_fd1_Success : thm
    val w22n_lt : thm
    val w22n_n2w2_bytes : thm
    val write_stdout : thm
end

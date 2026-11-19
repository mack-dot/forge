structure forge_refundLOutTheory :> forge_refundLOutTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundLOutTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundSlideProfileATheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundLOut",
        hash = "f82e9cb076cc59dcb771dd3564d5147b86c4ff29",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundLOut" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op write_stdout _ = () val op write_stdout = TDB.find "write_stdout"
  fun op write_chunk_nosucc_def _ = ()
  val op write_chunk_nosucc_def = TDB.find "write_chunk_nosucc_def"
  fun op write_chunk_nofd_def _ = ()
  val op write_chunk_nofd_def = TDB.find "write_chunk_nofd_def"
  fun op write_chunk_def _ = ()
  val op write_chunk_def = TDB.find "write_chunk_def"
  fun op w22n_n2w2_bytes _ = ()
  val op w22n_n2w2_bytes = TDB.find "w22n_n2w2_bytes"
  fun op w22n_lt _ = () val op w22n_lt = TDB.find "w22n_lt"
  fun op refund_profile_a_sl_fd1_Success _ = ()
  val op refund_profile_a_sl_fd1_Success = TDB.find
    "refund_profile_a_sl_fd1_Success"
  fun op refund_profile_a_sl_fd1_Resource_limit_hit _ = ()
  val op refund_profile_a_sl_fd1_Resource_limit_hit = TDB.find
    "refund_profile_a_sl_fd1_Resource_limit_hit"
  fun op refund_profile_a_sl_fd1 _ = ()
  val op refund_profile_a_sl_fd1 = TDB.find "refund_profile_a_sl_fd1"
  fun op refund_L_OUT_prefix _ = ()
  val op refund_L_OUT_prefix = TDB.find "refund_L_OUT_prefix"
  fun op refund_L_OUT _ = () val op refund_L_OUT = TDB.find "refund_L_OUT"
  fun op read_stdout _ = () val op read_stdout = TDB.find "read_stdout"
  fun op openFile_truncate_stdout _ = ()
  val op openFile_truncate_stdout = TDB.find "openFile_truncate_stdout"
  fun op openFile_stdout _ = ()
  val op openFile_stdout = TDB.find "openFile_stdout"
  fun op fs_ffi_part_stdout_step _ = ()
  val op fs_ffi_part_stdout_step = TDB.find "fs_ffi_part_stdout_step"
  fun op fs0_def _ = () val op fs0_def = TDB.find "fs0_def"
  fun op ffi_write_stdout_step _ = ()
  val op ffi_write_stdout_step = TDB.find "ffi_write_stdout_step"
  fun op ffi_write_cases _ = ()
  val op ffi_write_cases = TDB.find "ffi_write_cases"
  fun op ffi_read_stdout_step _ = ()
  val op ffi_read_stdout_step = TDB.find "ffi_read_stdout_step"
  fun op ffi_open_out_stdout_step _ = ()
  val op ffi_open_out_stdout_step = TDB.find "ffi_open_out_stdout_step"
  fun op ffi_open_in_stdout_step _ = ()
  val op ffi_open_in_stdout_step = TDB.find "ffi_open_in_stdout_step"
  fun op ffi_close_stdout_step _ = ()
  val op ffi_close_stdout_step = TDB.find "ffi_close_stdout_step"
  fun op fd1_written_prefix _ = ()
  val op fd1_written_prefix = TDB.find "fd1_written_prefix"
  fun op fd1_written_ind _ = ()
  val op fd1_written_ind = TDB.find "fd1_written_ind"
  fun op fd1_written_def_primitive _ = ()
  val op fd1_written_def_primitive = TDB.find "fd1_written_def_primitive"
  fun op fd1_written_def _ = ()
  val op fd1_written_def = TDB.find "fd1_written_def"
  fun op fd1_written_APPEND _ = ()
  val op fd1_written_APPEND = TDB.find "fd1_written_APPEND"
  fun op extract_no_ext_stdout_step_fs_ffi_part _ = ()
  val op extract_no_ext_stdout_step_fs_ffi_part = TDB.find
    "extract_no_ext_stdout_step_fs_ffi_part"
  fun op extract_no_ext_stdout_step_event _ = ()
  val op extract_no_ext_stdout_step_event = TDB.find
    "extract_no_ext_stdout_step_event"
  fun op extract_no_ext_stdout_step_basis_other _ = ()
  val op extract_no_ext_stdout_step_basis_other = TDB.find
    "extract_no_ext_stdout_step_basis_other"
  fun op extract_no_ext_stdout_step_SharedMem _ = ()
  val op extract_no_ext_stdout_step_SharedMem = TDB.find
    "extract_no_ext_stdout_step_SharedMem"
  fun op extract_no_ext_stdout_step_ExtCall _ = ()
  val op extract_no_ext_stdout_step_ExtCall = TDB.find
    "extract_no_ext_stdout_step_ExtCall"
  fun op extract_no_ext_stdout_step _ = ()
  val op extract_no_ext_stdout_step = TDB.find "extract_no_ext_stdout_step"
  fun op extract_no_ext_stdout_nil _ = ()
  val op extract_no_ext_stdout_nil = TDB.find "extract_no_ext_stdout_nil"
  fun op extract_no_ext_stdout_cons _ = ()
  val op extract_no_ext_stdout_cons = TDB.find "extract_no_ext_stdout_cons"
  fun op extract_no_ext_stdout _ = ()
  val op extract_no_ext_stdout = TDB.find "extract_no_ext_stdout"
  fun op extract_no_ext_ExtCall _ = ()
  val op extract_no_ext_ExtCall = TDB.find "extract_no_ext_ExtCall"
  fun op extract_fs_inode_tbl _ = ()
  val op extract_fs_inode_tbl = TDB.find "extract_fs_inode_tbl"
  fun op ext_bad_def _ = () val op ext_bad_def = TDB.find "ext_bad_def"
  fun op closeFD_stdout _ = ()
  val op closeFD_stdout = TDB.find "closeFD_stdout"
  fun op STD_streams_fs0 _ = ()
  val op STD_streams_fs0 = TDB.find "STD_streams_fs0"
  fun op STD_streams_facts _ = ()
  val op STD_streams_facts = TDB.find "STD_streams_facts"
  fun op STD_streams_File_fd _ = ()
  val op STD_streams_File_fd = TDB.find "STD_streams_File_fd"
  fun op STD_streams_ADELKEY_File _ = ()
  val op STD_streams_ADELKEY_File = TDB.find "STD_streams_ADELKEY_File"
  fun op P_O4_partial_write_counts_nw _ = ()
  val op P_O4_partial_write_counts_nw = TDB.find
    "P_O4_partial_write_counts_nw"
  fun op N_O3_fd2_write_counted_without_fd_test _ = ()
  val op N_O3_fd2_write_counted_without_fd_test = TDB.find
    "N_O3_fd2_write_counted_without_fd_test"
  fun op N_O2_failed_write_counted_without_success_test _ = ()
  val op N_O2_failed_write_counted_without_success_test = TDB.find
    "N_O2_failed_write_counted_without_success_test"
  fun op N_O1_free_ext_breaks _ = ()
  val op N_O1_free_ext_breaks = TDB.find "N_O1_free_ext_breaks"
  fun op ALOOKUP_fs_ffi_part _ = ()
  val op ALOOKUP_fs_ffi_part = TDB.find "ALOOKUP_fs_ffi_part"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundLOut"

end

signature forge_refundR6ReadTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val INSTREAM_BUFFERED_FD_V_def : thm
    val INSTREAM_STRP_V_def : thm
    val INSTREAM_STR_V_def : thm
    val read_event_ok_def : thm
  
  (*  Theorems  *)
    val INSTREAM_BUFFERED_FD_V_IMP : thm
    val INSTREAM_STRP_V_F_F : thm
    val INSTREAM_STR_V_IMP : thm
    val STD_streams_fd0 : thm
    val read_event_ok_read_into : thm
    val read_event_ok_refund : thm
    val read_into_spec_R : thm
    val refillBuffer_with_read_spec_STR_V : thm
    val refillBuffer_with_read_spec_V : thm
end

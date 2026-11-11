signature forge_refundReadEventGapTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val basis_read_ignores_ext : thm
    val basis_stdin_read_total : thm
    val stdin_error_complete_trace_rejected : thm
    val stdin_error_event_rejected : thm
end

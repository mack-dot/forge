signature forge_refundStdinDomainTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val stdin_ffi_read_status_zero : thm
    val stdin_ffi_read_total : thm
    val stdin_read_inputs : thm
    val wf_read_inputs : thm
end

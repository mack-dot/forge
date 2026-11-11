signature forge_refundReadBoundaryTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val ffi_read_ready : thm
    val ffi_read_ready_status : thm
    val ffi_read_unavailable : thm
    val read_ready : thm
end

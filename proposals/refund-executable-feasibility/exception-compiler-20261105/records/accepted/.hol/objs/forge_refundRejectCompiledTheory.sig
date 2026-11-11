signature forge_refundRejectCompiledTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val exception_event_witness : thm
    val refund_error_compiled_precise : thm
end

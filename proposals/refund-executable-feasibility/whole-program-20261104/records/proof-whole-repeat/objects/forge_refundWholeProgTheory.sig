signature forge_refundWholeProgTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val refund_prog_def : thm
  
  (*  Theorems  *)
    val refund_request_whole_prog_spec : thm
    val refund_semantics : thm
    val refund_whole_prog_spec : thm
end

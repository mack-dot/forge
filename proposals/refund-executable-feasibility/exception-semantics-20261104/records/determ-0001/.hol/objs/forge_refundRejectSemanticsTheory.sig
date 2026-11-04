signature forge_refundRejectSemanticsTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_exception_determ : thm
    val refund_raise_determ : thm
end

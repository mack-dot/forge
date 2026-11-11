signature forge_refundRejectBasisTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_error_basis_semantics : thm
    val refund_sem_satisfies_imp : thm
    val refund_stdio_extract_fs : thm
end

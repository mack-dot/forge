signature forge_refundRejectBasisTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_basis_fs_projection : thm
    val refund_basis_parts_ok : thm
    val refund_error_basis_semantics : thm
    val refund_error_initialized_semantics : thm
    val refund_error_program_identity : thm
    val refund_initial_stdio : thm
    val refund_sem_satisfies_imp : thm
    val refund_split_from_subset : thm
    val refund_stdio_extract_fs : thm
end

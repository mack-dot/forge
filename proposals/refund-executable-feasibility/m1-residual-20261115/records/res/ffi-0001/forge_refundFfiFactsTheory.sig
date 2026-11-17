signature forge_refundFfiFactsTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val refund_prog_cv_def : thm
  
  (*  Theorems  *)
    val ffinames_to_string_list_LENGTH : thm
    val mmio_index_LENGTH_all_ExtCall : thm
    val refund_ffi_names : thm
    val refund_lab_conf2_ffis : thm
    val refund_prog_cv_eq : thm
    val refund_prog_cv_thm : thm
end

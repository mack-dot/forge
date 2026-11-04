signature forge_refundRejectSemanticsTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_error_stdio_semantics : thm
    val refund_evaluate_dec_list_clock_result : thm
    val refund_exception_determ : thm
    val refund_exception_semantics : thm
    val refund_raise_determ : thm
    val refund_semantics_dec_list_all_terminate : thm
    val refund_semantics_dec_list_determ_terminate_unique : thm
end

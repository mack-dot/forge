signature forge_refund_callTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val refund_argument_env_def : thm
    val refund_call_def : thm
    val refund_expected_tuple_def : thm
    val refund_method_cml_def : thm
    val refund_method_def : thm
    val refund_program_def : thm
  
  (*  Theorems  *)
    val concrete_bool_tests : thm
    val refund_caller_returns : thm
    val refund_method_compilation : thm
end

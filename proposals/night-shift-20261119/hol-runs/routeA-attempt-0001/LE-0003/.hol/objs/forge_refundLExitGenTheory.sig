signature forge_refundLExitGenTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val cml_exit_status_def : thm
    val cml_exit_stderr_def : thm
  
  (*  Theorems  *)
    val N_E1_status_collision : thm
    val N_E2_silent_stop : thm
    val N_E3_success_with_zero_register : thm
    val evaluate_Halt_reg : thm
    val machine_sem_of_evaluate_Halt : thm
    val refund_halt_address : thm
end

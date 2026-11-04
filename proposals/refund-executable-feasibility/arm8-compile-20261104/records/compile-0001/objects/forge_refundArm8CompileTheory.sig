signature forge_refundArm8CompileTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val code_def : thm
    val compiled : thm
    val conf_def : thm
    val data_def : thm
    val ffis_def : thm
    val refund_prog_cv_def : thm
  
  (*  Theorems  *)
    val refund_arm8_compiled : thm
    val refund_prog_cv_eq : thm
    val refund_prog_cv_thm : thm
    val temp_oracle_cv_thm : thm
end

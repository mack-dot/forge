signature forge_refundCmlMainStepTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val arm8_run_def : thm
    val cml_main_post_def : thm
    val cml_main_pre_def : thm
  
  (*  Theorems  *)
    val arm8_run_compute : thm
    val cml_main_run : thm
    val cml_main_startup_conditions : thm
    val cml_main_wrong_target_refuted : thm
end

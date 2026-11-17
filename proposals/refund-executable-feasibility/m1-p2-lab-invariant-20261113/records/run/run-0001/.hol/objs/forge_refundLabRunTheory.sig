signature forge_refundLabRunTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val cv_hyp_walk1_def : thm
    val cv_line_ok1_def : thm
    val cv_walk_check_def : thm
    val line_ok1_def : thm
    val refund_prog_cv_def : thm
    val walk_check_def : thm
  
  (*  Theorems  *)
    val cv_hyp_walk1_thm : thm
    val cv_line_ok1_thm : thm
    val cv_walk_check_thm : thm
    val hyp_walk1_def : thm
    val hyp_walk1_eq : thm
    val hyp_walk1_ind : thm
    val line_ok1_eq : thm
    val refund_lab_region_hyp : thm
    val refund_lab_run_avoids_install : thm
    val refund_lab_walk_not_closed_29 : thm
    val refund_prog_cv_eq : thm
    val refund_prog_cv_thm : thm
end

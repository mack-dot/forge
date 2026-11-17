signature forge_refundExactExclusionTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val refund_lab_inv_def : thm
  
  (*  Theorems  *)
    val refund_filtered_region_hyp : thm
    val refund_filtered_walk_not_closed_29 : thm
    val refund_lab_inv_init : thm
    val refund_lab_no_share_mem : thm
    val refund_lab_sharemem_counts : thm
    val refund_lab_step_closed : thm
    val refund_target_install_exclusion : thm
    val region2_lab_step : thm
    val sharemem_line_detected : thm
    val sm_free_no_share_mem_inst : thm
    val trivial_invariant_not_closed : thm
end

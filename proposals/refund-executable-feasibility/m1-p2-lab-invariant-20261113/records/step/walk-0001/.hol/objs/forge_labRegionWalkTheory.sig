signature forge_labRegionWalkTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val line_ok_def : thm
    val loc_good_def : thm
  
  (*  Theorems  *)
    val hyp_walk_def : thm
    val hyp_walk_fetch : thm
    val hyp_walk_ind : thm
    val hyp_walk_region_hyp : thm
    val line_ok_step_ok : thm
end

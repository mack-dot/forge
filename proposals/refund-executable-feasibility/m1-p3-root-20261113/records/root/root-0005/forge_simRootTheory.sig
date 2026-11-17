signature forge_simRootTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val forge_toy_mc2_def : thm
    val forge_toy_mc_def : thm
  
  (*  Theorems  *)
    val asm_step_IMP_evaluate_step_find_next_prefix : thm
    val asm_step_IMP_evaluate_step_nop_prefix : thm
    val asm_step_IMP_evaluate_step_prefix : thm
    val endpoint_correspondence_insufficient : thm
    val interior_install_example : thm
    val run_head_ordinary : thm
    val run_interior_ordinary : thm
    val segment_compose_no_install_prefix : thm
    val segment_end_no_install_prefix : thm
    val segment_interior_ordinary : thm
    val state_rel_segment_compose : thm
end

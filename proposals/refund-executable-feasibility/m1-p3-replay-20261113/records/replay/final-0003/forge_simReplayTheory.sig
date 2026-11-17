signature forge_simReplayTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val halt_ctx_def : thm
    val lab_step_closed_def : thm
    val lab_step_def : thm
    val nip_ctx_def : thm
  
  (*  Theorems  *)
    val compile_correct_no_install_prefix : thm
    val compile_no_install_prefix : thm
    val final_nip : thm
    val lab_step_evaluate : thm
    val seg_finish : thm
    val state_rel_ctx : thm
    val step_nip : thm
    val target_install_exclusion_conditional : thm
end

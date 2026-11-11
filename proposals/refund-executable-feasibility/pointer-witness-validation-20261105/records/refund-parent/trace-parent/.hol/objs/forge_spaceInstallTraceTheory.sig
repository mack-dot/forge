signature forge_spaceInstallTraceTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val bounded_stack_single_epoch : thm
    val epoch_single : thm
    val safe_run_single_epoch : thm
end

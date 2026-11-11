signature forge_targetInstallBridgeTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val evaluate_install_irrelevant : thm
    val machine_sem_install_irrelevant : thm
end

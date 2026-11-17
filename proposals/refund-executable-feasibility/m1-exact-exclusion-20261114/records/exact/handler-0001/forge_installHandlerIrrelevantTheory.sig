signature forge_installHandlerIrrelevantTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val forge_toy_mc3_def : thm
    val same_but_install_def : thm
  
  (*  Theorems  *)
    val evaluate_same_but_install : thm
    val handler_matters_when_installer_reached : thm
    val no_install_prefix_same_but_install : thm
end

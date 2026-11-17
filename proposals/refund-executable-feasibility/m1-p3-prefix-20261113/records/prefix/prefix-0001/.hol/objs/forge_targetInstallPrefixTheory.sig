signature forge_targetInstallPrefixTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val no_install_prefix_def : thm
  
  (*  Theorems  *)
    val no_install_prefix_all : thm
    val no_install_prefix_halt : thm
    val no_install_prefix_mono : thm
    val no_install_prefix_next : thm
    val no_install_prefix_segment : thm
    val no_install_prefix_zero : thm
end

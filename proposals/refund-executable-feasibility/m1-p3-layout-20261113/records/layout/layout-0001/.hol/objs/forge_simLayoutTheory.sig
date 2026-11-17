signature forge_simLayoutTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val code_layout_ok_def : thm
  
  (*  Theorems  *)
    val installed_bound_code_layout : thm
    val state_rel_no_install_prefix_layout : thm
end

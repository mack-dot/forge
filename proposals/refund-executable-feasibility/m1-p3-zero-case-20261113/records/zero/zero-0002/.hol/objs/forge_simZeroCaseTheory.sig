signature forge_simZeroCaseTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val install_entry_distinct : thm
    val install_entry_wrap_example : thm
    val state_rel_no_install_prefix_zero : thm
end

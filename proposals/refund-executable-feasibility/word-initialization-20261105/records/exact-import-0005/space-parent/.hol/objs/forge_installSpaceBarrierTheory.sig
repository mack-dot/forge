signature forge_installSpaceBarrierTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val install_outcomes : thm
    val install_suffix_unbounded : thm
    val safe_run_excludes_install_suffix : thm
end

signature forge_refundExclusionChainTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val nip_goal_def : thm
  
  (*  Theorems  *)
    val IMP_state_rel_make_init : thm
    val compile_install_exclusion : thm
    val exclusion_mid : thm
    val nip_make_init : thm
    val refund_compile_install_exclusion : thm
end

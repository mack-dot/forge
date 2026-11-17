signature forge_refundExclusionArm8Theory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_install_exclusion_arm8 : thm
    val refund_install_exclusion_installed : thm
    val refund_u298_exclusion_any_handler : thm
end

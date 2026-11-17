signature forge_refundExclusionSourceTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val compile_lab_conf : thm
    val refund_install_exclusion_compiled : thm
    val refund_install_exclusion_source : thm
    val refund_u298_exclusion_source_any_handler : thm
end

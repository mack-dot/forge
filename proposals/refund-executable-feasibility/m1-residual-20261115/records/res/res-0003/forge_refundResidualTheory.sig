signature forge_refundResidualTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val refund_installed_rest2_def : thm
  
  (*  Theorems  *)
    val ffi_entry_stub_in_domain_rejected : thm
    val halt_stub_in_domain_rejected : thm
    val heap_on_halt_stub_rejected : thm
    val refund_behavior_from_entry_reduced : thm
    val refund_installed_from_entry_reduced : thm
    val refund_installed_rest_reduced : thm
    val refund_mc_concrete_fields : thm
    val refund_stub_outside_domain : thm
    val refund_u298_exclusion_from_entry_reduced : thm
    val wrong_base0_rejected : thm
end

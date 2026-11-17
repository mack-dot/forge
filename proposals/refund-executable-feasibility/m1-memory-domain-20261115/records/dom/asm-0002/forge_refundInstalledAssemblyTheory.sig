signature forge_refundInstalledAssemblyTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val refund_installed_rest_def : thm
  
  (*  Theorems  *)
    val code_outside_domain_rejected : thm
    val heap_on_bitmaps_rejected : thm
    val heap_on_code_rejected : thm
    val prog_addresses_mismatch_rejected : thm
    val refund_behavior_from_entry : thm
    val refund_entry_and_heap_premises_satisfiable : thm
    val refund_installed_from_end_state : thm
    val refund_installed_from_entry : thm
    val refund_u298_exclusion_from_entry : thm
    val unaligned_heap_end_not_closed : thm
end

signature forge_refundStartupBridgeTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val refund_mc_def : thm
  
  (*  Theorems  *)
    val refund_mc_behavior_stdin_no_handler : thm
    val refund_mc_fields : thm
    val refund_mc_is_arm8 : thm
    val refund_mc_u298_exclusion_stdin : thm
    val refund_startup_established : thm
    val refund_startup_from_cml_main : thm
    val stdin_absent_characterised : thm
end

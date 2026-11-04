signature forge_refundStdioProgTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val forge_refundStdioProg_env_def : thm
    val refund_main_v_def : thm
  
  (*  Theorems  *)
    val nsLookup_forge_refundStdioProg_env_pfun_eqs : thm
    val refund_main_error : thm
    val refund_main_valid : thm
end

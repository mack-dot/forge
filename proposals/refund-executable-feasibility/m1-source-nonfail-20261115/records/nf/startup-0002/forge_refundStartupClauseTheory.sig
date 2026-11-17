signature forge_refundStartupClauseTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val arm8_fix_def : thm
    val refund_startup_clause_def : thm
  
  (*  Theorems  *)
    val arm8_fix_is_arm8 : thm
    val arm8_startup_fields : thm
    val is_arm8_iff_fix : thm
    val refund_installed_startup : thm
    val refund_startup_clause_arm8 : thm
end

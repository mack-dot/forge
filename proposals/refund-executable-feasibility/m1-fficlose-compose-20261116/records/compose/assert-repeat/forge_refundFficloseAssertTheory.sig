signature forge_refundFficloseAssertTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val fficlose_alen_zero_pre_def : thm
    val fficlose_clen_bad_pre_def : thm
  
  (*  Theorems  *)
    val fficlose_alen_zero_reaches_assert : thm
    val fficlose_clen_bad_reaches_assert : thm
end

signature forge_refundResourceBindingTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val recorded_config : thm
    val recorded_limits : thm
    val recorded_read_limits : thm
end

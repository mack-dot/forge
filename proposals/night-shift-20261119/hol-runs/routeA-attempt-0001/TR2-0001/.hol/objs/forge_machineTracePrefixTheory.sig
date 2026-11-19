signature forge_machineTracePrefixTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val toy_bad_not_followed : thm
    val trace_diverge : thm
    val trace_fail : thm
    val trace_terminate : thm
end

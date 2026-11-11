signature forge_refundPreciseBehaviorTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val empty_resource_prefix_allowed : thm
    val precise_sem_satisfies_IMP_Terminate : thm
    val refund_compiled_precise : thm
end

signature forge_refundInitializerInstalledTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val arm8_machine_model_instance : thm
    val heap_region_extends : thm
    val refund_initialization_installed : thm
end

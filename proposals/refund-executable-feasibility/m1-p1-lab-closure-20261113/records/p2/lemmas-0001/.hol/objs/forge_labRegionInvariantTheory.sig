signature forge_labRegionInvariantTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val region_hyp_def : thm
    val region_inv_def : thm
    val step_ok_def : thm
    val val_inv_def : thm
  
  (*  Theorems  *)
    val asm_inst_val_inv : thm
    val write_bytearray_val_inv : thm
end

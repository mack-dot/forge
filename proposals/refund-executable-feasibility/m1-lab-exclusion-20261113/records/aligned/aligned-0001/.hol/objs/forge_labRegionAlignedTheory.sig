signature forge_labRegionAlignedTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val load_covered_def : thm
    val mval_inv_def : thm
    val region_inv2_def : thm
  
  (*  Theorems  *)
    val all_address_premise_not_implied : thm
    val asm_inst_mval_inv : thm
    val load_covered_byte_align_64 : thm
    val region2_inv_facts : thm
    val region2_inv_next : thm
    val region2_one_step : thm
    val region2_prefix : thm
    val region2_run : thm
    val region2_step_call : thm
    val region2_step_callffi : thm
    val region2_step_halt : thm
    val region2_step_inst : thm
    val region2_step_install : thm
    val region2_step_jump : thm
    val region2_step_jumpcmp : thm
    val region2_step_jumpreg : thm
    val region2_step_label : thm
    val region2_step_locvalue : thm
    val region2_step_sharemem : thm
    val write_bytearray_mval_inv : thm
end

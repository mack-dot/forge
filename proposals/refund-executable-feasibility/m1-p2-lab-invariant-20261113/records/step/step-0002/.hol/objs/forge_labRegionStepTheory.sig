signature forge_labRegionStepTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val region_hyp_witness : thm
    val region_inv_facts : thm
    val region_inv_next : thm
    val region_one_step : thm
    val region_prefix : thm
    val region_run : thm
    val region_step_call : thm
    val region_step_callffi : thm
    val region_step_halt : thm
    val region_step_inst : thm
    val region_step_install : thm
    val region_step_jump : thm
    val region_step_jumpcmp : thm
    val region_step_jumpreg : thm
    val region_step_label : thm
    val region_step_locvalue : thm
    val region_step_sharemem : thm
end

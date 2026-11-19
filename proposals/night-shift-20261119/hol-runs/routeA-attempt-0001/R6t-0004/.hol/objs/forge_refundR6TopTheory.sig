signature forge_refundR6TopTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val FFI_part_IN_st2heap_FILTER : thm
    val IOFS_V_init : thm
    val IOxV_events_IN : thm
    val STDIO_V_FFI_part_hprop : thm
    val STDIO_V_events : thm
    val STDIO_V_of_IOFS_V : thm
    val basis_proj2_names : thm
    val every_basis_events : thm
    val final_heap_events : thm
    val init_cl_part_IN : thm
    val init_fs_part_IN : thm
    val init_heap_V : thm
    val init_iobuff_IN : thm
    val init_rt_part_IN : thm
    val parts_ok_basis_ffi : thm
    val sem_satisfies_imp_V : thm
    val whole_prog_spec_V_events : thm
    val whole_prog_spec_V_init : thm
end

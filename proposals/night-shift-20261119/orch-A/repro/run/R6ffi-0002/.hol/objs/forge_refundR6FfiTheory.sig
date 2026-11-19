signature forge_refundR6FfiTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val IOFS_V_def : thm
    val IOxV_def : thm
    val STDIO_V_def : thm
  
  (*  Theorems  *)
    val IOFS_V_FFI_part_hprop : thm
    val IOxV_IMP_IOx : thm
    val read_into_spec_V : thm
    val writei_spec_V : thm
end

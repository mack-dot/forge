signature forge_refundR6WriteTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val write_event_ok_def : thm
  
  (*  Theorems  *)
    val IOFS_V_HPROP_INJ : thm
    val IOxV_FFI_part_IN : thm
    val SEG_APPEND3_W : thm
    val STDIO_V_HPROP_INJ : thm
    val STDIO_V_numchars : thm
    val UNIQUE_IOFS_V : thm
    val UNIQUE_STDIO_V : thm
    val output_STDIO_spec_V : thm
    val output_aux_spec_V : thm
    val output_spec_V : thm
    val print_spec_V : thm
    val print_spec_refund : thm
    val write_event_ok_refund : thm
    val write_event_ok_writei : thm
    val write_spec_V : thm
    val writei_spec_W : thm
end

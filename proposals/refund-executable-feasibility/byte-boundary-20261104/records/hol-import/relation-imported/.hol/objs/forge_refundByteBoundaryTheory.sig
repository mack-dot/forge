signature forge_refundByteBoundaryTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val byte_codes_def : thm
    val byte_string_def : thm
  
  (*  Theorems  *)
    val byte_codes_empty : thm
    val byte_fields_result : thm
    val byte_roundtrip : thm
    val byte_string_codes : thm
    val byte_string_eq : thm
    val byte_wire_inputs : thm
    val byte_wire_outputs : thm
end

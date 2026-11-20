signature forge_refundFlatContractTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val codes_def : thm
    val flat_plain_def : thm
  
  (*  Theorems  *)
    val code_map_11 : thm
    val codes_11 : thm
    val codes_bytes : thm
    val codes_literals : thm
    val codes_onto : thm
    val eligible_flat_plain : thm
    val flat_plain_fallback : thm
    val flat_plain_functional : thm
    val flat_plain_total : thm
    val flat_plain_witnesses : thm
    val refund_fields_flat_plain : thm
end

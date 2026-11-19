signature forge_refundExportedContractTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val exported_contract_program_def : thm
    val exported_contract_state_def : thm
    val exported_contract_text_def : thm
    val exported_ens1_def : thm
    val exported_ens2_def : thm
    val exported_ens3_def : thm
    val exported_ensures_def : thm
  
  (*  Theorems  *)
    val exported_contract_decode : thm
    val exported_contract_exact : thm
    val exported_contract_on_refund_fields : thm
    val exported_contract_shape : thm
    val exported_contract_value : thm
    val exported_contract_witnesses : thm
    val exported_ens1_value : thm
    val exported_ens2_value : thm
    val exported_ens3_value : thm
end

signature forge_refundCertifiedProgTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val eligible_v_def : thm
    val forge_refundCertifiedProg_env_0_def : thm
    val forge_refundCertifiedProg_env_1_def : thm
    val forge_refundCertifiedProg_env_def : thm
    val refund_fields_def : thm
    val refund_fields_v_def : thm
    val refund_verified_v_def : thm
  
  (*  Theorems  *)
    val eligible_v_thm : thm
    val nsLookup_forge_refundCertifiedProg_env_0_pfun_eqs : thm
    val nsLookup_forge_refundCertifiedProg_env_1_pfun_eqs : thm
    val nsLookup_forge_refundCertifiedProg_env_pfun_eqs : thm
    val refund_fields_original_method : thm
    val refund_fields_v_thm : thm
    val refund_verified_spec : thm
end

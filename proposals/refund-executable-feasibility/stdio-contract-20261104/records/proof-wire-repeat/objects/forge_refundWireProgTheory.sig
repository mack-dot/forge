signature forge_refundWireProgTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val bind_v_def : thm
    val dest9_v_def : thm
    val dest_expr_v_def : thm
    val dest_fail_v_def : thm
    val eligible_v_def : thm
    val forge_refundWireProg_env_0_def : thm
    val forge_refundWireProg_env_10_def : thm
    val forge_refundWireProg_env_11_def : thm
    val forge_refundWireProg_env_12_def : thm
    val forge_refundWireProg_env_13_def : thm
    val forge_refundWireProg_env_1_def : thm
    val forge_refundWireProg_env_2_def : thm
    val forge_refundWireProg_env_3_def : thm
    val forge_refundWireProg_env_4_def : thm
    val forge_refundWireProg_env_5_def : thm
    val forge_refundWireProg_env_6_def : thm
    val forge_refundWireProg_env_7_def : thm
    val forge_refundWireProg_env_8_def : thm
    val forge_refundWireProg_env_9_def : thm
    val forge_refundWireProg_env_def : thm
    val refund_decode_v_def : thm
    val refund_decode_wire_v_def : thm
    val refund_dispatch_v_def : thm
    val refund_fields_v_def : thm
    val refund_render_fields_def : thm
    val refund_render_fields_v_def : thm
    val refund_response_v_def : thm
    val refund_run_wire_def : thm
    val refund_run_wire_v_def : thm
    val to_bool_v_def : thm
    val to_int_v_def : thm
    val to_mlstring_v_def : thm
  
  (*  Theorems  *)
    val bind_v_thm : thm
    val dest9_v_thm : thm
    val dest_expr_v_thm : thm
    val dest_fail_v_thm : thm
    val eligible_v_thm : thm
    val nsLookup_forge_refundWireProg_env_0_pfun_eqs : thm
    val nsLookup_forge_refundWireProg_env_10_pfun_eqs : thm
    val nsLookup_forge_refundWireProg_env_11_pfun_eqs : thm
    val nsLookup_forge_refundWireProg_env_12_pfun_eqs : thm
    val nsLookup_forge_refundWireProg_env_13_pfun_eqs : thm
    val nsLookup_forge_refundWireProg_env_1_pfun_eqs : thm
    val nsLookup_forge_refundWireProg_env_2_pfun_eqs : thm
    val nsLookup_forge_refundWireProg_env_3_pfun_eqs : thm
    val nsLookup_forge_refundWireProg_env_4_pfun_eqs : thm
    val nsLookup_forge_refundWireProg_env_5_pfun_eqs : thm
    val nsLookup_forge_refundWireProg_env_6_pfun_eqs : thm
    val nsLookup_forge_refundWireProg_env_7_pfun_eqs : thm
    val nsLookup_forge_refundWireProg_env_8_pfun_eqs : thm
    val nsLookup_forge_refundWireProg_env_9_pfun_eqs : thm
    val nsLookup_forge_refundWireProg_env_pfun_eqs : thm
    val refund_decode_v_thm : thm
    val refund_decode_wire_v_thm : thm
    val refund_dispatch_error : thm
    val refund_dispatch_valid : thm
    val refund_fields_v_thm : thm
    val refund_render_fields_roundtrip : thm
    val refund_render_fields_v_thm : thm
    val refund_response_v_thm : thm
    val refund_run_wire_decode_error : thm
    val refund_run_wire_malformed : thm
    val refund_run_wire_trailing : thm
    val refund_run_wire_v_thm : thm
    val refund_run_wire_valid : thm
    val to_bool_v_thm : thm
    val to_int_v_thm : thm
    val to_mlstring_v_thm : thm
end

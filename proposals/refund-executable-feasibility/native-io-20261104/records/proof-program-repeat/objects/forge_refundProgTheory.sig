signature forge_refundProgTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val bind_v_def : thm
    val dest9_v_def : thm
    val dest_expr_v_def : thm
    val dest_fail_v_def : thm
    val forge_refundProg_env_0_def : thm
    val forge_refundProg_env_10_def : thm
    val forge_refundProg_env_11_def : thm
    val forge_refundProg_env_1_def : thm
    val forge_refundProg_env_2_def : thm
    val forge_refundProg_env_3_def : thm
    val forge_refundProg_env_4_def : thm
    val forge_refundProg_env_5_def : thm
    val forge_refundProg_env_6_def : thm
    val forge_refundProg_env_7_def : thm
    val forge_refundProg_env_8_def : thm
    val forge_refundProg_env_9_def : thm
    val forge_refundProg_env_def : thm
    val forge_refundProg_st_def : thm
    val refund_decode_v_def : thm
    val refund_executable_program_def : thm
    val refund_handle_v_def : thm
    val refund_handler_input_pattern_def : thm
    val refund_handler_output_pattern_def : thm
    val refund_library_program_def : thm
    val refund_main_v_def : thm
    val refund_method_native_v_def : thm
    val refund_response_v_def : thm
    val to_bool_v_def : thm
    val to_int_v_def : thm
    val to_mlstring_v_def : thm
  
  (*  Theorems  *)
    val bind_v_thm : thm
    val dest9_v_thm : thm
    val dest_expr_v_thm : thm
    val dest_fail_v_thm : thm
    val nsLookup_forge_refundProg_env_0_pfun_eqs : thm
    val nsLookup_forge_refundProg_env_10_pfun_eqs : thm
    val nsLookup_forge_refundProg_env_11_pfun_eqs : thm
    val nsLookup_forge_refundProg_env_1_pfun_eqs : thm
    val nsLookup_forge_refundProg_env_2_pfun_eqs : thm
    val nsLookup_forge_refundProg_env_3_pfun_eqs : thm
    val nsLookup_forge_refundProg_env_4_pfun_eqs : thm
    val nsLookup_forge_refundProg_env_5_pfun_eqs : thm
    val nsLookup_forge_refundProg_env_6_pfun_eqs : thm
    val nsLookup_forge_refundProg_env_7_pfun_eqs : thm
    val nsLookup_forge_refundProg_env_8_pfun_eqs : thm
    val nsLookup_forge_refundProg_env_9_pfun_eqs : thm
    val nsLookup_forge_refundProg_env_pfun_eqs : thm
    val refund_decode_v_thm : thm
    val refund_decoder_bindings : thm
    val refund_entry_call : thm
    val refund_response_v_thm : thm
    val refund_result_bindings : thm
    val refund_sum_constructors_bound : thm
    val to_bool_v_thm : thm
    val to_int_v_thm : thm
    val to_mlstring_v_thm : thm
end

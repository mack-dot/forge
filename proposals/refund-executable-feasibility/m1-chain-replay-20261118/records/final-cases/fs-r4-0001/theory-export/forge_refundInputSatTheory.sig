signature forge_refundInputSatTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val sat_fs_def : thm
  
  (*  Theorems  *)
    val LFINITE_not_LREPEAT_one : thm
    val LREPEAT_one_unfold : thm
    val always_eventually_LREPEAT_one : thm
    val consumed_stdin_has_no_content : thm
    val finite_numchars_is_not_live : thm
    val live_numchars_LREPEAT_one : thm
    val refund_input_premises_satisfiable : thm
    val refund_profile_a_sl_all_premises_satisfiable_at_0x4000 : thm
    val refund_profile_a_sl_conclusion_holds_for_a_constructed_model_state_at_0x4000 : thm
    val sat_cl_wfcl : thm
    val sat_fs_STD_streams : thm
    val sat_fs_stdin_content : thm
    val sat_fs_wfFS : thm
end

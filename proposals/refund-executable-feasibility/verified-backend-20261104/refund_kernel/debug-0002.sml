val tm = ``assign_values (refund_initial h charge request original remaining enabled opened candidate amount reason) env [VarLhs «v9»] [BoolV F]``;
print (Parse.thm_to_string (EVAL tm) ^ "\n");
print (Parse.thm_to_string (SIMP_CONV (srw_ss()) [refund_initial_def, init_state_def, assign_values_def, assign_value_def, update_local_def, update_local_aux_def] tm) ^ "\n");
OS.Process.exit OS.Process.success;

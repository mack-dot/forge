print (Parse.thm_to_string assign_values_def ^ "\n");
print (Parse.thm_to_string (EVAL ``assign_values (init_state 0) env [VarLhs «v9»] [BoolV F]``) ^ "\n");
print (Parse.thm_to_string (SIMP_CONV (srw_ss()) [assign_values_def, assign_value_def, update_local_def, update_local_aux_def, init_state_def] ``assign_values (init_state 0) env [VarLhs «v9»] [BoolV F]``) ^ "\n");
OS.Process.exit OS.Process.success;

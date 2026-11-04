e (strip_tac >> mp_tac refund_full_result >> simp [] >> rpt strip_tac >> mp_tac refund_output_names_fresh >> rpt strip_tac >> imp_res_tac related_local >> fs [val_rel_simp, refund_cml_outputs_def]);
val (asl,g) = top_goal();
val _ = List.app (fn t => print (Parse.term_to_string t ^ "\n---\n")) asl;
OS.Process.exit OS.Process.success;

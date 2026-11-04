load "forge_refundProgTheory";
open forge_refundProgTheory;
val _ = Globals.max_print_depth := 50;
val _ = print (Parse.thm_to_string refund_handle_v_def ^ "\n");
val _ = print (Parse.thm_to_string refund_decode_v_thm ^ "\n");
val _ = print (Parse.thm_to_string std_preludeTheory.SUM_TYPE_def ^ "\n");
OS.Process.exit OS.Process.success;

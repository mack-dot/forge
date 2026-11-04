load "forge_refundProgTheory";
open HolKernel Parse boolLib bossLib forge_refundProgTheory;
val _ = Globals.max_print_depth := 80;
val _ = print (Parse.thm_to_string refund_main_v_def ^ "\n");
val _ = print (Parse.thm_to_string cfHeapsBaseTheory.Fail_exn_def ^ "\n");
val _ = print (Parse.thm_to_string semanticsTheory.evaluate_def ^ "\n");
OS.Process.exit OS.Process.success;

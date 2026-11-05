load "forge_refundArm8CompileTheory";
open preamble;
val _ = Globals.max_print_depth := 1000;
val _ = print ("EXACT_FFIS_DEFINITION " ^ Parse.thm_to_string forge_refundArm8CompileTheory.ffis_def ^ "\n");
val _ = print ("EVAL_FFIS " ^ Parse.thm_to_string (EVAL ``forge_refundArm8Compile$ffis``) ^ "\n");
val _ = print "FFIS_DEFINITION_DIAGNOSTIC_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

(* cml_main of the linked refund executable (SHA256 b8ed5ec2...): one L3 ARMv8 step theorem per instruction word. Shapes only. *)
open HolKernel Parse boolLib bossLib arm8Theory arm8_stepTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
val words = ["90000000","91034000","90000141","91000021","f9400021","90000142","91006042","f9000022","90000162","913cc042","f9000422",
             "90000162","913cc042","f9000822","f00000e2","91395042","f9000c22","90000102","91000042","f9001022","90000142","91002042",
             "f9400042","90000143","91004063","f9400063","1400001a"];
val _ = List.app (fn w => let val ths = arm8_stepLib.arm8_step_hex w in
   pr ("WORD " ^ w ^ " THEOREMS " ^ Int.toString (length ths)); List.app (fn th => pr ("STEP " ^ thm_to_string th)) ths end)
   (List.take (words, 5) @ [List.nth (words, 7), List.nth (words, 26)]);
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

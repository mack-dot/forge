(* Exploration: step theorems of the L3 ARMv8 step library for the words of cake_fficlose, fficlose and the close import stub. No theorem is stored. *)
open HolKernel Parse boolLib bossLib arm8Theory arm8_stepTheory wordsTheory wordsLib;
val _ = Globals.max_print_depth := 200;
fun pr s = print (s ^ "\n");
val words = ["14008478","a9be4ff4","a9017bfd","910043fd","f100007f","540001ad","f100203f","54000181","aa0203f3","b9400408","5ac00900","94000199",
             "90000010","f9401210","d61f0200","7100001f","1a9f07e8","39000268","a9417bfd","a8c24ff4","d65f03c0","9400016b","94000160","d503201f"];
val _ = List.app (fn w => let val ths = arm8_stepLib.arm8_step_hex w in
     pr ("WORD " ^ w ^ " THEOREMS " ^ Int.toString (length ths));
     List.app (fn th => pr (thm_to_string th)) ths end
   handle e => pr ("WORD " ^ w ^ " FAILED " ^ General.exnMessage e)) words;
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

(* Exploration: step theorems for the words of ffiwrite that were not used for fficlose. No theorem is stored. *)
open HolKernel Parse boolLib bossLib arm8Theory arm8_stepTheory wordsTheory wordsLib;
val _ = Globals.max_print_depth := 200;
fun pr s = print (s ^ "\n");
val words = ["14008454","f100203f","54000341","79400048","5ac00502","79400668","5ac00508","0b080049","11001129","eb03013f","5400024c","b9400409","5ac00920",
             "8b284268","91001101","940001e7","f9405a10","37f800c0","52800008","5ac00809","53107d29","78001269","14000002","52800028","39000268"];
val _ = List.app (fn w => let val ths = arm8_stepLib.arm8_step_hex w in
     pr ("WORD " ^ w ^ " THEOREMS " ^ Int.toString (length ths));
     List.app (fn th => pr (thm_to_string th)) ths end
   handle e => pr ("WORD " ^ w ^ " FAILED " ^ General.exnMessage e)) words;
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

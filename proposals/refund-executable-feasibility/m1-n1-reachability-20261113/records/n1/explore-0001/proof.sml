(* Exploration only: what the compile theory and the ARM8 cv pipeline provide. Stores nothing. *)
load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "word_elimTheory";
open HolKernel Parse boolLib bossLib;
val _ = Globals.max_print_depth := 30;
fun pr s = print (s ^ "\n");
val _ = List.app (fn (n, th) => pr ("COMPILE_THY " ^ n ^ " :: " ^ String.substring (thm_to_string th, 0, Int.min (600, size (thm_to_string th)))))
          (DB.definitions "forge_refundArm8Compile" @ DB.theorems "forge_refundArm8Compile");
val _ = List.app (fn c => pr ("ARM8_CONST " ^ fst (dest_const c) ^ " : " ^ type_to_string (type_of c))) (Theory.constants "backend_arm8");
val _ = List.app (fn (n, _) => pr ("ARM8_CV_THM " ^ n)) (DB.theorems "backend_arm8_cv");
val _ = pr ("FIND_WORD_REF " ^ thm_to_string word_elimTheory.find_word_ref_def);
val _ = pr ("INSTALL_LOCATION " ^ thm_to_string (EVAL ``data_to_word$Install_location``));
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

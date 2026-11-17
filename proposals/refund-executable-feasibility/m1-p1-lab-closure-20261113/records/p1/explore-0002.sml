load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "labPropsTheory"; load "backendProofTheory";
open preamble;
val _ = Globals.max_print_depth := 200;
fun pr s = print (s ^ "\n");
val _ = pr ("ARM8_THEOREMS " ^ String.concatWith " " (map fst (DB.theorems "backend_arm8")));
val _ = pr ("ARM8_DEFINITIONS " ^ String.concatWith " " (map fst (DB.definitions "backend_arm8")));
val _ = List.app (fn (n, th) => if String.isSuffix "_thm" n then pr ("ARM8_LINK " ^ n ^ " :: " ^ String.substring (thm_to_string th, 0, Int.min (300, size (thm_to_string th)))) else ())
          (DB.theorems "backend_arm8");
val _ = List.app (fn (t, n) => pr ("PUBLISHED " ^ t ^ "." ^ n ^ "\n" ^ thm_to_string (DB.fetch t n) ^ "\nEND"))
   [("labProps", "get_code_labels_def"), ("labProps", "sec_get_code_labels_def"), ("labProps", "get_labels_def"),
    ("stack_to_lab", "compile_def"), ("stack_to_lab", "prog_to_section_def"), ("word_to_stack", "compile_def"),
    ("backend", "compile_eq_from_source"), ("labSem", "evaluate_def")] handle ex => pr ("FETCH_FAILED " ^ exn_to_string ex);
val _ = List.app (fn (thy, n, _) => pr ("TO_TARGET_THM " ^ thy ^ "." ^ n)) (map (fn ((thy, n), (th, _, _)) => (thy, n, th)) (DB.find "to_target") handle _ => []);
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

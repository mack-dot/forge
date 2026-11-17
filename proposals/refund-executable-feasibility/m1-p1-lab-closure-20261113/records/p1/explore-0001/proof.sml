(* Exploration only: definitions of the ARM8 in-logic pipeline and of the published lab-level functions. *)
load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "labPropsTheory"; load "backendProofTheory";
open preamble;
val _ = Globals.max_print_depth := 200;
fun pr s = print (s ^ "\n");
val _ = List.app (fn (n, th) => pr ("BACKEND_ARM8 " ^ n ^ "\n" ^ thm_to_string th ^ "\nEND"))
   (List.filter (fn (n, _) => List.exists (fn k => String.isPrefix k n)
        ["from_word_0_arm8", "from_word_arm8", "from_stack_arm8", "from_lab_arm8", "word_to_word_inlogic_arm8", "each_inlogic_arm8",
         "word_alloc_inlogic_arm8", "compile_cake_arm8", "compile_word_to_stack_arm8", "to_lab_all_arm8", "lab_to_target_arm8", "compile_lab_arm8"])
      (DB.definitions "backend_arm8" @ DB.theorems "backend_arm8"));
val _ = List.app (fn n => pr ("BACKEND " ^ n ^ "\n" ^ thm_to_string (DB.fetch "backend" n) ^ "\nEND"))
   ["to_lab_def", "to_stack_def", "to_target_def", "compile_def", "from_lab_def", "from_stack_def", "from_word_def", "attach_bitmaps_def"];
val _ = List.app (fn (t, n) => pr ("PUBLISHED " ^ t ^ "." ^ n ^ "\n" ^ thm_to_string (DB.fetch t n) ^ "\nEND"))
   [("labProps", "get_code_labels_def"), ("labProps", "sec_get_code_labels_def"), ("labProps", "get_labels_def"),
    ("stack_to_lab", "compile_def"), ("stack_to_lab", "prog_to_section_def")];
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

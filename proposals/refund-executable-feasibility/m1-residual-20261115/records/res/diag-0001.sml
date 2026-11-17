(* Diagnostic: form of the stored compile theorem, FFI names and shmem_extra. No theorem is stored. *)
open preamble backendTheory lab_to_targetTheory forge_refundArm8CompileTheory forge_refundLabClosureTheory forge_refundCompileFactsTheory;
fun pr s = print (s ^ "\n");
val _ = Globals.max_print_depth := 40;
val comp = DB.fetch "forge_refundArm8Compile" "refund_arm8_compiled";
val _ = pr ("FREE_VARS " ^ String.concatWith " " (map (fn v => fst (dest_var v) ^ ":" ^ type_to_string (type_of v)) (free_vars (concl comp))));
val cjs = CONJUNCTS comp;
val _ = List.app (fn th => let val s = thm_to_string th in pr ("CONJ " ^ String.substring (s, 0, Int.min (400, size s))) end) (List.filter (fn th => term_size (concl th) < 2000) cjs);
val _ = pr ("CONJ_COUNT " ^ Int.toString (length cjs));
fun show n = let val th = DB.fetch "forge_refundArm8Compile" n val s = thm_to_string th in pr ("DEF " ^ n ^ " " ^ String.substring (s, 0, Int.min (600, size s))) end;
val _ = List.app show ["ffis_def", "compiled"];
val _ = pr ("EVAL_FFIS " ^ thm_to_string (EVAL ``forge_refundArm8Compile$ffis``));
val oc = List.filter (fn c => let val {Name, Thy, ...} = dest_thy_const c in Thy = "forge_refundArm8Compile" end) (Theory.constants "forge_refundArm8Compile");
val _ = pr ("CONSTANTS " ^ String.concatWith " " (map (fn c => fst (dest_const c) ^ ":" ^ type_to_string (type_of c)) oc));
val _ = pr ("ALLOC_COMPILED " ^ thm_to_string (DB.fetch "forge_refundLabClosure" "refund_alloc_compiled"));
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

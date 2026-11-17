(* Fresh import; expected statements are written out. *)
load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "labPropsTheory"; load "wordConvsTheory"; load "labSemTheory";
open preamble cv_transLib backendTheory backend_asmTheory labSemTheory labLangTheory
     forge_refundLabClosureTheory forge_refundLabResolveTheory
     forge_labRegionInvariantTheory forge_labRegionStepTheory forge_labRegionWalkTheory forge_refundLabRunTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val L_tm = ``SND (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))``;
val ls_tm = ``[Install_location; InstallData_location]``;
val run_expected = ``!s k res t.
   s.code = ^L_tm /\ val_inv (loc_good (pc_ok ^ls_tm ^L_tm) ^L_tm) s /\ pc_ok ^ls_tm ^L_tm s.pc /\
   labSem$evaluate (s with clock := k) = (res,t) ==>
   pc_ok ^ls_tm ^L_tm t.pc /\ t.code = ^L_tm /\ val_inv (loc_good (pc_ok ^ls_tm ^L_tm) ^L_tm) t /\
   (!i bs n. labSem$asm_fetch t <> SOME (LabAsm Install i bs n))``;
val expected = [
 ("refund_lab_run_avoids_install", run_expected),
 ("refund_lab_region_hyp", ``region_hyp (loc_good (pc_ok ^ls_tm ^L_tm) ^L_tm) (pc_ok ^ls_tm ^L_tm) ^L_tm /\ pc_ok ^ls_tm ^L_tm 0``),
 ("refund_lab_walk_not_closed_29", ``~(hyp_walk1 [29] ^L_tm 0 ^L_tm /\ pc_ok [29] ^L_tm 0)``),
 ("hyp_walk1_eq", ``!ls whole pc secs. hyp_walk1 ls whole pc secs = hyp_walk (pc_ok ls whole) (\n1 n2. labSem$loc_to_pc n1 n2 whole) pc secs``)];
val _ = List.app (fn (n, tm) =>
  let val th = DB.fetch "forge_refundLabRun" n in
    if aconv tm (concl th) then () else raise Fail ("Exact statement mismatch: " ^ n);
    tags n th; pr ("IMPORTED " ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end) expected;
val _ = List.app (fn n => pr ("DEFINITION " ^ n ^ "\n" ^ thm_to_string (DB.fetch "forge_refundLabRun" n))) ["line_ok1_def", "hyp_walk1_def", "walk_check_def"];
val _ = pr ("ORACLE_CONSTANTS " ^ String.concatWith "," (map (fn c => #Thy (dest_thy_const c) ^ "$" ^ #Name (dest_thy_const c))
    (find_terms (fn t => is_const t andalso String.isSubstring "oracle" (fst (dest_const t))) (concl (DB.fetch "forge_refundLabRun" "refund_lab_run_avoids_install")))));
val closure = "forge_refundLabRun" :: Theory.ancestry "forge_refundLabRun";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "RUN_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

(* Fresh import of the resolution theory. *)
load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "labPropsTheory"; load "wordConvsTheory"; load "labSemTheory";
open preamble cv_transLib backendTheory backend_asmTheory labSemTheory forge_refundLabClosureTheory forge_refundLabResolveTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val L_tm = ``SND (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))``;
val expected = [
 ("loc_pc_thm", ``!n1 n2 secs. loc_pc n1 n2 secs = labSem$loc_to_pc n1 n2 secs``),
 ("refund_lab_resolve_closed", ``refs_ok [29;31] ^L_tm /\ fall_pairs [29;31] (flat_lines ^L_tm)``),
 ("refund_lab_resolve_not_closed_29", ``~(refs_ok [29] ^L_tm /\ fall_pairs [29] (flat_lines ^L_tm))``),
 ("refund_lab_resolve_stats", ``resolve_stats ^L_tm = (29095,5244,0,SOME 0)``),
 ("refund_lab_refs_resolve_outside", ``!sec a i bs len n1 n2 p. MEM sec ^L_tm /\ Section_num sec <> Install_location /\ Section_num sec <> InstallData_location /\
      MEM (LabAsm a i bs len) (Section_lines sec) /\ (n1,n2) IN labProps$labs_of a /\ labSem$loc_to_pc n1 n2 ^L_tm = SOME p ==>
      pc_ok [Install_location; InstallData_location] ^L_tm p``)];
val _ = List.app (fn (n, tm) =>
  let val th = DB.fetch "forge_refundLabResolve" n in
    if aconv tm (concl th) then () else raise Fail ("Exact statement mismatch: " ^ n);
    tags n th; pr ("IMPORTED " ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end) expected;
val _ = List.app (fn n => pr ("DEFINITION " ^ n ^ "\n" ^ thm_to_string (DB.fetch "forge_refundLabResolve" n)))
   ["sec_at_def", "pc_ok_def", "ref_ok_def", "line_refs_ok_def", "refs_ok_def", "flat_lines_def", "fall_pairs_def", "resolve_stats_def", "loc_pc_def"];
val closure = "forge_refundLabResolve" :: Theory.ancestry "forge_refundLabResolve";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => pr ("CLOSURE_NODE " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n))) closure;
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "P1_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

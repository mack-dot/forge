(* Fresh import. Expected statements are written out here. *)
load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "labPropsTheory"; load "wordConvsTheory";
open preamble cv_transLib backendTheory backend_asmTheory forge_refundLabClosureTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val L_tm = ``SND (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))``;
val p1_expected = ``!sec n1 n2. MEM sec ^L_tm /\ Section_num sec <> Install_location /\ Section_num sec <> InstallData_location /\
   (n1,n2) IN labProps$sec_get_labels sec ==> n1 <> Install_location /\ n1 <> InstallData_location``;
val expected = [
 ("refund_lab_install_closure", p1_expected),
 ("refund_lab_closed", ``lab_closed [29;31] ^L_tm``),
 ("refund_lab_not_closed_29", ``~lab_closed [29] ^L_tm``),
 ("refund_lab_stats", ``lab_stats ^L_tm = (558,[29],553,1206,[29;31])``),
 ("refund_alloc_compiled", ``?c1. backend$compile arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog = SOME (code,data,c1)``),
 ("lab_forge8_to_lab", ``lab_forge8 c p = SOME L ==> SND (SND (to_lab arm8_config c p)) = L``),
 ("lab_closed_labels", ``!ls secs. lab_closed ls secs ==>
   !sec n1 n2. MEM sec secs /\ ~MEM (Section_num sec) ls /\ (n1,n2) IN labProps$sec_get_labels sec ==> ~MEM n1 ls``),
 ("refund_alloc_target", ``?c1. attach_bitmaps (FST (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog)))
     (FST (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))
     (lab_to_target$compile arm8_config
        (FST (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))).lab_conf ^L_tm) = SOME (code,data,c1)``)];
val _ = List.app (fn (n, tm) =>
  let val th = DB.fetch "forge_refundLabClosure" n in
    if aconv tm (concl th) then () else raise Fail ("Exact statement mismatch: " ^ n);
    tags n th; pr ("IMPORTED " ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end) expected;
val links = DB.fetch "forge_refundLabClosure" "forge8_links";
val _ = (tags "forge8_links" links; pr ("LINKS\n" ^ thm_to_string links));
val _ = List.app (fn n => pr ("DEFINITION " ^ n ^ "\n" ^ thm_to_string (DB.fetch "forge_refundLabClosure" n)))
   ["forge8_config_def", "lab_forge8_def", "lab_closed_def", "no_fall_def", "sec_ends_exit_def", "line_is_exit_def", "line_no_label_def", "asm_no_label_def", "lab_stats_def"];
val odef = DB.fetch "forge_refundLabClosure" "refund_alloc_oracle_def";
val _ = pr ("ORACLE_IS_DEFINED " ^ Bool.toString (is_eq (concl odef) andalso is_const (lhs (concl odef))) ^ " entries " ^
            Int.toString (length (fst (listSyntax.dest_list (rhs (concl odef))))));
val closure = "forge_refundLabClosure" :: Theory.ancestry "forge_refundLabClosure";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => pr ("CLOSURE_NODE " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n))) closure;
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "P1_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

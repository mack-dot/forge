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
(* Control: the statement without the InstallData exclusion must not be the stored one. *)
val th = DB.fetch "forge_refundLabClosure" "refund_lab_install_closure";
val _ = if aconv p1_expected (concl th) then () else raise Fail "Harness: original statement does not match";
val _ = pr "AFTER_POSITIVE_AUDIT";
val naive = ``!sec n1 n2. MEM sec ^L_tm /\ Section_num sec <> Install_location /\
   (n1,n2) IN labProps$sec_get_labels sec ==> n1 <> Install_location``;
val _ = if aconv naive (concl th) then pr "UNEXPECTED_CONTROL_ACCEPTANCE"
        else raise Fail "Exact statement mismatch: naive P1 without the InstallData exclusion";
val _ = OS.Process.exit OS.Process.success;

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
(* Control: without the value premise on the start state the statement must not be the stored one. *)
val th = DB.fetch "forge_refundLabRun" "refund_lab_run_avoids_install";
val _ = if aconv run_expected (concl th) then () else raise Fail "Harness: original statement does not match";
val _ = pr "AFTER_POSITIVE_AUDIT";
val weaker = ``!s k res t. s.code = ^L_tm /\ pc_ok ^ls_tm ^L_tm s.pc /\ labSem$evaluate (s with clock := k) = (res,t) ==>
   (!i bs n. labSem$asm_fetch t <> SOME (LabAsm Install i bs n))``;
val _ = if aconv weaker (concl th) then pr "UNEXPECTED_CONTROL_ACCEPTANCE"
        else raise Fail "Exact statement mismatch: missing value premise on the start state";
val _ = OS.Process.exit OS.Process.success;

(* The runtime theorem at the published initial lab state. Only the memory premise remains. *)
load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "labPropsTheory"; load "wordConvsTheory"; load "labSemTheory";
load "lab_to_targetProofTheory";
open preamble backendTheory labSemTheory labLangTheory
     forge_refundLabClosureTheory forge_refundLabResolveTheory
     forge_labRegionInvariantTheory forge_labRegionStepTheory forge_labRegionWalkTheory forge_refundLabRunTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_RUN_OUT"));
val _ = new_theory "forge_refundLabRunInit";
val L_tm = ``SND (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))``;
val ls_tm = ``[Install_location; InstallData_location]``;
val init_tm = ``lab_to_targetProof$make_init mc0 ffi0 t0 m dm0 sdm0 ms0 ^L_tm cmp0 cbpos0 cbspace0 coracle0``;
val goal = ``(!a. loc_good (pc_ok ^ls_tm ^L_tm) ^L_tm (m a)) /\
   labSem$evaluate (^init_tm with clock := k) = (res,s2) ==>
   pc_ok ^ls_tm ^L_tm s2.pc /\ s2.code = ^L_tm /\ (!i bs n. labSem$asm_fetch s2 <> SOME (LabAsm Install i bs n))``;
val hyp0 = CONJUNCT2 refund_lab_region_hyp;
val init_thm = store_thm ("refund_lab_init_run_avoids_install", goal,
  strip_tac >> qspecl_then [`^init_tm`, `k`, `res`, `s2`] mp_tac refund_lab_run_avoids_install >>
  impl_tac >- (simp[lab_to_targetProofTheory.make_init_def, val_inv_def, hyp0] >> simp[loc_good_def]) >>
  simp[]);
val _ = (tags "refund_lab_init_run_avoids_install" init_thm; pr ("CHECKED refund_lab_init_run_avoids_install\n" ^ thm_to_string init_thm));
val _ = export_theory ();
val _ = pr "RUN_PROOF_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

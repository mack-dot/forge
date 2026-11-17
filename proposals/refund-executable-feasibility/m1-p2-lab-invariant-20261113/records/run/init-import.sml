(* The runtime theorem at the published initial lab state. Only the memory premise remains. *)
load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "labPropsTheory"; load "wordConvsTheory"; load "labSemTheory";
load "lab_to_targetProofTheory";
open preamble backendTheory labSemTheory labLangTheory
     forge_refundLabClosureTheory forge_refundLabResolveTheory
     forge_labRegionInvariantTheory forge_labRegionStepTheory forge_labRegionWalkTheory forge_refundLabRunTheory forge_refundLabRunInitTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val L_tm = ``SND (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))``;
val ls_tm = ``[Install_location; InstallData_location]``;
val init_tm = ``lab_to_targetProof$make_init mc0 ffi0 t0 m dm0 sdm0 ms0 ^L_tm cmp0 cbpos0 cbspace0 coracle0``;
val goal = ``(!a. loc_good (pc_ok ^ls_tm ^L_tm) ^L_tm (m a)) /\
   labSem$evaluate (^init_tm with clock := k) = (res,s2) ==>
   pc_ok ^ls_tm ^L_tm s2.pc /\ s2.code = ^L_tm /\ (!i bs n. labSem$asm_fetch s2 <> SOME (LabAsm Install i bs n))``;
val th = DB.fetch "forge_refundLabRunInit" "refund_lab_init_run_avoids_install";
val _ = if aconv goal (concl th) then () else raise Fail "Exact statement mismatch: refund_lab_init_run_avoids_install";
val _ = tags "refund_lab_init_run_avoids_install" th;
val _ = pr "IMPORTED refund_lab_init_run_avoids_install EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0";
val _ = if length (DB.theorems "forge_refundLabRunInit") = 1 then () else raise Fail "Unexpected theorem count";
val consts = find_terms (fn t => is_const t andalso String.isSubstring "oracle" (fst (dest_const t))) (concl th);
val _ = pr ("ORACLE_CONSTANTS " ^ String.concatWith "," (Lib.mk_set (map (fn c => #Thy (dest_thy_const c) ^ "$" ^ #Name (dest_thy_const c)) consts)));
val closure = "forge_refundLabRunInit" :: Theory.ancestry "forge_refundLabRunInit";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "RUN_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

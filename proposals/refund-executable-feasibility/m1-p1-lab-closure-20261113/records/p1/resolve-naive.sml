load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "labPropsTheory"; load "wordConvsTheory"; load "labSemTheory";
open preamble cv_transLib backendTheory backend_asmTheory labSemTheory forge_refundLabClosureTheory forge_refundLabResolveTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val L_tm = ``SND (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))``;
(* Control: fresh evaluation; the pair is accepted (harness), section 29 alone must be rejected. *)
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P1_OUT"));
val _ = new_theory "forge_refundLabResolveControl";
val prog_def = DB.fetch "forge_refundWholeProg" "refund_prog_def";
val _ = Feedback.trace ("Theory.allow_rebinds", 1) (cv_trans_deep_embedding EVAL) prog_def;
val conf_tm = rhs (concl (EVAL ``arm8_config$arm8_backend_config``));
val c_oracle_tm = ``set_oracle ^conf_tm refund_alloc_oracle``;
val pair = rhs (concl (cv_eval ``resolve_check [29;31] ^c_oracle_tm refund_prog``));
val _ = if aconv pair T then () else raise Fail "Harness: the pair is not accepted";
val _ = pr "AFTER_POSITIVE_AUDIT";
val single = rhs (concl (cv_eval ``resolve_check [29] ^c_oracle_tm refund_prog``));
val _ = if aconv single T then pr "UNEXPECTED_CONTROL_ACCEPTANCE"
        else raise Fail ("Resolution check rejected for section 29 alone: " ^ term_to_string single);
val _ = OS.Process.exit OS.Process.success;

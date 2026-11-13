load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "wordConvsTheory";
load "wordConvsProofTheory"; load "backendProofTheory";
open preamble cv_transLib backendTheory word_to_wordTheory data_to_wordTheory wordConvsTheory wordConvsProofTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun stamp s = pr ("STAMP " ^ s ^ " " ^ Time.toString (Time.now ()));
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
(* N1 (corrected): in the exact word program, for every allocation oracle, no function
   other than the two installer stubs holds a code label of either stub. *)
open forge_refundInstallReachTheory;
(* Control: recompute the closure check in a fresh session. The pair of stubs is
   closed (harness); the single location Install_location must NOT be closed. *)
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_N1_OUT"));
val _ = new_theory "forge_refundInstallReachControl";
val prog_def = DB.fetch "forge_refundWholeProg" "refund_prog_def";
val _ = Feedback.trace ("Theory.allow_rebinds", 1) (cv_trans_deep_embedding EVAL) prog_def;
val conf_tm = rhs (concl (EVAL ``arm8_config$arm8_backend_config``));
val p0_cv = ``SND (to_word_0_arm8 ^conf_tm refund_prog)``;
val pair = rhs (concl (cv_eval ``labels_closed [29;31] ^p0_cv``));
val _ = if aconv pair T then () else raise Fail "Harness: the stub pair is not closed";
val _ = pr "AFTER_POSITIVE_AUDIT";
val single = rhs (concl (cv_eval ``labels_closed [29] ^p0_cv``));
val _ = if aconv single T then pr "UNEXPECTED_CONTROL_ACCEPTANCE"
        else raise Fail ("Closure rejected for Install_location alone: " ^ term_to_string single);
val _ = OS.Process.exit OS.Process.success;

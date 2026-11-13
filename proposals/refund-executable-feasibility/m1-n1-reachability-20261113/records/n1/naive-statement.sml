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
(* Control: the naive N1 (only Install_location excluded) must not be the stored statement. *)
val th = DB.fetch "forge_refundInstallReach" "install_stubs_unreferenced";
val original = ``!orac n m pp md.
   MEM (n,m,pp,md) (SND (to_word arm8_config (set_oracle arm8_backend_config orac) refund_prog)) /\
   n <> Install_location /\ n <> InstallData_location ==>
   Install_location NOTIN wordConvs$get_code_labels pp /\ InstallData_location NOTIN wordConvs$get_code_labels pp``;
val _ = if aconv original (concl th) then () else raise Fail "Harness: original statement does not match";
val _ = pr "AFTER_POSITIVE_AUDIT";
val naive = ``!orac n m pp md.
   MEM (n,m,pp,md) (SND (to_word arm8_config (set_oracle arm8_backend_config orac) refund_prog)) /\
   n <> Install_location ==> Install_location NOTIN wordConvs$get_code_labels pp``;
val _ = if aconv naive (concl th) then pr "UNEXPECTED_CONTROL_ACCEPTANCE"
        else raise Fail "Exact statement mismatch: naive N1 without the InstallData exclusion";
val _ = OS.Process.exit OS.Process.success;

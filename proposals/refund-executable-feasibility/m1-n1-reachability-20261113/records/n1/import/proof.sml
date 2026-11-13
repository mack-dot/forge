(* Fresh import. Expected statements are written out here; they use published
   constants, except the three checker constants defined by the theory itself. *)
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
val expected = [
 ("install_stubs_unreferenced", ``!orac n m pp md.
   MEM (n,m,pp,md) (SND (to_word arm8_config (set_oracle arm8_backend_config orac) refund_prog)) /\
   n <> Install_location /\ n <> InstallData_location ==>
   Install_location NOTIN wordConvs$get_code_labels pp /\ InstallData_location NOTIN wordConvs$get_code_labels pp``),
 ("word_to_word_labels", ``!wc ac progs. EVERY (\(n,m,pp,md). wordConvs$good_handlers n pp) progs ==>
   !n m2 pp2 md2. MEM (n,m2,pp2,md2) (SND (word_to_word$compile wc ac progs)) ==>
     ?m pp md. MEM (n,m,pp,md) progs /\ wordConvs$get_code_labels pp2 SUBSET n INSERT wordConvs$get_code_labels pp``),
 ("no_label_thm", ``!l p. no_label l p <=> l NOTIN wordConvs$get_code_labels p``),
 ("to_word_0_oracle_independent", ``SND (to_word_0 ac (set_oracle c orac) p) = SND (to_word_0 ac c p)``),
 ("to_word_0_arm8_link", ``to_word_0_arm8 c p = to_word_0 arm8_config c p``),
 ("refund_pre_alloc_count", ``LENGTH (SND (to_word_0 arm8_config arm8_backend_config refund_prog)) = 552``),
 ("refund_pre_alloc_closed", ``labels_closed [29;31] (SND (to_word_0 arm8_config arm8_backend_config refund_prog))``),
 ("refund_pre_alloc_not_closed_29", ``~labels_closed [29] (SND (to_word_0 arm8_config arm8_backend_config refund_prog))``),
 ("refund_install_callers", ``label_callers 29 (SND (to_word_0 arm8_config arm8_backend_config refund_prog)) = [31]``),
 ("refund_install_data_callers", ``label_callers 31 (SND (to_word_0 arm8_config arm8_backend_config refund_prog)) = [31]``)];
val _ = List.app (fn (n, tm) =>
  let val th = DB.fetch "forge_refundInstallReach" n in
    if aconv tm (concl th) then () else raise Fail ("Exact statement mismatch: " ^ n);
    tags n th; pr ("IMPORTED " ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end) expected;
val _ = pr ("THEOREM_COUNT " ^ Int.toString (length (DB.theorems "forge_refundInstallReach")));
val _ = List.app (fn (n, th) => pr ("DEFINITION " ^ n ^ "\n" ^ thm_to_string th)) (DB.definitions "forge_refundInstallReach");
val _ = pr ("LOCATIONS " ^ thm_to_string (EVAL ``(Install_location, InstallData_location)``));
val closure = "forge_refundInstallReach" :: Theory.ancestry "forge_refundInstallReach";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => pr ("CLOSURE_NODE " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n))) closure;
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "N1_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

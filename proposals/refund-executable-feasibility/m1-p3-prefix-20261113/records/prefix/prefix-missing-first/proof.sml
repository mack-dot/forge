load "targetPropsTheory";
open preamble targetSemTheory targetPropsTheory forge_targetInstallPrefixTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val segment_expected = ``(!k. targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate c2 io2 k ms2) /\ c2.install_pc = c.install_pc /\ c2.target = c.target /\
   no_install_prefix c io l ms1 /\ no_install_prefix c2 io2 n ms2 ==> no_install_prefix c io (l + n) ms1``;
(* Control: segment composition without the prefix fact for the first segment must not be the stored statement. *)
val th = DB.fetch "forge_targetInstallPrefix" "no_install_prefix_segment";
val _ = if aconv segment_expected (concl th) then () else raise Fail "Harness: original statement does not match";
val _ = pr "AFTER_POSITIVE_AUDIT";
val weaker = ``(!k. targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate c2 io2 k ms2) /\ c2.install_pc = c.install_pc /\ c2.target = c.target /\
   no_install_prefix c2 io2 n ms2 ==> no_install_prefix c io (l + n) ms1``;
val _ = if aconv weaker (concl th) then pr "UNEXPECTED_CONTROL_ACCEPTANCE"
        else raise Fail "Exact statement mismatch: missing prefix fact for the first segment";
val _ = OS.Process.exit OS.Process.success;

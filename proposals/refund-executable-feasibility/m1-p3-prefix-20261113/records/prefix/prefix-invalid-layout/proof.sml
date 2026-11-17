load "targetPropsTheory";
open preamble targetSemTheory targetPropsTheory forge_targetInstallPrefixTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val segment_expected = ``(!k. targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate c2 io2 k ms2) /\ c2.install_pc = c.install_pc /\ c2.target = c.target /\
   no_install_prefix c io l ms1 /\ no_install_prefix c2 io2 n ms2 ==> no_install_prefix c io (l + n) ms1``;
(* Control by countermodel: with an invalid layout (halt entry equal to the installer entry) the Halt lemma's claim is false. *)
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_targetInstallPrefixControl";
val _ = DB.fetch "forge_targetInstallPrefix" "no_install_prefix_halt";
val _ = pr "AFTER_POSITIVE_AUDIT";
val mc = ``(ARB:(64,num,unit) machine_config) with
    <| prog_addresses := {}; halt_pc := 0w; install_pc := 0w;
       target := (ARB:(64,num,unit) asmProps$target) with get_pc := (\s. 0w) |>``;
val refuted = prove (``(^mc).target.get_pc (0:num) = (^mc).halt_pc /\ (^mc).halt_pc NOTIN (^mc).prog_addresses /\
     ~no_install_prefix ^mc ffi 0 (0:num)``, simp[no_install_prefix_zero]);
val _ = raise Fail ("Halt claim refuted for an invalid layout: " ^ thm_to_string refuted);

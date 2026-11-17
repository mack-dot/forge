load "lab_to_targetProofTheory";
open preamble labSemTheory targetSemTheory targetPropsTheory asmPropsTheory lab_to_targetProofTheory
     forge_targetInstallPrefixTheory forge_simZeroCaseTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory THEORY_NAME;
(* Static layout bound: the encoded program plus the distance to the installer entry does not wrap. *)
val layout_def = Define `code_layout_ok (:'a) code2 <=> LENGTH (prog_to_bytes code2) + 2 * ffi_offset < dimword (:'a)`;
(* Every target state that is state_rel-related to SOME lab state of this code is off the installer entry. *)
val static_goal = ``state_rel (mc_conf,code2,labs,(p:'a word)) s1 t1 ms1 /\ code_layout_ok (:'a) code2 ==>
   no_install_prefix mc_conf ffi 0 (ms1:'state)``;
val static_tac = strip_tac >> match_mp_tac (GEN_ALL state_rel_no_install_prefix_zero) >>
   qexistsl_tac [`t1`,`s1`,`p`,`labs`,`code2`] >> simp[] >>
   `pos_val s1.pc 0 code2 <= LENGTH (prog_to_bytes code2)` by
      (qpat_x_assum `state_rel _ _ _ _` mp_tac >> simp[state_rel_def] >> rpt strip_tac >>
       drule pos_val_bound >> disch_then (qspecl_then [`s1.pc`,`0`] mp_tac) >> simp[]) >>
   fs[layout_def];
(* The bound that the published installed predicate states implies the layout bound. *)
val installed_goal = ``cbspace + LENGTH (prog_to_bytes code2) + ffi_offset * (i + 3) < dimword (:'a) ==> code_layout_ok (:'a) code2``;
val installed_tac = simp[layout_def, lab_to_targetTheory.ffi_offset_def];

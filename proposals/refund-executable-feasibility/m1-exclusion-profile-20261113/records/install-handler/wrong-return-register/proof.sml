(* Control: the harness proves the original; the same tactic must fail for a handler with a wrong return register. *)
open preamble targetSemTheory targetPropsTheory asmPropsTheory arm8_targetTheory arm8_configProofTheory
     forge_targetInstallBridgeTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
(* The ideal handler: return to the link register, write the byte array at the
   destination register, put the destination in the pointer register. *)
val handler = ``\(k:num) (x:word8 list # arm8_state).
   (SND x) with <| PC := (SND x).REG 30w;
                   MEM := asm_write_bytearray ((SND x).REG 2w) (FST x) (SND x).MEM;
                   REG := (0w =+ (SND x).REG 2w) (SND x).REG |>``;
val handler_goal = ``!mc pc cbspace. is_arm8_machine_config mc ==>
   install_interfer_ok pc cbspace (mc with install_interfer := ^handler)``;
(* "installed" with the install_interfer_ok clause removed: unfold the two
   published definitions and replace that one conjunct by T. *)
val mc = mk_var ("mc", type_of (fst (dest_forall handler_goal)));
val mc2 = mk_var ("mc2", type_of mc);
val installed_tm = ``targetSem$installed (bytes:word8 list) cbspace bitmaps data_sp ffi_names (r1,r2) ^mc shmem ms``;
val unfolded = rhs (concl (REWRITE_CONV [installed_def, good_init_state_def] installed_tm));
fun is_install t = is_comb t andalso
  (let val (h, args) = strip_comb t in is_const h andalso fst (dest_const h) = "install_interfer_ok" andalso length args = 3 end);
val dropped = ref 0;
fun drop t = if is_install t then (dropped := !dropped + 1; T)
             else if is_comb t then mk_comb (drop (rator t), drop (rand t))
             else if is_abs t then let val (v, b) = dest_abs t in mk_abs (v, drop b) end
             else t;
val weak = drop unfolded;
val _ = if !dropped = 1 then () else raise Fail "Expected exactly one install_interfer_ok clause";
val _ = if can (find_term is_install) weak then raise Fail "Clause still present" else ();
val mc' = ``^mc with install_interfer := ^handler``;
val weak_goal = ``is_arm8_machine_config mc /\ ^weak ==> ^(subst [mc |-> mc'] installed_tm)``;
val exclusion = ``!j ms' (ffi':'ffi ffi_state).
   targetSem$evaluate ^mc (ffi:'ffi ffi_state) j ms = (targetSem$TimeOut,ms',ffi') ==>
   mc.target.get_pc ms' <> mc.install_pc``;
val final_goal = ``is_arm8_machine_config mc /\ ^weak /\ ^exclusion ==>
   ?^mc2. is_arm8_machine_config ^mc2 /\
         ^(subst [mc |-> mc2] installed_tm) /\
         targetSem$machine_sem ^mc2 (ffi:'ffi ffi_state) ms = targetSem$machine_sem ^mc ffi ms``;
val handler_tac =
  rpt gen_tac >> strip_tac >>
  fs[is_arm8_machine_config_def, install_interfer_ok_def] >> rpt gen_tac >> strip_tac >>
  fs[target_state_rel_def, arm8_target_def, arm8_config_def, arm8_ok_def, read_ffi_bytearray_def] >>
  map_every (fn q => first_assum (qspec_then q mp_tac))
    [`30`,`2`,`0`,`19`,`20`,`21`,`22`,`23`,`24`,`25`,`27`,`28`] >>
  simp[] >> rpt strip_tac >> gvs[combinTheory.APPLY_UPDATE_THM] >>
  metis_tac[miscTheory.mem_eq_imp_asm_write_bytearray_eq];
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_HANDLER_OUT"));
val _ = new_theory "forge_refundInstallHandlerControl";
val original = prove (handler_goal, handler_tac);
val _ = pr "AFTER_POSITIVE_AUDIT";
val wrong = subst [``30w:word5`` |-> ``29w:word5``] handler_goal;
val _ = if aconv wrong handler_goal then raise Fail "Harness: control statement equals the original" else ();
val bad = prove (wrong, handler_tac);
val _ = pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val _ = OS.Process.exit OS.Process.success;

(* Fresh import: rebuild each expected statement from the published
   definitions and compare by aconv; check tags and closure. *)
open preamble targetSemTheory targetPropsTheory asmPropsTheory arm8_targetTheory arm8_configProofTheory
     forge_targetInstallBridgeTheory forge_refundInstallHandlerTheory;
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
val h = mk_var ("h", type_of handler);
val exists_goal = ``!^mc pc cbspace. is_arm8_machine_config ^mc ==>
   ?^h. install_interfer_ok pc cbspace (^mc with install_interfer := ^h)``;
val expected = [("arm8_install_handler_ok", handler_goal), ("arm8_install_handler_exists", exists_goal),
                ("installed_modulo_install_handler", weak_goal), ("install_exclusion_suffices", final_goal)];
val stored = DB.theorems "forge_refundInstallHandler";
val _ = if length stored = 4 then () else raise Fail "Unexpected theorem count";
val _ = List.app (fn (n, tm) =>
  let val th = DB.fetch "forge_refundInstallHandler" n in
    if aconv tm (concl th) then () else raise Fail ("Exact statement mismatch: " ^ n);
    tags n th; pr ("IMPORTED " ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end) expected;
val _ = pr ("FINAL_STATEMENT\n" ^ term_to_string final_goal);
val closure = "forge_refundInstallHandler" :: Theory.ancestry "forge_refundInstallHandler";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => pr ("CLOSURE_NODE " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n))) closure;
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "HANDLER_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

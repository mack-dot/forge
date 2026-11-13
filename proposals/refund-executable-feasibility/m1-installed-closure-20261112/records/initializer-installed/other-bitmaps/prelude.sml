load "forge_refundArm8ProofTheory";
open preamble backendProofTheory arm8_configProofTheory targetPropsTheory targetSemTheory
     stack_to_labProofTheory lab_to_targetProofTheory stack_removeProofTheory labSemTheory
     forge_refundSuccessfulInitializationTheory forge_refundInitializationStaticTheory
     forge_refundInitialStackCodeTheory forge_refundInitializerMachineTheory
     forge_refundInitializerAlignedTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
(* Construction of the statements from the audited two-premise theorem (U354). *)
val base = forge_refundInitializerAlignedTheory.refund_initialization_aligned;
fun var name = hd (List.filter (fn v => fst (dest_var v) = name) (free_vars (concl base)));
val (mc, ms, tar, m, dm, sdm, cbpos, cbspace, data_sp) =
  (var "mc", var "ms", var "tar", var "m", var "dm", var "sdm", var "cbpos", var "cbspace", var "data_sp");
val (ante, conclusion) = dest_imp (concl base);
val (pred_tm, mem_tm) = case strip_conj ante of [a, b] => (a, b) | _ => raise Fail "Base theorem does not have 2 premises";
fun has_const name t = can (find_term (fn c => is_const c andalso fst (dest_const c) = name)) t;
val _ = if has_const "is_arm8_machine_config" pred_tm andalso has_const "memory_assumption" mem_tm then ()
        else raise Fail "Unexpected premises";
val bitmaps_w = el 2 (snd (strip_comb mem_tm));          (* MAP n2w (FST (to_stack ...)) *)
val bitmaps_n = rand bitmaps_w;
val bytes = mk_var ("bytes", ``:word8 list``);
val cbpos_tm = ``(^mc).target.get_pc ^ms + n2w (LENGTH ^bytes)``;
val installed_tm = ``targetSem$installed ^bytes ^cbspace ^bitmaps_n ^data_sp ffi_names
                       (backendProof$heap_regs arm8_backend_config.stack_conf.reg_names) ^mc shmem ^ms``;
val good_tm = ``targetSem$good_init_state ^mc ^ms ^bytes ^cbspace ^tar ^m ^dm ^sdm``;
val conclusion2 = subst [cbpos |-> cbpos_tm] conclusion;
val installed_goal = mk_imp (mk_conj (pred_tm, installed_tm),
                             list_mk_exists ([tar, m, dm, sdm], mk_conj (good_tm, conclusion2)));
val base_gen = GENL [tar, m, dm, sdm, cbpos] base;
(* Explicit machine-model instance: any machine record with these six fields. *)
val model_tm = ``(^mc) with <| target := arm8_target; len_reg := 1; ptr_reg := 0; len2_reg := 3; ptr2_reg := 2;
                               callee_saved_regs := [19;20;21;22;23;24;25;26;27;28] |>``;
val model_goal = mk_comb (rator pred_tm, model_tm);

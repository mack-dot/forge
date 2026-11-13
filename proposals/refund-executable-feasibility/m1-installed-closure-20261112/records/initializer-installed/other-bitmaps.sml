load "forge_refundArm8ProofTheory";
open preamble backendProofTheory arm8_configProofTheory targetPropsTheory targetSemTheory
     stack_to_labProofTheory lab_to_targetProofTheory stack_removeProofTheory labSemTheory
     forge_refundSuccessfulInitializationTheory forge_refundInitializationStaticTheory
     forge_refundInitialStackCodeTheory forge_refundInitializerMachineTheory
     forge_refundInitializerAlignedTheory
     forge_refundInitializerInstalledTheory;
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
val th = forge_refundInitializerInstalledTheory.refund_initialization_installed;
val lem = forge_refundInitializerInstalledTheory.heap_region_extends;
val model = forge_refundInitializerInstalledTheory.arm8_machine_model_instance;
val expected_lemma = ``
  good_dimindex (:'a) /\
  byte_aligned (a:'a word) /\ byte_aligned b /\ a <=+ b /\
  DISJOINT {w | a <=+ w /\ w <+ b} bitmaps_dm /\
  p (fun2set (m, byte_aligned INTER bitmaps_dm)) ==>
  (p * word_list_exists a (w2n (-1w * a + b) DIV w2n (bytes_in_word:'a word)))
    (fun2set (m, ({w | a <=+ w /\ w <+ b} UNION bitmaps_dm) INTER byte_aligned))``;
val _ = if aconv installed_goal (concl th) then () else raise Fail "Exact statement mismatch: refund_initialization_installed";
val _ = if aconv expected_lemma (concl lem) then () else raise Fail "Exact statement mismatch: heap_region_extends";
val _ = if aconv model_goal (concl model) then () else raise Fail "Exact statement mismatch: arm8_machine_model_instance";
val (th_ante, th_concl) = dest_imp (concl th);
val th_conds = strip_conj th_ante;
val _ = if length th_conds = 2 andalso has_const "is_arm8_machine_config" (hd th_conds)
           andalso has_const "installed" (el 2 th_conds) andalso not (has_const "memory_assumption" th_ante)
        then () else raise Fail "Premises are not the predicate and installed";
val (witnesses, body) = strip_exists th_concl;
val _ = if length witnesses = 4 andalso has_const "good_init_state" (hd (strip_conj body))
           andalso aconv (list_mk_conj (tl (strip_conj body))) conclusion2
        then () else raise Fail "Conclusion is not the instantiated base conclusion";
val _ = List.app (fn (n, t) => tags n t) [("refund_initialization_installed", th), ("heap_region_extends", lem),
                                          ("arm8_machine_model_instance", model)];
val _ = if length (DB.theorems "forge_refundInitializerInstalled") = 3 then () else raise Fail "Unexpected theorem count";
val _ = pr "IMPORTED_THEOREM refund_initialization_installed";
val _ = List.app (fn c => pr ("KEPT_PREMISE " ^
  String.substring (term_to_string c, 0, Int.min (160, size (term_to_string c))))) th_conds;
val closure = Lib.mk_set ("forge_refundInitializerInstalled" :: Theory.ancestry "forge_refundInitializerInstalled");
val _ = List.app (fn n => pr ("CLOSURE_NODE " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n))) closure;
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "AFTER_POSITIVE_AUDIT";
(* Altered claim: the installed premise names an empty bitmap list instead of the exact program bitmaps. *)
val altered = mk_imp (mk_conj (pred_tm, subst [bitmaps_n |-> ``[]:num list``] installed_tm), snd (dest_imp installed_goal));
val _ = if aconv altered installed_goal then raise Fail "Control statement equals the original" else ();
val _ = if aconv altered (concl th) then () else raise Fail "Exact statement mismatch: installed state for other bitmaps";
val _ = pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val _ = OS.Process.exit OS.Process.success;

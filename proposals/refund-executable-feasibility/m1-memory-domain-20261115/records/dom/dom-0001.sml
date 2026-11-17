(* U390: explicit asm state and memory domains for the end state of the 27 cml_main steps, at slide 0.
   Domain clauses of the installed-state predicate; target_state_rel and target_configured; conditional assembly of
   refund_installed_no_handler with the unproved clauses as one explicit residual premise.
   The heap/image non-overlap is an explicit premise (refund_heap_clear). Nothing here models a loader or a slide. *)
open preamble backendTheory targetSemTheory targetPropsTheory asmPropsTheory asmSemTheory arm8_targetTheory alignmentTheory arm8_stepTheory
     set_sepTheory miscTheory backendProofTheory arm8_configProofTheory forge_refundArm8CompileTheory forge_refundExclusionRealTheory
     forge_refundStartupClauseTheory forge_refundCmlMainStepTheory forge_refundCmlMainFrameTheory forge_refundStartupBridgeTheory
     forge_loaderMemLemmasTheory forge_refundImageTheory forge_refundLoaderMemoryTheory forge_refundEntrySatTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (300, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundInstalledDomains";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
fun has_const nm tm = can (find_term (fn x => is_const x andalso fst (dest_const x) = nm)) tm;
val code_tm = ``forge_refundArm8Compile$code``; val data_tm = ``forge_refundArm8Compile$data``;
val comp = DB.fetch "forge_refundArm8Compile" "refund_arm8_compiled";
fun len_of c = valOf (List.find (fn th => is_eq (concl th) andalso aconv (lhs (concl th)) ``LENGTH ^c``) (CONJUNCTS comp));
val len_code = len_of code_tm; val len_data = len_of data_tm;
val img_code = DB.fetch "forge_refundImage" "refund_image_code";
val dm_def = DB.fetch "forge_refundLoaderMemory" "refund_bitmaps_dm_def";
val dm_closed = DB.fetch "forge_refundLoaderMemory" "refund_bitmaps_dm_closed";
val bm_clause = BETA_RULE (DB.fetch "forge_refundLoaderMemory" "refund_image_bitmap_clause");
val cl = DB.fetch "forge_refundLoaderMemory" "code_loaded_from_memory";
val entry_def = DB.fetch "forge_refundLoaderMemory" "refund_entry_pre_def";
val main389 = DB.fetch "forge_refundLoaderMemory" "refund_loader_startup";
val runf = DB.fetch "forge_refundCmlMainFrame" "cml_main_run_frame";
val entry_pre = DB.fetch "forge_refundLoaderMemory" "refund_entry_pre_IMP_cml_main_pre";
val ba64 = prove (``byte_aligned (a:word64) <=> aligned 3 a``, simp [byte_aligned_def] >> EVAL_TAC);
val biw = prove (``bytes_in_word = 8w:word64``, EVAL_TAC);
(* ---- 1. Domains, premise, asm state. ---- *)
val code_dm_def = new_definition ("refund_code_dm_def", ``refund_code_dm = {a:word64 | 0x1000040D0w <=+ a /\ a <+ 0x100024000w}``);
val mem_dm_def = new_definition ("refund_mem_dm_def",
  ``refund_mem_dm (h:word64) (e:word64) = refund_code_dm UNION {w | h <=+ w /\ w <+ e} UNION refund_bitmaps_dm``);
val clear_def = new_definition ("refund_heap_clear_def",
  ``refund_heap_clear (h:word64) (e:word64) <=> !a. h <=+ a /\ a <+ e ==> ~(0x100000000w <=+ a /\ a <+ 0x100030F30w)``);
val t_def = new_definition ("refund_t_def", ``refund_t (ms:arm8_state) =
   <| regs := (\i. ms.REG (n2w i)); fp_regs := (\i. 0w); mem := ms.MEM; mem_domain := refund_mem_dm (ms.REG 1w) (ms.REG 3w);
      pc := ms.PC; lr := 30; align := 2; be := F; failed := F |> : 64 asm_state``);
val end_def = new_definition ("refund_end_state_def", ``refund_end_state (ms:arm8_state) <=>
   ms.PSTATE.EL = 0w /\ ~ms.SCTLR_EL1.E0E /\ ~ms.SCTLR_EL1.SA0 /\ ~ms.TCR_EL1.TBI1 /\ ~ms.TCR_EL1.TBI0 /\ ms.exception = NoException /\
   ms.PC = 0x1000040D0w /\ aligned 3 (ms.REG 1w) /\ aligned 3 (ms.REG 3w) /\ ms.REG 1w <=+ ms.REG 3w /\ 8192w <=+ ms.REG 3w - ms.REG 1w /\
   refund_heap_clear (ms.REG 1w) (ms.REG 3w) /\ refund_image_mem 0w ms.MEM /\
   mem_dword ms.MEM (ms.REG 1w) = 0x10002C018w /\ mem_dword ms.MEM (ms.REG 1w + 8w) = 0x100030F30w /\
   mem_dword ms.MEM (ms.REG 1w + 16w) = 0x100030F30w /\ mem_dword ms.MEM (ms.REG 1w + 24w) = 0x100023E54w /\
   mem_dword ms.MEM (ms.REG 1w + 32w) = 0x100024000w``);
val _ = List.app (fn th => pr ("DEFINITION " ^ thm_to_string th)) [code_dm_def, mem_dm_def, clear_def, t_def, end_def];
(* ---- 2. Clean domain lemmas. ---- *)
val heap = ``{w:word64 | h <=+ w /\ w <+ e}``;
val bnd_bm = prove (``i < 2531 ==> 0x10002C018w <=+ 0x10002C018w + n2w i * 8w:word64 /\ 0x10002C018w + n2w i * 8w <+ 0x100030F30w:word64``,
  strip_tac >> simp [word_mul_n2w, word_add_n2w, word_ls_n2w, word_lo_n2w]);
val al_rng = prove (``!x y:word64. align 3 x = y /\ 0x10002C018w <=+ y /\ y <+ 0x100030F30w ==> 0x10002C018w <=+ x /\ x <+ 0x100030F30w``,
  rewrite_tac [align_bitwise_and] >> blastLib.BBLAST_TAC);
val bal3 = prove (``byte_align (a:word64) = align 3 a``, simp [byte_align_def] >> EVAL_TAC);
val C1 = thm "refund_bitmaps_dm_range" ``!x. x IN refund_bitmaps_dm ==> 0x10002C018w <=+ x /\ x <+ 0x100030F30w``
  (simp_tac std_ss [dm_def, GSPECIFICATION, len_data, bal3] >> gen_tac >> strip_tac >> match_mp_tac al_rng >>
   qexists_tac `0x10002C018w + n2w i * 8w` >> imp_res_tac bnd_bm >> asm_rewrite_tac [] >> show_tac "C1");
val hc = prove (``!a h e:word64. aligned 3 h /\ aligned 3 e /\ h <=+ align 3 a /\ align 3 a <+ e ==> h <=+ a /\ a <+ e``,
  rewrite_tac [align_bitwise_and, aligned_bitwise_and] >> blastLib.BBLAST_TAC);
val C3 = thm "refund_heap_bitmaps_closed"
  ``aligned 3 h /\ aligned 3 e ==> !a. byte_align a IN ^heap UNION refund_bitmaps_dm ==> a IN ^heap UNION refund_bitmaps_dm``
  (strip_tac >> gen_tac >> simp_tac std_ss [IN_UNION, GSPECIFICATION] >> strip_tac
   >- (disj1_tac >> match_mp_tac hc >> fs [bal3] >> show_tac "C3a")
   >- (disj2_tac >> imp_res_tac dm_closed));
val lo1 = prove (``x <+ 0x100030F30w /\ 0x10002C018w <=+ x ==> 0x100000000w <=+ (x:word64)``, blastLib.BBLAST_TAC);
val C4 = thm "refund_heap_bitmaps_disjoint" ``refund_heap_clear h e ==> DISJOINT ^heap refund_bitmaps_dm``
  (rewrite_tac [clear_def] >> strip_tac >> simp_tac std_ss [DISJOINT_DEF, EXTENSION, IN_INTER, NOT_IN_EMPTY, GSPECIFICATION] >>
   gen_tac >> CCONTR_TAC >> full_simp_tac bool_ss [] >> imp_res_tac C1 >> imp_res_tac lo1 >> res_tac >> show_tac "C4");
val bnd_code = prove (``i < 130864 ==> 0x1000040D0w <=+ 0x1000040D0w + n2w i:word64 /\ 0x1000040D0w + n2w i <+ 0x100024000w:word64 /\
                        0x100000000w <=+ 0x1000040D0w + n2w i:word64 /\ 0x1000040D0w + n2w i <+ 0x100030F30w:word64 /\
                        ~(0x10002C018w <=+ 0x1000040D0w + n2w i:word64)``,
  strip_tac >> simp [word_add_n2w, word_ls_n2w, word_lo_n2w]);
val C5 = thm "refund_code_addr_in_dm" ``!i h e. i < 130864 ==> 0x1000040D0w + n2w i IN refund_mem_dm h e``
  (rpt strip_tac >> imp_res_tac bnd_code >> asm_simp_tac std_ss [mem_dm_def, code_dm_def, IN_UNION, GSPECIFICATION]);
val C6 = thm "refund_code_addr_not_excluded"
  ``!i h e. refund_heap_clear h e /\ i < 130864 ==> 0x1000040D0w + n2w i NOTIN ^heap UNION refund_bitmaps_dm``
  (rewrite_tac [clear_def] >> rpt strip_tac >> imp_res_tac bnd_code >> full_simp_tac std_ss [IN_UNION, GSPECIFICATION]
   >- (res_tac >> show_tac "C6a") >- (imp_res_tac C1 >> show_tac "C6b"));
val C7 = thm "refund_code_bytes_in_mem"
  ``!m h e. refund_heap_clear h e /\ refund_image_mem 0w m ==>
      bytes_in_mem 0x1000040D0w ^code_tm m (refund_mem_dm h e) (^heap UNION refund_bitmaps_dm)``
  (rpt strip_tac >> rewrite_tac [bytes_in_mem_iff, len_code] >> conj_tac
   >- (mp_tac (Q.SPECL [`0w`, `m`] img_code) >> asm_rewrite_tac [WORD_ADD_0])
   >- (rpt strip_tac >> `i < 130864` by decide_tac >- (match_mp_tac C5 >> first_assum ACCEPT_TAC) >>
       mp_tac (Q.SPECL [`i`, `h`, `e`] C6) >> asm_rewrite_tac []));
val C8 = thm "refund_code_buffer_in_dm"
  ``!h e. refund_heap_clear h e ==> !n. n < 428 ==> n2w (n + 130436) + 0x1000040D0w IN refund_mem_dm h e /\
                                              n2w (n + 130436) + 0x1000040D0w NOTIN ^heap UNION refund_bitmaps_dm``
  (rpt gen_tac >> strip_tac >> gen_tac >> strip_tac >> `n + 130436 < 130864` by decide_tac >>
   once_rewrite_tac [WORD_ADD_COMM] >> conj_tac >- (match_mp_tac C5 >> first_assum ACCEPT_TAC) >>
   match_mp_tac C6 >> asm_rewrite_tac []);
val C9 = thm "refund_heap_bitmaps_subset" ``!h e. ^heap UNION refund_bitmaps_dm SUBSET refund_mem_dm h e``
  (simp_tac std_ss [mem_dm_def, SUBSET_DEF, IN_UNION] >> metis_tac []);
val sepv = prove (``!v a h e:word64. v <+ 40w /\ h <=+ e /\ 8192w <=+ e - h /\ h + v = a ==> h <=+ a /\ a <+ e``, blastLib.BBLAST_TAC);
val C0 = thm "refund_heap_clear_IMP_header_separation"
  ``refund_heap_clear h e /\ h <=+ e /\ 8192w <=+ e - h ==>
    !i (a:word64). i < 40 /\ 0x100000000w <=+ a /\ a <+ 0x100030F30w ==> h + n2w i <> a``
  (rewrite_tac [clear_def] >> rpt strip_tac >> `n2w i <+ 40w:word64` by simp [word_lo_n2w] >>
   mp_tac (Q.SPECL [`n2w i`, `a`, `h`, `e`] sepv) >> asm_rewrite_tac [] >> strip_tac >> res_tac);
(* ---- 3. The asm state: target_state_rel and target_configured. ---- *)
val arm8_tgt = prove (``is_arm8_machine_config mc0 ==> mc0.target = arm8_target``, simp [is_arm8_machine_config_def]);
val C10 = thm "refund_t_target_state_rel" ``!ms. refund_end_state ms ==> target_state_rel arm8_target (refund_t ms) ms``
  (rw [end_def, target_state_rel_def, arm8_target_def, arm8_config_def, t_def, arm8_ok_def] >> EVAL_TAC >> show_tac "C10");
val C11 = thm "refund_t_target_configured"
  ``!ms mc0. is_arm8_machine_config mc0 /\ mc0.prog_addresses = refund_mem_dm (ms.REG 1w) (ms.REG 3w) ==> target_configured (refund_t ms) mc0``
  (rpt strip_tac >> imp_res_tac arm8_tgt >> asm_simp_tac (srw_ss()) [target_configured_def, t_def, arm8_target_def, arm8_config_def] >> show_tac "C11");
val C12 = thm "refund_code_loaded"
  ``!ms mc0. is_arm8_machine_config mc0 /\ mc0.prog_addresses = refund_mem_dm (ms.REG 1w) (ms.REG 3w) /\ ms.PC = 0x1000040D0w /\
             refund_image_mem 0w ms.MEM ==> code_loaded ^code_tm mc0 ms``
  (rpt strip_tac >> match_mp_tac cl >> asm_rewrite_tac [len_code] >> conj_tac
   >- (mp_tac (Q.SPECL [`0w`, `ms.MEM`] img_code) >> asm_rewrite_tac [WORD_ADD_0])
   >- (rpt strip_tac >> match_mp_tac C5 >> decide_tac));
(* ---- 4. End state from the entry pre-state. ---- *)
val T_end = thm "refund_end_state_established"
  ``refund_entry_pre s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h /\ refund_heap_clear h e ==>
    ?ms. arm8_run 27 s = SOME ms /\ ms.REG 1w = h /\ ms.REG 3w = e /\ refund_end_state ms``
  (strip_tac >> first_assum (assume_tac o MATCH_MP entry_pre) >>
   mp_tac main389 >> impl_tac >- asm_rewrite_tac [] >> disch_then (qx_choose_then `ms` strip_assume_tac) >>
   mp_tac runf >> impl_tac >- first_assum ACCEPT_TAC >> disch_then (qx_choose_then `s1` strip_assume_tac) >>
   `ms = s1` by (qpat_x_assum `arm8_run 27 s = SOME ms` mp_tac >> asm_rewrite_tac [] >> simp_tac (srw_ss()) []) >>
   pop_assum SUBST_ALL_TAC >>
   qpat_x_assum `refund_entry_pre _ _ _ _` (strip_assume_tac o REWRITE_RULE [entry_def]) >>
   qexists_tac `s1` >> asm_rewrite_tac [end_def] >> show_tac "TEND");
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val closure = "forge_refundInstalledDomains" :: Theory.ancestry "forge_refundInstalledDomains";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

(* U407, S3 part 2: memory frame, shifted domains, asm state and end state of the 27 cml_main steps at a free load slide sl.
   Premise everywhere: slide_ok sl (page-aligned, no wrap). The entry pre-state refund_entry_pre_sl stays an explicit premise.
   NOT modelled, NOT proved: the loader, dyld, the C run-time, that any real process has such a state. Slide-0 theorems are unchanged. *)
open preamble backendTheory targetSemTheory targetPropsTheory asmPropsTheory asmSemTheory arm8_targetTheory alignmentTheory arm8_stepTheory
     set_sepTheory miscTheory backendProofTheory arm8_configProofTheory wordsLib blastLib forge_refundArm8CompileTheory
     forge_refundStartupClauseTheory forge_refundCmlMainStepTheory forge_loaderMemLemmasTheory forge_refundImageTheory
     forge_refundLoaderMemoryTheory forge_refundInstalledDomainsTheory forge_refundCmlMainSlideTheory forge_refundSlideEntryTheory
     forge_refundCmlMainFrameSlideTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (300, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1800, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundSlideDomains";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
(* mk_thm is used ONLY to let later lemmas be explored after a failure; the run raises Fail before export if any lemma failed,
   and every stored theorem is tag-checked. *)
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; mk_thm ([], goal));
val code_tm = ``forge_refundArm8Compile$code``; val data_tm = ``forge_refundArm8Compile$data``;
val comp = DB.fetch "forge_refundArm8Compile" "refund_arm8_compiled";
fun len_of c = valOf (List.find (fn th => is_eq (concl th) andalso aconv (lhs (concl th)) ``LENGTH ^c``) (CONJUNCTS comp));
val len_code = len_of code_tm; val len_data = len_of data_tm;
fun img n = DB.fetch "forge_refundImage" n;
val image_def = img "refund_image_mem_def"; val img_code = img "refund_image_code"; val img_bm = img "refund_image_bitmaps";
val len_text = img "refund_file_text_length"; val len_bm = img "refund_file_bitmap_length";
val dm_def = DB.fetch "forge_refundLoaderMemory" "refund_bitmaps_dm_def";
val dm_al = DB.fetch "forge_refundLoaderMemory" "refund_bitmaps_dm_aligned";
val dm_closed = DB.fetch "forge_refundLoaderMemory" "refund_bitmaps_dm_closed";
val cl = DB.fetch "forge_refundLoaderMemory" "code_loaded_from_memory";
fun D n = DB.fetch "forge_refundInstalledDomains" n;
val code_dm_def = D "refund_code_dm_def";
fun SE n = DB.fetch "forge_refundSlideEntry" n;
val [slide_def, entry_sl_def, code_sl_def, bm_sl_def, mem_sl_def, clear_sl_def] = map SE ["slide_ok_def", "refund_entry_pre_sl_def",
     "refund_code_dm_sl_def", "refund_bitmaps_dm_sl_def", "refund_mem_dm_sl_def", "refund_heap_clear_sl_def"];
val [E1, run_eq, D3, D6] = map SE ["refund_entry_pre_sl_IMP_cml_main_pre_sl", "arm8_run_constants_agree", "refund_shifted_domains_disjoint",
     "shifted_heap_clear_keeps_heap_outside_code_and_bitmaps"];
val runf_sl = DB.fetch "forge_refundCmlMainFrameSlide" "cml_main_run_frame_sl";
val sep_sl = el 12 (strip_conj (rhs (snd (strip_forall (concl entry_sl_def)))));
val _ = pr ("SEPARATION_PREMISE " ^ term_to_string sep_sl);
val ba64 = prove (``byte_aligned (a:word64) <=> aligned 3 a``, simp [byte_aligned_def] >> EVAL_TAC);
val bal3 = prove (``byte_align (a:word64) = align 3 a``, simp [byte_align_def] >> EVAL_TAC);
val biw = prove (``bytes_in_word = 8w:word64``, EVAL_TAC);
val heap = ``{w:word64 | h <=+ w /\ w <+ e}``;
(* ---- 1. Facts about a permitted slide. ---- *)
val _ = pr "MARK 1";
val SLA = thm "slide_ok_alignment_facts"
  ``slide_ok sl ==> aligned 3 sl /\ aligned 2 (sl + 0x1000040D0w) /\ (3w && (sl + 0x1000040D0w) = 0w) /\ aligned 3 (sl + 0x10002C018w) /\
                    byte_aligned (sl + 0x10002C018w)``
  (rewrite_tac [slide_def, ba64, aligned_bitwise_and] >> blastLib.BBLAST_TAC);
val SLW = thm "slide_ok_bitmaps_no_wrap" ``slide_ok sl ==> w2n (sl + 0x10002C018w) + 20248 < 18446744073709551616``
  (rewrite_tac [slide_def] >> strip_tac >> Cases_on `sl` >> fs [word_add_n2w, word_ls_n2w] >> show_tac "SLW");
val bas1 = GEN_ALL (prove (``aligned 3 (sl:word64) ==> (aligned 3 (x - sl) <=> aligned 3 x)``,
  rewrite_tac [aligned_bitwise_and] >> blastLib.BBLAST_TAC));
val bas2 = GEN_ALL (prove (``aligned 3 (sl:word64) ==> align 3 (x - sl) = align 3 x - sl``,
  rewrite_tac [aligned_bitwise_and, align_bitwise_and] >> blastLib.BBLAST_TAC));
val BAS = thm "aligned_slide_commutes_with_byte_align"
  ``aligned 3 (sl:word64) ==> (!x. byte_aligned (x - sl) <=> byte_aligned x) /\ (!x. byte_align (x - sl) = byte_align x - sl)``
  (strip_tac >> rewrite_tac [ba64, bal3] >> conj_tac >> gen_tac >> metis_tac [bas1, bas2]);
val wsub = prove (``!sl c v:word64. sl + c + v - sl = c + v``, blastLib.BBLAST_TAC);
val wsub2 = prove (``!sl c v:word64. c + sl + v - sl = c + v``, blastLib.BBLAST_TAC);
val weq = prove (``!x sl v:word64. (x - sl = v) <=> (x = sl + v)``, blastLib.BBLAST_TAC);
val img_code_sl = thm "refund_image_code_sl" ``!sl m. refund_image_mem sl m ==> bytes_in_memory (sl + 0x1000040D0w) ^code_tm m UNIV``
  (rpt strip_tac >> imp_res_tac img_code >> `sl + 0x1000040D0w = 0x1000040D0w + sl` by simp [] >> asm_rewrite_tac []);
(* ---- 2. The memory frame keeps the image. ---- *)
val _ = pr "MARK 2";
val sepA = prove (``^sep_sl ==> !k i. k < 40 /\ i < 163840 ==> 0x100000000w + sl + n2w i <> h + n2w k``,
  rpt strip_tac >> `i < 200496` by decide_tac >> first_x_assum (qspecl_then [`k`, `i`] mp_tac) >> asm_rewrite_tac []);
val wl = prove (``!sl i. 0x100000000w + sl + n2w (i + 180248) = 0x10002C018w + sl + n2w i : word64``, simp [GSYM word_add_n2w]);
val sepB = prove (``^sep_sl ==> !k i. k < 40 /\ i < 20248 ==> 0x10002C018w + sl + n2w i <> h + n2w k``,
  rpt strip_tac >> `i + 180248 < 200496` by decide_tac >> first_x_assum (qspecl_then [`k`, `i + 180248`] mp_tac) >> asm_rewrite_tac [wl]);
val pres_sl = thm "refund_image_preserved_sl"
  ``!m m' h sl. refund_image_mem sl m /\ ^sep_sl /\ (!a. (!i. i < 40 ==> a <> h + n2w i) ==> m' a = m a) ==> refund_image_mem sl m'``
  (rewrite_tac [image_def] >> rpt gen_tac >> strip_tac >> first_assum (assume_tac o MATCH_MP sepA) >> first_assum (assume_tac o MATCH_MP sepB) >>
   conj_tac >> match_mp_tac bytes_in_memory_univ_frame >> qexists_tac `m` >> asm_rewrite_tac [len_text, len_bm] >>
   rpt strip_tac >> first_x_assum match_mp_tac >> metis_tac []);
(* ---- 3. Bitmap domain and bitmap clause at a slide. ---- *)
val _ = pr "MARK 3";
val dm_al_sl = thm "refund_bitmaps_dm_sl_aligned"
  ``slide_ok sl ==> !x. x IN byte_aligned INTER refund_bitmaps_dm_sl sl <=> ?i. i < LENGTH ^data_tm /\ x = sl + 0x10002C018w + n2w i * 8w``
  (strip_tac >> drule SLA >> strip_tac >> drule BAS >> strip_tac >> gen_tac >>
   `!y:word64. y IN byte_aligned <=> byte_aligned y` by simp [IN_DEF] >>
   `x IN byte_aligned INTER refund_bitmaps_dm_sl sl <=> x - sl IN byte_aligned INTER refund_bitmaps_dm` by
      (rewrite_tac [IN_INTER, bm_sl_def] >> CONV_TAC (DEPTH_CONV pred_setLib.SET_SPEC_CONV) >> asm_rewrite_tac [] >> show_tac "DMAL0") >>
   pop_assum (fn th => rewrite_tac [th, dm_al, weq, WORD_ADD_ASSOC]) >> show_tac "DMAL");
val dm_closed_sl = thm "refund_bitmaps_dm_sl_closed"
  ``aligned 3 sl ==> !a. byte_align a IN refund_bitmaps_dm_sl sl ==> a IN refund_bitmaps_dm_sl sl``
  (strip_tac >> drule BAS >> strip_tac >> rewrite_tac [bm_sl_def] >> CONV_TAC (DEPTH_CONV pred_setLib.SET_SPEC_CONV) >> gen_tac >> strip_tac >>
   match_mp_tac dm_closed >> asm_rewrite_tac [] >> show_tac "DMC");
val clause_sl = ``\(sl:word64) (m:word64 -> word8). (word_list (sl + 0x10002C018w) (MAP (Word o n2w) ^data_tm) *
     word_list_exists (sl + 0x10002C018w + bytes_in_word * n2w (LENGTH ^data_tm)) 0)
       (fun2set ((\a. Word (mem_dword m a) : 64 word_loc), byte_aligned INTER refund_bitmaps_dm_sl sl))``;
val bm_clause_sl = thm "refund_image_bitmap_clause_sl" ``!m. slide_ok sl /\ refund_image_mem sl m ==> ^clause_sl sl m``
  (rpt strip_tac >> BETA_TAC >> rewrite_tac [word_list_exists_0, SEP_CLAUSES] >> match_mp_tac word_list_fun2set >>
   rewrite_tac [LENGTH_MAP] >> rpt conj_tac
   >- (rewrite_tac [len_data] >> drule SLW >> simp [])
   >- (drule dm_al_sl >> disch_then (fn th => rewrite_tac [th]))
   >- (BETA_TAC >> rpt strip_tac >> mp_tac (Q.SPECL [`sl`, `m`, `i`] img_bm) >> `i * 8 = 8 * i` by decide_tac >> asm_simp_tac (srw_ss()) [EL_MAP, word_mul_n2w] >> show_tac "BMC"));
(* ---- 4. Domain lemmas at a slide. ---- *)
val _ = pr "MARK 4";
val bnd_code = prove (``i < 130864 ==> 0x1000040D0w <=+ 0x1000040D0w + n2w i:word64 /\ 0x1000040D0w + n2w i <+ 0x100024000w:word64``,
  strip_tac >> simp [word_add_n2w, word_ls_n2w, word_lo_n2w]);
val hc = prove (``!a h e:word64. aligned 3 h /\ aligned 3 e /\ h <=+ align 3 a /\ align 3 a <+ e ==> h <=+ a /\ a <+ e``,
  rewrite_tac [align_bitwise_and, aligned_bitwise_and] >> blastLib.BBLAST_TAC);
val C5c = thm "refund_code_addr_in_code_dm_sl" ``!i. i < 130864 ==> sl + 0x1000040D0w + n2w i IN refund_code_dm_sl sl``
  (rpt strip_tac >> rewrite_tac [code_sl_def] >> CONV_TAC (DEPTH_CONV pred_setLib.SET_SPEC_CONV) >> rewrite_tac [wsub, code_dm_def] >>
   CONV_TAC (DEPTH_CONV pred_setLib.SET_SPEC_CONV) >> imp_res_tac bnd_code >> asm_rewrite_tac []);
val C5 = thm "refund_code_addr_in_dm_sl" ``!i h e. i < 130864 ==> sl + 0x1000040D0w + n2w i IN refund_mem_dm_sl sl h e``
  (rpt strip_tac >> imp_res_tac C5c >> asm_rewrite_tac [mem_sl_def, IN_UNION]);
val D3x = prove (``!x. x IN refund_code_dm_sl sl ==> x NOTIN refund_bitmaps_dm_sl sl``,
  assume_tac D3 >> fs [DISJOINT_DEF, EXTENSION] >> metis_tac []);
val C6 = thm "refund_code_addr_not_excluded_sl"
  ``!i h e. refund_heap_clear_sl sl h e /\ i < 130864 ==> sl + 0x1000040D0w + n2w i NOTIN ^heap UNION refund_bitmaps_dm_sl sl``
  (rpt gen_tac >> strip_tac >> imp_res_tac C5c >> imp_res_tac D3x >> drule D6 >>
   disch_then (qspec_then `sl + 0x1000040D0w + n2w i` mp_tac) >> rewrite_tac [IN_UNION] >>
   CONV_TAC (DEPTH_CONV pred_setLib.SET_SPEC_CONV) >> asm_rewrite_tac [] >> show_tac "C6" >> metis_tac []);
val C7 = thm "refund_code_bytes_in_mem_sl"
  ``!m h e. refund_heap_clear_sl sl h e /\ refund_image_mem sl m ==>
      bytes_in_mem (sl + 0x1000040D0w) ^code_tm m (refund_mem_dm_sl sl h e) (^heap UNION refund_bitmaps_dm_sl sl)``
  (rpt strip_tac >> rewrite_tac [bytes_in_mem_iff, len_code] >> conj_tac
   >- (imp_res_tac img_code_sl)
   >- (rpt strip_tac >> `i < 130864` by decide_tac >- (match_mp_tac C5 >> first_assum ACCEPT_TAC) >>
       mp_tac (Q.SPECL [`i`, `h`, `e`] C6) >> asm_rewrite_tac []));
val C8 = thm "refund_code_buffer_in_dm_sl"
  ``!h e. refund_heap_clear_sl sl h e ==> !n. n < 428 ==> n2w (n + 130436) + (sl + 0x1000040D0w) IN refund_mem_dm_sl sl h e /\
                                              n2w (n + 130436) + (sl + 0x1000040D0w) NOTIN ^heap UNION refund_bitmaps_dm_sl sl``
  (rpt gen_tac >> strip_tac >> gen_tac >> strip_tac >> `n + 130436 < 130864` by decide_tac >>
   `!v:word64. v + (sl + 0x1000040D0w) = sl + 0x1000040D0w + v` by metis_tac [WORD_ADD_COMM] >> pop_assum (fn th => rewrite_tac [th]) >>
   conj_tac >- (match_mp_tac C5 >> first_assum ACCEPT_TAC) >> match_mp_tac C6 >> asm_rewrite_tac []);
val C9 = thm "refund_heap_bitmaps_subset_sl" ``!h e. ^heap UNION refund_bitmaps_dm_sl sl SUBSET refund_mem_dm_sl sl h e``
  (simp_tac std_ss [mem_sl_def, SUBSET_DEF, IN_UNION] >> metis_tac []);
val C3 = thm "refund_heap_bitmaps_closed_sl"
  ``aligned 3 h /\ aligned 3 e /\ aligned 3 sl ==>
    !a. byte_align a IN ^heap UNION refund_bitmaps_dm_sl sl ==> a IN ^heap UNION refund_bitmaps_dm_sl sl``
  (strip_tac >> gen_tac >> simp_tac std_ss [IN_UNION, GSPECIFICATION] >> strip_tac
   >- (disj1_tac >> match_mp_tac hc >> fs [bal3] >> show_tac "C3a")
   >- (disj2_tac >> imp_res_tac dm_closed_sl));
val C4 = thm "refund_heap_bitmaps_disjoint_sl" ``refund_heap_clear_sl sl h e ==> DISJOINT ^heap (refund_bitmaps_dm_sl sl)``
  (strip_tac >> imp_res_tac D6 >> simp_tac std_ss [DISJOINT_DEF, EXTENSION, IN_INTER, NOT_IN_EMPTY, GSPECIFICATION] >> metis_tac []);
val b0 = prove (``j < 200496 ==> 0x100000000w <=+ 0x100000000w + n2w j:word64 /\ 0x100000000w + n2w j <+ 0x100030F30w:word64``,
  strip_tac >> simp [word_add_n2w, word_ls_n2w, word_lo_n2w]);
val sepv = prove (``!v a h e:word64. v <+ 40w /\ h <=+ e /\ 8192w <=+ e - h /\ h + v = a ==> h <=+ a /\ a <+ e``, blastLib.BBLAST_TAC);
val C0 = thm "refund_heap_clear_sl_IMP_header_separation"
  ``refund_heap_clear_sl sl h e /\ h <=+ e /\ 8192w <=+ e - h ==> ^sep_sl``
  (rewrite_tac [clear_sl_def] >> rpt strip_tac >> `n2w i <+ 40w:word64` by simp [word_lo_n2w] >>
   mp_tac (Q.SPECL [`n2w i`, `0x100000000w + sl + n2w j`, `h`, `e`] sepv) >> asm_rewrite_tac [] >> strip_tac >>
   first_x_assum (qspec_then `0x100000000w + sl + n2w j` mp_tac) >> imp_res_tac b0 >> asm_rewrite_tac [wsub2] >> show_tac "C0");
(* ---- 5. The asm state and the end state at a slide. ---- *)
val _ = pr "MARK 5";
val t_sl_def = new_definition ("refund_t_sl_def", ``refund_t_sl (sl:word64) (ms:arm8_state) =
   <| regs := (\i. ms.REG (n2w i)); fp_regs := (\i. 0w); mem := ms.MEM; mem_domain := refund_mem_dm_sl sl (ms.REG 1w) (ms.REG 3w);
      pc := ms.PC; lr := 30; align := 2; be := F; failed := F |> : 64 asm_state``);
val end_sl_def = new_definition ("refund_end_state_sl_def", ``refund_end_state_sl (sl:word64) (ms:arm8_state) <=>
   slide_ok sl /\
   ms.PSTATE.EL = 0w /\ ~ms.SCTLR_EL1.E0E /\ ~ms.SCTLR_EL1.SA0 /\ ~ms.TCR_EL1.TBI1 /\ ~ms.TCR_EL1.TBI0 /\ ms.exception = NoException /\
   ms.PC = sl + 0x1000040D0w /\ aligned 3 (ms.REG 1w) /\ aligned 3 (ms.REG 3w) /\ ms.REG 1w <=+ ms.REG 3w /\ 8192w <=+ ms.REG 3w - ms.REG 1w /\
   refund_heap_clear_sl sl (ms.REG 1w) (ms.REG 3w) /\ refund_image_mem sl ms.MEM /\
   mem_dword ms.MEM (ms.REG 1w) = sl + 0x10002C018w /\ mem_dword ms.MEM (ms.REG 1w + 8w) = sl + 0x100030F30w /\
   mem_dword ms.MEM (ms.REG 1w + 16w) = sl + 0x100030F30w /\ mem_dword ms.MEM (ms.REG 1w + 24w) = sl + 0x100023E54w /\
   mem_dword ms.MEM (ms.REG 1w + 32w) = sl + 0x100024000w``);
val _ = List.app (fn th => pr ("DEFINITION " ^ thm_to_string th)) [t_sl_def, end_sl_def];
val arm8_tgt = prove (``is_arm8_machine_config mc0 ==> mc0.target = arm8_target``, simp [is_arm8_machine_config_def]);
val C10 = thm "refund_t_sl_target_state_rel" ``!ms. refund_end_state_sl sl ms ==> target_state_rel arm8_target (refund_t_sl sl ms) ms``
  (gen_tac >> rewrite_tac [end_sl_def] >> strip_tac >> drule SLA >> strip_tac >>
   asm_simp_tac (srw_ss()) [target_state_rel_def, arm8_target_def, arm8_config_def, t_sl_def, arm8_ok_def] >>
   rpt strip_tac >> TRY (EVAL_TAC >> NO_TAC) >> show_tac "C10");
val C11 = thm "refund_t_sl_target_configured"
  ``!ms mc0. is_arm8_machine_config mc0 /\ mc0.prog_addresses = refund_mem_dm_sl sl (ms.REG 1w) (ms.REG 3w) ==>
             target_configured (refund_t_sl sl ms) mc0``
  (rpt strip_tac >> imp_res_tac arm8_tgt >> asm_simp_tac (srw_ss()) [target_configured_def, t_sl_def, arm8_target_def, arm8_config_def] >> show_tac "C11");
val C12 = thm "refund_code_loaded_sl"
  ``!ms mc0. is_arm8_machine_config mc0 /\ mc0.prog_addresses = refund_mem_dm_sl sl (ms.REG 1w) (ms.REG 3w) /\ ms.PC = sl + 0x1000040D0w /\
             refund_image_mem sl ms.MEM ==> code_loaded ^code_tm mc0 ms``
  (rpt strip_tac >> match_mp_tac cl >> asm_rewrite_tac [len_code] >> conj_tac
   >- (imp_res_tac img_code_sl)
   >- (rpt strip_tac >> match_mp_tac C5 >> decide_tac));
(* ---- 6. End state from the entry pre-state at a slide. ---- *)
val _ = pr "MARK 6";
val T_end = thm "refund_end_state_sl_established"
  ``refund_entry_pre_sl sl s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h /\ refund_heap_clear_sl sl h e ==>
    ?ms. forge_refundCmlMainStep$arm8_run 27 s = SOME ms /\ ms.REG 1w = h /\ ms.REG 3w = e /\ refund_end_state_sl sl ms``
  (strip_tac >> first_assum (assume_tac o MATCH_MP E1) >>
   mp_tac runf_sl >> impl_tac >- first_assum ACCEPT_TAC >> disch_then (qx_choose_then `s1` strip_assume_tac) >>
   qpat_x_assum `refund_entry_pre_sl _ _ _ _ _` (strip_assume_tac o REWRITE_RULE [entry_sl_def]) >>
   `refund_image_mem sl s1.MEM` by (match_mp_tac pres_sl >> qexistsl_tac [`s.MEM`, `h`] >> rpt conj_tac >> first_assum ACCEPT_TAC) >>
   qexists_tac `s1` >> asm_rewrite_tac [end_sl_def, GSYM run_eq] >> show_tac "TEND");
(* ---- 7. Regression to slide 0 and negative controls. ---- *)
val _ = pr "MARK 7";
val t_def = D "refund_t_def"; val end_def = D "refund_end_state_def";
val D4 = SE "shifted_domains_at_slide_zero";
val R1 = thm "slide_zero_asm_state_is_the_old_one" ``refund_t_sl 0w ms = refund_t ms`` (rewrite_tac [t_sl_def, t_def, D4]);
val R2 = thm "slide_zero_end_state_is_the_old_one" ``refund_end_state_sl 0w ms <=> refund_end_state ms``
  (rewrite_tac [end_sl_def, end_def, D4, WORD_ADD_0] >> `slide_ok 0w` by (rewrite_tac [slide_def] >> EVAL_TAC) >> asm_rewrite_tac []);
val K1 = thm "heap_on_relocated_code_rejected"
  ``h <=+ sl + 0x1000040D0w /\ sl + 0x1000040D0w <+ e ==> ~refund_heap_clear_sl sl h e /\
    !m md. ~bytes_in_mem (sl + 0x1000040D0w) ^code_tm m md (^heap UNION refund_bitmaps_dm_sl sl)``
  (strip_tac >> conj_tac
   >- (rewrite_tac [clear_sl_def] >> strip_tac >> first_x_assum (qspec_then `sl + 0x1000040D0w` mp_tac) >> asm_rewrite_tac [WORD_ADD_SUB2] >>
       EVAL_TAC)
   >- (rpt gen_tac >> rewrite_tac [bytes_in_mem_iff, len_code] >> strip_tac >> first_x_assum (qspec_then `0` mp_tac) >>
       asm_simp_tac (srw_ss()) [] >> show_tac "K1"));
val K2 = thm "image_at_another_slide_is_not_preserved_evidence"
  ``slide_ok sl /\ refund_image_mem sl m /\ m (sl + 0x1000040D4w) <> EL 0 ^code_tm ==> ~bytes_in_memory (sl + 0x1000040D4w) ^code_tm m UNIV``
  (rewrite_tac [bytes_in_memory_univ_EL] >> rpt strip_tac >> first_x_assum (qspec_then `0` mp_tac) >> asm_rewrite_tac [len_code, WORD_ADD_0] >> EVAL_TAC);
val K3 = thm "end_state_fixes_one_slide" ``refund_end_state_sl sl ms /\ refund_end_state_sl sl' ms ==> sl = sl'``
  (rewrite_tac [end_sl_def] >> strip_tac >> qpat_x_assum `ms.PC = sl + _` mp_tac >> asm_rewrite_tac [] >> blastLib.BBLAST_TAC);
val K4 = thm "wrong_slide_domain_does_not_hold_the_code"
  ``sl + 0x1000040D0w NOTIN refund_code_dm_sl (sl + 0x24000w) /\ sl + 0x1000040D0w IN refund_code_dm_sl sl``
  (rewrite_tac [code_sl_def, code_dm_def] >> CONV_TAC (DEPTH_CONV pred_setLib.SET_SPEC_CONV) >> blastLib.BBLAST_TAC);
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundSlideDomains" @ DB.definitions "forge_refundSlideDomains");
val _ = if aconv (concl (D "refund_end_state_established"))
     ``refund_entry_pre s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h /\ refund_heap_clear h e ==>
       ?ms. forge_refundCmlMainStep$arm8_run 27 s = SOME ms /\ ms.REG 1w = h /\ ms.REG 3w = e /\ refund_end_state ms``
        then pr "CONTROL_OK the U390 slide-0 end-state theorem is loaded unchanged" else raise Fail "UNEXPECTED_CONTROL_ACCEPTANCE";
val closure = "forge_refundSlideDomains" :: Theory.ancestry "forge_refundSlideDomains";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundSlideDomains")));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = pr ("CLOSURE_HAS_COMPILE_CORRECT_CONTROL " ^ Bool.toString (Lib.mem "forge_compileCorrectControl" closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

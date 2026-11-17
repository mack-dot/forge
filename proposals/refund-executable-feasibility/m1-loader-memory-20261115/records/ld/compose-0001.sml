(* U389: loader-memory clauses of the installed-state predicate for a memory that holds the executable image, composed with the
   27 cml_main steps. Link addresses, slide 0. The loader is NOT modelled: the image predicate is an explicit premise. *)
open preamble backendTheory targetSemTheory targetPropsTheory asmPropsTheory arm8_targetTheory alignmentTheory arm8_stepTheory set_sepTheory
     miscTheory backendProofTheory arm8_configProofTheory forge_refundArm8CompileTheory forge_refundExclusionRealTheory
     forge_refundStartupClauseTheory forge_refundCmlMainStepTheory forge_refundCmlMainFrameTheory forge_refundStartupBridgeTheory
     forge_loaderMemLemmasTheory forge_refundImageTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (400, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundLoaderMemory";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
fun named nm tm = can (find_term (fn x => is_const x andalso fst (dest_const x) = nm)) tm;
val code_tm = ``forge_refundArm8Compile$code``; val data_tm = ``forge_refundArm8Compile$data``;
val comp = DB.fetch "forge_refundArm8Compile" "refund_arm8_compiled";
fun len_of c = valOf (List.find (fn th => is_eq (concl th) andalso aconv (lhs (concl th)) ``LENGTH ^c``) (CONJUNCTS comp));
val len_code = len_of code_tm; val len_data = len_of data_tm;
fun img n = DB.fetch "forge_refundImage" n;
val image_def = img "refund_image_mem_def"; val img_code = img "refund_image_code"; val img_stub = img "refund_image_cml_main";
val img_bm = img "refund_image_bitmaps"; val len_text = img "refund_file_text_length"; val len_bm = img "refund_file_bitmap_length";
val samples = CONJUNCTS (img "refund_code_data_samples");
val el_code = List.take (samples, 2); val el_data = List.drop (samples, 2);
val _ = List.app (fn th => pr ("SAMPLE " ^ thm_to_string th)) samples;
(* ---- 5. Clauses for a memory that holds the image at slide 0. ---- *)
val dm_def = new_definition ("refund_bitmaps_dm_def",
  ``refund_bitmaps_dm = {x:word64 | ?i. i < LENGTH ^data_tm /\ byte_align x = 0x10002C018w + n2w i * 8w}``);
val ba64 = prove (``byte_aligned (a:word64) <=> aligned 3 a``, simp [byte_aligned_def] >> EVAL_TAC);
val dm_al = thm "refund_bitmaps_dm_aligned"
  ``!x. x IN byte_aligned INTER refund_bitmaps_dm <=> ?i. i < LENGTH ^data_tm /\ x = 0x10002C018w + n2w i * 8w``
  (gen_tac >> `x IN byte_aligned <=> byte_aligned x` by simp [IN_DEF] >> asm_simp_tac std_ss [IN_INTER, dm_def, GSPECIFICATION] >>
   eq_tac >> strip_tac
   >- (qexists_tac `i` >> fs [byte_aligned_def, byte_align_def, aligned_def] >> show_tac "DM1" >> metis_tac [])
   >- (`byte_aligned x` by (asm_rewrite_tac [ba64, aligned_bitwise_and] >> qspec_tac (`n2w i:word64`, `v`) >> blastLib.BBLAST_TAC) >>
       asm_rewrite_tac [] >> qexists_tac `i` >> fs [byte_aligned_def, byte_align_def, aligned_def] >> metis_tac []));
val dm_closed = thm "refund_bitmaps_dm_closed" ``!a. byte_align a IN refund_bitmaps_dm ==> a IN refund_bitmaps_dm``
  (simp [dm_def, byte_align_def, align_align] >> show_tac "DMC");
val clause_tm = ``\(m:word64 -> word8). (word_list 0x10002C018w (MAP (Word o n2w) ^data_tm) *
     word_list_exists (0x10002C018w + bytes_in_word * n2w (LENGTH ^data_tm)) 0)
       (fun2set ((\a. Word (mem_dword m a) : 64 word_loc), byte_aligned INTER refund_bitmaps_dm))``;
val bm_clause = thm "refund_image_bitmap_clause" ``!m. refund_image_mem 0w m ==> ^clause_tm m``
  (rpt strip_tac >> BETA_TAC >> simp [word_list_exists_0, SEP_CLAUSES] >> match_mp_tac word_list_fun2set >>
   simp [len_data, dm_al] >> rpt strip_tac >> simp [EL_MAP, len_data] >>
   mp_tac (Q.SPECL [`0w`, `m`, `i`] img_bm) >> simp [len_data, word_mul_n2w] >> show_tac "BMC");
val cl = thm "code_loaded_from_memory"
  ``!bs mc0 (ms:arm8_state). is_arm8_machine_config mc0 /\ bytes_in_memory ms.PC bs ms.MEM UNIV /\
      (!i. i < LENGTH bs ==> ms.PC + n2w i IN mc0.prog_addresses) ==> code_loaded bs mc0 ms``
  (rw [code_loaded_def, is_arm8_machine_config_def] >> simp [arm8_target_def] >> match_mp_tac read_bytearray_from_EL >>
   fs [bytes_in_memory_univ_EL] >> show_tac "CL");
val b1 = prove (``i < 163840 ==> 0x100000000w <=+ 0x100000000w + n2w i:word64 /\ 0x100000000w + n2w i <+ 0x100030F30w:word64``,
  strip_tac >> simp [word_add_n2w, word_ls_n2w, word_lo_n2w]);
val b2 = prove (``i < 20248 ==> 0x100000000w <=+ 0x10002C018w + n2w i:word64 /\ 0x10002C018w + n2w i <+ 0x100030F30w:word64``,
  strip_tac >> simp [word_add_n2w, word_ls_n2w, word_lo_n2w]);
val sep_tm = ``!i (a:word64). i < 40 /\ 0x100000000w <=+ a /\ a <+ 0x100030F30w ==> (h:word64) + n2w i <> a``;
val pres = thm "refund_image_preserved"
  ``!m m' h. refund_image_mem 0w m /\ ^sep_tm /\ (!a. (!i. i < 40 ==> a <> h + n2w i) ==> m' a = m a) ==> refund_image_mem 0w m'``
  (rw [image_def] >> match_mp_tac bytes_in_memory_univ_frame >> qexists_tac `m` >> asm_rewrite_tac [len_text, len_bm] >>
   rpt strip_tac >> first_x_assum match_mp_tac >> rpt strip_tac >> imp_res_tac b1 >> imp_res_tac b2 >> metis_tac []);
(* ---- 6. Entry pre-state and the composition with the 27 steps. ---- *)
val entry_def = new_definition ("refund_entry_pre_def", ``refund_entry_pre (s:arm8_state) (h:word64) (stk:word64) (e:word64) <=>
   ~s.SCTLR_EL1.E0E /\ ~s.SCTLR_EL1.SA0 /\ ~s.TCR_EL1.TBI0 /\ ~s.TCR_EL1.TBI1 /\ s.PSTATE.EL = 0w /\ s.exception = NoException /\
   s.PC = 0x100004000w /\ mem_dword s.MEM 0x10002C000w = h /\ mem_dword s.MEM 0x10002C008w = stk /\ mem_dword s.MEM 0x10002C010w = e /\
   aligned 3 h /\ ^sep_tm /\ refund_image_mem 0w s.MEM``);
val _ = pr ("DEFINITION " ^ thm_to_string entry_def);
val hb1 = prove (``0x100004000w <=+ a ==> 0x100000000w <=+ (a:word64)``, blastLib.BBLAST_TAC);
val hb2 = prove (``a <+ 0x10002C018w ==> a <+ 0x100030F30w:word64``, blastLib.BBLAST_TAC);
val sep_weak = prove (``^sep_tm ==> !i (a:word64). i < 40 /\ 0x100004000w <=+ a /\ a <+ 0x10002C018w ==> (h:word64) + n2w i <> a``,
  rpt strip_tac >> imp_res_tac hb1 >> imp_res_tac hb2 >> metis_tac []);
val entry_pre = thm "refund_entry_pre_IMP_cml_main_pre" ``refund_entry_pre s h stk e ==> cml_main_pre s h stk e``
  (rewrite_tac [entry_def] >> strip_tac >> imp_res_tac sep_weak >> drule img_stub >> simp [bytes_in_memory_def] >> strip_tac >>
   PURE_ONCE_REWRITE_TAC [cml_main_pre_def] >> rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >> show_tac "ENTRY");
val est = DB.fetch "forge_refundStartupBridge" "refund_startup_established";
val runf = DB.fetch "forge_refundCmlMainFrame" "cml_main_run_frame";
val ms = ``ms:arm8_state``;
val startup_conj = el 3 (strip_conj (snd (dest_exists (snd (dest_imp (concl est))))));
val main_goal = ``refund_entry_pre s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h ==>
  ?ms. arm8_run 27 s = SOME ms /\ ms.PC = 0x1000040D0w /\ ms.REG 1w = h /\ ms.REG 3w = e /\
       refund_image_mem 0w ms.MEM /\ bytes_in_memory ms.PC ^code_tm ms.MEM UNIV /\
       (!md k. (!i. i < LENGTH ^code_tm ==> ms.PC + n2w i IN md /\ ms.PC + n2w i NOTIN k) ==> bytes_in_mem ms.PC ^code_tm ms.MEM md k) /\
       (!mc0. is_arm8_machine_config mc0 /\ (!i. i < LENGTH ^code_tm ==> ms.PC + n2w i IN mc0.prog_addresses) ==>
              code_loaded ^code_tm mc0 ms) /\
       ^clause_tm ms.MEM /\
       (!a. ?w. ms.MEM a = get_byte a w F /\ (\a. Word (mem_dword ms.MEM a) : 64 word_loc) (byte_align a) = Word w) /\
       ^startup_conj``;
val main = thm "refund_loader_startup" main_goal
  (strip_tac >> imp_res_tac entry_pre >>
   mp_tac est >> impl_tac >- asm_rewrite_tac [] >> strip_tac >>
   mp_tac runf >> impl_tac >- asm_rewrite_tac [] >> strip_tac >>
   show_tac "MAIN0" >> `s1 = ms` by fs [] >> rpt BasicProvers.VAR_EQ_TAC >>
   qexists_tac `s1` >>
   `refund_image_mem 0w s1.MEM` by (match_mp_tac pres >> qexistsl_tac [`s.MEM`, `h`] >> fs [entry_def] >> show_tac "MAIN1") >>
   `bytes_in_memory s1.PC ^code_tm s1.MEM UNIV` by (drule img_code >> asm_simp_tac (srw_ss()) []) >>
   asm_rewrite_tac [] >> rpt conj_tac
   >- (rpt strip_tac >> asm_simp_tac std_ss [bytes_in_mem_iff] >> fs [])
   >- (rpt strip_tac >> match_mp_tac cl >> fs [])
   >- (mp_tac (Q.SPEC `s1.MEM` bm_clause) >> asm_rewrite_tac [])
   >- (MATCH_ACCEPT_TAC (Q.SPEC `s1.MEM` mem_dword_word_memory_clause))
   >- (show_tac "MAIN2" >> first_assum ACCEPT_TAC));
(* ---- 7. Negative controls (theorems). ---- *)
val n1 = thm "code_byte_change_rejected"
  ``!i a (m:word64 -> word8) md k. i < LENGTH ^code_tm /\ m (a + n2w i) <> EL i ^code_tm ==> ~bytes_in_mem a ^code_tm m md k``
  (simp [bytes_in_mem_iff, bytes_in_memory_univ_EL] >> metis_tac []);
val n4a = thm "code_overlap_rejected"
  ``!i a (m:word64 -> word8) md k. i < LENGTH ^code_tm /\ a + n2w i IN k ==> ~bytes_in_mem a ^code_tm m md k``
  (simp [bytes_in_mem_iff] >> metis_tac []);
val n2 = thm "bitmap_word_change_rejected"
  ``!(m:word64 -> word8) dm r i. i < LENGTH ^data_tm /\ mem_dword m (0x10002C018w + n2w (8 * i)) <> n2w (EL i ^data_tm) ==>
      ~(word_list 0x10002C018w (MAP (Word o n2w) ^data_tm) * r) (fun2set ((\a. Word (mem_dword m a) : 64 word_loc), dm))``
  (rpt strip_tac >> drule_at (Pos (el 2)) word_list_clause_read >> simp [len_data] >> qexists_tac `i` >>
   fs [len_data, EL_MAP, word_mul_n2w] >> show_tac "N2");
val n3a = thm "code_wrong_offset_rejected" ``!m md k. refund_image_mem 0w m ==> ~bytes_in_mem 0x1000040D4w ^code_tm m md k``
  (rpt strip_tac >> drule img_code >> strip_tac >> fs [bytes_in_mem_iff] >>
   qpat_x_assum `bytes_in_memory 0x1000040D4w _ _ _` (mp_tac o Q.SPEC `0` o SIMP_RULE std_ss [bytes_in_memory_univ_EL]) >>
   qpat_x_assum `bytes_in_memory _ _ _ _` (mp_tac o Q.SPEC `4` o SIMP_RULE std_ss [bytes_in_memory_univ_EL]) >>
   simp (len_code :: el_code) >> show_tac "N3A");
val n3b = thm "bitmap_wrong_offset_rejected"
  ``!m dm r. refund_image_mem 0w m ==>
      ~(word_list 0x10002C020w (MAP (Word o n2w) ^data_tm) * r) (fun2set ((\a. Word (mem_dword m a) : 64 word_loc), dm))``
  (rpt strip_tac >> drule_at (Pos (el 2)) word_list_clause_read >> simp [len_data] >> qexists_tac `0` >>
   mp_tac (Q.SPECL [`0w`, `m`, `1`] img_bm) >> asm_simp_tac (srw_ss()) ([len_data, EL_MAP] @ el_data) >> show_tac "N3B");
val run0 = DB.fetch "forge_refundCmlMainStep" "cml_main_run";
val n4b = thm "header_on_bitmaps_refuted"
  ``cml_main_pre s 0x10002C018w stk e ==> ?ms. arm8_run 27 s = SOME ms /\
      !dm r. ~(word_list 0x10002C018w (MAP (Word o n2w) ^data_tm) * r) (fun2set ((\a. Word (mem_dword ms.MEM a) : 64 word_loc), dm))``
  (strip_tac >> imp_res_tac run0 >> qexists_tac `s1` >> asm_rewrite_tac [] >> rpt gen_tac >>
   match_mp_tac (SIMP_RULE (srw_ss()) [] (Q.SPECL [`s1.MEM`, `dm`, `r`, `0`] n2)) >> asm_simp_tac (srw_ss()) (len_data :: el_data) >> show_tac "N4B");
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val closure = "forge_refundLoaderMemory" :: Theory.ancestry "forge_refundLoaderMemory";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

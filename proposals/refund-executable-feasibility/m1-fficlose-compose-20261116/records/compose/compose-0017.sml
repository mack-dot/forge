(* U394: the complete cake_fficlose path as one conditional machine-level theorem.
   entry stub (1 step) + fficlose prefix (14 steps) + an ASSUMED relation for the external close call + fficlose suffix (6 steps).
   close_call_rel is an explicit assumption. libSystem, the kernel, dynamic binding, oracle conformance, the loader and the
   PIE slide are NOT modelled and NOT proved. Only the name close is treated. Slide 0. *)
open preamble targetSemTheory asmPropsTheory lab_to_targetTheory arm8Theory arm8_targetTheory arm8_stepTheory alignmentTheory miscTheory
     fsFFITheory forge_refundStartupBridgeTheory forge_refundCmlMainStepTheory forge_loaderMemLemmasTheory forge_refundImageTheory
     forge_refundLoaderMemoryTheory forge_refundEntrySatTheory forge_refundInstalledDomainsTheory forge_refundEnvModelTheory
     forge_refundFficloseStepTheory forge_refundFficloseBridgeTheory forge_refundFficloseAssertTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (300, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundFficloseCompose";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
val image_def = DB.fetch "forge_refundImage" "refund_image_mem_def";
val len_text = DB.fetch "forge_refundImage" "refund_file_text_length"; val len_bm = DB.fetch "forge_refundImage" "refund_file_bitmap_length";
fun F n = DB.fetch "forge_refundFficloseStep" n;
val [user_def, pre3_def, suffix_thm] = map F ["arm8_user_def", "fficlose_return_pre_def", "fficlose_suffix_run"];
val exit_thm = DB.fetch "forge_refundFficloseBridge" "cake_fficlose_to_import_branch";
val img_code = DB.fetch "forge_refundFficloseBridge" "refund_image_fficlose_code";
val tsr_facts = DB.fetch "forge_refundEnvModel" "arm8_target_state_rel_facts";
val s = ``s:arm8_state``; val s1 = ``s1:arm8_state``; val s2 = ``s2:arm8_state``; val s3 = ``s3:arm8_state``;
val b = ``b:word64``; val c = ``c:word64``; val g = ``g:word64``; val dm = ``dm:word64 set``;
val regs = ``[19w;20w;21w;22w;23w;24w;25w;26w;27w;28w] : word5 list``;
(* ---- 1. Definitions. ---- *)
val rel_def = new_definition ("close_call_rel_def", ``close_call_rel ^dm ^s1 ^s2 <=>
   arm8_user s2 /\ s2.PC = s1.REG 30w /\ s2.SP_EL0 = s1.SP_EL0 /\
   (!r. MEM r ^regs ==> s2.REG r = s1.REG r) /\
   (!i. i < 32 ==> s2.MEM (s1.SP_EL0 + n2w i) = s1.MEM (s1.SP_EL0 + n2w i)) /\
   (!q. 0x100000000w <=+ q /\ q <+ 0x100030F30w ==> s2.MEM q = s1.MEM q) /\
   (!q. q IN dm ==> s2.MEM q = s1.MEM q)``);
val (eant, _) = dest_imp (concl exit_thm);
val pre_def = new_definition ("fficlose_call_pre_def", ``fficlose_call_pre ^dm ^s ^b ^c ^g <=> ^eant /\
   (!i. i < 32 ==> ^b + n2w i NOTIN dm) /\ (!i. i < 32 ==> s.REG 2w <> ^b + n2w i) /\
   ~(0x100000000w <=+ s.REG 2w /\ s.REG 2w <+ 0x100030F30w)``);
val byte_def = new_definition ("close_result_byte_def", ``close_result_byte (x0:word64) = if (w2w x0 : word32) = 0w then 0w else 1w : word8``);
val at_def = new_definition ("fficlose_at_call_def", ``fficlose_at_call ^s ^b ^g ^s1 <=>
   arm8_user s1 /\ s1.PC = g /\ s1.REG 30w = 0x10002528Cw /\ s1.REG 19w = s.REG 2w /\ s1.SP_EL0 = b /\
   mem_dword s1.MEM b = s.REG 20w /\ mem_dword s1.MEM (b + 8w) = s.REG 19w /\ mem_dword s1.MEM (b + 16w) = s.REG 29w /\
   mem_dword s1.MEM (b + 24w) = s.REG 30w /\
   (!q. (!i. i < 32 ==> q <> b + n2w i) ==> s1.MEM q = s.MEM q) /\
   (!r. r <> 0w /\ r <> 8w /\ r <> 16w /\ r <> 19w /\ r <> 29w /\ r <> 30w ==> s1.REG r = s.REG r)``);
val path_def = new_definition ("fficlose_path_def", ``fficlose_path ^dm ^s ^s3 <=>
   ?s1 s2. arm8_run 15 s = SOME s1 /\ close_call_rel dm s1 s2 /\ arm8_run 6 s2 = SOME s3``);
val _ = List.app (fn d => pr ("DEFINITION " ^ thm_to_string d)) [rel_def, pre_def, byte_def, at_def, path_def];
(* ---- 2. Small lemmas. ---- *)
val b1 = prove (``i < 163840 ==> 0x100000000w <=+ 0x100000000w + n2w i:word64 /\ 0x100000000w + n2w i <+ 0x100030F30w:word64``,
  strip_tac >> simp [word_add_n2w, word_ls_n2w, word_lo_n2w]);
val b2 = prove (``i < 20248 ==> 0x100000000w <=+ 0x10002C018w + n2w i:word64 /\ 0x10002C018w + n2w i <+ 0x100030F30w:word64``,
  strip_tac >> simp [word_add_n2w, word_ls_n2w, word_lo_n2w]);
val IP = thm "refund_image_mem_agree"
  ``!m m'. refund_image_mem 0w m /\ (!q. 0x100000000w <=+ q /\ q <+ 0x100030F30w ==> m' q = m q) ==> refund_image_mem 0w m'``
  (rw [image_def] >> match_mp_tac bytes_in_memory_univ_frame >> qexists_tac `m` >> asm_rewrite_tac [len_text, len_bm] >>
   rpt strip_tac >> first_x_assum match_mp_tac >> imp_res_tac b1 >> imp_res_tac b2 >> asm_rewrite_tac []);
val MD = thm "mem_dword_frame_agree"
  ``!m m' (x:word64). (!i. i < 32 ==> m' (x + n2w i) = m (x + n2w i)) ==>
      mem_dword m' x = mem_dword m x /\ mem_dword m' (x + 8w) = mem_dword m (x + 8w) /\
      mem_dword m' (x + 16w) = mem_dword m (x + 16w) /\ mem_dword m' (x + 24w) = mem_dword m (x + 24w)``
  (rpt gen_tac >> strip_tac >>
   map_every (fn k => first_assum (mp_tac o SIMP_RULE (srw_ss()) [] o SPEC (numSyntax.term_of_int k))) (List.tabulate (32, fn k => k)) >>
   rpt strip_tac >> asm_simp_tac (srw_ss()) [mem_dword_def]);
val (_, sbody) = dest_exists (snd (dest_imp (concl suffix_thm)));
val raw_byte = rhs (valOf (List.find (fn t => is_eq t andalso aconv (lhs t) ``(s1:arm8_state).MEM a``) (strip_conj sbody)));
val byte_eq = prove (mk_eq (raw_byte, ``close_result_byte ((s:arm8_state).REG 0w)``), rw [byte_def] >> EVAL_TAC);
val _ = pr ("BYTE_FORM " ^ thm_to_string byte_eq);
(* ---- 3. The three parts. ---- *)
val T_a = thm "cake_fficlose_reaches_call"
  ``fficlose_call_pre ^dm ^s ^b ^c ^g ==> ?s1. arm8_run 15 s = SOME s1 /\ fficlose_at_call s b g s1``
  (rewrite_tac [pre_def] >> strip_tac >> mp_tac exit_thm >> (impl_tac >- asm_rewrite_tac []) >>
   disch_then (qx_choose_then `s1` strip_assume_tac) >> qexists_tac `s1` >> asm_rewrite_tac [at_def, user_def] >>
   fs [user_def]);
val ret_tm = ``fficlose_return_pre ^s2 ^b (s.REG 2w) (s.REG 20w) (s.REG 19w) (s.REG 29w) (s.REG 30w)``;
val T_b = thm "close_call_rel_gives_return_state"
  ``fficlose_call_pre ^dm ^s ^b ^c ^g /\ fficlose_at_call s b g ^s1 /\ close_call_rel dm s1 ^s2 ==> ^ret_tm``
  (rewrite_tac [pre_def, at_def, rel_def] >> strip_tac >>
   `!q. 0x100000000w <=+ q /\ q <+ 0x100030F30w ==> s2.MEM q = s.MEM q` by
      (rpt strip_tac >> `s1.MEM q = s.MEM q` by (first_x_assum match_mp_tac >> rpt strip_tac >> metis_tac []) >> metis_tac []) >>
   `fficlose_code_bytes s2.MEM` by (match_mp_tac img_code >> match_mp_tac IP >> qexists_tac `s.MEM` >> asm_rewrite_tac []) >>
   `!i. i < 32 ==> s2.MEM (b + n2w i) = s1.MEM (b + n2w i)` by metis_tac [] >>
   drule MD >> strip_tac >>
   `s2.REG 19w = s1.REG 19w` by (first_x_assum match_mp_tac >> simp []) >>
   asm_rewrite_tac [pre3_def] >> rpt conj_tac
   >- (rpt strip_tac >> `i = 0` by decide_tac >> fs [] >> metis_tac [])
   >- (rpt strip_tac >> `i = 0` by decide_tac >> fs [] >> metis_tac []));
val concl_tm = ``s3.PC = s.REG 30w /\ s3.SP_EL0 = s.SP_EL0 /\ arm8_user s3 /\ (!r. MEM r ^regs ==> s3.REG r = s.REG r) /\
                 (!q. q IN dm ==> s3.MEM q = if q = s.REG 2w then close_result_byte (s2.REG 0w) else s.MEM q)``;
val T_c = thm "fficlose_after_call"
  ``fficlose_call_pre ^dm ^s ^b ^c ^g /\ fficlose_at_call s b g ^s1 /\ close_call_rel dm s1 ^s2 ==> ?s3. arm8_run 6 s2 = SOME s3 /\ ^concl_tm``
  (strip_tac >> `^ret_tm` by (match_mp_tac T_b >> asm_rewrite_tac []) >>
   drule suffix_thm >> rewrite_tac [byte_eq] >> disch_then (qx_choose_then `s3` strip_assume_tac) >> qexists_tac `s3` >>
   qpat_x_assum `fficlose_call_pre _ _ _ _ _` (strip_assume_tac o REWRITE_RULE [pre_def]) >>
   qpat_x_assum `fficlose_at_call _ _ _ _` (strip_assume_tac o REWRITE_RULE [at_def]) >>
   qpat_x_assum `close_call_rel _ _ _` (strip_assume_tac o REWRITE_RULE [rel_def]) >>
   qpat_x_assum `arm8_user s2` (strip_assume_tac o REWRITE_RULE [user_def]) >>
   rpt conj_tac >|
   [asm_rewrite_tac [],
    asm_rewrite_tac [],
    asm_rewrite_tac [],
    asm_rewrite_tac [user_def],
    rpt gen_tac >> strip_tac >>
      qpat_assum `!r. _ ==> s3.REG r = s2.REG r` (qspec_then `r` assume_tac) >>
      qpat_assum `!r. _ ==> s2.REG r = s1.REG r` (qspec_then `r` assume_tac) >>
      qpat_assum `!r. _ ==> s1.REG r = s.REG r` (qspec_then `r` assume_tac) >>
      fs [] >> rveq >> fs [],
    rpt strip_tac >> Cases_on `q = s.REG 2w` >> asm_rewrite_tac []
      >> `s3.MEM q = s2.MEM q` by (qpat_x_assum `!q. _ ==> s3.MEM q = s2.MEM q` match_mp_tac >> rpt strip_tac >>
                                     `i = 0` by decide_tac >> fs []) >>
         `s2.MEM q = s1.MEM q` by (qpat_x_assum `!q. q IN dm ==> _` match_mp_tac >> first_assum ACCEPT_TAC) >>
         `s1.MEM q = s.MEM q` by (qpat_x_assum `!q. _ ==> s1.MEM q = s.MEM q` match_mp_tac >> rpt strip_tac >> metis_tac []) >>
         asm_rewrite_tac []]);
val M = thm "cake_fficlose_path"
  ``fficlose_call_pre ^dm ^s ^b ^c ^g ==>
    ?s1. arm8_run 15 s = SOME s1 /\ s1.PC = g /\ s1.REG 30w = 0x10002528Cw /\
         !s2. close_call_rel dm s1 s2 ==> ?s3. arm8_run 6 s2 = SOME s3 /\ ^concl_tm``
  (strip_tac >> drule T_a >> disch_then (qx_choose_then `s1` strip_assume_tac) >> qexists_tac `s1` >>
   first_assum (strip_assume_tac o REWRITE_RULE [at_def]) >> asm_rewrite_tac [] >> rpt strip_tac >>
   mp_tac T_c >> (impl_tac >- asm_rewrite_tac []) >> disch_then ACCEPT_TAC);
(* ---- 4. Relation to the FFI contract, for close only (index 2). ---- *)
val RBT = thm "read_bytearray_nonempty"
  ``!n (x:word64) f (bs:word8 list). read_bytearray x n f = SOME bs /\ n <> 0 ==>
      ?h t. bs = h::t /\ f x = SOME h /\ read_bytearray (x + 1w) (n - 1) f = SOME t``
  (Cases >> simp [read_bytearray_def, AllCaseEqs()] >> rpt strip_tac >> gvs []);
val WB = thm "asm_write_bytearray_same_content"
  ``!bs n (x:word64) (m:word64 -> word8) tm dm.
      read_bytearray x n (\a. if a IN dm then SOME (m a) else NONE) = SOME bs /\ (!a. a IN dm ==> m a = tm a) ==>
      !q. q IN dm ==> asm_write_bytearray x bs tm q = tm q``
  (Induct >> simp [asm_write_bytearray_def] >> rpt gen_tac >> Cases_on `n` >> simp [read_bytearray_def, AllCaseEqs()] >>
   rpt strip_tac >> gvs [combinTheory.APPLY_UPDATE_THM] >> rw [] >> metis_tac []);
val KM = thm "asm_write_bytearray_first_byte"
  ``!bytes2 n (x:word64) (m:word64 -> word8) tm dm v q.
      read_bytearray x n (\a. if a IN dm then SOME (m a) else NONE) = SOME bytes2 /\ n <> 0 /\ (!a. a IN dm ==> m a = tm a) /\ q IN dm ==>
      asm_write_bytearray x (v :: TL bytes2) tm q = if q = x then v else m q``
  (rpt strip_tac >> drule_all RBT >> strip_tac >> rveq >>
   mp_tac (Q.SPECL [`t`, `n - 1`, `x + 1w`, `m`, `tm`, `dm`] WB) >> (impl_tac >- asm_rewrite_tac []) >>
   disch_then (qspec_then `q` mp_tac) >> asm_rewrite_tac [] >> strip_tac >>
   asm_simp_tac (srw_ss()) [asm_write_bytearray_def, combinTheory.APPLY_UPDATE_THM] >> rw [] >> res_tac >> fs []);
val K = thm "cake_fficlose_path_contract_instance"
  ``(t1:64 asm_state).mem_domain = ^dm /\
    read_bytearray (s.REG 2w) (w2n (s.REG 3w)) (\a. if a IN dm then SOME (s.MEM a) else NONE) = SOME bytes2 /\
    target_state_rel arm8_target (t1 with pc := 0x1000040D0w - n2w ((3 + 2) * 16)) ^s /\ aligned 2 (t1.regs 30) /\
    fficlose_call_pre dm s ^b ^c ^g /\ fficlose_path dm s ^s3 ==>
    ?v. (v = 0w \/ v = 1w) /\ arm8_ok s3 /\ s3.PC = t1.regs 30 /\
        (!a. a IN dm ==> s3.MEM a = asm_write_bytearray (t1.regs 2) (v :: TL bytes2) t1.mem a) /\
        (!r. MEM r [19;20;21;22;23;24;25;27;28] ==> s3.REG (n2w r) = t1.regs r)``
  (rewrite_tac [path_def] >> strip_tac >> drule M >> disch_then (qx_choose_then `s1'` strip_assume_tac) >>
   `s1' = s1` by fs [] >> rveq >> first_x_assum drule >> disch_then (qx_choose_then `s3'` strip_assume_tac) >>
   `s3' = s3` by fs [] >> rveq >>
   first_assum (strip_assume_tac o SIMP_RULE (srw_ss()) [] o MATCH_MP tsr_facts) >>
   qpat_assum `fficlose_call_pre _ _ _ _ _` (strip_assume_tac o REWRITE_RULE [pre_def]) >>
   `w2n (s.REG 3w) <> 0` by (Cases_on `s.REG 3w` >> fs []) >>
   `s.REG 30w = t1.regs 30 /\ s.REG 2w = t1.regs 2` by
      (qpat_assum `!i. _ ==> s.REG (n2w i) = t1.regs i` (fn th => mp_tac (Q.SPEC `30` th) >> mp_tac (Q.SPEC `2` th)) >> simp []) >>
   qexists_tac `close_result_byte (s2.REG 0w)` >> rpt conj_tac
   >- (rw [byte_def])
   >- (qpat_x_assum `arm8_user s3` (strip_assume_tac o REWRITE_RULE [user_def]) >> asm_simp_tac (srw_ss()) [arm8_ok_def])
   >- (asm_rewrite_tac [])
   >- (rpt strip_tac >>
       qpat_x_assum `s.REG 2w = t1.regs 2` (fn th => rewrite_tac [SYM th]) >>
       qpat_assum `read_bytearray _ _ _ = SOME bytes2` (fn rb =>
         qpat_assum `!a. a IN t1.mem_domain ==> s.MEM a = t1.mem a` (fn eqm =>
           qpat_assum `a IN t1.mem_domain` (fn ain =>
             qpat_assum `w2n _ <> 0` (fn nz => assume_tac (MATCH_MP KM (LIST_CONJ [rb, nz, eqm, ain])))))) >>
       pop_assum (fn th => rewrite_tac [th]) >>
       qpat_assum `!q. q IN t1.mem_domain ==> s3.MEM q = _` match_mp_tac >> first_assum ACCEPT_TAC)
   >- (rpt gen_tac >> strip_tac >>
       qpat_assum `!r. MEM r _ ==> s3.REG r = s.REG r` (qspec_then `n2w r` mp_tac) >>
       qpat_assum `!i. _ ==> s.REG (n2w i) = t1.regs i` (qspec_then `r` mp_tac) >>
       fs [] >> rveq >> fs []));
(* ---- 5. Non-vacuity. Constructed witnesses; NOT evidence about a loader, libSystem or a real process. ---- *)
val NV1 = thm "close_call_rel_inhabited" ``!dm s1. arm8_user s1 ==> close_call_rel dm s1 (s1 with PC := s1.REG 30w)``
  (simp [rel_def, user_def]);
val a0 = ``0x200000100w:word64``; val b0 = ``0x400000000w:word64``; val c0 = ``0x200000200w:word64``; val g0 = ``0w:word64``;
val dm0 = ``{^a0}``;
val sw = ``(ARB:arm8_state) with <| MEM := sat_mem; PC := 0x100004080w; SP_EL0 := 0x400000020w;
     REG := (\r. if r = 0w then ^c0 else if r = 1w then 8w else if r = 2w then ^a0 else if r = 3w then 1w else 0w);
     PSTATE := (ARB with EL := 0w); exception := NoException;
     SCTLR_EL1 := (ARB with <| E0E := F; SA0 := F |>); TCR_EL1 := (ARB with <| TBI0 := F; TBI1 := F |>) |>``;
val sat_img = DB.fetch "forge_refundEntrySat" "sat_mem_image";
val sat_mem_def = DB.fetch "forge_refundEntrySat" "sat_mem_def";
val sels = map (fn q => SIMP_CONV (srw_ss()) [] q) [``(^sw).MEM``, ``(^sw).REG 0w``, ``(^sw).REG 1w``, ``(^sw).REG 2w``, ``(^sw).REG 3w``,
                                                    ``(^sw).SP_EL0``, ``(^sw).PC``];
val vS = prove (``!v a:word64. v <+ 32w /\ 0x100000000w <=+ a /\ a <+ 0x100030F30w ==> ^b0 + v <> a``, blastLib.BBLAST_TAC);
val vC = prove (``!v w:word64. v <+ 32w /\ w <+ 8w ==> ^b0 + v <> ^c0 + w``, blastLib.BBLAST_TAC);
val vA = prove (``!v:word64. v <+ 32w ==> ^a0 <> ^b0 + v /\ ^b0 + v <> ^a0``, blastLib.BBLAST_TAC);
val inst_pre = ``fficlose_call_pre ^dm0 ^sw ^b0 ^c0 ^g0``;
val unfolded = (REWR_CONV pre_def THENC PURE_REWRITE_CONV sels) inst_pre handle e => (pr "UNFOLD_FAILED"; raise e);
val wcs = strip_conj (rhs (concl unfolded));
val _ = pr ("WITNESS_CONJUNCTS " ^ Int.toString (length wcs));
val closers = [ACCEPT_TAC sat_img,
   rewrite_tac [user_def] >> EVAL_TAC >> NO_TAC,
   rewrite_tac [mem_dword_def, sat_mem_def] >> EVAL_TAC >> NO_TAC,
   EVAL_TAC >> NO_TAC,
   rpt gen_tac >> strip_tac >> match_mp_tac vS >> asm_rewrite_tac [] >> simp [word_lo_n2w] >> NO_TAC,
   rpt gen_tac >> strip_tac >> match_mp_tac vC >> simp [word_lo_n2w] >> NO_TAC,
   rpt gen_tac >> strip_tac >> `n2w i <+ 32w:word64` by simp [word_lo_n2w] >> imp_res_tac vA >> asm_simp_tac (srw_ss()) [] >> NO_TAC,
   simp [] >> NO_TAC];
val wths = map (fn cj => Tactical.TAC_PROOF (([], cj), FIRST closers)
                handle e => (pr ("WITNESS_CONJUNCT_FAILED " ^ term_to_string cj); failed := "witness" :: !failed; TRUTH)) wcs;
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val W2 = save_thm ("fficlose_call_pre_witness", EQ_MP (SYM unfolded)
   (Tactical.TAC_PROOF (([], rhs (concl unfolded)), rpt conj_tac >> FIRST (map ACCEPT_TAC wths))));
val _ = chk "fficlose_call_pre_witness" W2;
val NV2 = thm "fficlose_call_pre_satisfiable" ``?dm s b c g. fficlose_call_pre dm s b c g``
  (map_every exists_tac [dm0, sw, b0, c0, g0] >> ACCEPT_TAC W2);
val isub = [dm |-> dm0, s |-> sw, b |-> b0, c |-> c0, g |-> g0];
val NV3 = thm "cake_fficlose_path_inhabited" ``?dm s b c g s3. fficlose_call_pre dm s b c g /\ fficlose_path dm s s3``
  (strip_assume_tac (MP (INST isub T_a) W2) >>
   `arm8_user s1` by (pop_assum mp_tac >> simp_tac std_ss [at_def]) >>
   first_assum (assume_tac o SPEC dm0 o MATCH_MP (ONCE_REWRITE_RULE [SWAP_FORALL_THM] NV1 |> SPEC_ALL |> Q.GENL [`dm`] handle _ => NV1)) >>
   mp_tac (INST (isub @ [s2 |-> ``(s1:arm8_state) with PC := s1.REG 30w``]) T_c) >>
   (impl_tac >- asm_rewrite_tac [W2]) >> strip_tac >>
   map_every exists_tac [dm0, sw, b0, c0, g0] >> qexists_tac `s3` >> rewrite_tac [W2, path_def] >>
   map_every qexists_tac [`s1`, `s1 with PC := s1.REG 30w`] >> asm_rewrite_tac []);
(* ---- 6. The oracle side for close (model fact; conformance of the real call is NOT proved). ---- *)
val O1 = thm "ffi_close_accepts_only_valid_lengths"
  ``ffi_close (cf:word8 list) (bs:word8 list) fs = SOME (FFIreturn nb fs') ==> LENGTH cf = 8 /\ 1 <= LENGTH bs /\ ?v. (v = 0w \/ v = 1w) /\ nb = v :: TL bs``
  (rw [ffi_close_def] >> gvs [OPTION_CHOICE_EQUALS_OPTION] >> rpt (pairarg_tac >> gvs []) >> Cases_on `bs` >> gvs [LUPDATE_def] >> show_tac "O1");
(* ---- 7. Negative controls. ---- *)
val stub_exact = DB.fetch "forge_refundFficloseBridge" "cake_fficlose_stub_exact";
val run_add = DB.fetch "forge_refundFficloseBridge" "arm8_run_add";
val clen_thm = DB.fetch "forge_refundFficloseAssert" "fficlose_clen_bad_reaches_assert";
val alen_thm = DB.fetch "forge_refundFficloseAssert" "fficlose_alen_zero_reaches_assert";
val clen_pre = DB.fetch "forge_refundFficloseAssert" "fficlose_clen_bad_pre_def";
val alen_pre = DB.fetch "forge_refundFficloseAssert" "fficlose_alen_zero_pre_def";
val sepS = ``!i (a:word64). i < 32 /\ 0x100000000w <=+ a /\ a <+ 0x100030F30w ==> ^b + n2w i <> a``;
fun bad_arg name extra pre_d th n pc =
  thm name ``arm8_user s /\ s.PC = 0x100004080w /\ refund_image_mem 0w s.MEM /\ s.SP_EL0 = ^b + 32w /\ aligned 3 ^b /\ ^sepS /\ ^extra ==>
             ?s1. arm8_run ^(numSyntax.term_of_int n) s = SOME s1 /\ s1.PC = ^pc``
  (strip_tac >> mp_tac stub_exact >> (impl_tac >- asm_rewrite_tac []) >> disch_then (qx_choose_then `s0` strip_assume_tac) >>
   mp_tac (Q.INST [`s` |-> `s0`] th) >>
   (impl_tac >- (fs [pre_d, user_def] >> match_mp_tac img_code >> first_assum ACCEPT_TAC)) >>
   disch_then (qx_choose_then `s1` strip_assume_tac) >> qexists_tac `s1` >> asm_rewrite_tac [] >>
   `arm8_run (1 + ^(numSyntax.term_of_int (n - 1))) s = SOME s1` by (match_mp_tac run_add >> qexists_tac `s0` >> asm_rewrite_tac []) >> fs []);
val c2a = bad_arg "invalid_clen_reaches_assert_block" ``~word_msb ((s:arm8_state).REG 3w) /\ s.REG 3w <> 0w /\ s.REG 1w <> 8w`` clen_pre clen_thm 8 ``0x1000252A8w:word64``;
val c2b = bad_arg "zero_alen_reaches_assert_block" ``(s:arm8_state).REG 3w = 0w`` alen_pre alen_thm 6 ``0x1000252A4w:word64``;
val c1 = thm "invalid_arguments_not_covered"
  ``(s.REG 1w <> 8w \/ s.REG 3w = 0w \/ word_msb (s.REG 3w)) ==> ~fficlose_call_pre ^dm ^s ^b ^c ^g``
  (rw [pre_def] >> fs []);
val c3 = thm "corrupted_return_state_not_in_relation"
  ``(s2.PC <> s1.REG 30w \/ s2.SP_EL0 <> s1.SP_EL0 \/ s2.REG 19w <> s1.REG 19w \/
     (?i. i < 32 /\ s2.MEM (s1.SP_EL0 + n2w i) <> s1.MEM (s1.SP_EL0 + n2w i))) ==> ~close_call_rel ^dm ^s1 ^s2``
  (rw [rel_def] >> fs [] >> metis_tac []);
val c4 = thm "frame_in_protected_domain_not_covered"
  ``i < 32 /\ ^b + n2w i IN dm ==> ~fficlose_call_pre ^dm ^s ^b ^c ^g``
  (rw [pre_def] >> metis_tac []);
val c4b = thm "prefix_writes_the_frame"
  ``fficlose_call_pre ^dm ^s ^b ^c ^g /\ mem_dword s.MEM b <> s.REG 20w ==> ?s1. arm8_run 15 s = SOME s1 /\ mem_dword s1.MEM b <> mem_dword s.MEM b``
  (strip_tac >> drule T_a >> disch_then (qx_choose_then `s1` strip_assume_tac) >> qexists_tac `s1` >> fs [at_def]);
val c5 = thm "overlapping_configuration_is_vacuous_case" ``~fficlose_call_pre ^dm ^s ^b ^b ^g``
  (rw [pre_def] >> rpt strip_tac >> CCONTR_TAC >> fs [] >> first_x_assum (qspecl_then [`0`, `0`] mp_tac) >> simp []);
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val closure = "forge_refundFficloseCompose" :: Theory.ancestry "forge_refundFficloseCompose";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

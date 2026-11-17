(* U398: composition of the write path for the outcome "the external call returns a non-negative 32-bit value", under the
   ASSUMED relation write_call_rel and the explicit premise ~s2.SCTLR_EL1.A on the return state. The halfword store at a + 1
   uses sturh_w9_x19_1_step_no_alignment (derived from the L3 definitions; no alignment premise on a + 1).
   NOT modelled, NOT proved: libSystem write, the kernel, the output effect, dynamic binding, oracle conformance, loader, slide,
   Device memory. Constructed witnesses are NOT reachable states. *)
open preamble targetSemTheory arm8Theory arm8_targetTheory arm8_stepTheory alignmentTheory miscTheory
     forge_refundCmlMainStepTheory forge_refundImageTheory forge_refundEntrySatTheory
     forge_refundFficloseStepTheory forge_refundFficloseBridgeTheory forge_refundFficloseComposeTheory forge_refundFfiwriteStepTheory
     forge_refundFfiwritePathTheory forge_refundFfiwriteComposeTheory forge_refundFfiwriteSiteTheory forge_refundFfiwriteUnalignedTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (300, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundFfiwriteSuccess";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
fun P n = DB.fetch "forge_refundFfiwritePath" n;
fun Cm n = DB.fetch "forge_refundFfiwriteCompose" n;
val [pre_def, rel_def, exit_thm, img_code] = map P ["ffiwrite_call_pre_def", "write_call_rel_def", "cake_ffiwrite_to_import_branch", "refund_image_ffiwrite_code"];
val [at_def, T_a, T_c] = map Cm ["ffiwrite_at_call_def", "cake_ffiwrite_reaches_call", "ffiwrite_after_failed_call"];
fun U n = DB.fetch "forge_refundFfiwriteUnaligned" n;
val [preN_def, ok_thm] = map U ["ffiwrite_return_ok_na_pre_def", "ffiwrite_suffix_ok_unaligned_run"];
val user_def = DB.fetch "forge_refundFficloseStep" "arm8_user_def";
val run_def = DB.fetch "forge_refundCmlMainStep" "arm8_run_def";
val IP = DB.fetch "forge_refundFficloseCompose" "refund_image_mem_agree";
val MD = DB.fetch "forge_refundFficloseCompose" "mem_dword_frame_agree";
val s = ``s:arm8_state``; val s1 = ``s1:arm8_state``; val s2 = ``s2:arm8_state``; val s3 = ``s3:arm8_state``;
val b = ``b:word64``; val c = ``c:word64``; val a = ``a:word64``; val g = ``g:word64``; val dm = ``dm:word64 set``;
val regs = ``[19w;20w;21w;22w;23w;24w;25w;26w;27w;28w] : word5 list``;
val preT = ``ffiwrite_call_pre ^dm ^s ^b ^c ^a ^g``;
val body = strip_conj (rhs (snd (strip_forall (concl pre_def))));
val failbit = ``word_bit 31 (w2w ((^s2).REG 0w) : word32)``;
val nA = ``~(^s2).SCTLR_EL1.A``;
val ret_tm = ``ffiwrite_return_ok_na_pre ^s2 ^b ^a (s.REG 20w) (s.REG 19w) (s.REG 29w) (s.REG 30w)``;
(* ---- 1. Return state of a successful call satisfies the suffix pre-state. ---- *)
val T_b = thm "write_call_rel_gives_ok_return_state"
  ``^preT /\ ffiwrite_at_call s b a g ^s1 /\ write_call_rel dm s1 ^s2 /\ ^nA /\ ~^failbit ==> ^ret_tm``
  (rewrite_tac [pre_def, at_def, rel_def] >> strip_tac >>
   `!q. 0x100000000w <=+ q /\ q <+ 0x100030F30w ==> s2.MEM q = s.MEM q` by
      (rpt strip_tac >> `s1.MEM q = s.MEM q` by (first_x_assum match_mp_tac >> rpt strip_tac >> metis_tac []) >> metis_tac []) >>
   `ffiwrite_code_bytes s2.MEM` by (match_mp_tac img_code >> match_mp_tac IP >> qexists_tac `s.MEM` >> asm_rewrite_tac []) >>
   `!i. i < 32 ==> s2.MEM (b + n2w i) = s1.MEM (b + n2w i)` by metis_tac [] >>
   drule MD >> strip_tac >>
   `s2.REG 19w = s1.REG 19w` by (first_x_assum match_mp_tac >> simp []) >>
   asm_rewrite_tac [preN_def] >> show_tac "TB");
val mem_ok = ``s3.MEM ^a = 0w /\ s3.MEM (^a + 1w) = (15 >< 8) ((^s2).REG 0w) /\ s3.MEM (^a + 2w) = (7 >< 0) ((^s2).REG 0w)``;
val common = ``s3.PC = s.REG 30w /\ s3.SP_EL0 = s.SP_EL0 /\ arm8_user s3 /\ (!r. MEM r ^regs ==> s3.REG r = s.REG r) /\
               (!q. q IN dm /\ q <> ^a /\ q <> a + 1w /\ q <> a + 2w ==> s3.MEM q = s.MEM q)``;
val concl_ok = mk_conj (common, mem_ok);
val prem = ``^preT /\ ffiwrite_at_call s b a g ^s1 /\ write_call_rel dm s1 ^s2 /\ ^nA /\ ~^failbit``;
val T_ok = thm "ffiwrite_after_successful_call" ``^prem ==> ?s3. arm8_run 10 s2 = SOME s3 /\ ^concl_ok``
  (strip_tac >> `^ret_tm` by (match_mp_tac T_b >> asm_rewrite_tac []) >>
   drule ok_thm >> disch_then (qx_choose_then `s3` strip_assume_tac) >> qexists_tac `s3` >>
   qpat_x_assum `ffiwrite_call_pre _ _ _ _ _ _` (strip_assume_tac o REWRITE_RULE [pre_def]) >>
   qpat_x_assum `ffiwrite_at_call _ _ _ _ _` (strip_assume_tac o REWRITE_RULE [at_def]) >>
   qpat_x_assum `write_call_rel _ _ _` (strip_assume_tac o REWRITE_RULE [rel_def]) >>
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
      fs [] >> rveq >> fs [] >> show_tac "TC-REG",
    rpt strip_tac
      >> `s3.MEM q = s2.MEM q` by (qpat_x_assum `!q. _ ==> s3.MEM q = s2.MEM q` match_mp_tac >> rpt strip_tac >>
                                     `i = 0 \/ i = 1 \/ i = 2` by decide_tac >> fs [] >> show_tac "TC-FRAME") >>
         `s2.MEM q = s1.MEM q` by (qpat_x_assum `!q. q IN dm ==> _` match_mp_tac >> first_assum ACCEPT_TAC) >>
         `s1.MEM q = s.MEM q` by (qpat_x_assum `!q. _ ==> s1.MEM q = s.MEM q` match_mp_tac >> rpt strip_tac >> metis_tac []) >>
         asm_rewrite_tac [],
    asm_rewrite_tac [],
    asm_rewrite_tac [],
    asm_rewrite_tac []]);
val M_ok = thm "cake_ffiwrite_path_successful_write"
  ``^preT ==> ?s1. arm8_run 23 s = SOME s1 /\ s1.PC = g /\ s1.REG 30w = 0x10002522Cw /\
       !s2. write_call_rel dm s1 s2 /\ ^nA /\ ~^failbit ==> ?s3. arm8_run 10 s2 = SOME s3 /\ ^concl_ok``
  (strip_tac >> drule T_a >> disch_then (qx_choose_then `s1` strip_assume_tac) >> qexists_tac `s1` >>
   first_assum (strip_assume_tac o REWRITE_RULE [at_def]) >> asm_rewrite_tac [] >> rpt strip_tac >>
   mp_tac T_ok >> (impl_tac >- asm_rewrite_tac []) >> disch_then ACCEPT_TAC);
(* ---- 2. Both outcomes in one statement. ---- *)
val M_all = thm "cake_ffiwrite_path_returns"
  ``^preT ==> ?s1. arm8_run 23 s = SOME s1 /\ s1.PC = g /\ s1.REG 30w = 0x10002522Cw /\
       !s2. write_call_rel dm s1 s2 /\ ^nA ==>
            ?n s3. arm8_run n s2 = SOME s3 /\ ^common /\
                   (if ^failbit then n = 6 /\ s3.MEM a = 1w /\ s3.MEM (a + 1w) = s.MEM (a + 1w) /\ s3.MEM (a + 2w) = s.MEM (a + 2w) \/ T
                    else n = 10 /\ ^mem_ok)``
  (strip_tac >> drule T_a >> disch_then (qx_choose_then `s1` strip_assume_tac) >> qexists_tac `s1` >>
   first_assum (strip_assume_tac o REWRITE_RULE [at_def]) >> asm_rewrite_tac [] >> rpt strip_tac >>
   Cases_on `^failbit`
   >- (mp_tac T_c >> (impl_tac >- asm_rewrite_tac []) >> disch_then (qx_choose_then `s3` strip_assume_tac) >>
       qexistsl_tac [`6`, `s3`] >> asm_rewrite_tac [] >> rpt strip_tac >> res_tac >> fs [])
   >- (mp_tac T_ok >> (impl_tac >- asm_rewrite_tac []) >> disch_then (qx_choose_then `s3` strip_assume_tac) >>
       qexistsl_tac [`10`, `s3`] >> asm_rewrite_tac []));
(* ---- 3. Controls. ---- *)
val k1 = thm "write_success_result_bytes_exact"
  ``^prem /\ arm8_run 10 s2 = SOME ^s3 ==> ^mem_ok``
  (strip_tac >> mp_tac T_ok >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >> fs []);
val k2 = thm "write_wrong_result_bytes_refuted"
  ``^prem /\ arm8_run 10 s2 = SOME ^s3 /\ (s3.MEM a <> 0w \/ s3.MEM (a + 1w) <> (15 >< 8) (s2.REG 0w) \/ s3.MEM (a + 2w) <> (7 >< 0) (s2.REG 0w)) ==> F``
  (strip_tac >> mp_tac k1 >> asm_rewrite_tac [] >> fs []);
val k3 = thm "write_return_to_wrong_address_not_in_relation"
  ``ffiwrite_at_call s b a g ^s1 /\ s2.PC <> 0x10002522Cw ==> ~write_call_rel ^dm s1 ^s2``
  (rw [at_def, rel_def] >> fs []);
val k4 = thm "write_result_bytes_in_image_not_covered"
  ``i < 3 /\ 0x100000000w <=+ ^a + n2w i /\ ^a + n2w i <+ 0x100030F30w ==> ~^preT``
  (rw [pre_def] >> metis_tac []);
val k5 = thm "write_success_caller_return_address_exact"
  ``^prem /\ arm8_run 10 s2 = SOME ^s3 /\ s3.PC <> s.REG 30w ==> F``
  (strip_tac >> mp_tac T_ok >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >> fs []);
(* ---- 4. Non-vacuity (constructed states; NOT reachable states). ---- *)
val ok_state = ``(s1:arm8_state) with <| PC := s1.REG 30w; REG := (0w =+ 5w) s1.REG |>``;
val NV1 = thm "write_call_rel_inhabited_ok"
  ``!dm s1. arm8_user s1 /\ ~s1.SCTLR_EL1.A ==>
      write_call_rel dm s1 ^ok_state /\ ~(^ok_state).SCTLR_EL1.A /\ ~word_bit 31 (w2w ((^ok_state).REG 0w) : word32)``
  (rpt gen_tac >> strip_tac >> rpt conj_tac
   >- (fs [rel_def, user_def, combinTheory.APPLY_UPDATE_THM] >> rpt strip_tac >> rveq >> simp_tac (srw_ss()) [])
   >- asm_simp_tac (srw_ss()) []
   >- (simp_tac (srw_ss()) [combinTheory.APPLY_UPDATE_THM] >> EVAL_TAC));
val a0 = ``0x200000100w:word64``; val b0 = ``0x400000000w:word64``; val c0 = ``0x200000200w:word64``; val g0 = ``0w:word64``;
val dm0 = ``{^a0}``;
val sw = ``(ARB:arm8_state) with <| MEM := sat_mem; PC := 0x100004090w; SP_EL0 := 0x400000020w;
     REG := (\r. if r = 0w then ^c0 else if r = 1w then 8w else if r = 2w then ^a0 else if r = 3w then 4w else 0w);
     PSTATE := (ARB with EL := 0w); exception := NoException;
     SCTLR_EL1 := (ARB with <| E0E := F; SA0 := F; A := F |>); TCR_EL1 := (ARB with <| TBI0 := F; TBI1 := F |>) |>``;
val sat_img = DB.fetch "forge_refundEntrySat" "sat_mem_image";
val sat_mem_def = DB.fetch "forge_refundEntrySat" "sat_mem_def";
val sels = map (fn q => SIMP_CONV (srw_ss()) [] q) [``(^sw).MEM``, ``(^sw).REG 0w``, ``(^sw).REG 1w``, ``(^sw).REG 2w``, ``(^sw).REG 3w``,
                                                    ``(^sw).SP_EL0``, ``(^sw).PC``];
val vS = prove (``!v x:word64. v <+ 32w /\ 0x100000000w <=+ x /\ x <+ 0x100030F30w ==> ^b0 + v <> x``, blastLib.BBLAST_TAC);
val vC = prove (``!v w:word64. v <+ 32w /\ w <+ 8w ==> ^b0 + v <> ^c0 + w``, blastLib.BBLAST_TAC);
val vBA = prove (``!v w:word64. v <+ 32w /\ w <+ 4w ==> ^b0 + v <> ^a0 + w``, blastLib.BBLAST_TAC);
val vA1 = prove (``!v x:word64. v <+ 3w /\ 0x100000000w <=+ x /\ x <+ 0x100030F30w ==> ^a0 + v <> x``, blastLib.BBLAST_TAC);
val vA2 = prove (``!v w:word64. v <+ 3w /\ w <+ 32w ==> ^a0 + v <> ^b0 + w``, blastLib.BBLAST_TAC);
val vD = prove (``!v:word64. v <+ 32w ==> ^b0 + v <> ^a0``, blastLib.BBLAST_TAC);
val inst_pre = ``ffiwrite_call_pre ^dm0 ^sw ^b0 ^c0 ^a0 ^g0``;
val unfolded = (REWR_CONV pre_def THENC PURE_REWRITE_CONV sels) inst_pre;
val wcs = strip_conj (rhs (concl unfolded));
val _ = pr ("WITNESS_CONJUNCTS " ^ Int.toString (length wcs));
val closers = [ACCEPT_TAC sat_img,
   rewrite_tac [user_def] >> EVAL_TAC >> NO_TAC,
   rewrite_tac [mem_dword_def, sat_mem_def] >> EVAL_TAC >> NO_TAC,
   rewrite_tac [sat_mem_def] >> EVAL_TAC >> NO_TAC,
   EVAL_TAC >> NO_TAC,
   rpt gen_tac >> strip_tac >> match_mp_tac vS >> asm_rewrite_tac [] >> simp [word_lo_n2w] >> NO_TAC,
   rpt gen_tac >> strip_tac >> match_mp_tac vA1 >> asm_rewrite_tac [] >> simp [word_lo_n2w] >> NO_TAC,
   rpt gen_tac >> strip_tac >> match_mp_tac vC >> simp [word_lo_n2w] >> NO_TAC,
   rpt gen_tac >> strip_tac >> match_mp_tac vBA >> simp [word_lo_n2w] >> NO_TAC,
   rpt gen_tac >> strip_tac >> match_mp_tac vA2 >> simp [word_lo_n2w] >> NO_TAC,
   rpt gen_tac >> strip_tac >> `n2w i <+ 32w:word64` by simp [word_lo_n2w] >> imp_res_tac vD >> asm_simp_tac (srw_ss()) [] >> NO_TAC,
   simp [] >> NO_TAC];
val wths = map (fn cj => Tactical.TAC_PROOF (([], cj), FIRST closers)
                handle e => (pr ("WITNESS_CONJUNCT_FAILED " ^ String.substring (term_to_string cj, 0, Int.min (300, size (term_to_string cj)))); failed := "witness" :: !failed; TRUTH)) wcs;
val W2 = save_thm ("ffiwrite_call_pre_witness_A_clear", EQ_MP (SYM unfolded)
   (Tactical.TAC_PROOF (([], rhs (concl unfolded)), rpt conj_tac >> FIRST (map ACCEPT_TAC wths))));
val _ = chk "ffiwrite_call_pre_witness_A_clear" W2;

val isub = [dm |-> dm0, s |-> sw, b |-> b0, c |-> c0, a |-> a0, g |-> g0];
val swA = prove (``~(^sw).SCTLR_EL1.A``, simp_tac (srw_ss()) []);
val NV3 = thm "cake_ffiwrite_success_path_inhabited"
  ``?dm s b c a g s1 s2 s3. ffiwrite_call_pre dm s b c a g /\ arm8_run 23 s = SOME s1 /\ write_call_rel dm s1 s2 /\ ~s2.SCTLR_EL1.A /\
       ~word_bit 31 (w2w (s2.REG 0w) : word32) /\ arm8_run 10 s2 = SOME s3 /\ s3.MEM a = 0w /\ s3.MEM (a + 2w) = 5w``
  (strip_assume_tac (MP (INST isub T_a) W2) >>
   strip_assume_tac (MP (INST isub exit_thm) W2) >>
   `arm8_user s1` by (qpat_x_assum `ffiwrite_at_call _ _ _ _ _` mp_tac >> simp_tac std_ss [at_def]) >>
   `~s1.SCTLR_EL1.A` by (fs [] >> rveq >> fs [swA] >> show_tac "NV3-A") >>
   mp_tac (SPECL [dm0, s1] NV1) >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
   mp_tac (INST (isub @ [s2 |-> ok_state]) T_ok) >>
   (impl_tac >- asm_rewrite_tac [W2]) >> strip_tac >>
   map_every exists_tac [dm0, sw, b0, c0, a0, g0] >> map_every qexists_tac [`s1`, `^ok_state`, `s3`] >> asm_rewrite_tac [W2] >>
   simp_tac (srw_ss()) [combinTheory.APPLY_UPDATE_THM] >> EVAL_TAC >> show_tac "NV3-END");
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val closure = "forge_refundFfiwriteSuccess" :: Theory.ancestry "forge_refundFfiwriteSuccess";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

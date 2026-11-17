(* U397: non-vacuity witnesses for the write path; what the published machine semantics gives at write call states;
   oracle facts; negative controls. Model machine only for the call-site part. Constructed witnesses are NOT reachable states. *)
open preamble targetSemTheory asmPropsTheory lab_to_targetTheory arm8Theory arm8_targetTheory arm8_stepTheory alignmentTheory miscTheory ffiTheory
     semanticsPropsTheory fsFFITheory basis_ffiTheory forge_refundImageTheory forge_refundEntrySatTheory forge_refundInstalledDomainsTheory
     forge_refundResidualTheory forge_refundEnvModelTheory forge_refundFficloseStepTheory forge_refundCallSiteTheory
     forge_refundFfiwriteStepTheory forge_refundFfiwritePathTheory forge_refundFfiwriteComposeTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (300, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundFfiwriteSite";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
fun P n = DB.fetch "forge_refundFfiwritePath" n;
fun Cm n = DB.fetch "forge_refundFfiwriteCompose" n;
val [pre_def, rel_def] = map P ["ffiwrite_call_pre_def", "write_call_rel_def"];
val [at_def, T_a, T_c] = map Cm ["ffiwrite_at_call_def", "cake_ffiwrite_reaches_call", "ffiwrite_after_failed_call"];
val user_def = DB.fetch "forge_refundFficloseStep" "arm8_user_def";
val conflict = DB.fetch "forge_refundFfiwriteStep" "ffiwrite_ok_alignment_conflict";
val s = ``s:arm8_state``; val s1 = ``s1:arm8_state``; val s2 = ``s2:arm8_state``;
val b = ``b:word64``; val c = ``c:word64``; val a = ``a:word64``; val g = ``g:word64``; val dm = ``dm:word64 set``;
val preT = ``ffiwrite_call_pre ^dm ^s ^b ^c ^a ^g``;
val body = strip_conj (rhs (snd (strip_forall (concl pre_def))));
(* ---- 1. Non-vacuity (constructed states). ---- *)
val fail_state = ``(s1:arm8_state) with <| PC := s1.REG 30w; REG := (0w =+ 0x80000000w) s1.REG |>``;
val NV1 = thm "write_call_rel_inhabited_fail"
  ``!dm s1. arm8_user s1 ==> write_call_rel dm s1 ^fail_state /\ word_bit 31 (w2w ((^fail_state).REG 0w) : word32)``
  (simp [rel_def, user_def, combinTheory.APPLY_UPDATE_THM] >> EVAL_TAC);
val a0 = ``0x200000100w:word64``; val b0 = ``0x400000000w:word64``; val c0 = ``0x200000200w:word64``; val g0 = ``0w:word64``;
val dm0 = ``{^a0}``;
val sw = ``(ARB:arm8_state) with <| MEM := sat_mem; PC := 0x100004090w; SP_EL0 := 0x400000020w;
     REG := (\r. if r = 0w then ^c0 else if r = 1w then 8w else if r = 2w then ^a0 else if r = 3w then 4w else 0w);
     PSTATE := (ARB with EL := 0w); exception := NoException;
     SCTLR_EL1 := (ARB with <| E0E := F; SA0 := F |>); TCR_EL1 := (ARB with <| TBI0 := F; TBI1 := F |>) |>``;
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
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val W2 = save_thm ("ffiwrite_call_pre_witness", EQ_MP (SYM unfolded)
   (Tactical.TAC_PROOF (([], rhs (concl unfolded)), rpt conj_tac >> FIRST (map ACCEPT_TAC wths))));
val _ = chk "ffiwrite_call_pre_witness" W2;
val NV2 = thm "ffiwrite_call_pre_satisfiable" ``?dm s b c a g. ffiwrite_call_pre dm s b c a g``
  (map_every exists_tac [dm0, sw, b0, c0, a0, g0] >> ACCEPT_TAC W2);
val isub = [dm |-> dm0, s |-> sw, b |-> b0, c |-> c0, a |-> a0, g |-> g0];
val NV3 = thm "cake_ffiwrite_failed_path_inhabited"
  ``?dm s b c a g s1 s2 s3. ffiwrite_call_pre dm s b c a g /\ arm8_run 23 s = SOME s1 /\ write_call_rel dm s1 s2 /\
       word_bit 31 (w2w (s2.REG 0w) : word32) /\ arm8_run 6 s2 = SOME s3``
  (strip_assume_tac (MP (INST isub T_a) W2) >>
   `arm8_user s1` by (pop_assum mp_tac >> simp_tac std_ss [at_def]) >>
   first_assum (strip_assume_tac o SPEC dm0 o Q.GEN `dm` o SPEC_ALL o MATCH_MP (SPEC_ALL NV1 |> Q.GEN `dm` |> SPEC dm0 |> DISCH_ALL |> REWRITE_RULE [] handle _ => SPEC_ALL NV1)) >>
   mp_tac (INST (isub @ [s2 |-> fail_state]) T_c) >>
   (impl_tac >- asm_rewrite_tac [W2]) >> strip_tac >>
   map_every exists_tac [dm0, sw, b0, c0, a0, g0] >> map_every qexists_tac [`s1`, `^fail_state`, `s3`] >> asm_rewrite_tac [W2]);
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

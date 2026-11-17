(* U397: composition of the write path for the outcome "the external call reports an error", under the ASSUMED relation
   write_call_rel; non-vacuity witnesses; call-site facts from the published machine semantics; controls.
   NOT modelled, NOT proved: libSystem write, the kernel, the output effect, dynamic binding, oracle conformance, loader, slide.
   The success outcome is NOT composed (no step theorem for the unaligned halfword store at a + 1). *)
open preamble targetSemTheory asmPropsTheory lab_to_targetTheory arm8Theory arm8_targetTheory arm8_stepTheory alignmentTheory miscTheory ffiTheory
     semanticsPropsTheory fsFFITheory basis_ffiTheory forge_refundCmlMainStepTheory forge_refundImageTheory forge_refundEntrySatTheory
     forge_refundInstalledDomainsTheory forge_refundResidualTheory forge_refundEnvModelTheory forge_refundFficloseStepTheory
     forge_refundFficloseBridgeTheory forge_refundFficloseComposeTheory forge_refundCallSiteTheory forge_refundFfiwriteStepTheory
     forge_refundFfiwritePathTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (300, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundFfiwriteCompose";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
fun P n = DB.fetch "forge_refundFfiwritePath" n;
val [pre_def, rel_def, exit_thm, img_code] = map P ["ffiwrite_call_pre_def", "write_call_rel_def", "cake_ffiwrite_to_import_branch", "refund_image_ffiwrite_code"];
fun W n = DB.fetch "forge_refundFfiwriteStep" n;
val [preF_def, fail_thm] = map W ["ffiwrite_return_fail_pre_def", "ffiwrite_suffix_fail_run"];
val user_def = DB.fetch "forge_refundFficloseStep" "arm8_user_def";
val IP = DB.fetch "forge_refundFficloseCompose" "refund_image_mem_agree";
val MD = DB.fetch "forge_refundFficloseCompose" "mem_dword_frame_agree";
val s = ``s:arm8_state``; val s1 = ``s1:arm8_state``; val s2 = ``s2:arm8_state``; val s3 = ``s3:arm8_state``;
val b = ``b:word64``; val c = ``c:word64``; val a = ``a:word64``; val g = ``g:word64``; val dm = ``dm:word64 set``;
val regs = ``[19w;20w;21w;22w;23w;24w;25w;26w;27w;28w] : word5 list``;
val preT = ``ffiwrite_call_pre ^dm ^s ^b ^c ^a ^g``;
(* ---- 1. State at the call. ---- *)
val at_def = new_definition ("ffiwrite_at_call_def", ``ffiwrite_at_call ^s ^b ^a ^g ^s1 <=>
   arm8_user s1 /\ s1.PC = g /\ s1.REG 30w = 0x10002522Cw /\ s1.REG 19w = a /\ s1.SP_EL0 = b /\
   mem_dword s1.MEM b = s.REG 20w /\ mem_dword s1.MEM (b + 8w) = s.REG 19w /\ mem_dword s1.MEM (b + 16w) = s.REG 29w /\
   mem_dword s1.MEM (b + 24w) = s.REG 30w /\
   (!q. (!i. i < 32 ==> q <> b + n2w i) ==> s1.MEM q = s.MEM q) /\
   (!r. r <> 0w /\ r <> 1w /\ r <> 2w /\ r <> 8w /\ r <> 9w /\ r <> 16w /\ r <> 19w /\ r <> 29w /\ r <> 30w ==> s1.REG r = s.REG r)``);
val T_a = thm "cake_ffiwrite_reaches_call" ``^preT ==> ?s1. arm8_run 23 s = SOME s1 /\ ffiwrite_at_call s b a g s1``
  (strip_tac >> drule exit_thm >> disch_then (qx_choose_then `s1` strip_assume_tac) >> qexists_tac `s1` >>
   qpat_x_assum `ffiwrite_call_pre _ _ _ _ _ _` (strip_assume_tac o REWRITE_RULE [pre_def]) >>
   asm_rewrite_tac [at_def, user_def] >> fs [user_def] >> show_tac "TA");
val ret_tm = ``ffiwrite_return_fail_pre ^s2 ^b ^a (s.REG 20w) (s.REG 19w) (s.REG 29w) (s.REG 30w)``;
val failbit = ``word_bit 31 (w2w ((^s2).REG 0w) : word32)``;
val T_b = thm "write_call_rel_gives_fail_return_state"
  ``^preT /\ ffiwrite_at_call s b a g ^s1 /\ write_call_rel dm s1 ^s2 /\ ^failbit ==> ^ret_tm``
  (rewrite_tac [pre_def, at_def, rel_def] >> strip_tac >>
   `!q. 0x100000000w <=+ q /\ q <+ 0x100030F30w ==> s2.MEM q = s.MEM q` by
      (rpt strip_tac >> `s1.MEM q = s.MEM q` by (first_x_assum match_mp_tac >> rpt strip_tac >> metis_tac []) >> metis_tac []) >>
   `ffiwrite_code_bytes s2.MEM` by (match_mp_tac img_code >> match_mp_tac IP >> qexists_tac `s.MEM` >> asm_rewrite_tac []) >>
   `!i. i < 32 ==> s2.MEM (b + n2w i) = s1.MEM (b + n2w i)` by metis_tac [] >>
   drule MD >> strip_tac >>
   `s2.REG 19w = s1.REG 19w` by (first_x_assum match_mp_tac >> simp []) >>
   asm_rewrite_tac [preF_def] >> show_tac "TB");
val concl_tm = ``s3.PC = s.REG 30w /\ s3.SP_EL0 = s.SP_EL0 /\ arm8_user s3 /\ (!r. MEM r ^regs ==> s3.REG r = s.REG r) /\
                 (!q. q IN dm ==> s3.MEM q = if q = a then 1w else s.MEM q)``;
val T_c = thm "ffiwrite_after_failed_call"
  ``^preT /\ ffiwrite_at_call s b a g ^s1 /\ write_call_rel dm s1 ^s2 /\ ^failbit ==> ?s3. arm8_run 6 s2 = SOME s3 /\ ^concl_tm``
  (strip_tac >> `^ret_tm` by (match_mp_tac T_b >> asm_rewrite_tac []) >>
   drule fail_thm >> disch_then (qx_choose_then `s3` strip_assume_tac) >> qexists_tac `s3` >>
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
    rpt strip_tac >> Cases_on `q = a` >> asm_rewrite_tac []
      >> `s3.MEM q = s2.MEM q` by (qpat_x_assum `!q. _ ==> s3.MEM q = s2.MEM q` match_mp_tac >> rpt strip_tac >>
                                     `i = 0` by decide_tac >> fs []) >>
         `s2.MEM q = s1.MEM q` by (qpat_x_assum `!q. q IN dm ==> _` match_mp_tac >> first_assum ACCEPT_TAC) >>
         `s1.MEM q = s.MEM q` by (qpat_x_assum `!q. _ ==> s1.MEM q = s.MEM q` match_mp_tac >> rpt strip_tac >> metis_tac []) >>
         asm_rewrite_tac []]);
val M = thm "cake_ffiwrite_path_failed_write"
  ``^preT ==> ?s1. arm8_run 23 s = SOME s1 /\ s1.PC = g /\ s1.REG 30w = 0x10002522Cw /\
       !s2. write_call_rel dm s1 s2 /\ ^failbit ==> ?s3. arm8_run 6 s2 = SOME s3 /\ ^concl_tm``
  (strip_tac >> drule T_a >> disch_then (qx_choose_then `s1` strip_assume_tac) >> qexists_tac `s1` >>
   first_assum (strip_assume_tac o REWRITE_RULE [at_def]) >> asm_rewrite_tac [] >> rpt strip_tac >>
   mp_tac T_c >> (impl_tac >- asm_rewrite_tac []) >> disch_then ACCEPT_TAC);
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

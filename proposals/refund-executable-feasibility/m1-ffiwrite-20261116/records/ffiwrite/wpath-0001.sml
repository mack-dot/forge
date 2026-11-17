(* U397: the write FFI path. File bytes of cake_ffiwrite, ffiwrite and the write import stub; ARMv8 steps on the image;
   composition for the outcome "the external call reports an error" under an ASSUMED relation for the call;
   call-site facts from the published machine semantics; controls.
   NOT modelled, NOT proved: libSystem write, the kernel, the output effect, dynamic binding, oracle conformance, loader, slide.
   The success outcome is NOT composed: the step library has no theorem for the unaligned halfword store at a + 1. *)
open preamble targetSemTheory asmPropsTheory lab_to_targetTheory arm8Theory arm8_targetTheory arm8_stepTheory alignmentTheory miscTheory ffiTheory
     semanticsPropsTheory fsFFITheory basis_ffiTheory forge_refundStartupBridgeTheory forge_refundCmlMainStepTheory forge_loaderMemLemmasTheory
     forge_refundImageTheory forge_refundEntrySatTheory forge_refundInstalledDomainsTheory forge_refundResidualTheory forge_refundEnvModelTheory
     forge_refundFficloseStepTheory forge_refundFficloseBridgeTheory forge_refundFficloseComposeTheory forge_refundCallSiteTheory
     forge_refundFfiwriteStepTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (300, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundFfiwritePath";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
val file_def = DB.fetch "forge_refundImage" "refund_file_def";
val file_c = lhs (concl file_def);
val len_file = DB.fetch "forge_refundImage" "refund_file_length";
val image_def = DB.fetch "forge_refundImage" "refund_image_mem_def";
fun W n = DB.fetch "forge_refundFfiwriteStep" n;
val [code_def, pre1_def, base_def, pre2_def, preF_def] = map W ["ffiwrite_code_bytes_def", "ffiwrite_stub_pre_def", "ffiwrite_entry_base_def",
      "ffiwrite_entry_pre_def", "ffiwrite_return_fail_pre_def"];
val [stub_thm, prefix_thm, fail_thm] = map W ["cake_ffiwrite_stub_run", "ffiwrite_prefix_run", "ffiwrite_suffix_fail_run"];
val user_def = DB.fetch "forge_refundFficloseStep" "arm8_user_def";
val SL = DB.fetch "forge_refundFficloseBridge" "bytes_in_memory_slice";
val run_add = DB.fetch "forge_refundFficloseBridge" "arm8_run_add";
val IP = DB.fetch "forge_refundFficloseCompose" "refund_image_mem_agree";
val MD = DB.fetch "forge_refundFficloseCompose" "mem_dword_frame_agree";
(* ---- 1. File bytes. ---- *)
fun slice (off, n) = (RAND_CONV (RAND_CONV (REWR_CONV file_def)) THENC EVAL)
      ``TAKE ^(numSyntax.term_of_int n) (DROP ^(numSyntax.term_of_int off) ^file_c)``;
val sl_stub = slice (0x4090, 4); val sl_body = slice (0x251E0, 120); val sl_imp = slice (0x259C4, 12);
val words_thm = save_thm ("refund_file_ffiwrite_words", LIST_CONJ [sl_stub, sl_body, sl_imp]);
val _ = chk "refund_file_ffiwrite_words" words_thm;
val img_code = thm "refund_image_ffiwrite_code" ``!m. refund_image_mem 0w m ==> ffiwrite_code_bytes m``
  (rw [image_def] >>
   map_every (fn (off, n) => mp_tac (Q.SPECL [`refund_file`, `0x100000000w`, `m`, `163840`, off, n] SL))
      [(`16528`, `4`), (`152032`, `120`), (`153028`, `12`)] >>
   asm_simp_tac std_ss [len_file] >> simp [sl_stub, sl_body, sl_imp, bytes_in_memory_def] >> rpt strip_tac >>
   asm_simp_tac std_ss [code_def]);
val stub_exact = thm "cake_ffiwrite_stub_exact"
  ``arm8_user s /\ s.PC = 0x100004090w /\ refund_image_mem 0w s.MEM ==>
    ?s1. arm8_run 1 s = SOME s1 /\ s1.PC = 0x1000251E0w /\ s1.REG = s.REG /\ s1.MEM = s.MEM /\ s1.SP_EL0 = s.SP_EL0 /\
         s1.PSTATE = s.PSTATE /\ s1.SCTLR_EL1 = s.SCTLR_EL1 /\ s1.TCR_EL1 = s.TCR_EL1 /\ s1.exception = s.exception``
  (strip_tac >> match_mp_tac stub_thm >> asm_rewrite_tac [pre1_def] >> match_mp_tac img_code >> first_assum ACCEPT_TAC);
(* ---- 2. Definitions: call pre-state, external-call relation. ---- *)
val s = ``s:arm8_state``; val s1 = ``s1:arm8_state``; val s2 = ``s2:arm8_state``; val s3 = ``s3:arm8_state``;
val b = ``b:word64``; val c = ``c:word64``; val a = ``a:word64``; val g = ``g:word64``; val dm = ``dm:word64 set``;
val regs = ``[19w;20w;21w;22w;23w;24w;25w;26w;27w;28w] : word5 list``;
val base_body = strip_conj (rhs (snd (strip_forall (concl base_def))));
val entry_conds = List.drop (base_body, 3);
val len_conds = tl (strip_conj (rhs (snd (strip_forall (concl pre2_def)))));
val sepA1 = ``!i (x:word64). i < 3 /\ 0x100000000w <=+ x /\ x <+ 0x100030F30w ==> ^a + n2w i <> x``;
val sepA2 = ``!i j. i < 3 /\ j < 32 ==> ^a + n2w i <> ^b + n2w j``;
val pre_def = new_definition ("ffiwrite_call_pre_def", ``ffiwrite_call_pre ^dm ^s ^b ^c ^a ^g <=>
   arm8_user s /\ s.PC = 0x100004090w /\ refund_image_mem 0w s.MEM /\ ^(list_mk_conj (entry_conds @ len_conds)) /\
   (!i. i < 32 ==> ^b + n2w i NOTIN dm) /\ ^sepA1 /\ ^sepA2``);
val rel_def = new_definition ("write_call_rel_def", ``write_call_rel ^dm ^s1 ^s2 <=>
   arm8_user s2 /\ s2.PC = s1.REG 30w /\ s2.SP_EL0 = s1.SP_EL0 /\
   (!r. MEM r ^regs ==> s2.REG r = s1.REG r) /\
   (!i. i < 32 ==> s2.MEM (s1.SP_EL0 + n2w i) = s1.MEM (s1.SP_EL0 + n2w i)) /\
   (!q. 0x100000000w <=+ q /\ q <+ 0x100030F30w ==> s2.MEM q = s1.MEM q) /\
   (!q. q IN dm ==> s2.MEM q = s1.MEM q)``);
val _ = List.app (fn d => pr ("DEFINITION " ^ thm_to_string d)) [pre_def, rel_def];
(* ---- 3. From the entry address to the branch that leaves the image: 23 steps. ---- *)
val (_, pbody) = dest_exists (snd (dest_imp (concl prefix_thm)));
val pconj = tl (strip_conj pbody);
val exit_thm = thm "cake_ffiwrite_to_import_branch"
  ``ffiwrite_call_pre ^dm ^s ^b ^c ^a ^g ==> ?s1. arm8_run 23 s = SOME s1 /\ ^(list_mk_conj pconj)``
  (rewrite_tac [pre_def] >> strip_tac >> mp_tac stub_exact >> (impl_tac >- asm_rewrite_tac []) >>
   disch_then (qx_choose_then `s0` strip_assume_tac) >>
   mp_tac (Q.INST [`s` |-> `s0`] prefix_thm) >>
   (impl_tac >- (fs [pre2_def, base_def, user_def] >> match_mp_tac img_code >> first_assum ACCEPT_TAC)) >>
   disch_then (qx_choose_then `s1` strip_assume_tac) >> qexists_tac `s1` >>
   `arm8_run (1 + 22) s = SOME s1` by (match_mp_tac run_add >> qexists_tac `s0` >> asm_rewrite_tac []) >>
   fs [] >> show_tac "EXIT");
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

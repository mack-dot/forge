(* U407 control: the premises of refund_installed_from_entry_reduced_sl are not contradictory at the nonzero slide 0x4000.
   One explicit, CONSTRUCTED ARMv8 model state satisfies them. This is a non-vacuity check only.
   It is NOT evidence that macOS, dyld or the C run-time produces such a state, and it is NOT a native execution witness. *)
open preamble arm8Theory arm8_stepTheory alignmentTheory miscTheory wordsLib blastLib targetSemTheory forge_refundCmlMainStepTheory
     forge_loaderMemLemmasTheory forge_refundImageTheory forge_refundLoaderMemoryTheory forge_refundStartupBridgeTheory
     forge_refundSlideEntryTheory forge_refundSlideDomainsTheory forge_refundSlideInstalledTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (400, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundSlideSat";
val failed = ref ([] : string list);
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th); th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; mk_thm ([], goal));
val image_def = DB.fetch "forge_refundImage" "refund_image_mem_def";
val len_text = DB.fetch "forge_refundImage" "refund_file_text_length"; val len_bm = DB.fetch "forge_refundImage" "refund_file_bitmap_length";
fun SE n = DB.fetch "forge_refundSlideEntry" n;
val [slide_def, entry_sl_def, clear_sl_def] = map SE ["slide_ok_def", "refund_entry_pre_sl_def", "refund_heap_clear_sl_def"];
val old_entry_def = DB.fetch "forge_refundLoaderMemory" "refund_entry_pre_def";
val T1 = DB.fetch "forge_refundSlideInstalled" "refund_installed_from_entry_reduced_sl";
fun w64 n = wordsSyntax.mk_wordii (n, 64);
fun le n = List.tabulate (8, fn k => wordsSyntax.mk_wordii ((n div (IntInf.toInt (IntInf.pow (256, k)))) mod 256, 8));
val h0 = 0x200000000; val stk0 = 0x200010000; val e0 = 0x200020000;
val SL = ``0x4000w:word64``;
val slots = listSyntax.mk_list (le h0 @ le stk0 @ le e0, ``:word8``);
(* image at 0x100000000 + 0x4000; bitmaps at 0x10002C018 + 0x4000; data slots at 0x10002C000 + 0x4000 *)
val mem_def = new_definition ("sat_mem_sl_def", ``sat_mem_sl (a:word64) =
   if a - 0x100004000w <+ 163840w then EL (w2n (a - 0x100004000w)) (TAKE 163840 refund_file)
   else if a - 0x100030018w <+ 20248w then EL (w2n (a - 0x100030018w)) (TAKE 20248 (DROP 180248 refund_file))
   else if a - 0x100030000w <+ 24w then EL (w2n (a - 0x100030000w)) ^slots else 0w:word8``);
val nb = prove (``!v:word64. v <+ 20248w ==> ~(v + 0x2C018w <+ 0x28000w)``, blastLib.BBLAST_TAC);
val img_sat = thm "sat_mem_sl_image" ``refund_image_mem ^SL sat_mem_sl``
  (simp [image_def, bytes_in_memory_univ_EL, len_text, len_bm] >> conj_tac >> rpt strip_tac
   >- (rewrite_tac [mem_def, WORD_ADD_SUB2] >> simp [word_lo_n2w] >> show_tac "SAT1")
   >- (`n2w i <+ 20248w:word64` by simp [word_lo_n2w] >>
       `~(n2w i + 0x2C018w <+ 0x28000w:word64)` by (match_mp_tac nb >> first_assum ACCEPT_TAC) >>
       rewrite_tac [mem_def] >> simp [word_lo_n2w] >> show_tac "SAT2"));
val slot = map (fn (a, v) => thm ("sat_sl_slot_" ^ Int.toString (a mod 256)) ``mem_dword sat_mem_sl ^(w64 a) = ^(w64 v)``
                   (rewrite_tac [mem_dword_def, mem_def] >> EVAL_TAC)) [(0x100030000, h0), (0x100030008, stk0), (0x100030010, e0)];
val sepv = prove (``!v u:word64. v <+ 40w /\ u <+ 200496w ==> 0x200000000w + v <> 0x100004000w + u``, blastLib.BBLAST_TAC);
val sep_sat = thm "sat_sl_separation" ``!i j. i < 40 /\ j < 200496 ==> 0x200000000w + n2w i <> 0x100004000w + (n2w j : word64)``
  (rpt gen_tac >> strip_tac >> match_mp_tac sepv >> simp [word_lo_n2w]);
val s0 = ``(ARB:arm8_state) with <| MEM := sat_mem_sl; PC := 0x100008000w; PSTATE := (ARB with EL := 0w); exception := NoException;
            SCTLR_EL1 := (ARB with <| E0E := F; SA0 := F |>); TCR_EL1 := (ARB with <| TBI0 := F; TBI1 := F |>) |>``;
val fmem = prove (``(^s0).MEM = sat_mem_sl``, simp []);
fun litadd t = if wordsSyntax.is_word_add t andalso null (free_vars t) andalso type_of t = ``:word64`` then EVAL t else NO_CONV t;
val slide_sat = prove (``slide_ok ^SL``, rewrite_tac [slide_def] >> EVAL_TAC);
val sat = thm "refund_entry_pre_sl_witness_0x4000" ``refund_entry_pre_sl ^SL ^s0 ^(w64 h0) ^(w64 stk0) ^(w64 e0)``
  (PURE_REWRITE_TAC [entry_sl_def, fmem] >> CONV_TAC (DEPTH_CONV litadd) >> rpt conj_tac >>
   FIRST (map ACCEPT_TAC (img_sat :: sep_sat :: slide_sat :: slot) @ [EVAL_TAC >> NO_TAC, simp [] >> NO_TAC, show_tac "SAT"]));
val heap_sat = thm "sat_sl_heap_premises"
  ``aligned 3 ^(w64 e0) /\ ^(w64 h0) <=+ ^(w64 e0) /\ 8192w <=+ ^(w64 e0) - ^(w64 h0) /\ refund_heap_clear_sl ^SL ^(w64 h0) ^(w64 e0)``
  (rewrite_tac [clear_sl_def] >> rpt conj_tac >> TRY (EVAL_TAC >> NO_TAC) >> blastLib.BBLAST_TAC);
val mcT = type_of (hd (List.filter (fn v => fst (dest_var v) = "envmc") (free_vars (concl T1))));
val env0 = ``(ARB : ^(ty_antiq mcT)) with prog_addresses := refund_mem_dm_sl ^SL ^(w64 h0) ^(w64 e0)``;
val env_sat = prove (``(^env0).prog_addresses = refund_mem_dm_sl ^SL ^(w64 h0) ^(w64 e0)``, simp []);
val ex = thm "refund_entry_sl_premises_satisfiable_at_0x4000"
  ``?s h stk e (envmc : ^(ty_antiq mcT)). refund_entry_pre_sl ^SL s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h /\ refund_heap_clear_sl ^SL h e /\
                       envmc.prog_addresses = refund_mem_dm_sl ^SL h e``
  (map_every exists_tac [s0, w64 h0, w64 stk0, w64 e0, env0] >> rewrite_tac [sat, heap_sat, env_sat]);
(* Consequence at the witness: the 27 steps end at the relocated code base and 28 clauses hold; the two environment clauses stay a premise. *)
val fv = fn n => valOf (List.find (fn v => fst (dest_var v) = n) (free_vars (concl T1)));
val T1i = INST [fv "sl" |-> SL, fv "s" |-> s0, fv "h" |-> w64 h0, fv "stk" |-> w64 stk0, fv "e" |-> w64 e0, fv "envmc" |-> env0] T1;
val T1c = MP T1i (LIST_CONJ [sat, CONJUNCT1 heap_sat, CONJUNCT1 (CONJUNCT2 heap_sat), CONJUNCT1 (CONJUNCT2 (CONJUNCT2 heap_sat)),
                             CONJUNCT2 (CONJUNCT2 (CONJUNCT2 heap_sat)), env_sat]);
val T1c = save_thm ("slide_0x4000_witness_reaches_installed_state_modulo_environment", CONV_RULE (DEPTH_CONV litadd) T1c);
val _ = (tags "slide_0x4000_witness_reaches_installed_state_modulo_environment" T1c;
         pr ("CHECKED slide_0x4000_witness_reaches_installed_state_modulo_environment\n" ^ thm_to_string T1c));
(* Negative controls: the witness is not a slide-0 entry state, and not an entry state for a different slide. *)
val pcv = prove (``(^s0).PC = 0x100008000w``, simp []);
val N1 = thm "sat_sl_witness_is_not_a_slide_zero_entry"
  ``~refund_entry_pre ^s0 ^(w64 h0) ^(w64 stk0) ^(w64 e0) /\ ~refund_entry_pre_sl 0w ^s0 ^(w64 h0) ^(w64 stk0) ^(w64 e0)``
  (PURE_REWRITE_TAC [old_entry_def, entry_sl_def, pcv] >> conj_tac >> strip_tac >> pop_assum kall_tac >>
   qpat_x_assum `0x100008000w = _` mp_tac >> EVAL_TAC);
val N2 = thm "sat_sl_witness_is_not_an_entry_for_slide_0x8000"
  ``~refund_entry_pre_sl 0x8000w ^s0 ^(w64 h0) ^(w64 stk0) ^(w64 e0)``
  (PURE_REWRITE_TAC [entry_sl_def, pcv] >> strip_tac >> qpat_x_assum `0x100008000w = _` mp_tac >> EVAL_TAC);
val N3 = thm "sat_sl_heap_on_relocated_image_rejected" ``~refund_heap_clear_sl ^SL 0x100004000w 0x100008000w``
  (rewrite_tac [clear_sl_def] >> strip_tac >> first_x_assum (qspec_then `0x100004000w` mp_tac) >> EVAL_TAC);
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundSlideSat" @ DB.definitions "forge_refundSlideSat");
val closure = "forge_refundSlideSat" :: Theory.ancestry "forge_refundSlideSat";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundSlideSat")));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

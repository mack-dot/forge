(* U389 control: the entry pre-state of refund_loader_startup is not contradictory. One explicit ARMv8 state satisfies it.
   This is a non-vacuity check only. It is NOT evidence that a loader or the C run-time produces such a state. *)
open preamble arm8Theory arm8_stepTheory alignmentTheory miscTheory wordsLib forge_refundCmlMainStepTheory forge_loaderMemLemmasTheory
     forge_refundImageTheory forge_refundLoaderMemoryTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (400, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundEntrySat";
val failed = ref ([] : string list);
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th); th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
val image_def = DB.fetch "forge_refundImage" "refund_image_mem_def";
val len_text = DB.fetch "forge_refundImage" "refund_file_text_length"; val len_bm = DB.fetch "forge_refundImage" "refund_file_bitmap_length";
val entry_def = DB.fetch "forge_refundLoaderMemory" "refund_entry_pre_def";
fun w64 n = wordsSyntax.mk_wordii (n, 64);
fun le n = List.tabulate (8, fn k => wordsSyntax.mk_wordii ((n div (IntInf.toInt (IntInf.pow (256, k)))) mod 256, 8));
val h0 = 0x200000000; val stk0 = 0x200010000; val e0 = 0x200020000;
val slots = listSyntax.mk_list (le h0 @ le stk0 @ le e0, ``:word8``);
val mem_def = new_definition ("sat_mem_def", ``sat_mem (a:word64) =
   if a - 0x100000000w <+ 163840w then EL (w2n (a - 0x100000000w)) (TAKE 163840 refund_file)
   else if a - 0x10002C018w <+ 20248w then EL (w2n (a - 0x10002C018w)) (TAKE 20248 (DROP 180248 refund_file))
   else if a - 0x10002C000w <+ 24w then EL (w2n (a - 0x10002C000w)) ^slots else 0w:word8``);
val nb = prove (``!v:word64. v <+ 20248w ==> ~(v + 0x2C018w <+ 0x28000w)``, blastLib.BBLAST_TAC);
val img_sat = thm "sat_mem_image" ``refund_image_mem 0w sat_mem``
  (simp [image_def, bytes_in_memory_univ_EL, len_text, len_bm] >> conj_tac >> rpt strip_tac
   >- (rewrite_tac [mem_def, WORD_ADD_SUB2] >> simp [word_lo_n2w])
   >- (`n2w i <+ 20248w:word64` by simp [word_lo_n2w] >>
       `~(n2w i + 0x2C018w <+ 0x28000w:word64)` by (match_mp_tac nb >> first_assum ACCEPT_TAC) >>
       rewrite_tac [mem_def] >> simp [word_lo_n2w] >> show_tac "SAT2"));
val slot = map (fn (a, v) => thm ("sat_slot_" ^ Int.toString (a mod 256)) ``mem_dword sat_mem ^(w64 a) = ^(w64 v)``
                   (rewrite_tac [mem_dword_def, mem_def] >> EVAL_TAC)) [(0x10002C000, h0), (0x10002C008, stk0), (0x10002C010, e0)];
val sepv = prove (``!v a:word64. v <+ 40w /\ 0x100000000w <=+ a /\ a <+ 0x100030F30w ==> 0x200000000w + v <> a``, blastLib.BBLAST_TAC);
val sep_sat = thm "sat_separation" ``!i (a:word64). i < 40 /\ 0x100000000w <=+ a /\ a <+ 0x100030F30w ==> 0x200000000w + n2w i <> a``
  (rpt gen_tac >> strip_tac >> match_mp_tac sepv >> asm_rewrite_tac [] >> simp [word_lo_n2w]);
val s0 = ``(ARB:arm8_state) with <| MEM := sat_mem; PC := 0x100004000w; PSTATE := (ARB with EL := 0w); exception := NoException;
            SCTLR_EL1 := (ARB with <| E0E := F; SA0 := F |>); TCR_EL1 := (ARB with <| TBI0 := F; TBI1 := F |>) |>``;
val fmem = prove (``(^s0).MEM = sat_mem``, simp []);
val sat = thm "refund_entry_pre_witness" ``refund_entry_pre ^s0 ^(w64 h0) ^(w64 stk0) ^(w64 e0)``
  (PURE_REWRITE_TAC [entry_def, fmem] >> rpt conj_tac >>
   FIRST (map ACCEPT_TAC (img_sat :: sep_sat :: slot) @ [EVAL_TAC >> NO_TAC, simp [] >> NO_TAC, show_tac "SAT"]));
val ex = thm "refund_entry_pre_satisfiable" ``?s h stk e. refund_entry_pre s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h``
  (map_every exists_tac [s0, w64 h0, w64 stk0, w64 e0] >> conj_tac >- ACCEPT_TAC sat >> EVAL_TAC);
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val closure = "forge_refundEntrySat" :: Theory.ancestry "forge_refundEntrySat";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

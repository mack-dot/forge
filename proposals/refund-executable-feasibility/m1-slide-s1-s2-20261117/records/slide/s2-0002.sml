(* U405: (E) the entry pre-state at a free slide gives the S1 pre-state: the file image at the relocated addresses supplies the
   108 linked code bytes; (D, plan step S2) the shifted memory domains, the no-wrap condition and their range forms.
   NOT modelled, NOT proved: the loader, dyld, the C run-time, that any real process has such a state. Slide-0 theorems are unchanged. *)
open preamble wordsLib blastLib alignmentTheory arm8Theory arm8_stepTheory targetSemTheory forge_refundArm8CompileTheory
     forge_refundCmlMainStepTheory forge_refundImageTheory forge_refundLoaderMemoryTheory forge_refundInstalledDomainsTheory
     forge_refundCmlMainSlideTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (300, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1800, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundSlideEntry";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
(* mk_thm is used ONLY to let later lemmas be explored after a failure; the run raises Fail before export if any lemma failed,
   and every stored theorem is tag-checked. *)
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; mk_thm ([], goal));
val code_tm = ``forge_refundArm8Compile$code``;
val comp = DB.fetch "forge_refundArm8Compile" "refund_arm8_compiled";
val len_code = valOf (List.find (fn th => is_eq (concl th) andalso aconv (lhs (concl th)) ``LENGTH ^code_tm``) (CONJUNCTS comp));
val _ = pr ("USED " ^ thm_to_string len_code);
fun img n = DB.fetch "forge_refundImage" n;
val image_def = img "refund_image_mem_def"; val img_code = img "refund_image_code"; val img_stub = img "refund_image_cml_main";
val pre_sl_def = DB.fetch "forge_refundCmlMainSlide" "cml_main_pre_sl_def";
val run_sl = DB.fetch "forge_refundCmlMainSlide" "cml_main_run_sl";
val old_entry_def = DB.fetch "forge_refundLoaderMemory" "refund_entry_pre_def";
val code_dm_def = DB.fetch "forge_refundInstalledDomains" "refund_code_dm_def";
val mem_dm_def = DB.fetch "forge_refundInstalledDomains" "refund_mem_dm_def";
val clear_def = DB.fetch "forge_refundInstalledDomains" "refund_heap_clear_def";
val bm_range = DB.fetch "forge_refundInstalledDomains" "refund_bitmaps_dm_range";
val _ = List.app (fn th => pr ("USED " ^ thm_to_string th)) [image_def, code_dm_def, mem_dm_def, clear_def, bm_range];
(* ---- 0. The two arm8_run constants are the same function. ---- *)
val run_new = ``forge_refundCmlMainSlide$arm8_run``; val run_old = ``forge_refundCmlMainStep$arm8_run``;
val rd_new = DB.fetch "forge_refundCmlMainSlide" "arm8_run_def"; val rd_old = DB.fetch "forge_refundCmlMainStep" "arm8_run_def";
val run_eq = thm "arm8_run_constants_agree" ``!n s. ^run_new n s = ^run_old n s``
  (Induct >> simp [rd_new, rd_old] >> gen_tac >> CASE_TAC >> simp []);
(* ---- 1. The slide. ---- *)
val slide_def = new_definition ("slide_ok_def", ``slide_ok (sl:word64) <=> aligned 12 sl /\ sl <=+ 0xFFFFFFFEFFFCF0CFw``);
val _ = pr ("DEFINITION " ^ thm_to_string slide_def);
val SL1 = thm "slide_ok_no_wrap" ``slide_ok sl ==> w2n sl + 0x100030F30 < 2 ** 64 /\ aligned 12 sl``
  (simp [slide_def, WORD_LS] >> strip_tac >> fs [] >> show_tac "SL1");
val SL2 = thm "slide_ok_examples"
  ``slide_ok 0w /\ slide_ok 0x4000w /\ slide_ok 0x2F8C000w /\ ~slide_ok 0x800w /\ ~slide_ok 4w /\ ~slide_ok 0xFFFFFFFEFFFF0000w /\
    aligned 12 (0xFFFFFFFEFFFF0000w:word64)``
  (simp [slide_def] >> EVAL_TAC);
(* ---- 2. Entry pre-state at a slide. 200496 = 0x30F30: the image range, in offset form. ---- *)
val sep_sl = ``!i j. i < 40 /\ j < 200496 ==> (h:word64) + n2w i <> 0x100000000w + sl + (n2w j : word64)``;
val entry_sl_def = new_definition ("refund_entry_pre_sl_def",
  ``refund_entry_pre_sl (sl:word64) (s:arm8_state) (h:word64) (stk:word64) (e:word64) <=>
     ~s.SCTLR_EL1.E0E /\ ~s.SCTLR_EL1.SA0 /\ ~s.TCR_EL1.TBI0 /\ ~s.TCR_EL1.TBI1 /\ s.PSTATE.EL = 0w /\ s.exception = NoException /\
     s.PC = sl + 0x100004000w /\ mem_dword s.MEM (sl + 0x10002C000w) = h /\ mem_dword s.MEM (sl + 0x10002C008w) = stk /\
     mem_dword s.MEM (sl + 0x10002C010w) = e /\ aligned 3 h /\ ^sep_sl /\ refund_image_mem sl s.MEM /\ slide_ok sl``);
val _ = pr ("DEFINITION " ^ thm_to_string entry_sl_def);
val _ = pr "MARK E";
val sep_weak = thm "entry_separation_covers_startup_range"
  ``^sep_sl ==> !i j. i < 40 /\ j < 163864 ==> (h:word64) + n2w i <> 0x100004000w + sl + (n2w j : word64)``
  (rpt strip_tac >> first_x_assum (qspecl_then [`i`, `j + 16384`] mp_tac) >> simp [GSYM word_add_n2w] >> show_tac "SEPW");
val E1 = thm "refund_entry_pre_sl_IMP_cml_main_pre_sl" ``refund_entry_pre_sl sl s h stk e ==> cml_main_pre_sl sl s h stk e``
  (rewrite_tac [entry_sl_def] >> strip_tac >> first_assum (assume_tac o MATCH_MP sep_weak) >> drule img_stub >>
   simp [bytes_in_memory_def] >> strip_tac >> `aligned 12 sl` by fs [slide_def] >>
   PURE_ONCE_REWRITE_TAC [pre_sl_def] >> rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >> show_tac "E1");
val (_, run_conc) = dest_imp (concl run_sl);
val run_conc_old = rhs (concl (QCONV (PURE_REWRITE_CONV [run_eq]) run_conc));
val E2 = thm "refund_entry_run_sl" (mk_imp (``refund_entry_pre_sl sl s h stk e``, run_conc_old))
  (strip_tac >> imp_res_tac E1 >> imp_res_tac run_sl >> fs [run_eq] >> metis_tac []);
val E3 = thm "refund_image_code_at_slide"
  ``refund_image_mem sl m ==> bytes_in_memory (0x1000040D0w + sl) ^code_tm m UNIV``
  (strip_tac >> imp_res_tac img_code);
val b0 = prove (``j < 200496 ==> 0x100000000w <=+ 0x100000000w + n2w j:word64 /\ 0x100000000w + n2w j <+ 0x100030F30w:word64``,
  strip_tac >> simp [word_add_n2w, word_ls_n2w, word_lo_n2w]);
val E4 = thm "slide_zero_entry_is_the_old_entry" ``refund_entry_pre s h stk e ==> refund_entry_pre_sl 0w s h stk e``
  (rewrite_tac [old_entry_def, entry_sl_def] >> strip_tac >> asm_simp_tac (srw_ss()) [] >> conj_tac
   >- (rpt strip_tac >> qpat_x_assum `!i a. _` (qspecl_then [`i`, `0x100000000w + n2w j`] mp_tac) >>
       imp_res_tac b0 >> asm_rewrite_tac [] >> fs [word_add_n2w] >> show_tac "E4")
   >- (simp [slide_def] >> EVAL_TAC));
(* ---- 3. Plan step S2: shifted domains. ---- *)
val _ = pr "MARK D";
val code_sl_def = new_definition ("refund_code_dm_sl_def", ``refund_code_dm_sl (sl:word64) = {a:word64 | a - sl IN refund_code_dm}``);
val bm_sl_def = new_definition ("refund_bitmaps_dm_sl_def", ``refund_bitmaps_dm_sl (sl:word64) = {a:word64 | a - sl IN refund_bitmaps_dm}``);
val mem_sl_def = new_definition ("refund_mem_dm_sl_def",
  ``refund_mem_dm_sl (sl:word64) (h:word64) (e:word64) = refund_code_dm_sl sl UNION {w | h <=+ w /\ w <+ e} UNION refund_bitmaps_dm_sl sl``);
val clear_sl_def = new_definition ("refund_heap_clear_sl_def",
  ``refund_heap_clear_sl (sl:word64) (h:word64) (e:word64) <=>
      !a. h <=+ a /\ a <+ e ==> ~(0x100000000w <=+ a - sl /\ a - sl <+ 0x100030F30w)``);
val _ = List.app (fn d => pr ("DEFINITION " ^ thm_to_string d)) [code_sl_def, bm_sl_def, mem_sl_def, clear_sl_def];
val shiftC = prove (``!sl a:word64. sl <=+ 0xFFFFFFFEFFFCF0CFw ==>
      (0x1000040D0w <=+ a - sl /\ a - sl <+ 0x100024000w <=> 0x1000040D0w + sl <=+ a /\ a <+ 0x100024000w + sl)``, rpt gen_tac >> blastLib.BBLAST_TAC);
val shiftI = prove (``!sl a:word64. sl <=+ 0xFFFFFFFEFFFCF0CFw ==>
      (0x100000000w <=+ a - sl /\ a - sl <+ 0x100030F30w <=> 0x100000000w + sl <=+ a /\ a <+ 0x100030F30w + sl)``, rpt gen_tac >> blastLib.BBLAST_TAC);
val _ = pr "MARK D1";
val D1 = thm "refund_code_dm_sl_range"
  ``slide_ok sl ==> !a. a IN refund_code_dm_sl sl <=> 0x1000040D0w + sl <=+ a /\ a <+ 0x100024000w + sl``
  (rw [slide_def, code_sl_def, code_dm_def] >> metis_tac [shiftC]);
val D2 = thm "refund_heap_clear_sl_range"
  ``slide_ok sl ==> (refund_heap_clear_sl sl h e <=> !a. h <=+ a /\ a <+ e ==> ~(0x100000000w + sl <=+ a /\ a <+ 0x100030F30w + sl))``
  (rw [slide_def, clear_sl_def] >> metis_tac [shiftI]);
val D3 = thm "refund_shifted_domains_disjoint" ``DISJOINT (refund_code_dm_sl sl) (refund_bitmaps_dm_sl sl)``
  (simp [DISJOINT_DEF, EXTENSION, code_sl_def, bm_sl_def, code_dm_def] >> gen_tac >> CCONTR_TAC >> fs [] >>
   imp_res_tac bm_range >> qpat_x_assum `_ <+ 0x100024000w` mp_tac >> qpat_x_assum `0x10002C018w <=+ _` mp_tac >>
   qspec_tac (`x - sl`, `v`) >> blastLib.BBLAST_TAC);
val D4 = thm "shifted_domains_at_slide_zero"
  ``refund_code_dm_sl 0w = refund_code_dm /\ refund_bitmaps_dm_sl 0w = refund_bitmaps_dm /\ refund_mem_dm_sl 0w h e = refund_mem_dm h e /\
    (refund_heap_clear_sl 0w h e <=> refund_heap_clear h e)``
  (simp [code_sl_def, bm_sl_def, mem_sl_def, clear_sl_def, mem_dm_def, clear_def, EXTENSION]);
val D5 = thm "relocated_code_addresses_in_shifted_domain"
  ``!i. i < LENGTH ^code_tm ==> 0x1000040D0w + sl + n2w i IN refund_code_dm_sl sl``
  (rw [len_code, code_sl_def, code_dm_def] >> simp [word_add_n2w, word_ls_n2w, word_lo_n2w] >> show_tac "D5");
val D6 = thm "shifted_heap_clear_keeps_heap_outside_code_and_bitmaps"
  ``refund_heap_clear_sl sl h e ==> !a. h <=+ a /\ a <+ e ==> a NOTIN refund_code_dm_sl sl /\ a NOTIN refund_bitmaps_dm_sl sl``
  (rw [clear_sl_def, code_sl_def, bm_sl_def, code_dm_def] >> first_x_assum drule_all >> strip_tac >> CCONTR_TAC >> fs [] >>
   imp_res_tac bm_range >> rpt (pop_assum mp_tac) >> qspec_tac (`a - sl`, `v`) >> blastLib.BBLAST_TAC);
(* ---- 4. Negative controls. ---- *)
val _ = pr "MARK K";
val K1 = thm "wrapping_slide_breaks_the_range_form"
  ``?sl a. aligned 12 sl /\ ~slide_ok sl /\ a IN refund_code_dm_sl sl /\ ~(0x1000040D0w + sl <=+ a /\ a <+ 0x100024000w + sl)``
  (qexistsl_tac [`0xFFFFFFFEFFFF0000w`, `0w`] >> simp [slide_def, code_sl_def, code_dm_def] >> EVAL_TAC);
val K2 = thm "nonzero_slide_moves_the_code_domain"
  ``0x1000080D0w IN refund_code_dm_sl 0x4000w /\ 0x1000040D0w NOTIN refund_code_dm_sl 0x4000w /\ 0x1000040D0w IN refund_code_dm``
  (simp [code_sl_def, code_dm_def] >> EVAL_TAC);
val K3 = thm "misaligned_or_wrapping_slide_not_covered"
  ``(~aligned 12 sl \/ 0xFFFFFFFEFFFCF0CFw <+ sl) ==> ~refund_entry_pre_sl sl s h stk e``
  (rw [entry_sl_def, slide_def] >> fs [WORD_NOT_LOWER_EQUAL]);
val K4 = thm "entry_fixes_image_and_pc_to_one_slide"
  ``refund_entry_pre_sl sl s h stk e ==> refund_image_mem sl s.MEM /\ s.PC = sl + 0x100004000w``
  (simp [entry_sl_def]);
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundSlideEntry" @ DB.definitions "forge_refundSlideEntry");
(* Preservation check: the slide-0 statement is untouched. *)
val _ = if aconv (concl (DB.fetch "forge_refundLoaderMemory" "refund_entry_pre_IMP_cml_main_pre")) ``refund_entry_pre s h stk e ==> cml_main_pre s h stk e``
        then pr "CONTROL_OK the U389 slide-0 entry theorem is loaded unchanged" else raise Fail "UNEXPECTED_CONTROL_ACCEPTANCE";
val closure = "forge_refundSlideEntry" :: Theory.ancestry "forge_refundSlideEntry";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundSlideEntry")));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = pr ("CLOSURE_HAS_COMPILE_CORRECT_CONTROL " ^ Bool.toString (Lib.mem "forge_compileCorrectControl" closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

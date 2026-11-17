(* U407, S3 part 3: the installed-state predicate at a free load slide sl.
   (a) 23 clauses of refund_installed_no_handler from refund_end_state_sl; the other 7 are the stored residual refund_installed_rest.
   (b) 5 of those 7 at the record refund_mc (sl + 0x1000040D0w) envmc; interference_ok and ffi_interfer_ok stay UNPROVED in the
       stored residual refund_installed_rest2.
   (c) both from the explicit entry pre-state refund_entry_pre_sl.
   The assembly is a forward kernel derivation from the stored definition. No loader, C run-time, processor or FFI-code model.
   No behaviour theorem is composed here (plan steps S4-S6 are not started). *)
open preamble backendTheory targetSemTheory targetPropsTheory asmPropsTheory asmSemTheory lab_to_targetTheory arm8_targetTheory alignmentTheory
     arm8_stepTheory set_sepTheory miscTheory backendProofTheory arm8_configProofTheory wordsLib blastLib forge_refundArm8CompileTheory
     forge_refundExclusionRealTheory forge_refundStartupClauseTheory forge_refundStartupBridgeTheory forge_loaderMemLemmasTheory
     forge_refundImageTheory forge_refundLoaderMemoryTheory forge_refundInstalledDomainsTheory forge_refundInstalledAssemblyTheory
     forge_refundFfiFactsTheory forge_refundResidualTheory forge_refundSlideEntryTheory forge_refundSlideDomainsTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (300, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1800, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundSlideInstalled";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
(* mk_thm is used ONLY to let later lemmas be explored after a failure; the run raises Fail before export if any lemma failed,
   and every stored theorem is tag-checked. *)
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; mk_thm ([], goal));
fun has_sub nms tm = can (find_term (fn x => is_const x andalso List.exists (fn n => String.isSubstring n (fst (dest_const x))) nms)) tm;
val code_tm = ``forge_refundArm8Compile$code``; val data_tm = ``forge_refundArm8Compile$data``;
val comp = DB.fetch "forge_refundArm8Compile" "refund_arm8_compiled";
fun len_of c = valOf (List.find (fn th => is_eq (concl th) andalso aconv (lhs (concl th)) ``LENGTH ^c``) (CONJUNCTS comp));
val len_code = len_of code_tm; val len_data = len_of data_tm;
val ba64 = prove (``byte_aligned (a:word64) <=> aligned 3 a``, simp [byte_aligned_def] >> EVAL_TAC);
val biw = prove (``bytes_in_word = 8w:word64``, EVAL_TAC);
fun SD n = DB.fetch "forge_refundSlideDomains" n;
fun SE n = DB.fetch "forge_refundSlideEntry" n;
val [slide_def, code_sl_def, bm_sl_def, mem_sl_def, clear_sl_def] = map SE ["slide_ok_def", "refund_code_dm_sl_def", "refund_bitmaps_dm_sl_def",
     "refund_mem_dm_sl_def", "refund_heap_clear_sl_def"];
val [t_sl_def, end_sl_def] = map SD ["refund_t_sl_def", "refund_end_state_sl_def"];
val [SLA, C3, C4, C7, C8, C9, C10, C11, C12, T_end] = map SD ["slide_ok_alignment_facts", "refund_heap_bitmaps_closed_sl",
   "refund_heap_bitmaps_disjoint_sl", "refund_code_bytes_in_mem_sl", "refund_code_buffer_in_dm_sl", "refund_heap_bitmaps_subset_sl",
   "refund_t_sl_target_state_rel", "refund_t_sl_target_configured", "refund_code_loaded_sl", "refund_end_state_sl_established"];
val bm_clause = BETA_RULE (SD "refund_image_bitmap_clause_sl");
val code_dm_def = DB.fetch "forge_refundInstalledDomains" "refund_code_dm_def";
val C1 = DB.fetch "forge_refundInstalledDomains" "refund_bitmaps_dm_range";
val arm8_tgt = prove (``is_arm8_machine_config mc0 ==> mc0.target = arm8_target``, simp [is_arm8_machine_config_def]);
val tgt_pc = prove (``arm8_target.get_pc (ms:arm8_state) = ms.PC``, simp [arm8_target_def]);
val tgt_be = prove (``arm8_target.config.big_endian = F``, simp [arm8_target_def, arm8_config_def]);
(* ---- 1. The stored predicate, instantiated with explicit witnesses at the slide. ---- *)
val _ = pr "MARK 1";
val weak_def = DB.fetch "forge_refundExclusionReal" "refund_installed_no_handler_def";
val (wl, wr) = dest_eq (snd (strip_forall (concl weak_def)));
val [mc0, ms, cbspace, data_sp] = snd (strip_comb wl);
val (evs, body) = strip_exists wr;
val _ = if map (fst o dest_var) evs = ["t", "m", "bitmap_ptr", "bitmaps_dm", "sdm"] then () else raise Fail "unexpected witnesses";
val H = ``(^ms).REG 1w``; val E = ``(^ms).REG 3w``;
val mwit = ``\a:word64. (Word (mem_dword (^ms).MEM a)) : 64 word_loc``;
val wit = [``refund_t_sl sl ^ms``, mwit, ``sl + 0x10002C018w:word64``, ``refund_bitmaps_dm_sl sl``, ``(^mc0).shared_addresses``];
val _ = List.app (fn w => pr ("WITNESS " ^ term_to_string w)) wit;
val nums = [cbspace |-> ``428:num``, data_sp |-> ``0:num``];
val bodyI = subst nums body;
val body_i = subst (ListPair.map (op |->) (evs, wit)) bodyI;
val tt = ``refund_t_sl sl ^ms``;
val sels = map (fn q => SIMP_CONV (srw_ss()) [t_sl_def] q) [``(^tt).regs 1``, ``(^tt).regs 3``, ``(^tt).pc``, ``(^tt).mem``, ``(^tt).mem_domain``, ``(^tt).align``];
val _ = List.app (fn th => pr ("SELECTOR " ^ thm_to_string th)) sels;
val norm = (SIMP_CONV bool_ss [LET_THM] THENC PURE_REWRITE_CONV sels) body_i;
val cs = strip_conj (rhs (concl norm));
val _ = pr ("CLAUSES " ^ Int.toString (length cs));
val _ = if length cs = 30 then () else raise Fail "expected 30 clauses";
val rest_names = ["start_pc_ok", "interference_ok", "ffi_interfer_ok", "shared_addresses", "ffi_names", "mmio_pcs_min_index"];
fun is_rest c = has_sub rest_names c;
val a1 = ``is_arm8_machine_config ^mc0``; val a2 = ``(^mc0).prog_addresses = refund_mem_dm_sl sl ^H ^E``; val a3 = ``refund_end_state_sl sl ^ms``;
val A = list_mk_conj [a1, a2, a3];
val insts = [Q.INST [`h` |-> `(^ms).REG 1w`, `e` |-> `(^ms).REG 3w`] C3, Q.INST [`h` |-> `(^ms).REG 1w`, `e` |-> `(^ms).REG 3w`] C4,
             SPECL [``(^ms).MEM``, H, E] C7, SPECL [H, E] C8, SPECL [H, E] C9, SPEC ms C10, SPECL [ms, mc0] C11, SPECL [ms, mc0] C12,
             SPEC ``(^ms).MEM`` bm_clause];
val gbi = BETA_RULE (Q.SPEC `(^ms).MEM` mem_dword_word_memory_clause);
val PRE = strip_tac >> first_assum (assume_tac o MATCH_MP arm8_tgt) >>
          first_assum (fn th => if has_sub ["refund_end_state_sl"] (concl th) then strip_assume_tac (REWRITE_RULE [end_sl_def] th) else NO_TAC) >>
          drule SLA >> strip_tac >>
          asm_rewrite_tac [tgt_pc, tgt_be, len_code, len_data, biw];
val CLOSE = FIRST ([ACCEPT_TAC TRUTH, first_assum ACCEPT_TAC, MATCH_ACCEPT_TAC gbi] @
                   map (fn th => mp_tac th >> asm_rewrite_tac [tgt_pc, tgt_be, len_code, len_data, biw] >> NO_TAC) insts @
                   [CONV_TAC (LAND_CONV EVAL) >> first_assum ACCEPT_TAC] @
                   [asm_rewrite_tac [ba64] >> NO_TAC, rewrite_tac [ba64] >> EVAL_TAC >> NO_TAC, EVAL_TAC >> NO_TAC,
                    asm_simp_tac (srw_ss()) [ba64] >> NO_TAC]);
val count = ref 0;
fun prove_clause c = (count := !count + 1;
  let val th = Tactical.TAC_PROOF (([], mk_imp (A, c)), PRE >> CLOSE)
  in pr ("CLAUSE_PROVED " ^ Int.toString (!count) ^ " " ^ String.substring (term_to_string c, 0, Int.min (150, size (term_to_string c)))); SOME th end
  handle e => (pr ("CLAUSE_FAILED " ^ Int.toString (!count)); ignore (Tactical.TAC_PROOF (([], mk_imp (A, c)), PRE >> show_tac "CLAUSE") handle _ => TRUTH);
               failed := ("clause-" ^ Int.toString (!count)) :: !failed; NONE));
val classed = map (fn c => if is_rest c then (count := !count + 1;
        pr ("CLAUSE_RESIDUAL " ^ Int.toString (!count) ^ " " ^ String.substring (term_to_string c, 0, Int.min (150, size (term_to_string c)))); (c, NONE))
      else (c, prove_clause c)) cs;
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val rest_cs = map fst (List.filter (fn (c, p) => is_rest c) classed);
val _ = pr ("RESIDUAL_CLAUSES " ^ Int.toString (length rest_cs) ^ " PROVED_CLAUSES " ^ Int.toString (length cs - length rest_cs));
(* The residual at a slide is the stored slide-0 residual, term for term: it does not mention the witnesses. *)
val rest_def = DB.fetch "forge_refundInstalledAssembly" "refund_installed_rest_def";
val rest_at = SPECL [mc0, ms] rest_def;
val rest_tm = lhs (concl rest_at);
val _ = if aconv (rhs (concl rest_at)) (list_mk_conj rest_cs) then pr "RESIDUAL_IDENTICAL_TO_STORED true" else raise Fail "residual differs from the stored one";
(* ---- 2. Forward assembly. ---- *)
val A_th = LIST_CONJ (map ASSUME [a1, a2, a3]);
val rest_ths = CONJUNCTS (EQ_MP rest_at (ASSUME rest_tm));
val clause_ths = map (fn (c, p) => case p of SOME th => MP th A_th | NONE => valOf (List.find (fn r => aconv (concl r) c) rest_ths)) classed;
val bodyN = Tactical.TAC_PROOF (([a1, a2, a3, rest_tm], rhs (concl norm)), rpt conj_tac >> FIRST (map ACCEPT_TAC clause_ths));
val body_th = EQ_MP (SYM norm) bodyN;
fun ex k th = if k < 0 then th else
  let val tm = list_mk_exists (List.drop (evs, k), subst (ListPair.map (op |->) (List.take (evs, k), List.take (wit, k))) bodyI)
  in ex (k - 1) (EXISTS (tm, List.nth (wit, k)) th) end;
val ex_th = ex 4 body_th;
val inst_th = EQ_MP (SYM (SPECL [mc0, ms, ``428:num``, ``0:num``] weak_def)) ex_th;
val asm_th = save_thm ("refund_installed_from_end_state_sl",
   REWRITE_RULE [AND_IMP_INTRO, GSYM CONJ_ASSOC] (DISCH a1 (DISCH a2 (DISCH a3 (DISCH rest_tm inst_th)))));
val _ = chk "refund_installed_from_end_state_sl" asm_th;
(* ---- 3. Five residual clauses at the relocated record. ---- *)
val _ = pr "MARK 3";
val mc_def = DB.fetch "forge_refundStartupBridge" "refund_mc_def";
val mc_is = DB.fetch "forge_refundStartupBridge" "refund_mc_is_arm8";
val mc_fields = DB.fetch "forge_refundStartupBridge" "refund_mc_fields";
val fix_def = DB.fetch "forge_refundStartupClause" "arm8_fix_def";
val names_thm = DB.fetch "forge_refundFfiFacts" "refund_ffi_names";
val rest2_def = DB.fetch "forge_refundResidual" "refund_installed_rest2_def";
val B = ``sl + 0x1000040D0w:word64``;
val envmc = mk_var ("envmc", type_of mc0);
val RMC = ``refund_mc ^B ^envmc``;
val genl4 = EVAL ``GENLIST (f:num -> word64) 4``;
val FLD = thm "refund_mc_concrete_fields_sl"
  ``!names. refund_lab_conf2.ffi_names = SOME names /\ LENGTH names = 4 ==>
      (^RMC).ffi_names = names /\
      (^RMC).ffi_entry_pcs = [sl + 0x1000040A0w; sl + 0x100004090w; sl + 0x100004080w; sl + 0x100004070w] /\
      (^RMC).halt_pc = sl + 0x1000040C0w /\ (^RMC).install_pc = sl + 0x1000040B0w /\ (^RMC).mmio_info = [] /\ (^RMC).shared_addresses = {} /\
      (^RMC).prog_addresses = (^envmc).prog_addresses /\ (^RMC).target = arm8_target``
  (rpt strip_tac >> asm_simp_tac (srw_ss()) [mc_def, fix_def, ffi_offset_def, genl4] >> TRY (EVAL_TAC >> NO_TAC) >> show_tac "FLD");
val hl = prove (``!a:word64. a <+ 0x1000040D0w ==> ~(0x1000040D0w <=+ a) /\ a <+ 0x100030F30w /\ ~(0x10002C018w <=+ a)``, blastLib.BBLAST_TAC);
val wsub0 = prove (``!sl c:word64. sl + c - sl = c``, blastLib.BBLAST_TAC);
val stub_out = thm "refund_stub_outside_domain_sl"
  ``!a h e. refund_heap_clear_sl sl h e /\ 0x100000000w <=+ a - sl /\ a - sl <+ 0x1000040D0w ==> a NOTIN refund_mem_dm_sl sl h e``
  (rewrite_tac [clear_sl_def] >> rpt gen_tac >> strip_tac >> first_assum (strip_assume_tac o MATCH_MP hl) >>
   rewrite_tac [mem_sl_def, code_sl_def, bm_sl_def, code_dm_def, IN_UNION] >> CONV_TAC (DEPTH_CONV pred_setLib.SET_SPEC_CONV) >>
   metis_tac [C1]);
val pc1 = prove (``slide_ok sl ==> (1w && (sl + 0x1000040D0w) = 0w)``, rewrite_tac [slide_def, aligned_bitwise_and] >> blastLib.BBLAST_TAC);
val (rl, rr) = dest_eq (snd (strip_forall (concl rest_def)));
val [mc0r, msr] = snd (strip_comb rl);
val rcs = strip_conj rr;
val _ = if length rcs = 7 then () else raise Fail "expected seven residual clauses";
fun kept c = has_sub ["interference_ok", "ffi_interfer_ok"] c;
val A2 = ``refund_heap_clear_sl sl h e /\ (^envmc).prog_addresses = refund_mem_dm_sl sl h e /\ (^msr).PC = ^B /\ slide_ok sl``;
val stubs = [``sl + 0x1000040C0w:word64``, ``sl + 0x1000040B0w:word64``, ``sl + 0x1000040A0w:word64``, ``sl + 0x100004090w:word64``,
             ``sl + 0x100004080w:word64``, ``sl + 0x100004070w:word64``];
fun stub_fact a = (SUBGOAL_THEN ``^a NOTIN refund_mem_dm_sl sl h e`` assume_tac) >- (match_mp_tac stub_out >> asm_rewrite_tac [wsub0] >> EVAL_TAC);
val PRE2 = strip_tac >> strip_assume_tac names_thm >> mp_tac (SPEC ``names:ffiname list`` FLD) >>
          (impl_tac >- asm_rewrite_tac []) >> strip_tac >> EVERY (map stub_fact stubs) >> drule pc1 >> strip_tac >>
          asm_simp_tac (srw_ss()) [start_pc_ok_def, ffi_offset_def, len_code, tgt_pc];
val TAIL = TRY (conj_tac
   >- (gen_tac >> strip_tac >> `index = 0 \/ index = 1 \/ index = 2 \/ index = 3` by decide_tac >>
       asm_simp_tac (srw_ss()) [find_index_def] >> TRY (EVAL_TAC >> NO_TAC))
   >- (rpt gen_tac >> strip_tac >> fs []));
val count2 = ref 0;
val inst_cs = map (subst [mc0r |-> RMC]) rcs;
fun prove_clause2 c = (count2 := !count2 + 1;
  let val th = Tactical.TAC_PROOF (([], mk_imp (A2, c)), PRE2 >> TAIL)
  in pr ("CLAUSE2_PROVED " ^ Int.toString (!count2) ^ " " ^ String.substring (term_to_string c, 0, Int.min (160, size (term_to_string c)))); SOME th end
  handle e => (pr ("CLAUSE2_FAILED " ^ Int.toString (!count2) ^ " " ^ term_to_string c);
               ignore (Tactical.TAC_PROOF (([], mk_imp (A2, c)), PRE2 >> TAIL >> show_tac "CLAUSE2") handle _ => TRUTH);
               failed := ("clause2-" ^ Int.toString (!count2)) :: !failed; NONE));
val classed2 = map (fn c => if kept c then (count2 := !count2 + 1;
     pr ("CLAUSE2_KEPT_UNPROVED " ^ Int.toString (!count2) ^ " " ^ String.substring (term_to_string c, 0, Int.min (160, size (term_to_string c)))); (c, NONE))
   else (c, prove_clause2 c)) inst_cs;
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val rest2_tm = ``refund_installed_rest2 ^RMC ^msr``;
val A2_th = LIST_CONJ (map ASSUME (strip_conj A2));
val kept_ths = CONJUNCTS (EQ_MP (SPECL [RMC, msr] rest2_def) (ASSUME rest2_tm));
val clause2_ths = map (fn (c, p) => case p of SOME th => MP th A2_th | NONE => valOf (List.find (fn r => aconv (concl r) c) kept_ths)) classed2;
val rest_body = Tactical.TAC_PROOF ((strip_conj A2 @ [rest2_tm], list_mk_conj inst_cs), rpt conj_tac >> FIRST (map ACCEPT_TAC clause2_ths));
val rest_th = EQ_MP (SYM (SPECL [RMC, msr] rest_def)) rest_body;
val reduced = save_thm ("refund_installed_rest_reduced_sl",
   REWRITE_RULE [AND_IMP_INTRO, GSYM CONJ_ASSOC] (List.foldr (fn (a, th) => DISCH a th) rest_th (strip_conj A2 @ [rest2_tm])));
val _ = chk "refund_installed_rest_reduced_sl" reduced;
(* ---- 4. From the entry pre-state at a slide. ---- *)
val _ = pr "MARK 4";
val pre = ``refund_entry_pre_sl sl s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h /\ refund_heap_clear_sl sl h e /\
            (^envmc).prog_addresses = refund_mem_dm_sl sl h e``;
val T1 = thm "refund_installed_from_entry_reduced_sl"
  ``^pre ==> ?ms. forge_refundCmlMainStep$arm8_run 27 s = SOME ms /\ ms.PC = ^B /\
       (refund_installed_rest2 ^RMC ms ==> refund_installed_no_handler ^RMC ms 428 0)``
  (strip_tac >> mp_tac T_end >> (impl_tac >- asm_rewrite_tac []) >> disch_then (qx_choose_then `ms` strip_assume_tac) >>
   first_assum (fn th => if has_sub ["refund_end_state_sl"] (concl th) then strip_assume_tac (REWRITE_RULE [end_sl_def] th) else NO_TAC) >>
   qexists_tac `ms` >> conj_tac >- first_assum ACCEPT_TAC >> conj_tac >- first_assum ACCEPT_TAC >> strip_tac >>
   SUBGOAL_THEN ``refund_installed_rest ^RMC ^msr`` assume_tac >- (mp_tac reduced >> asm_rewrite_tac []) >>
   match_mp_tac asm_th >> asm_rewrite_tac [mc_is, mc_fields] >> show_tac "T1");
(* ---- 5. Negative controls. ---- *)
val _ = pr "MARK 5";
val n1 = DB.fetch "forge_refundResidual" "wrong_base0_rejected";
val n2 = DB.fetch "forge_refundResidual" "halt_stub_in_domain_rejected";
val n3 = DB.fetch "forge_refundInstalledAssembly" "code_outside_domain_rejected";
val _ = List.app (fn th => pr ("USED " ^ thm_to_string th)) [n1, n2, n3];
val ne0 = prove (``!sl:word64. sl <> 0w ==> 0x1000040D0w <> sl + 0x1000040D0w``, blastLib.BBLAST_TAC);
val K1 = thm "unrelocated_record_rejected_at_nonzero_slide"
  ``sl <> 0w ==> ~start_pc_ok (refund_mc 0x1000040D0w ^envmc) ^B``
  (strip_tac >> match_mp_tac n1 >> match_mp_tac ne0 >> first_assum ACCEPT_TAC);
val K2 = thm "heap_on_relocated_halt_stub_rejected"
  ``h <=+ sl + 0x1000040C0w /\ sl + 0x1000040C0w <+ e /\ (^envmc).prog_addresses = refund_mem_dm_sl sl h e ==> ~start_pc_ok ^RMC ^B``
  (strip_tac >> match_mp_tac n2 >> asm_simp_tac (srw_ss()) [mem_sl_def, ffi_offset_def] >> show_tac "K2");
val K3 = thm "code_start_outside_domain_rejected_sl"
  ``!m md k. sl + 0x1000040D0w NOTIN md ==> ~bytes_in_mem (sl + 0x1000040D0w) ^code_tm m md k``
  (metis_tac [n3, WORD_ADD_0, len_code, DECIDE ``0 < 130436n``] ORELSE
   (rpt gen_tac >> strip_tac >> match_mp_tac n3 >> qexists_tac `0` >> asm_rewrite_tac [len_code, WORD_ADD_0] >> EVAL_TAC));
val K4 = thm "prog_addresses_mismatch_rejected_sl"
  ``!ms mc0. mc0.prog_addresses <> (refund_t_sl sl ms).mem_domain ==> ~target_configured (refund_t_sl sl ms) mc0``
  (simp [target_configured_def] >> metis_tac []);
val K5 = thm "slide_zero_domain_misses_relocated_code"
  ``0x1000380D0w NOTIN refund_code_dm /\ 0x1000380D0w IN refund_code_dm_sl 0x24000w /\ slide_ok 0x24000w``
  (rewrite_tac [code_sl_def, code_dm_def, slide_def] >> CONV_TAC (DEPTH_CONV pred_setLib.SET_SPEC_CONV) >> EVAL_TAC);
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundSlideInstalled" @ DB.definitions "forge_refundSlideInstalled");
(* Preservation: the slide-0 theorems of U390/U391 and the published compiler theorem are loaded unchanged. *)
val _ = if aconv (concl (DB.fetch "forge_refundResidual" "refund_installed_from_entry_reduced"))
     ``refund_entry_pre s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h /\ refund_heap_clear h e /\
       (^envmc).prog_addresses = refund_mem_dm h e ==>
       ?ms. forge_refundCmlMainStep$arm8_run 27 s = SOME ms /\ ms.PC = 0x1000040D0w /\
         (refund_installed_rest2 (refund_mc 0x1000040D0w ^envmc) ms ==> refund_installed_no_handler (refund_mc 0x1000040D0w ^envmc) ms 428 0)``
        then pr "CONTROL_OK the U391 slide-0 theorem is loaded unchanged" else raise Fail "UNEXPECTED_CONTROL_ACCEPTANCE";
val cc = DB.fetch "backendProof" "compile_correct'";
val _ = (tags "compile_correct'" cc; pr ("PUBLISHED compile_correct' loaded, tag clean, " ^ Int.toString (size (thm_to_string cc)) ^ " characters"));
val closure = "forge_refundSlideInstalled" :: Theory.ancestry "forge_refundSlideInstalled";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundSlideInstalled")));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = pr ("CLOSURE_HAS_COMPILE_CORRECT_CONTROL " ^ Bool.toString (Lib.mem "forge_compileCorrectControl" closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

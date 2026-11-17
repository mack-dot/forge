(* U390: conditional assembly of refund_installed_no_handler for the end state of the 27 cml_main steps (slide 0).
   Every clause that is not proved is collected, unchanged, in the explicit residual premise refund_installed_rest.
   The assembly is a forward kernel derivation from the stored definition. Negative controls. No loader or slide model. *)
open preamble backendTheory targetSemTheory targetPropsTheory asmPropsTheory asmSemTheory arm8_targetTheory alignmentTheory arm8_stepTheory
     set_sepTheory miscTheory backendProofTheory arm8_configProofTheory forge_refundArm8CompileTheory forge_refundExclusionRealTheory
     forge_refundStartupClauseTheory forge_refundCmlMainStepTheory forge_refundCmlMainFrameTheory forge_refundStartupBridgeTheory
     forge_loaderMemLemmasTheory forge_refundImageTheory forge_refundLoaderMemoryTheory forge_refundEntrySatTheory forge_refundInstalledDomainsTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (300, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundInstalledAssembly";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
fun has_const nm tm = can (find_term (fn x => is_const x andalso fst (dest_const x) = nm)) tm;
val code_tm = ``forge_refundArm8Compile$code``; val data_tm = ``forge_refundArm8Compile$data``;
val comp = DB.fetch "forge_refundArm8Compile" "refund_arm8_compiled";
fun len_of c = valOf (List.find (fn th => is_eq (concl th) andalso aconv (lhs (concl th)) ``LENGTH ^c``) (CONJUNCTS comp));
val len_code = len_of code_tm; val len_data = len_of data_tm;
val img_code = DB.fetch "forge_refundImage" "refund_image_code";
val dm_def = DB.fetch "forge_refundLoaderMemory" "refund_bitmaps_dm_def";
val dm_closed = DB.fetch "forge_refundLoaderMemory" "refund_bitmaps_dm_closed";
val bm_clause = BETA_RULE (DB.fetch "forge_refundLoaderMemory" "refund_image_bitmap_clause");
val cl = DB.fetch "forge_refundLoaderMemory" "code_loaded_from_memory";
val entry_def = DB.fetch "forge_refundLoaderMemory" "refund_entry_pre_def";
val main389 = DB.fetch "forge_refundLoaderMemory" "refund_loader_startup";
val runf = DB.fetch "forge_refundCmlMainFrame" "cml_main_run_frame";
val entry_pre = DB.fetch "forge_refundLoaderMemory" "refund_entry_pre_IMP_cml_main_pre";
val ba64 = prove (``byte_aligned (a:word64) <=> aligned 3 a``, simp [byte_aligned_def] >> EVAL_TAC);
val biw = prove (``bytes_in_word = 8w:word64``, EVAL_TAC);
fun D n = DB.fetch "forge_refundInstalledDomains" n;
val [code_dm_def, mem_dm_def, clear_def, t_def, end_def] = map D ["refund_code_dm_def", "refund_mem_dm_def", "refund_heap_clear_def", "refund_t_def", "refund_end_state_def"];
val [C3, C4, C7, C8, C9, C10, C11, C12, T_end] = map D ["refund_heap_bitmaps_closed", "refund_heap_bitmaps_disjoint", "refund_code_bytes_in_mem",
   "refund_code_buffer_in_dm", "refund_heap_bitmaps_subset", "refund_t_target_state_rel", "refund_t_target_configured", "refund_code_loaded",
   "refund_end_state_established"];
val arm8_tgt = prove (``is_arm8_machine_config mc0 ==> mc0.target = arm8_target``, simp [is_arm8_machine_config_def]);
val tgt_pc = prove (``arm8_target.get_pc (ms:arm8_state) = ms.PC``, simp [arm8_target_def]);
val tgt_be = prove (``arm8_target.config.big_endian = F``, simp [arm8_target_def, arm8_config_def]);
(* ---- 1. The stored predicate, instantiated with explicit witnesses. ---- *)
val weak_def = DB.fetch "forge_refundExclusionReal" "refund_installed_no_handler_def";
val (wl, wr) = dest_eq (snd (strip_forall (concl weak_def)));
val [mc0, ms, cbspace, data_sp] = snd (strip_comb wl);
val (evs, body) = strip_exists wr;
val _ = if map (fst o dest_var) evs = ["t", "m", "bitmap_ptr", "bitmaps_dm", "sdm"] then () else raise Fail "unexpected witnesses";
val H = ``(^ms).REG 1w``; val E = ``(^ms).REG 3w``;
val mwit = ``\a:word64. (Word (mem_dword (^ms).MEM a)) : 64 word_loc``;
val wit = [``refund_t ^ms``, mwit, ``0x10002C018w:word64``, ``refund_bitmaps_dm``, ``(^mc0).shared_addresses``];
val nums = [cbspace |-> ``428:num``, data_sp |-> ``0:num``];
val bodyI = subst nums body;
val body_i = subst (ListPair.map (op |->) (evs, wit)) bodyI;
val tt = ``refund_t ^ms``;
val sels = map (fn q => SIMP_CONV (srw_ss()) [t_def] q) [``(^tt).regs 1``, ``(^tt).regs 3``, ``(^tt).pc``, ``(^tt).mem``, ``(^tt).mem_domain``, ``(^tt).align``];
val _ = List.app (fn th => pr ("SELECTOR " ^ thm_to_string th)) sels;
val norm = (SIMP_CONV bool_ss [LET_THM] THENC PURE_REWRITE_CONV sels) body_i;
val cs = strip_conj (rhs (concl norm));
val _ = pr ("CLAUSES " ^ Int.toString (length cs));
val rest_names = ["start_pc_ok", "interference_ok", "ffi_interfer_ok", "shared_addresses", "ffi_names", "mmio_pcs_min_index"];
fun is_rest c = List.exists (fn n => has_const n c) rest_names;
val a1 = ``is_arm8_machine_config ^mc0``; val a2 = ``(^mc0).prog_addresses = refund_mem_dm ^H ^E``; val a3 = ``refund_end_state ^ms``;
val A = list_mk_conj [a1, a2, a3];
val insts = [Q.INST [`h` |-> `(^ms).REG 1w`, `e` |-> `(^ms).REG 3w`] C3, Q.INST [`h` |-> `(^ms).REG 1w`, `e` |-> `(^ms).REG 3w`] C4,
             SPECL [``(^ms).MEM``, H, E] C7, SPECL [H, E] C8, SPECL [H, E] C9, SPEC ms C10, SPECL [ms, mc0] C11, SPECL [ms, mc0] C12,
             SPEC ``(^ms).MEM`` bm_clause];
val gbi = BETA_RULE (Q.SPEC `(^ms).MEM` mem_dword_word_memory_clause);
val PRE = strip_tac >> first_assum (assume_tac o MATCH_MP arm8_tgt) >>
          first_assum (fn th => if has_const "refund_end_state" (concl th) then strip_assume_tac (REWRITE_RULE [end_def] th) else NO_TAC) >>
          asm_rewrite_tac [tgt_pc, tgt_be, len_code, len_data, biw];
val CLOSE = FIRST ([ACCEPT_TAC TRUTH, first_assum ACCEPT_TAC, MATCH_ACCEPT_TAC gbi] @
                   map (fn th => mp_tac th >> asm_rewrite_tac [] >> NO_TAC) insts @
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
val rest_c = mk_var ("refund_installed_rest", type_of mc0 --> type_of ms --> bool);
val rest_def = new_definition ("refund_installed_rest_def", mk_eq (list_mk_comb (rest_c, [mc0, ms]), list_mk_conj rest_cs));
val _ = pr ("DEFINITION " ^ thm_to_string rest_def);
val rest_tm = lhs (snd (strip_forall (concl rest_def)));
(* ---- 2. Forward assembly. ---- *)
val A_th = LIST_CONJ (map ASSUME [a1, a2, a3]);
val rest_ths = CONJUNCTS (EQ_MP (SPEC_ALL rest_def) (ASSUME rest_tm));
val clause_ths = map (fn (c, p) => case p of SOME th => MP th A_th | NONE => valOf (List.find (fn r => aconv (concl r) c) rest_ths)) classed;
val bodyN = Tactical.TAC_PROOF (([a1, a2, a3, rest_tm], rhs (concl norm)), rpt conj_tac >> FIRST (map ACCEPT_TAC clause_ths));
val body_th = EQ_MP (SYM norm) bodyN;
fun ex k th = if k < 0 then th else
  let val tm = list_mk_exists (List.drop (evs, k), subst (ListPair.map (op |->) (List.take (evs, k), List.take (wit, k))) bodyI)
  in ex (k - 1) (EXISTS (tm, List.nth (wit, k)) th) end;
val ex_th = ex 4 body_th;
val inst_th = EQ_MP (SYM (SPECL [mc0, ms, ``428:num``, ``0:num``] weak_def)) ex_th;
val asm_th = save_thm ("refund_installed_from_end_state",
   REWRITE_RULE [AND_IMP_INTRO, GSYM CONJ_ASSOC] (DISCH a1 (DISCH a2 (DISCH a3 (DISCH rest_tm inst_th)))));
val _ = chk "refund_installed_from_end_state" asm_th;
(* ---- 3. From the entry pre-state; composition with the stored final theorems at refund_mc. ---- *)
val T1 = thm "refund_installed_from_entry"
  ``refund_entry_pre s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h /\ refund_heap_clear h e ==>
    ?ms. arm8_run 27 s = SOME ms /\
         !mc0. is_arm8_machine_config mc0 /\ mc0.prog_addresses = refund_mem_dm h e /\ refund_installed_rest mc0 ms ==>
               refund_installed_no_handler mc0 ms 428 0``
  (strip_tac >> mp_tac T_end >> impl_tac >- asm_rewrite_tac [] >> disch_then (qx_choose_then `ms` strip_assume_tac) >>
   qexists_tac `ms` >> asm_rewrite_tac [] >> rpt strip_tac >> match_mp_tac asm_th >> asm_rewrite_tac []);
val mc_is = DB.fetch "forge_refundStartupBridge" "refund_mc_is_arm8";
val mc_fields = DB.fetch "forge_refundStartupBridge" "refund_mc_fields";
fun compose src new =
  let val th = DB.fetch "forge_refundStartupBridge" src
      val fv = fn n => valOf (List.find (fn v => fst (dest_var v) = n) (free_vars (concl th)))
      val th_i = INST [fv "cbspace" |-> ``428:num``, fv "data_sp" |-> ``0:num``] th
      val (ant, c) = dest_imp (concl th_i)
      val (weak :: inputs) = strip_conj ant
      val rmc = el 1 (snd (strip_comb weak)); val msv = el 2 (snd (strip_comb weak))
      val envmc = el 2 (snd (strip_comb rmc))
      val goal = mk_imp (list_mk_conj ([``refund_entry_pre s h stk e``, ``aligned 3 (e:word64)``, ``(h:word64) <=+ e``, ``8192w <=+ (e:word64) - h``,
                    ``refund_heap_clear h e``, ``(^envmc).prog_addresses = refund_mem_dm h e``] @ inputs),
                 mk_exists (msv, mk_conj (``arm8_run 27 s = SOME ^msv``, mk_imp (``refund_installed_rest ^rmc ^msv``, c))))
  in thm new goal
     (strip_tac >> mp_tac T1 >> impl_tac >- asm_rewrite_tac [] >> disch_then (qx_choose_then `ms` strip_assume_tac) >>
      qexists_tac `ms` >> asm_rewrite_tac [] >> strip_tac >> match_mp_tac th_i >> asm_rewrite_tac [] >>
      first_x_assum match_mp_tac >> asm_rewrite_tac [mc_is, mc_fields]) end;
val B1 = compose "refund_mc_behavior_stdin_no_handler" "refund_behavior_from_entry";
val B2 = compose "refund_mc_u298_exclusion_stdin" "refund_u298_exclusion_from_entry";
(* ---- 4. Negative controls and non-vacuity of the premises. ---- *)
val ovl = DB.fetch "forge_refundLoaderMemory" "code_overlap_rejected";
val n1 = thm "heap_on_code_rejected"
  ``h <=+ 0x1000040D0w /\ 0x1000040D0w <+ e ==> ~refund_heap_clear h e /\
    !m md. ~bytes_in_mem 0x1000040D0w ^code_tm m md ({w | h <=+ w /\ w <+ e} UNION refund_bitmaps_dm)``
  (strip_tac >> conj_tac
   >- (simp [clear_def] >> qexists_tac `0x1000040D0w` >> asm_rewrite_tac [] >> EVAL_TAC)
   >- (rpt gen_tac >> mp_tac (Q.SPECL [`0`, `0x1000040D0w`, `m`, `md`, `{w | h <=+ w /\ w <+ e} UNION refund_bitmaps_dm`] ovl) >> simp [len_code]));
val n2 = thm "heap_on_bitmaps_rejected"
  ``h <=+ 0x10002C018w /\ 0x10002C018w <+ e ==> ~DISJOINT {w | h <=+ w /\ w <+ e} refund_bitmaps_dm``
  (strip_tac >> simp [DISJOINT_DEF, EXTENSION] >> qexists_tac `0x10002C018w` >> simp [dm_def, len_data] >> qexists_tac `0` >> EVAL_TAC);
val n3 = thm "code_outside_domain_rejected"
  ``!i a (m:word64 -> word8) md k. i < LENGTH ^code_tm /\ a + n2w i NOTIN md ==> ~bytes_in_mem a ^code_tm m md k``
  (simp [bytes_in_mem_iff] >> metis_tac []);
val n4 = thm "prog_addresses_mismatch_rejected"
  ``!ms mc0. mc0.prog_addresses <> (refund_t ms).mem_domain ==> ~target_configured (refund_t ms) mc0``
  (simp [target_configured_def] >> metis_tac []);
val n5 = thm "unaligned_heap_end_not_closed"
  ``~(!a:word64. byte_align a IN {w | 0w <=+ w /\ w <+ 1w} ==> a IN {w | 0w <=+ w /\ w <+ 1w})``
  (simp [] >> qexists_tac `1w` >> EVAL_TAC);
val wit0 = DB.fetch "forge_refundEntrySat" "refund_entry_pre_witness";
val sat = thm "refund_entry_and_heap_premises_satisfiable"
  ``?s h stk e. refund_entry_pre s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h /\ refund_heap_clear h e``
  (map_every exists_tac (snd (strip_comb (concl wit0))) >> conj_tac >- ACCEPT_TAC wit0 >>
   rewrite_tac [clear_def] >> rpt conj_tac >> TRY (EVAL_TAC >> NO_TAC) >> blastLib.BBLAST_TAC);
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val closure = "forge_refundInstalledAssembly" :: Theory.ancestry "forge_refundInstalledAssembly";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

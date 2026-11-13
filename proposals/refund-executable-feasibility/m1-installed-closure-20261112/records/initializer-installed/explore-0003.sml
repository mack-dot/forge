(* Exploration only: generic heap-domain lemma (published tactic of
   compile_correct', lines 4568-4617) and its use for the installed state.
   It stores no theorem and exports no theory. *)
load "forge_refundArm8ProofTheory";
open preamble backendProofTheory arm8_configProofTheory targetPropsTheory targetSemTheory
     stack_to_labProofTheory lab_to_targetProofTheory stack_removeProofTheory labSemTheory
     forge_refundSuccessfulInitializationTheory forge_refundInitializationStaticTheory
     forge_refundInitialStackCodeTheory forge_refundInitializerMachineTheory
     forge_refundInitializerAlignedTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
(* Construction of the statements from the audited two-premise theorem (U354). *)
val base = forge_refundInitializerAlignedTheory.refund_initialization_aligned;
fun var name = hd (List.filter (fn v => fst (dest_var v) = name) (free_vars (concl base)));
val (mc, ms, tar, m, dm, sdm, cbpos, cbspace, data_sp) =
  (var "mc", var "ms", var "tar", var "m", var "dm", var "sdm", var "cbpos", var "cbspace", var "data_sp");
val (ante, conclusion) = dest_imp (concl base);
val (pred_tm, mem_tm) = case strip_conj ante of [a, b] => (a, b) | _ => raise Fail "Base theorem does not have 2 premises";
fun has_const name t = can (find_term (fn c => is_const c andalso fst (dest_const c) = name)) t;
val _ = if has_const "is_arm8_machine_config" pred_tm andalso has_const "memory_assumption" mem_tm then ()
        else raise Fail "Unexpected premises";
val bitmaps_w = el 2 (snd (strip_comb mem_tm));          (* MAP n2w (FST (to_stack ...)) *)
val bitmaps_n = rand bitmaps_w;
val bytes = mk_var ("bytes", ``:word8 list``);
val cbpos_tm = ``(^mc).target.get_pc ^ms + n2w (LENGTH ^bytes)``;
val installed_tm = ``targetSem$installed ^bytes ^cbspace ^bitmaps_n ^data_sp ffi_names
                       (backendProof$heap_regs arm8_backend_config.stack_conf.reg_names) ^mc shmem ^ms``;
val good_tm = ``targetSem$good_init_state ^mc ^ms ^bytes ^cbspace ^tar ^m ^dm ^sdm``;
val conclusion2 = subst [cbpos |-> cbpos_tm] conclusion;
val installed_goal = mk_imp (mk_conj (pred_tm, installed_tm),
                             list_mk_exists ([tar, m, dm, sdm], mk_conj (good_tm, conclusion2)));
val base_gen = GENL [tar, m, dm, sdm, cbpos] base;
(* Explicit machine-model instance: any machine record with these six fields. *)
val model_tm = ``(^mc) with <| target := arm8_target; len_reg := 1; ptr_reg := 0; len2_reg := 3; ptr2_reg := 2;
                               callee_saved_regs := [19;20;21;22;23;24;25;26;27;28] |>``;
val model_goal = mk_comb (rator pred_tm, model_tm);
open proofManagerLib;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _ = new_theory "forge_refundInitializerInstalledExplore";
fun goals_now () = (top_goals ()) handle _ => [];
fun proved () = ((top_thm (); true) handle _ => false);
fun clip t = let val s = term_to_string t in String.substring (s, 0, Int.min (1100, size s)) end;
fun show label =
  (pr ("STATE " ^ label ^ " goals=" ^ Int.toString (length (goals_now ())));
   case goals_now () of
     [] => pr "NO_OPEN_GOAL"
   | (asms,gl)::_ => (List.app (fn t => pr ("ASSUMPTION " ^ clip t)) asms; pr ("GOAL " ^ clip gl); pr "END_GOAL"));
fun step label mk =
  ((e (mk ()); pr ("STEP_OK " ^ label); show label; true)
   handle ex => (pr ("STEP_FAIL " ^ label ^ " :: " ^ exn_to_string ex); false));

(* A. Generic lemma, polymorphic in the word size, as in the published proof. *)
val _ = g `
  good_dimindex (:'a) /\
  byte_aligned (a:'a word) /\ byte_aligned b /\ byte_aligned (bitmap_ptr:'a word) /\
  a <=+ b /\ DISJOINT {w | a <=+ w /\ w <+ b} bitmaps_dm /\
  (word_list bitmap_ptr (MAP Word (bitmaps:'a word list)) *
   word_list_exists (bitmap_ptr + bytes_in_word * n2w (LENGTH bitmaps)) data_sp)
    (fun2set (m, byte_aligned INTER bitmaps_dm)) ==>
  (word_list bitmap_ptr (MAP Word bitmaps) *
   word_list_exists (bitmap_ptr + bytes_in_word * n2w (LENGTH bitmaps)) data_sp *
   word_list_exists a (w2n (-1w * a + b) DIV w2n (bytes_in_word:'a word)))
    (fun2set (m, ({w | a <=+ w /\ w <+ b} UNION bitmaps_dm) INTER byte_aligned))`;
val _ = step "L:strip" (fn () => strip_tac);
val _ = step "L:biw" (fn () => `(w2n:'a word -> num) bytes_in_word = dimindex (:'a) DIV 8` by
                                 rfs [good_dimindex_def,bytes_in_word_def,dimword_def]);
val _ = step "L:domain" (fn () => once_rewrite_tac[INTER_COMM] >> rewrite_tac[UNION_OVER_INTER] >>
                                    once_rewrite_tac[UNION_COMM]);
val _ = step "L:union" (fn () => match_mp_tac fun2set_disjoint_union);
val _ = step "L:disjoint" (fn () => conj_tac >- (match_mp_tac DISJOINT_INTER >> metis_tac[DISJOINT_SYM]));
val _ = step "L:bitmaps" (fn () => conj_tac >- (first_assum ACCEPT_TAC));
val _ = step "L:heap-open" (fn () => match_mp_tac word_list_exists_imp >>
                                       fs [stack_removeProofTheory.addresses_thm]);
val _ = step "L:heap-size" (fn () => `0 < dimindex (:'a) DIV 8` by rfs [good_dimindex_def] >>
   reverse conj_tac >- (fs [] >> match_mp_tac IMP_MULT_DIV_LESS >> fs [w2n_lt] >> rfs [good_dimindex_def]));
val _ = step "L:heap-set" (fn () =>
   qpat_x_assum `a <=+ b` assume_tac >> drule WORD_LS_IMP >> strip_tac >> fs [EXTENSION] >>
   fs [IN_DEF,PULL_EXISTS,bytes_in_word_def,word_mul_n2w] >>
   rw [] >> reverse eq_tac THEN1
    (rw [] >> fs [] >> qexists_tac `i * (dimindex (:'a) DIV 8)` >> fs [] >>
     `0 < dimindex (:'a) DIV 8` by rfs [good_dimindex_def] >>
     drule X_LT_DIV >> disch_then (fn th => fs [th]) >>
     fs [RIGHT_ADD_DISTRIB] >>
     fs [GSYM word_mul_n2w,GSYM bytes_in_word_def] >>
     fs [byte_aligned_mult]));
val _ = step "L:heap-rest" (fn () =>
   rw [] >> fs [] >>
   `i < dimword (:'a)` by metis_tac [LESS_TRANS,w2n_lt] >> fs [] >>
   qexists_tac `i DIV (dimindex (:'a) DIV 8)` >>
   rfs [alignmentTheory.byte_aligned_def,
        ONCE_REWRITE_RULE [WORD_ADD_COMM] alignmentTheory.aligned_add_sub] >>
   fs [aligned_w2n] >>
   drule DIVISION >>
   disch_then (qspec_then `i` (strip_assume_tac o GSYM)) >>
   `2 ** LOG2 (dimindex (:'a) DIV 8) = dimindex (:'a) DIV 8` by
        (fs [good_dimindex_def] >> NO_TAC) >>
   fs [] >> rfs [] >> `-1w * a + b = b - a` by fs [] >>
   full_simp_tac std_ss [] >>
   Cases_on `a` >> Cases_on `b` >>
   full_simp_tac std_ss [WORD_LS,addressTheory.word_arith_lemma2] >>
   fs [] >> match_mp_tac DIV_LESS_DIV >> fs [] >>
   rfs [] >> fs [] >> match_mp_tac MOD_SUB_LEMMA >> fs []);
val _ = pr ("LEMMA proved=" ^ Bool.toString (proved ()));

(* B. Main goal up to the heap-domain conjunct. *)
val _ = set_goal ([], installed_goal);
val _ = step "strip" (fn () => strip_tac);
val _ = step "unfold-installed" (fn () => fs [installed_def, heap_regs_def, LET_THM, GSYM MAP_MAP_o]);
val _ = step "abbrev" (fn () => qmatch_asmsub_abbrev_tac `good_init_state mc ms bytes cbspace t0 m0 dm0 sdm0`);
val _ = step "witnesses" (fn () => map_every qexists_tac [`t0`,`m0`,`dm0`,`sdm0`]);
val _ = step "good" (fn () => conj_tac >- (first_assum ACCEPT_TAC));
val _ = step "match-base" (fn () => match_mp_tac base_gen);
val _ = step "pred" (fn () => conj_tac >- (first_assum ACCEPT_TAC));
val _ = step "unfold-mem" (fn () => simp [memory_assumption_def]);
val _ = if proved () then true else step "dm" (fn () => fs [Abbr `dm0`, Abbr `t0`, Abbr `m0`]);
val _ = pr ("MAIN proved=" ^ Bool.toString (proved ()));
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

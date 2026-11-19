(* P9a v2: the conditional space theorem for the refund slide machine.
   Worker A6, Night-Shift Orchestrator A, 2026-11-19.

   STATUS: UNCHECKED. NOT RUN. NOT EVIDENCE. No tactic in this file has run in HOL.
   Replaces the shape in proposals/m1b-mission-20261119/drafts/progress/P9a_space_conditional_DRAFT.sml
   (SHA-256 abb5255a...4f8c). The changes and the reasons are in P9a-audit.txt (section C).

   EXPORTED THEOREM refund_profile_a_sl_space_conditional (intended statement):
     [the 11 premises of forge_refundSlideProfileA.refund_profile_a_sl, taken from the stored term]
     /\ A-SPACE:
        !ms'. forge_refundCmlMainStep$arm8_run 27 s = SOME ms' ==>
          !po. is_safe_for_space (:64) (basis_ffi ext cl fs) po arm8_config
                 (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog
                 (read_limits arm8_config (set_oracle arm8_backend_config refund_alloc_oracle)
                    (refund_mc (sl + 0x1000040D0w) envmc) ms')
     ==>
     ?ms. (arm8_run 27 s = SOME ms /\ ms.PC = sl + 0x1000040D0w) /\
          ?io_events.
            machine_sem (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi ext cl fs) ms
              = {Terminate Success io_events} /\
            extract_fs ext (cl,fs) io_events =
              SOME (add_stdout (fastForwardFD fs 0) (refund_render_fields (refund_fields ...)))

   OPTIONAL COROLLARY refund_profile_a_sl_space_conditional_hse: the same with A-SPACE stated on the
   three entry values h, stk, e (from the stored refund_entry_run_sl: after 27 steps x1 = h, x2 = stk,
   x3 = e). A failure of the corollary does not stop the export of the main theorem.

   ROUTE. Each step is a sibling of a stored, replayed step. Only the compiler theorem changes.
     S1  sibling of forge_refundExclusionReal.refund_compile_correct_no_handler
         (results/refund-compile-correct-local-20261114/attempt-0001/real-0004.sml lines 59-92),
         with backendProof.compile_correct_is_safe_for_space (backendProofScript.sml 5005-5021)
         in place of backendProof.compile_correct (4952-4966).
     S2  sibling of forge_refundSourceNonFail.refund_behavior_valid_request_no_handler
         (m1-source-nonfail-20261115/records/nf/nonfail-0002.sml lines 51-63), with set equality.
     S3  sibling of forge_refundSlideProfileA.refund_profile_a_sl (e4-0001/proof.sml, S5, theorem TA).

   WHAT IT DOES NOT GIVE: A-SPACE itself (data_lang_safe_for_space for the whole refund data program:
   graph link P9, MISSING); that A-SPACE is satisfiable for any input or any limits (if it is not,
   this theorem is vacuously true); any step or time bound; anything about the real process.

   No cheat, no mk_thm, no new_axiom, no oracle. A failed lemma raises Fail before export_theory. *)

open preamble targetSemTheory targetPropsTheory semanticsPropsTheory semanticsTheory ml_progTheory
     backendTheory labSemTheory lab_to_targetTheory lab_to_targetProofTheory backendProofTheory
     arm8_configProofTheory arm8_targetTheory basis_ffiTheory
     forge_targetInstallPrefixTheory forge_installHandlerIrrelevantTheory forge_refundInstallHandlerTheory
     forge_refundCompileFactsTheory forge_refundExclusionSourceTheory forge_refundLabClosureTheory
     forge_refundArm8CompileTheory forge_refundWholeProgTheory forge_refundExclusionRealTheory
     forge_refundSourceNonFailTheory forge_refundStartupBridgeTheory forge_refundSlideEntryTheory
     forge_refundSlideInstalledTheory forge_refundSlideProfileATheory;

val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (500, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2500, size (term_to_string w)))); ALL_TAC g);
(* Same overload clean-up as real-0004.sml lines 15-16. *)
val _ = List.app (fn c => (let val {Name,Thy,...} = dest_thy_const c in Parse.temp_remove_ovl_mapping Name {Name=Name,Thy=Thy} end handle _ => ()))
          (Theory.constants "backend_asm");
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundSpaceConditional";

fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
(* No mk_thm: a failed proof prints LEMMA_FAILED and raises, so nothing is exported. *)
fun thm name goal tac =
  (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); raise Fail ("lemma failed: " ^ name));
fun control ok msg = if ok then pr ("CONTROL_OK " ^ msg) else (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ msg); raise Fail msg);
fun fv tm n = valOf (List.find (fn v => fst (dest_var v) = n) (free_vars tm));
fun instn th l = INST (map (fn (n, tm) => let val v = fv (concl th) n in
     if type_of v = type_of tm then () else (pr ("INSTN_TYPE_MISMATCH " ^ n); raise Fail ("instantiation type mismatch: " ^ n)); v |-> tm end) l) th;

val cfg = ``set_oracle arm8_backend_config refund_alloc_oracle``;

(* ================= K: configuration controls (EVAL only) ================= *)
val _ = pr "MARK K";
val gck = (SIMP_CONV (srw_ss()) [set_oracle_def] THENC EVAL) ``(^cfg).data_conf.gc_kind``;
val _ = pr ("GC_KIND " ^ thm_to_string gck);
val _ = control (is_const (rhs (concl gck)) andalso fst (dest_const (rhs (concl gck))) = "Simple")
                "K1 gc_kind of the compile configuration is Simple (needed: gc_kind <> None in is_safe_for_space_def)";
val mxh = (SIMP_CONV (srw_ss()) [set_oracle_def] THENC EVAL) ``2 * max_heap_limit 64 (^cfg).data_conf - 1``;
val _ = pr ("MAX_HEAP_ARG " ^ thm_to_string mxh);
val f2 = (SIMP_CONV (srw_ss()) [set_oracle_def] THENC EVAL) ``find_name (^cfg).stack_conf.reg_names 2``;
val f3 = (SIMP_CONV (srw_ss()) [set_oracle_def] THENC EVAL) ``find_name (^cfg).stack_conf.reg_names 3``;
val f4 = (SIMP_CONV (srw_ss()) [set_oracle_def] THENC EVAL) ``find_name (^cfg).stack_conf.reg_names 4``;
val _ = List.app (fn th => pr ("LIMIT_REG " ^ thm_to_string th)) [f2, f3, f4];
val _ = control (ListPair.all (uncurry aconv) (List.map (rhs o concl) [f2, f3, f4], [``1n``, ``2n``, ``3n``]))
                "K2 read_limits reads target registers x1, x2, x3 (the cml_main stub loads h, stk, e there)";

(* K3, negative and cheap: with gc_kind = None the space predicate is false for every argument. *)
val K3 = thm "is_safe_for_space_false_without_gc"
  ``!(ffi:'ffi ffi_state) po p l.
      ~is_safe_for_space (:64) ffi po arm8_config
         ((^cfg) with data_conf := (^cfg).data_conf with gc_kind := None) p l``
  (rw [is_safe_for_space_def]);

(* ================= S1: compile_correct_is_safe_for_space on the real record ================= *)
val _ = pr "MARK S1";
val hr = (SIMP_CONV (srw_ss()) [set_oracle_def, heap_regs_def] THENC EVAL) ``heap_regs (^cfg).stack_conf.reg_names``;
val (r1n, r2n) = pairSyntax.dest_pair (rhs (concl hr));
val hr2 = EVAL ``heap_regs arm8_backend_config.stack_conf.reg_names``;
val thmC = DB.fetch "forge_refundExclusionSource" "refund_u298_exclusion_source_any_handler";
val modulo = DB.fetch "forge_refundInstallHandler" "installed_modulo_install_handler";
val suffices = DB.fetch "forge_refundInstallHandler" "install_exclusion_suffices";
val thmR = DB.fetch "forge_refundExclusionReal" "refund_u298_exclusion_real";
val thmF = DB.fetch "forge_refundExclusionReal" "refund_compile_correct_no_handler";
val weak_def = DB.fetch "forge_refundExclusionReal" "refund_installed_no_handler_def";
val link = DB.fetch "forge_refundExclusionSource" "compile_lab_conf";
val cC = concl thmC;
val mc0 = fv cC "mc0"; val ffi = fv cC "ffi"; val ms = fv cC "ms";
val cbspace = fv cC "cbspace"; val data_sp = fv cC "data_sp";
val nofail = el 3 (strip_conj (fst (dest_imp cC)));
val u298 = ``!j ms' ffi'. targetSem$evaluate ^mc0 ^ffi j ^ms = (TimeOut,ms',ffi') ==> (^mc0).target.get_pc ms' <> (^mc0).install_pc``;
(* install_exclusion_suffices at the exact code, bitmaps and configuration: copy of real-0004.sml lines 60-65. *)
val s0 = INST_TYPE (match_type (type_of (fv (concl suffices) "ffi")) (type_of ffi)) suffices handle _ => suffices;
val sm = concl s0;
val suff_i = INST [fv sm "mc" |-> mc0, fv sm "bytes" |-> ``forge_refundArm8Compile$code``, fv sm "bitmaps" |-> ``forge_refundArm8Compile$data``,
            fv sm "ffi_names" |-> ``refund_lab_conf2.ffi_names``, fv sm "shmem" |-> ``refund_lab_conf2.shmem_extra``,
            fv sm "r1" |-> r1n, fv sm "r2" |-> r2n, fv sm "ms" |-> ms, fv sm "cbspace" |-> cbspace, fv sm "data_sp" |-> data_sp,
            fv sm "ffi" |-> ffi] s0;
val mcty = type_of mc0;
(* The space theorem, instantiated as compile_correct is at real-0004.sml lines 66-75, plus the two limits. *)
val rl0 = ``read_limits arm8_config ^cfg ^mc0 ^ms``;
val ccS0 = DB.fetch "backendProof" "compile_correct_is_safe_for_space";
val ccS1 = INST_TYPE (match_type (type_of (fv (concl ccS0) "mc")) mcty) ccS0;
val ccS2 = INST_TYPE (match_type (type_of (fv (concl ccS1) "ffi")) (type_of ffi)) ccS1;
val b2 = concl ccS2;
val mc2v = mk_var ("mc2", mcty);
val c1v = mk_var ("c1", type_of (fv b2 "c'"));
val ccS = INST [fv b2 "mc" |-> mc2v, fv b2 "asm_conf" |-> ``arm8_config``, fv b2 "c" |-> cfg, fv b2 "prog" |-> ``refund_prog``,
               fv b2 "bytes" |-> ``forge_refundArm8Compile$code``, fv b2 "bitmaps" |-> ``forge_refundArm8Compile$data``, fv b2 "c'" |-> c1v,
               fv b2 "ffi" |-> ffi, fv b2 "ms" |-> ms, fv b2 "cbspace" |-> cbspace, fv b2 "data_sp" |-> data_sp,
               fv b2 "stack_limit" |-> ``FST ^rl0``, fv b2 "heap_limit" |-> ``SND ^rl0``] ccS2;
val _ = pr ("SPACE_THEOREM_INSTANCE " ^ thm_to_string ccS);
(* read_limits depends on the machine record only through its target field. *)
val RL = thm "read_limits_same_target"
  ``!(m1:^(ty_antiq mcty)) (m2:^(ty_antiq mcty)) (t:^(ty_antiq (type_of ms))).
      m1.target = m2.target ==> read_limits arm8_config ^cfg m1 t = read_limits arm8_config ^cfg m2 t``
  (rw [read_limits_def]);
val spc = ``!po. is_safe_for_space (:64) ^ffi po arm8_config ^cfg refund_prog ^rl0``;
val goalS = ``is_arm8_machine_config ^mc0 /\ ^nofail /\ refund_installed_no_handler ^mc0 ^ms ^cbspace ^data_sp /\ ^spc ==>
   machine_sem ^mc0 ^ffi ^ms SUBSET
   semantics_prog (FST (THE (prim_sem_env ^ffi))) (SND (THE (prim_sem_env ^ffi))) refund_prog``;
(* Tactic: the stored thmF tactic (real-0004.sml lines 82-92), plus the two limit steps. *)
val thmS = thm "refund_compile_safe_no_handler" goalS
  (strip_tac >>
   `^u298` by (match_mp_tac thmR >> rpt conj_tac >> first_assum ACCEPT_TAC) >>
   qpat_x_assum `refund_installed_no_handler _ _ _ _` (assume_tac o PURE_REWRITE_RULE [weak_def]) >>
   mp_tac suff_i >> impl_tac >- (rpt conj_tac >> first_assum ACCEPT_TAC) >> strip_tac >>
   qpat_x_assum `?t m bitmap_ptr bitmaps_dm sdm. _` kall_tac >>
   strip_assume_tac forge_refundLabClosureTheory.refund_alloc_compiled >> drule link >> strip_tac >>
   `c1.lab_conf = refund_lab_conf2` by (assume_tac refund_lab_compile >> gvs []) >>
   `lab_to_targetProof$mc_conf_ok mc2` by (irule arm8_machine_config_ok >> first_assum ACCEPT_TAC) >>
   `mc_init_ok arm8_config ^cfg mc2` by (imp_res_tac arm8_init_ok >> fs [set_oracle_def]) >>
   `backend_config_ok arm8_config ^cfg` by (assume_tac arm8_backend_config_ok >> fs [set_oracle_def]) >>
   `read_limits arm8_config ^cfg mc2 ^ms = ^rl0` by
      (irule RL >> fs [is_arm8_machine_config_def] >> show_tac "S1-RL") >>
   mp_tac ccS >> Cases_on `THE (prim_sem_env ^ffi)` >> fs [hr, hr2, pairTheory.PAIR] >> show_tac "S1-END");

(* Control: the antecedent of S1 is the antecedent of the stored thmF plus exactly the one space conjunct. *)
val _ = control (let val a = strip_conj (fst (dest_imp (concl thmS))); val b = strip_conj (fst (dest_imp (concl thmF))) in
                   length a = length b + 1 andalso ListPair.all (uncurry aconv) (b, List.take (a, length b)) andalso aconv (List.last a) spc end)
                "S1 premises = stored refund_compile_correct_no_handler premises + A-SPACE";
val _ = control (let val (_, cF) = dest_imp (concl thmF); val (_, cS) = dest_imp (concl thmS) in
                   aconv (rand cF) (mk_comb (``extend_with_resource_limit``, rand cS)) handle _ => false end)
                "S1 conclusion = stored conclusion with extend_with_resource_limit removed";

(* ================= S2: Success with the full output, as a set equality ================= *)
val _ = pr "MARK S2";
val sem = DB.fetch "forge_refundWholeProg" "refund_semantics";
val _ = tags "refund_semantics" sem;
val syn = valOf (List.find (fn th => aconv (concl th) ``prog_syntax_ok refund_prog``)
                 (CONJUNCTS (DB.fetch "forge_refundArm8Compile" "refund_arm8_compiled")));
val thmN = DB.fetch "forge_refundSourceNonFail" "refund_source_nonfail";
val (inp, semc) = dest_imp (concl sem);
val bffi = rand (rand (rator (rator (rand (rator semc)))));   (* as nonfail-0002.sml line 24 *)
val post = rand semc;
val extract = rand (snd (dest_exists (snd (dest_abs post))));  (* as nonfail-0002.sml line 52 *)
val iov = fst (dest_exists (snd (dest_abs post)));
val nofail_b = ``~semantics_prog (FST (THE (prim_sem_env ^bffi))) (SND (THE (prim_sem_env ^bffi))) refund_prog Fail``;
fun at_basis th = let val f = fv (concl th) "ffi" in
   INST [inst (match_type (type_of f) (type_of bffi)) f |-> bffi] (INST_TYPE (match_type (type_of f) (type_of bffi)) th) end;
val thmSb = at_basis thmS;
val (antS, _) = dest_imp (concl thmSb);
val [armS, nfS, instS, spcS] = strip_conj antS;
val _ = control (aconv nfS nofail_b) "S2 non-Fail premise form equals refund_source_nonfail";
val behS = mk_exists (iov, mk_conj (``machine_sem ^mc0 ^bffi ^ms = {Terminate Success ^iov}``, extract));
val sat_rw = MATCH_MP semantics_dec_list_eq syn;
val thmB = thm "refund_behavior_valid_request_space" (mk_imp (list_mk_conj [armS, instS, spcS, inp], behS))
  (strip_tac >>
   `^nofail_b` by (match_mp_tac thmN >> asm_rewrite_tac []) >>
   `machine_sem ^mc0 ^bffi ^ms SUBSET
      semantics_prog (FST (THE (prim_sem_env ^bffi))) (SND (THE (prim_sem_env ^bffi))) refund_prog` by
      (match_mp_tac thmSb >> rpt conj_tac >> first_assum ACCEPT_TAC) >>
   pop_assum (assume_tac o REWRITE_RULE [init_state_env_thm, FST, SND]) >>
   `sem_satisfies (semantics_prog (init_state ^bffi) init_env refund_prog) ^post` by
      (mp_tac sem >> asm_rewrite_tac [sat_rw] >> show_tac "S2-sat") >>
   `?b. machine_sem ^mc0 ^bffi ^ms = {b}` by rewrite_tac [machine_sem_sing] >>
   fs [sem_satisfies_def, SUBSET_DEF] >> res_tac >> fs [] >> show_tac "S2-END" >> metis_tac []);

(* ================= S3: the slide-generic statement ================= *)
val _ = pr "MARK S3";
val inst_red = DB.fetch "forge_refundSlideInstalled" "refund_installed_from_entry_reduced_sl";
val E1 = DB.fetch "forge_refundSlideProfileA" "refund_env_ok_sl_iff_installed_residual";
val TA = DB.fetch "forge_refundSlideProfileA" "refund_profile_a_sl";
val RUNS = DB.fetch "forge_refundSlideProfileA" "refund_profile_a_sl_every_machine_run";
val mcf = DB.fetch "forge_refundSlideProfileA" "refund_mc_environment_fields_sl";
val is_arm8 = DB.fetch "forge_refundStartupBridge" "refund_mc_is_arm8";
val mctyG = fst (dom_rng (type_of ``is_arm8_machine_config``));
val envmc = mk_var ("envmc", mctyG);
val B = ``sl + 0x1000040D0w:word64``;
val MC = ``refund_mc ^B ^envmc``;
val prem_TA = fst (dest_imp (concl TA));                          (* the 11 stored premises, term for term *)
val beh_i = instn thmB [("mc0", MC), ("cbspace", ``428n``), ("data_sp", ``0n``)];
val (beh_ante, beh_ci) = dest_imp (concl beh_i);
val msv = fv beh_ante "ms";
val msq = mk_var ("ms'", type_of msv);
val run_c = ``forge_refundCmlMainStep$arm8_run 27 s = SOME ^msv /\ (^msv).PC = ^B``;
val spc_i = el 3 (strip_conj beh_ante);
val aspace = ``!^msq. forge_refundCmlMainStep$arm8_run 27 s = SOME ^msq ==> ^(subst [msv |-> msq] spc_i)``;
val _ = pr ("A_SPACE " ^ term_to_string aspace);
val P9A = thm "refund_profile_a_sl_space_conditional"
  (mk_imp (mk_conj (prem_TA, aspace), mk_exists (msv, mk_conj (run_c, beh_ci))))
  (strip_tac >> mp_tac inst_red >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
   `refund_installed_rest2 ^MC ms` by (mp_tac (SPEC msv E1) >> asm_rewrite_tac [] >> show_tac "S3-rest2") >>
   `refund_installed_no_handler ^MC ms 428 0` by res_tac >>
   `^spc_i` by res_tac >>
   qexists_tac `ms` >> asm_rewrite_tac [] >>
   match_mp_tac beh_i >> asm_rewrite_tac [is_arm8] >> show_tac "S3-END");

(* Controls on the exported statement. *)
val _ = control (let val a = strip_conj (fst (dest_imp (concl P9A))); val b = strip_conj prem_TA in
                   length a = length b + 1 andalso ListPair.all (uncurry aconv) (b, List.take (a, length b)) end)
                "S3 premises = the 11 stored premises of refund_profile_a_sl + A-SPACE (12 conjuncts)";
val _ = control (not (can (find_term (fn t => is_const t andalso fst (dest_const t) = "extend_with_resource_limit")) (concl P9A)))
                "S3 conclusion has no extend_with_resource_limit";
val _ = control (can (find_term (fn t => is_const t andalso fst (dest_const t) = "is_safe_for_space")) (concl P9A))
                "S3 premise names is_safe_for_space (A-SPACE is present)";
(* The output equation is the stored one: compare with the extract_fs conjunct of refund_profile_a_sl. *)
val _ = control (let fun ex tm = find_term (fn t => is_eq t andalso can (find_term (fn u => is_const u andalso fst (dest_const u) = "extract_fs")) (lhs t)
                                              andalso is_comb (rhs t)) tm
                 in aconv (rhs (ex (concl TA))) (rhs (ex (concl P9A))) end handle _ => false)
                "S3 output term is the stored refund_profile_a_sl output term";

(* K4: the resource stop is excluded. A consequence; it shows the strength gained over RUNS. *)
val P9A_rlh = thm "refund_profile_a_sl_space_no_resource_stop"
  (mk_imp (mk_conj (prem_TA, aspace),
     mk_exists (msv, list_mk_conj [run_c,
       ``!io'. ~(Terminate Resource_limit_hit io' IN machine_sem ^MC (basis_ffi ext cl fs) ^msv)``,
       ``~(Fail IN machine_sem ^MC (basis_ffi ext cl fs) ^msv)``])))
  (strip_tac >> mp_tac P9A >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
   qexists_tac `ms` >> asm_rewrite_tac [] >> simp [] >> show_tac "K4");

(* ================= OPTIONAL: A-SPACE on the entry values h, stk, e ================= *)
val _ = pr "MARK OPT";
val _ = (let
  val ER = DB.fetch "forge_refundSlideEntry" "refund_entry_run_sl";
  val AG = DB.fetch "forge_refundSlideEntry" "arm8_run_constants_agree";
  val RL2 = thm "read_limits_arm8_registers"
    ``!(mc:^(ty_antiq mctyG)) (t:arm8_state). mc.target = arm8_target ==>
        read_limits arm8_config ^cfg mc t =
        stack_removeProof$get_stack_heap_limit (2 * max_heap_limit 64 (^cfg).data_conf - 1) (t.REG 1w, t.REG 2w, t.REG 3w)``
    (rw [read_limits_def] >> simp [arm8_target_def, f2, f3, f4] >> show_tac "RL2");
  val spc_hse = subst [``read_limits arm8_config ^cfg ^MC ^msv`` |->
                       ``stack_removeProof$get_stack_heap_limit (2 * max_heap_limit 64 (^cfg).data_conf - 1) (h:word64, stk:word64, e:word64)``] spc_i;
  val _ = pr ("A_SPACE_HSE " ^ term_to_string spc_hse);
  val _ = control (not (free_in msv spc_hse)) "OPT the h/stk/e form of A-SPACE has no machine state";
  val P9H = thm "refund_profile_a_sl_space_conditional_hse"
    (mk_imp (mk_conj (prem_TA, spc_hse), mk_exists (msv, mk_conj (run_c, beh_ci))))
    (strip_tac >> match_mp_tac P9A >> rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >>
     rpt strip_tac >>
     qpat_x_assum `refund_entry_pre_sl _ _ _ _ _` (fn th => assume_tac th >> strip_assume_tac (MATCH_MP ER th)) >>
     fs [AG] >> gvs [] >> fs [RL2, mcf] >> show_tac "OPT-END")
  in () end)
  handle e => pr ("OPTIONAL_LEMMA_FAILED refund_profile_a_sl_space_conditional_hse " ^ General.exnMessage e);

val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

(* U409, plan steps S4, S5, S6 of the slide-generic chain.
   S4: the FFI contract and the environment predicate at the relocated base sl + 0x1000040D0w; exact equivalence with the two
       residual clauses; the abstract environment satisfies it; regression to refund_env_ok at slide 0.
   S5: composition with the U387 behaviour and exclusion theorems: the Profile A statement at every permitted slide.
   S6: the instance sl = 0w is, term for term, the stored U404 theorem (derived here from the slide theorem only).
   NOT proved: that any real environment satisfies refund_env_ok_sl; the entry state; the loader, dyld, the C run-time, the processor;
   the Dafny-to-HOL contract link. No profile is approved by this file. *)
open preamble targetSemTheory targetPropsTheory ffiTheory semanticsPropsTheory fsFFITheory basis_ffiTheory TextIOProofTheory
     backendTheory asmPropsTheory lab_to_targetTheory arm8Theory arm8_targetTheory alignmentTheory miscTheory set_sepTheory
     backendProofTheory arm8_configProofTheory wordsLib blastLib forge_refundArm8CompileTheory forge_refundExclusionRealTheory
     forge_refundStartupClauseTheory forge_refundStartupBridgeTheory forge_refundInstalledDomainsTheory forge_refundInstalledAssemblyTheory
     forge_refundFfiFactsTheory forge_refundResidualTheory forge_refundEnvModelTheory forge_refundSourceNonFailTheory
     forge_refundProfileATheory forge_refundSlideEntryTheory forge_refundSlideDomainsTheory forge_refundSlideInstalledTheory
     forge_refundSlideSatTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (500, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundSlideProfileA";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
(* mk_thm is used ONLY to let later lemmas be explored after a failure; the run raises Fail before export if any lemma failed,
   and every stored theorem is tag-checked. *)
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; mk_thm ([], goal));
fun instn th l = INST (map (fn (n, tm) => let val v = valOf (List.find (fn v => fst (dest_var v) = n) (free_vars (concl th))) in
     if type_of v = type_of tm then () else (pr ("INSTN_TYPE_MISMATCH " ^ n ^ " : " ^ type_to_string (type_of v) ^ " VERSUS " ^ type_to_string (type_of tm));
                                             raise Fail ("instantiation type mismatch: " ^ n)); v |-> tm end) l) th;
fun has_const n tm = can (find_term (fn t => is_const t andalso fst (dest_const t) = n)) tm;
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val envmc = mk_var ("envmc", mcty);
val sl = ``sl:word64``;
val B = ``sl + 0x1000040D0w:word64``;
val MC = ``refund_mc ^B ^envmc``;
val mc_def = DB.fetch "forge_refundStartupBridge" "refund_mc_def";
val fix_def = DB.fetch "forge_refundStartupClause" "arm8_fix_def";
val is_arm8 = DB.fetch "forge_refundStartupBridge" "refund_mc_is_arm8";
val names_thm = DB.fetch "forge_refundFfiFacts" "refund_ffi_names";
val rest2_def = DB.fetch "forge_refundResidual" "refund_installed_rest2_def";
fun EM n = DB.fetch "forge_refundEnvModel" n;
val [contract_def, names4, abs_def, AWB, tsr_facts, env_def, I1, N1, msw_def, bad_ret_def] = map EM ["refund_ffi_contract_def",
     "refund_ffi_names_list", "refund_abs_ffi_def", "asm_write_bytearray_agree_on_domain", "arm8_target_state_rel_facts", "refund_abs_env_def",
     "refund_id_interfer_ok", "pc_change_breaks_interference", "refund_ffi_witness_state_def", "refund_bad_return_ffi_def"];
val FLD = DB.fetch "forge_refundSlideInstalled" "refund_mc_concrete_fields_sl";
val inst_red = DB.fetch "forge_refundSlideInstalled" "refund_installed_from_entry_reduced_sl";
val beh = DB.fetch "forge_refundSourceNonFail" "refund_behavior_valid_request_no_handler";
val exc = DB.fetch "forge_refundSourceNonFail" "refund_u298_exclusion_valid_request";
val ok_def = DB.fetch "forge_refundProfileA" "refund_env_ok_def";
val TA0_stored = DB.fetch "forge_refundProfileA" "refund_profile_a_slide0";
val RUNS0_stored = DB.fetch "forge_refundProfileA" "refund_profile_a_slide0_every_machine_run";
fun SE n = DB.fetch "forge_refundSlideEntry" n;
val E4 = SE "slide_zero_entry_is_the_old_entry"; val D4 = SE "shifted_domains_at_slide_zero";
val _ = List.app (fn (n, th) => pr ("USED " ^ n ^ "\n" ^ thm_to_string th)) [("refund_installed_from_entry_reduced_sl", inst_red),
          ("refund_behavior_valid_request_no_handler", beh), ("refund_u298_exclusion_valid_request", exc), ("refund_ffi_contract_def", contract_def)];
(* ================= S4 ================= *)
val _ = pr "MARK S4";
(* The contract with the code base as a parameter: the stored slide-0 body with the literal base replaced by b. *)
val (cl0, cr0) = dest_eq (snd (strip_forall (concl contract_def)));
val [dmv, ffiv] = snd (strip_comb cl0);
val lit = ``0x1000040D0w:word64``; val bv = ``b:word64``;
val cr_b = subst [lit |-> bv] cr0;
val _ = if can (find_term (aconv lit)) cr0 andalso not (can (find_term (aconv lit)) cr_b) andalso free_in bv cr_b then pr "CONTRACT_BODY_PARAMETRISED true"
        else raise Fail "contract body";
val cat_c = mk_var ("refund_ffi_contract_at", ``:word64`` --> type_of dmv --> type_of ffiv --> bool);
val contract_at_def = new_definition ("refund_ffi_contract_at_def", mk_eq (list_mk_comb (cat_c, [bv, dmv, ffiv]), cr_b));
val _ = pr ("DEFINITION " ^ thm_to_string contract_at_def);
val R0 = thm "refund_ffi_contract_at_link_base_is_the_old_contract"
  ``!dm f. refund_ffi_contract_at 0x1000040D0w dm f <=> refund_ffi_contract dm f``
  (rewrite_tac [contract_at_def, contract_def]);
val flds2 = thm "refund_mc_register_fields_sl"
  ``(^MC).ffi_interfer = (^envmc).ffi_interfer /\ (^MC).next_interfer = (^envmc).next_interfer /\ (^MC).ptr_reg = 0 /\ (^MC).len_reg = 1 /\
    (^MC).ptr2_reg = 2 /\ (^MC).len2_reg = 3 /\ (^MC).callee_saved_regs = [19;20;21;22;23;24;25;26;27;28]``
  (simp [mc_def, fix_def]);
val tg = prove (``arm8_target.get_pc (ms:arm8_state) = ms.PC /\ arm8_target.get_byte ms = ms.MEM /\ arm8_target.get_reg ms r = ms.REG (n2w r) /\
                  arm8_target.state_ok = arm8_ok /\ arm8_target.config.code_alignment = 2 /\ arm8_target.config.link_reg = SOME 30 /\
                  arm8_target.config.reg_count = 32 /\ arm8_target.config.avoid_regs = [18; 26; 31]``,
  simp [arm8_target_def, arm8_config_def, FUN_EQ_THM]);
val elx = prove (``index < 4 ==> ([ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»]❲index❳ = ExtCall «» <=> F)``,
  strip_tac >> `index = 0 \/ index = 1 \/ index = 2 \/ index = 3` by decide_tac >> simp []);
val idx = prove (``index < 4 ==> (4 <= index <=> F)``, decide_tac);
val fld1 = MP (SPEC ``[ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»]`` FLD)
              (prove (``refund_lab_conf2.ffi_names = SOME [ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»] /\
                        LENGTH [ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»] = 4``, simp [names4]));
val mm4 = prove (``mmio_pcs_min_index [ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»] = SOME 4``,
  strip_assume_tac names_thm >> fs [names4] >> rveq >> fs []);
val S = [ffi_interfer_ok_def, read_ffi_bytearrays_def, read_ffi_bytearray_def, ffi_offset_def, LET_THM, tg, fld1, flds2, mm4, elx, idx];
val lhs_n = SIMP_CONV (srw_ss()) S ``ffi_interfer_ok ^B ^MC``;
val _ = pr ("LHS_N " ^ thm_to_string lhs_n);
val rhs_n = SIMP_CONV (srw_ss()) (contract_at_def :: S) ``refund_ffi_contract_at ^B (^envmc).prog_addresses (^envmc).ffi_interfer``;
val _ = pr ("RHS_N " ^ thm_to_string rhs_n);
val FC = (let
  val long = find_term (fn t => is_conj t andalso is_disj (fst (dest_conj t)) andalso can (find_term (aconv ``r < 32n``)) t) (rhs (concl lhs_n))
  val short = find_term (fn t => is_disj t andalso length (strip_disj t) = 9 andalso aconv (hd (strip_disj t)) ``r = 19n``) (rhs (concl rhs_n))
  val rl' = prove (mk_eq (long, short), decide_tac)
  val lhs_n' = CONV_RULE (RAND_CONV (PURE_REWRITE_CONV [rl'])) lhs_n
  val mid = Tactical.TAC_PROOF (([], mk_eq (rhs (concl lhs_n'), rhs (concl rhs_n))),
    eq_tac >> rpt gen_tac
    >- (disch_then (fn all => rpt gen_tac >> strip_tac >>
          mp_tac (Q.SPECL [`ms2`, `k`, `index`, `new_bytes`, `t1`, `bytes`, `bytes2`] all)) >> asm_rewrite_tac [] >> show_tac "MID1")
    >- (disch_then (fn all => rpt gen_tac >> strip_tac >> strip_tac >>
          mp_tac (Q.SPECL [`k`, `index`, `new_bytes`, `ms2`, `t1`, `bytes`, `bytes2`] all)) >> asm_rewrite_tac [] >> show_tac "MID2"))
  val th = save_thm ("ffi_interfer_ok_iff_contract_sl", TRANS lhs_n' (TRANS mid (SYM rhs_n)))
  in chk "ffi_interfer_ok_iff_contract_sl" th; th end)
  handle e => (pr ("LEMMA_FAILED ffi_interfer_ok_iff_contract_sl " ^ General.exnMessage e); failed := "ffi_interfer_ok_iff_contract_sl" :: !failed;
               mk_thm ([], ``ffi_interfer_ok ^B ^MC <=> refund_ffi_contract_at ^B (^envmc).prog_addresses (^envmc).ffi_interfer``));
val ok_sl_def = new_definition ("refund_env_ok_sl_def",
  ``refund_env_ok_sl ^sl ^envmc <=>
      interference_ok (^envmc).next_interfer (arm8_target.proj (^envmc).prog_addresses) /\
      refund_ffi_contract_at (^sl + 0x1000040D0w) (^envmc).prog_addresses (^envmc).ffi_interfer``);
val _ = pr ("DEFINITION " ^ thm_to_string ok_sl_def);
val mcf = thm "refund_mc_environment_fields_sl"
  ``(^MC).next_interfer = (^envmc).next_interfer /\ (^MC).target = arm8_target /\ (^MC).prog_addresses = (^envmc).prog_addresses``
  (simp [mc_def, fix_def] >> show_tac "MCF");
val E1 = thm "refund_env_ok_sl_iff_installed_residual"
  ``!ms. ms.PC = ^B ==> (refund_installed_rest2 ^MC ms <=> refund_env_ok_sl ^sl ^envmc)``
  (rpt strip_tac >> asm_rewrite_tac [rest2_def, ok_sl_def, FC, mcf] >> show_tac "E1");
val AB = thm "refund_abs_ffi_contract_at" ``!b dm. refund_ffi_contract_at b dm refund_abs_ffi``
  (rewrite_tac [contract_at_def] >> rpt gen_tac >> strip_tac >> first_assum (strip_assume_tac o MATCH_MP tsr_facts) >>
   `ms2.REG 30w = t1.regs 30 /\ ms2.REG 2w = t1.regs 2` by
      (first_assum (qspec_then `30` mp_tac) >> first_x_assum (qspec_then `2` mp_tac) >> simp []) >>
   fs [abs_def, arm8_ok_def] >> rpt strip_tac
   >- (show_tac "AB1" >> metis_tac [AWB])
   >> show_tac "AB2" >> first_x_assum match_mp_tac >> simp []);
val E2 = thm "refund_abs_env_is_ok_sl" ``refund_env_ok_sl ^sl (refund_abs_env ^envmc)``
  (simp [ok_sl_def, env_def, I1, AB] >> show_tac "E2");
val E3 = thm "refund_env_ok_sl_at_slide_zero" ``refund_env_ok_sl 0w ^envmc <=> refund_env_ok ^envmc``
  (rewrite_tac [ok_sl_def, ok_def, WORD_ADD_0, R0]);
val env_prog = prove (``(refund_abs_env ^envmc).prog_addresses = (^envmc).prog_addresses``, simp [env_def]);
(* Controls for S4. *)
val K1 = thm "pc_changing_environment_is_not_ok_sl"
  ``~refund_env_ok_sl ^sl (^envmc with next_interfer := (\(i:num) ms. ms with PC := ms.PC + 4w))``
  (simp [ok_sl_def, N1] >> show_tac "K1");
(* Base sensitivity: an FFI effect that is correct only when called from the stubs of base b satisfies the contract at b,
   and does NOT satisfy the contract at the base of slide 0x4000. Slide-0 environment evidence does not transfer to a slide. *)
val guard_def = new_definition ("refund_stub_guard_ffi_def",
  ``refund_stub_guard_ffi (b:word64) (k:num) (x:num # word8 list # arm8_state) =
      if (SND (SND x)).PC = b - 48w \/ (SND (SND x)).PC = b - 64w \/ (SND (SND x)).PC = b - 80w \/ (SND (SND x)).PC = b - 96w
      then refund_abs_ffi k x else refund_bad_return_ffi k x``);
val G1 = thm "stub_guard_ffi_satisfies_contract_at_its_base" ``!b dm. refund_ffi_contract_at b dm (refund_stub_guard_ffi b)``
  (rpt gen_tac >> rewrite_tac [contract_at_def] >> rpt gen_tac >> strip_tac >> first_assum (strip_assume_tac o MATCH_MP tsr_facts) >>
   `refund_stub_guard_ffi b k (index,new_bytes,ms2) = refund_abs_ffi k (index,new_bytes,ms2)` by
      (`index = 0 \/ index = 1 \/ index = 2 \/ index = 3` by decide_tac >> fs [guard_def] >> show_tac "G1a") >>
   pop_assum (fn th => rewrite_tac [th]) >>
   mp_tac (REWRITE_RULE [contract_at_def] (Q.SPECL [`b`, `dm`] AB)) >>
   disch_then (qspecl_then [`k`, `index`, `new_bytes`, `ms2`, `t1`, `bytes`, `bytes2`] mp_tac) >> asm_rewrite_tac [] >> show_tac "G1b");
val W1 = ``refund_ffi_witness_state with PC := 0x1000080A0w``;
val G2 = thm "slide_zero_stub_guard_ffi_fails_contract_at_slide_0x4000"
  ``!dm. ~refund_ffi_contract_at 0x1000080D0w dm (refund_stub_guard_ffi 0x1000040D0w)``
  (gen_tac >> rewrite_tac [contract_at_def] >> strip_tac >>
   first_x_assum (qspecl_then [`0`, `0`, `[]`, `^W1`,
      `<| regs := (\i. 0w); fp_regs := (\i. 0w); mem := (^W1).MEM; mem_domain := dm; pc := ARB; lr := 30; align := 2; be := F; failed := F |>`,
      `[]`, `[]`] mp_tac) >>
   impl_tac
   >- (simp [msw_def, read_bytearray_def, target_state_rel_def, tg, arm8_ok_def] >> simp [arm8_target_def, arm8_config_def] >> EVAL_TAC >> show_tac "G2a")
   >- (simp [guard_def, bad_ret_def, abs_def, msw_def] >> show_tac "G2b"));
(* ================= S5 ================= *)
val _ = pr "MARK S5";
val (red_ante, red_conc) = dest_imp (concl inst_red);
val (beh_ante, beh_conc) = dest_imp (concl beh);
val input_prems = List.drop (strip_conj beh_ante, 2);   (* stdin, wfcl, wfFS, STD_streams *)
val _ = List.app (fn t => pr ("INPUT_PREMISE " ^ term_to_string t)) input_prems;
val msv = valOf (List.find (fn v => fst (dest_var v) = "ms") (free_vars beh_ante));
val beh_i = instn beh [("mc0", MC), ("cbspace", ``428n``), ("data_sp", ``0n``)];
val exc_i = instn exc [("mc0", MC), ("cbspace", ``428n``), ("data_sp", ``0n``)];
val (_, beh_ci) = dest_imp (concl beh_i); val (_, exc_ci) = dest_imp (concl exc_i);
val prem_g = list_mk_conj (strip_conj red_ante @ [``refund_env_ok_sl ^sl ^envmc``] @ input_prems);
val run_c = ``forge_refundCmlMainStep$arm8_run 27 s = SOME ^msv /\ (^msv).PC = ^B``;
val TA = thm "refund_profile_a_sl"
  (mk_imp (prem_g, mk_exists (msv, list_mk_conj [run_c, exc_ci, beh_ci])))
  (strip_tac >> mp_tac inst_red >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
   `refund_installed_rest2 ^MC ms` by (mp_tac (SPEC msv E1) >> asm_rewrite_tac [] >> show_tac "TA-rest2") >>
   `refund_installed_no_handler ^MC ms 428 0` by res_tac >>
   qexists_tac `ms` >> asm_rewrite_tac [] >> conj_tac
   >- (match_mp_tac exc_i >> asm_rewrite_tac [is_arm8] >> show_tac "TA-exc")
   >- (match_mp_tac beh_i >> asm_rewrite_tac [is_arm8] >> show_tac "TA-beh"));
val TAa = thm "refund_profile_a_sl_abstract_env"
  (let val th = INST [envmc |-> ``refund_abs_env ^envmc``] TA |> REWRITE_RULE [env_prog, E2] in concl th end)
  (ACCEPT_TAC (INST [envmc |-> ``refund_abs_env ^envmc``] TA |> REWRITE_RULE [env_prog, E2]));
val (iov, beh_body) = dest_exists beh_ci;
val [beh_sub, beh_fs] = strip_conj beh_body;
val msem = rand (rator beh_sub);
val _ = pr ("MACHINE_SEM_TERM " ^ term_to_string msem);
val out_fs = rhs beh_fs;
val every_run = ``!b. ^msem b ==>
     (?io. b = Terminate Success io /\ extract_fs ext (cl, fs) io = ^out_fs) \/
     (?io io'. b = Terminate Resource_limit_hit io' /\ io' ≼ io /\ extract_fs ext (cl, fs) io = ^out_fs)``;
val RUNS = thm "refund_profile_a_sl_every_machine_run"
  (mk_imp (prem_g, mk_exists (msv, list_mk_conj [run_c, every_run, ``?b. ^msem b``, ``~^msem Fail``])))
  (strip_tac >> mp_tac TA >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
   qexists_tac `ms` >> asm_rewrite_tac [machine_sem_total] >> conj_tac
   >- (rpt strip_tac >> `b IN extend_with_resource_limit {Terminate Success io_events}` by (fs [SUBSET_DEF, IN_DEF] >> show_tac "RUNS-in") >>
       pop_assum mp_tac >> simp [extend_with_resource_limit_def] >> strip_tac >> rveq >> fs [] >> metis_tac [] )
   >- (strip_tac >> `Fail IN extend_with_resource_limit {Terminate Success io_events}` by (fs [SUBSET_DEF, IN_DEF] >> show_tac "RUNS-fail") >>
       pop_assum mp_tac >> simp [extend_with_resource_limit_def] >> show_tac "RUNS-nofail"));
(* Satisfiability of the entry, heap, domain AND environment premises at slide 0x4000 (constructed model state, abstract environment).
   The input premises (a well-formed file system with a canonical request) are NOT included. *)
val wit = DB.fetch "forge_refundSlideSat" "refund_entry_pre_sl_witness_0x4000";
val heap_sat = DB.fetch "forge_refundSlideSat" "sat_sl_heap_premises";
val [SLv, s0, h0, stk0, e0] = snd (strip_comb (concl wit));
val env0 = ``refund_abs_env ((ARB : ^(ty_antiq mcty)) with prog_addresses := refund_mem_dm_sl ^SLv ^h0 ^e0)``;
val env0_prog = prove (``(^env0).prog_addresses = refund_mem_dm_sl ^SLv ^h0 ^e0``, simp [env_def]);
val E2i = INST [sl |-> SLv, envmc |-> ``(ARB : ^(ty_antiq mcty)) with prog_addresses := refund_mem_dm_sl ^SLv ^h0 ^e0``] E2;
val SAT = thm "refund_profile_a_sl_machine_premises_satisfiable_at_0x4000"
  ``?s h stk e (envmc : ^(ty_antiq mcty)). refund_entry_pre_sl ^SLv s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h /\
       refund_heap_clear_sl ^SLv h e /\ envmc.prog_addresses = refund_mem_dm_sl ^SLv h e /\ refund_env_ok_sl ^SLv envmc``
  (map_every exists_tac [s0, h0, stk0, e0, env0] >> rewrite_tac [wit, heap_sat, env0_prog, E2i]);
(* ================= S6 ================= *)
val _ = pr "MARK S6";
val D4g = GEN_ALL D4;
val z = ``0w:word64``;
fun regress name stored slide_thm =
  thm name (concl stored)
   (strip_tac >> mp_tac (INST [sl |-> z] slide_thm) >> rewrite_tac [WORD_ADD_0, D4g, E3] >>
    (impl_tac >- (asm_rewrite_tac [] >> match_mp_tac E4 >> first_assum ACCEPT_TAC)) >>
    (disch_then ACCEPT_TAC ORELSE (strip_tac >> qexists_tac `ms` >> asm_rewrite_tac [] >> show_tac ("S6 " ^ name))));
val S6a = regress "slide_zero_instance_is_refund_profile_a_slide0" TA0_stored TA;
val S6b = regress "slide_zero_instance_is_refund_profile_a_slide0_every_machine_run" RUNS0_stored RUNS;
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = if aconv (concl S6a) (concl TA0_stored) andalso aconv (concl S6b) (concl RUNS0_stored)
        then pr "CONTROL_OK the slide-0 instances are term-identical to the stored U404 theorems" else raise Fail "UNEXPECTED_CONTROL_ACCEPTANCE regression";
(* ---- Structural checks on the stored slide statement. ---- *)
val problems = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
val (ta_ante, ta_conc) = dest_imp (concl TA);
val (_, ta_body) = dest_exists ta_conc;
val ta_conjs = strip_conj ta_body;
val ta_beh = List.last ta_conjs;
val (io2, bb) = dest_exists ta_beh; val [sub2, fs2] = strip_conj bb;
val _ = if aconv (rhs fs2) (rhs (List.nth (strip_conj (snd (dest_exists beh_conc)), 1)))
        then pr "CONTROL_OK the output term of the slide theorem is syntactically the U387 output term (not weakened, not restated)" else bad "output-term";
val _ = if free_in io2 (rand sub2) andalso free_in io2 (lhs fs2) then pr "CONTROL_OK one io_events is bound for both the machine_sem inclusion and the extract_fs equation"
        else bad "shared-io";
val _ = if aconv (rand (rator sub2)) msem andalso free_in msv msem andalso can (find_term (aconv MC)) msem
        then pr "CONTROL_OK the machine_sem term is for refund_mc (sl + 0x1000040D0w) envmc, the basis oracle, and the state ms reached by arm8_run 27 s" else bad "machine-term";
val _ = if not (has_const "extract_fs" ta_ante) andalso not (has_const "machine_sem" ta_ante) andalso not (has_const "refund_installed_no_handler" ta_ante)
           andalso not (has_const "refund_installed_rest2" ta_ante)
           andalso has_const "refund_env_ok_sl" ta_ante andalso has_const "refund_entry_pre_sl" ta_ante andalso has_const "stdin_content" ta_ante
        then pr "CONTROL_OK premises: entry state at a slide, refund_env_ok_sl, input; no premise mentions extract_fs, machine_sem or an installed-state predicate" else bad "premises";
val _ = if not (has_const "semantics_prog" (concl TA)) andalso not (has_const "semantics_dec_list" (concl TA))
        then pr "CONTROL_OK the slide statement mentions no source-semantics constant" else bad "source-constant";
val _ = if not (has_const "refund_env_ok_sl" (concl TAa)) andalso has_const "refund_abs_env" (concl TAa) then pr "CONTROL_OK the abstract-environment instance has no environment premise"
        else bad "abstract-instance";
val _ = if length (strip_conj ta_ante) = length (strip_conj (fst (dest_imp (concl TA0_stored)))) then pr "CONTROL_OK the slide theorem has the same number of premises as the U404 theorem"
        else bad "premise-count";
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundSlideProfileA" @ DB.definitions "forge_refundSlideProfileA");
val cc = DB.fetch "backendProof" "compile_correct'";
val _ = (tags "compile_correct'" cc; pr "PUBLISHED compile_correct' loaded, tag clean");
val closure = "forge_refundSlideProfileA" :: Theory.ancestry "forge_refundSlideProfileA";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundSlideProfileA")));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = pr ("CLOSURE_HAS_COMPILE_CORRECT_CONTROL " ^ Bool.toString (Lib.mem "forge_compileCorrectControl" closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

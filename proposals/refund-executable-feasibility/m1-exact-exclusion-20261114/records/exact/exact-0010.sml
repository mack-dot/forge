(* Exact refund lab program: step-closed invariant, initialisation, and target-level installer exclusion. *)
open preamble backendTheory labSemTheory labLangTheory labPropsTheory lab_filterTheory targetSemTheory targetPropsTheory asmPropsTheory
     lab_to_targetProofTheory
     forge_refundLabClosureTheory forge_refundLabResolveTheory
     forge_labRegionInvariantTheory forge_labRegionStepTheory forge_labRegionWalkTheory forge_refundLabRunTheory
     forge_labRegionAlignedTheory forge_targetInstallPrefixTheory forge_simZeroCaseTheory forge_simLayoutTheory
     forge_simRootTheory forge_simReplayTheory forge_refundLabFilteredTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundExactExclusion";
val L_tm = ``SND (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))``;
val F_tm = ``filter_skip ^L_tm``;
val ls_tm = ``[Install_location; InstallData_location]``;
val OK_tm = ``pc_ok ^ls_tm ^F_tm``;
val G_tm = ``(loc_good ^OK_tm ^F_tm) : 64 word_loc -> bool``;
val D_tm = ``\x:word64. ?a. x = byte_align a``;
val lab_link = DB.fetch "forge_refundLabClosure" "lab_forge8_to_lab";
val the_lab = ``lab_forge8 (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog``;
val loc_eqs = [data_to_wordTheory.Install_location_eq, data_to_wordTheory.InstallData_location_eq];
val info = DB.fetch "forge_refundLabFiltered" "filt_info_eval";
val wpair = DB.fetch "forge_refundLabFiltered" "filt_walk_pair_eval";
val wsingle = DB.fetch "forge_refundLabFiltered" "filt_walk_single_eval";
val walk1_thm = DB.fetch "forge_refundLabRun" "hyp_walk1_eq";
(* 1. Counts for the exact lab program and for the filtered program. *)
val counts_goal = ``sm_count ^L_tm = 0 /\ sm_secs ^L_tm = [] /\ sm_free ^L_tm /\ line_count ^L_tm = 33749 /\
   sm_count ^F_tm = 0 /\ sm_free ^F_tm /\ line_count ^F_tm = 33735 /\ lab_stats ^F_tm = (558,[29],553,1206,[29;31])``;
val counts_thm = store_thm ("refund_lab_sharemem_counts", counts_goal,
  mp_tac info >> simp[filt_info_def] >> CASE_TAC >> simp[] >> strip_tac >> drule lab_link >> strip_tac >> gvs[]);
val line_lemma = prove (``!l. ~line_is_sharemem l <=> (!op re a inst len. l <> Asm (ShareMem op re a) inst len)``,
  Cases >> simp[line_is_sharemem_def] >> CASE_TAC >> simp[]);
val fetch_lemma = prove (``!pc secs. sm_free secs ==> !op re a inst len. asm_fetch_aux pc secs <> SOME (Asm (ShareMem op re a) inst len)``,
  ho_match_mp_tac asm_fetch_aux_ind >> rw[asm_fetch_aux_def] >> fs[sm_free_def, line_lemma] >> rw[] >> fs[]);
val free_thm = store_thm ("sm_free_no_share_mem_inst", ``!secs. sm_free secs ==> no_share_mem_inst secs``,
  rw[no_share_mem_inst_def] >> drule fetch_lemma >> simp[]);
val no_share_thm = store_thm ("refund_lab_no_share_mem", ``no_share_mem_inst ^L_tm /\ no_share_mem_inst ^F_tm``,
  conj_tac >> irule free_thm >> simp[counts_thm]);
(* 2. Region hypothesis for the filtered program, and the single-section control. *)
val hyp_F_goal = ``region_hyp ^G_tm ^OK_tm ^F_tm /\ ^OK_tm 0``;
val walk_F = prove (``hyp_walk1 [29;31] ^F_tm 0 ^F_tm /\ pc_ok [29;31] ^F_tm 0``,
  mp_tac wpair >> simp[filt_walk_def] >> CASE_TAC >> simp[] >> strip_tac >> drule lab_link >> strip_tac >> gvs[]);
val hyp_F = store_thm ("refund_filtered_region_hyp", hyp_F_goal,
  rewrite_tac loc_eqs >> conj_tac
  >- (irule hyp_walk_region_hyp >> rewrite_tac [GSYM walk1_thm, walk_F])
  >- rewrite_tac [walk_F]);
val not29 = store_thm ("refund_filtered_walk_not_closed_29", ``~(hyp_walk1 [29] ^F_tm 0 ^F_tm /\ pc_ok [29] ^F_tm 0)``,
  mp_tac wsingle >> mp_tac wpair >> simp[filt_walk_def] >> CASE_TAC >> simp[] >> rpt strip_tac >> drule lab_link >> strip_tac >> gvs[]);
(* 3. The region invariant is closed under the lab one-step function, for code without shared-memory lines. *)
val inv_def = region_inv2_def; val inv_facts = region2_inv_facts; val inv_next = region2_inv_next;
val inst_thm = asm_inst_mval_inv; val wb_thm = write_bytearray_mval_inv;
val upd_defs = [inc_pc_def, dec_clock_def, upd_pc_def, upd_reg_def, asm_inst_consts];
val pc_tac = first_x_assum irule >> fs[mval_inv_def] >> metis_tac[];
val gen_val_tac = fs[mval_inv_def, APPLY_UPDATE_THM, lab_to_loc_def] >> rw[] >> fs[];
val inst_val_tac = (`mval_inv G D (asm_inst i s)` by (irule inst_thm >> simp[])) >> fs[mval_inv_def];
val ffi_val_tac = fs[mval_inv_def] >> rw[]
   >- (Cases_on `s.io_regs 0 (ExtCall fname) r` >> fs[targetSemTheory.get_reg_value_def])
   >- (irule wb_thm >> conj_tac >- first_assum ACCEPT_TAC >> qexists_tac `D` >> fs[]);
val close_tac = FIRST [first_assum ACCEPT_TAC, gen_val_tac >> NO_TAC, inst_val_tac >> NO_TAC, ffi_val_tac >> NO_TAC, pc_tac >> NO_TAC];
val leaf_tac = strip_tac >> pop_assum (SUBST_ALL_TAC o SYM) >> irule inv_next >> rpt conj_tac >>
               TRY (qexists_tac `s` >> simp upd_defs >> NO_TAC) >> simp upd_defs >> close_tac;
val unfold_tac = rpt strip_tac >> drule inv_facts >> strip_tac >> first_x_assum drule >> simp[step_ok_def, lab_to_loc_def] >> TRY (disch_then strip_assume_tac) >>
                 qpat_x_assum `lab_step _ = _` mp_tac >> simp[lab_step_def, get_pc_value_def];
val split_tac = rpt (TOP_CASE_TAC >> gvs[]);
fun branch_goal line = ``!s s'. region_inv2 G D OK lcode s /\ no_share_mem_inst lcode /\ s.clock <> 0 /\ asm_fetch s = SOME ^line /\ lab_step s = SOME s' ==>
   region_inv2 G D OK lcode s'``;
val branches = [
  ("callffi",  ``LabAsm (CallFFI fname) i bs n``,              unfold_tac >> split_tac >> leaf_tac),
  ("halt",     ``LabAsm Halt i bs n``,                        unfold_tac >> split_tac),
  ("install",  ``LabAsm Install i bs n``,                     unfold_tac),
  ("call",     ``LabAsm (Call lab) i bs n``,                  unfold_tac),
  ("jump",     ``LabAsm (Jump (Lab n1 n2)) i bs n``,          unfold_tac >> split_tac >> leaf_tac),
  ("jumpcmp",  ``LabAsm (JumpCmp c r ri (Lab n1 n2)) i bs n``, unfold_tac >> split_tac >> leaf_tac),
  ("locvalue", ``LabAsm (LocValue r (Lab n1 n2)) i bs n``,    unfold_tac >> split_tac >> leaf_tac),
  ("label",    ``Label k1 k2 k3``,                            unfold_tac),
  ("inst",     ``Asm (Asmi (Inst i)) bs n``,                  unfold_tac >> split_tac >> leaf_tac),
  ("jumpreg",  ``Asm (Asmi (JumpReg r)) bs n``,               unfold_tac >> split_tac >> leaf_tac),
  ("sharemem", ``Asm (ShareMem m r ad) bs n``,                rpt strip_tac >> drule inv_facts >> strip_tac >> gvs[no_share_mem_inst_def, asm_fetch_def])];
val branch_thms = map (fn (nm, line, tac) =>
   (pr ("BRANCH " ^ nm); (prove (branch_goal line, tac) handle e => (pr ("BRANCH_FAILED " ^ nm); raise e)))) branches;
val closed_goal = ``!s s'. region_inv2 G D OK lcode s /\ no_share_mem_inst lcode /\ lab_step s = SOME s' ==> region_inv2 G D OK lcode s'``;
val closed_thm = store_thm ("region2_lab_step", closed_goal,
  rpt strip_tac >> Cases_on `s.clock = 0` >- (qpat_x_assum `lab_step _ = _` mp_tac >> simp[lab_step_def]) >>
  Cases_on `asm_fetch s` >- (qpat_x_assum `lab_step _ = _` mp_tac >> simp[lab_step_def]) >>
  rename1 `asm_fetch s = SOME x` >> Cases_on `x` >>
  TRY (rename1 `Asm aa` >> Cases_on `aa` >> TRY (rename1 `Asmi a2` >> Cases_on `a2`)) >>
  TRY (rename1 `LabAsm aa` >> Cases_on `aa`) >>
  TRY (rename1 `Jump lb` >> Cases_on `lb`) >> TRY (rename1 `JumpCmp _ _ _ lb` >> Cases_on `lb`) >> TRY (rename1 `LocValue _ lb` >> Cases_on `lb`) >>
  FIRST (map (fn th => drule_all th >> disch_then ACCEPT_TAC) branch_thms @
         [qpat_x_assum `lab_step _ = _` mp_tac >> simp[lab_step_def] >> NO_TAC]));
(* 4. The exact-program invariant and its closure. *)
val refund_inv_def = new_definition ("refund_lab_inv_def",
  ``refund_lab_inv (s:(64,'c,'ffi) labSem$state) <=> region_inv2 ^G_tm ^D_tm ^OK_tm ^F_tm s``);
val step_closed_thm = store_thm ("refund_lab_step_closed", ``lab_step_closed (refund_lab_inv : (64,'c,'ffi) labSem$state -> bool)``,
  simp[lab_step_closed_def, refund_inv_def] >> rpt conj_tac >> rpt gen_tac >> strip_tac
  >- (drule inv_facts >> strip_tac >> spose_not_then assume_tac >> first_x_assum drule >> simp[step_ok_def])
  >- (drule inv_facts >> strip_tac >> mp_tac (CONJUNCT2 no_share_thm) >> fs[no_share_mem_inst_def, asm_fetch_def])
  >- (irule closed_thm >> simp[no_share_thm] >> qexists_tac `s` >> simp[]));
(* 5. Initialisation from the published initial-state predicate, for every clock. *)
val init_tm = ``lab_to_targetProof$make_init mc0 ffi0 t0 (m:word64 -> 64 word_loc) dm1 sdm1 ms0 ^F_tm cmp0 cbpos0 cbspace0 coracle0``;
val init_goal = ``targetSem$good_init_state mc0 ms0 bytes0 cbs0 t0 (m:word64 -> 64 word_loc) dm0 sdm0 ==>
   !k. refund_lab_inv (^init_tm with clock := k)``;
val init_thm = store_thm ("refund_lab_inv_init", init_goal,
  strip_tac >> gen_tac >>
  `!a:word64. ?w. m (byte_align a) = Word w` by
     (fs[good_init_state_def] >> rw[] >> qpat_x_assum `!a. ?w. _` (qspec_then `a` strip_assume_tac) >> simp[]) >>
  simp[refund_inv_def, region_inv2_def, lab_to_targetProofTheory.make_init_def, mval_inv_def, hyp_F, load_covered_byte_align_64] >>
  rw[] >> simp[loc_good_def] >> first_x_assum (qspec_then `a` strip_assume_tac) >> simp[]);
(* 6. Target-level exclusion for the exact filtered lab program. No invariant premise remains. *)
val s0_tm = ``lab_to_targetProof$make_init (mc0:(64,'state,'b) machine_config) (ffi0:'ffi ffi_state) t0 (m:word64 -> 64 word_loc) dm1 sdm1 ms0 ^F_tm cmp0 cbpos0 cbspace0 (coracle0:num -> lab_to_target$config # sec list)``;
val exact_goal = ``targetSem$good_init_state mc0 ms0 bytes0 cbs0 t0 (m:word64 -> 64 word_loc) dm0 sdm0 /\
   (!k. FST (labSem$evaluate (^s0_tm with clock := k)) <> Error) /\
   encoder_correct mc0.target /\
   lab_to_targetProof$state_rel (mc0,code2,labs,p) ^s0_tm t1 ms0 /\ code_layout_ok (:64) code2 ==>
   !n. no_install_prefix mc0 ffi0 n ms0``;
val exact_thm = store_thm ("refund_target_install_exclusion", exact_goal,
  strip_tac >>
  mp_tac (target_install_exclusion_conditional |> Q.GENL [`Inv`,`s1`,`mc_conf`,`ms1`,`code2`,`labs`,`p`,`t1`]
            |> ISPECL [``refund_lab_inv : (64,lab_to_target$config,'ffi) labSem$state -> bool``, s0_tm,
                       ``mc0:(64,'state,'b) machine_config``, ``ms0:'state``]
            |> Q.SPECL [`code2`,`labs`,`p`,`t1`]) >>
  impl_tac >- (rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >>
               TRY (rewrite_tac [step_closed_thm, oracle_tie_make_init] >> NO_TAC) >>
               qpat_assum `good_init_state _ _ _ _ _ _ _ _` (fn g => rewrite_tac [MATCH_MP (GEN_ALL init_thm) g])) >>
  simp[lab_to_targetProofTheory.make_init_def]);
(* 7. Negative controls. *)
val bad_state = ``(ARB:(64,'c,'ffi) labSem$state) with <| pc := 0; code := [Section 0 [LabAsm Install ARB [] 0] ARB] |>``;
val trivial_inv_not_closed = store_thm ("trivial_invariant_not_closed",
  ``~lab_step_closed (\s:(64,'c,'ffi) labSem$state. T)``,
  simp[lab_step_closed_def] >> disj1_tac >> qexists_tac `^bad_state` >>
  simp[asm_fetch_def, asm_fetch_aux_def, is_Label_def]);
val sharemem_detected = store_thm ("sharemem_line_detected",
  ``~sm_free [Section 0 [Asm (ShareMem mop r ad) bs n] md] /\ ~no_share_mem_inst [Section 0 [Asm (ShareMem mop r ad) bs n] md] /\
    sm_count [Section 0 [Asm (ShareMem mop r ad) bs n] md] = 1``,
  simp[sm_free_def, sm_count_def, line_is_sharemem_def, no_share_mem_inst_def] >> qexists_tac `0` >>
  simp[asm_fetch_aux_def, is_Label_def]);
val all = [("refund_lab_sharemem_counts", counts_thm), ("sm_free_no_share_mem_inst", free_thm), ("refund_lab_no_share_mem", no_share_thm),
  ("refund_filtered_region_hyp", hyp_F), ("refund_filtered_walk_not_closed_29", not29), ("region2_lab_step", closed_thm),
  ("refund_lab_step_closed", step_closed_thm), ("refund_lab_inv_init", init_thm), ("refund_target_install_exclusion", exact_thm),
  ("trivial_invariant_not_closed", trivial_inv_not_closed), ("sharemem_line_detected", sharemem_detected)];
val _ = List.app (fn (n, th) => (tags n th; let val t = thm_to_string th in pr ("CHECKED " ^ n ^ "\n" ^ String.substring (t, 0, Int.min (2200, size t))) end)) all;
val _ = pr ("DEFINITION refund_lab_inv_def\n" ^ thm_to_string refund_inv_def);
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

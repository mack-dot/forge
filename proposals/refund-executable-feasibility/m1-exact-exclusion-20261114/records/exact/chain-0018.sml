(* Exclusion chain: from the premises of the published compile-level lemma to the target-level installer exclusion. *)
open preamble BasicProvers ffiTheory wordSemTheory labSemTheory labPropsTheory lab_to_targetTheory lab_filterProofTheory
     asmTheory asmSemTheory asmPropsTheory targetSemTheory targetPropsTheory backendPropsTheory lab_to_targetProofTheory
     forge_targetInstallPrefixTheory forge_simZeroCaseTheory forge_simLayoutTheory forge_simRootTheory forge_simReplayTheory
     forge_refundLabFilteredTheory forge_refundExactExclusionTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundExclusionChain";
(* In this heap some bare names of the published text parse to constants of backend_asm. Remove those mappings,
   so the published text parses as in the published build. A constant-origin check at the end fails closed. *)
val _ = List.app (fn c => (let val {Name,Thy,...} = dest_thy_const c in Parse.temp_remove_ovl_mapping Name {Name=Name,Thy=Thy} end handle _ => ()))
          (Theory.constants "backend_asm");
(* The published text uses these names as variables; the refund compile theory defines constants with the same names. *)
val _ = List.app (fn n => (Parse.hide n; ())) ["code", "data", "ffis", "conf", "info", "name"];
fun say0 pfx s g = (print (pfx ^ ": " ^ s ^ "\n"); ALL_TAC g)
val s1 = ``s1:('a,lab_to_target$config,'ffi) labSem$state``;
val IMP_LEMMA = METIS_PROVE [] ``(a ==> b) ==> (b ==> c) ==> (a ==> c)``
fun dbgf tag name (g as (asl, w)) =
  (pr ("SHOWF " ^ tag);
   List.app (fn a => if String.isSubstring name (term_to_string a) andalso size (term_to_string a) < 900 then pr ("  ASM " ^ term_to_string a) else ()) asl;
   pr ("  GOAL " ^ term_to_string w); ALL_TAC g);

(* published line 11 *)
val _ = temp_delsimps ["NORMEQ_CONV"]

(* published line 12 *)
val _ = diminish_srw_ss ["ABBREV"]

(* published line 47 *)
Overload len_no_lab[local] = ``λxs. LENGTH (FILTER ($~ o is_Label) xs)``

(* published line 91 *)
val _ = temp_remove_rules_for_term"step";

(* published line 102 *)
Theorem enc_with_nop_thm[local]:
  enc_with_nop enc (b:asm) bytes =
      ?n. bytes = enc b ++ FLAT (REPLICATE n (enc (asm$Inst Skip)))
Proof
  fs [enc_with_nop_def,LENGTH_NIL]
  \\ IF_CASES_TAC \\ fs [FLAT_REPLICATE_NIL]
  \\ EQ_TAC \\ rw [] THEN1 metis_tac []
  \\ fs [LENGTH_APPEND,LENGTH_FLAT,map_replicate,SUM_REPLICATE]
  \\ full_simp_tac (std_ss++ARITH_ss) [GSYM LENGTH_NIL,MULT_DIV]
QED

(* published line 1338 *)
Theorem UPDATE_COND_PUSH[local]:
  ∀cs rc ar (regs:num -> 'a word) g k v.
    (λa. if MEM a cs ∨ ¬(a < rc) ∨ MEM a ar then regs a else g a)⦇ k ↦ v ⦈ =
    (λa. if MEM a cs ∨ a = k ∨ ¬(a < rc) ∨ MEM a ar
         then (if a = k then v else regs a) else g a)
Proof
  rpt gen_tac \\ once_rewrite_tac[FUN_EQ_THM]
  \\ qx_gen_tac `aa` \\ rewrite_tac[APPLY_UPDATE_THM] \\ BETA_TAC
  \\ Cases_on `aa = k` \\ simp[]
QED

(* published line 3758 *)
Overload all_encd0 = ``λenc l. EVERY (sec_encd0 enc) l``

(* establishing encd0 *)

(* published line 3843 *)
Overload all_length_leq = ``λl. EVERY sec_length_leq l``

(* invariant: label annotated lengths are 0 or 1 *)

(* published line 5134 *)
Overload all_labs_exist = ``λlabs code. EVERY (sec_labs_exist labs) code``

(* Remove tail recursion from zero_labs_acc_exist *)

(* published line 6457 *)
Theorem all_enc_ok_prog_to_bytes_EVEN[local]:
  ∀code n c labs ffi pos.
   EVEN pos ∧
   all_enc_ok c labs ffi pos code ⇒
   EVEN (LENGTH (prog_to_bytes code))
Proof
  fs[prog_to_bytes_MAP]>>
  Induct>>fs[]>>Cases>>
  fs[all_enc_ok_cons]>>rw[EVEN_ADD]>>
  rfs[]>>
  fs[LENGTH_FLAT]>>
  `MAP line_length l = MAP LENGTH (MAP line_bytes l)` by
    metis_tac[lines_ok_MAP_line_byte_length]>>
  pop_assum SUBST_ALL_TAC >>simp[]>>
  metis_tac[EVEN_ADD]
QED

(* published line 8007 *)
Theorem i2w_sub_nat[local,simp]:
  (i2w (&m - &n):'a word) = n2w m - n2w n
Proof
  rw [integerTheory.int_sub,GSYM integer_wordTheory.word_i2w_add,
      GSYM integer_wordTheory.MULT_MINUS_ONE,integer_wordTheory.i2w_pos]
  \\ metis_tac [WORD_NEG_MUL]
QED

(* published line 8015 *)
Theorem i2w_neg_nat[local,simp]:
  (i2w (-&n):'a word) = -n2w n
Proof
  rw [GSYM integer_wordTheory.MULT_MINUS_ONE,integer_wordTheory.i2w_pos]
  \\ metis_tac [WORD_NEG_MUL]
QED

(* published line 10173 *)
Theorem find_index_MAP_w2n[local]:
  !l (x:'a word) n. find_index (w2n x) (MAP w2n l) n = find_index x l n
Proof
  Induct >> simp[find_index_def] >> rw[] >> fs[w2n_11]
QED

(* This is set up for the very first compile call *)

(* published line 10612 *)
Theorem all_enc_ok_pre_filter_skip[local]:
  ∀code c.
  all_enc_ok_pre c code ⇒
  all_enc_ok_pre c (filter_skip code)
Proof
  Induct>>TRY(Cases)>>fs[lab_filterTheory.filter_skip_def]>>rw[]>>
  Induct_on`l`>>fs[]>>rw[]
QED


(* The exclusion conclusion with its three Forge premises, kept opaque while published tactics run. *)
Definition nip_goal_def:
  nip_goal Inv (mc:('a,'state,'b) machine_config) io ms s (code2:sec list) <=>
    (lab_step_closed Inv /\ (!k. Inv (s with clock := k)) /\ code_layout_ok (:'a) code2 ==>
     !n. no_install_prefix mc io n ms)
End

(* Same antecedent chain as the published intermediate form of machine_sem_EQ_sem. *)
Theorem exclusion_mid:
  !mc_conf p ms ^s1 code2 labs t1 Inv.
    encoder_correct mc_conf.target ==>
    state_rel (mc_conf,code2,labs,p) s1 t1 ms ==>
    oracle_tie mc_conf ms s1 ==>
    semantics s1 <> Fail ==>
    nip_goal Inv mc_conf s1.ffi (ms:'state) s1 code2
Proof
  rw[nip_goal_def]
  \\ qspecl_then [`Inv`,`s1`,`mc_conf`,`ms`,`code2`,`labs`,`p`,`t1`] mp_tac
       (Q.GENL [`Inv`,`s1`,`mc_conf`,`ms1`,`code2`,`labs`,`p`,`t1`] target_install_exclusion_conditional)
  \\ impl_tac
  >- (simp[] \\ qpat_x_assum `semantics _ <> Fail` mp_tac \\ simp[labSemTheory.semantics_def] \\ rw[] \\ fs[])
  \\ simp[]
QED


Theorem IMP_state_rel_make_init:
  good_code mc_conf.target.config LN (code: sec list) ∧
   mc_conf_ok mc_conf ∧
   (no_share_mem_inst code ==>
     compiler_oracle_ok coracle labs (LENGTH (prog_to_bytes code2)) mc_conf.target.config mc_conf.ffi_names) ∧
   list_subset (FILTER (\x. ∃s. x= ExtCall s) $
      find_ffi_names code) $ TAKE i mc_conf.ffi_names ∧
   remove_labels clock mc_conf.target.config 0 LN (TAKE i mc_conf.ffi_names) code =
      SOME (code2,labs) /\
   good_init_state mc_conf ms (prog_to_bytes code2)
      cbspace t m dm sdm /\
   get_shmem_info code2 0 [] [] = (new_ffi_names, shmem_info) /\
   new_shmem_info = MAP (\rec. rec with
    <|entry_pc:= w2n (mc_conf.target.get_pc ms) + rec.entry_pc
     ;exit_pc:= w2n (mc_conf.target.get_pc ms) + rec.exit_pc|>) shmem_info /\
   DROP i mc_conf.ffi_names = new_ffi_names /\
   mmio_pcs_min_index mc_conf.ffi_names = SOME i /\
   MAP (\rec. rec.entry_pc) new_shmem_info = DROP i (MAP w2n mc_conf.ffi_entry_pcs) /\
   (mc_conf.mmio_info = ZIP (GENLIST (λindex. index + i) (LENGTH new_shmem_info),
                              (MAP (\rec. (rec.nbytes,
                                Addr rec.addr_reg rec.addr_off,
                                rec.reg, n2w rec.exit_pc)) new_shmem_info))) /\
   no_install_or_no_share_mem code mc_conf.ffi_names /\
   (!bn. bn < cbspace ==>
      ~MEM (n2w bn + n2w (LENGTH (prog_to_bytes code2)) +
             mc_conf.target.get_pc ms) (TAKE i mc_conf.ffi_entry_pcs))
   ==>
   state_rel ((mc_conf: ('a,'state,'b) machine_config),code2,labs,
       mc_conf.target.get_pc ms)
     (make_init mc_conf (ffi:'ffi ffi_state) t m dm sdm ms code
      (compile_lab mc_conf.target.config)
      (mc_conf.target.get_pc ms+n2w(LENGTH(prog_to_bytes code2))) cbspace coracle) t ms
Proof
  rw[] \\ drule $ GEN_ALL remove_labels_thm
  \\ impl_tac >- (
    fs[good_code_def,mc_conf_ok_def]
    \\ rw[lab_lookup_def]>>
    TOP_CASE_TAC>>fs[lookup_def])
  \\ qabbrev_tac `new_shmem_info=MAP (\rec. rec with
      <|entry_pc:=w2n (mc_conf.target.get_pc ms) + rec.entry_pc
       ;exit_pc:=w2n (mc_conf.target.get_pc ms) + rec.exit_pc|>) shmem_info`
  \\ rw[]
  \\ fs[state_rel_def,
        word_loc_val_def,
        make_init_def,
        good_init_state_def,
        mc_conf_ok_def,
        compiler_oracle_ok_def,
        target_configured_def,
        good_code_def,
        start_pc_ok_def]
  \\ rfs[]
  \\ conj_tac >- suspend "ISR1"
  \\ conj_tac >- suspend "ISR2"
  \\ conj_tac >- suspend "ISR3"
  \\ conj_tac >- suspend "ISR4"
  \\ conj_tac >- suspend "ISR5"
  \\ conj_tac >- suspend "ISR6"
  \\ conj_tac >- suspend "ISR7"
  \\ conj_tac >- suspend "ISR8"
  \\ conj_tac >- suspend "ISR9"
  \\ conj_tac >- suspend "ISR10"
  \\ conj_tac >- suspend "ISR11"
  \\ conj_tac >- suspend "ISR12"
  \\ conj_tac >- suspend "ISR13"
  \\ conj_tac >- suspend "ISR14"
  \\ conj_tac >- suspend "ISR15"
  \\ conj_tac >- suspend "ISR16" >- suspend "ISR17"
QED

Resume IMP_state_rel_make_init[ISR1]:
  fs[Abbr ‘new_shmem_info’]>>
  fs[MAP_MAP_o,o_DEF]>>
  qmatch_goalsub_abbrev_tac ‘ZIP (l1,MAP ff _)’>>
  ‘LENGTH l1 = LENGTH (MAP ff shmem_info)’ by fs[Abbr ‘l1’,LENGTH_GENLIST]>>
  fs[ALOOKUP_ZIP_MAP_SND]>>
  `LENGTH shmem_info = LENGTH (DROP i (MAP w2n mc_conf.ffi_entry_pcs))`
    by (qpat_assum `MAP _ shmem_info = DROP _ _` (fn h => assume_tac (Q.AP_TERM `LENGTH` h))>>
        gvs[LENGTH_MAP,LENGTH_DROP])>>
  rw[Abbr ‘l1’]
  >- (‘shmem_info ≠ []’ by (strip_tac>>fs[])>>
      irule_at Any ALOOKUP_ALL_DISTINCT_MEM>>
      simp[MEM_ZIP,MAP_ZIP,ALL_DISTINCT_GENLIST,EL_GENLIST]>>
      qexists_tac ‘index - i’>>
      reverse conj_asm1_tac>- fs[EL_GENLIST]>>fs[LENGTH_MAP,LENGTH_DROP])>>
  rewrite_tac[ALOOKUP_FAILS]>>
  rpt strip_tac>>
  gvs[NOT_LESS,NOT_LESS_EQUAL,MEM_ZIP]
QED

Resume IMP_state_rel_make_init[ISR2]:
  rpt strip_tac
  \\ irule (REWRITE_RULE [post_ffi_asm_def] ffi_interfer_ok_post_ffi_asm)
  \\ rpt conj_tac \\ fs[]
  >- (drule mmio_pcs_min_index_is_SOME \\ gvs[])
  >- (conj_tac
      >- (imp_res_tac evaluatePropsTheory.call_FFI_LENGTH \\ simp[])
      \\ strip_tac \\ gvs[call_FFI_def, AllCaseEqs()])
  \\ qexists_tac `mc_conf.target.get_pc ms`
  \\ simp[]
QED

Resume IMP_state_rel_make_init[ISR3]:
  rpt strip_tac
  \\ irule (SIMP_RULE (srw_ss()) [post_install_asm_def,post_ffi_asm_def,
                                  LET_THM,UPDATE_COND_PUSH]
              install_interfer_ok_post_install_asm)
  \\ simp[]
  \\ qexistsl_tac [`cbspace`,`mc_conf.target.get_pc ms`]
  \\ simp[]
QED

Resume IMP_state_rel_make_init[ISR4]:
  ntac 2 strip_tac >>
  pairarg_tac >> fs[]>>
  drule_then assume_tac code_similar_sym >>
  drule_all_then assume_tac code_similar_IMP_both_no_share_mem >>
  fs[] >>
  qpat_x_assum`!k. _ (coracle k)`(qspec_then`k` assume_tac)>>rfs[]>>
  strip_tac>>fs[]
QED

Resume IMP_state_rel_make_init[ISR5]:
  metis_tac[EVEN,all_enc_ok_prog_to_bytes_EVEN]
QED

Resume IMP_state_rel_make_init[ISR6]:
  metis_tac[list_subset_TAKE,list_subset_trans]
QED

Resume IMP_state_rel_make_init[ISR7]:
  metis_tac[EVEN,all_enc_ok_prog_to_bytes_EVEN]
QED

Resume IMP_state_rel_make_init[ISR8]:
  imp_res_tac mmio_pcs_min_index_is_SOME>>
  rpt strip_tac>>fs[]>>
  fs[get_ffi_index_def,backendPropsTheory.the_eqn]>>
  imp_res_tac find_index_MEM>>
  first_x_assum $ qspecl_then [‘0’] assume_tac>>gvs[]
QED

Resume IMP_state_rel_make_init[ISR9]:
  simp[word_loc_val_byte_def,case_eq_thms]
  \\ metis_tac[SUBSET_DEF,word_loc_val_def]
QED

Resume IMP_state_rel_make_init[ISR10]:
  metis_tac[word_add_n2w]
QED

Resume IMP_state_rel_make_init[ISR11]:
  simp[bytes_in_mem_def]
QED

Resume IMP_state_rel_make_init[ISR12]:
  rpt strip_tac >>
  `MAP (\rec. n2w rec.entry_pc) new_shmem_info = DROP i (mc_conf.ffi_entry_pcs : 'a word list)` by (
    qpat_x_assum `MAP _ new_shmem_info = DROP i (MAP w2n _)` (fn h =>
      mp_tac (AP_TERM ``MAP (n2w:num -> 'a word)`` h)) >>
    simp[MAP_MAP_o, o_DEF, n2w_w2n, MAP_DROP]) >>
  qpat_x_assum `!bn. bn < cbspace ==> _` $ imp_res_tac >>
  gvs[MEM_EL] >>
  drule_then assume_tac $ cj 1 mmio_pcs_min_index_is_SOME>>
  gvs[LENGTH_TAKE] >>
  first_x_assum $ qspec_then`n` assume_tac >>
  Cases_on `n < i`
  >- gvs[EL_TAKE] >>
  `i <= n` by decide_tac >>
  gvs[] >>
  drule get_shmem_info_thm >>
  disch_then $ qspecl_then [`0`,`[]`,`[]`] assume_tac >>
  gvs[UNZIP_MAP,MAP_GENLIST,combinTheory.o_DEF,ZIP_MAP_FST_SND_EQ,MAP_MAP_o,
    Abbr`new_shmem_info`,EL_MAP] >>
  qspecl_then [`n - i`, `i`,`mc_conf.ffi_entry_pcs`]
    assume_tac $ GSYM EL_DROP >>
  gvs[] >>
  pop_assum kall_tac >>
  qpat_x_assum `_ = DROP i mc_conf.ffi_entry_pcs` $ assume_tac o GSYM >>
  fs[GSYM word_add_n2w]>>
  qmatch_assum_abbrev_tac `DROP i mc_conf.ffi_entry_pcs = MAP offset_func flatten_genlist` >>
  gvs[] >>
  `n - i < LENGTH (MAP offset_func flatten_genlist)` by (
    qpat_x_assum `DROP i mc_conf.ffi_entry_pcs = _` $ assume_tac o GSYM >>
    asm_rewrite_tac[LENGTH_DROP] >>
    simp[]
  ) >>
  gvs[EL_MAP,Abbr`offset_func`] >>
  drule_all genlist_line_to_info_entry_pc_max >>
  strip_tac >>
  drule_then (qspec_then `n-i` assume_tac) $ iffLR EVERY_EL >>
  gvs[Abbr`flatten_genlist`] >>
  qmatch_asmsub_abbrev_tac `entry_pc' < pos_val _ _ _` >>
  drule_then (fn t =>
    gvs[t,addressTheory.word_arith_lemma1]) $
    GEN_ALL pos_val_num_pcs
QED

Resume IMP_state_rel_make_init[ISR13]:
  drule pos_val_0 \\ simp[]
QED

Resume IMP_state_rel_make_init[ISR14]:
  metis_tac[code_similar_sec_labels_ok]
QED

Resume IMP_state_rel_make_init[ISR15]:
  fs[ffi_interfer_ok_def]
  \\ gvs[share_mem_state_rel_def]
  \\ rpt strip_tac
  \\ gvs[IMP_CONJ_THM, AND_IMP_INTRO]
  \\ first_x_assum $ qspecl_then [`ms2`, `k`, `index`, `new_bytes`, `t1`, `B`, `C`] mp_tac
  \\ gvs[] >> strip_tac>>fs[]>>
  drule mmio_pcs_min_index_is_SOME>>
  strip_tac>>fs[]>>
  first_x_assum $ qspec_then ‘index’ assume_tac>>gvs[]>>
  TOP_CASE_TAC>>fs[]
QED

Resume IMP_state_rel_make_init[ISR16]:
  simp[share_mem_domain_code_rel_def]
  \\ fs[MAP_MAP_o,o_DEF,ELIM_UNCURRY]
  \\ drule $ GEN_ALL get_shmem_info_ok_lemma
  \\ disch_then $ qspecl_then [
      `w2n (mc_conf.target.get_pc ms)`,`new_shmem_info`,`mc_conf.ffi_names`,
      `TAKE i mc_conf.ffi_names`] mp_tac
  \\ gvs[]
  \\ impl_tac
  >- (
    drule mmio_pcs_min_index_is_SOME >>
    strip_tac >>
    reverse $ rw[EVERY_EL]
   >- (
      qpat_abbrev_tac `info = get_shmem_info _ _ _ _` >>
      first_x_assum $ assume_tac o GSYM o ONCE_REWRITE_RULE[markerTheory.Abbrev_def] >>
      Cases_on `info` >>
      drule $ GEN_ALL get_shmem_info_PREPEND >>
      gvs[] >>
      strip_tac >>
      drule $ GEN_ALL get_shmem_info_init_pc_offset >>
      disch_then $ qspec_then `w2n (mc_conf.target.get_pc ms)` mp_tac >>
      strip_tac >>
      gvs[markerTheory.Abbrev_def] >>
      metis_tac[TAKE_DROP] ) >>
    first_x_assum $ mp_tac o GSYM >>
    spose_not_then assume_tac >>fs[]>>
    qpat_x_assum`∀s. EL _ (TAKE i mc_conf.ffi_names) ≠ _` $ mp_tac >>
    fs[EL_TAKE]
  )
  \\ rw[]
  >- (
    qpat_x_assum `!pc op re a inst len. asm_fetch_aux _ _ = _ ==> ?i._` $ imp_res_tac
    \\ qexists `index + i`
    \\ drule find_index_LESS_LENGTH
    \\ fs[GSYM word_add_n2w]
    \\ `LENGTH (MAP (\rec. (n2w rec.entry_pc):'a word) new_shmem_info) =
        LENGTH mc_conf.ffi_entry_pcs - i`
          by (qpat_x_assum `MAP _ new_shmem_info = DROP _ _` (fn h =>
                assume_tac (Q.AP_TERM `LENGTH` h)) >>
              gvs[LENGTH_MAP,LENGTH_DROP])
    \\ fs[LENGTH_MAP,LESS_SUB_ADD_LESS,EL_MAP,LENGTH_TAKE]
    \\ strip_tac
    \\ `find_index (n2w (pos_val pc 0 code2) + mc_conf.target.get_pc ms)
          (DROP i mc_conf.ffi_entry_pcs) 0 = SOME index` by (
      ONCE_REWRITE_TAC[GSYM find_index_MAP_w2n] >>
      simp[MAP_DROP] >>
      `w2n (mc_conf.target.get_pc ms) + pos_val pc 0 code2 < dimword(:'a)` by (
        drule find_index_is_MEM >> strip_tac >>
        imp_res_tac MEM_DROP_IMP >>
        fs[MEM_MAP] >> metis_tac[w2n_lt]) >>
      ONCE_REWRITE_TAC[GSYM n2w_w2n |> Q.ISPEC `mc_conf.target.get_pc ms`] >>
      rewrite_tac[word_add_n2w, w2n_n2w] >>
      `pos_val pc 0 code2 < dimword(:'a)` by fs[] >>
      simp[] >>
      ONCE_REWRITE_TAC[ADD_COMM] >>
      first_x_assum ACCEPT_TAC)
    \\ drule find_index_shift >> fs[]
    \\ disch_then $ qspec_then `i` assume_tac
    \\ `~MEM (n2w (pos_val pc 0 code2) + mc_conf.target.get_pc ms)
          (TAKE i mc_conf.ffi_entry_pcs)` by (
      `LENGTH (prog_to_bytes code2) < dimword(:'a)` by gvs[] >>
      drule $ GEN_ALL asm_fetch_NOT_ffi_entry_pcs >>
      rpt $ disch_then $ drule_at Any >>
      disch_then $ qspec_then `0` mp_tac >>
      simp[line_bytes_def, line_length_def] >>
      impl_tac >- (
        drule $ GEN_ALL enc_ok_LENGTH_GT_0 >>
        drule_all $ GEN_ALL all_enc_ok_asm_fetch_aux_IMP_line_ok >>
        gvs[line_ok_def,line_length_def,enc_with_nop_thm] >>
        rpt strip_tac >> gvs[] >>
        first_x_assum $ qspec_then `Inst (Mem op re a)` assume_tac >> gvs[]) >>
      metis_tac[WORD_ADD_COMM, WORD_ADD_ASSOC])
    \\ `find_index (n2w (pos_val pc 0 code2) + mc_conf.target.get_pc ms)
          (TAKE i mc_conf.ffi_entry_pcs) 0 = NONE` by
      fs[GSYM find_index_NOT_MEM]
    \\ qspecl_then [
        `TAKE i (mc_conf: ('a,'state,'b) machine_config).ffi_entry_pcs`,
        `DROP i (mc_conf: ('a,'state,'b) machine_config).ffi_entry_pcs`,
        `n2w (pos_val pc 0 code2) + (mc_conf.target.get_pc ms: 'a word)`,
        `0`] assume_tac find_index_APPEND
    \\ gvs[AllCaseEqs()]
    \\ gvs[ELIM_UNCURRY,shmem_info_num_component_equality]>>
    irule ALOOKUP_ALL_DISTINCT_MEM>>
    qmatch_goalsub_abbrev_tac `ZIP (l1, l2)`>>
    `LENGTH l1 = LENGTH l2` by (unabbrev_all_tac>>fs[LENGTH_GENLIST,LENGTH_MAP])>>
    fs[MAP_ZIP,MEM_ZIP]>>unabbrev_all_tac>>fs[]>>
    fs[ALL_DISTINCT_GENLIST]>>fs[MAP_MAP_o,o_DEF]>>gvs[]>>simp[EL_MAP]>>
    qexists_tac `index`>>fs[EL_MAP]>>
    fs[EL_GENLIST]>>
    Cases_on `a` >> simp[n2w_w2n] >>
    rewrite_tac[GSYM word_add_n2w] >> simp[n2w_w2n])
  >- (
    qpat_x_assum `!pc line. asm_fetch_aux _ _ = _ /\ _ ==> _` imp_res_tac
    \\ simp[IN_DISJOINT] >> rpt strip_tac >> spose_not_then assume_tac >> gvs[]
    \\ `LENGTH (prog_to_bytes code2) < dimword(:'a)` by gvs[]
    (* TAKE case: asm_fetch_NOT_ffi_entry_pcs *)
    \\ `~MEM (mc_conf.target.get_pc ms + n2w a + n2w (pos_val pc 0 code2))
         (TAKE i mc_conf.ffi_entry_pcs)` by (
      irule asm_fetch_NOT_ffi_entry_pcs >> gvs[] >> metis_tac[])
    (* Get MEM in DROP via TAKE_DROP *)
    \\ `MEM (mc_conf.target.get_pc ms + n2w a + n2w (pos_val pc 0 code2))
         (DROP i mc_conf.ffi_entry_pcs)` by (
      ONCE_REWRITE_TAC[WORD_ADD_COMM] >>
      qpat_x_assum `MEM _ _` mp_tac >>
      `mc_conf.ffi_entry_pcs = TAKE i mc_conf.ffi_entry_pcs ++ DROP i mc_conf.ffi_entry_pcs`
        by simp[TAKE_DROP] >>
      pop_assum (fn h => ONCE_REWRITE_TAC[h]) >>
      rewrite_tac[MEM_APPEND] >> strip_tac >> gvs[])
    (* Get w2n version in DROP *)
    \\ `MEM (w2n (mc_conf.target.get_pc ms + n2w a + n2w (pos_val pc 0 code2)))
         (DROP i (MAP w2n mc_conf.ffi_entry_pcs))` by (
      rewrite_tac[GSYM MAP_DROP] >>
      irule MEM_MAP_f >> first_x_assum ACCEPT_TAC)
    (* w2n x >= w2n(get_pc ms) from new_shmem_info structure *)
    \\ `w2n (mc_conf.target.get_pc ms) <=
       w2n (mc_conf.target.get_pc ms + n2w a + n2w (pos_val pc 0 code2))` by (
      qpat_x_assum `MEM _ (DROP i (MAP w2n _))` mp_tac >>
      qpat_x_assum `MAP _ new_shmem_info = DROP i _` (SUBST1_TAC o GSYM) >>
      qpat_x_assum `Abbrev (new_shmem_info = _)` mp_tac >>
      simp[markerTheory.Abbrev_def] >> strip_tac >>
      ASM_REWRITE_TAC[] >>
      simp[MAP_MAP_o, o_DEF, MEM_MAP] >>
      strip_tac >> simp[])
    (* a + pos_val < LENGTH prog *)
    \\ `a + pos_val pc 0 code2 < LENGTH (prog_to_bytes code2)` by (
      imp_res_tac asm_fetch_aux_pos_val_SUC >>
      pop_assum $ qspec_then `0` assume_tac >>
      drule pos_val_bound >>
      disch_then $ qspecl_then [`pc+1`,`0`] assume_tac >>
      gvs[])
    (* Apply DISJOINT to get contradiction *)
    \\ qpat_x_assum `DISJOINT _ _` (mp_tac o REWRITE_RULE[DISJOINT_ALT])
    \\ disch_then $ qspec_then `w2n (mc_conf.target.get_pc ms + n2w a + n2w (pos_val pc 0 code2))` mp_tac
    \\ impl_tac >- (
      rewrite_tac[GSYM MAP_DROP] >>
      irule MEM_MAP_f >> first_x_assum ACCEPT_TAC)
    \\ strip_tac >> pop_assum mp_tac >> simp[]
    \\ qexists_tac `a` >> simp[]
    (* Prove w2n equality: w2n(n2w a + n2w(pos_val) + get_pc ms) = a + (w2n(pc) + pos_val) *)
    \\ ONCE_REWRITE_TAC[WORD_ADD_COMM] >> rewrite_tac[word_add_n2w]
    \\ `a + pos_val pc 0 code2 < dimword(:'a)` by fs[]
    \\ DEP_REWRITE_TAC[w2n_add_2] >> simp[w2n_n2w]
    (* Show no overflow: a + pos_val + w2n(pc) < dimword *)
    \\ spose_not_then assume_tac >> gvs[NOT_LESS]
    \\ qpat_x_assum `w2n _ <= _` mp_tac >> simp[NOT_LESS_EQUAL]
    \\ ONCE_REWRITE_TAC[WORD_ADD_COMM] >> rewrite_tac[word_add_n2w]
    \\ simp[word_add_def, w2n_n2w]
    \\ `w2n (mc_conf.target.get_pc ms) < dimword(:'a)` by simp[w2n_lt]
    \\ `a + (w2n (mc_conf.target.get_pc ms) + pos_val pc 0 code2) < 2 * dimword(:'a)` by fs[]
    \\ `(a + (w2n (mc_conf.target.get_pc ms) + pos_val pc 0 code2)) MOD dimword(:'a) =
       a + (w2n (mc_conf.target.get_pc ms) + pos_val pc 0 code2) - dimword(:'a)` by (
      `0 < dimword(:'a)` by simp[] >>
      drule_all SUB_MOD >> strip_tac >>
      `a + (w2n (mc_conf.target.get_pc ms) + pos_val pc 0 code2) - dimword(:'a) < dimword(:'a)` by fs[] >>
      imp_res_tac LESS_MOD >> fs[])
    \\ simp[] >> fs[])
QED

Resume IMP_state_rel_make_init[ISR17]:
  drule_then (drule_then irule) $ GEN_ALL code_similar_IMP_both_no_install_or_no_share_mem
QED

Finalise IMP_state_rel_make_init;

(* The published pipeline of semantics_make_init, applied to the exclusion form. *)
val mid = exclusion_mid |> SPEC_ALL |> UNDISCH;
val nip_make_init =
  mid |> Q.GEN `s1` |> Q.GEN `p`
  |> Q.GEN `t1` |> Q.SPEC `t`
  |> Q.SPEC `(mc_conf: ('a,'state,'b) machine_config).target.get_pc ms`
  |> Q.SPEC `make_init (mc_conf: ('a,'state,'b) machine_config)
       ffi t m dm sdm (ms:'state) code
       (compile_lab mc_conf.target.config) (mc_conf.target.get_pc ms + (n2w (LENGTH (prog_to_bytes (code2:labLang$prog)))))
       cbspace coracle`
  |> SIMP_RULE std_ss [make_init_simp]
  |> MATCH_MP (MATCH_MP IMP_LEMMA IMP_state_rel_make_init)
  |> DISCH_ALL |> REWRITE_RULE [AND_IMP_INTRO,GSYM CONJ_ASSOC]
  |> REWRITE_RULE [oracle_tie_make_init];
val _ = save_thm ("nip_make_init", nip_make_init);
val _ = pr ("NIP_MAKE_INIT\n" ^ thm_to_string nip_make_init);
(* Fail closed: the antecedents must be those of the published semantics_make_init, before and after SRULE. *)
val _ = if aconv (fst (dest_imp (concl nip_make_init))) (fst (dest_imp (concl semantics_make_init)))
        then pr "FIDELITY antecedent of nip_make_init equals antecedent of the published semantics_make_init"
        else raise Fail "Antecedent differs from the published semantics_make_init";
val nip_use = SRULE [] nip_make_init;
val pub_use = SRULE [] semantics_make_init;
val _ = if aconv (fst (dest_imp (concl nip_use))) (fst (dest_imp (concl pub_use)))
        then pr "FIDELITY simplified antecedents equal"
        else raise Fail "Simplified antecedent differs from the published one";


Theorem compile_install_exclusion:
  mc_conf_ok (mc_conf:('a,'state,'b) machine_config) ∧
  (no_share_mem_inst code ==>
    compiler_oracle_ok coracle c'.labels (LENGTH bytes) (asm_conf:asm_config) mc_conf.ffi_names) ∧
  (* Assumptions on input code *)
  good_code mc_conf.target.config LN code ∧
  (* Config state *)
  asm_conf = mc_conf.target.config /\
  c.labels = LN ∧ c.pos = 0 ∧
  lab_to_target$compile asm_conf (c:lab_to_target$config) code = SOME (bytes,c') /\
  (* FFI is either given or computed *)
  c'.ffi_names = SOME mc_conf.ffi_names /\
  good_init_state mc_conf ms bytes cbspace t m dm sdm /\
  (* set up mmio_info and ffi_entry_pcs for mmio *)
  MAP (\rec. w2n (mc_conf.target.get_pc ms) + rec.entry_pc) c'.shmem_extra =
    DROP i (MAP w2n mc_conf.ffi_entry_pcs) /\
  mc_conf.mmio_info = ZIP (GENLIST (λindex. index + i) (LENGTH c'.shmem_extra),
                            (MAP (\rec. (rec.nbytes, Addr rec.addr_reg rec.addr_off,
                              rec.reg, n2w rec.exit_pc + mc_conf.target.get_pc ms))
                                 c'.shmem_extra)) /\
  no_install_or_no_share_mem code mc_conf.ffi_names /\
  (mmio_pcs_min_index mc_conf.ffi_names = SOME i) /\
  (* to avoid the ffi_entry_pc wraps around and overlaps with the program or code buffer *)
  cbspace + LENGTH bytes + ffi_offset * (i + 3) < dimword (:'a) /\
  (* the original ffi names provided does not contain MappedRead or MappedWrite *)
  (!ffis. c.ffi_names = SOME ffis ==> EVERY (λx. ∃s. x = ExtCall s) ffis) /\
  semantics (make_init mc_conf ffi t m dm sdm ms code
    (lab_to_target$compile asm_conf) (mc_conf.target.get_pc ms+n2w(LENGTH bytes)) cbspace
    coracle
  ) <> Fail /\
  lab_step_closed Inv /\
  (!k. Inv (make_init mc_conf ffi t m dm sdm ms (filter_skip code)
              (compile_lab mc_conf.target.config) (mc_conf.target.get_pc ms + n2w (LENGTH bytes)) cbspace
              ((\(a,b). (a,filter_skip b)) o coracle) with clock := k)) ==>
  !n. no_install_prefix mc_conf ffi n ms
Proof
  fs[compile_def,compile_lab_def]>>
  pairarg_tac \\ fs[] \\
  CASE_TAC>>fs[]>>
  CASE_TAC>>fs[]>>
  rw[]>>
  `compile mc_conf.target.config =
    (λc p. compile_lab mc_conf.target.config c (filter_skip p)) ` by
    fs[FUN_EQ_THM,compile_def]>>
  pop_assum SUBST_ALL_TAC>>
  gvs[] >>
  fs[GSYM make_init_filter_skip]>>
  SIMP_TAC (bool_ss) [Once WORD_ADD_COMM]>>
  qabbrev_tac `info=get_shmem_info q 0 [] []` >>
  first_x_assum $ mp_tac o GSYM o ONCE_REWRITE_RULE[markerTheory.Abbrev_def] >>
  pairarg_tac >>
  strip_tac >>
  gvs[ELIM_UNCURRY] >>
  qsuff_tac `nip_goal Inv mc_conf ffi ms
      (make_init mc_conf ffi t m dm sdm ms (filter_skip code) (compile_lab mc_conf.target.config)
         (n2w (LENGTH (prog_to_bytes q)) + mc_conf.target.get_pc ms) cbspace ((\(a,b). (a,filter_skip b)) o coracle)) q`
  >- (rewrite_tac[nip_goal_def] >> disch_then match_mp_tac >> rpt conj_tac
      >- first_assum ACCEPT_TAC
      >- (gen_tac >> qpat_x_assum `!k. Inv _` (qspec_then `k` mp_tac) >> simp[ELIM_UNCURRY])
      >- (fs[code_layout_ok_def, lab_to_targetTheory.ffi_offset_def])) >>
  rpt (qpat_x_assum `lab_step_closed _` kall_tac) >> rpt (qpat_x_assum `!k. Inv _` kall_tac) >>
  match_mp_tac (GEN_ALL nip_use) >>

  fs[sec_ends_with_label_filter_skip,all_enc_ok_pre_filter_skip]>>
  fs[find_ffi_names_filter_skip,GSYM PULL_EXISTS,MAP_MAP_o,o_DEF]>>
  qpat_x_assum `_ ++ _ = mc_conf.ffi_names` $ assume_tac o GSYM >>
  conj_tac >- fs[mc_conf_ok_def] >>
  conj_tac >- (
    fs[good_code_def] >>
    fs[sec_ends_with_label_filter_skip,all_enc_ok_pre_filter_skip]>>
    fs[GSYM ALL_EL_MAP])>>
  rename1`_ = SOME (q,r)` >>
  qexists `r` >>
  fs[good_init_state_def] >>
  conj_tac >- (
    rpt strip_tac >>
    fs[compiler_oracle_ok_def,no_share_mem_filter_skip] >>
    rw[] >>
    rename1 `coracle k` >>
    qpat_x_assum `!k. _ (coracle k)` (qspec_then `k` assume_tac)>>rfs[]>>
    pairarg_tac \\ fs[] \\
    pairarg_tac \\ fs[] \\ rw[] \\
    fs[good_code_def]>>
    fs[sec_ends_with_label_filter_skip,all_enc_ok_pre_filter_skip]>>
    fs[GSYM ALL_EL_MAP,no_share_mem_filter_skip]
  )>>
  qmatch_asmsub_rename_tac `mmio_pcs_min_index (ffis ++ rest) = SOME i` >>
  `mmio_pcs_min_index (ffis ++ rest) = SOME (LENGTH ffis)` by (
    Cases_on`c.ffi_names`
    >- (
      gvs[] >>
      drule get_shmem_info_MappedRead_or_MappedWrite >>
      simp[Sh_not_Ext] >>
      strip_tac >>
      drule $ GEN_ALL mmio_pcs_min_index_APPEND_thm >>
      qmatch_assum_abbrev_tac`mmio_pcs_min_index (ffi' ++ _) = SOME _` >>
      disch_then $ qspec_then ‘ffi'’ mp_tac>>impl_tac >-
       (irule find_ffi_names_EVERY>>
        gvs[Abbr`ffi'`]>>metis_tac[])>>
      strip_tac>>fs[]
    ) >>
      gvs[] >>
      drule get_shmem_info_MappedRead_or_MappedWrite >>
      simp[Sh_not_Ext] >>
      strip_tac >>
      drule $ GEN_ALL mmio_pcs_min_index_APPEND_thm >>
      disch_then $ qspec_then ‘ffis’ mp_tac>>fs[]
  ) >>
  gvs[] >>
  conj_tac >- (
    gvs[TAKE_LENGTH_APPEND] >>
    Cases_on `c.ffi_names` >- (
      mp_tac find_ffi_names_EVERY>>
      disch_then $ qspec_then ‘code’ mp_tac>>
      simp[GSYM FILTER_EQ_ID]>>strip_tac>>fs[list_subset_refl])>>
    gvs[list_subset_TAKE,list_subset_refl]>>
    irule list_subset_trans>>
    last_assum $ irule_at Any>>
    mp_tac find_ffi_names_EVERY>>
    simp[GSYM FILTER_EQ_ID]>>
    strip_tac>>fs[list_subset_refl]
  ) >>
  conj_tac >- (
    qexists `c.init_clock` >>
    gvs[TAKE_LENGTH_APPEND]
  ) >>
  simp[DROP_LENGTH_APPEND,TAKE_LENGTH_APPEND] >>
  simp[GSYM word_add_n2w, n2w_w2n]>>
  simp[no_install_or_no_share_mem_filter_skip] >>
  gvs[start_pc_ok_def,MEM_EL]>>
  rw[] >>
  spose_not_then assume_tac >>
  gvs[] >>
  TRY (qpat_x_assum `semantics _ = Fail` mp_tac >> fs[ELIM_UNCURRY] >> NO_TAC) >>
  last_x_assum $ drule_then assume_tac >>
  rw[]>>
  gvs[find_index_LEAST_EL] >>
  qpat_x_assum `(LEAST n'. _) = n` mp_tac >>
  DEEP_INTRO_TAC WhileTheory.LEAST_ELIM >>
  conj_tac
  >- (fs[MEM_EL] >> metis_tac[]) >>
  simp[] >>
  strip_tac >>
  spose_not_then kall_tac >>
  first_x_assum $ assume_tac o GSYM >>
  gvs[addressTheory.word_arith_lemma1,EL_TAKE] >>
  qpat_x_assum `n2w _ = -n2w _ ` $ assume_tac >>
  drule $ iffLR o GSYM $ cj 1 addressTheory.WORD_EQ_ADD_CANCEL >>
  disch_then $ qspec_then `n2w (ffi_offset * (n + 3))` mp_tac >>
  first_x_assum kall_tac >>
  PURE_REWRITE_TAC[cj 1 addressTheory.word_arith_lemma1,WORD_LITERAL_ADD,WORD_ADD_COMM] >>
  simp[] >>
  `cbspace + (LENGTH (prog_to_bytes q) + ffi_offset * (n + 3)) < dimword (:'a)`
    by (
      drule_at_then Any irule LESS_TRANS >>
      simp[ADD_COMM,ffi_offset_def]
  ) >>
  `bn  + (LENGTH (prog_to_bytes q) + ffi_offset * (n + 3)) < dimword (:'a)`
    by (
      drule_at_then (Pos $ el 2) irule LESS_TRANS >>
      simp[LESS_MONO_ADD]
  ) >>
  gvs[ffi_offset_def]
QED


val _ = pr "GENERIC_CHAIN_PROVED";
(* Exact instance: code := the exact refund lab program, Inv := the exact-program invariant.
   The two Forge premises are discharged; the remaining premises are those of the published compile-level lemma. *)
val L_tm = ``SND (SND (backend$to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))``;
val gen64 = INST_TYPE [alpha |-> ``:64``] compile_install_exclusion;
fun fv th n = valOf (List.find (fn v => fst (dest_var v) = n) (free_vars (concl th)));
val inv_v = fv gen64 "Inv"; val code_v = fv gen64 "code";
val inv_c = let val c0 = ``refund_lab_inv`` in inst (match_type (type_of c0) (type_of inv_v)) c0 end;
val inst_thm = INST [inv_v |-> inv_c, code_v |-> L_tm] gen64;
val (ante, conc) = dest_imp (concl inst_thm);
val cs = strip_conj ante;
val pub_cs = List.take (cs, length cs - 2);
val _ = if same_const (rator (el 1 (List.drop (cs, length cs - 2)))) ``lab_step_closed`` then () else raise Fail "Unexpected premise order";
val exact_goal = mk_imp (list_mk_conj pub_cs, conc);
val exact_thm = store_thm ("refund_compile_install_exclusion", exact_goal,
  strip_tac >> match_mp_tac inst_thm >> rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >>
  TRY (rewrite_tac [refund_lab_step_closed] >> NO_TAC) >>
  qpat_assum `good_init_state _ _ _ _ _ _ _ _` (fn g => rewrite_tac [MATCH_MP (GEN_ALL refund_lab_inv_init) g]));
val _ = (tags "refund_compile_install_exclusion" exact_thm; pr ("CHECKED refund_compile_install_exclusion\n" ^ thm_to_string exact_thm));
(* Fidelity: the exact theorem has the premises of the generic one, minus the two Forge premises, at the exact program. *)
val _ = pr ("EXACT_PREMISE_COUNT " ^ Int.toString (length pub_cs) ^ " GENERIC_PREMISE_COUNT " ^ Int.toString (length cs));
val _ = if List.exists (fn c => can (find_term (fn x => aconv x inv_c orelse (is_const x andalso fst (dest_const x) = "lab_step_closed"))) c) pub_cs
        then raise Fail "An invariant premise remains" else pr "CONTROL_OK no invariant premise remains in the exact theorem";

val _ = List.app (fn n => let val th = DB.fetch "forge_refundExclusionChain" n in tags n th; pr ("CHECKED " ^ n ^ "\n" ^ thm_to_string th) end)
  ["exclusion_mid", "IMP_state_rel_make_init", "compile_install_exclusion"];
fun origin_check n = let val th = DB.fetch "forge_refundExclusionChain" n
      val bad = List.filter (fn c => let val {Thy,...} = dest_thy_const c in Thy = "backend_asm" orelse Thy = "forge_refundArm8Compile" end) (find_terms is_const (concl th))
  in if null bad then pr ("ORIGIN_OK " ^ n) else raise Fail ("Statement of " ^ n ^ " uses an unexpected constant: " ^ term_to_string (hd bad)) end;
val _ = List.app origin_check ["exclusion_mid", "IMP_state_rel_make_init", "nip_make_init", "compile_install_exclusion", "refund_compile_install_exclusion"];
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

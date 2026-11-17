val say = say0 "compile_no_install_prefix";

Theorem compile_no_install_prefix:
  lab_step_closed Inv ==>
  !^s1 res (mc_conf: ('a,'state,'b) machine_config) s2 code2 labs t1 ms1.
     oracle_tie mc_conf ms1 s1 /\
     (evaluate s1 = (res,s2)) /\ (res <> Error) /\
     encoder_correct mc_conf.target /\
     state_rel (mc_conf,code2,labs,p) s1 t1 ms1 ==>
     Inv s1 /\ code_layout_ok (:'a) code2 ==>
     no_install_prefix mc_conf s1.ffi s1.clock ms1
Proof
  strip_tac
  \\ HO_MATCH_MP_TAC labSemTheory.evaluate_ind \\ NTAC 2 STRIP_TAC
  \\ ONCE_REWRITE_TAC [labSemTheory.evaluate_def]
  \\ Cases_on `s1.clock = 0` \\ full_simp_tac(srw_ss())[]
  \\ REPEAT (Q.PAT_X_ASSUM `T` (K ALL_TAC)) \\ REPEAT STRIP_TAC
  THEN1 (qpat_assum `state_rel _ _ _ _` (mp_then Any mp_tac state_rel_no_install_prefix_layout) \\ simp[no_install_prefix_zero])
  \\ drule state_rel_ctx \\ strip_tac
  \\ Cases_on `asm_fetch s1` \\ full_simp_tac(srw_ss())[]
  \\ Cases_on `x` \\ full_simp_tac(srw_ss())[] \\ Cases_on `a` \\ full_simp_tac(srw_ss())[]
  \\ REPEAT (Q.PAT_X_ASSUM `T` (K ALL_TAC)) \\ full_simp_tac(srw_ss())[LET_DEF]
  THEN1 suspend "Asm"
  THEN1 suspend "ShareMemOp"
  THEN1 suspend "Jump"
  THEN1 suspend "JumpCmp"
  THEN1 suspend "Call"
  THEN1 suspend "LocValue"
  THEN1 suspend "CallFFI"
  THEN1 suspend "Install"
  THEN1 suspend "Halt"
QED

Theorem i2w_sub_nat[local,simp]:
  (i2w (&m - &n):'a word) = n2w m - n2w n
Proof
  rw [integerTheory.int_sub,GSYM integer_wordTheory.word_i2w_add,
      GSYM integer_wordTheory.MULT_MINUS_ONE,integer_wordTheory.i2w_pos]
  \\ metis_tac [WORD_NEG_MUL]
QED

Theorem i2w_neg_nat[local,simp]:
  (i2w (-&n):'a word) = -n2w n
Proof
  rw [GSYM integer_wordTheory.MULT_MINUS_ONE,integer_wordTheory.i2w_pos]
  \\ metis_tac [WORD_NEG_MUL]
QED

Resume compile_no_install_prefix[Asm]:
  fs[case_eq_thms]>>rw[]
  THEN1 (* Asm Inst *) (
     say "Asm Inst"
     \\ qmatch_assum_rename_tac `asm_fetch s1 = SOME (Asm (Asmi(Inst i)) bytes len)`
     \\ qabbrev_tac `ffi_names = TAKE (THE (mmio_pcs_min_index mc_conf.ffi_names)) mc_conf.ffi_names`
     \\ mp_tac IMP_bytes_in_memory_Inst
     \\ full_simp_tac(srw_ss())[]
     \\ impl_tac
     THEN1 (full_simp_tac(srw_ss())[state_rel_def])
     \\ rpt strip_tac \\ pop_assum mp_tac \\ pop_assum mp_tac
     \\ qpat_abbrev_tac `jj = asm$Inst i` \\ rpt strip_tac
     \\ (Q.ISPECL_THEN [`mc_conf`,`t1`,`ms1`,`s1.ffi`,`jj`]MP_TAC
          asm_step_IMP_evaluate_step_nop) \\ full_simp_tac(srw_ss())[]
     \\ disch_then (mp_tac o Q.SPEC `bytes'`)
     \\ impl_tac>-
      (imp_res_tac Inst_lemma \\ pop_assum (K all_tac)
       \\ full_simp_tac(srw_ss())[state_rel_def,asm_def,LET_DEF] \\ unabbrev_all_tac \\ full_simp_tac(srw_ss())[]
       \\ full_simp_tac(srw_ss())[asm_step_nop_def,asm_def,LET_DEF]
       \\ full_simp_tac(srw_ss())[asm_def,upd_pc_def,upd_reg_def]
       \\ conj_tac
       >- (fs[asm_fetch_def] >>
        `!op re a. Asmi (Inst i) <> ShareMem op re a` by simp[] >>
        drule_all $ GEN_ALL IMP_ffi_entry_pcs_disjoint_Asm >>
        simp[])
       \\ qpat_x_assum `bytes_in_mem ww bytes' t1.mem
             t1.mem_domain s1.mem_domain` mp_tac
       \\ match_mp_tac bytes_in_mem_IMP_memory \\ full_simp_tac(srw_ss())[])
     \\ rpt strip_tac \\ full_simp_tac(srw_ss())[]
     \\ rfs[] \\ fs[]
     \\ FIRST_X_ASSUM (MP_TAC o peel o Q.SPECL [`shift_interfer l mc_conf`,
          `code2`,`labs`,
          `(asm jj (t1.pc + n2w (LENGTH (bytes':word8 list))) t1)`,`ms2`])
     \\ impl_tac THEN1
      (conj_tac
       >- (irule oracle_tie_step
           \\ qpat_assum `oracle_tie _ _ _` (irule_at Any)
           \\ simp[labSemTheory.inc_pc_def,labSemTheory.dec_clock_def,
                   labSemTheory.upd_pc_def,asm_inst_consts]
           \\ metis_tac[])
       \\ unabbrev_all_tac \\ rpt strip_tac \\ full_simp_tac(srw_ss())[asm_def]
       THEN1 (full_simp_tac(srw_ss())[shift_interfer_def])
       \\ full_simp_tac(srw_ss())[GSYM PULL_FORALL]
       \\ match_mp_tac state_rel_shift_interfer
       \\ drule_then (qspecl_then [`t1`,`p`,`ms2`,`ms1`,`mc_conf`,`labs`,`code2`,`bytes'`] mp_tac)
            Inst_lemma
       \\ fs[])
     \\ nip_finish [] [inc_pc_def,dec_clock_def,asm_inst_consts])
  THEN1 (* Asm JumpReg *) (
    say "Asm JumpReg"
    \\ qmatch_assum_rename_tac `read_reg r1 s1 = Loc l1 l2`
    \\ Cases_on `loc_to_pc l1 l2 s1.code` \\ full_simp_tac(srw_ss())[]
    \\ (Q.ISPECL_THEN [`mc_conf`,`t1`,`ms1`, `s1.ffi`, `JumpReg r1`]MP_TAC
         asm_step_IMP_evaluate_step_find_next) \\ full_simp_tac(srw_ss())[]
    \\ impl_tac >-
     (full_simp_tac(srw_ss())[state_rel_def,asm_def,LET_DEF]
      \\ conj_tac
      >- (fs[asm_fetch_def]
        \\ drule_all $ GEN_ALL IMP_bytes_in_memory
        \\ strip_tac
        \\ fs[]
        \\ `!op re a. Asmi (JumpReg r1) <> ShareMem op re a` by simp[]
        \\ drule_all $ GEN_ALL IMP_ffi_entry_pcs_disjoint_Asm
        \\ `LENGTH ((mc_conf.target.config.encode (JumpReg r1))) <=
          LENGTH (line_bytes j)`
          suffices_by metis_tac[ffi_entry_pcs_disjoint_LENGTH_shorter]
        \\ Cases_on `j`
        \\ fs[line_similar_def,line_ok_def]
        \\ fs[enc_with_nop_thm,line_length_def]
        \\ Cases_on `a` >> fs[]
        \\ metis_tac[LENGTH_APPEND,LESS_EQ_ADD])
      \\ full_simp_tac(srw_ss())[asm_step_def,asm_def,LET_DEF]
      \\ imp_res_tac bytes_in_mem_IMP
      \\ full_simp_tac(srw_ss())[IMP_bytes_in_memory_JumpReg,asmSemTheory.upd_pc_def,
             asmSemTheory.assert_def]
      \\ imp_res_tac IMP_bytes_in_memory_JumpReg \\ full_simp_tac(srw_ss())[]
      \\ full_simp_tac(srw_ss())[asmSemTheory.read_reg_def]
      \\ full_simp_tac(srw_ss())[interference_ok_def,shift_seq_def]
      \\ FIRST_X_ASSUM (kall_tac o Q.SPEC `r1:num`)
      \\ qpat_x_assum `!n. n<s1.code_buffer.space_left ==> _` kall_tac
      \\ qpat_x_assum `!r. word_loc_val _ _ (read_reg r _) = _` (MP_TAC o Q.SPEC `r1:num`)
      \\ strip_tac \\ rev_full_simp_tac(srw_ss())[]
      \\ full_simp_tac(srw_ss())[word_loc_val_def]
      \\ Cases_on `lab_lookup l1 l2 labs` \\ full_simp_tac(srw_ss())[]
      \\ Q.PAT_X_ASSUM `xx = t1.regs r1` (fn th => full_simp_tac(srw_ss())[GSYM th])
      \\ FIRST_X_ASSUM (MP_TAC o Q.SPECL [`l1`,`l2`]) \\ full_simp_tac(srw_ss())[] \\ srw_tac[][]
      \\ (alignmentTheory.aligned_add_sub_cor
          |> SPEC_ALL |> UNDISCH |> CONJUNCT1 |> DISCH_ALL |> irule)
      \\ conj_tac >- fs[alignmentTheory.aligned_bitwise_and]
      \\ simp[aligned_w2n]
      \\ qmatch_goalsub_abbrev_tac`pv MOD dw MOD _`
      \\ `pv MOD dw = pv` by (
        simp[Abbr`pv`,Abbr`dw`]
        \\ irule LESS_EQ_LESS_TRANS
        \\ qexists_tac`LENGTH (prog_to_bytes code2)`
        \\ simp[]
        \\ drule pos_val_bound
        \\ disch_then(qspec_then`0`mp_tac o CONV_RULE SWAP_FORALL_CONV)
        \\ simp[] )
      \\ simp[]
      \\ qunabbrev_tac`pv`
      \\ qabbrev_tac `ffi_names = TAKE (THE (mmio_pcs_min_index mc_conf.ffi_names)) mc_conf.ffi_names`
      \\ match_mp_tac pos_val_MOD_0 \\ gvs[]
      \\ metis_tac[has_odd_inst_alignment] )
    \\ rpt strip_tac
    \\ rfs[] \\ fs[] \\ rfs[]
    \\ FIRST_X_ASSUM (mp_tac o peel o Q.SPECL [`shift_interfer l' mc_conf`,
         `code2`,`labs`,`(asm (JumpReg r1)
            (t1.pc + n2w (LENGTH (mc_conf.target.config.encode (JumpReg r1)))) t1)`,`ms2`])
    \\ impl_tac >-
     (conj_tac
       >- (irule oracle_tie_step
           \\ qpat_assum `oracle_tie _ _ _` (irule_at Any)
           \\ simp[labSemTheory.upd_pc_def,labSemTheory.dec_clock_def]
           \\ metis_tac[])
      \\ full_simp_tac(srw_ss())[shift_interfer_def,state_rel_def,asm_def,LET_DEF] \\ rev_full_simp_tac(srw_ss())[]
      \\ full_simp_tac(srw_ss())[asmSemTheory.upd_pc_def,asmSemTheory.assert_def,
             asmSemTheory.read_reg_def,dec_clock_def,labSemTheory.upd_pc_def,
             labSemTheory.assert_def]
      \\ full_simp_tac(srw_ss())[interference_ok_def,shift_seq_def]
      \\ FIRST_X_ASSUM (K ALL_TAC o Q.SPEC `r1:num`)
      \\ FIRST_X_ASSUM (K ALL_TAC o Q.SPEC `r1:num`)
      \\ FIRST_X_ASSUM (K ALL_TAC o Q.SPEC `r1:num`)
      \\ FIRST_X_ASSUM (MP_TAC o Q.SPEC `r1:num`)
      \\ strip_tac \\ rev_full_simp_tac(srw_ss())[]
      \\ full_simp_tac(srw_ss())[word_loc_val_def]
      \\ Cases_on `lab_lookup l1 l2 labs` \\ full_simp_tac(srw_ss())[]
      \\ Q.PAT_X_ASSUM `xx = t1.regs r1` (fn th => full_simp_tac(srw_ss())[GSYM th])
      \\ FIRST_X_ASSUM (MP_TAC o Q.SPECL [`l1`,`l2`]) \\ full_simp_tac(srw_ss())[] \\ srw_tac[][]
      \\ RES_TAC \\ full_simp_tac(srw_ss())[] \\ rpt strip_tac \\ res_tac \\ srw_tac[][]
      >- ((alignmentTheory.aligned_add_sub_cor
          |> SPEC_ALL |> UNDISCH |> CONJUNCT1 |> DISCH_ALL |> irule)
        \\ conj_tac >- fs[alignmentTheory.aligned_bitwise_and]
        \\ simp[aligned_w2n]
        \\ qmatch_goalsub_abbrev_tac`pv MOD dw MOD _`
        \\ `pv MOD dw = pv` by (
          simp[Abbr`pv`,Abbr`dw`]
          \\ irule LESS_EQ_LESS_TRANS
          \\ qexists_tac`LENGTH (prog_to_bytes code2)`
          \\ simp[]
          \\ drule pos_val_bound
          \\ disch_then(qspec_then`0`mp_tac o CONV_RULE SWAP_FORALL_CONV)
          \\ simp[] )
        \\ simp[]
        \\ qunabbrev_tac`pv`
        \\ match_mp_tac $ Q.GEN `ffi_names` pos_val_MOD_0 \\ fs[]
        \\ metis_tac[has_odd_inst_alignment])
      >- (fs[share_mem_state_rel_def] >> share_mem_state_rel_tac)
      >- fs[share_mem_domain_code_rel_def] )
    \\ nip_finish [] [labSemTheory.upd_pc_def,dec_clock_def])
QED
val _ = pr "CASE_PROVED Asm";

Resume compile_no_install_prefix[ShareMemOp]:
  say "ShareMemOp (excluded by the invariant premise)"
  \\ qpat_x_assum `lab_step_closed _` (strip_assume_tac o REWRITE_RULE [lab_step_closed_def])
  \\ qpat_x_assum `!s m r ad bs n. Inv s ==> _` drule
  \\ simp[]
QED
val _ = pr "CASE_PROVED ShareMemOp";

Resume compile_no_install_prefix[Jump]:
(* Jump *)
  say "Jump"
  \\ qmatch_assum_rename_tac
       `asm_fetch s1 = SOME (LabAsm (Jump jtarget) l1 l2 l3)`
  \\ qmatch_assum_rename_tac
       `asm_fetch s1 = SOME (LabAsm (Jump jtarget) l bytes n)`
  \\ Cases_on `get_pc_value jtarget s1` \\ full_simp_tac(srw_ss())[]
  \\ qabbrev_tac `ffi_names = TAKE (THE (mmio_pcs_min_index mc_conf.ffi_names)) mc_conf.ffi_names`
  \\ mp_tac IMP_bytes_in_memory_Jump \\ full_simp_tac(srw_ss())[]
  \\ match_mp_tac IMP_IMP \\ strip_tac
  THEN1 (full_simp_tac(srw_ss())[state_rel_def] \\ imp_res_tac bytes_in_mem_IMP \\ full_simp_tac(srw_ss())[])
  \\ rpt strip_tac \\ pop_assum mp_tac
  \\ qpat_abbrev_tac `jj = asm$Jump lll` \\ rpt strip_tac
  \\ (Q.ISPECL_THEN [`mc_conf`,`t1`,`ms1`,`s1.ffi`,`jj`]MP_TAC
       asm_step_IMP_evaluate_step_find_next) \\ full_simp_tac(srw_ss())[]
  \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1
   (full_simp_tac(srw_ss())[state_rel_def,asm_def,LET_DEF]
    \\ full_simp_tac(srw_ss())[asm_step_def,asm_def,LET_DEF]
    \\ imp_res_tac bytes_in_mem_IMP
    \\ full_simp_tac(srw_ss())[asmSemTheory.jump_to_offset_def,asmSemTheory.upd_pc_def]
    \\ rev_full_simp_tac(srw_ss())[] \\ unabbrev_all_tac
    \\ full_simp_tac(srw_ss())[asmSemTheory.jump_to_offset_def,asmSemTheory.upd_pc_def,asm_def]
    \\ fs[asm_fetch_def]
    \\ drule_all $ GEN_ALL IMP_bytes_in_memory
    \\ strip_tac
    \\ fs[]
    \\ drule_all $ GEN_ALL IMP_ffi_entry_pcs_disjoint_LabAsm
    \\ `LENGTH
          ((mc_conf.target.config.encode
            (Jump
               (&(find_pos jtarget labs) -
                &(pos_val s1.pc 0 code2)))))
        <= LENGTH (line_bytes j)` suffices_by
      metis_tac[ffi_entry_pcs_disjoint_LENGTH_shorter]
    \\ Cases_on `j`
    \\ gvs[line_similar_def,line_ok_def,line_length_def,line_bytes_def]
    \\ fs[get_label_def]
    \\ Cases_on `jtarget`
    \\ fs[]
    \\ Cases_on `lab_lookup n'' n0 labs`
    \\ gvs[lab_inst_def,enc_with_nop_thm, LENGTH_APPEND]
    \\ drule lab_lookup_IMP
    \\ fs[]
  )
  \\ rpt strip_tac
  \\ FIRST_X_ASSUM (MP_TAC o peel o Q.SPECL [`shift_interfer l' mc_conf`,
       `code2`,`labs`,
       `(asm jj (t1.pc + n2w (LENGTH (mc_conf.target.config.encode jj))) t1)`,`ms2`])
  \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1
   (conj_tac
     >- (irule oracle_tie_step
         \\ qpat_assum `oracle_tie _ _ _` (irule_at Any)
         \\ simp[labSemTheory.inc_pc_def,labSemTheory.dec_clock_def,
                 labSemTheory.upd_pc_def,labSemTheory.upd_reg_def,asm_inst_consts]
         \\ metis_tac[])
    \\ unabbrev_all_tac
    \\ full_simp_tac(srw_ss())[shift_interfer_def,state_rel_def,asm_def,LET_DEF] \\ rev_full_simp_tac(srw_ss())[]
    \\ full_simp_tac(srw_ss())[asmSemTheory.upd_pc_def,asmSemTheory.assert_def,
           asmSemTheory.read_reg_def, dec_clock_def,labSemTheory.upd_pc_def,
           labSemTheory.assert_def,asm_def,
           jump_to_offset_def]
    \\ full_simp_tac(srw_ss())[interference_ok_def,shift_seq_def,read_reg_def]
    \\ rewrite_tac [GSYM word_add_n2w,GSYM word_sub_def,WORD_SUB_PLUS,
          WORD_ADD_SUB] \\ full_simp_tac(srw_ss())[get_pc_value_def]
    \\ Cases_on `jtarget` \\ full_simp_tac(srw_ss())[]
    \\ qmatch_assum_rename_tac `loc_to_pc l1 l2 s1.code = SOME x`
    \\ FIRST_X_ASSUM (MP_TAC o Q.SPECL [`l1`,`l2`]) \\ full_simp_tac(srw_ss())[] \\ srw_tac[][]
    \\ imp_res_tac lab_lookup_IMP \\ full_simp_tac(srw_ss())[]
    >- metis_tac[]
    >- metis_tac[]
    >- (fs[share_mem_state_rel_def] >> share_mem_state_rel_tac)
    >- fs[share_mem_domain_code_rel_def] )
  \\ nip_finish [] [labSemTheory.upd_pc_def,dec_clock_def]
QED
val _ = pr "CASE_PROVED Jump";

Resume compile_no_install_prefix[JumpCmp]:
(* JumpCmp *)
  say "JumpCmp"
  \\ qmatch_assum_rename_tac
       `asm_fetch s1 = SOME (LabAsm (JumpCmp cmp rr ri jtarget) l1 l2 l3)`
  \\ qmatch_assum_rename_tac
       `asm_fetch s1 = SOME (LabAsm (JumpCmp cmp rr ri jtarget) l bytes n)`
  \\ `word_cmp cmp (read_reg rr s1) (labSem$reg_imm ri s1) =
      SOME (asm$word_cmp cmp (read_reg rr t1) (reg_imm ri t1))` by
   (Cases_on `word_cmp cmp (read_reg rr s1) (reg_imm ri s1)` \\ full_simp_tac(srw_ss())[]
    \\ imp_res_tac word_cmp_lemma \\ full_simp_tac(srw_ss())[])
  \\ full_simp_tac(srw_ss())[]
  \\ qabbrev_tac `ffi_names = TAKE (THE (mmio_pcs_min_index mc_conf.ffi_names)) mc_conf.ffi_names`
  \\ Cases_on `word_cmp cmp (read_reg rr t1) (reg_imm ri t1)` \\ full_simp_tac(srw_ss())[]


  THEN1
   (Cases_on `get_pc_value jtarget s1` \\ full_simp_tac(srw_ss())[]
    \\ mp_tac IMP_bytes_in_memory_JumpCmp \\ full_simp_tac(srw_ss())[]
    \\ match_mp_tac IMP_IMP \\ strip_tac
    THEN1 (full_simp_tac(srw_ss())[state_rel_def] \\ imp_res_tac bytes_in_mem_IMP \\ full_simp_tac(srw_ss())[])
    \\ rpt strip_tac \\ pop_assum mp_tac
    \\ qpat_abbrev_tac `jj = asm$JumpCmp cmp rr ri lll` \\ rpt strip_tac
    \\ (Q.ISPECL_THEN [`mc_conf`,`t1`,`ms1`,`s1.ffi`,`jj`]mp_tac
         asm_step_IMP_evaluate_step_find_next) \\ full_simp_tac(srw_ss())[]
    \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1
     (full_simp_tac(srw_ss())[state_rel_def,asm_def,LET_DEF]
      \\ unabbrev_all_tac \\ full_simp_tac(srw_ss())[asm_step_def,asm_def,LET_DEF]
      \\ imp_res_tac bytes_in_mem_IMP
      \\ full_simp_tac(srw_ss())[asmSemTheory.jump_to_offset_def,asmSemTheory.upd_pc_def]
      \\ rev_full_simp_tac(srw_ss())[] \\ unabbrev_all_tac
      \\ full_simp_tac(srw_ss())[asmSemTheory.jump_to_offset_def,asmSemTheory.upd_pc_def,asm_def]
      \\ fs[asm_fetch_def]
      \\ drule_all $ GEN_ALL IMP_bytes_in_memory
      \\ strip_tac
      \\ fs[]
      \\ drule_all $ GEN_ALL IMP_ffi_entry_pcs_disjoint_LabAsm
      \\ ho_match_mp_tac (
        PURE_REWRITE_RULE [satTheory.AND_IMP] o
        PURE_REWRITE_RULE [Once CONJ_SYM] $
        GEN_ALL ffi_entry_pcs_disjoint_LENGTH_shorter )
      \\ Cases_on `j`
      \\ gvs[line_similar_def,line_ok_def,line_length_def,line_bytes_def]
      \\ fs[get_label_def]
      \\ Cases_on `jtarget`
      \\ fs[]
      \\ Cases_on `lab_lookup n'' n0 labs`
      \\ gvs[lab_inst_def,enc_with_nop_thm, LENGTH_APPEND]
      \\ drule lab_lookup_IMP
      \\ fs[]
    )
    \\ rpt strip_tac
    \\ FIRST_X_ASSUM (MP_TAC o peel o Q.SPECL [`shift_interfer l' mc_conf`,
         `code2`,`labs`,
         `(asm jj (t1.pc + n2w (LENGTH (mc_conf.target.config.encode jj))) t1)`,`ms2`])
    \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1
     (conj_tac
       >- (irule oracle_tie_step
           \\ qpat_assum `oracle_tie _ _ _` (irule_at Any)
           \\ simp[labSemTheory.inc_pc_def,labSemTheory.dec_clock_def,
                   labSemTheory.upd_pc_def,labSemTheory.upd_reg_def,asm_inst_consts]
           \\ metis_tac[])
      \\ unabbrev_all_tac
      \\ full_simp_tac(srw_ss())[shift_interfer_def,state_rel_def,asm_def,LET_DEF] \\ rev_full_simp_tac(srw_ss())[]
      \\ full_simp_tac(srw_ss())[asmSemTheory.upd_pc_def,asmSemTheory.assert_def,
             asmSemTheory.read_reg_def, dec_clock_def,labSemTheory.upd_pc_def,
             labSemTheory.assert_def,asm_def,
             jump_to_offset_def]
      \\ full_simp_tac(srw_ss())[interference_ok_def,shift_seq_def,read_reg_def]
      \\ rewrite_tac [GSYM word_add_n2w,GSYM word_sub_def,WORD_SUB_PLUS,
            WORD_ADD_SUB] \\ full_simp_tac(srw_ss())[get_pc_value_def]
      \\ Cases_on `jtarget` \\ full_simp_tac(srw_ss())[]
      \\ qmatch_assum_rename_tac `loc_to_pc l1 l2 s1.code = SOME x`
      \\ FIRST_X_ASSUM (MP_TAC o Q.SPECL [`l1`,`l2`]) \\ full_simp_tac(srw_ss())[] \\ srw_tac[][]
      \\ imp_res_tac lab_lookup_IMP \\ full_simp_tac(srw_ss())[]
      >- metis_tac []
      >- metis_tac []
      >- (fs[share_mem_state_rel_def] >> share_mem_state_rel_tac)
      >- fs[share_mem_domain_code_rel_def] )
    \\ nip_finish [] [labSemTheory.upd_pc_def,dec_clock_def])
  \\ mp_tac (IMP_bytes_in_memory_JumpCmp_1) \\ full_simp_tac(srw_ss())[]
  \\ match_mp_tac IMP_IMP \\ strip_tac
  THEN1 (full_simp_tac(srw_ss())[state_rel_def] \\ imp_res_tac bytes_in_mem_IMP \\ full_simp_tac(srw_ss())[])
  \\ rpt strip_tac \\ pop_assum mp_tac \\ pop_assum mp_tac
  \\ qpat_abbrev_tac `jj = asm$JumpCmp cmp rr ri lll` \\ rpt strip_tac
  \\ (Q.ISPECL_THEN [`mc_conf`,`t1`,`ms1`,`s1.ffi`,`jj`]mp_tac
       asm_step_IMP_evaluate_step_nop) \\ full_simp_tac(srw_ss())[]
  \\ strip_tac \\ pop_assum (mp_tac o Q.SPEC `bytes'`)
  \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1
   (full_simp_tac(srw_ss())[state_rel_def,asm_def,LET_DEF] \\ unabbrev_all_tac \\ full_simp_tac(srw_ss())[]
    \\ full_simp_tac(srw_ss())[asm_step_nop_def,asm_def,LET_DEF]
    \\ full_simp_tac(srw_ss())[asm_def,upd_pc_def,upd_reg_def]
    \\ fs[asm_fetch_def]
    \\ drule_all $ GEN_ALL IMP_bytes_in_memory
    \\ strip_tac
    \\ fs[]
    \\ drule_all $ GEN_ALL IMP_ffi_entry_pcs_disjoint_LabAsm
    \\ ho_match_mp_tac (
      PURE_REWRITE_RULE [satTheory.AND_IMP] o
      PURE_REWRITE_RULE [Once CONJ_SYM] $
      GEN_ALL ffi_entry_pcs_disjoint_LENGTH_shorter )
    \\ Cases_on `j`
    \\ gvs[line_similar_def,line_ok_def,line_length_def,line_bytes_def] )
  \\ rpt strip_tac
  \\ FIRST_X_ASSUM (MP_TAC o peel o Q.SPECL [`shift_interfer l' mc_conf`,
       `code2`,`labs`,
       `(asm jj (t1.pc + n2w (LENGTH (bytes':word8 list))) t1)`,`ms2`])
  \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1
   (conj_tac
     >- (irule oracle_tie_step
         \\ qpat_assum `oracle_tie _ _ _` (irule_at Any)
         \\ simp[labSemTheory.inc_pc_def,labSemTheory.dec_clock_def,
                 labSemTheory.upd_pc_def,labSemTheory.upd_reg_def,asm_inst_consts]
         \\ metis_tac[])
    \\ unabbrev_all_tac
    \\ full_simp_tac(srw_ss())[shift_interfer_def,state_rel_def,asm_def,LET_DEF] \\ rev_full_simp_tac(srw_ss())[]
    \\ full_simp_tac(srw_ss())[asmSemTheory.upd_pc_def,asmSemTheory.assert_def,
           asmSemTheory.read_reg_def, dec_clock_def,labSemTheory.upd_pc_def,
           labSemTheory.assert_def,asm_def,
           jump_to_offset_def,inc_pc_def,asmSemTheory.upd_reg_def,
           labSemTheory.upd_reg_def]
    \\ full_simp_tac(srw_ss())[interference_ok_def,shift_seq_def,read_reg_def]
    \\ rewrite_tac [GSYM word_add_n2w,GSYM word_sub_def,WORD_SUB_PLUS,
          WORD_ADD_SUB] \\ full_simp_tac(srw_ss())[get_pc_value_def]
    \\ rpt strip_tac \\ res_tac \\ full_simp_tac(srw_ss())[]
    >- (fs[share_mem_state_rel_def] >> share_mem_state_rel_tac)
    >- fs[share_mem_domain_code_rel_def] )
  \\ nip_finish [] [inc_pc_def,dec_clock_def]
QED
val _ = pr "CASE_PROVED JumpCmp";

Resume compile_no_install_prefix[Call]:
(* Call *)
  say "Call"
  \\ qmatch_assum_rename_tac
       `asm_fetch s1 = SOME (LabAsm (Call lab) x1 x2 x3)`
  \\ Cases_on `lab`
  \\ qmatch_assum_rename_tac
       `asm_fetch s1 = SOME (LabAsm (Call (Lab l1 l2)) l bytes len)`
  \\ qabbrev_tac `ffi_names = TAKE (THE (mmio_pcs_min_index mc_conf.ffi_names)) mc_conf.ffi_names`
  \\ (Q.SPECL_THEN [`Lab l1 l2`,`len`]mp_tac
          (Q.GENL[`ww`,`n`]IMP_bytes_in_memory_Call))
  \\ match_mp_tac IMP_IMP \\ strip_tac \\ full_simp_tac(srw_ss())[]
  \\ full_simp_tac(srw_ss())[state_rel_def] \\ imp_res_tac bytes_in_mem_IMP \\ full_simp_tac(srw_ss())[]
QED
val _ = pr "CASE_PROVED Call";

Resume compile_no_install_prefix[LocValue]:
(* LocValue *)
  say "LocValue"
  \\ qmatch_assum_rename_tac
       `asm_fetch s1 = SOME (LabAsm (LocValue reg lab) x1 x2 x3)`
  \\ Cases_on `lab`
  \\ qmatch_assum_rename_tac
       `asm_fetch s1 = SOME (LabAsm (LocValue reg (Lab l1 l2)) ww bytes len)`
  \\ full_simp_tac(srw_ss())[lab_to_loc_def]
  \\ qabbrev_tac `ffi_names = TAKE (THE (mmio_pcs_min_index mc_conf.ffi_names)) mc_conf.ffi_names`
  \\ mp_tac (Q.INST [`l`|->`ww`,`n`|->`len`]
             IMP_bytes_in_memory_LocValue) \\ full_simp_tac(srw_ss())[]
  \\ match_mp_tac IMP_IMP \\ strip_tac
  THEN1 (full_simp_tac(srw_ss())[state_rel_def]
         \\ imp_res_tac bytes_in_mem_IMP \\ full_simp_tac(srw_ss())[])
  \\ rpt strip_tac \\ pop_assum mp_tac
  \\ Cases_on `get_pc_value (Lab l1 l2) s1` \\ fs []
  \\ qpat_abbrev_tac `jj = asm$Loc reg lll` \\ rpt strip_tac
  \\ (Q.ISPECL_THEN [`mc_conf`,`t1`,`ms1`,`s1.ffi`,`jj`]mp_tac
       asm_step_IMP_evaluate_step_nop) \\ full_simp_tac(srw_ss())[]
  \\ strip_tac \\ pop_assum (mp_tac o Q.SPEC `bytes'`)
  \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1
   (full_simp_tac(srw_ss())[state_rel_def,asm_def,LET_DEF]
    \\ unabbrev_all_tac \\ full_simp_tac(srw_ss())[]
    \\ full_simp_tac(srw_ss())[asm_step_nop_def,asm_def,LET_DEF]
    \\ full_simp_tac(srw_ss())[asm_def,upd_pc_def,upd_reg_def]
    \\ fs[asm_fetch_def]
    \\ drule_all $ GEN_ALL IMP_bytes_in_memory
    \\ strip_tac
    \\ fs[]
    \\ drule_all $ GEN_ALL IMP_ffi_entry_pcs_disjoint_LabAsm
    \\ ho_match_mp_tac (
      PURE_REWRITE_RULE [satTheory.AND_IMP] o
      PURE_REWRITE_RULE [Once CONJ_SYM] $
      GEN_ALL ffi_entry_pcs_disjoint_LENGTH_shorter )
    \\ Cases_on `j`
    \\ gvs[line_similar_def,line_ok_def,line_length_def,line_bytes_def] )
  \\ rpt strip_tac
  \\ FIRST_X_ASSUM (MP_TAC o peel o Q.SPECL [`shift_interfer l mc_conf`,
       `code2`,`labs`,
       `(asm jj (t1.pc + n2w (LENGTH (bytes':word8 list))) t1)`,`ms2`])
  \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1
   (conj_tac
     >- (irule oracle_tie_step
         \\ qpat_assum `oracle_tie _ _ _` (irule_at Any)
         \\ simp[labSemTheory.inc_pc_def,labSemTheory.dec_clock_def,
                 labSemTheory.upd_pc_def,labSemTheory.upd_reg_def,asm_inst_consts]
         \\ metis_tac[])
    \\ unabbrev_all_tac
    \\ full_simp_tac(srw_ss())[shift_interfer_def,state_rel_def,asm_def,LET_DEF]
    \\ rev_full_simp_tac(srw_ss())[]
    \\ full_simp_tac(srw_ss())[asmSemTheory.upd_pc_def,asmSemTheory.assert_def,
           asmSemTheory.read_reg_def, dec_clock_def,labSemTheory.upd_pc_def,
           labSemTheory.assert_def,asm_def,
           jump_to_offset_def,inc_pc_def,asmSemTheory.upd_reg_def,
           labSemTheory.upd_reg_def]
    \\ full_simp_tac(srw_ss())[interference_ok_def,shift_seq_def,read_reg_def]
    \\ rewrite_tac [GSYM word_add_n2w,GSYM word_sub_def,WORD_SUB_PLUS,
          WORD_ADD_SUB] \\ full_simp_tac(srw_ss())[get_pc_value_def]
    \\ full_simp_tac(srw_ss())[APPLY_UPDATE_THM] \\ srw_tac[][word_loc_val_def]
    \\ res_tac \\ full_simp_tac(srw_ss())[]
    >- (
      Cases_on `lab_lookup l1 l2 labs` \\ full_simp_tac(srw_ss())[]
      \\ imp_res_tac lab_lookup_IMP \\ srw_tac[][] )
    >- (fs[share_mem_state_rel_def] >> share_mem_state_rel_tac)
    >- fs[share_mem_domain_code_rel_def] )
  \\ nip_finish [lab_to_loc_def] [inc_pc_def,dec_clock_def,labSemTheory.upd_reg_def]
QED
val _ = pr "CASE_PROVED LocValue";

Resume compile_no_install_prefix[CallFFI]:
  say "CallFFI"
  \\ qmatch_assum_rename_tac `asm_fetch s1 = SOME (LabAsm (CallFFI s) l1 l2 l3)`
  \\ qmatch_assum_rename_tac
       `asm_fetch s1 = SOME (LabAsm (CallFFI s) l bytes n)`
  \\ Cases_on `s1.regs s1.len_reg` \\ full_simp_tac(srw_ss())[]
  \\ Cases_on `s1.regs s1.len2_reg` \\ full_simp_tac(srw_ss())[]
  \\ Cases_on `s1.regs s1.link_reg` \\ full_simp_tac(srw_ss())[]
  \\ Cases_on `s1.regs s1.ptr_reg` \\ full_simp_tac(srw_ss())[]
  \\ Cases_on `s1.regs s1.ptr2_reg` \\ full_simp_tac(srw_ss())[]
  \\ qmatch_assum_rename_tac `read_reg _.len2_reg _ = Word c2`
  \\ qmatch_assum_rename_tac `read_reg _.ptr2_reg _ = Word c2'`
  \\ qmatch_assum_rename_tac `read_reg _.ptr_reg _ = Word c'`
  \\ Cases_on `read_bytearray c' (w2n c) (mem_load_byte_aux s1.mem s1.mem_domain s1.be)`
  \\ full_simp_tac(srw_ss())[]
  \\ Cases_on `read_bytearray c2' (w2n c2) (mem_load_byte_aux s1.mem s1.mem_domain s1.be)`
  \\ full_simp_tac(srw_ss())[]
  \\ qmatch_assum_rename_tac `s1.regs s1.link_reg = Loc n1 n2`
  \\ qmatch_asmsub_abbrev_tac `loc_to_pc a1 a2 a3`
  \\ Cases_on `loc_to_pc a1 a2 a3` >- fs[]
  \\ unabbrev_all_tac \\ fs[]
  \\ qabbrev_tac `ffi_names = TAKE (THE (mmio_pcs_min_index mc_conf.ffi_names)) mc_conf.ffi_names`
  \\ mp_tac (Q.GEN `name` IMP_bytes_in_memory_CallFFI) \\ full_simp_tac(srw_ss())[]
  \\ match_mp_tac IMP_IMP \\ strip_tac
  THEN1 (
    full_simp_tac(srw_ss())[state_rel_def]
    \\ imp_res_tac bytes_in_mem_IMP \\ full_simp_tac(srw_ss())[]
  )
  \\ rpt strip_tac \\ pop_assum mp_tac
  \\ qpat_abbrev_tac `jj = asm$Jump lll` \\ rpt strip_tac
  \\ (Q.ISPECL_THEN [`mc_conf`,`t1`,`ms1`,`s1.ffi`,`jj`]mp_tac
       asm_step_IMP_evaluate_step_find_next) \\ full_simp_tac(srw_ss())[]
  \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1 (
    full_simp_tac(srw_ss())[state_rel_def,asm_def,LET_DEF]
    \\ full_simp_tac(srw_ss())[asm_step_def,asm_def,LET_DEF]
    \\ imp_res_tac bytes_in_mem_IMP
    \\ full_simp_tac(srw_ss())[asmSemTheory.jump_to_offset_def,
         asmSemTheory.upd_pc_def]
    \\ rev_full_simp_tac(srw_ss())[] \\ unabbrev_all_tac
    \\ full_simp_tac(srw_ss())[asmSemTheory.jump_to_offset_def,
         asmSemTheory.upd_pc_def,asm_def]
    \\ fs[asm_fetch_def]
    \\ drule_all $ GEN_ALL IMP_bytes_in_memory
    \\ strip_tac
    \\ fs[]
    \\ drule_all $ GEN_ALL IMP_ffi_entry_pcs_disjoint_LabAsm
    \\ ho_match_mp_tac (
      PURE_REWRITE_RULE [satTheory.AND_IMP] o
      PURE_REWRITE_RULE [Once CONJ_SYM] $
      GEN_ALL ffi_entry_pcs_disjoint_LENGTH_shorter )
    \\ Cases_on `j`
    \\ gvs[line_similar_def,line_ok_def,line_length_def,line_bytes_def]
    \\ gvs[lab_inst_def,enc_with_nop_thm, LENGTH_APPEND]
  )
  \\ rpt strip_tac
  \\ Cases_on `loc_to_pc n1 n2 s1.code` \\ full_simp_tac(srw_ss())[]
  \\ qmatch_assum_rename_tac `loc_to_pc n1 n2 s1.code = SOME new_pc`
  \\ `mc_conf.target.get_pc ms2 = p - n2w ((3 + get_ffi_index ffi_names (ExtCall s)) * ffi_offset)` by
   (full_simp_tac(srw_ss())[GSYM PULL_FORALL]
    \\ full_simp_tac(srw_ss())[state_rel_def] \\ rev_full_simp_tac(srw_ss())[]
    \\ full_simp_tac(srw_ss())
         [encoder_correct_def,target_ok_def,target_state_rel_def]
    \\ unabbrev_all_tac
    \\ full_simp_tac(srw_ss())[asm_def,asmSemTheory.jump_to_offset_def,
         asmSemTheory.upd_pc_def]
    \\ rewrite_tac [GSYM word_sub_def,WORD_SUB_PLUS,
         GSYM word_add_n2w,WORD_ADD_SUB]) \\ full_simp_tac(srw_ss())[]
  \\ `has_io_name s s1.code` by
        (imp_res_tac IMP_has_io_name \\ NO_TAC)
  \\ `MEM (ExtCall s) mc_conf.ffi_names` by (
    imp_res_tac has_io_name_find_index>>
    imp_res_tac find_index_is_MEM>>
    gvs[list_subset_def,state_rel_def,EVERY_MEM,Abbr`ffi_names`]>>
    drule_all mmio_pcs_min_index_is_SOME >>
    strip_tac >>
    gvs[MEM_FILTER] >>
    `MEM s mc_conf.ffi_names` by (
      first_x_assum irule >> gvs[]) >>
    gvs[MEM_EL] >>
    `n'' < i` by (
      spose_not_then assume_tac >>
      `i <= n''` by decide_tac >>
      first_x_assum drule_all >>
      gvs[]
    ) >>
    qexists `n''` >>
    gvs[] >>
    irule $ GSYM EL_TAKE >>
    simp[]
  )
  \\ `~(mc_conf.target.get_pc ms2 IN mc_conf.prog_addresses) /\
      ~(mc_conf.target.get_pc ms2 = mc_conf.halt_pc) /\
      ~(mc_conf.target.get_pc ms2 = mc_conf.install_pc) /\
      (find_index (mc_conf.target.get_pc ms2) mc_conf.ffi_entry_pcs 0 =
         SOME (get_ffi_index mc_conf.ffi_names (ExtCall s))) /\
      get_ffi_index mc_conf.ffi_names (ExtCall s) = get_ffi_index ffi_names (ExtCall s)` by (
     full_simp_tac(srw_ss())[state_rel_def]>>
     first_x_assum $ qspecl_then [`ExtCall s`, `i`] drule >>
     gvs[] >>
     impl_keep_tac
     >- (irule ffi_name_NOT_Mapped >> fs[]) >>
     `get_ffi_index mc_conf.ffi_names (ExtCall s) = get_ffi_index ffi_names (ExtCall s)`
       suffices_by gvs[] >>
     gvs[get_ffi_index_def,backendPropsTheory.the_eqn] >>
     gvs[Abbr`ffi_names`] >>
     imp_res_tac find_index_MEM >>
     first_x_assum $ qspec_then `0` assume_tac >>fs[]>>
     fs[CaseEq"option"]>>irule OR_INTRO_THM2>>
     Cases_on ‘i ≤ LENGTH mc_conf.ffi_names’>>fs[]>-
      (
      drule LENGTH_TAKE>>strip_tac>>
      irule find_index_APPEND1>>fs[]>>
      qexists_tac `DROP i mc_conf.ffi_names` >>
      fs[TAKE_DROP])>>
     fs[NOT_LESS_EQUAL,TAKE_LENGTH_TOO_LONG])

  \\ `EL (get_ffi_index mc_conf.ffi_names (ExtCall s)) mc_conf.ffi_names = (ExtCall s)` by (
    irule EL_get_ffi_index_MEM >> simp[]
  )
  \\ sg `(mc_conf.target.get_reg ms2 mc_conf.ptr_reg = t1.regs mc_conf.ptr_reg) /\
      (mc_conf.target.get_reg ms2 mc_conf.len_reg = t1.regs mc_conf.len_reg) /\
      (mc_conf.target.get_reg ms2 mc_conf.ptr2_reg = t1.regs mc_conf.ptr2_reg) /\
      (mc_conf.target.get_reg ms2 mc_conf.len2_reg = t1.regs mc_conf.len2_reg) /\
      !a. a IN mc_conf.prog_addresses ==>
          (mc_conf.target.get_byte ms2 a = t1.mem a)`
  >- (
    qpat_x_assum `!k. _` (strip_assume_tac o SPEC_ALL)
    \\ gvs[asmPropsTheory.target_state_rel_def,asm_def,jump_to_offset_def,
           asmSemTheory.upd_pc_def]
    \\ unabbrev_all_tac \\ full_simp_tac(srw_ss())[state_rel_def,asm_def,
         jump_to_offset_def,asmSemTheory.upd_pc_def,AND_IMP_INTRO]
    \\ rpt strip_tac \\ first_x_assum match_mp_tac
    \\ full_simp_tac(srw_ss())[reg_ok_def]
  )
  \\ full_simp_tac(srw_ss())[]
  \\ `(t1.regs mc_conf.ptr_reg = c') /\
      (t1.regs mc_conf.len_reg = c) /\
      (t1.regs mc_conf.ptr2_reg = c2') /\
      (t1.regs mc_conf.len2_reg = c2)` by
   (full_simp_tac(srw_ss())[state_rel_def]
    \\ Q.PAT_X_ASSUM `!r. word_loc_val p labs (s1.regs r) = SOME (t1.regs r)`
         (fn th =>
        MP_TAC (Q.SPEC `(mc_conf: ('a,'state,'b) machine_config).ptr_reg` th)
        \\ MP_TAC (Q.SPEC `(mc_conf: ('a,'state,'b) machine_config).len_reg` th)
        \\ MP_TAC (Q.SPEC `(mc_conf: ('a,'state,'b) machine_config).ptr2_reg` th)
        \\ MP_TAC (Q.SPEC `(mc_conf: ('a,'state,'b) machine_config).len2_reg` th))
    \\ Q.PAT_X_ASSUM `xx = s1.ptr_reg` (ASSUME_TAC o GSYM)
    \\ Q.PAT_X_ASSUM `xx = s1.len_reg` (ASSUME_TAC o GSYM)
    \\ Q.PAT_X_ASSUM `xx = s1.ptr2_reg` (ASSUME_TAC o GSYM)
    \\ Q.PAT_X_ASSUM `xx = s1.len2_reg` (ASSUME_TAC o GSYM)
    \\ full_simp_tac(srw_ss())[word_loc_val_def] \\ NO_TAC)
  \\ full_simp_tac(srw_ss())[]
  \\ imp_res_tac read_bytearray_state_rel \\ full_simp_tac(srw_ss())[]
  \\ reverse(Cases_on `call_FFI s1.ffi (ExtCall s) x x'`) THEN1
   ((* FFI_final *)
   sg `!n. FST (targetSem$evaluate (shift_interfer l' mc_conf) s1.ffi (SUC n) ms2) <> TimeOut`
   >- (gen_tac
       \\ once_rewrite_tac [targetSemTheory.evaluate_def]
       \\ simp[shift_interfer_def]
       \\ rpt (TOP_CASE_TAC \\ simp[])
       \\ fs[shift_interfer_def,read_ffi_bytearrays_def,read_ffi_bytearray_def]
       \\ gvs[]
       \\ dbg "FFI_FINAL_RESIDUE")
   \\ seg_split
   \\ qpat_x_assum `!n. FST _ <> TimeOut` (fn th => mp_tac (MATCH_MP final_nip th))
   \\ (impl_tac >- shift_tac)
   \\ disch_then (qspec_then `s1.clock - 1` assume_tac)
   \\ nip_tail)
  (* FFI_return *)
  \\ full_simp_tac(srw_ss())[]
  \\ qmatch_assum_rename_tac
       `call_FFI s1.ffi (ExtCall s) x x' = FFI_return new_ffi new_bytes`
  \\ FIRST_X_ASSUM (Q.SPECL_THEN [
       `shift_interfer l' mc_conf with
        ffi_interfer := shift_seq 1 mc_conf.ffi_interfer`,
       `code2`,`labs`,
       `t1 with <| pc := p + n2w (pos_val new_pc 0 (code2:sec list)) ;
                   mem := asm_write_bytearray c2' new_bytes t1.mem ;
                   regs := \a. get_reg_value (s1.io_regs 0 (ExtCall s) a) (t1.regs a) I ;
                   fp_regs := \n. s1.io_fp_regs 0 n |>`,
       `mc_conf.ffi_interfer 0 (get_ffi_index mc_conf.ffi_names (ExtCall s),new_bytes,ms2)`]mp_tac)
  \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1 (
    (conj_tac
      >- (
        sg `oracle_tie (shift_interfer l' mc_conf) ms2 s1`
        >- (
          irule oracle_tie_shift_interfer
          \\ qexists_tac `ms1`
          \\ conj_tac
          >- (gen_tac
              \\ qpat_x_assum `!k. _ /\ _ /\ _ /\ _` (qspec_then `k` strip_assume_tac)
              \\ first_assum ACCEPT_TAC)
          \\ first_assum ACCEPT_TAC
        )
        \\ `(shift_interfer l' mc_conf).ffi_interfer = mc_conf.ffi_interfer` by
             simp[shift_interfer_def]
        \\ sg `next_interference (shift_interfer l' mc_conf) s1.ffi ms2 =
            SOME (FfiApp (get_ffi_index mc_conf.ffi_names (ExtCall s)) new_bytes ms2
                    (mc_conf.ffi_interfer 0
                       (get_ffi_index mc_conf.ffi_names (ExtCall s),new_bytes,ms2)),
                  shift_interfer l' mc_conf with
                    ffi_interfer := shift_seq 1 mc_conf.ffi_interfer, new_ffi)`
        >- (
          qpat_x_assum `(shift_interfer l' mc_conf).ffi_interfer = mc_conf.ffi_interfer`
            (fn th => rewrite_tac[GSYM th])
          \\ irule next_interference_ExtCall
          \\ full_simp_tac(srw_ss())[shift_interfer_def,state_rel_def,
               read_ffi_bytearrays_def,read_ffi_bytearray_def]
          \\ rpt conj_tac
          >- (
            qpat_x_assum `mc_conf.target.get_pc ms2 = _` (fn th => rewrite_tac[GSYM th])
            \\ first_assum ACCEPT_TAC
          )
          >- (
            qpat_x_assum `mc_conf.target.get_pc ms2 = _` (fn th => rewrite_tac[GSYM th])
            \\ first_assum ACCEPT_TAC
          )
          >- (
            disj1_tac
            \\ qpat_x_assum `mc_conf.target.get_pc ms2 = _` (fn th => rewrite_tac[GSYM th])
            \\ qpat_x_assum `mc_conf.prog_addresses = _` (fn th => rewrite_tac[GSYM th])
            \\ first_assum ACCEPT_TAC
          )
          >- (
            qpat_x_assum `mc_conf.target.get_pc ms2 = _` (fn th => rewrite_tac[GSYM th])
            \\ first_assum ACCEPT_TAC
          )
          >- (
            `get_ffi_index ffi_names (ExtCall s) < i` by
               (qpat_x_assum `get_ffi_index mc_conf.ffi_names _ = _`
                  (fn th => rewrite_tac[GSYM th])
                \\ irule ffi_name_NOT_Mapped
                \\ simp[]
                \\ first_assum ACCEPT_TAC)
            \\ qpat_x_assum `!index. if _ then _ else _`
                 (qspec_then `get_ffi_index ffi_names (ExtCall s)` mp_tac)
            \\ rw[]
          )
          >- (
            qexists_tac `x` \\ qexists_tac `x'` \\ qexists_tac `s`
            \\ full_simp_tac(srw_ss())[]
            \\ rev_full_simp_tac(srw_ss())[]
          )
        )
        >- (
          irule oracle_tie_ffi_next
          \\ qpat_assum `next_interference (shift_interfer l' mc_conf) _ _ = _`
               (irule_at Any)
          \\ simp[]
          \\ first_assum ACCEPT_TAC
        )
      )
     \\ rpt strip_tac
     THEN1 (full_simp_tac(srw_ss())[encoder_correct_def,shift_interfer_def]
            \\ metis_tac [])
     >- (
       unabbrev_all_tac
       \\ imp_res_tac bytes_in_mem_asm_write_bytearray
       \\ full_simp_tac(srw_ss())[state_rel_def,shift_interfer_def,
              asm_def,jump_to_offset_def,
              asmSemTheory.upd_pc_def] \\ rev_full_simp_tac(srw_ss())[]
       \\ rewrite_tac [GSYM word_add_n2w,GSYM word_sub_def,WORD_SUB_PLUS,
             WORD_ADD_SUB] \\ full_simp_tac(srw_ss())[get_pc_value_def]
       \\ full_simp_tac bool_ss [GSYM word_add_n2w,GSYM word_sub_def,WORD_SUB_PLUS,
             WORD_ADD_SUB] \\ full_simp_tac(srw_ss())[get_pc_value_def]
       \\ `interference_ok (shift_seq l' mc_conf.next_interfer)
             (mc_conf.target.proj t1.mem_domain)` by
                (full_simp_tac(srw_ss())[interference_ok_def,shift_seq_def]
                 \\ NO_TAC) \\ full_simp_tac(srw_ss())[]
       \\ `p + n2w (pos_val new_pc 0 code2) = t1.regs s1.link_reg` by
        (Q.PAT_X_ASSUM `!r. word_loc_val p labs (s1.regs r) = SOME (t1.regs r)`
            (Q.SPEC_THEN `s1.link_reg`mp_tac)
         \\ full_simp_tac(srw_ss())[word_loc_val_def]
         \\ Cases_on `lab_lookup n1 n2 labs` \\ full_simp_tac(srw_ss())[]
         \\ ONCE_REWRITE_TAC [EQ_SYM_EQ] \\ full_simp_tac(srw_ss())[]
         \\ res_tac \\ full_simp_tac(srw_ss())[]) \\ full_simp_tac(srw_ss())[]
       \\ `w2n c2 = LENGTH new_bytes` by
        (imp_res_tac read_bytearray_LENGTH
         \\ imp_res_tac evaluatePropsTheory.call_FFI_LENGTH \\ full_simp_tac(srw_ss())[])
       \\ qmatch_goalsub_abbrev_tac`mc_conf.ffi_interfer _ (index,_,_)`
       \\ `index < i` by (
         imp_res_tac mmio_pcs_min_index_is_SOME>>gvs[]>>
         simp[get_ffi_index_def,backendPropsTheory.the_eqn] >>
        imp_res_tac find_index_MEM >>
         first_x_assum $ qspec_then `0` assume_tac >>fs[]>>
         Cases_on ‘i' < i’>>fs[NOT_LESS]>>
         first_x_assum $ qspec_then `i'` assume_tac >>gvs[]
       )
       \\ `index < LENGTH mc_conf.ffi_names` by (
         drule mmio_pcs_min_index_is_SOME >> gvs[]
         )
       \\ qunabbrev_tac`index`
       \\ conj_tac >- (
         `read_ffi_bytearrays mc_conf ms2 = (SOME x, SOME x')` by
            full_simp_tac(srw_ss())[read_ffi_bytearrays_def,read_ffi_bytearray_def]
         \\ qspecl_then [`mc_conf`,`ms1`,`s1`,`ms2`,`l'`,
                         `get_ffi_index (TAKE i mc_conf.ffi_names) (ExtCall s)`,`s`,
                         `x`,`x'`,`new_ffi`,`new_bytes`,`t1`] mp_tac
              oracle_tie_ExtCall_residues
         \\ impl_tac
         >- (
           qpat_assum `mc_conf.target.get_pc ms2 = _` $ rewrite_tac o single
           \\ rpt conj_tac
           >- first_assum ACCEPT_TAC
           >- (gen_tac
               \\ qpat_x_assum `!k. _ /\ _ /\ _ /\ _` (qspec_then `k` strip_assume_tac)
               \\ first_assum ACCEPT_TAC)
           >- (qpat_x_assum `mc_conf.prog_addresses = _` $ rewrite_tac o single
               \\ rewrite_tac[pred_setTheory.IN_DIFF]
               \\ qpat_x_assum `p + -n2w _ NOTIN t1.mem_domain` $ rewrite_tac o single)
           >- first_assum ACCEPT_TAC
           >- first_assum ACCEPT_TAC
           >- first_assum ACCEPT_TAC
           >- first_assum ACCEPT_TAC
           >- (qpat_x_assum `!index. if _ then _ else _`
                 (qspec_then `get_ffi_index (TAKE i mc_conf.ffi_names) (ExtCall s)` mp_tac)
               \\ qpat_x_assum `get_ffi_index (TAKE i mc_conf.ffi_names) (ExtCall s) < i` mp_tac
               \\ rw[])
           >- first_assum ACCEPT_TAC
           \\ first_assum ACCEPT_TAC
         )
         >- (
           strip_tac
           \\ pop_assum $ rewrite_tac o single
           \\ pop_assum $ rewrite_tac o single
           \\ qpat_x_assum `!ms2' k index new_bytes' t1' bytes' bytes2 st new_st. _`
                (qspecl_then [`ms2`,`0`,
                              `get_ffi_index (TAKE i mc_conf.ffi_names) (ExtCall s)`,
                              `new_bytes`,`t1`,`x`,`x'`,`s1.ffi`,`new_ffi`] mp_tac)
           \\ impl_tac
           >- (
             rpt conj_tac
             >- first_assum ACCEPT_TAC
             >- first_assum ACCEPT_TAC
             >- MATCH_ACCEPT_TAC relationTheory.RTC_REFL
             >- (qpat_x_assum `mc_conf.ffi_names❲_❳ = ExtCall s` $ rewrite_tac o single
                 \\ first_assum ACCEPT_TAC)
             >- rewrite_tac[]
             >- (qpat_x_assum `!k. _ /\ _ /\ _ /\ _` (qspec_then `0` strip_assume_tac)
                 \\ first_assum ACCEPT_TAC)
             \\ `aligned mc_conf.target.config.code_alignment p` by
                  fs [alignmentTheory.aligned_bitwise_and]
             \\ qpat_x_assum `_ = t1.regs s1.link_reg` (fn th => rewrite_tac [GSYM th])
             \\ simp [ONCE_REWRITE_RULE [WORD_ADD_COMM] alignmentTheory.aligned_add_sub]
             \\ drule all_enc_ok_aligned_pos_val \\ simp []
             \\ disch_then (qspec_then `new_pc` mp_tac)
             \\ impl_tac >- metis_tac[has_odd_inst_alignment]
             \\ rw[]
           )
           >- (
             qpat_x_assum `t1.regs s1.ptr2_reg = c2'` (fn th => rewrite_tac[GSYM th])
             \\ qpat_x_assum `new_pc = x''` (fn th => rewrite_tac[GSYM th])
             \\ qpat_x_assum `p + n2w (pos_val new_pc 0 code2) = t1.regs s1.link_reg`
                  $ rewrite_tac o single
             \\ rewrite_tac[LET_THM]
             \\ BETA_TAC
             \\ disch_then ACCEPT_TAC
           )
         )
       )
       \\ conj_tac >- (
         rpt gen_tac \\ strip_tac
         \\ qpat_x_assum `!ms2'' k' index' new_bytes'' t1'' bytes'' bytes2' st' new_st'. _`
              (qspecl_then [`ms2'`,`k+1`,`index`,`new_bytes'`,`t1'`,`bytes'`,`bytes2`,
                            `st`,`new_st`] mp_tac)
         \\ impl_tac
         >- (
           rpt conj_tac
           >- first_assum ACCEPT_TAC
           >- first_assum ACCEPT_TAC
           >- (once_rewrite_tac[RTC_CASES1]
               \\ disj2_tac
               \\ qexists_tac `new_ffi`
               \\ conj_tac
               >- (rewrite_tac[evaluatePropsTheory.call_FFI_rel_def]
                   \\ goal_assum (first_assum o mp_then Any mp_tac))
               \\ first_assum ACCEPT_TAC)
           \\ first_assum ACCEPT_TAC
         )
         >- (
           rewrite_tac[shift_seq_def, LET_THM]
           \\ BETA_TAC
           \\ disch_then ACCEPT_TAC
         )
       )
       \\ conj_tac THEN1 metis_tac[]
       \\ conj_tac THEN1
        (Cases_on `s1.io_regs 0 (ExtCall s) r`
         \\ full_simp_tac(srw_ss())[get_reg_value_def,word_loc_val_def])
       \\ conj_tac THEN1
        (rpt strip_tac \\ qpat_x_assum `!a.
            byte_align a IN s1.mem_domain ==> bbb` (MP_TAC o Q.SPEC `a`)
         \\ full_simp_tac(srw_ss())[] \\ REPEAT STRIP_TAC
         \\ match_mp_tac (SIMP_RULE std_ss [] (Q.INST [`x` |-> `x'`] CallFFI_bytearray_lemma))
         \\ full_simp_tac(srw_ss())[])
       \\ rw[]
       >- (
         match_mp_tac (MP_CANON (Q.INST [`x`|->`x'`] bytes_in_mem_asm_write_bytearray))
         \\ simp[] \\ fs[])
       >- (
         match_mp_tac (MP_CANON (Q.INST [`x`|->`x'`] bytes_in_mem_asm_write_bytearray))
         \\ simp[] \\ fs[])
       >- (
           fs[share_mem_state_rel_def] >>
           gvs[]>>
           rpt gen_tac>>strip_tac>>fs[]>>
           gvs[IMP_CONJ_THM,AND_IMP_INTRO,shift_seq_def] >>
           first_assum $ irule_at Any>>
           fs[]>>
           irule $ cj 2 RTC_RULES >>
           qexists `new_ffi` >>
           gvs[evaluatePropsTheory.call_FFI_rel_def] >>
           metis_tac[]
       )
       >- fs[share_mem_domain_code_rel_def]
     ))
  )
  \\ ih_extras []
  \\ qpat_x_assum `no_install_prefix _ _ _ _` (assume_tac o SIMP_RULE (srw_ss()) [])
  \\ dbg "FFI_RETURN"
  \\ sg `!n. targetSem$evaluate (shift_interfer l' mc_conf) s1.ffi (SUC n) ms2 =
              targetSem$evaluate (shift_interfer l' mc_conf with ffi_interfer := shift_seq 1 mc_conf.ffi_interfer) new_ffi n
                (mc_conf.ffi_interfer 0 (get_ffi_index mc_conf.ffi_names (ExtCall s),new_bytes,ms2))`
  >- (gen_tac
      \\ CONV_TAC (LAND_CONV (ONCE_REWRITE_CONV [targetSemTheory.evaluate_def]))
  \\ full_simp_tac(srw_ss())[shift_interfer_def]
  \\ full_simp_tac(srw_ss())[AC ADD_COMM ADD_ASSOC,AC MULT_COMM MULT_ASSOC]
  \\ rev_full_simp_tac(srw_ss())[LET_DEF]
  \\ rewrite_tac[read_ffi_bytearrays_def, read_ffi_bytearray_def]
      \\ dbg "FFI_STEP"
      \\ TOP_CASE_TAC>>fs[]
      \\ TRY (TOP_CASE_TAC>>fs[])
      \\ TRY (TOP_CASE_TAC>>fs[])
      >- (pairarg_tac>>fs[apply_oracle_def])>>
  qabbrev_tac ‘j = get_ffi_index ffi_names (ExtCall s)’>>
  fs[state_rel_def]>>
  drule mmio_pcs_min_index_is_SOME>>
  strip_tac>>fs[]>>
  last_x_assum $ qspec_then ‘j’ assume_tac>>fs[]>>
  Cases_on ‘j < i’>>fs[NOT_LESS]>>
  drule find_index_LESS_LENGTH>>strip_tac>>fs[]>>
  first_x_assum $ qspec_then ‘j’ assume_tac>>gvs[])
  \\ seg_split
  \\ qpat_x_assum `!n. targetSem$evaluate _ _ (SUC n) _ = _` (fn th => mp_tac (MATCH_MP step_nip th))
  \\ (impl_tac >- shift_tac)
  \\ (impl_tac >- shift_tac)
  \\ (impl_tac >- shift_tac)
  \\ disch_then (qspec_then `s1.clock - 1` mp_tac)
  \\ (impl_tac >- first_assum ACCEPT_TAC)
  \\ strip_tac
  \\ `no_install_prefix (shift_interfer l' mc_conf) s1.ffi (s1.clock - 1) ms2` by
       (irule no_install_prefix_mono \\ qexists_tac `SUC (s1.clock - 1)` \\ simp[])
  \\ nip_tail
QED
val _ = pr "CASE_PROVED CallFFI";

Resume compile_no_install_prefix[Install]:
  say "Install"
  \\ qpat_x_assum `lab_step_closed _` (strip_assume_tac o REWRITE_RULE [lab_step_closed_def])
  \\ qpat_x_assum `!s i bs n. Inv s ==> _` drule
  \\ simp[]
QED
val _ = pr "CASE_PROVED Install";

Resume compile_no_install_prefix[Halt]:
(* Halt *)
  say "Halt"
  \\ srw_tac[][]
  \\ qmatch_assum_rename_tac `asm_fetch s1 = SOME (LabAsm Halt l1 l2 l3)`
  \\ qmatch_assum_rename_tac `asm_fetch s1 = SOME (LabAsm Halt l bytes n)`
  \\ qabbrev_tac `ffi_names = TAKE (THE (mmio_pcs_min_index mc_conf.ffi_names)) mc_conf.ffi_names`
  \\ mp_tac IMP_bytes_in_memory_Halt \\ full_simp_tac(srw_ss())[]
  \\ match_mp_tac IMP_IMP \\ strip_tac
  THEN1 (full_simp_tac(srw_ss())[state_rel_def]
         \\ imp_res_tac bytes_in_mem_IMP \\ full_simp_tac(srw_ss())[])
  \\ rpt strip_tac \\ pop_assum mp_tac
  \\ qpat_abbrev_tac `jj = asm$Jump lll` \\ rpt strip_tac
  \\ (Q.ISPECL_THEN [`mc_conf`,`t1`,`ms1`,`s1.ffi`,`jj`]mp_tac
       asm_step_IMP_evaluate_step_find_next) \\ full_simp_tac(srw_ss())[]
  \\ MATCH_MP_TAC IMP_IMP2 \\ STRIP_TAC THEN1
   (full_simp_tac(srw_ss())[state_rel_def,asm_def,LET_DEF]
    \\ full_simp_tac(srw_ss())[asm_step_def,asm_def,LET_DEF]
    \\ imp_res_tac bytes_in_mem_IMP
    \\ full_simp_tac(srw_ss())[asmSemTheory.jump_to_offset_def,
          asmSemTheory.upd_pc_def]
    \\ rev_full_simp_tac(srw_ss())[] \\ unabbrev_all_tac
    \\ full_simp_tac(srw_ss())[asmSemTheory.jump_to_offset_def,
          asmSemTheory.upd_pc_def,asm_def]
    \\ fs[asm_fetch_def]
    \\ drule_all $ GEN_ALL IMP_bytes_in_memory
    \\ strip_tac
    \\ fs[]
    \\ drule_all $ GEN_ALL IMP_ffi_entry_pcs_disjoint_LabAsm
    \\ ho_match_mp_tac (
      PURE_REWRITE_RULE [satTheory.AND_IMP] o
      PURE_REWRITE_RULE [Once CONJ_SYM] $
      GEN_ALL ffi_entry_pcs_disjoint_LENGTH_shorter )
    \\ Cases_on `j`
    \\ gvs[line_similar_def,line_ok_def,line_length_def,line_bytes_def]
    \\ gvs[enc_with_nop_thm,LENGTH_APPEND]
  )
  \\ rpt strip_tac
  \\ unabbrev_all_tac \\ full_simp_tac(srw_ss())[asm_def]
  \\ FIRST_ASSUM (Q.SPEC_THEN `s1.clock`mp_tac) \\ srw_tac[][]
  \\ `mc_conf.target.get_pc ms2 = mc_conf.halt_pc` by
   (full_simp_tac(srw_ss())
      [encoder_correct_def,target_ok_def,target_state_rel_def]
    \\ res_tac
    \\ full_simp_tac(srw_ss())[]
    \\ full_simp_tac(srw_ss())[jump_to_offset_def,asmSemTheory.upd_pc_def]
    \\ full_simp_tac(srw_ss())[state_rel_def]
    \\ rewrite_tac [GSYM word_add_n2w,GSYM word_sub_def,WORD_SUB_PLUS,
         WORD_ADD_SUB] \\ full_simp_tac(srw_ss())[])
  \\ seg_split
  \\ `no_install_prefix (shift_interfer l' mc_conf) s1.ffi (s1.clock - 1) ms2` by
       (irule no_install_prefix_halt \\ fs[halt_ctx_def, shift_interfer_def])
  \\ nip_tail
QED
val _ = pr "CASE_PROVED Halt";

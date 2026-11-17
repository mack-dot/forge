val sm_defs = [share_mem_op_def, share_mem_load_def, share_mem_store_def];
val pc_tac = first_x_assum irule >> fs[mval_inv_def] >> metis_tac[];
val gen_val_tac = fs[mval_inv_def, APPLY_UPDATE_THM, lab_to_loc_def] >> rw[] >> fs[];
val inst_val_tac = (`mval_inv G D (asm_inst i s)` by (irule inst_thm >> simp[])) >> fs[mval_inv_def];
val ffi_val_tac = fs[mval_inv_def] >> rw[]
   >- (Cases_on `s.io_regs 0 (ExtCall name) r` >> fs[targetSemTheory.get_reg_value_def])
   >- (irule wb_thm >> conj_tac >- first_assum ACCEPT_TAC >> qexists_tac `D` >> fs[]);
val close_tac = FIRST [first_assum ACCEPT_TAC, gen_val_tac >> NO_TAC, inst_val_tac >> NO_TAC, ffi_val_tac >> NO_TAC, pc_tac >> NO_TAC];
val leaf_tac = strip_tac >> disj1_tac >> first_assum (irule_at (Pos hd)) >> simp upd_defs >> irule inv_next >> rpt conj_tac >>
               TRY (qexists_tac `s` >> simp upd_defs >> NO_TAC) >> simp upd_defs >> close_tac;
val unfold_tac = rpt strip_tac >> drule inv_facts >> strip_tac >> first_x_assum drule >> simp[step_ok_def, lab_to_loc_def] >> TRY (disch_then strip_assume_tac) >>
                 qpat_x_assum `evaluate _ = _` mp_tac >> simp[Once evaluate_def, get_pc_value_def];
val split_tac = rpt (TOP_CASE_TAC >> gvs[]);
val share_tac = qpat_x_assum `share_mem_op _ _ _ _ = _` mp_tac >> Cases_on `m` >> simp (sm_defs @ [AllCaseEqs()]) >> strip_tac >> gvs[];
val branches = [
  ("callffi",  ``LabAsm (CallFFI name) i bs n``,              unfold_tac >> split_tac >> leaf_tac),
  ("halt",     ``LabAsm Halt i bs n``,                        unfold_tac >> split_tac),
  ("install",  ``LabAsm Install i bs n``,                     unfold_tac),
  ("call",     ``LabAsm (Call lab) i bs n``,                  unfold_tac),
  ("jump",     ``LabAsm (Jump (Lab n1 n2)) i bs n``,          unfold_tac >> split_tac >> leaf_tac),
  ("jumpcmp",  ``LabAsm (JumpCmp c r ri (Lab n1 n2)) i bs n``, unfold_tac >> split_tac >> leaf_tac),
  ("locvalue", ``LabAsm (LocValue r (Lab n1 n2)) i bs n``,    unfold_tac >> split_tac >> leaf_tac),
  ("label",    ``Label k1 k2 k3``,                            unfold_tac),
  ("inst",     ``Asm (Asmi (Inst i)) bs n``,                  unfold_tac >> split_tac >> leaf_tac),
  ("jumpreg",  ``Asm (Asmi (JumpReg r)) bs n``,               unfold_tac >> split_tac >> leaf_tac),
  ("sharemem", ``Asm (ShareMem m r ad) bs n``,                unfold_tac >> split_tac >> TRY share_tac >> TRY (leaf_tac >> NO_TAC) >> TRY (gvs[] >> NO_TAC))];

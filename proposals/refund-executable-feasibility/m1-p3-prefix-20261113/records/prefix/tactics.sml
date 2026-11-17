val zero_tac = rw[nip_def, EQ_IMP_THM] >- (first_x_assum (qspecl_then [`ms`,`ffi`] mp_tac) >> simp[Once evaluate_def]) >>
     pop_assum mp_tac >> simp[Once evaluate_def] >> rw[] >> gvs[];
val mono_tac = rw[nip_def] >> first_x_assum irule >> qexistsl_tac [`ffi'`,`j`] >> simp[];
val all_tac = rw[nip_def, EQ_IMP_THM] >> metis_tac[LESS_EQ_REFL];
val halt_tac = rw[nip_def] >> Cases_on `j` >> qpat_x_assum `evaluate _ _ _ _ = _` mp_tac >> simp[Once evaluate_def] >> rw[] >> gvs[];
val next_tac =
  strip_tac >> simp[nip_def, EQ_IMP_THM] >> rpt strip_tac
  >- (`evaluate mc ffi (SUC j) ms = (TimeOut,ms',ffi')` by (simp[Once evaluate_def, apply_oracle_def] >> gvs[]) >>
      first_x_assum (qspecl_then [`SUC j`,`ms'`,`ffi'`] mp_tac) >> simp[]) >>
  Cases_on `j`
  >- (qpat_x_assum `evaluate _ _ _ _ = _` mp_tac >> simp[Once evaluate_def] >> strip_tac >> gvs[] >> metis_tac[]) >>
  qpat_x_assum `evaluate _ _ _ _ = _` mp_tac >> simp[Once evaluate_def, apply_oracle_def] >> gvs[] >>
  rw[] >> gvs[] >> metis_tac[];
val segment_tac = rw[nip_def] >> Cases_on `j <= l` >- metis_tac[] >>
           `?k. j = k + l /\ k <= n` by (qexists_tac `j - l` >> simp[]) >> gvs[] >> metis_tac[];
val all_lemmas = [("no_install_prefix_zero", zero_goal, zero_tac), ("no_install_prefix_mono", mono_goal, mono_tac),
  ("no_install_prefix_all", all_goal, all_tac), ("no_install_prefix_halt", halt_goal, halt_tac),
  ("no_install_prefix_next", next_goal, next_tac), ("no_install_prefix_segment", segment_goal, segment_tac)];

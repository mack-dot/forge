  qsuff_tac `nip_goal Inv mc_conf ffi ms
      (make_init mc_conf ffi t m dm sdm ms (filter_skip code) (compile_lab mc_conf.target.config)
         (n2w (LENGTH (prog_to_bytes q)) + mc_conf.target.get_pc ms) cbspace ((\(a,b). (a,filter_skip b)) o coracle)) q`
  >- (rewrite_tac[nip_goal_def] >> disch_then match_mp_tac >> rpt conj_tac
      >- first_assum ACCEPT_TAC
      >- (gen_tac >> qpat_x_assum `!k. Inv _` (qspec_then `k` mp_tac) >> simp[ELIM_UNCURRY])
      >- (fs[code_layout_ok_def, lab_to_targetTheory.ffi_offset_def])) >>
  rpt (qpat_x_assum `lab_step_closed _` kall_tac) >> rpt (qpat_x_assum `!k. Inv _` kall_tac) >>
  match_mp_tac (GEN_ALL nip_use) >>

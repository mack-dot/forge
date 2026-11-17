  match_mp_tac implements'_strengthen \\ qexists_tac `T` \\ rewrite_tac [] \\
  (* Forge tail: the published last step, with the lab facts collected first. *)
  rewrite_tac [implements'_def] \\ strip_tac \\
  `stackSem$semantics InitGlobals_location q <> Fail` by fs [] \\
  `labSem$semantics lab_st = stackSem$semantics InitGlobals_location q` by res_tac \\
  qmatch_goalsub_abbrev_tac `lab_guard _ LF` \\
  `LF` by (
    qunabbrev_tac `LF` \\
    rewrite_tac [lab_facts_def] \\
    qexistsl_tac [`t`,`m`,`dm`,`sdm`,`lab_oracle`] \\
    `?c1. backend$to_word mc.target.config c prog = (c1,p5)` by
       (qpat_x_assum `lab_keep_word _ _ _ _` mp_tac \\ rewrite_tac [lab_keep_word_def] \\
        Cases_on `backend$to_word mc.target.config c prog` \\ simp []) \\
    drule to_word_confs \\ strip_tac \\
    `SND (SND (backend$to_lab mc.target.config c prog)) = p7 /\
     (FST (SND (backend$to_lab mc.target.config c prog))).lab_conf = c.lab_conf` by
       (simp [to_lab_def, to_stack_def] \\ fs [Abbr `p7`, Abbr `stk`, Abbr `stoff`] \\ show_tac "TOLAB" \\ NO_TAC) \\
    asm_simp_tac (srw_ss()) [] \\
    rpt conj_tac \\ TRY (first_assum ACCEPT_TAC) \\ TRY (fs [] \\ NO_TAC) \\
    TRY (match_mp_tac lab_nonfail_unaligned \\ conj_tac >- fs [mc_conf_ok_def] \\
         qpat_x_assum `labSem$semantics lab_st = _` mp_tac \\ simp [Abbr `lab_st`] \\ NO_TAC) \\
    show_tac "LFREST" \\ NO_TAC) \\
  `lab_guard (machine_sem mc ffi ms) LF = machine_sem mc ffi ms` by
     (irule lab_guard_true \\ first_assum ACCEPT_TAC) \\
  pop_assum (fn th => rewrite_tac [th]) \\
  qpat_x_assum `implements' T (machine_sem _ _ _) _` mp_tac \\
  asm_simp_tac (srw_ss()) [implements'_def, extend_with_resource_limit'_def]
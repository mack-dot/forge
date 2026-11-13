val single_ok = prove (single_goal, single_tac);
val no_label_thm = prove (no_label_goal, no_label_tac);
val list_tac =
   rpt gen_tac >> strip_tac >> simp[word_to_wordTheory.compile_def] >> pairarg_tac >> simp[MEM_MAP] >> rpt strip_tac >>
   `LENGTH n_oracles = LENGTH progs` by (fs[next_n_oracle_def] >> every_case_tac >> gvs[]) >>
   PairCases_on `y` >> gvs[MEM_ZIP] >>
   rename1 `k < LENGTH progs` >> `MEM (EL k progs) progs` by metis_tac[MEM_EL] >>
   Cases_on `EL k progs` >> PairCases_on `r` >> fs[EVERY_MEM] >> first_x_assum drule >> simp[] >> strip_tac >>
   drule single_ok >> disch_then (qspecl_then [`wc`,`ac`,`r0`,`r2`,`EL k n_oracles`] strip_assume_tac) >>
   gvs[] >> metis_tac[];
val list_ok = prove (list_goal, list_tac);
val _ = (cv_auto_trans (INST_TYPE [alpha |-> ``:64``] no_label_def); cv_auto_trans (INST_TYPE [alpha |-> ``:64``] wordConvsTheory.good_handlers_def);
         cv_auto_trans (INST_TYPE [alpha |-> ``:64``] closed_def); cv_auto_trans (INST_TYPE [alpha |-> ``:64``] callers_def));
val prog_def = DB.fetch "forge_refundWholeProg" "refund_prog_def";
val _ = Feedback.trace ("Theory.allow_rebinds", 1) (cv_trans_deep_embedding EVAL) prog_def;
val c = EVAL ``arm8_config$arm8_backend_config``;
val conf_tm = rhs (concl c);
val p0_cv = ``SND (to_word_0_arm8 ^conf_tm refund_prog)``;
fun on_p0 th = th |> REWRITE_RULE [GSYM c, arm8_link];
val closed_thm = cv_eval ``labels_closed [29;31] ^p0_cv`` |> on_p0;
val open_thm = cv_eval ``labels_closed [29] ^p0_cv`` |> on_p0;
val callers_29 = cv_eval ``label_callers 29 ^p0_cv`` |> on_p0;
val callers_31 = cv_eval ``label_callers 31 ^p0_cv`` |> on_p0;
val count_thm = cv_eval ``LENGTH ^p0_cv`` |> on_p0;
val to_word_snd = prove (``SND (to_word ac c p) = SND (word_to_word$compile (FST (to_word_0 ac c p)).word_to_word_conf ac (SND (to_word_0 ac c p)))``,
  simp[to_word_thm, UNCURRY]);
val final_goal = ``!orac n m pp md.
   MEM (n,m,pp,md) (SND (to_word arm8_config (set_oracle arm8_backend_config orac) refund_prog)) /\
   n <> Install_location /\ n <> InstallData_location ==>
   Install_location NOTIN get_code_labels pp /\ InstallData_location NOTIN get_code_labels pp``;

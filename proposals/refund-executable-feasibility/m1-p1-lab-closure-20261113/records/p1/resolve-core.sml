val _ = List.app (fn th => (cv_auto_trans th; ())) trans_defs;
val prog_def = DB.fetch "forge_refundWholeProg" "refund_prog_def";
val _ = Feedback.trace ("Theory.allow_rebinds", 1) (cv_trans_deep_embedding EVAL) prog_def;
val c = EVAL ``arm8_config$arm8_backend_config``;
val conf_tm = rhs (concl c);
val c_oracle_tm = ``set_oracle ^conf_tm refund_alloc_oracle``;
val rcheck_pair = cv_eval ``resolve_check [29;31] ^c_oracle_tm refund_prog`` |> REWRITE_RULE [GSYM c];
val rcheck_single = cv_eval ``resolve_check [29] ^c_oracle_tm refund_prog`` |> REWRITE_RULE [GSYM c];
val rinfo = cv_eval ``resolve_info ^c_oracle_tm refund_prog`` |> REWRITE_RULE [GSYM c];
val lab_link = DB.fetch "forge_refundLabClosure" "lab_forge8_to_lab";
val L_tm = ``SND (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))``;
val twin_tac = ho_match_mp_tac (theorem "loc_pc_ind") >> rw[] >> simp[Once loc_pc_def, Once loc_to_pc_def] >>
   rpt (TOP_CASE_TAC >> gvs[]) >> Cases_on `h` >> gvs[];
val rclosed_goal = ``refs_ok [29;31] ^L_tm /\ fall_pairs [29;31] (flat_lines ^L_tm)``;
val rnot_goal = ``~(refs_ok [29] ^L_tm /\ fall_pairs [29] (flat_lines ^L_tm))``;
val rstats_goal = ``resolve_stats ^L_tm = (29095,5244,0,SOME 0)``;
val rmeaning_goal = ``!ls secs. refs_ok ls secs ==>
   !sec a i bs len n1 n2 p. MEM sec secs /\ ~MEM (Section_num sec) ls /\ MEM (LabAsm a i bs len) (Section_lines sec) /\
      (n1,n2) IN labProps$labs_of a /\ loc_to_pc n1 n2 secs = SOME p ==> pc_ok ls secs p``;
val p2s_goal = ``!sec a i bs len n1 n2 p. MEM sec ^L_tm /\ Section_num sec <> Install_location /\ Section_num sec <> InstallData_location /\
      MEM (LabAsm a i bs len) (Section_lines sec) /\ (n1,n2) IN labProps$labs_of a /\ loc_to_pc n1 n2 ^L_tm = SOME p ==>
      pc_ok [Install_location; InstallData_location] ^L_tm p``;
val the_lab = ``lab_forge8 (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog``;
val rclosed_tac = Cases_on `^the_lab` >- (mp_tac rcheck_pair >> simp[resolve_check_def]) >>
   drule lab_link >> strip_tac >> mp_tac rcheck_pair >> gvs[resolve_check_def];
val rnot_tac = Cases_on `^the_lab` >- (mp_tac rcheck_pair >> simp[resolve_check_def]) >>
   drule lab_link >> strip_tac >> mp_tac rcheck_single >> gvs[resolve_check_def];
val rstats_tac = Cases_on `^the_lab` >- (mp_tac rcheck_pair >> simp[resolve_check_def]) >>
   drule lab_link >> strip_tac >> mp_tac rinfo >> gvs[resolve_info_def];

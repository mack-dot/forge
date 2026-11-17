load "reg_allocComputeLib";
val _ = cv_auto_trans (lab_forge8_def |> SRULE [data_to_wordTheory.max_heap_limit_def, backend_commonTheory.word_shift_def]);
val _ = List.app (fn d => (cv_auto_trans d; ()))
   [asm_no_label_def, line_no_label_def, line_is_exit_def, is_label_def, sec_ends_exit_def, no_fall_def, lab_closed_def,
    line_is_install_def, line_is_jumpreg_def, line_is_locvalue_def, lab_stats_def, lab_names_def, lab_check_def, lab_info_def];
val arm8_fields = REWRITE_RULE [forge8_config_def] field_lemma;
val isa_bits_thm = EVAL ``isa_bits arm8_config``;
val lab_link = prove (lab_link_goal,
  simp[lab_forge8_def, arm8_link] >> pairarg_tac >> simp[AllCaseEqs()] >> strip_tac >> pairarg_tac >> gvs[] >>
  fs[GSYM w2w_link, GSYM cwts_link, forge8_config_def] >>
  `c0.word_to_word_conf = c0.word_to_word_conf` by simp[] >> drule w2w_inlogic_thm >> strip_tac >>
  simp[to_lab_def, to_stack_def, to_word_thm, word_to_stackTheory.compile_def] >> rpt (pairarg_tac >> gvs[]) >>
  gvs[arm8_fields, isa_bits_thm]);
(* The allocation oracle, recomputed by the published external allocator and KEPT as a defined constant. *)
val prog_def = DB.fetch "forge_refundWholeProg" "refund_prog_def";
val _ = Feedback.trace ("Theory.allow_rebinds", 1) (cv_trans_deep_embedding EVAL) prog_def;
val c = EVAL ``arm8_config$arm8_backend_config``;
val conf_tm = rhs (concl c);
val graphs_raw = cv_eval_raw ``FST (to_livesets_arm8 ^conf_tm refund_prog)`` |> concl |> rhs;
val oracles = reg_allocComputeLib.get_oracle_raw reg_alloc.Irc graphs_raw;
val oracle_def = new_definition ("refund_alloc_oracle_def", mk_eq (mk_var ("refund_alloc_oracle", type_of oracles), oracles));
val _ = Feedback.trace ("Theory.allow_rebinds", 1) (cv_trans_deep_embedding EVAL) oracle_def;
val oracle_tm = lhs (concl oracle_def);
val c_oracle_tm = ``set_oracle ^conf_tm ^oracle_tm``;
val th1 = cv_eval_raw ``compile_cake_arm8 ^c_oracle_tm refund_prog``;
val to_option_some = cv_typeTheory.to_option_def |> cj 2;
val to_pair = cv_typeTheory.to_pair_def |> cj 1;
val c2n_Num = cvTheory.c2n_def |> cj 1;
val th3 = th1 |> CONV_RULE (PATH_CONV "lr" (REWRITE_CONV [GSYM c]))
              |> CONV_RULE (PATH_CONV "r" (REWR_CONV to_option_some))
              |> CONV_RULE (PATH_CONV "rr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrrr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrrrr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrrrrr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrrrrrr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrrrrrrr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrrlr" (REWR_CONV c2n_Num)
                        THENC PATH_CONV "rrrrrlr" (REWR_CONV c2n_Num)
                        THENC PATH_CONV "rrrrrrrlr" (REWR_CONV c2n_Num));
(* Fail closed: each stored constant must be syntactically the recomputed value. *)
fun fold name path def th = CONV_RULE (PATH_CONV path (REWR_CONV (SYM def))) th
   handle _ => raise Fail ("Recomputed " ^ name ^ " differs from the stored constant");
val th4 = th3 |> fold "code" "rrlr" forge_refundArm8CompileTheory.code_def
              |> fold "data" "rrrrlr" forge_refundArm8CompileTheory.data_def
              |> fold "ffis" "rrrrrrlr" forge_refundArm8CompileTheory.ffis_def
              |> fold "conf" "rrrrrrrrr" forge_refundArm8CompileTheory.conf_def;
val _ = pr "SAME_AS_STORED code data ffis conf";
val compiled_full = MATCH_MP backend_arm8Theory.compile_cake_arm8_thm th4 |> REWRITE_RULE [LENGTH_NIL];
val compiled_goal = ``?c1. backend$compile arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog = SOME (code,data,c1)``;
val compiled_new = prove (compiled_goal, strip_assume_tac compiled_full >> metis_tac[]);
fun on_cfg th = th |> CONV_RULE (LAND_CONV (REWRITE_CONV [GSYM c]));
val check_pair = cv_eval ``lab_check [29;31] ^c_oracle_tm refund_prog`` |> REWRITE_RULE [GSYM c];
val check_single = cv_eval ``lab_check [29] ^c_oracle_tm refund_prog`` |> REWRITE_RULE [GSYM c];
val info_thm = cv_eval ``lab_info ^c_oracle_tm refund_prog`` |> REWRITE_RULE [GSYM c];
val L_tm = ``SND (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))``;
val closed_goal = ``lab_closed [29;31] ^L_tm``;
val not_closed_goal = ``~lab_closed [29] ^L_tm``;
val stats_goal = ``lab_stats ^L_tm = (558,[29],553,1206,[29;31])``;
val meaning_goal = ``!ls secs. lab_closed ls secs ==>
   !sec n1 n2. MEM sec secs /\ ~MEM (Section_num sec) ls /\ (n1,n2) IN sec_get_labels sec ==> ~MEM n1 ls``;
val p1_goal = ``!sec n1 n2. MEM sec ^L_tm /\ Section_num sec <> Install_location /\ Section_num sec <> InstallData_location /\
   (n1,n2) IN sec_get_labels sec ==> n1 <> Install_location /\ n1 <> InstallData_location``;
val target_goal = ``?c1. attach_bitmaps (FST (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog)))
     (FST (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))
     (lab_to_target$compile arm8_config
        (FST (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))).lab_conf ^L_tm) = SOME (code,data,c1)``;

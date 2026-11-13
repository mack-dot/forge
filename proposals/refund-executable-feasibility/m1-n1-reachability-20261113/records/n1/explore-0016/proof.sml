load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "wordConvsTheory";
load "wordConvsProofTheory"; load "backendProofTheory";
open preamble cv_transLib backendTheory word_to_wordTheory data_to_wordTheory wordConvsTheory wordConvsProofTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun stamp s = pr ("STAMP " ^ s ^ " " ^ Time.toString (Time.now ()));
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
(* Exploration only. Goal manager; nothing exported. *)
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_N1_OUT"));
val _ = new_theory "forge_n1Explore";
open proofManagerLib;
fun goals_now () = (top_goals ()) handle _ => [];
fun proved () = ((top_thm (); true) handle _ => false);
fun goal_string (asl, w) = String.concatWith "\n" (map (fn a => "  ASM " ^ term_to_string a) asl) ^ "\n  GOAL " ^ term_to_string w;
fun show label = (pr ("AFTER " ^ label ^ ": " ^ Int.toString (length (goals_now ())) ^ " goals, proved=" ^ Bool.toString (proved ()));
                  List.app (fn gl => pr (goal_string gl ^ "\n----")) (goals_now ()));
fun step label tac = ((e tac; show label) handle ex => (pr ("STEP_FAILED " ^ label ^ " " ^ exn_to_string ex); show ("failure of " ^ label)));
fun attempt label f = (f (); pr ("STEP_OK " ^ label)) handle ex => pr ("STEP_FAILED " ^ label ^ " :: " ^ exn_to_string ex);
val _ = List.app (fn (n, th) => if String.isSubstring "compile_0_arm8" n then pr ("ARM8_THM " ^ n ^ " :: " ^ thm_to_string th) else ())
          (DB.theorems "backend_arm8" @ DB.definitions "backend_arm8");
val arm8_link = prove (``to_word_0_arm8 c p = to_word_0 arm8_config c p``,
  simp[backend_arm8Theory.to_word_0_arm8_def, to_word_0_def, backend_arm8Theory.compile_0_arm8_def, compile_0_def, arm8_targetTheory.arm8_config_def]);
val oracle_indep = prove (``SND (to_word_0 ac (set_oracle c orac) p) = SND (to_word_0 ac c p)``,
  simp[to_word_0_def, to_data_def, to_bvi_def, to_bvl_def, to_clos_def, to_flat_def, set_oracle_def] >> rpt (pairarg_tac >> gvs[]));
val singleton = prove (``!wc ac f orac. SND (word_to_word$compile (wc with col_oracle := [orac]) ac [f]) =
     [full_compile_single (isa_bits ac) ac.two_reg_arith (ac.reg_count - (5 + LENGTH ac.avoid_regs)) wc.reg_alg ac (f, orac)]``,
  simp[word_to_wordTheory.compile_def, next_n_oracle_def]);
val fst_single = prove (``!bits tra rc alg ac n m pp md orac. FST (full_compile_single bits tra rc alg ac ((n,m,pp,md),orac)) = n``,
  simp[full_compile_single_def, compile_single_def] >> rpt gen_tac >> rpt (pairarg_tac >> gvs[]));
(* D: one function: labels after word_to_word are within the name and the labels before *)
val _ = g `!wc ac n m pp md orac. good_handlers n pp ==>
   ?m2 pp2 md2. full_compile_single (isa_bits ac) ac.two_reg_arith (ac.reg_count - (5 + LENGTH ac.avoid_regs)) wc.reg_alg ac ((n,m,pp,md), orac) = (n,m2,pp2,md2) /\
                get_code_labels pp2 SUBSET n INSERT get_code_labels pp`;
val gen_w2w = GEN_ALL word_good_code_labels_word_to_word;
val single_goal = ``!wc ac n m pp md orac. good_handlers n pp ==>
   ?m2 pp2 md2. full_compile_single (isa_bits ac) ac.two_reg_arith (ac.reg_count - (5 + LENGTH ac.avoid_regs)) wc.reg_alg ac ((n,m,pp,md), orac) = (n,m2,pp2,md2) /\
                get_code_labels pp2 SUBSET n INSERT get_code_labels pp``;
val single_tac =
   rpt strip_tac >>
   qspecl_then [`wc`,`ac`,`(n,m,pp,md)`,`orac`] assume_tac singleton >>
   qspecl_then [`isa_bits ac`,`ac.two_reg_arith`,`ac.reg_count - (5 + LENGTH ac.avoid_regs)`,`wc.reg_alg`,`ac`,`n`,`m`,`pp`,`md`,`orac`] assume_tac fst_single >>
   qspecl_then [`wc with col_oracle := [orac]`, `[(n,m,pp,md)]`] mp_tac gen_w2w >>
   disch_then (qspec_then `word_get_code_labels pp` mp_tac) >>
   disch_then (qspec_then `ac` mp_tac) >>
   qmatch_asmsub_abbrev_tac `FST out = n` >> PairCases_on `out` >>
   fs[markerTheory.Abbrev_def] >> pop_assum (assume_tac o SYM) >> fs[good_code_labels_def] >>
   strip_tac >> fs[SUBSET_DEF] >> metis_tac[];
val list_goal = ``!wc ac progs. EVERY (\(n,m,pp,md). good_handlers n pp) progs ==>
   !n m2 pp2 md2. MEM (n,m2,pp2,md2) (SND (word_to_word$compile wc ac progs)) ==>
     ?m pp md. MEM (n,m,pp,md) progs /\ get_code_labels pp2 SUBSET n INSERT get_code_labels pp``;
val no_label_def = Define `
  (no_label (l:num) (wordLang$Call r d a h) <=>
     (case d of SOME x => x <> l | NONE => T) /\
     (case r of SOME (_,_,x,_,_) => no_label l x | NONE => T) /\
     (case h of SOME (_,x,_,_) => no_label l x | NONE => T)) /\
  (no_label l (Seq p1 p2) <=> no_label l p1 /\ no_label l p2) /\
  (no_label l (Loop names p exit_names) <=> no_label l p) /\
  (no_label l (If _ _ _ p1 p2) <=> no_label l p1 /\ no_label l p2) /\
  (no_label l (MustTerminate p) <=> no_label l p) /\
  (no_label l (LocValue _ l1) <=> l1 <> l) /\
  (no_label l _ <=> T)`;
val no_label_goal = ``!l p. no_label l p <=> l NOTIN wordConvs$get_code_labels p``;
val no_label_tac = ho_match_mp_tac (theorem "no_label_ind") >> rw[no_label_def, wordConvsTheory.get_code_labels_def] >>
      rpt (TOP_CASE_TAC >> gvs[]) >> metis_tac[];
val closed_def = Define `labels_closed (ls:num list) ps =
   EVERY (\(n:num,m:num,pp,md:metadata). wordConvs$good_handlers n pp /\ (~MEM n ls ==> EVERY (\l. no_label l pp) ls)) ps`;
val callers_def = Define `label_callers (l:num) ps = MAP FST (FILTER (\(n:num,m:num,pp,md:metadata). ~no_label l pp) ps)`;
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
val _ = List.app (fn (n, th) => pr ("FACT " ^ n ^ " tags=" ^ String.concatWith "," (fst (Tag.dest_tag (Thm.tag th))) ^ " :: " ^ thm_to_string th))
   [("closed", closed_thm), ("open", open_thm), ("callers_29", callers_29), ("callers_31", callers_31), ("count", count_thm)];
val _ = g `^final_goal`;
val _ = step "f1" (rpt gen_tac >> strip_tac >> fs[to_word_snd, oracle_indep, Install_location_eq, InstallData_location_eq]);
val _ = step "f2" (qabbrev_tac `P0 = SND (to_word_0 arm8_config arm8_backend_config refund_prog)` >>
   `labels_closed [29;31] P0` by simp[Abbr`P0`, closed_thm]);
val _ = step "f3" (`EVERY (\(n,m,pp,md). good_handlers n pp) P0` by
   (pop_assum mp_tac >> simp[closed_def, EVERY_MEM, FORALL_PROD] >> metis_tac[]));
val _ = step "f4" (drule list_ok >> disch_then drule >> strip_tac);
val _ = step "f5" (qpat_x_assum `labels_closed _ _` mp_tac >> simp[closed_def, EVERY_MEM] >> disch_then drule >> simp[no_label_thm] >> strip_tac);
val _ = step "f6" (fs[SUBSET_DEF] >> metis_tac[]);
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

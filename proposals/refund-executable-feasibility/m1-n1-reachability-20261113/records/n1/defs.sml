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

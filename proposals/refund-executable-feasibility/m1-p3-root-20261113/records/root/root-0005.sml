(* Strengthened root lemma: every interior target state of a simulation segment is ordinary. *)
load "lab_to_targetProofTheory";
open preamble labSemTheory targetSemTheory targetPropsTheory asmPropsTheory lab_to_targetProofTheory
     forge_targetInstallPrefixTheory forge_simZeroCaseTheory forge_simLayoutTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_simRoot";
(* H: a clock-positive run that ends in TimeOut with no interference found starts on an ordinary address. *)
val head_goal = ``l <> 0 /\ find_next_interference c io l ms = NONE /\ targetSem$evaluate c io l ms = (TimeOut,ms2,io2) ==>
   c.target.get_pc ms IN (c.prog_addresses DIFF set c.ffi_entry_pcs)``;
val head_tac = strip_tac >> CCONTR_TAC >>
   qpat_x_assum `evaluate _ _ _ _ = _` mp_tac >> qpat_x_assum `find_next_interference _ _ _ _ = _` mp_tac >>
   simp[Once evaluate_def, Once find_next_interference_def, apply_oracle_def] >>
   rpt (TOP_CASE_TAC >> simp[]);
(* G: then every interior state of that run is on an ordinary address. *)
val interior_goal = ``!l c io ms ms2 io2. find_next_interference c io l ms = NONE /\ targetSem$evaluate c io l ms = (TimeOut,ms2,io2) ==>
   !j ms' io'. j < l /\ targetSem$evaluate c io j ms = (TimeOut,ms',io') ==>
     c.target.get_pc ms' IN (c.prog_addresses DIFF set c.ffi_entry_pcs)``;
val ev_suc = evaluate_def |> Q.SPECL [`c`,`io`,`SUC n`,`ms`] |> SIMP_RULE (srw_ss()) [apply_oracle_def] |> GEN_ALL;
val fn_suc = find_next_interference_def |> Q.SPECL [`c`,`io`,`SUC n`,`ms`] |> SIMP_RULE (srw_ss()) [apply_oracle_def] |> GEN_ALL;
val ev0 = Q.prove(`targetSem$evaluate c io 0 ms = (TimeOut,ms,io)`, simp[Once evaluate_def]);
val fn0 = Q.prove(`find_next_interference c io 0 ms = NONE`, simp[Once find_next_interference_def]);
fun interior_tac head_thm =
  Induct >- simp[] >> rpt gen_tac >> strip_tac >> rpt gen_tac >> strip_tac >>
  `c.target.get_pc ms IN (c.prog_addresses DIFF set c.ffi_entry_pcs)` by (irule head_thm >> qexistsl_tac [`io`,`io2`,`SUC l`,`ms2`] >> simp[]) >>
  Cases_on `j` >- (qpat_x_assum `evaluate _ _ 0 _ = _` mp_tac >> simp[Once evaluate_def] >> strip_tac >> gvs[]) >>
  rpt (qpat_x_assum `evaluate _ _ (SUC _) _ = _` mp_tac) >> qpat_x_assum `find_next_interference _ _ _ _ = _` mp_tac >>
  simp[ev_suc, fn_suc] >> gvs[] >> rw[] >> gvs[] >> first_x_assum drule_all >> simp[];
(* Any segment of the published shape (both equations) has only ordinary interior states. *)
val seg_hyp = ``!k. targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate c2 io2 k ms2 /\
                    find_next_interference c io (k + l) ms1 = find_next_interference c2 io2 k (ms2:'state)``;
val seg_interior_goal = ``^seg_hyp ==>
   !j ms' io'. j < l /\ targetSem$evaluate c io j ms1 = (TimeOut,ms',io') ==>
     c.target.get_pc ms' IN (c.prog_addresses DIFF set c.ffi_entry_pcs)``;
fun seg_interior_tac interior_thm = strip_tac >> match_mp_tac interior_thm >> qexistsl_tac [`ms2`,`io2`] >>
   first_x_assum (qspec_then `0` mp_tac) >> rewrite_tac[ADD_CLAUSES, ev0, fn0] >> simp[];
(* Segment end form: prefix up to the last interior state; the end state needs its own fact. *)
val seg_end_goal = ``^seg_hyp /\ l <> 0 /\ c.install_pc NOTIN c.prog_addresses ==>
   no_install_prefix c io (l - 1) ms1 /\
   (c.target.get_pc ms2 <> c.install_pc ==> no_install_prefix c io l ms1)``;
fun seg_end_tac seg_interior_thm = strip_tac >>
   `targetSem$evaluate c io l ms1 = (TimeOut,ms2,io2)` by (first_assum (qspec_then `0` mp_tac) >> rewrite_tac[ADD_CLAUSES, ev0] >> simp[]) >>
   drule seg_interior_thm >> strip_tac >>
   rw[no_install_prefix_def] >> spose_not_then strip_assume_tac >>
   (Cases_on `j < l` >- (qpat_x_assum `!j ms' io'. _` drule_all >> gvs[])) >>
   `j = l` by decide_tac >> gvs[];
(* Composition with clock offsets: segment of length l, then a prefix of length n from the end state. *)
val seg_compose_goal = ``^seg_hyp /\ c.install_pc NOTIN c.prog_addresses /\
   c2.install_pc = c.install_pc /\ c2.target = c.target /\ no_install_prefix c2 io2 n ms2 ==>
   no_install_prefix c io (l + n) ms1``;
fun seg_compose_tac seg_interior_thm = strip_tac >> drule seg_interior_thm >> strip_tac >>
   fs[no_install_prefix_def] >> rpt strip_tac >>
   Cases_on `j < l` >- (first_x_assum drule_all >> gvs[]) >>
   `?k. j = k + l /\ k <= n` by (qexists_tac `j - l` >> simp[]) >> gvs[] >> metis_tac[];
(* Strengthened root lemma: every original conclusion, plus the interior and prefix facts. *)
val root_pub = targetPropsTheory.asm_step_IMP_evaluate_step_find_next;
val (root_vars, root_body) = strip_forall (concl root_pub);
val (root_ante, root_conc) = dest_imp root_body;
val (root_ex, root_exbody) = strip_exists root_conc;
val [rc, rs1, rms1, rio, ri] = root_vars;
val (rl, rms2) = (el 1 root_ex, el 2 root_ex);
val root_s2 = ``asm ^ri ((^rs1).pc + n2w (LENGTH ((^rc).target.config.encode ^ri))) ^rs1``;
val root_goal = list_mk_forall (root_vars, mk_imp (root_ante, list_mk_exists (root_ex, list_mk_conj [root_exbody,
   ``!j ms' io'. j < ^rl /\ targetSem$evaluate ^rc ^rio j ^rms1 = (TimeOut,ms',io') ==>
        (^rc).target.get_pc ms' IN ((^rc).prog_addresses DIFF set (^rc).ffi_entry_pcs)``,
   ``(^rc).install_pc NOTIN (^rc).prog_addresses ==>
        no_install_prefix ^rc ^rio (^rl - 1) ^rms1 /\ ((^root_s2).pc <> (^rc).install_pc ==> no_install_prefix ^rc ^rio ^rl ^rms1)``])));
fun root_tac seg_interior_thm seg_end_thm = rpt gen_tac >> strip_tac >> drule_all root_pub >>
   disch_then (qspec_then `io` strip_assume_tac) >> qexistsl_tac [`l`,`ms2`] >>
   `c.target.get_pc ms2 = (^root_s2).pc` by (first_assum (qspec_then `0` strip_assume_tac) >> fs[target_state_rel_def]) >>
   `l <> 0` by (first_assum (qspec_then `0` strip_assume_tac)) >>
   `!k. targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate (shift_interfer l c) io k ms2 /\
        find_next_interference c io (k + l) ms1 = find_next_interference (shift_interfer l c) io k ms2` by
      (gen_tac >> qpat_assum `!k. _ /\ _ /\ target_state_rel _ _ _ /\ _` (qspec_then `k` mp_tac) >> simp[]) >>
   conj_tac >- (gen_tac >> qpat_assum `!k. _ /\ _ /\ target_state_rel _ _ _ /\ _` (qspec_then `k` mp_tac) >> simp[]) >>
   conj_tac >- (drule seg_interior_thm >> simp[]) >>
   strip_tac >> qpat_x_assum `!k. _ /\ _ /\ target_state_rel _ _ _ /\ _` kall_tac >> drule seg_end_thm >> simp[];
(* Generic strengthening of a published segment lemma whose conclusion has the form
   ?l ms2. !k. evaluate-eq /\ find_next-eq /\ target_state_rel c.target S2 ms2 /\ l <> 0. *)
fun strengthen pub =
  let val (vars, body) = strip_forall (concl pub)
      val (ante, conc) = dest_imp body
      val (ex, exbody) = strip_exists conc
      val (kv, kbody) = dest_forall exbody
      val cj = strip_conj kbody
      val (_, [cc, cio, _, cms1]) = strip_comb (lhs (el 1 cj))
      val (_, [_, s2tm, _]) = strip_comb (el 3 cj)
      val (lv, ms2v) = (el 1 ex, el 2 ex)
      val goal = list_mk_forall (vars, mk_imp (ante, list_mk_exists (ex, list_mk_conj [exbody,
        ``!j ms' io'. j < ^lv /\ targetSem$evaluate ^cc ^cio j ^cms1 = (TimeOut,ms',io') ==>
             (^cc).target.get_pc ms' IN ((^cc).prog_addresses DIFF set (^cc).ffi_entry_pcs)``,
        ``(^cc).install_pc NOTIN (^cc).prog_addresses ==>
             no_install_prefix ^cc ^cio (^lv - 1) ^cms1 /\ ((^s2tm).pc <> (^cc).install_pc ==> no_install_prefix ^cc ^cio ^lv ^cms1)``])))
      fun tac seg_interior_thm seg_end_thm =
        rpt gen_tac >> disch_then (fn th => strip_assume_tac th >> strip_assume_tac (SPEC_ALL (MATCH_MP pub th))) >>
        qexistsl_tac [`l`,`ms2`] >>
        `^(mk_eq (``(^cc).target.get_pc ^ms2v``, ``(^s2tm).pc``))` by (first_assum (qspec_then `0` strip_assume_tac) >> fs[target_state_rel_def]) >>
        `l <> 0` by (first_assum (qspec_then `0` strip_assume_tac)) >>
        `!k. targetSem$evaluate ^cc ^cio (k + l) ^cms1 = targetSem$evaluate (shift_interfer l ^cc) ^cio k ^ms2v /\
             find_next_interference ^cc ^cio (k + l) ^cms1 = find_next_interference (shift_interfer l ^cc) ^cio k ^ms2v` by
           (gen_tac >> qpat_assum `!k. _ /\ _ /\ target_state_rel _ _ _ /\ _` (qspec_then `k` mp_tac) >> simp[]) >>
        conj_tac >- (gen_tac >> qpat_assum `!k. _ /\ _ /\ target_state_rel _ _ _ /\ _` (qspec_then `k` mp_tac) >> simp[]) >>
        conj_tac >- (drule seg_interior_thm >> simp[]) >>
        strip_tac >> qpat_x_assum `!k. _ /\ _ /\ target_state_rel _ _ _ /\ _` kall_tac >> drule seg_end_thm >> simp[]
  in (goal, tac) end;
val (root_goal2, root_tac2) = strengthen targetPropsTheory.asm_step_IMP_evaluate_step_find_next;
val (nop_goal, nop_tac) = strengthen lab_to_targetProofTheory.asm_step_IMP_evaluate_step_nop;
(* Negative control model: one ordinary step enters the installer; the installer step leaves it. *)
val toy_tm = ``(ARB:(8,num,unit) machine_config) with
  <| prog_addresses := {0w}; ffi_entry_pcs := []; halt_pc := 5w; install_pc := 1w; ptr_reg := 0; len_reg := 0;
     next_interfer := (\k ms. ms); install_interfer := (\k x. 2);
     target := (ARB:(8,num,unit) target) with
       <| get_pc := (\ms. n2w ms); get_byte := (\ms a. 0w); get_reg := (\ms r. 0w); next := SUC; state_ok := (\ms. T);
          config := (ARB:asm_config) with <| encode := (\i. [0w]); code_alignment := 0 |> |> |>``;
val head_thm = store_thm ("run_head_ordinary", head_goal, head_tac);
val interior_thm = store_thm ("run_interior_ordinary", interior_goal, interior_tac head_thm);
val seg_interior_thm = store_thm ("segment_interior_ordinary", seg_interior_goal, seg_interior_tac interior_thm);
val seg_end_thm = store_thm ("segment_end_no_install_prefix", seg_end_goal, seg_end_tac seg_interior_thm);
val seg_compose_thm = store_thm ("segment_compose_no_install_prefix", seg_compose_goal, seg_compose_tac seg_interior_thm);
val _ = if aconv root_goal root_goal2 then () else raise Fail "Two constructions of the root goal differ";
val root_thm = store_thm ("asm_step_IMP_evaluate_step_find_next_prefix", root_goal2, root_tac2 seg_interior_thm seg_end_thm);
val nop_thm = store_thm ("asm_step_IMP_evaluate_step_nop_prefix", nop_goal, nop_tac seg_interior_thm seg_end_thm);
(* Fidelity: removing the two added conjuncts gives the published statements. *)
fun fidelity name pub th =
  let val (v, b) = strip_forall (concl th); val (a, c) = dest_imp b; val (ex, eb) = strip_exists c
      val back = list_mk_forall (v, mk_imp (a, list_mk_exists (ex, hd (strip_conj eb))))
  in if aconv back (concl pub) then pr ("FIDELITY " ^ name ^ ": published statement recovered by removing the two added conjuncts")
     else raise Fail ("Fidelity check failed: " ^ name) end;
val _ = fidelity "asm_step_IMP_evaluate_step_find_next_prefix" targetPropsTheory.asm_step_IMP_evaluate_step_find_next root_thm;
val _ = fidelity "asm_step_IMP_evaluate_step_nop_prefix" lab_to_targetProofTheory.asm_step_IMP_evaluate_step_nop nop_thm;
(* The form without the interference equation. *)
val pub8 = targetPropsTheory.asm_step_IMP_evaluate_step;
val (v8, b8) = strip_forall (concl pub8); val (a8, c8) = dest_imp b8; val (ex8, eb8) = strip_exists c8;
val added = tl (strip_conj (snd (strip_exists (snd (dest_imp (snd (strip_forall root_goal2)))))));
val step_goal = list_mk_forall (v8, mk_imp (a8, list_mk_exists (ex8, list_mk_conj (eb8 :: added))));
val step_tac = rpt gen_tac >> disch_then (strip_assume_tac o SPEC_ALL o MATCH_MP root_thm) >> qexistsl_tac [`l`,`ms2`] >>
   qpat_assum `!k. _ /\ _ /\ target_state_rel _ _ _ /\ _` (qspec_then `0` strip_assume_tac) >>
   rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >>
   gen_tac >> qpat_assum `!k. _ /\ _ /\ target_state_rel _ _ _ /\ _` (qspec_then `k` strip_assume_tac) >> first_assum ACCEPT_TAC;
val step_thm = store_thm ("asm_step_IMP_evaluate_step_prefix", step_goal, step_tac);
val _ = let val (v, b) = strip_forall (concl step_thm); val (a, c) = dest_imp b; val (ex, eb) = strip_exists c
            val cj = strip_conj eb
            val back = list_mk_forall (v, mk_imp (a, list_mk_exists (ex, list_mk_conj (List.take (cj, 3)))))
        in if aconv back (concl pub8) then pr "FIDELITY asm_step_IMP_evaluate_step_prefix: published statement recovered by removing the two added conjuncts"
           else raise Fail "Fidelity check failed: asm_step_IMP_evaluate_step_prefix" end;
(* Composition under state_rel: the installer entry is outside prog_addresses there. *)
val sr_compose_goal = ``lab_to_targetProof$state_rel (c,code2,labs,(p:'a word)) s1 t1 (ms1:'state) /\
   (!k. targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate c2 io2 k ms2 /\
        find_next_interference c io (k + l) ms1 = find_next_interference c2 io2 k (ms2:'state)) /\
   c2.install_pc = c.install_pc /\ c2.target = c.target /\ no_install_prefix c2 io2 n ms2 ==>
   no_install_prefix c io (l + n) ms1``;
val sr_compose_tac = strip_tac >> qpat_x_assum `!k. _` (mp_then (Pos hd) mp_tac seg_compose_thm) >>
   disch_then match_mp_tac >> fs[state_rel_def];
val sr_compose_thm = store_thm ("state_rel_segment_compose", sr_compose_goal, sr_compose_tac);
(* Negative control: both ends of a segment are off the installer entry, the evaluate equation holds,
   and an interior state is ON the installer entry. The interference equation is what fails. *)
val toy_def = Define `forge_toy_mc = ^toy_tm`;
val toy2_def = Define `forge_toy_mc2 = forge_toy_mc with <| next_interfer := shift_seq 1 forge_toy_mc.next_interfer;
                                                             install_interfer := shift_seq 1 forge_toy_mc.install_interfer |>`;
val toy1 = Q.prove (`targetSem$evaluate forge_toy_mc (io:'ffi ffi_state) (SUC n) 0 =
     targetSem$evaluate (forge_toy_mc with next_interfer := shift_seq 1 forge_toy_mc.next_interfer) io n 1`,
  simp[ev_suc, toy_def, encoded_bytes_in_mem_def, bytes_in_memory_def]);
val toy2 = Q.prove (`targetSem$evaluate (forge_toy_mc with next_interfer := shift_seq 1 forge_toy_mc.next_interfer) (io:'ffi ffi_state) (SUC n) 1 =
     targetSem$evaluate forge_toy_mc2 io n 2`,
  simp[ev_suc, toy_def, toy2_def, read_ffi_bytearray_def, read_bytearray_def]);
val toy_goal = ``(!k (io:'ffi ffi_state). targetSem$evaluate forge_toy_mc io (k + 2) 0 = targetSem$evaluate forge_toy_mc2 io k 2) /\
   forge_toy_mc2.install_pc = forge_toy_mc.install_pc /\ forge_toy_mc2.target = forge_toy_mc.target /\
   forge_toy_mc.install_pc NOTIN forge_toy_mc.prog_addresses /\
   forge_toy_mc.target.get_pc 0 <> forge_toy_mc.install_pc /\ forge_toy_mc.target.get_pc 2 <> forge_toy_mc.install_pc /\
   (!io:'ffi ffi_state. ~no_install_prefix forge_toy_mc io 2 0) /\
   (!io:'ffi ffi_state. find_next_interference forge_toy_mc io 2 0 <> find_next_interference forge_toy_mc2 io 0 2)``;
val toy_tac = rpt conj_tac
  >- (rpt gen_tac >> rewrite_tac[DECIDE ``k + 2 = SUC (SUC k)``, toy1, toy2])
  >- simp[toy_def, toy2_def] >- simp[toy_def, toy2_def] >- simp[toy_def] >- simp[toy_def] >- simp[toy_def]
  >- (gen_tac >> simp[no_install_prefix_def] >> qexistsl_tac [`1`,`1`,`io`] >>
      `targetSem$evaluate forge_toy_mc io 1 0 = (TimeOut,1,io)` by
         (mp_tac (Q.INST [`n` |-> `0`] toy1) >> rewrite_tac[ev0] >> simp[]) >>
      simp[toy_def])
  >- (gen_tac >> rewrite_tac[fn0, DECIDE ``2 = SUC (SUC 0)``] >>
      simp[Once fn_suc, toy_def, encoded_bytes_in_mem_def, bytes_in_memory_def] >>
      simp[Once find_next_interference_def, apply_oracle_def, read_ffi_bytearray_def, read_bytearray_def]);
val toy_thm = store_thm ("interior_install_example", toy_goal, toy_tac);
(* Endpoint correspondence alone does not give the prefix property. *)
val insufficient_goal = ``~(!(c:(8,num,unit) machine_config) c2 (io:'ffi ffi_state) l ms1 ms2.
   (!k. targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate c2 io k ms2) /\ c2.install_pc = c.install_pc /\ c2.target = c.target /\
   c.install_pc NOTIN c.prog_addresses /\ c.target.get_pc ms1 <> c.install_pc /\ c.target.get_pc ms2 <> c.install_pc ==>
   no_install_prefix c io l ms1)``;
val insufficient_tac = strip_tac >> first_x_assum (qspecl_then [`forge_toy_mc`,`forge_toy_mc2`,`ARB`,`2`,`0`,`2`] mp_tac) >> simp[toy_thm];
val insufficient_thm = store_thm ("endpoint_correspondence_insufficient", insufficient_goal, insufficient_tac);
val all = [("endpoint_correspondence_insufficient", insufficient_thm), ("run_head_ordinary", head_thm), ("run_interior_ordinary", interior_thm), ("segment_interior_ordinary", seg_interior_thm),
  ("segment_end_no_install_prefix", seg_end_thm), ("segment_compose_no_install_prefix", seg_compose_thm),
  ("asm_step_IMP_evaluate_step_find_next_prefix", root_thm), ("asm_step_IMP_evaluate_step_nop_prefix", nop_thm),
  ("asm_step_IMP_evaluate_step_prefix", step_thm), ("state_rel_segment_compose", sr_compose_thm), ("interior_install_example", toy_thm)];
val _ = List.app (fn (n, th) => (tags n th; pr ("CHECKED " ^ n ^ "\n" ^ thm_to_string th))) all;
val _ = show_types := true; val _ = List.app (fn (n, th) => pr ("TYPED " ^ n ^ "\n" ^ thm_to_string th)) all; val _ = show_types := false;
val _ = export_theory ();
val _ = pr "P3_PROOF_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

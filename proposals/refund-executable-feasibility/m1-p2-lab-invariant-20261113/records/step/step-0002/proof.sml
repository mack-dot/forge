(* P2, generic part: one-step and whole-run region invariant for the published lab semantics. *)
load "labSemTheory"; load "labPropsTheory";
open preamble labSemTheory labLangTheory forge_labRegionInvariantTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P2_OUT"));
val _ = new_theory "forge_labRegionStep";
val inv_def = region_inv_def;
val upd_defs = [inc_pc_def, dec_clock_def, upd_pc_def, upd_reg_def, asm_inst_consts];
(* Facts carried by the invariant, stated on s.code. *)
val inv_facts_goal = ``region_inv G OK code s ==>
   s.code = code /\ (!w. G (Word w)) /\ val_inv G s /\ OK s.pc /\
   (!n1 n2 p. G (Loc n1 n2) /\ loc_to_pc n1 n2 s.code = SOME p ==> OK p) /\
   (!line. asm_fetch s = SOME line ==> step_ok G OK s.code s.pc line)``;
val inv_facts_tac = rw[inv_def, region_hyp_def, asm_fetch_def] >> metis_tac[];
(* Re-establishing the invariant for a successor state. *)
val inv_next_goal = ``!s s2. region_inv G OK code s /\ s2.code = s.code /\ val_inv G s2 /\ OK s2.pc ==> region_inv G OK code s2``;
val inv_next_tac = rw[inv_def];
fun branch_goal line = ``!s res t. region_inv G OK code s /\ s.clock <> 0 /\ asm_fetch s = SOME ^line /\ evaluate s = (res,t) ==>
   (?s2. evaluate s2 = (res,t) /\ region_inv G OK code s2 /\ s2.clock < s.clock) \/ t = s``;
val inv_facts = prove (inv_facts_goal, inv_facts_tac);
val inv_next = prove (inv_next_goal, inv_next_tac);
val sm_defs = [share_mem_op_def, share_mem_load_def, share_mem_store_def];
val pc_tac = first_x_assum irule >> fs[val_inv_def] >> metis_tac[];
val gen_val_tac = fs[val_inv_def, APPLY_UPDATE_THM, lab_to_loc_def] >> rw[] >> fs[];
val inst_val_tac = (`val_inv G (asm_inst i s)` by (irule asm_inst_val_inv >> simp[])) >> fs[val_inv_def];
val ffi_val_tac = fs[val_inv_def] >> rw[]
   >- (Cases_on `s.io_regs 0 (ExtCall name) r` >> fs[targetSemTheory.get_reg_value_def])
   >- (irule write_bytearray_val_inv >> fs[]);
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
val one_step_goal = ``!s res t. region_inv G OK code s /\ evaluate s = (res,t) ==>
   (?s2. evaluate s2 = (res,t) /\ region_inv G OK code s2 /\ s2.clock < s.clock) \/ t = s``;
val run_goal = ``!k s res t. s.clock = k /\ region_inv G OK code s /\ evaluate s = (res,t) ==> region_inv G OK code t``;
val prefix_goal = ``!s k res t. region_inv G OK code s /\ evaluate (s with clock := k) = (res,t) ==>
   region_inv G OK code t /\ OK t.pc /\ t.code = code /\ (!i bs n. asm_fetch t <> SOME (LabAsm Install i bs n))``;
fun one_step_tac lemmas =
  rpt strip_tac >> Cases_on `s.clock = 0` >- (qpat_x_assum `evaluate _ = _` mp_tac >> simp[Once evaluate_def]) >>
  Cases_on `asm_fetch s` >- (qpat_x_assum `evaluate _ = _` mp_tac >> simp[Once evaluate_def]) >>
  rename1 `asm_fetch s = SOME x` >> Cases_on `x` >>
  TRY (rename1 `Asm aa` >> Cases_on `aa` >> TRY (rename1 `Asmi a2` >> Cases_on `a2`)) >>
  TRY (rename1 `LabAsm aa` >> Cases_on `aa`) >>
  TRY (rename1 `Jump lb` >> Cases_on `lb`) >> TRY (rename1 `JumpCmp _ _ _ lb` >> Cases_on `lb`) >> TRY (rename1 `LocValue _ lb` >> Cases_on `lb`) >>
  FIRST (map (fn th => drule_all th >> disch_then ACCEPT_TAC) lemmas @
         [qpat_x_assum `evaluate _ = _` mp_tac >> simp[Once evaluate_def] >> NO_TAC]);
fun run_tac one_step =
  completeInduct_on `k` >> rpt strip_tac >> drule_all one_step >> strip_tac
  >- (first_x_assum (qspec_then `s2.clock` mp_tac) >> impl_tac >- fs[] >>
      disch_then (qspecl_then [`s2`,`res`,`t`] mp_tac) >> simp[])
  >> gvs[];
fun prefix_tac run_thm =
  rpt gen_tac >> strip_tac >>
  `region_inv G OK code (s with clock := k)` by fs[inv_def, val_inv_def] >>
  `region_inv G OK code t` by (irule run_thm >> metis_tac[]) >>
  drule inv_facts >> strip_tac >> fs[] >> rpt strip_tac >> first_x_assum drule >> simp[step_ok_def];
val proved = map (fn (name, line, tac) => (name, GEN_ALL (prove (branch_goal line, tac)))) branches;
val lemmas = map snd proved;
val one_step = prove (one_step_goal, one_step_tac lemmas);
val run_thm = prove (run_goal, run_tac one_step);
val prefix_thm = prove (prefix_goal, prefix_tac run_thm);
(* Non-vacuity: the hypotheses are satisfiable. *)
val witness = prove (``region_hyp (\v. T) (\p. T) []``, simp[region_hyp_def, asm_fetch_aux_def]);
val stored = [("region_inv_facts", inv_facts), ("region_inv_next", inv_next)] @
  map (fn (n, th) => ("region_step_" ^ n, th)) proved @
  [("region_one_step", one_step), ("region_run", run_thm), ("region_prefix", prefix_thm), ("region_hyp_witness", witness)];
val _ = List.app (fn (n, th) => (tags n th; save_thm (n, th); pr ("CHECKED " ^ n ^ "\n" ^ thm_to_string th))) stored;
val _ = export_theory ();
val _ = pr "P2_PROOF_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

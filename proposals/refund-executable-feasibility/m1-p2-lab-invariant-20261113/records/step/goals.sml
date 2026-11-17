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

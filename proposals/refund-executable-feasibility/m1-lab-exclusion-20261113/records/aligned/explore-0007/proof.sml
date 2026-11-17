load "labSemTheory"; load "labPropsTheory";
open preamble labSemTheory labLangTheory forge_labRegionInvariantTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P2_OUT"));
val _ = new_theory "forge_alignedExplore";
(* Region invariant with memory constrained only on a covered address set D.
   D must contain every address at which a word load can succeed. *)
val mval_inv_def = Define `mval_inv G D (s:('a,'c,'ffi) labSem$state) <=> (!r. G (s.regs r)) /\ (!a. D a ==> G (s.mem a))`;
val covers_def = Define `load_covered (D:'a word -> bool) <=> !w:'a word. w2n w MOD (dimindex (:'a) DIV 8) = 0 ==> D w`;
val inv_def = Define `region_inv2 G D OK code (s:('a,'c,'ffi) labSem$state) <=>
   s.code = code /\ region_hyp G OK code /\ load_covered D /\ mval_inv G D s /\ OK s.pc`;
val upd_defs = [inc_pc_def, dec_clock_def, upd_pc_def, upd_reg_def, asm_inst_consts];
val all_defs = [arith_upd_def, binop_upd_def, upd_reg_def, assert_def, APPLY_UPDATE_THM, mem_op_def, mem_load_def, mem_load_byte_def,
   upd_mem_def, mem_load32_def, mem_store32_def, mem_store_def, mem_store_byte_def, addr_def, fp_upd_def, upd_fp_reg_def,
   wordSemTheory.mem_store_byte_aux_def, wordSemTheory.mem_store_32_def];
val inst_goal = ``!i s. (!w. G (Word w)) /\ load_covered D /\ mval_inv G D s /\ ~(asm_inst i s).failed ==> mval_inv G D (asm_inst i s)``;
val wb_goal = ``!bs w m. (!w. G (Word w)) /\ (!a. D a ==> G (m a)) ==> !a. D a ==> G (wordSem$write_bytearray w bs m dm be a)``;
val sub_tac = fs all_defs >> every_case_tac >> fs all_defs >> rw[] >> fs[] >> rw[] >> fs[] >> TRY (metis_tac[]);
val inst_tac =
  Cases >> rpt gen_tac >> strip_tac >> fs[mval_inv_def, covers_def, asm_inst_def] >>
  TRY (fs[upd_reg_def, APPLY_UPDATE_THM] >> rw[] >> fs[] >> NO_TAC) >>
  TRY (rename1 `arith_upd x` >> Cases_on `x` >> fs all_defs >> rpt gen_tac >> every_case_tac >> fs all_defs >>
       TRY (Cases_on `b`) >> fs all_defs >> rw[] >> fs[] >> metis_tac[]) >>
  TRY (rename1 `mem_op mm` >> Cases_on `mm` >> fs all_defs >> rpt (TOP_CASE_TAC >> gvs all_defs) >> rpt strip_tac >> rw[] >> fs[] >> TRY (metis_tac[] >> NO_TAC) >>
       gvs[AllCaseEqs()] >> rw[APPLY_UPDATE_THM] >> fs[] >> NO_TAC) >>
  TRY (rename1 `fp_upd ff` >> Cases_on `ff` >> sub_tac >> NO_TAC);
val wb_tac = Induct >> rw[wordSemTheory.write_bytearray_def] >> every_case_tac >> fs[] >>
   fs[wordSemTheory.mem_store_byte_aux_def] >> every_case_tac >> gvs[APPLY_UPDATE_THM] >> rw[] >> fs[];
val inv_facts_goal = ``region_inv2 G D OK code s ==>
   s.code = code /\ (!w. G (Word w)) /\ load_covered D /\ mval_inv G D s /\ OK s.pc /\
   (!n1 n2 p. G (Loc n1 n2) /\ loc_to_pc n1 n2 s.code = SOME p ==> OK p) /\
   (!line. asm_fetch s = SOME line ==> step_ok G OK s.code s.pc line)``;
val inv_facts_tac = rw[inv_def, region_hyp_def, asm_fetch_def] >> metis_tac[];
val inv_next_goal = ``!s s2. region_inv2 G D OK code s /\ s2.code = s.code /\ mval_inv G D s2 /\ OK s2.pc ==> region_inv2 G D OK code s2``;
val inv_next_tac = rw[inv_def];
fun branch_goal line = ``!s res t. region_inv2 G D OK code s /\ s.clock <> 0 /\ asm_fetch s = SOME ^line /\ evaluate s = (res,t) ==>
   (?s2. evaluate s2 = (res,t) /\ region_inv2 G D OK code s2 /\ s2.clock < s.clock) \/ t = s``;
open proofManagerLib;
fun goals_now () = (top_goals ()) handle _ => [];
fun proved () = ((top_thm (); true) handle _ => false);
fun clip s = if size s > 1300 then String.substring (s, 0, 500) ^ "\n  ...\n" ^ String.substring (s, size s - 700, 700) else s;
fun goal_string (asl, w) = String.concatWith "\n" (map (fn a => "  ASM " ^ term_to_string a) asl) ^ "\n  GOAL " ^ term_to_string w;
fun show label = (pr ("AFTER " ^ label ^ ": " ^ Int.toString (length (goals_now ())) ^ " goals, proved=" ^ Bool.toString (proved ()));
                  List.app (fn gl => pr (clip (goal_string gl) ^ "\n----")) (List.take (goals_now (), Int.min (2, length (goals_now ())))));
(* Run stages in order on the top goal; stop at the first failure. Returns the theorem if proved. *)
fun run name goal stages =
  let val _ = (proofManagerLib.g `^goal`; ())
      fun go [] = ()
        | go ((label, tac) :: rest) =
            ((e tac; if proved () then pr ("STAGE_OK " ^ name ^ "/" ^ label ^ " (proved)") else (pr ("STAGE_OK " ^ name ^ "/" ^ label); go rest))
             handle ex => (pr ("STAGE_FAILED " ^ name ^ "/" ^ label ^ " :: " ^ exn_to_string ex); show (name ^ "/" ^ label)))
      val _ = go stages
  in if proved () then (pr ("LEMMA_PROVED " ^ name); SOME (top_thm ()))
     else (pr ("LEMMA_OPEN " ^ name); show (name ^ " end"); NONE) end;
val it0 = run "inst" inst_goal [("all", inst_tac)];
val wb0 = run "wb" wb_goal [("all", wb_tac)];
val inst_thm = valOf it0; val wb_thm = valOf wb0;
val inv_facts = prove (inv_facts_goal, inv_facts_tac);
val inv_next = prove (inv_next_goal, inv_next_tac);
val sm_defs = [share_mem_op_def, share_mem_load_def, share_mem_store_def];
val pc_tac = first_x_assum irule >> fs[mval_inv_def] >> metis_tac[];
val gen_val_tac = fs[mval_inv_def, APPLY_UPDATE_THM, lab_to_loc_def] >> rw[] >> fs[];
val inst_val_tac = (`mval_inv G D (asm_inst i s)` by (irule inst_thm >> simp[])) >> fs[mval_inv_def];
val ffi_val_tac = fs[mval_inv_def] >> rw[]
   >- (Cases_on `s.io_regs 0 (ExtCall name) r` >> fs[targetSemTheory.get_reg_value_def])
   >- (irule wb_thm >> qexists_tac `D` >> fs[]);
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
val one_step_goal = ``!s res t. region_inv2 G D OK code s /\ evaluate s = (res,t) ==>
   (?s2. evaluate s2 = (res,t) /\ region_inv2 G D OK code s2 /\ s2.clock < s.clock) \/ t = s``;
val run_goal = ``!k s res t. s.clock = k /\ region_inv2 G D OK code s /\ evaluate s = (res,t) ==> region_inv2 G D OK code t``;
val prefix_goal = ``!s k res t. region_inv2 G D OK code s /\ evaluate (s with clock := k) = (res,t) ==>
   region_inv2 G D OK code t /\ OK t.pc /\ t.code = code /\ (!i bs n. asm_fetch t <> SOME (LabAsm Install i bs n))``;
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
  `region_inv2 G D OK code (s with clock := k)` by fs[inv_def, mval_inv_def] >>
  `region_inv2 G D OK code t` by (irule run_thm >> metis_tac[]) >>
  drule inv_facts >> strip_tac >> fs[] >> rpt strip_tac >> first_x_assum drule >> simp[step_ok_def];
val results = map (fn (name, line, tac) => (name, run name (branch_goal line) [("all", tac)])) branches;
val _ = pr ("SUMMARY " ^ String.concatWith " " (map (fn (n, r) => n ^ "=" ^ (if isSome r then "PROVED" else "OPEN")) results));
val lemmas = map (GEN_ALL o valOf o snd) results;
val os = run "one_step" one_step_goal [("all", one_step_tac lemmas)];
val rn = run "run" run_goal [("all", run_tac (valOf os))];
val px = run "prefix" prefix_goal [("all", prefix_tac (valOf rn))];
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

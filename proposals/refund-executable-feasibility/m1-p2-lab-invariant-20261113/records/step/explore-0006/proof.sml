load "labSemTheory"; load "labPropsTheory";
open preamble labSemTheory labLangTheory forge_labRegionInvariantTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P2_OUT"));
val _ = new_theory "forge_p2Explore";
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
val inv_facts = prove (inv_facts_goal, inv_facts_tac);
val inv_next = prove (inv_next_goal, inv_next_tac);
val sm_defs = [share_mem_op_def, share_mem_load_def, share_mem_store_def];
val pc_tac = first_x_assum irule >> fs[val_inv_def] >> metis_tac[];
val gen_val_tac = fs[val_inv_def, APPLY_UPDATE_THM] >> rw[] >> fs[];
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
val _ = run "locvalue" (branch_goal ``LabAsm (LocValue r (Lab n1 n2)) i bs n``)
  [("unfold", unfold_tac), ("split", split_tac),
   ("l1", strip_tac >> disj1_tac >> first_assum (irule_at (Pos hd)) >> simp upd_defs),
   ("l2", irule inv_next >> rpt conj_tac >> TRY (qexists_tac `s` >> simp upd_defs >> NO_TAC)),
   ("l3", simp upd_defs), ("l4", close_tac), ("l5", simp upd_defs >> close_tac)];
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

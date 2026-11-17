(* Generic region invariant for the published lab semantics: definitions and two
   preservation lemmas. The one-step and whole-evaluation theorems are NOT proved here. *)
load "labSemTheory"; load "labPropsTheory";
open preamble labSemTheory labLangTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P2_OUT"));
val _ = new_theory "forge_labRegionInvariant";
(* A generic region invariant for the published lab semantics.
   G is a predicate on values (true of every Word). OK is a predicate on program counters. *)
val val_inv_def = Define `val_inv G (s:('a,'c,'ffi) labSem$state) <=> (!r. G (s.regs r)) /\ (!a. G (s.mem a))`;
val step_ok_def = Define `
  step_ok G OK code (pc:num) line =
    case line of
      Asm (Asmi (Inst _)) _ _ => OK (pc + 1)
    | Asm (Asmi _) _ _ => T
    | Asm (ShareMem _ _ _) _ _ => OK (pc + 1)
    | LabAsm Halt _ _ _ => T
    | LabAsm (LocValue r lab) _ _ _ => G (lab_to_loc lab) /\ OK (pc + 1)
    | LabAsm (Jump (Lab n1 n2)) _ _ _ => (!p. loc_to_pc n1 n2 code = SOME p ==> OK p)
    | LabAsm (JumpCmp _ _ _ (Lab n1 n2)) _ _ _ => (!p. loc_to_pc n1 n2 code = SOME p ==> OK p) /\ OK (pc + 1)
    | LabAsm (Call _) _ _ _ => F
    | LabAsm Install _ _ _ => F
    | LabAsm (CallFFI _) _ _ _ => T
    | Label _ _ _ => T`;
val region_hyp_def = Define `
  region_hyp G OK code <=>
    (!w. G (Word w)) /\
    (!pc line. asm_fetch_aux pc code = SOME line /\ OK pc ==> step_ok G OK code pc line) /\
    (!n1 n2 p. G (Loc n1 n2) /\ loc_to_pc n1 n2 code = SOME p ==> OK p)`;
val inst_goal = ``!i s. (!w. G (Word w)) /\ val_inv G s ==> val_inv G (asm_inst i s)``;
val main_goal = ``!s res s'. evaluate s = (res,s') ==>
   region_hyp G OK s.code /\ val_inv G s /\ OK s.pc ==> val_inv G s' /\ OK s'.pc /\ s'.code = s.code``;
val all_defs = [arith_upd_def, binop_upd_def, upd_reg_def, assert_def, APPLY_UPDATE_THM, mem_op_def, mem_load_def, mem_load_byte_def,
   upd_mem_def, mem_load32_def, mem_store32_def, mem_store_def, mem_store_byte_def, addr_def, fp_upd_def, upd_fp_reg_def,
   wordSemTheory.mem_store_byte_aux_def, wordSemTheory.mem_store_32_def];
val sub_tac = fs all_defs >> every_case_tac >> fs all_defs >> rw[] >> fs[] >> rw[] >> fs[];
val inst_tac =
  Cases >> rpt gen_tac >> strip_tac >> fs[val_inv_def, asm_inst_def] >>
  TRY (fs[upd_reg_def, APPLY_UPDATE_THM] >> rw[] >> fs[] >> NO_TAC) >>
  TRY (rename1 `arith_upd x` >> Cases_on `x` >> fs all_defs >> rpt gen_tac >> every_case_tac >> fs all_defs >>
       TRY (Cases_on `b`) >> fs all_defs >> rw[] >> fs[] >> metis_tac[]) >>
  TRY (rename1 `mem_op mm` >> Cases_on `mm` >> sub_tac >> NO_TAC) >>
  TRY (rename1 `fp_upd ff` >> Cases_on `ff` >> sub_tac >> NO_TAC);
val inst_tac =
  Cases >> rpt gen_tac >> strip_tac >> fs[val_inv_def, asm_inst_def] >>
  TRY (fs[upd_reg_def, APPLY_UPDATE_THM] >> rw[] >> fs[] >> NO_TAC) >>
  TRY (rename1 `arith_upd x` >> Cases_on `x` >> fs all_defs >> rpt gen_tac >> every_case_tac >> fs all_defs >>
       TRY (Cases_on `b`) >> fs all_defs >> rw[] >> fs[] >> metis_tac[]) >>
  TRY (rename1 `mem_op mm` >> Cases_on `mm` >> sub_tac >> NO_TAC) >>
  TRY (rename1 `fp_upd ff` >> Cases_on `ff` >> sub_tac >> NO_TAC);
val inv_def = Define `region_inv G OK code (s:('a,'c,'ffi) labSem$state) <=>
   s.code = code /\ region_hyp G OK code /\ val_inv G s /\ OK s.pc`;
val wb_goal = ``!bs w m. (!w. G (Word w)) /\ (!a. G (m a)) ==> !a. G (wordSem$write_bytearray w bs m dm be a)``;
val asm_inst_val_inv = store_thm ("asm_inst_val_inv", inst_goal, inst_tac);
val write_bytearray_val_inv = store_thm ("write_bytearray_val_inv", wb_goal,
   Induct >> rw[wordSemTheory.write_bytearray_def] >> every_case_tac >> fs[] >>
   fs[wordSemTheory.mem_store_byte_aux_def] >> every_case_tac >> gvs[APPLY_UPDATE_THM] >> rw[] >> fs[]);
val _ = List.app (fn (n, th) => (tags n th; pr ("CHECKED " ^ n ^ "\n" ^ thm_to_string th)))
   [("asm_inst_val_inv", asm_inst_val_inv), ("write_bytearray_val_inv", write_bytearray_val_inv)];
val _ = pr ("PROPOSED_NOT_PROVED one_step\n" ^ term_to_string ``!s res t. region_inv G OK code s /\ evaluate s = (res,t) ==>
   (?s2. evaluate s2 = (res,t) /\ region_inv G OK code s2 /\ s2.clock < s.clock) \/ t = s``);
val _ = pr ("PROPOSED_NOT_PROVED whole_run\n" ^ term_to_string main_goal);
val _ = export_theory ();
val _ = pr "P2_PROOF_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

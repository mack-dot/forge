load "labSemTheory"; load "labPropsTheory";
open preamble labSemTheory labLangTheory forge_labRegionInvariantTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P2_OUT"));
val _ = new_theory THEORY_NAME;
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

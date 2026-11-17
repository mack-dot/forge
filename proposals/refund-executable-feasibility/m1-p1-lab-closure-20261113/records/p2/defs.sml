load "labSemTheory"; load "labPropsTheory";
open preamble labSemTheory labLangTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P2_OUT"));
val _ = new_theory THEORY_NAME;
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

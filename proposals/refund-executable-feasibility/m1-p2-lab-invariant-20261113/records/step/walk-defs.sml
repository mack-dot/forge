load "labSemTheory"; load "labPropsTheory";
open preamble labSemTheory labLangTheory forge_labRegionInvariantTheory forge_labRegionStepTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P2_OUT"));
val _ = new_theory THEORY_NAME;
(* A per-line check, generic in a program-counter predicate okp and a label resolver rs,
   and a walk over the program that visits lines exactly as labSem$asm_fetch_aux counts them. *)
val line_ok_def = Define `
  line_ok (okp:num -> bool) (rs:num -> num -> num option) (pc:num) line =
    case line of
      Asm (Asmi (Inst _)) _ _ => okp (pc + 1)
    | Asm (Asmi _) _ _ => T
    | Asm (ShareMem _ _ _) _ _ => okp (pc + 1)
    | LabAsm Halt _ _ _ => T
    | LabAsm (LocValue r (Lab n1 n2)) _ _ _ => (case rs n1 n2 of NONE => T | SOME p => okp p) /\ okp (pc + 1)
    | LabAsm (Jump (Lab n1 n2)) _ _ _ => (case rs n1 n2 of NONE => T | SOME p => okp p)
    | LabAsm (JumpCmp _ _ _ (Lab n1 n2)) _ _ _ => (case rs n1 n2 of NONE => T | SOME p => okp p) /\ okp (pc + 1)
    | LabAsm (Call _) _ _ _ => F
    | LabAsm Install _ _ _ => F
    | LabAsm (CallFFI _) _ _ _ => T
    | Label _ _ _ => T`;
val hyp_walk_def = Define `
  (hyp_walk okp rs (pc:num) [] = T) /\
  (hyp_walk okp rs pc ((Section k [] md)::xs) = hyp_walk okp rs pc xs) /\
  (hyp_walk okp rs pc ((Section k (y::ys) md)::xs) =
     if is_Label y then hyp_walk okp rs pc ((Section k ys md)::xs)
     else (okp pc ==> line_ok okp rs pc y) /\ hyp_walk okp rs (pc + 1) ((Section k ys md)::xs))`;
val loc_good_def = Define `
  loc_good okp code v = case v of Loc n1 n2 => (!p. loc_to_pc n1 n2 code = SOME p ==> okp p) | Word _ => T`;
val walk_goal = ``!okp rs k secs. hyp_walk okp rs k secs ==>
   !pc line. asm_fetch_aux pc secs = SOME line /\ okp (k + pc) ==> line_ok okp rs (k + pc) line``;
val line_goal = ``!line pc. line_ok okp (\n1 n2. loc_to_pc n1 n2 code) pc line ==> step_ok (loc_good okp code) okp code pc line``;
val hyp_goal = ``!okp code. hyp_walk okp (\n1 n2. loc_to_pc n1 n2 code) 0 code ==> region_hyp (loc_good okp code) okp code``;
val walk_tac = ho_match_mp_tac (theorem "hyp_walk_ind") >> rw[hyp_walk_def, asm_fetch_aux_def] >> gvs[] >>
   TRY (first_x_assum drule >> simp[] >> NO_TAC) >>
   TRY (Cases_on `pc` >> gvs[ADD1] >> first_x_assum drule >> simp[] >> NO_TAC);
val line_tac = Cases >> simp[line_ok_def, step_ok_def] >> rpt gen_tac >>
   rpt (TOP_CASE_TAC >> gvs[loc_good_def, lab_to_loc_def]) >> rw[] >> gvs[];
fun hyp_tac walk_thm line_thm = rw[region_hyp_def, loc_good_def]
   >- (irule line_thm >> drule walk_thm >> disch_then (qspecl_then [`pc`,`line`] mp_tac) >> simp[])
   >- (first_x_assum irule >> simp[]);

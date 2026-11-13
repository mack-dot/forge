(* Exploration only: goal-manager check of the explicit composed statement.
   It stores no theorem and exports no theory. *)
open HolKernel Parse boolLib bossLib arm8Theory arm8_stepTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
val words = ["37f800c0","52800028","39000268","a9417bfd","a8c24ff4","d65f03c0"];
val all = map arm8_stepLib.arm8_step_hex words;
fun positive_bit h = not (is_neg h) andalso can (find_term (fn t => same_const t ``word_bit``)) h;
val taken = hd (List.filter (fn th => List.exists positive_bit (hyp th)) (hd all));
val steps = taken :: map hd (tl all);
val s = ``s:arm8_state``;
val simp_thms = [combinTheory.APPLY_UPDATE_THM, wordsTheory.WORD_ADD_0];
fun advance (th, (state, acc)) =
  let val th1 = INST [s |-> state] th
      val th2 = CONV_RULE (RHS_CONV (RAND_CONV (SIMP_CONV (srw_ss()) simp_thms))) th1 handle UNCHANGED => th1
  in (rand (rhs (concl th2)), th2 :: acc) end;
val (final, rev_ths) = List.foldl advance (s, []) steps;
val chain_ths = List.rev rev_ths;
val states = map (fn th => rand (rhs (concl th))) chain_ths;
val chain_imp = DISCH_ALL (LIST_CONJ chain_ths) |> REWRITE_RULE [AND_IMP_INTRO];
val statement = ``!s.
  ~s.SCTLR_EL1.E0E /\ ~s.SCTLR_EL1.SA0 /\ ~s.TCR_EL1.TBI0 /\ ~s.TCR_EL1.TBI1 /\
  s.PSTATE.EL = 0w /\ s.exception = NoException /\
  aligned 2 s.PC /\ aligned 3 s.SP_EL0 /\
  word_bit 31 (w2w (s.REG 0w) : word32) /\
  s.MEM s.PC = 192w /\
  s.MEM (s.PC + 1w) = 0w /\
  s.MEM (s.PC + 2w) = 248w /\
  s.MEM (s.PC + 3w) = 55w /\
  s.MEM (s.PC + 24w) = 40w /\
  s.MEM (s.PC + 25w) = 0w /\
  s.MEM (s.PC + 26w) = 128w /\
  s.MEM (s.PC + 27w) = 82w /\
  s.MEM (s.PC + 28w) = 104w /\
  s.MEM (s.PC + 29w) = 2w /\
  s.MEM (s.PC + 30w) = 0w /\
  s.MEM (s.PC + 31w) = 57w /\
  s.MEM (s.PC + 32w) = 253w /\
  s.MEM (s.PC + 33w) = 123w /\
  s.MEM (s.PC + 34w) = 65w /\
  s.MEM (s.PC + 35w) = 169w /\
  s.MEM (s.PC + 36w) = 244w /\
  s.MEM (s.PC + 37w) = 79w /\
  s.MEM (s.PC + 38w) = 194w /\
  s.MEM (s.PC + 39w) = 168w /\
  s.MEM (s.PC + 40w) = 192w /\
  s.MEM (s.PC + 41w) = 3w /\
  s.MEM (s.PC + 42w) = 95w /\
  s.MEM (s.PC + 43w) = 214w /\
  s.REG 19w <> s.PC + 32w /\
  s.REG 19w <> s.PC + 33w /\
  s.REG 19w <> s.PC + 34w /\
  s.REG 19w <> s.PC + 35w /\
  s.REG 19w <> s.PC + 36w /\
  s.REG 19w <> s.PC + 37w /\
  s.REG 19w <> s.PC + 38w /\
  s.REG 19w <> s.PC + 39w /\
  s.REG 19w <> s.PC + 40w /\
  s.REG 19w <> s.PC + 41w /\
  s.REG 19w <> s.PC + 42w /\
  s.REG 19w <> s.PC + 43w ==>
  ?s1 s2 s3 s4 s5.
    NextStateARM8 s = SOME s1 /\ NextStateARM8 s1 = SOME s2 /\
    NextStateARM8 s2 = SOME s3 /\ NextStateARM8 s3 = SOME s4 /\
    NextStateARM8 s4 = SOME s5 /\
    NextStateARM8 s5 = SOME (s with
      <| MEM := (s.REG 19w =+ 1w) s.MEM;
         PC := mem_dword ((s.REG 19w =+ 1w) s.MEM) (s.SP_EL0 + 24w);
         REG := (19w =+ mem_dword ((s.REG 19w =+ 1w) s.MEM) (s.SP_EL0 + 8w))
                ((20w =+ mem_dword ((s.REG 19w =+ 1w) s.MEM) s.SP_EL0)
                 ((30w =+ mem_dword ((s.REG 19w =+ 1w) s.MEM) (s.SP_EL0 + 24w))
                  ((29w =+ mem_dword ((s.REG 19w =+ 1w) s.MEM) (s.SP_EL0 + 16w))
                   ((8w =+ 1w) s.REG))));
         SP_EL0 := s.SP_EL0 + 32w;
         branch_hint := SOME BranchType_RET |>)``;
open proofManagerLib;
val _ = pr ("CHAIN_IMP\n" ^ thm_to_string chain_imp);
fun goals_now () = (top_goals ()) handle _ => [];
fun proved () = ((top_thm (); true) handle _ => false);
fun show label =
  (pr ("STATE " ^ label ^ " goals=" ^ Int.toString (length (goals_now ())));
   case goals_now () of
     [] => pr "NO_OPEN_GOAL"
   | (asms,gl)::_ =>
       (List.app (fn t => pr ("ASSUMPTION " ^ term_to_string t)) asms;
        pr ("GOAL " ^ term_to_string gl); pr "END_GOAL"));
fun step label mk =
  ((e (mk ()); pr ("STEP_OK " ^ label); show label; true)
   handle ex => (pr ("STEP_FAIL " ^ label ^ " :: " ^ exn_to_string ex); false));
val _ = set_goal ([], statement);
val _ = step "strip" (fn () => rpt strip_tac);
val _ = step "exists" (fn () => map_every exists_tac (List.take (states, 5)));
val _ = step "mp" (fn () => mp_tac chain_imp);
val ok = step "impl" (fn () => impl_tac >-
  simp [combinTheory.APPLY_UPDATE_THM, alignmentTheory.aligned_add_sub_123, alignmentTheory.aligned_numeric]);
val _ = if ok then true else
  (step "impl-open" (fn () => impl_tac);
   step "impl-simp" (fn () => simp [combinTheory.APPLY_UPDATE_THM, alignmentTheory.aligned_add_sub_123,
                                    alignmentTheory.aligned_numeric]));
val _ = if proved () then true else step "final" (fn () => simp [combinTheory.APPLY_UPDATE_THM]);
val _ = if proved () then true else step "final-ext" (fn () =>
  simp [arm8_state_component_equality, FUN_EQ_THM, combinTheory.APPLY_UPDATE_THM] >> rw [] >> fs []);
val _ = pr ("FINAL proved=" ^ Bool.toString (proved ()));
val _ = (pr ("EXPLORE_THEOREM\n" ^ thm_to_string (top_thm ()))) handle _ => ();
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

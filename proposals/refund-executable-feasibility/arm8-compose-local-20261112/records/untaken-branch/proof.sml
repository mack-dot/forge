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
val altered = ``!s.
  ~s.SCTLR_EL1.E0E /\ ~s.SCTLR_EL1.SA0 /\ ~s.TCR_EL1.TBI0 /\ ~s.TCR_EL1.TBI1 /\
  s.PSTATE.EL = 0w /\ s.exception = NoException /\
  aligned 2 s.PC /\ aligned 3 s.SP_EL0 /\
  ~word_bit 31 (w2w (s.REG 0w) : word32) /\
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
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val th = forge_refundNativeReadErrorTheory.ffiread_error_return;
val _ = if aconv statement (concl th) then () else raise Fail "Exact statement mismatch: ffiread_error_return";
val _ = tags "ffiread_error_return" th;
val _ = pr "AFTER_POSITIVE_AUDIT";
val _ = prove (altered,
  rpt strip_tac >> map_every exists_tac (List.take (states, 5)) >> mp_tac chain_imp >>
  impl_tac >- simp [combinTheory.APPLY_UPDATE_THM, alignmentTheory.aligned_add_sub_123,
                    alignmentTheory.aligned_numeric] >>
  simp [combinTheory.APPLY_UPDATE_THM]);
val _ = pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val _ = OS.Process.exit OS.Process.success;

open HolKernel Parse boolLib bossLib arm8Theory arm8_stepTheory forge_refundNativeReadErrorTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
val expected = ``!s.
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
val th = forge_refundNativeReadErrorTheory.ffiread_error_return;
val _ = if aconv expected (concl th) then () else raise Fail "Exact statement mismatch: ffiread_error_return";
val (ors,axs) = Tag.dest_tag (Thm.tag th);
val _ = if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors
  then () else raise Fail "Unexpected theorem dependency";
val _ = pr ("IMPORTED_THEOREM ffiread_error_return\n" ^ thm_to_string th);
val _ = pr ("IMPORTED_ORACLES " ^ String.concatWith "," ors);
val _ = pr "IMPORTED_HYPOTHESES 0\nIMPORTED_TAGGED_AXIOMS 0";
val _ = if length (DB.theorems "forge_refundNativeReadError") = 1 then () else raise Fail "Unexpected theorem count";
val closure = "forge_refundNativeReadError" :: Theory.ancestry "forge_refundNativeReadError";
val _ = List.app (fn n => pr ("CLOSURE_NODE " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n))) closure;
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "NATIVE_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

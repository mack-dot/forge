open HolKernel Parse boolLib bossLib arm8Theory arm8_stepTheory forge_refundInstallSiteTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
val th = forge_refundInstallSiteTheory.install_call_site_step;
val expected = ``!s. ~s.SCTLR_EL1.E0E /\ ~s.TCR_EL1.TBI0 /\ ~s.TCR_EL1.TBI1 /\
      s.MEM s.PC = 107w /\ s.MEM (s.PC + 1w) = 251w /\
      s.MEM (s.PC + 3w) = 23w /\ s.MEM (s.PC + 2w) = 255w /\ s.PSTATE.EL = 0w /\
      s.exception = NoException /\ aligned 2 s.PC ==>
      ?s1. NextStateARM8 s = SOME s1 /\ s1.PC = s.PC - 4692w /\
           s1.MEM = s.MEM /\ s1.REG = s.REG /\ s1.SP_EL0 = s.SP_EL0``;
val _ = if aconv expected (concl th) then () else raise Fail "Exact statement mismatch: install_call_site_step";
val (ors,axs) = Tag.dest_tag (Thm.tag th);
val _ = if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors
  then () else raise Fail "Unexpected theorem dependency";
val _ = if length (DB.theorems "forge_refundInstallSite") = 1 then () else raise Fail "Unexpected theorem count";
val _ = pr ("IMPORTED_THEOREM install_call_site_step\n" ^ thm_to_string th);
val _ = pr "IMPORTED_ORACLES DISK_THM\nIMPORTED_HYPOTHESES 0\nIMPORTED_TAGGED_AXIOMS 0";
val closure = "forge_refundInstallSite" :: Theory.ancestry "forge_refundInstallSite";
val _ = List.app (fn n => pr ("CLOSURE_NODE " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n))) closure;
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "AFTER_POSITIVE_AUDIT";
(* Altered claim: the branch lands on the halt entry (code start - 16), not the installer entry. *)
val wrong = ``!s. ~s.SCTLR_EL1.E0E /\ ~s.TCR_EL1.TBI0 /\ ~s.TCR_EL1.TBI1 /\
      s.MEM s.PC = 107w /\ s.MEM (s.PC + 1w) = 251w /\
      s.MEM (s.PC + 3w) = 23w /\ s.MEM (s.PC + 2w) = 255w /\ s.PSTATE.EL = 0w /\
      s.exception = NoException /\ aligned 2 s.PC ==>
      ?s1. NextStateARM8 s = SOME s1 /\ s1.PC = s.PC - 4676w /\
           s1.MEM = s.MEM /\ s1.REG = s.REG /\ s1.SP_EL0 = s.SP_EL0``;
val _ = if aconv wrong (concl th) then () else raise Fail "Exact statement mismatch: wrong branch target";
val _ = pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val _ = OS.Process.exit OS.Process.success;

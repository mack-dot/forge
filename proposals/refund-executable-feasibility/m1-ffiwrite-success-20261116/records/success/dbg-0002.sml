(* Diagnostic. No theorem is stored. *)
open HolKernel Parse boolLib bossLib arm8Theory arm8_stepTheory wordsTheory wordsLib state_transformerTheory;
fun pr s = print (s ^ "\n");
fun show n th = pr ("SHOW " ^ n ^ "\n" ^ thm_to_string th) ;
val _ = Globals.show_assums := true;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_NATIVE_STEP_OUT"));
val _ = new_theory "forge_dbgScratch";
val d = arm8_stepLib.arm8_decode_hex "78001269";
val _ = show "decode" d;
val r = arm8_stepLib.arm8_run d;
val _ = show "run" r;
val _ = List.app (fn n => (show n (DB.fetch "arm8_step" n) handle e => pr ("NOFETCH " ^ n))) ["mem4", "write'mem2", "CheckAlignment_rwt", "BigEndian_rwt", "X_rwt"];
val ca_ok = prove (``s.PSTATE.EL = 0w /\ ~s.SCTLR_EL1.A /\ acctype <> AccType_ATOMIC /\ acctype <> AccType_ORDERED ==>
    CheckAlignment (address:word64, n, acctype, iswrite) s = s``, rw [CheckAlignment_def, SCTLR_def, TranslationRegime_def] >> fs []) handle e => (pr ("CAOK_FAIL " ^ General.exnMessage e); TRUTH);
val _ = show "ca_ok" ca_ok;
val asms = [``s.PSTATE.EL = 0w``, ``~s.SCTLR_EL1.A``, ``~s.SCTLR_EL1.E0E``, ``(acctype:AccType) <> AccType_ATOMIC``, ``(acctype:AccType) <> AccType_ORDERED``];
val A = map ASSUME asms;
val ca = MP (SPEC_ALL ca_ok |> Q.GENL [`address`, `n`, `iswrite`] |> SPEC_ALL) (LIST_CONJ [el 1 A, el 2 A, el 4 A, el 5 A]) handle e => (pr "CA_FAIL"; TRUTH);
val _ = show "ca" ca;
val t1 = (SIMP_CONV (srw_ss()++boolSimps.LET_ss) ([write'Mem_def, BigEndian_def, FOR_def, BIND_DEF, DB.fetch "arm8_step" "fields", ca_ok] @ A)
            ``write'Mem (d:word16, address, 2, acctype) s``) handle e => (pr ("T1_FAIL " ^ General.exnMessage e); TRUTH);
val _ = show "t1" t1;
val t2 = (SIMP_CONV (srw_ss()++boolSimps.LET_ss) ([Fetch_def, Mem_def, BigEndian_def, FOR_def, BIND_DEF, ca_ok] @ A @
            [ASSUME ``s.MEM s.PC = 105w``, ASSUME ``s.MEM (s.PC + 1w) = 18w``, ASSUME ``s.MEM (s.PC + 2w) = 0w``, ASSUME ``s.MEM (s.PC + 3w) = 120w``])
            ``Fetch (s with branch_hint := NONE)``) handle e => (pr ("T2_FAIL " ^ General.exnMessage e); TRUTH);
val _ = show "t2" t2;
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

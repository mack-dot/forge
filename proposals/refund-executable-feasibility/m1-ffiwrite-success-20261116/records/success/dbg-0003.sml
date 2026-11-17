(* Diagnostic. No theorem is exported. *)
open HolKernel Parse boolLib bossLib arm8Theory arm8_stepTheory wordsTheory wordsLib state_transformerTheory;
fun pr s = print (s ^ "\n");
fun show n th = pr ("SHOW " ^ n ^ "\n" ^ thm_to_string th) ;
val _ = Globals.show_assums := true;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_NATIVE_STEP_OUT"));
val _ = new_theory "forge_dbgScratch";
val st = ``s:arm8_state``;
val cond_rand_thms = utilsLib.mk_cond_rand_thms [pairSyntax.fst_tm];
fun datatype_thms thms = thms @ [cond_rand_thms, GSYM mem_half_def, GSYM mem_word_def, GSYM mem_dword_def] @ utilsLib.datatype_rewrites true "arm8" ["arm8_state"];
val EV0 = utilsLib.STEP (datatype_thms, st);
fun F n = DB.fetch "arm8_step" n;
val ca_ok = prove (``s.PSTATE.EL = 0w /\ ~s.SCTLR_EL1.A /\ acctype <> AccType_ATOMIC /\ acctype <> AccType_ORDERED ==>
    CheckAlignment (address:word64, n, acctype, iswrite) s = s``, rw [CheckAlignment_def, SCTLR_def, TranslationRegime_def] >> fs []);
val ca = UNDISCH_ALL (REWRITE_RULE [GSYM AND_IMP_INTRO] ca_ok);
val _ = show "ca" ca;
val wm2 = (hd (EV0 [write'Mem_def, F "BigEndian_rwt", ca, F "fields", FOR_def, BIND_DEF] [] [] ``write'Mem (d:word16, address, 2, acctype)``))
          handle e => (pr ("WM2_FAIL " ^ General.exnMessage e); TRUTH);
val _ = show "wm2" wm2;
val _ = show "NextStateARM8" (F "NextStateARM8");
val d = arm8_stepLib.arm8_decode_hex "78001269";
val r = arm8_stepLib.arm8_run d;
val tm = rator (rhs (concl (SPEC_ALL r)));
val wm2n = INST [``acctype:AccType`` |-> ``AccType_NORMAL``] wm2;
val wm2n = List.foldl (fn (h, t) => (PROVE_HYP (EQT_ELIM (EVAL h)) t handle _ => t)) wm2n (hyp wm2n);
val _ = show "wm2n" wm2n;
val t4 = ((SIMP_CONV (srw_ss()++boolSimps.LET_ss) [dfn'LoadStoreImmediate_def, LoadStoreSingle_def, F "X_rwt"] THENC
           utilsLib.INST_REWRITE_CONV [wm2n] THENC SIMP_CONV (srw_ss()) []) (mk_comb (tm, ``s with branch_hint := NONE``)))
          handle e => (pr ("T4_FAIL " ^ General.exnMessage e); TRUTH);
val _ = show "t4" t4;
val m4 = INST [``address:word64`` |-> ``(^st).PC``, ``acctype:AccType`` |-> ``AccType_IFETCH``, st |-> ``^st with branch_hint := NONE``] (F "mem4");
val _ = show "m4" m4;
val f1 = (SIMP_CONV (srw_ss()) [Fetch_def, m4] ``Fetch (s with branch_hint := NONE)``) handle e => (pr ("F1_FAIL " ^ General.exnMessage e); TRUTH);
val _ = show "f1" f1;
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

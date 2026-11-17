(* U398 control: with SCTLR_EL1.A set and an unaligned data address, the L3 model raises ALIGNMENT_FAULT at word 78001269
   and NextStateARM8 has no result. Derived from the L3 definitions. No axiom. *)
open HolKernel Parse boolLib bossLib arm8Theory arm8_stepTheory wordsTheory wordsLib combinTheory alignmentTheory state_transformerTheory
     forge_refundFfiwriteUnalignedTheory;
val _ = Globals.max_print_depth := 200;
fun pr s = print (s ^ "\n");
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_NATIVE_STEP_OUT"));
val _ = new_theory "forge_refundFfiwriteFault";
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
val _ = Globals.show_assums := true;
val st = ``s:arm8_state``;
val cond_rand_thms = utilsLib.mk_cond_rand_thms [pairSyntax.fst_tm];
fun datatype_thms thms = thms @ [cond_rand_thms, GSYM mem_half_def, GSYM mem_word_def, GSYM mem_dword_def] @ utilsLib.datatype_rewrites true "arm8" ["arm8_state"];
val EV0 = utilsLib.STEP (datatype_thms, st);
fun SF n = DB.fetch "arm8_step" n;
val ca_fault = DB.fetch "forge_refundFfiwriteUnaligned" "check_alignment_fault";
val caf = UNDISCH_ALL (REWRITE_RULE [GSYM AND_IMP_INTRO] (Q.INST [`iswrite` |-> `T`] ca_fault));
val be = prove (``s.PSTATE.EL = 0w /\ ~s.SCTLR_EL1.E0E ==> (BigEndian (s with exception := ALIGNMENT_FAULT) <=> F)``, simp [BigEndian_def]);
val be = UNDISCH_ALL (REWRITE_RULE [GSYM AND_IMP_INTRO] be);
val wm2f = hd (EV0 [write'Mem_def, be, SF "BigEndian_rwt", caf, SF "fields", FOR_def, BIND_DEF] [] [] ``write'Mem (d:word16, address, 2, acctype)``);
val _ = pr ("WM2F " ^ thm_to_string wm2f);
val nxf = prove (``s.exception = NoException /\ Fetch (s with branch_hint := NONE) = (w, s with branch_hint := NONE) /\ Decode w = ast /\
     (!s. Run ast s = f x s) /\ f x (s with branch_hint := NONE) = s1 /\ s1.exception <> NoException ==> NextStateARM8 s = NONE``,
  lrw [NextStateARM8_def, Next_def] >> fs [] >> rw [] >> fs []);
val _ = pr ("NXF " ^ thm_to_string nxf);
val word = "78001269";
val gconv = DEPTH_CONV bitstringLib.v2w_n2w_CONV THENC DEPTH_CONV (fn t => if wordsSyntax.is_sw2sw t then EVAL t else NO_CONV t);
val dec = CONV_RULE gconv (arm8_stepLib.arm8_decode_hex word);
val run = CONV_RULE gconv (arm8_stepLib.arm8_run (arm8_stepLib.arm8_decode_hex word));
val sb = ``^st with branch_hint := NONE``;
val hyp_simp = utilsLib.ALL_HYP_CONV_RULE (SIMP_CONV (srw_ss()) []);
val dfn_tm = mk_comb (rator (rhs (concl (SPEC_ALL run))), sb);
val t4 = hyp_simp ((SIMP_CONV (srw_ss()++boolSimps.LET_ss) [dfn'LoadStoreImmediate_def, LoadStoreSingle_def, SF "X_rwt"] THENC
           utilsLib.INST_REWRITE_CONV [wm2f] THENC SIMP_CONV (srw_ss()) []) dfn_tm);
val _ = pr ("T4F " ^ thm_to_string t4);
val m4 = INST [``address:word64`` |-> ``(^st).PC``, ``acctype:AccType`` |-> ``AccType_IFETCH``, st |-> sb] (SF "mem4");
val f1 = hyp_simp (SIMP_CONV (srw_ss()) [Fetch_def, m4] ``Fetch ^sb``);
val bytes = [``(^st).MEM s.PC = 105w``, ``(^st).MEM (s.PC + 1w) = 18w``, ``(^st).MEM (s.PC + 2w) = 0w``, ``(^st).MEM (s.PC + 3w) = 120w``];
val mw = (REWR_CONV mem_word_def THENC REWRITE_CONV (map ASSUME bytes) THENC EVAL) ``mem_word (^st).MEM s.PC``;
val f2 = CONV_RULE (RAND_CONV (LAND_CONV (K mw))) f1;
val exc = EQT_ELIM (SIMP_CONV (srw_ss()) [] ``(^(rhs (concl t4))).exception <> NoException``);
val xtup = rand (rator (rhs (concl (SPEC_ALL run))));
val nx1 = INST_TYPE [alpha |-> type_of xtup] nxf;
val fv = valOf (List.find (fn v => fst (dest_var v) = "f") (free_vars (concl nx1)));
val xv = valOf (List.find (fn v => fst (dest_var v) = "x") (free_vars (concl nx1)));
val nx2 = INST [``w:word32`` |-> ``0x78001269w:word32``, ``ast:instruction`` |-> rhs (concl dec), fv |-> rator (rator (rhs (concl (SPEC_ALL run)))),
                xv |-> xtup, ``s1:arm8_state`` |-> rhs (concl t4)] nx1;
val conj = LIST_CONJ [ASSUME ``(^st).exception = NoException``, f2, dec, run, t4, exc];
val res = MP nx2 (EQ_MP (ALPHA (concl conj) (fst (dest_imp (concl nx2)))) conj);
val _ = pr ("FAULT_HYPS " ^ String.concatWith " ; " (map term_to_string (hyp res)));
val _ = if List.exists (aconv ``(^st).SCTLR_EL1.A``) (hyp res) andalso
           List.exists (fn h => is_neg h andalso can (find_term (fn t => (fst (dest_const t) = "aligned") handle _ => false)) h) (hyp res)
        then () else raise Fail "fault hypotheses missing";
val fault = save_thm ("sturh_w9_x19_1_alignment_fault", DISCH_ALL res |> REWRITE_RULE [AND_IMP_INTRO] |> PURE_REWRITE_RULE [GSYM CONJ_ASSOC]);
val _ = Globals.show_assums := false;
val _ = chk "sturh_w9_x19_1_alignment_fault" fault;
val _ = pr "CONTROL_OK with SCTLR_EL1.A set and an unaligned address the store step has no next state";
val _ = export_theory ();
val _ = pr "NATIVE_STEP_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

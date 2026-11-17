(* U398: the halfword store at a + 1 in ffiwrite (word 78001269, sturh w9, [x19, #1]) WITHOUT an alignment hypothesis.
   Derived from the L3 definitions (CheckAlignment_def, write'Mem_def, dfn'LoadStoreImmediate_def, LoadStoreSingle_def) with the
   library's own evaluator. New explicit premise in place of alignment: ~s.SCTLR_EL1.A. No axiom. The L3 model has no
   Normal/Device memory distinction; nothing is claimed about Device memory. Then: the success suffix of ffiwrite (10 steps). *)
open HolKernel Parse boolLib bossLib arm8Theory arm8_stepTheory wordsTheory wordsLib combinTheory alignmentTheory state_transformerTheory
     forge_refundCmlMainStepTheory forge_refundFficloseStepTheory forge_refundFfiwriteStepTheory;
val _ = Globals.max_print_depth := 200;
fun pr s = print (s ^ "\n");
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_NATIVE_STEP_OUT"));
val _ = new_theory "forge_refundFfiwriteUnaligned";
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
val run_def = DB.fetch "forge_refundCmlMainStep" "arm8_run_def";
val run_snoc = prove (``!n s s1 s2. arm8_run n s = SOME s1 /\ NextStateARM8 s1 = SOME s2 ==> arm8_run (SUC n) s = SOME s2``,
  Induct >- simp [run_def] >>
  rpt gen_tac >> ONCE_REWRITE_TAC [run_def] >> Cases_on `NextStateARM8 s` >> simp [] >> metis_tac []);
fun w64 n = wordsSyntax.mk_wordii (n, 64);
fun w8 n = wordsSyntax.mk_wordii (n, 8);
fun hexbyte str i = valOf (StringCvt.scanString (Int.scan StringCvt.HEX) (String.substring (str, i, 2)));
fun QC c tm = c tm handle UNCHANGED => REFL tm;
val s = ``s:arm8_state``; val m = ``m:word64 -> word8``;
val user_def = DB.fetch "forge_refundFficloseStep" "arm8_user_def";
val extra_defs = ref ([] : thm list); val extra_facts = ref ([] : thm list);
val extra_steps = ref ([] : (string * thm list) list);
val fallback = ref (fn (t:term) => (raise mk_HOL_ERR "forge" "fallback" "none") : thm);
val stub_words = [(0x100004090, "14008454")];
val body = ["a9be4ff4","a9017bfd","910043fd","f100203f","54000341","aa0203f3","79400048","5ac00502","79400668","5ac00508","0b080049","11001129",
            "eb03013f","5400024c","b9400409","5ac00920","8b284268","91001101","940001e7","37f800c0","52800008","5ac00809","53107d29","78001269",
            "14000002","52800028","39000268","a9417bfd","a8c24ff4","d65f03c0"];
val body_words = ListPair.zip (List.tabulate (30, fn i => 0x1000251E0 + 4 * i), body);
val imp_words = [(0x1000259C4, "f0000010"), (0x1000259C8, "f9405a10"), (0x1000259CC, "d61f0200")];
val code_eqs = List.concat (map (fn (a, w) => List.tabulate (4, fn k => ``^m ^(w64 (a + k)) = ^(w8 (hexbyte w (6 - 2 * k)))``))
                                (stub_words @ body_words @ imp_words));
val code_def = DB.fetch "forge_refundFfiwriteStep" "ffiwrite_code_bytes_def";
(* ---- engine ---- *)
fun base_off tm =
  if null (free_vars tm) then (NONE, wordsSyntax.uint_of_word (rhs (concl (EVAL tm)) handle UNCHANGED => tm))
  else if is_var tm then (SOME tm, 0)
  else let val (x, y) = wordsSyntax.dest_word_add tm in
         if is_var x andalso null (free_vars y) then (SOME x, wordsSyntax.uint_of_word y) else raise mk_HOL_ERR "forge" "base_off" "form" end;
fun engine (pre_tm, pre_def, lit_seps, pair_seps, aligned_vars, rules) =
  let
    val all = CONJUNCTS (REWRITE_RULE (pre_def :: !extra_defs @ [user_def, code_def]) (ASSUME pre_tm))
    val plain = List.filter (fn th => not (is_forall (concl th))) all
    fun find_sep tm = valOf (List.find (fn th => aconv (concl th) tm) all)
    val lit = map (fn (v, tm) => (v, find_sep tm)) lit_seps
    val pair = map (fn ((x, y), tm) => ((x, y), find_sep tm)) pair_seps
    fun al_of v = let val base = valOf (List.find (fn th => aconv (concl th) ``aligned 3 ^v``) all)
                      val more = map (fn c => MP (prove (``aligned 3 ^v ==> aligned 3 (^v + ^(w64 c))``,
                                     simp [aligned_bitwise_and] >> blastLib.BBLAST_TAC)) base) [8, 16, 24, 32]
                      val alls = base :: more
                  in alls @ List.mapPartial (fn th => SOME (SIMP_RULE (srw_ss()) [] th) handle _ => NONE) alls end
    val derived = map (fn r => MP r (valOf (List.find (fn th => aconv (concl th) (fst (dest_imp (concl r)))) all))) rules
    val facts = plain @ derived @ !extra_facts @ List.concat (map al_of aligned_vars)
    fun num k = numSyntax.term_of_int k
    fun var_lit x k l = (* |- x + k <> l *)
      let val th = (case List.find (fn (v, _) => aconv v x) lit of SOME (_, t) => t
                         | NONE => raise mk_HOL_ERR "forge" "decide" ("no literal separation for " ^ term_to_string x))
          val th1 = SPECL [num k, l] th |> CONV_RULE (LAND_CONV EVAL) |> (fn t => MP t TRUTH) |> REWRITE_RULE [WORD_ADD_0] in th1 end
    fun var_var x i y j =
      case List.find (fn ((p, q), _) => aconv p x andalso aconv q y) pair of
        SOME (_, th) => SPECL [num i, num j] th |> CONV_RULE (LAND_CONV EVAL) |> (fn t => MP t TRUTH) |> REWRITE_RULE [WORD_ADD_0]
      | NONE => (case List.find (fn ((p, q), _) => aconv p y andalso aconv q x) pair of
                   SOME (_, th) => GSYM (SPECL [num j, num i] th |> CONV_RULE (LAND_CONV EVAL) |> (fn t => MP t TRUTH) |> REWRITE_RULE [WORD_ADD_0])
                 | NONE => raise mk_HOL_ERR "forge" "decide" ("no separation for " ^ term_to_string x ^ " / " ^ term_to_string y))
    fun decide eq =
      (let val (l, r) = dest_eq eq
           val (bl, ol) = base_off l val (br, or') = base_off r
       in case (bl, br) of
            (NONE, NONE) => EVAL eq
          | (SOME x, SOME y) => if aconv x y then
                (let val th = SIMP_CONV (srw_ss()) [] eq in if aconv (rhs (concl th)) T orelse aconv (rhs (concl th)) F then th
                    else blastLib.BBLAST_CONV eq end)
              else EQF_INTRO (var_var x ol y or')
          | (SOME x, NONE) => EQF_INTRO (var_lit x ol (rhs (concl (EVAL r)) handle UNCHANGED => r))
          | (NONE, SOME y) => EQF_INTRO (GSYM (var_lit y or' (rhs (concl (EVAL l)) handle UNCHANGED => l)))
       end) handle ex => (pr ("DECIDE_FAILED " ^ term_to_string eq); raise ex)
    fun lookup tm = let val (c, args) = strip_comb tm in
       if is_const c andalso fst (dest_const c) = "UPDATE" andalso length args = 4 then
         let val x = List.nth (args, 3)
             val xth = if null (free_vars x) then (EVAL x handle UNCHANGED => REFL x) else REFL x
             val th0 = AP_TERM (rator tm) xth
             val tm1 = rhs (concl th0)
             val (_, [a, v, f, x1]) = strip_comb tm1
             val eqth = decide (mk_eq (a, x1))
             val eqth = if aconv (lhs (concl eqth)) (mk_eq (a, x1)) then eqth else TRANS (ALPHA (mk_eq (a, x1)) (lhs (concl eqth))) eqth
             val th1 = (REWR_CONV APPLY_UPDATE_THM THENC RATOR_CONV (RATOR_CONV (RAND_CONV (K eqth))) THENC PURE_ONCE_REWRITE_CONV [COND_CLAUSES]) tm1
             val th2 = TRANS th0 th1
         in TRANS th2 (lookup (rhs (concl th2))) handle UNCHANGED => th2 | HOL_ERR _ => th2 end
       else raise mk_HOL_ERR "forge" "lookup" "not an update lookup" end
    val simp_conv = SIMP_CONV (srw_ss()) facts
    fun norm tm = (QC simp_conv THENC QC (ONCE_DEPTH_CONV lookup) THENC QC simp_conv) tm
    val base_mem = ``(^s).MEM``
    fun frame_loads tm =
      let fun is_load t = (let val (c, args) = strip_comb t in is_const c andalso Lib.mem (fst (dest_const c)) ["mem_dword", "mem_word", "mem_half"] andalso
                                 length args = 2 andalso not (aconv (hd args) base_mem) end) handle _ => false
          val ts = find_terms is_load tm
          fun one t = let val (c, [mm, a]) = strip_comb t
                          val d = (case fst (dest_const c) of "mem_dword" => mem_dword_def | "mem_word" => mem_word_def | _ => mem_half_def)
                          val l = (REWR_CONV d THENC QC (SIMP_CONV (srw_ss()) []) THENC QC (ONCE_DEPTH_CONV lookup)) t
                          val r = (REWR_CONV d THENC QC (SIMP_CONV (srw_ss()) [])) (mk_comb (mk_comb (c, base_mem), a))
                      in SOME (TRANS l (SYM r)) handle HOL_ERR _ => NONE end
      in QC (PURE_REWRITE_CONV (List.mapPartial one ts)) tm end
    fun step (w, (k, st, chain)) =
      let val ths = arm8_stepLib.arm8_step_hex w @ List.concat (map #2 (List.filter (fn (x, _) => x = w) (!extra_steps)))
          fun inst_some th = (* step theorems for bit-field moves have a hypothesis SOME (c1, c2) = SOME (v1, v2) with free v1, v2 *)
            case List.find (fn h => (is_eq h andalso optionSyntax.is_some (lhs h) andalso optionSyntax.is_some (rhs h) andalso
                                     not (null (free_vars (rhs h))) andalso null (free_vars (lhs h))) handle _ => false) (hyp th) of
              SOME h => INST (fst (match_term (optionSyntax.dest_some (rhs h)) (optionSyntax.dest_some (lhs h)))) th
            | NONE => th
          fun try th = let val th1 = INST [s |-> st] (inst_some th)
                           fun dis hy = let val r = (norm THENC QC EVAL) hy in
                                 if aconv (rhs (concl r)) T then EQT_ELIM r
                                 else (EQ_MP (SYM r) ((!fallback) (rhs (concl r))) handle HOL_ERR _ => raise Fail "x") handle Fail _ => raise mk_HOL_ERR "forge" "step" ("hypothesis: " ^ term_to_string hy ^ " ==> " ^ term_to_string (rhs (concl r))) end
                       in List.foldl (fn (hy, t) => PROVE_HYP (dis hy) t) th1 (hyp th1) end
          fun first [] = raise Fail ("no step theorem applies at step " ^ Int.toString (k + 1) ^ " word " ^ w)
            | first (th :: rest) = (try th handle (e as HOL_ERR _) => (pr ("STEP_ALTERNATIVE_REJECTED " ^ w ^ " " ^ String.substring (General.exnMessage e, 0, Int.min (300, size (General.exnMessage e)))); first rest))
          val th2 = first ths
          val th3 = CONV_RULE (RAND_CONV (RAND_CONV (norm THENC frame_loads THENC norm))) th2
          val st' = rand (rhs (concl th3))
          val chain' = MATCH_MP run_snoc (CONJ chain th3)
          val _ = pr ("STEP_OK " ^ Int.toString (k + 1) ^ " " ^ w ^ " PC " ^ term_to_string (rhs (concl (QC simp_conv ``(^st').PC``))))
      in (k + 1, st', chain') end
    fun run words = let val chain0 = SPEC s (CONJUNCT1 run_def)
                        val (n, st, chain) = List.foldl step (0, s, chain0) words
                    in (st, CONV_RULE (LAND_CONV (RATOR_CONV (RAND_CONV numLib.REDUCE_CONV))) chain) end
    fun fact tm = (norm THENC frame_loads THENC norm THENC QC EVAL) tm
  in {run = run, fact = fact, lookup = lookup, facts = facts, simp_conv = simp_conv} end;
val s1 = ``s1:arm8_state``;
fun close_thm name pre_tm st conj =
  let val ex_tm = mk_exists (s1, subst [st |-> s1] (concl conj))
      val ex = EXISTS (ex_tm, st) conj
      val _ = if List.all (aconv pre_tm) (hyp ex) then () else (List.app (fn t => pr ("HYP " ^ term_to_string t)) (hyp ex); raise Fail "unexpected hypotheses")
      val th = save_thm (name, DISCH pre_tm ex)
  in chk name th; th end;
fun unchanged st fld = let val l = QC (SIMP_CONV (srw_ss()) []) (mk_comb (fld, st)) val want = mk_comb (fld, s) in
   if aconv (rhs (concl l)) want then l else raise Fail ("field changed: " ^ term_to_string fld) end;
(* generalise state atoms, then bit-blast *)
fun atoms tm = let fun is_atom t = (let val (c, args) = strip_comb t in is_const c andalso length args = 2 andalso
        (Lib.mem (fst (dest_const c)) ["mem_dword", "mem_word", "mem_half"] orelse
         same_const c ``arm8_state_MEM`` orelse same_const c ``arm8_state_REG``) end) handle _ => false
   in Lib.op_mk_set aconv (find_terms is_atom tm) end;
fun blast_gen goal = let val ats = Lib.sort (fn x => fn y => term_size x >= term_size y) (atoms goal)
     val (g', _) = List.foldl (fn (t, (g, k)) => (subst [t |-> mk_var ("atom" ^ Int.toString k, type_of t)] g, k + 1)) (goal, 0) ats
     val th = prove (g', blastLib.BBLAST_TAC)
     val (_, k') = List.foldl (fn (t, (u, k)) => ((), k + 1)) ((), 0) ats
  in INST (#1 (List.foldl (fn (t, (l, k)) => ((mk_var ("atom" ^ Int.toString k, type_of t) |-> t) :: l, k + 1)) ([], 0) ats)) th end;
val s1 = ``s1:arm8_state``;
val b = ``b:word64``; val c = ``c:word64``; val a = ``a:word64``; val g = ``g:word64``;
val s1 = ``s1:arm8_state``;
val b = ``b:word64``; val c = ``c:word64``; val a = ``a:word64``; val g = ``g:word64``;
fun showfact f tm = let val th = f tm in pr ("POST " ^ term_to_string (lhs (concl th)) ^ " = " ^ term_to_string (rhs (concl th))); th end;
fun frame_thm st n base =
  let val q = ``q:word64`` val hy = ``!i. i < ^(numSyntax.term_of_int n) ==> ^q <> ^base + n2w i``
      val _ = if Lib.exists (aconv q) (free_vars st) then raise Fail "frame variable is not fresh" else ()
      val ne = List.tabulate (n, fn k => SPEC (numSyntax.term_of_int k) (ASSUME hy) |> CONV_RULE (LAND_CONV EVAL) |> (fn th => MP th TRUTH) |> REWRITE_RULE [WORD_ADD_0])
      val _ = List.app (fn th => if aconv (concl th) F then raise Fail "contradictory frame hypothesis" else ()) ne
      val th = SIMP_CONV (srw_ss()) (APPLY_UPDATE_THM :: ne @ map GSYM ne) ``(^st).MEM ^q``
      val _ = if aconv (rhs (concl th)) ``(^s).MEM ^q`` then () else raise Fail ("frame not reduced: " ^ term_to_string (rhs (concl th)))
  in GEN q (DISCH hy th) end;
fun regs_thm st changed =
  let val r = ``r:word5`` val hy = list_mk_conj (map (fn k => ``^r <> ^(wordsSyntax.mk_wordii (k, 5))``) changed)
      val ne = CONJUNCTS (ASSUME hy)
      val th = SIMP_CONV (srw_ss()) (APPLY_UPDATE_THM :: ne @ map GSYM ne) ``(^st).REG ^r``
      val _ = if aconv (rhs (concl th)) ``(^s).REG ^r`` then () else raise Fail ("registers not reduced: " ^ term_to_string (rhs (concl th)))
  in GEN r (DISCH hy th) end;

(* ================= A. The model: alignment check and the 2-byte write. ================= *)
val st = s;
val cond_rand_thms = utilsLib.mk_cond_rand_thms [pairSyntax.fst_tm];
fun datatype_thms thms = thms @ [cond_rand_thms, GSYM mem_half_def, GSYM mem_word_def, GSYM mem_dword_def] @ utilsLib.datatype_rewrites true "arm8" ["arm8_state"];
val EV0 = utilsLib.STEP (datatype_thms, st);
fun SF n = DB.fetch "arm8_step" n;
val ca_ok = store_thm ("check_alignment_no_fault",
  ``s.PSTATE.EL = 0w /\ ~s.SCTLR_EL1.A /\ acctype <> AccType_ATOMIC /\ acctype <> AccType_ORDERED ==>
    CheckAlignment (address:word64, n, acctype, iswrite) s = s``, rw [CheckAlignment_def, SCTLR_def, TranslationRegime_def] >> fs []);
val _ = chk "check_alignment_no_fault" ca_ok;
val ca_fault = store_thm ("check_alignment_fault",
  ``s.PSTATE.EL = 0w /\ s.SCTLR_EL1.A /\ ~aligned 1 (address:word64) /\ s.exception = NoException ==>
    CheckAlignment (address, 2, acctype, iswrite) s = s with exception := ALIGNMENT_FAULT``,
  rw [CheckAlignment_def, SCTLR_def, TranslationRegime_def, raise'exception_def, SF "Aligned"] >> fs []);
val _ = chk "check_alignment_fault" ca_fault;
val ca = UNDISCH_ALL (REWRITE_RULE [GSYM AND_IMP_INTRO] ca_ok);
val wm2 = hd (EV0 [write'Mem_def, SF "BigEndian_rwt", ca, SF "fields", FOR_def, BIND_DEF] [] [] ``write'Mem (d:word16, address, 2, acctype)``);
val _ = pr ("WM2_HYPS " ^ String.concatWith " ; " (map term_to_string (hyp wm2)));
val _ = if List.exists (fn h => can (find_term (fn t => (fst (dest_const t) = "aligned" orelse fst (dest_const t) = "Aligned") handle _ => false)) h) (hyp wm2)
        then raise Fail "alignment hypothesis present" else ();
val wm2_thm = save_thm ("write_mem2_no_alignment", REWRITE_RULE [AND_IMP_INTRO] (DISCH_ALL wm2));
val _ = chk "write_mem2_no_alignment" wm2_thm;
(* ================= B. The step for word 78001269. ================= *)
val word = "78001269";
val dec0 = arm8_stepLib.arm8_decode_hex word;
val run0 = arm8_stepLib.arm8_run dec0;
val _ = pr ("DECODE " ^ thm_to_string dec0);
val args0 = rand (rator (rhs (concl (SPEC_ALL run0))));
val args_eq = EVAL args0;
val _ = pr ("ARGS " ^ term_to_string (rhs (concl args_eq)));
val opc_eq = bitstringLib.v2w_n2w_CONV (rand (lhs (concl dec0)));
val _ = pr ("OPC " ^ thm_to_string opc_eq);
val _ = if aconv (rhs (concl opc_eq)) ``0x78001269w:word32`` then () else raise Fail "opcode";
val gconv = DEPTH_CONV bitstringLib.v2w_n2w_CONV THENC DEPTH_CONV (fn t => if wordsSyntax.is_sw2sw t then EVAL t else NO_CONV t);
val dec = CONV_RULE gconv dec0;
val run = CONV_RULE gconv run0;
val _ = pr ("DECODE_N " ^ thm_to_string dec); val _ = pr ("RUN_N " ^ thm_to_string run);
val sb = ``^st with branch_hint := NONE``;
val hyp_simp = utilsLib.ALL_HYP_CONV_RULE (SIMP_CONV (srw_ss()) []);
val wm2n = INST [``acctype:AccType`` |-> ``AccType_NORMAL``] wm2;
val wm2n = List.foldl (fn (h, t) => if null (free_vars h) then PROVE_HYP (EQT_ELIM (EVAL h)) t else t) wm2n (hyp wm2n);
val dfn_tm = mk_comb (rator (rhs (concl (SPEC_ALL run))), sb);
val t4 = hyp_simp ((SIMP_CONV (srw_ss()++boolSimps.LET_ss) [dfn'LoadStoreImmediate_def, LoadStoreSingle_def, SF "X_rwt"] THENC
           utilsLib.INST_REWRITE_CONV [wm2n] THENC SIMP_CONV (srw_ss()) []) dfn_tm);
val _ = pr ("T4 " ^ thm_to_string t4);
val m4 = INST [``address:word64`` |-> ``(^st).PC``, ``acctype:AccType`` |-> ``AccType_IFETCH``, st |-> sb] (SF "mem4");
val f1 = hyp_simp (SIMP_CONV (srw_ss()) [Fetch_def, m4] ``Fetch ^sb``);
val bytes = [``(^st).MEM s.PC = 105w``, ``(^st).MEM (s.PC + 1w) = 18w``, ``(^st).MEM (s.PC + 2w) = 0w``, ``(^st).MEM (s.PC + 3w) = 120w``];
val mw = (REWR_CONV mem_word_def THENC REWRITE_CONV (map ASSUME bytes) THENC EVAL) ``mem_word (^st).MEM s.PC``;
val _ = if aconv (rhs (concl mw)) ``0x78001269w:word32`` then () else raise Fail ("fetched word: " ^ thm_to_string mw);
val f2 = CONV_RULE (RAND_CONV (LAND_CONV (K mw))) f1;
val exc = SIMP_CONV (srw_ss()) [] ``(^(rhs (concl t4))).exception``;
val nx = UNDISCH (SF "NextStateARM8" |> DISCH_ALL) handle _ => SF "NextStateARM8";
val _ = pr ("NX " ^ thm_to_string nx);
val conj = LIST_CONJ [f2, dec, run, t4, exc];
val _ = pr ("CONJ " ^ thm_to_string conj);
val xtup = rand (rator (rhs (concl (SPEC_ALL run))));
val nx1 = INST_TYPE [alpha |-> type_of xtup] nx;
val fv = valOf (List.find (fn v => fst (dest_var v) = "f") (free_vars (concl nx1)));
val xv = valOf (List.find (fn v => fst (dest_var v) = "x") (free_vars (concl nx1)));
val nx2 = INST [``w:word32`` |-> ``0x78001269w:word32``, ``ast:instruction`` |-> rhs (concl dec), fv |-> rator (rator (rhs (concl (SPEC_ALL run)))),
                xv |-> xtup, ``s1:arm8_state`` |-> rhs (concl t4)] nx1;
val step0 = MP nx2 (EQ_MP (ALPHA (concl conj) (fst (dest_imp (concl nx2)))) conj);
val step1 = CONV_RULE (RAND_CONV (SIMP_CONV (srw_ss()) [])) step0;
val _ = pr ("STEP_HYPS " ^ String.concatWith " ; " (map term_to_string (hyp step1)));
val _ = if List.exists (fn h => can (find_term (fn t => aconv t ``(^st).REG 19w``)) h) (hyp step1) then raise Fail "hypothesis on the data address" else ();
val hyps = [``(^st).exception = NoException``, ``(^st).PSTATE.EL = 0w``, ``~(^st).SCTLR_EL1.E0E``, ``~(^st).SCTLR_EL1.A``, ``aligned 2 (^st).PC``] @ bytes;
val _ = if List.all (fn h => List.exists (aconv h) hyps) (hyp step1) then () else raise Fail "unexpected step hypotheses";
val step_thm = save_thm ("sturh_w9_x19_1_step_no_alignment", List.foldr (fn (h, t) => DISCH h t) step1 hyps |> REWRITE_RULE [AND_IMP_INTRO] |> PURE_REWRITE_RULE [GSYM CONJ_ASSOC]);
val _ = chk "sturh_w9_x19_1_step_no_alignment" step_thm;
val step_hyp = List.foldl (fn (h, t) => UNDISCH t) (List.foldr (fn (h, t) => DISCH h t) step1 hyps) hyps;
val _ = extra_steps := [(word, [step_hyp])];

(* ================= C. The success suffix of ffiwrite: 10 steps, no alignment premise on a + 1. ================= *)
val [v20, v19, v29, v30] = map (fn n => mk_var (n, ``:word64``)) ["v20", "v19", "v29", "v30"];
val sepA1 = ``!i (x:word64). i < 3 /\ 0x100000000w <=+ x /\ x <+ 0x100030F30w ==> ^a + n2w i <> x``;
val sepA2 = ``!i j. i < 3 /\ j < 32 ==> ^a + n2w i <> ^b + n2w j``;
val ret_common = ``arm8_user s /\ s.PC = 0x10002522Cw /\ ffiwrite_code_bytes s.MEM /\ s.SP_EL0 = ^b /\ aligned 3 ^b /\ s.REG 19w = ^a /\
      mem_dword s.MEM b = ^v20 /\ mem_dword s.MEM (b + 8w) = ^v19 /\ mem_dword s.MEM (b + 16w) = ^v29 /\ mem_dword s.MEM (b + 24w) = ^v30 /\
      ^sepA1 /\ ^sepA2``;
val preN_def = new_definition ("ffiwrite_return_ok_na_pre_def",
  ``ffiwrite_return_ok_na_pre ^s ^b ^a ^v20 ^v19 ^v29 ^v30 <=> ^ret_common /\ ~word_bit 31 (w2w (s.REG 0w) : word32) /\ ~s.SCTLR_EL1.A``);
val _ = pr ("DEFINITION " ^ thm_to_string preN_def);
val preN = lhs (snd (strip_forall (concl preN_def)));
val EN = engine (preN, preN_def, [(a, sepA1)], [((a, b), sepA2)], [b], []);
val (stN, chainN) = #run EN (List.take (List.drop (body, 19), 6) @ List.drop (body, 26));
val pN = map (showfact (#fact EN)) [``(^stN).PC``, ``(^stN).REG 30w``, ``(^stN).REG 29w``, ``(^stN).REG 19w``, ``(^stN).REG 20w``, ``(^stN).SP_EL0``,
                                   ``(^stN).MEM ^a``, ``(^stN).PSTATE.EL``];
val _ = ListPair.app (fn (th, x) => if aconv (rhs (concl th)) x then () else raise Fail ("unexpected post value: " ^ thm_to_string th))
          (List.take (pN, 7), [v30, v30, v29, v19, v20, ``^b + 32w``, ``0w:word8``]);
val neqs = map (fn t => EQF_INTRO (blastLib.BBLAST_PROVE (mk_neg t)))
             [``^a = ^a + 1w``, ``^a + 2w = ^a + 1w``, ``^a = ^a + 2w``, ``^a + 1w = ^a + 2w``, ``^a + 1w = ^a``, ``^a + 2w = ^a``];
fun nice ad want = let val th = CONV_RULE (RAND_CONV (QC (REWRITE_CONV neqs))) (#fact EN ``(^stN).MEM ^ad``)
                       val e = if aconv (rhs (concl th)) want then REFL want else blast_gen (mk_eq (rhs (concl th), want))
                   in TRANS th e end;
val hi = nice ``^a + 1w`` ``(15 >< 8) ((^s).REG 0w) : word8``;
val lo = nice ``^a + 2w`` ``(7 >< 0) ((^s).REG 0w) : word8``;
val _ = pr ("RESULT_BYTES " ^ thm_to_string hi ^ " ;; " ^ thm_to_string lo);
val sameN = map (unchanged stN) [``arm8_state_SCTLR_EL1``, ``arm8_state_TCR_EL1``, ``arm8_state_exception``];
val ok_thm = close_thm "ffiwrite_suffix_ok_unaligned_run" preN stN
   (LIST_CONJ (chainN :: pN @ [hi, lo] @ sameN @ [frame_thm stN 3 a, regs_thm stN [8, 9, 19, 20, 29, 30]]));
(* controls *)
val _ = let val r = (#run EN [List.nth (body, 19), List.nth (body, 20), List.nth (body, 21), List.nth (body, 22), "78001268"]; "ACCEPTED") handle _ => "REJECTED" in
   if r = "REJECTED" then pr "CONTROL_OK changed store word (78001269 -> 78001268) rejected by the fetch hypotheses" else raise Fail "UNEXPECTED_CONTROL_ACCEPTANCE" end;
val _ = extra_steps := [];
val _ = let val r = (#run EN (List.take (List.drop (body, 19), 5)); "ACCEPTED") handle _ => "REJECTED" in
   if r = "REJECTED" then pr "CONTROL_OK without the new step theorem the library rejects the store (alignment hypothesis)" else raise Fail "UNEXPECTED_CONTROL_ACCEPTANCE" end;
val _ = export_theory ();
val _ = pr "NATIVE_STEP_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

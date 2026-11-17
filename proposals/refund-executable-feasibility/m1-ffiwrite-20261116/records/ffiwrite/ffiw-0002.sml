(* U397: exact ARMv8 (L3) execution of the entry stub cake_ffiwrite at 0x100004090, of the C function ffiwrite up to the indirect
   branch that leaves the image (import stub for write), and of ffiwrite after the call returns (two outcomes).
   Link addresses, slide 0. The call into libSystem is NOT modelled. The step library gives theorems for aligned accesses only. *)
open HolKernel Parse boolLib bossLib arm8Theory arm8_stepTheory wordsTheory wordsLib combinTheory alignmentTheory forge_refundCmlMainStepTheory
     forge_refundFficloseStepTheory;
val _ = Globals.max_print_depth := 200;
fun pr s = print (s ^ "\n");
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_NATIVE_STEP_OUT"));
val _ = new_theory "forge_refundFfiwriteStep";
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
val fallback = ref (fn (t:term) => (raise mk_HOL_ERR "forge" "fallback" "none") : thm);
val stub_words = [(0x100004090, "14008454")];
val body = ["a9be4ff4","a9017bfd","910043fd","f100203f","54000341","aa0203f3","79400048","5ac00502","79400668","5ac00508","0b080049","11001129",
            "eb03013f","5400024c","b9400409","5ac00920","8b284268","91001101","940001e7","37f800c0","52800008","5ac00809","53107d29","78001269",
            "14000002","52800028","39000268","a9417bfd","a8c24ff4","d65f03c0"];
val body_words = ListPair.zip (List.tabulate (30, fn i => 0x1000251E0 + 4 * i), body);
val imp_words = [(0x1000259C4, "f0000010"), (0x1000259C8, "f9405a10"), (0x1000259CC, "d61f0200")];
val code_eqs = List.concat (map (fn (a, w) => List.tabulate (4, fn k => ``^m ^(w64 (a + k)) = ^(w8 (hexbyte w (6 - 2 * k)))``))
                                (stub_words @ body_words @ imp_words));
val code_def = new_definition ("ffiwrite_code_bytes_def", ``ffiwrite_code_bytes ^m = ^(list_mk_conj code_eqs)``);
val _ = pr ("CODE_BYTES " ^ Int.toString (length code_eqs));
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
      let val ths = arm8_stepLib.arm8_step_hex w
          fun try th = let val th1 = INST [s |-> st] th
                           fun dis hy = let val r = (norm THENC QC EVAL) hy in
                                 if aconv (rhs (concl r)) T then EQT_ELIM r
                                 else (pr ("RESIDUAL " ^ term_to_string (rhs (concl r))); EQ_MP (SYM r) ((!fallback) (rhs (concl r))) handle HOL_ERR _ => raise Fail "x") handle Fail _ => raise mk_HOL_ERR "forge" "step" ("hypothesis: " ^ term_to_string hy ^ " ==> " ^ term_to_string (rhs (concl r))) end
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
fun atoms tm = let fun is_atom t = (let val (c, args) = strip_comb t in is_const c andalso
        ((Lib.mem (fst (dest_const c)) ["mem_dword", "mem_word", "mem_half"] andalso length args = 2) orelse
         (fst (dest_const c) = "arm8_state_MEM" andalso length args = 2) orelse (fst (dest_const c) = "arm8_state_REG" andalso length args = 2)) end) handle _ => false
   in Lib.op_mk_set aconv (find_terms is_atom tm) end;
fun blast_gen goal = let val ats = Lib.sort (fn x => fn y => term_size x >= term_size y) (atoms goal)
     val (g', _) = List.foldl (fn (t, (g, k)) => (subst [t |-> mk_var ("atom" ^ Int.toString k, type_of t)] g, k + 1)) (goal, 0) ats
     val th = prove (g', blastLib.BBLAST_TAC)
     val (_, k') = List.foldl (fn (t, (u, k)) => ((), k + 1)) ((), 0) ats
  in INST (#1 (List.foldl (fn (t, (l, k)) => ((mk_var ("atom" ^ Int.toString k, type_of t) |-> t) :: l, k + 1)) ([], 0) ats)) th end;
val s1 = ``s1:arm8_state``;
val b = ``b:word64``; val c = ``c:word64``; val a = ``a:word64``; val g = ``g:word64``;
(* ================= 1. The entry stub. ================= *)
val pre1_def = new_definition ("ffiwrite_stub_pre_def", ``ffiwrite_stub_pre ^s <=> arm8_user s /\ s.PC = 0x100004090w /\ ffiwrite_code_bytes s.MEM``);
val pre1 = lhs (snd (strip_forall (concl pre1_def)));
val E1 = engine (pre1, pre1_def, [], [], [], []);
val (st1, chain1) = #run E1 (map snd stub_words);
val posts1 = [#fact E1 ``(^st1).PC``] @ map (unchanged st1) [``arm8_state_REG``, ``arm8_state_MEM``, ``arm8_state_SP_EL0``, ``arm8_state_PSTATE``,
               ``arm8_state_SCTLR_EL1``, ``arm8_state_TCR_EL1``, ``arm8_state_exception``];
val _ = if aconv (rhs (concl (hd posts1))) ``0x1000251E0w:word64`` then () else raise Fail "unexpected stub target";
val stub_thm = close_thm "cake_ffiwrite_stub_run" pre1 st1 (LIST_CONJ (chain1 :: posts1));
val stub_noret = store_thm ("cake_ffiwrite_stub_does_not_return",
  ``ffiwrite_stub_pre ^s /\ s.REG 30w <> 0x1000251E0w ==> ?s1. arm8_run 1 s = SOME s1 /\ s1.PC <> s.REG 30w``,
  rpt strip_tac >> imp_res_tac stub_thm >> gvs []);
val _ = chk "cake_ffiwrite_stub_does_not_return" stub_noret;
val _ = let val r = (#run E1 ["14008455"]; "ACCEPTED") handle _ => "REJECTED" in
   if r = "REJECTED" then pr "CONTROL_OK changed stub word (14008454 -> 14008455) rejected by the fetch hypotheses" else raise Fail "UNEXPECTED_CONTROL_ACCEPTANCE" end;
(* ================= 2. ffiwrite to the branch that leaves the image. ================= *)
val sepS = ``!i (x:word64). i < 32 /\ 0x100000000w <=+ x /\ x <+ 0x100030F30w ==> ^b + n2w i <> x``;
val sepC = ``!i j. i < 32 /\ j < 8 ==> ^b + n2w i <> ^c + n2w j``;
val sepA = ``!i j. i < 32 /\ j < 4 ==> ^b + n2w i <> ^a + n2w j``;
val base_def = new_definition ("ffiwrite_entry_base_def",
  ``ffiwrite_entry_base ^s ^b ^c ^a ^g <=> arm8_user s /\ s.PC = 0x1000251E0w /\ ffiwrite_code_bytes s.MEM /\
      s.SP_EL0 = b + 32w /\ aligned 3 b /\ s.REG 0w = c /\ aligned 2 c /\ s.REG 2w = a /\ aligned 1 a /\ s.REG 1w = 8w /\
      mem_dword s.MEM 0x1000280B0w = g /\ ^sepS /\ ^sepC /\ ^sepA``);
val baseT = lhs (snd (strip_forall (concl base_def)));
val c4 = prove (``aligned 2 ^c ==> aligned 2 (^c + 4w)``, simp [aligned_bitwise_and] >> blastLib.BBLAST_TAC);
val a2 = prove (``aligned 1 ^a ==> aligned 1 (^a + 2w)``, simp [aligned_bitwise_and] >> blastLib.BBLAST_TAC);
val Eb = engine (baseT, base_def, [(b, sepS)], [((b, c), sepC), ((b, a), sepA)], [b], [c4, a2]);
val (stb, _) = #run Eb (List.take (body, 12));
val X9 = rhs (concl (#fact Eb ``(^stb).REG 9w``));
val _ = pr ("LENGTH_TERM " ^ term_to_string X9);
val pre2_def = new_definition ("ffiwrite_entry_pre_def",
  ``ffiwrite_entry_pre ^s ^b ^c ^a ^g <=> ffiwrite_entry_base s b c a g /\ ~word_msb (s.REG 3w) /\ ^X9 <=+ s.REG 3w``);
val pre2 = lhs (snd (strip_forall (concl pre2_def)));
val _ = extra_defs := [base_def];
val p2facts = CONJUNCTS (REWRITE_RULE [pre2_def] (ASSUME pre2));
val f_nmsb = List.nth (p2facts, 1); val f_le = List.nth (p2facts, 2);
val x9_nmsb = blast_gen ``word_msb ^X9 <=> F``;
val y_msb = MP (blast_gen ``~word_msb ((^s).REG 3w) ==> (word_msb (~(^s).REG 3w) <=> T)``) f_nmsb;
val _ = extra_facts := [x9_nmsb, y_msb];
val _ = fallback := (fn r => MP (MP (blast_gen (mk_imp (concl f_nmsb, mk_imp (concl f_le, r)))) f_nmsb) f_le);
val E2 = engine (pre2, pre2_def, [(b, sepS)], [((b, c), sepC), ((b, a), sepA)], [b], [c4, a2]);
val (st2, chain2) = #run E2 (List.take (body, 19) @ map snd imp_words);
val _ = (extra_facts := []; fallback := (fn t => raise mk_HOL_ERR "forge" "fallback" "none"));
fun showfact f tm = let val th = f tm in pr ("POST " ^ term_to_string (lhs (concl th)) ^ " = " ^ term_to_string (rhs (concl th))); th end;
val p2 = map (showfact (#fact E2)) [``(^st2).PC``, ``(^st2).REG 30w``, ``(^st2).REG 19w``, ``(^st2).REG 29w``, ``(^st2).REG 16w``, ``(^st2).SP_EL0``,
                                   ``(^st2).REG 0w``, ``(^st2).REG 1w``, ``(^st2).REG 2w``, ``(^st2).PSTATE.EL``];
val _ = ListPair.app (fn (th, x) => if aconv (rhs (concl th)) x then () else raise Fail ("unexpected post value: " ^ thm_to_string th))
          (List.take (p2, 6), [g, ``0x10002522Cw:word64``, a, ``^b + 16w``, g, b]);
val same2 = map (unchanged st2) [``arm8_state_SCTLR_EL1``, ``arm8_state_TCR_EL1``, ``arm8_state_exception``];
fun slot lk st off reg =
  let val ad = if off = 0 then b else ``^b + ^(w64 off)``
      val l = (REWR_CONV mem_dword_def THENC QC (SIMP_CONV (srw_ss()) []) THENC QC (ONCE_DEPTH_CONV lk) THENC QC (SIMP_CONV (srw_ss()) [])) ``mem_dword (^st).MEM ^ad``
      val e = if aconv (rhs (concl l)) reg then REFL reg else prove (mk_eq (rhs (concl l), reg), SPEC_TAC (reg, ``w:word64``) >> blastLib.BBLAST_TAC)
  in TRANS l e end;
val slots2 = ListPair.map (fn (off, r) => slot (#lookup E2) st2 off r) ([0, 8, 16, 24], [``(^s).REG 20w``, ``(^s).REG 19w``, ``(^s).REG 29w``, ``(^s).REG 30w``]);
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
val prefix_thm = close_thm "ffiwrite_prefix_run" pre2 st2
   (LIST_CONJ (chain2 :: p2 @ same2 @ slots2 @ [frame_thm st2 32 b, regs_thm st2 [0, 1, 2, 8, 9, 16, 19, 29, 30]]));
val _ = extra_defs := [];
(* ================= 3. After the call: the pre-states are ASSUMED. ================= *)
val [v20, v19, v29, v30] = map (fn n => mk_var (n, ``:word64``)) ["v20", "v19", "v29", "v30"];
val sepA1 = ``!i (x:word64). i < 3 /\ 0x100000000w <=+ x /\ x <+ 0x100030F30w ==> ^a + n2w i <> x``;
val sepA2 = ``!i j. i < 3 /\ j < 32 ==> ^a + n2w i <> ^b + n2w j``;
val ret_common = ``arm8_user s /\ s.PC = 0x10002522Cw /\ ffiwrite_code_bytes s.MEM /\ s.SP_EL0 = ^b /\ aligned 3 ^b /\ s.REG 19w = ^a /\
      mem_dword s.MEM b = ^v20 /\ mem_dword s.MEM (b + 8w) = ^v19 /\ mem_dword s.MEM (b + 16w) = ^v29 /\ mem_dword s.MEM (b + 24w) = ^v30 /\
      ^sepA1 /\ ^sepA2``;
(* 3a. the call reported an error (bit 31 of w0 set): 6 steps *)
val preF_def = new_definition ("ffiwrite_return_fail_pre_def",
  ``ffiwrite_return_fail_pre ^s ^b ^a ^v20 ^v19 ^v29 ^v30 <=> ^ret_common /\ word_bit 31 (w2w (s.REG 0w) : word32)``);
val preF = lhs (snd (strip_forall (concl preF_def)));
val EF = engine (preF, preF_def, [(a, sepA1)], [((a, b), sepA2)], [b], []);
val (stF, chainF) = #run EF ([List.nth (body, 19)] @ List.drop (body, 25));
val pF = map (showfact (#fact EF)) [``(^stF).PC``, ``(^stF).REG 30w``, ``(^stF).REG 29w``, ``(^stF).REG 19w``, ``(^stF).REG 20w``, ``(^stF).SP_EL0``,
                                   ``(^stF).MEM ^a``, ``(^stF).PSTATE.EL``];
val _ = ListPair.app (fn (th, x) => if aconv (rhs (concl th)) x then () else raise Fail ("unexpected post value: " ^ thm_to_string th))
          (List.take (pF, 7), [v30, v30, v29, v19, v20, ``^b + 32w``, ``1w:word8``]);
val sameF = map (unchanged stF) [``arm8_state_SCTLR_EL1``, ``arm8_state_TCR_EL1``, ``arm8_state_exception``];
val fail_thm = close_thm "ffiwrite_suffix_fail_run" preF stF
   (LIST_CONJ (chainF :: pF @ sameF @ [frame_thm stF 1 a, regs_thm stF [8, 19, 20, 29, 30]]));
(* 3b. the call reported a count (bit 31 clear): 10 steps. The step library needs the halfword store at a + 1 to be aligned. *)
val preS_def = new_definition ("ffiwrite_return_ok_pre_def",
  ``ffiwrite_return_ok_pre ^s ^b ^a ^v20 ^v19 ^v29 ^v30 <=> ^ret_common /\ ~word_bit 31 (w2w (s.REG 0w) : word32) /\ aligned 1 (^a + 1w)``);
val preS = lhs (snd (strip_forall (concl preS_def)));
val ES = engine (preS, preS_def, [(a, sepA1)], [((a, b), sepA2)], [b], []);
val (stS, chainS) = #run ES (List.take (List.drop (body, 19), 6) @ List.drop (body, 26));
val pS = map (showfact (#fact ES)) [``(^stS).PC``, ``(^stS).REG 30w``, ``(^stS).REG 29w``, ``(^stS).REG 19w``, ``(^stS).REG 20w``, ``(^stS).SP_EL0``,
                                   ``(^stS).MEM ^a``, ``(^stS).MEM (^a + 1w)``, ``(^stS).MEM (^a + 2w)``, ``(^stS).PSTATE.EL``];
val _ = ListPair.app (fn (th, x) => if aconv (rhs (concl th)) x then () else raise Fail ("unexpected post value: " ^ thm_to_string th))
          (List.take (pS, 7), [v30, v30, v29, v19, v20, ``^b + 32w``, ``0w:word8``]);
val sameS = map (unchanged stS) [``arm8_state_SCTLR_EL1``, ``arm8_state_TCR_EL1``, ``arm8_state_exception``];
val ok_thm = close_thm "ffiwrite_suffix_ok_run" preS stS
   (LIST_CONJ (chainS :: pS @ sameS @ [frame_thm stS 3 a, regs_thm stS [8, 9, 19, 20, 29, 30]]));
val incompat = store_thm ("ffiwrite_ok_alignment_conflict", ``~(aligned 1 ^a /\ aligned 1 (^a + 1w))``,
  simp [aligned_bitwise_and] >> blastLib.BBLAST_TAC);
val _ = chk "ffiwrite_ok_alignment_conflict" incompat;
(* ================= 4. clen <> 8: the first check branches to the assertion block. ================= *)
val preC_def = new_definition ("ffiwrite_clen_bad_pre_def",
  ``ffiwrite_clen_bad_pre ^s ^b <=> arm8_user s /\ s.PC = 0x1000251E0w /\ ffiwrite_code_bytes s.MEM /\
      s.SP_EL0 = b + 32w /\ aligned 3 b /\ s.REG 1w <> 8w /\ ^sepS``);
val preC = lhs (snd (strip_forall (concl preC_def)));
val ne8 = prove (``(s:arm8_state).REG 1w <> 8w ==> (s.REG 1w + 0xFFFFFFFFFFFFFFF8w = 0w <=> F)``, blastLib.BBLAST_TAC);
val EC = engine (preC, preC_def, [(b, sepS)], [], [b], [ne8]);
val (stC, chainC) = #run EC (List.take (body, 5));
val pC = #fact EC ``(^stC).PC``;
val _ = if aconv (rhs (concl pC)) ``0x100025258w:word64`` then () else raise Fail ("unexpected pc: " ^ thm_to_string pC);
val thC = close_thm "ffiwrite_clen_bad_reaches_assert" preC stC (LIST_CONJ [chainC, pC]);
val _ = List.app (fn d => pr ("DEFINITION " ^ thm_to_string d)) [pre1_def, base_def, pre2_def, preF_def, preS_def, preC_def];
val _ = export_theory ();
val _ = pr "NATIVE_STEP_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

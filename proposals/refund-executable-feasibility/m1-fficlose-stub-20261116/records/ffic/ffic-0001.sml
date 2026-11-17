(* U393: exact ARMv8 (L3) execution of the entry stub cake_fficlose at 0x100004080 of the linked refund executable, of the C function
   fficlose up to the indirect branch that leaves the image (import stub for close), and of fficlose after the call returns.
   Link addresses, slide 0. The call into libSystem is NOT modelled: the third run starts from an ASSUMED state after the call. *)
open HolKernel Parse boolLib bossLib arm8Theory arm8_stepTheory wordsTheory wordsLib combinTheory alignmentTheory forge_refundCmlMainStepTheory;
val _ = Globals.max_print_depth := 200;
fun pr s = print (s ^ "\n");
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_NATIVE_STEP_OUT"));
val _ = new_theory "forge_refundFficloseStep";
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
(* ---- exact words (compared with the file by the runner's wrapper script and, in the CakeML context, with refund_file) ---- *)
val stub_words = [(0x100004080, "14008478")];
val body_words = ListPair.zip (List.tabulate (17, fn i => 0x100025260 + 4 * i),
   ["a9be4ff4","a9017bfd","910043fd","f100007f","540001ad","f100203f","54000181","aa0203f3","b9400408","5ac00900","94000199",
    "7100001f","1a9f07e8","39000268","a9417bfd","a8c24ff4","d65f03c0"]);
val imp_words = [(0x1000258EC, "f0000010"), (0x1000258F0, "f9401210"), (0x1000258F4, "d61f0200")];
val code_eqs = List.concat (map (fn (a, w) => List.tabulate (4, fn k => ``^m ^(w64 (a + k)) = ^(w8 (hexbyte w (6 - 2 * k)))``))
                                (stub_words @ body_words @ imp_words));
val code_def = new_definition ("fficlose_code_bytes_def", ``fficlose_code_bytes ^m = ^(list_mk_conj code_eqs)``);
val user_def = new_definition ("arm8_user_def", ``arm8_user ^s <=> ~s.SCTLR_EL1.E0E /\ ~s.SCTLR_EL1.SA0 /\ ~s.TCR_EL1.TBI0 /\ ~s.TCR_EL1.TBI1 /\
                                                   s.PSTATE.EL = 0w /\ s.exception = NoException``);
val _ = pr ("CODE_BYTES " ^ Int.toString (length code_eqs));
(* ---- engine ---- *)
fun base_off tm =
  if null (free_vars tm) then (NONE, wordsSyntax.uint_of_word (rhs (concl (EVAL tm)) handle UNCHANGED => tm))
  else if is_var tm then (SOME tm, Arbnum.zero)
  else let val (x, y) = wordsSyntax.dest_word_add tm in
         if is_var x andalso null (free_vars y) then (SOME x, wordsSyntax.uint_of_word y) else raise mk_HOL_ERR "forge" "base_off" "form" end;
fun engine (pre_tm, pre_def, lit_seps, pair_seps, aligned_vars) =
  let
    val all = CONJUNCTS (REWRITE_RULE [pre_def, user_def, code_def] (ASSUME pre_tm))
    val plain = List.filter (fn th => not (is_forall (concl th))) all
    fun find_sep tm = valOf (List.find (fn th => aconv (concl th) tm) all)
    val lit = map (fn (v, tm) => (v, find_sep tm)) lit_seps
    val pair = map (fn ((x, y), tm) => ((x, y), find_sep tm)) pair_seps
    fun al_of v = let val base = valOf (List.find (fn th => aconv (concl th) ``aligned 3 ^v``) all)
                      val more = map (fn c => MP (prove (``aligned 3 ^v ==> aligned 3 (^v + ^(w64 c))``,
                                     simp [aligned_bitwise_and] >> blastLib.BBLAST_TAC)) base) [8, 16, 24, 32]
                      val alls = base :: more
                  in alls @ List.mapPartial (fn th => SOME (SIMP_RULE (srw_ss()) [] th) handle _ => NONE) alls end
    val facts = plain @ List.concat (map al_of aligned_vars)
    fun num k = numSyntax.mk_numeral k
    fun var_lit x k l = (* |- x + k <> l *)
      let val th = Lib.assoc x lit handle _ => raise mk_HOL_ERR "forge" "decide" ("no literal separation for " ^ term_to_string x)
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
      let fun is_load t = (let val (c, args) = strip_comb t in is_const c andalso Lib.mem (fst (dest_const c)) ["mem_dword", "mem_word"] andalso
                                 length args = 2 andalso not (aconv (hd args) base_mem) end) handle _ => false
          val ts = find_terms is_load tm
          fun one t = let val (c, [mm, a]) = strip_comb t
                          val d = if fst (dest_const c) = "mem_dword" then mem_dword_def else mem_word_def
                          val l = (REWR_CONV d THENC QC (SIMP_CONV (srw_ss()) []) THENC QC (ONCE_DEPTH_CONV lookup)) t
                          val r = (REWR_CONV d THENC QC (SIMP_CONV (srw_ss()) [])) (mk_comb (mk_comb (c, base_mem), a))
                      in SOME (TRANS l (SYM r)) handle HOL_ERR _ => NONE end
      in QC (PURE_REWRITE_CONV (List.mapPartial one ts)) tm end
    fun step (w, (k, st, chain)) =
      let val ths = arm8_stepLib.arm8_step_hex w
          fun try th = let val th1 = INST [s |-> st] th
                           fun dis hy = let val r = (norm THENC QC EVAL) hy in
                                 if aconv (rhs (concl r)) T then EQT_ELIM r
                                 else raise mk_HOL_ERR "forge" "step" ("hypothesis: " ^ term_to_string hy ^ " ==> " ^ term_to_string (rhs (concl r))) end
                       in List.foldl (fn (hy, t) => PROVE_HYP (dis hy) t) th1 (hyp th1) end
          fun first [] = raise Fail ("no step theorem applies at step " ^ Int.toString (k + 1) ^ " word " ^ w)
            | first (th :: rest) = (try th handle HOL_ERR e => (pr ("STEP_ALTERNATIVE_REJECTED " ^ w ^ " " ^ #message e); first rest))
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
(* ================= 1. The entry stub: one step. ================= *)
val pre1_def = new_definition ("fficlose_stub_pre_def",
  ``fficlose_stub_pre ^s <=> arm8_user s /\ s.PC = 0x100004080w /\ fficlose_code_bytes s.MEM``);
val pre1 = lhs (snd (strip_forall (concl pre1_def)));
val E1 = engine (pre1, pre1_def, [], [], []);
val (st1, chain1) = #run E1 (map snd stub_words);
val _ = pr ("STUB_STATE " ^ term_to_string st1);
val posts1 = [#fact E1 ``(^st1).PC``] @ map (unchanged st1) [``arm8_state_REG``, ``arm8_state_MEM``, ``arm8_state_SP_EL0``, ``arm8_state_PSTATE``,
               ``arm8_state_SCTLR_EL1``, ``arm8_state_TCR_EL1``, ``arm8_state_exception``];
val _ = if aconv (rhs (concl (hd posts1))) ``0x100025260w:word64`` then () else raise Fail "unexpected stub target";
val stub_thm = close_thm "cake_fficlose_stub_run" pre1 st1 (LIST_CONJ (chain1 :: posts1));
val stub_wrong = store_thm ("cake_fficlose_stub_wrong_target_refuted",
  ``fficlose_stub_pre ^s ==> ~(?s1. arm8_run 1 s = SOME s1 /\ s1.PC = 0x100025264w)``,
  rpt strip_tac >> imp_res_tac stub_thm >> gvs []);
val _ = chk "cake_fficlose_stub_wrong_target_refuted" stub_wrong;
val stub_noret = store_thm ("cake_fficlose_stub_does_not_return",
  ``fficlose_stub_pre ^s /\ s.REG 30w <> 0x100025260w ==> ?s1. arm8_run 1 s = SOME s1 /\ s1.PC <> s.REG 30w``,
  rpt strip_tac >> imp_res_tac stub_thm >> gvs []);
val _ = chk "cake_fficlose_stub_does_not_return" stub_noret;
val _ = let val r = (#run E1 ["14008479"]; "ACCEPTED") handle _ => "REJECTED" in
   if r = "REJECTED" then pr "CONTROL_OK changed stub word (14008478 -> 14008479) rejected by the fetch hypotheses" else raise Fail "UNEXPECTED_CONTROL_ACCEPTANCE" end;
(* ================= 2. fficlose up to the branch that leaves the image: 14 steps. ================= *)
val b = ``b:word64``; val c = ``c:word64``; val g = ``g:word64``;
val sepS = ``!i (a:word64). i < 32 /\ 0x100000000w <=+ a /\ a <+ 0x100030F30w ==> ^b + n2w i <> a``;
val sepC = ``!i j. i < 32 /\ j < 8 ==> ^b + n2w i <> ^c + n2w j``;
val pre2_def = new_definition ("fficlose_entry_pre_def",
  ``fficlose_entry_pre ^s ^b ^c ^g <=> arm8_user s /\ s.PC = 0x100025260w /\ fficlose_code_bytes s.MEM /\
      s.SP_EL0 = b + 32w /\ aligned 3 b /\ s.REG 0w = c /\ s.REG 1w = 8w /\ ~word_msb (s.REG 3w) /\ s.REG 3w <> 0w /\
      mem_dword s.MEM 0x100028020w = g /\ ^sepS /\ ^sepC``);
val pre2 = lhs (snd (strip_forall (concl pre2_def)));
val E2 = engine (pre2, pre2_def, [(b, sepS)], [((b, c), sepC)], [b]);
val (st2, chain2) = #run E2 (map snd (List.take (body_words, 11)) @ map snd imp_words);
val _ = pr ("PREFIX_STATE " ^ term_to_string st2);
fun showfact E tm = let val th = #fact E tm in pr ("POST " ^ thm_to_string th); th end;
val p2 = map (showfact E2) [``(^st2).PC``, ``(^st2).REG 30w``, ``(^st2).REG 19w``, ``(^st2).REG 29w``, ``(^st2).REG 16w``, ``(^st2).SP_EL0``,
                            ``(^st2).REG 0w``, ``(^st2).PSTATE.EL``];
val want2 = [g, ``0x10002528Cw:word64``, ``(^s).REG 2w``, ``^b + 16w``, g, b];
val _ = ListPair.app (fn (th, x) => if aconv (rhs (concl th)) x then () else raise Fail ("unexpected post value: " ^ thm_to_string th)) (List.take (p2, 6), want2);
val same2 = map (unchanged st2) [``arm8_state_SCTLR_EL1``, ``arm8_state_TCR_EL1``, ``arm8_state_exception``];
(* saved registers in the frame *)
fun slot E st off reg =
  let val a = if off = 0 then b else ``^b + ^(w64 off)``
      val l = (REWR_CONV mem_dword_def THENC QC (SIMP_CONV (srw_ss()) []) THENC QC (ONCE_DEPTH_CONV (#lookup E)) THENC QC (SIMP_CONV (srw_ss()) [])) ``mem_dword (^st).MEM ^a``
      val goal = mk_eq (rhs (concl l), reg)
      val e = if aconv (rhs (concl l)) reg then REFL reg else prove (goal, SPEC_TAC (reg, ``w:word64``) >> blastLib.BBLAST_TAC)
  in TRANS l e end;
val slots2 = ListPair.map (fn (off, r) => slot E2 st2 off r) ([0, 8, 16, 24], [``(^s).REG 20w``, ``(^s).REG 19w``, ``(^s).REG 29w``, ``(^s).REG 30w``]);
val _ = List.app (fn th => pr ("SLOT " ^ term_to_string (lhs (concl th)) ^ " = " ^ term_to_string (rhs (concl th)))) slots2;
(* frame and other registers *)
fun frame_thm st n base =
  let val a = ``a:word64`` val hy = ``!i. i < ^(numSyntax.term_of_int n) ==> ^a <> ^base + n2w i``
      val ne = List.tabulate (n, fn k => SPEC (numSyntax.term_of_int k) (ASSUME hy) |> CONV_RULE (LAND_CONV EVAL) |> (fn th => MP th TRUTH) |> REWRITE_RULE [WORD_ADD_0])
      val th = SIMP_CONV (srw_ss()) (APPLY_UPDATE_THM :: ne @ map GSYM ne) ``(^st).MEM ^a``
      val _ = if aconv (rhs (concl th)) ``(^s).MEM ^a`` then () else raise Fail ("frame not reduced: " ^ term_to_string (rhs (concl th)))
  in GEN a (DISCH hy th) end;
fun regs_thm st changed =
  let val r = ``r:word5`` val hy = list_mk_conj (map (fn k => ``^r <> ^(wordsSyntax.mk_wordii (k, 5))``) changed)
      val ne = CONJUNCTS (ASSUME hy)
      val th = SIMP_CONV (srw_ss()) (APPLY_UPDATE_THM :: ne @ map GSYM ne) ``(^st).REG ^r``
      val _ = if aconv (rhs (concl th)) ``(^s).REG ^r`` then () else raise Fail ("registers not reduced: " ^ term_to_string (rhs (concl th)))
  in GEN r (DISCH hy th) end;
val prefix_thm = close_thm "fficlose_prefix_run" pre2 st2
   (LIST_CONJ (chain2 :: p2 @ same2 @ slots2 @ [frame_thm st2 32 b, regs_thm st2 [0, 8, 16, 19, 29, 30]]));
(* ================= 3. fficlose after the call returns: 6 steps. The pre-state is ASSUMED. ================= *)
val a = ``a:word64``;
val [v20, v19, v29, v30] = map (fn n => mk_var (n, ``:word64``)) ["v20", "v19", "v29", "v30"];
val sepA1 = ``!i (x:word64). i < 1 /\ 0x100000000w <=+ x /\ x <+ 0x100030F30w ==> ^a + n2w i <> x``;
val sepA2 = ``!i j. i < 1 /\ j < 32 ==> ^a + n2w i <> ^b + n2w j``;
val pre3_def = new_definition ("fficlose_return_pre_def",
  ``fficlose_return_pre ^s ^b ^a ^v20 ^v19 ^v29 ^v30 <=> arm8_user s /\ s.PC = 0x10002528Cw /\ fficlose_code_bytes s.MEM /\
      s.SP_EL0 = b /\ aligned 3 b /\ s.REG 19w = a /\
      mem_dword s.MEM b = v20 /\ mem_dword s.MEM (b + 8w) = v19 /\ mem_dword s.MEM (b + 16w) = v29 /\ mem_dword s.MEM (b + 24w) = v30 /\
      ^sepA1 /\ ^sepA2``);
val pre3 = lhs (snd (strip_forall (concl pre3_def)));
val E3 = engine (pre3, pre3_def, [(a, sepA1)], [((a, b), sepA2)], [b]);
val (st3, chain3) = #run E3 (map snd (List.drop (body_words, 11)));
val _ = pr ("SUFFIX_STATE " ^ term_to_string st3);
val p3 = map (showfact E3) [``(^st3).PC``, ``(^st3).REG 30w``, ``(^st3).REG 29w``, ``(^st3).REG 19w``, ``(^st3).REG 20w``, ``(^st3).SP_EL0``,
                            ``(^st3).MEM ^a``, ``(^st3).PSTATE.EL``];
val _ = ListPair.app (fn (th, x) => if aconv (rhs (concl th)) x then () else raise Fail ("unexpected post value: " ^ thm_to_string th))
          (List.take (p3, 6), [v30, v30, v29, v19, v20, ``^b + 32w``]);
val same3 = map (unchanged st3) [``arm8_state_SCTLR_EL1``, ``arm8_state_TCR_EL1``, ``arm8_state_exception``];
val suffix_thm = close_thm "fficlose_suffix_run" pre3 st3
   (LIST_CONJ (chain3 :: p3 @ same3 @ [frame_thm st3 1 a, regs_thm st3 [8, 19, 20, 29, 30]]));
val suffix_wrong = store_thm ("fficlose_suffix_wrong_return_refuted",
  ``fficlose_return_pre ^s ^b ^a ^v20 ^v19 ^v29 ^v30 /\ x <> v30 ==> ~(?s1. arm8_run 6 s = SOME s1 /\ s1.PC = x)``,
  rpt strip_tac >> imp_res_tac suffix_thm >> gvs []);
val _ = chk "fficlose_suffix_wrong_return_refuted" suffix_wrong;
val _ = let val r = (#run E3 ("7100001f" :: "1a9f07e8" :: "39000269" :: map snd (List.drop (body_words, 14))); "ACCEPTED") handle _ => "REJECTED" in
   if r = "REJECTED" then pr "CONTROL_OK changed store word (39000268 -> 39000269) rejected by the fetch hypotheses" else raise Fail "UNEXPECTED_CONTROL_ACCEPTANCE" end;
val _ = List.app (fn d => pr ("DEFINITION " ^ thm_to_string d)) [user_def, pre1_def, pre2_def, pre3_def];
val _ = export_theory ();
val _ = pr "NATIVE_STEP_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

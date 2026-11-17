(* U394: the two assertion paths of fficlose (invalid arguments): exact ARMv8 (L3) steps up to the branch into the assertion block.
   The assertion block and __assert_rtn are NOT modelled. Link addresses, slide 0. *)
open HolKernel Parse boolLib bossLib arm8Theory arm8_stepTheory wordsTheory wordsLib combinTheory alignmentTheory forge_refundCmlMainStepTheory
     forge_refundFficloseStepTheory;
val _ = Globals.max_print_depth := 200;
fun pr s = print (s ^ "\n");
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_NATIVE_STEP_OUT"));
val _ = new_theory "forge_refundFficloseAssert";
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
val run_def = DB.fetch "forge_refundCmlMainStep" "arm8_run_def";
val run_snoc = prove (``!n s s1 s2. arm8_run n s = SOME s1 /\ NextStateARM8 s1 = SOME s2 ==> arm8_run (SUC n) s = SOME s2``,
  Induct >- simp [run_def] >>
  rpt gen_tac >> ONCE_REWRITE_TAC [run_def] >> Cases_on `NextStateARM8 s` >> simp [] >> metis_tac []);
fun w64 n = wordsSyntax.mk_wordii (n, 64);
fun QC c tm = c tm handle UNCHANGED => REFL tm;
val s = ``s:arm8_state``;
val code_def = DB.fetch "forge_refundFficloseStep" "fficlose_code_bytes_def";
val user_def = DB.fetch "forge_refundFficloseStep" "arm8_user_def";
val body = ["a9be4ff4","a9017bfd","910043fd","f100007f","540001ad","f100203f","54000181"];
(* ---- engine ---- *)
fun base_off tm =
  if null (free_vars tm) then (NONE, wordsSyntax.uint_of_word (rhs (concl (EVAL tm)) handle UNCHANGED => tm))
  else if is_var tm then (SOME tm, 0)
  else let val (x, y) = wordsSyntax.dest_word_add tm in
         if is_var x andalso null (free_vars y) then (SOME x, wordsSyntax.uint_of_word y) else raise mk_HOL_ERR "forge" "base_off" "form" end;
fun engine (pre_tm, pre_def, lit_seps, pair_seps, aligned_vars, rules) =
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
    val derived = map (fn r => MP r (valOf (List.find (fn th => aconv (concl th) (fst (dest_imp (concl r)))) all))) rules
    val facts = plain @ derived @ List.concat (map al_of aligned_vars)
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
val b = ``b:word64``;
val sepS = ``!i (a:word64). i < 32 /\ 0x100000000w <=+ a /\ a <+ 0x100030F30w ==> ^b + n2w i <> a``;
(* ---- alen = 0: the first check branches to 0x1000252A4. ---- *)
val preA_def = new_definition ("fficlose_alen_zero_pre_def",
  ``fficlose_alen_zero_pre ^s ^b <=> arm8_user s /\ s.PC = 0x100025260w /\ fficlose_code_bytes s.MEM /\
      s.SP_EL0 = b + 32w /\ aligned 3 b /\ s.REG 3w = 0w /\ ^sepS``);
val preA = lhs (snd (strip_forall (concl preA_def)));
val EA = engine (preA, preA_def, [(b, sepS)], [], [b], []);
val (stA, chainA) = #run EA (List.take (body, 5));
val pA = #fact EA ``(^stA).PC``;
val _ = if aconv (rhs (concl pA)) ``0x1000252A4w:word64`` then () else raise Fail ("unexpected pc: " ^ thm_to_string pA);
val thA = close_thm "fficlose_alen_zero_reaches_assert" preA stA (LIST_CONJ [chainA, pA, #fact EA ``(^stA).REG 30w``]);
(* ---- clen <> 8 (alen positive): the second check branches to 0x1000252A8. ---- *)
val preC_def = new_definition ("fficlose_clen_bad_pre_def",
  ``fficlose_clen_bad_pre ^s ^b <=> arm8_user s /\ s.PC = 0x100025260w /\ fficlose_code_bytes s.MEM /\
      s.SP_EL0 = b + 32w /\ aligned 3 b /\ ~word_msb (s.REG 3w) /\ s.REG 3w <> 0w /\ s.REG 1w <> 8w /\ ^sepS``);
val preC = lhs (snd (strip_forall (concl preC_def)));
val ne8 = prove (``(s:arm8_state).REG 1w <> 8w ==> (s.REG 1w + 0xFFFFFFFFFFFFFFF8w = 0w <=> F)``, blastLib.BBLAST_TAC);
val EC = engine (preC, preC_def, [(b, sepS)], [], [b], [ne8]);
val (stC, chainC) = #run EC body;
val pC = #fact EC ``(^stC).PC``;
val _ = if aconv (rhs (concl pC)) ``0x1000252A8w:word64`` then () else raise Fail ("unexpected pc: " ^ thm_to_string pC);
val thC = close_thm "fficlose_clen_bad_reaches_assert" preC stC (LIST_CONJ [chainC, pC, #fact EC ``(^stC).REG 30w``]);
val _ = List.app (fn d => pr ("DEFINITION " ^ thm_to_string d)) [preA_def, preC_def];
val _ = export_theory ();
val _ = pr "NATIVE_STEP_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

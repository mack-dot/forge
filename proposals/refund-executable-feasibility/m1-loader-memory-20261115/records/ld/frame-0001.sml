(* U389: the 27 cml_main steps of U388 again, with a memory frame and unchanged control fields.
   Definitions arm8_run and cml_main_pre are the stored ones of forge_refundCmlMainStep. Unslid link addresses. *)
open HolKernel Parse boolLib bossLib arm8Theory arm8_stepTheory wordsTheory wordsLib combinTheory alignmentTheory forge_refundCmlMainStepTheory;
val _ = Globals.max_print_depth := 200;
fun pr s = print (s ^ "\n");
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_NATIVE_STEP_OUT"));
val _ = new_theory "forge_refundCmlMainFrame";
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val words = ["90000000","91034000","90000141","91000021","f9400021","90000142","91006042","f9000022","90000162","913cc042","f9000422",
             "90000162","913cc042","f9000822","f00000e2","91395042","f9000c22","90000102","91000042","f9001022","90000142","91002042",
             "f9400042","90000143","91004063","f9400063","1400001a"];
val base = 0x100004000;
val s = ``s:arm8_state``; val h = ``h:word64``; val stk = ``stk:word64``; val e = ``e:word64``;
fun w64 n = wordsSyntax.mk_wordii (n, 64);
fun w8 n = wordsSyntax.mk_wordii (n, 8);
fun hexbyte str i = valOf (StringCvt.scanString (Int.scan StringCvt.HEX) (String.substring (str, i, 2)));
(* little-endian: byte k of the word at offset 4*j is characters 6-2k .. *)
val code_eqs = List.concat (List.tabulate (length words, fn j => let val w = List.nth (words, j) in List.tabulate (4, fn k =>
      ``(^s).MEM ^(w64 (base + 4 * j + k)) = ^(w8 (hexbyte w (6 - 2 * k)))``) end));
val run_def = DB.fetch "forge_refundCmlMainStep" "arm8_run_def";
val run_snoc = prove (``!n s s1 s2. arm8_run n s = SOME s1 /\ NextStateARM8 s1 = SOME s2 ==> arm8_run (SUC n) s = SOME s2``,
  Induct >- simp [run_def] >>
  rpt gen_tac >> ONCE_REWRITE_TAC [run_def] >> Cases_on `NextStateARM8 s` >> simp [] >> metis_tac []);
val sep_tm = ``!i a. i < 40 /\ 0x100004000w <=+ a /\ a <+ 0x10002C018w ==> ^h + n2w i <> (a:word64)``;
val pre_list = [``~(^s).SCTLR_EL1.E0E``, ``~(^s).SCTLR_EL1.SA0``, ``~(^s).TCR_EL1.TBI0``, ``~(^s).TCR_EL1.TBI1``,
   ``(^s).PSTATE.EL = 0w``, ``(^s).exception = NoException``, ``(^s).PC = 0x100004000w``,
   ``mem_dword (^s).MEM 0x10002C000w = ^h``, ``mem_dword (^s).MEM 0x10002C008w = ^stk``, ``mem_dword (^s).MEM 0x10002C010w = ^e``,
   ``aligned 3 ^h``, sep_tm] @ code_eqs;
val pre_def = DB.fetch "forge_refundCmlMainStep" "cml_main_pre_def";
val _ = if aconv (rhs (snd (strip_forall (concl pre_def)))) (list_mk_conj pre_list) then pr "PRE_DEFINITION_IDENTICAL true" else raise Fail "stored pre-state differs";
val pre_tm = lhs (snd (strip_forall (concl pre_def)));
val pre_facts = CONJUNCTS (CONV_RULE (REWR_CONV (SPEC_ALL pre_def)) (ASSUME pre_tm));
val _ = if length pre_facts = length pre_list then () else raise Fail "precondition split";
val sepA = List.nth (pre_facts, 11);
val al = map (fn c => MP (prove (``aligned 3 ^h ==> aligned 3 (^h + ^(w64 c))``,
              simp [aligned_bitwise_and] >> blastLib.BBLAST_TAC)) (List.nth (pre_facts, 10))) [8, 16, 24, 32];
val al_all = List.nth (pre_facts, 10) :: al;
val al_n = List.mapPartial (fn th => SOME (SIMP_RULE (srw_ss()) [] th) handle _ => NONE) al_all;
val _ = List.app (fn th => pr ("ALIGN_FACT " ^ thm_to_string th)) al_n;
val facts = List.take (pre_facts, 11) @ List.drop (pre_facts, 12) @ al @ al_n;
(* Address comparison. *)
fun h_off tm = if aconv tm h then SOME 0 else
   (let val (a, b) = wordsSyntax.dest_word_add tm in if aconv a h then SOME (wordsSyntax.uint_of_word b) else NONE end handle _ => NONE);
fun decide eq = let val (a, x) = dest_eq eq in
   if null (free_vars a) andalso null (free_vars x) then EVAL eq
   else if not (null (free_vars a)) andalso not (null (free_vars x)) then SIMP_CONV (srw_ss()) [] eq
   else let val (ht, lit, flip) = if null (free_vars x) then (a, x, false) else (x, a, true)
            val c = valOf (h_off ht)
            val lit' = rhs (concl (EVAL lit)) handle _ => lit
            val th = SPECL [numSyntax.term_of_int c, lit'] sepA |> CONV_RULE (LAND_CONV EVAL) |> (fn th => MP th TRUTH)
                     |> REWRITE_RULE [WORD_ADD_0]
            val th = if flip then GSYM th else th
            val res = EQF_INTRO th
        in if aconv (lhs (concl res)) (if aconv lit lit' then eq else lhs (concl res)) then res else res end end
   handle ex => (pr ("DECIDE_FAILED " ^ term_to_string eq); raise ex);
fun lookup tm = let val (c, args) = strip_comb tm in
   if is_const c andalso fst (dest_const c) = "UPDATE" andalso length args = 4 then
     let val x = List.nth (args, 3)
         val xth = if null (free_vars x) then (EVAL x handle UNCHANGED => REFL x) else REFL x
         val th0 = AP_TERM (rator tm) xth
         val tm1 = rhs (concl th0)
         val (_, [a, v, f, x1]) = strip_comb tm1
         val eqth = decide (mk_eq (a, x1))
         val th1 = (REWR_CONV APPLY_UPDATE_THM THENC RATOR_CONV (RATOR_CONV (RAND_CONV (K eqth))) THENC PURE_ONCE_REWRITE_CONV [COND_CLAUSES]) tm1
         val th2 = TRANS th0 th1
     in TRANS th2 (lookup (rhs (concl th2))) handle UNCHANGED => th2 | HOL_ERR _ => th2 end
   else raise mk_HOL_ERR "forge" "lookup" "not an update lookup" end;
fun QC c tm = c tm handle UNCHANGED => REFL tm;
val simp_conv = SIMP_CONV (srw_ss()) facts;

fun norm tm = (QC simp_conv THENC QC (ONCE_DEPTH_CONV lookup) THENC QC simp_conv) tm;
val base_mem = ``(^s).MEM``;
fun frame_dwords tm = (* rewrite mem_dword M A, M not the initial memory, to mem_dword s.MEM A *)
  let val ts = find_terms (fn t => (let val (c, args) = strip_comb t in is_const c andalso fst (dest_const c) = "mem_dword" andalso length args = 2
                                        andalso not (aconv (hd args) base_mem) end) handle _ => false) tm
      fun one t = let val [m, a] = snd (strip_comb t)
                      val l = (REWR_CONV mem_dword_def THENC QC (SIMP_CONV (srw_ss()) []) THENC QC (ONCE_DEPTH_CONV lookup)) t
                      val r = (REWR_CONV mem_dword_def THENC QC (SIMP_CONV (srw_ss()) [])) ``mem_dword ^base_mem ^a``
                  in TRANS l (SYM r) end
  in QC (PURE_REWRITE_CONV (map one ts)) tm end;
fun step (w, (k, st, chain)) =
  let val th = hd (arm8_stepLib.arm8_step_hex w)
      val th1 = INST [s |-> st] th
      fun dis hy = let val r0 = norm hy
                       val r = (norm THENC QC EVAL) hy in
                     if aconv (rhs (concl r)) T then EQT_ELIM r
                     else (pr ("HYP_FAILED step " ^ Int.toString k ^ " word " ^ w ^ "\n" ^ term_to_string hy ^ "\n==> " ^ term_to_string (rhs (concl r)));
                           raise Fail "hypothesis") end
      val th2 = List.foldl (fn (hy, t) => PROVE_HYP (dis hy) t) th1 (hyp th1)
      val th3 = CONV_RULE (RAND_CONV (RAND_CONV (norm THENC frame_dwords THENC norm))) th2
      val st' = rand (rhs (concl th3))
      val chain' = MATCH_MP run_snoc (CONJ chain th3)
      val _ = pr ("STEP_OK " ^ Int.toString (k + 1) ^ " " ^ w ^ " PC " ^ term_to_string (rhs (concl (QC simp_conv ``(^st').PC``))))
  in (k + 1, st', chain') end;
val chain0 = SPEC s (CONJUNCT1 run_def);
val (n, st27, chain) = List.foldl step (0, s, chain0) words;
val chain = CONV_RULE (LAND_CONV (RATOR_CONV (RAND_CONV numLib.REDUCE_CONV))) chain;
val _ = pr ("FINAL_STATE " ^ term_to_string st27);
fun fact tm = let val r = (norm THENC QC EVAL) tm in pr ("POST " ^ thm_to_string r); r end;
fun hdr off = let val a = if off = 0 then h else ``^h + ^(w64 off)`` in
   (REWR_CONV mem_dword_def THENC QC (SIMP_CONV (srw_ss()) []) THENC QC (ONCE_DEPTH_CONV lookup) THENC QC EVAL) ``mem_dword (^st27).MEM ^a`` end;
val posts = [fact ``(^st27).PC``, fact ``(^st27).REG 0w``, fact ``(^st27).REG 1w``, fact ``(^st27).REG 2w``, fact ``(^st27).REG 3w``] @
            map (fn off => let val r = hdr off in pr ("POST " ^ thm_to_string r); r end) [0, 8, 16, 24, 32];
val expected = [``0x1000040D0w:word64``, ``0x1000040D0w:word64``, h, stk, e, ``0x10002C018w:word64``, ``0x100030F30w:word64``,
                ``0x100030F30w:word64``, ``0x100023E54w:word64``, ``0x100024000w:word64``];
val _ = ListPair.app (fn (th, x) => if aconv (rhs (concl th)) x then () else raise Fail ("unexpected post value: " ^ thm_to_string th)) (posts, expected);
val conjT = LIST_CONJ (chain :: posts);
val s1 = ``s1:arm8_state``;
val ex_tm = mk_exists (s1, subst [st27 |-> s1] (concl conjT));
val exT = EXISTS (ex_tm, st27) conjT;
val _ = if length (hyp exT) = 1 andalso aconv (hd (hyp exT)) pre_tm then () else
          (List.app (fn t => pr ("HYP " ^ term_to_string t)) (hyp exT); raise Fail "unexpected hypotheses");
val stored_run = DB.fetch "forge_refundCmlMainStep" "cml_main_run";
val _ = if aconv (concl (DISCH pre_tm exT)) (concl stored_run) then pr "RUN_STATEMENT_IDENTICAL true" else raise Fail "re-derived cml_main_run differs from the stored one";
(* Frame: an address outside the 40 header bytes keeps its byte. *)
val a = ``a:word64``;
val frame_tm = ``!i. i < 40 ==> ^a <> ^h + n2w i``;
val ne = List.tabulate (40, fn k => SPEC (numSyntax.term_of_int k) (ASSUME frame_tm) |> CONV_RULE (LAND_CONV EVAL) |> (fn th => MP th TRUTH)
                                     |> REWRITE_RULE [WORD_ADD_0]);
val ne2 = ne @ map GSYM ne;
val memeq = SIMP_CONV (srw_ss()) (APPLY_UPDATE_THM :: ne2) ``(^st27).MEM ^a``;
val _ = if aconv (rhs (concl memeq)) ``(^s).MEM ^a`` then () else raise Fail ("frame not reduced: " ^ thm_to_string memeq);
val frameT = GEN a (DISCH frame_tm memeq);
fun same tm = let val r = QC (SIMP_CONV (srw_ss()) []) ``^tm ^st27`` val want = ``^tm ^s`` in
   if aconv (rhs (concl r)) want orelse aconv (rhs (concl r)) (rhs (concl (QC (SIMP_CONV (srw_ss()) []) want))) then
     TRANS r (SYM (QC (SIMP_CONV (srw_ss()) []) want)) else raise Fail ("field changed: " ^ term_to_string tm) end;
val fields = map same [``arm8_state_PSTATE``, ``arm8_state_SCTLR_EL1``, ``arm8_state_TCR_EL1``, ``arm8_state_exception``];
val _ = List.app (fn th => pr ("FIELD " ^ thm_to_string th)) fields;
val conjF = LIST_CONJ (chain :: posts @ [frameT] @ fields);
val ex_tmF = mk_exists (s1, subst [st27 |-> s1] (concl conjF));
val exF = EXISTS (ex_tmF, st27) conjF;
val _ = if length (hyp exF) = 1 andalso aconv (hd (hyp exF)) pre_tm then () else raise Fail "unexpected hypotheses (frame)";
val cml_main_run_frame = save_thm ("cml_main_run_frame", DISCH pre_tm exF);
val _ = (tags "cml_main_run_frame" cml_main_run_frame; pr ("CHECKED cml_main_run_frame\n" ^ thm_to_string cml_main_run_frame));
(* Control: the frame does not hold inside the header. Byte 0 of the header becomes 0x18. *)
val inside = (REWR_CONV (GSYM (SPEC_ALL WORD_ADD_0)) THENC ALL_CONV) h handle _ => REFL h;
val b0 = QC (SIMP_CONV (srw_ss()) [APPLY_UPDATE_THM]) ``(^st27).MEM ^h``;
val _ = if aconv (rhs (concl b0)) ``24w:word8`` then pr ("CONTROL_OK header byte is written: " ^ thm_to_string b0) else raise Fail "UNEXPECTED_CONTROL_ACCEPTANCE";
val _ = export_theory ();
val _ = pr "NATIVE_STEP_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

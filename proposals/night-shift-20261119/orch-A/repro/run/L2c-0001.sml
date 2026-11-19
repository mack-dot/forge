(* routeA-L2c.sml: worker A19 (Night-Shift Orchestrator A). Route A, step L2c. NOT RUN. Every tactic here is UNCHECKED.
   Theory forge_refundRouteA2c. Parents (by loading): forge_refundRouteA1, forge_refundRouteA2 (case L2-0003),
   forge_refundRouteA2b (case L2b-0003).
   Content:
     (a) DEFINITIONS VokY3 (text of L2b-0003.sml lines 544-550, as a constant) and refund_valid_event (the Y3 event
         predicate WITH the repair LENGTH nb = LENGTH ab; text of L2b-0003.sml lines 538-541 = EVc).
         Controls: VokY3_is_the_L2b_lambda, refund_valid_event_is_the_L2b_EVc_lambda (constant = L2b lambda).
     (b) R4: refund_valid_event_gives_VokY3 (general record; the call_FFI premise of the L2b R4 text is replaced by its
         consequence LENGTH nb = LENGTH ab, so the statement is more general; the literal L2b R4 text is proved as the
         OPTIONAL corollary R4_L2b_literal). refund_calls_premise_VokY3: the third hypothesis of R5
         (ffi_calls_ok_of_valid_events) with P := VokY3, E := refund_valid_event, mc := refund_mc b envmc, built from
         the STORED R5 by ISPECL (not retyped).
     (c) R3 is NOT needed: R4 derives ~word_msb (REG 3w) from w2n (REG 3w) = 4100 or 2052 (the exact array lengths of
         a valid event and read_bytearray_LENGTH). No CARD/FINITE premise anywhere (control).
     (d) refund_profile_a_sl_events: refund_profile_a_sl_reach with Vok := VokY3 and its premise (3) replaced by R6
         (the events premise exactly as R5 consumes it, for the totalised machine). All goal terms are built from the
         stored theorems (DB.fetch, INST, ISPECL, strip_conj, dest_imp), never retyped.
     (e) controls (proved): two positive events, a close event and the N4 short-array read event rejected,
         aconv checks of the assembly theorem against refund_profile_a_sl_reach, REMAINING_PREMISE_* lines.
   Harness: the one of L2b-0003.sml (sha256 cb6efb52...af95), copied. *)
open preamble targetSemTheory targetPropsTheory ffiTheory semanticsPropsTheory fsFFITheory basis_ffiTheory TextIOProofTheory
     backendTheory asmPropsTheory lab_to_targetTheory arm8Theory arm8_targetTheory alignmentTheory miscTheory set_sepTheory
     backendProofTheory arm8_configProofTheory wordsLib blastLib forge_refundArm8CompileTheory forge_refundExclusionRealTheory
     forge_refundStartupClauseTheory forge_refundStartupBridgeTheory forge_refundInstalledDomainsTheory forge_refundInstalledAssemblyTheory
     forge_refundFfiFactsTheory forge_refundResidualTheory forge_refundEnvModelTheory forge_refundSourceNonFailTheory
     forge_refundProfileATheory forge_refundSlideEntryTheory forge_refundSlideDomainsTheory forge_refundSlideInstalledTheory
     forge_refundSlideSatTheory forge_refundSlideProfileATheory forge_refundRouteA1Theory;
val _ = Globals.max_print_depth := 60;
(* ===== harness (copied from L2b-0003.sml lines 51-120; names A8 -> A19 only) ===== *)
fun pr s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut);
val _ = (load "Timeout"; pr "TIMEOUT_HELPER Timeout.apply loaded")
  handle e => (pr ("TIMEOUT_LOAD_FAILED " ^ General.exnMessage e); raise e);
val _ = metisTools.limit := {time = SOME 30.0, infs = NONE};
val ALT_SECS = 180;
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun trunc n s = if size s <= n then s else String.substring (s, 0, n) ^ " ...";
fun showg tag ((asl, w) : goal) = (pr ("SHOW " ^ tag);
   List.app (fn a => pr ("  ASM " ^ trunc 600 (term_to_string a))) asl;
   pr ("  GOAL " ^ trunc 2500 (term_to_string w)));
fun show_tac tag (g : goal) (ctxt : Context.t) = (showg tag g; ALL_TAC g ctxt);
fun ST tag (tac : tactic) (g : goal) (ctxt : Context.t) = tac g ctxt
  handle e => (showg ("STAGE_FAILED " ^ tag ^ " : " ^ trunc 300 (General.exnMessage e)) g; raise e);
fun CL tag (tac : tactic) (g : goal) (ctxt : Context.t) =
  let val r as (gs, _) = ST tag tac g ctxt in
    if null gs then r
    else (List.app (showg ("UNSOLVED " ^ tag)) gs; raise mk_HOL_ERR "A19" "CL" ("unsolved goals at " ^ tag))
  end;
fun tlim secs (tac : tactic) (g : goal) (ctxt : Context.t) =
  Timeout.apply (Time.fromSeconds (Int.toLarge secs)) (fn () => tac g ctxt) ()
  handle Timeout.TIMEOUT _ => (pr ("TIMEOUT_ALT after " ^ Int.toString secs ^ " s");
                               raise mk_HOL_ERR "A19" "tlim" "time limit");
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundRouteA2c";
val failed = ref ([] : string list);
val problems = ref ([] : string list);
val failed_stmts = ref ([] : (string * term) list);
val diag = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun has_const n tm = can (find_term (fn t => is_const t andalso fst (dest_const t) = n)) tm;
fun names_of_hyps th = map (fn h => case List.find (fn (_, t) => aconv t h) (!failed_stmts) of
                                      SOME (n, _) => n | NONE => "?" ^ trunc 80 (term_to_string h)) (hyp th);
fun tryall name goal tacs =
  let fun go _ [] = raise Fail "all listed tactics failed"
        | go i (t :: ts) =
            (let val th = Tactical.TAC_PROOF (([], goal), tlim ALT_SECS t) in pr ("TACTIC_USED " ^ name ^ " " ^ Int.toString i); th end
             handle e => (pr ("TACTIC_ATTEMPT_FAILED " ^ name ^ " " ^ Int.toString i ^ " " ^ General.exnMessage e); go (i + 1) ts))
  in go 1 tacs end;
fun thmA name goal tacs =
  let val _ = pr ("BEGIN " ^ name)
      fun fail_with msg = (pr ("LEMMA_FAILED " ^ name ^ " " ^ msg); failed := name :: !failed;
                           failed_stmts := (name, goal) :: !failed_stmts; ASSUME goal)
  in (let val th0 = tryall name goal tacs in
        if null (hyp th0) then (let val th = save_thm (name, th0) in chk name th; th end)
        else (pr ("DIAG_OK_UNDER " ^ name ^ " assumed: " ^ String.concatWith " " (names_of_hyps th0));
              diag := name :: !diag; fail_with "(diagnostic only: proved only under failed lemmas)") end)
     handle e => fail_with (General.exnMessage e)
  end;
fun thmO name goal tacs =
  (pr ("BEGIN " ^ name);
   let val th0 = tryall name goal tacs in
     if null (hyp th0) then (let val th = save_thm (name, th0) in chk name th; SOME th end)
     else (pr ("OPTIONAL_FAILED " ^ name ^ " DIAG_OK_UNDER " ^ String.concatWith " " (names_of_hyps th0)); NONE) end)
  handle e => (pr ("OPTIONAL_FAILED " ^ name ^ " " ^ General.exnMessage e); NONE);
(* forward proof as a tactic: f builds the theorem; ACCEPT_TAC checks it against the goal (aconv) *)
fun fwd (f : unit -> thm) (g : goal) (ctxt : Context.t) = ACCEPT_TAC (f ()) g ctxt;
fun three l = case l of [a, b, c] => (a, b, c) | _ => raise Fail "three: expected exactly three conjuncts";
(* ===== stored inputs ===== *)
val _ = pr "MARK INPUTS";
val RCH = DB.fetch "forge_refundRouteA2" "refund_profile_a_sl_reach";
val GEV = DB.fetch "forge_refundRouteA2b" "ffi_calls_ok_of_valid_events";
val RMF = DB.fetch "forge_refundRouteA2b" "refund_mc_close_fields";
val mc_def = DB.fetch "forge_refundStartupBridge" "refund_mc_def";
val fix_def = DB.fetch "forge_refundStartupClause" "arm8_fix_def";
val NM = DB.fetch "forge_refundEnvModel" "refund_ffi_names_list";
val _ = pr ("INPUT R5 ffi_calls_ok_of_valid_events " ^ thm_to_string GEV);
val _ = pr ("INPUT refund_mc_close_fields " ^ thm_to_string RMF);
(* ===== (a) definitions ===== *)
val _ = pr "MARK DEFS";
val VokY3_def = Define `
  VokY3 i (nb:word8 list) (s:arm8_state) <=>
      (i = 0 ==> s.REG 1w = 8w /\ (!j. j < 8 ==> s.MEM (s.REG 0w + n2w j) = EL j (n2w8 0)) /\
                 w22n [s.MEM (s.REG 2w); s.MEM (s.REG 2w + 1w)] + 4 <= w2n (s.REG 3w) /\ ~word_msb (s.REG 3w)) /\
      (i = 1 ==> s.REG 1w = 8w /\ (!j. j < 8 ==> s.MEM (s.REG 0w + n2w j) = EL j (n2w8 1)) /\
                 w22n [s.MEM (s.REG 2w); s.MEM (s.REG 2w + 1w)] + w22n [s.MEM (s.REG 2w + 2w); s.MEM (s.REG 2w + 3w)] + 4
                   <= w2n (s.REG 3w) /\ ~word_msb (s.REG 3w)) /\
      (i = 2 ==> F) /\ (i = 3 ==> F)`
  handle e => (pr ("DEFINITION_FAILED VokY3 " ^ General.exnMessage e); raise e);
val _ = pr ("DEFINITION " ^ thm_to_string VokY3_def);
val EV_def = Define `
  refund_valid_event e <=>
    (?ab nb. e = IO_event (ExtCall «read») (n2w8 0) (ZIP (ab,nb)) /\ LENGTH ab = 4100 /\ LENGTH nb = LENGTH ab /\
             TAKE 2 ab = n2w2 4096 /\ HD nb = (0w:word8)) \/
    (?ab nb. e = IO_event (ExtCall «write») (n2w8 1) (ZIP (ab,nb)) /\ LENGTH ab = 2052 /\ LENGTH nb = LENGTH ab /\
             w22n [EL 0 ab; EL 1 ab] + w22n [EL 2 ab; EL 3 ab] <= 2048 /\ HD nb = (0w:word8))`
  handle e => (pr ("DEFINITION_FAILED refund_valid_event " ^ General.exnMessage e); raise e);
val _ = pr ("DEFINITION " ^ thm_to_string EV_def);
fun const_of_def d = fst (strip_comb (lhs (snd (strip_forall (concl d)))));
val VokC = const_of_def VokY3_def;
val EvC = const_of_def EV_def;
(* the L2b texts, verbatim (L2b-0003.sml 538-541 and 544-550) *)
val EvLam = ``\e. (?ab nb. e = IO_event (ExtCall «read») (n2w8 0) (ZIP (ab,nb)) /\ LENGTH ab = 4100 /\ LENGTH nb = LENGTH ab /\
                         TAKE 2 ab = n2w2 4096 /\ HD nb = (0w:word8)) \/
                (?ab nb. e = IO_event (ExtCall «write») (n2w8 1) (ZIP (ab,nb)) /\ LENGTH ab = 2052 /\ LENGTH nb = LENGTH ab /\
                         w22n [EL 0 ab; EL 1 ab] + w22n [EL 2 ab; EL 3 ab] <= 2048 /\ HD nb = (0w:word8))``;
val VokLam =
  ``\i (nb:word8 list) (s:arm8_state).
      (i = 0 ==> s.REG 1w = 8w /\ (!j. j < 8 ==> s.MEM (s.REG 0w + n2w j) = EL j (n2w8 0)) /\
                 w22n [s.MEM (s.REG 2w); s.MEM (s.REG 2w + 1w)] + 4 <= w2n (s.REG 3w) /\ ~word_msb (s.REG 3w)) /\
      (i = 1 ==> s.REG 1w = 8w /\ (!j. j < 8 ==> s.MEM (s.REG 0w + n2w j) = EL j (n2w8 1)) /\
                 w22n [s.MEM (s.REG 2w); s.MEM (s.REG 2w + 1w)] + w22n [s.MEM (s.REG 2w + 2w); s.MEM (s.REG 2w + 3w)] + 4
                   <= w2n (s.REG 3w) /\ ~word_msb (s.REG 3w)) /\
      (i = 2 ==> F) /\ (i = 3 ==> F)``;
val VOKLAM = thmA "VokY3_is_the_L2b_lambda" (mk_eq (VokC, VokLam))
  [(simp [FUN_EQ_THM, VokY3_def]),
   (rewrite_tac [FUN_EQ_THM] >> rpt gen_tac >> BETA_TAC >> rewrite_tac [VokY3_def])];
val EVLAM = thmA "refund_valid_event_is_the_L2b_EVc_lambda" (mk_eq (EvC, EvLam))
  [(simp [FUN_EQ_THM, EV_def]),
   (rewrite_tac [FUN_EQ_THM] >> gen_tac >> BETA_TAC >> rewrite_tac [EV_def])];
(* ===== helpers ===== *)
val _ = pr "MARK HELPERS";
val CFLEN = thmA "call_FFI_return_keeps_length"
  ``!(st:'ffi ffi_state) s c ab st' nb. call_FFI st s c ab = FFI_return st' nb ==> LENGTH nb = LENGTH ab``
  [(rw [call_FFI_def] >> every_case_tac >> fs [] >> rw []),
   (rw [call_FFI_def] >> gvs [AllCaseEqs()]),
   (rpt gen_tac >> simp [call_FFI_def] >> rpt (TOP_CASE_TAC >> simp []) >> rw [] >> simp [])];
val ZIPEQ = thmA "zip_equal_lengths_injective"
  ``!(a:'a list) (b:'b list) (a':'a list) (b':'b list).
      LENGTH a = LENGTH b /\ LENGTH a' = LENGTH b' /\ ZIP (a,b) = ZIP (a',b') ==> a = a' /\ b = b'``
  [(rpt gen_tac >> strip_tac >>
    `UNZIP (ZIP (a,b)) = (a,b)` by metis_tac [listTheory.UNZIP_ZIP] >>
    `UNZIP (ZIP (a',b')) = (a',b')` by metis_tac [listTheory.UNZIP_ZIP] >>
    `(a,b) = (a',b')` by metis_tac [] >> fs []),
   (metis_tac [listTheory.UNZIP_ZIP, pairTheory.PAIR_EQ])];
val DIST = thmA "refund_ffi_names_distinct"
  ``«read» <> «write» /\ «write» <> «read» /\ «read» <> «close» /\ «close» <> «read» /\
    «read» <> «open_in» /\ «open_in» <> «read» /\ «write» <> «close» /\ «close» <> «write» /\
    «write» <> «open_in» /\ «open_in» <> «write» /\ «close» <> «open_in» /\ «open_in» <> «close» /\
    «read» <> «» /\ «write» <> «» /\ «close» <> «» /\ «open_in» <> «»``
  [EVAL_TAC, simp [], (rpt conj_tac >> EVAL_TAC)];
val EVC = thmA "close_event_is_not_valid"
  ``!c z. ~refund_valid_event (IO_event (ExtCall «close») c z)``
  [(simp [EV_def, DIST]), (rw [EV_def] >> fs [DIST]),
   (rpt gen_tac >> rewrite_tac [EV_def] >> rpt strip_tac >> fs [DIST])];
val EVO = thmA "open_in_event_is_not_valid"
  ``!c z. ~refund_valid_event (IO_event (ExtCall «open_in») c z)``
  [(simp [EV_def, DIST]), (rw [EV_def] >> fs [DIST]),
   (rpt gen_tac >> rewrite_tac [EV_def] >> rpt strip_tac >> fs [DIST])];
val EVR = thmA "valid_read_event_shape"
  ``!c ab (nb:word8 list). LENGTH nb = LENGTH ab /\ refund_valid_event (IO_event (ExtCall «read») c (ZIP (ab,nb))) ==>
      c = n2w8 0 /\ LENGTH ab = 4100 /\ TAKE 2 ab = n2w2 4096``
  [(rpt gen_tac >> simp [EV_def, DIST] >> rpt strip_tac >> metis_tac [ZIPEQ]),
   (rw [EV_def] >> fs [DIST] >> metis_tac [ZIPEQ]),
   (rpt gen_tac >> rewrite_tac [EV_def] >> rpt strip_tac >> fs [DIST] >> metis_tac [ZIPEQ])];
val EVW = thmA "valid_write_event_shape"
  ``!c ab (nb:word8 list). LENGTH nb = LENGTH ab /\ refund_valid_event (IO_event (ExtCall «write») c (ZIP (ab,nb))) ==>
      c = n2w8 1 /\ LENGTH ab = 2052 /\ w22n [EL 0 ab; EL 1 ab] + w22n [EL 2 ab; EL 3 ab] <= 2048``
  [(rpt gen_tac >> simp [EV_def, DIST] >> rpt strip_tac >> metis_tac [ZIPEQ]),
   (rw [EV_def] >> fs [DIST] >> metis_tac [ZIPEQ]),
   (rpt gen_tac >> rewrite_tac [EV_def] >> rpt strip_tac >> fs [DIST] >> metis_tac [ZIPEQ])];
val NAMES4 = ``[ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»]``;
val EVI = thmA "valid_event_index_and_shape"
  ``!i c ab (nb:word8 list). i < 4 /\ LENGTH nb = LENGTH ab /\
      refund_valid_event (IO_event (EL i ^NAMES4) c (ZIP (ab,nb))) ==>
      (i = 0 /\ c = n2w8 0 /\ LENGTH ab = 4100 /\ TAKE 2 ab = n2w2 4096) \/
      (i = 1 /\ c = n2w8 1 /\ LENGTH ab = 2052 /\ w22n [EL 0 ab; EL 1 ab] + w22n [EL 2 ab; EL 3 ab] <= 2048)``
  [(rpt gen_tac >> strip_tac >>
    `i = 0 \/ i = 1 \/ i = 2 \/ i = 3` by decide_tac >>
    pop_assum (REPEAT_TCL DISJ_CASES_THEN SUBST_ALL_TAC) >>
    RULE_ASSUM_TAC (SIMP_RULE (srw_ss()) []) >>
    FIRST [((disj1_tac >> conj_tac >- REFL_TAC) >> metis_tac [EVR]),
           ((disj2_tac >> conj_tac >- REFL_TAC) >> metis_tac [EVW]),
           (metis_tac [EVC, EVO])]),
   (rpt gen_tac >> strip_tac >>
    `i = 0 \/ i = 1 \/ i = 2 \/ i = 3` by decide_tac >>
    pop_assum (REPEAT_TCL DISJ_CASES_THEN SUBST_ALL_TAC) >>
    fs [EVC, EVO] >> metis_tac [EVR, EVW, listTheory.EL_restricted])];
val WEQ = thmA "word_add_n2w_suc"
  ``!(a:'a word) n. a + n2w (SUC n) = a + 1w + n2w n``
  [(simp [wordsTheory.n2w_SUC, simpLib.AC wordsTheory.WORD_ADD_ASSOC wordsTheory.WORD_ADD_COMM]),
   (rewrite_tac [wordsTheory.n2w_SUC] >> metis_tac [wordsTheory.WORD_ADD_ASSOC, wordsTheory.WORD_ADD_COMM]),
   (rpt gen_tac >> Cases_on `a` >> simp [wordsTheory.word_add_n2w, arithmeticTheory.ADD1] >> AP_TERM_TAC >> decide_tac)];
val RBEL = thmA "read_bytearray_EL"
  ``!n (a:'a word) (g:'a word -> 'b option) bs. read_bytearray a n g = SOME bs ==>
      !j. j < n ==> g (a + n2w j) = SOME (EL j bs)``
  [(Induct
    >- simp []
    >> rpt gen_tac >> simp [read_bytearray_def] >>
       Cases_on `g a` >> simp [] >>
       Cases_on `read_bytearray (a + 1w) n g` >> simp [] >>
       strip_tac >> rveq >> Cases >> simp [wordsTheory.WORD_ADD_0] >>
       strip_tac >>
       first_x_assum (qspecl_then [`a + 1w`, `g`, `x'`] mp_tac) >> simp [] >>
       disch_then (qspec_then `n'` mp_tac) >> simp [] >>
       metis_tac [WEQ]),
   (Induct
    >- simp []
    >> rpt gen_tac >> rewrite_tac [read_bytearray_def] >>
       Cases_on `g a` >> simp [] >>
       Cases_on `read_bytearray (a + 1w) n g` >> simp [] >>
       rpt strip_tac >> rveq >> Cases_on `j` >> fs [wordsTheory.WORD_ADD_0] >>
       `a + n2w (SUC n') = a + 1w + n2w n'` by metis_tac [WEQ] >>
       pop_assum SUBST1_TAC >> metis_tac [])];
val RBEL2 = thmA "read_bytearray_EL_domain"
  ``!n (a:'a word) (P:'a word set) (m:'a word -> 'b) bs.
      read_bytearray a n (\x. if x IN P then SOME (m x) else NONE) = SOME bs ==>
      !j. j < n ==> m (a + n2w j) = EL j bs``
  [(rpt gen_tac >> strip_tac >> gen_tac >> strip_tac >>
    drule RBEL >> disch_then (qspec_then `j` mp_tac) >> simp [] >>
    Cases_on `a + n2w j IN P` >> simp []),
   (rpt strip_tac >> imp_res_tac RBEL >>
    qpat_x_assum `!j. j < n ==> _` (qspec_then `j` mp_tac) >> simp [] >> rw [] >> fs [])];
val RBA = thmA "refund_record_bytearrays"
  ``!mc (ms:arm8_state) c ab.
      mc.target = arm8_target /\ mc.ptr_reg = 0 /\ mc.len_reg = 1 /\ mc.ptr2_reg = 2 /\ mc.len2_reg = 3 /\
      read_ffi_bytearrays mc ms = (SOME c, SOME ab) ==>
      LENGTH c = w2n (ms.REG 1w) /\ LENGTH ab = w2n (ms.REG 3w) /\
      (!j. j < LENGTH c ==> ms.MEM (ms.REG 0w + n2w j) = EL j c) /\
      (!j. j < LENGTH ab ==> ms.MEM (ms.REG 2w + n2w j) = EL j ab)``
  [(rpt gen_tac >> strip_tac >>
    qpat_x_assum `read_ffi_bytearrays _ _ = _` mp_tac >>
    asm_simp_tac (srw_ss()) [read_ffi_bytearrays_def, read_ffi_bytearray_def, arm8_target_def] >>
    strip_tac >> imp_res_tac read_bytearray_LENGTH >> imp_res_tac RBEL2 >>
    rpt conj_tac >> FIRST [first_assum ACCEPT_TAC,
                           (rpt strip_tac >> fs [] >> NO_TAC),
                           (rpt strip_tac >> metis_tac [])]),
   (rpt gen_tac >> strip_tac >>
    qpat_x_assum `read_ffi_bytearrays _ _ = _` mp_tac >>
    asm_simp_tac (srw_ss()) [read_ffi_bytearrays_def, read_ffi_bytearray_def, arm8_target_def] >>
    strip_tac >> imp_res_tac read_bytearray_LENGTH >>
    rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >> rpt strip_tac >>
    imp_res_tac RBEL >> rfs [] >> res_tac >> fs [] >> every_case_tac >> fs [])];
val TK = thmA "first_two_elements_are_take_two"
  ``!(ab:'a list). 2 <= LENGTH ab ==> [EL 0 ab; EL 1 ab] = TAKE 2 ab``
  [(Cases >> simp [] >> Cases_on `t` >> simp []),
   (rpt strip_tac >> Cases_on `ab` >> fs [] >> Cases_on `t` >> fs [])];
(* ===== (b) R4 ===== *)
val _ = pr "MARK R4";
(* goal closers; each closes its goal or fails (FIRST tries the next) *)
val c_acc : tactic = first_assum ACCEPT_TAC;
val c_conf : tactic =
  rpt strip_tac >> qpat_assum `!j. j < LENGTH c ==> _` (qspec_then `j` mp_tac) >>
  qpat_assum `c = _` (fn th => rewrite_tac [th, MarshallingTheory.LENGTH_n2w8]) >>
  disch_then match_mp_tac >> first_assum ACCEPT_TAC >> NO_TAC;
val c3r : tactic =
  qpat_assum `ms1.MEM (ms1.REG 2w) = _` (fn a =>
  qpat_assum `ms1.MEM (ms1.REG 2w + 1w) = _` (fn b =>
  qpat_assum `w22n [EL 0 ab; EL 1 ab] = _` (fn d =>
  qpat_assum `w2n (ms1.REG 3w) = _` (fn e => rewrite_tac [a, b, d, e])))) >> decide_tac >> NO_TAC;
val c3w : tactic =
  qpat_assum `_ <= 2048` mp_tac >>
  qpat_assum `ms1.MEM (ms1.REG 2w) = _` (fn a =>
  qpat_assum `ms1.MEM (ms1.REG 2w + 1w) = _` (fn b =>
  qpat_assum `ms1.MEM (ms1.REG 2w + 2w) = _` (fn f =>
  qpat_assum `ms1.MEM (ms1.REG 2w + 3w) = _` (fn h =>
  qpat_assum `w2n (ms1.REG 3w) = _` (fn e => rewrite_tac [a, b, f, h, e]))))) >> decide_tac >> NO_TAC;
val c_msb : tactic = qpat_assum `ms1.REG 3w = _` (fn th => rewrite_tac [th]) >> EVAL_TAC >> NO_TAC;
val c_fs : tactic = fs [] >> NO_TAC;
val mem_tac : tactic = qpat_assum `!j. j < LENGTH ab ==> _` match_mp_tac >> decide_tac;
val w4096_tac : tactic =
  `[EL 0 ab; EL 1 ab] = TAKE 2 ab` by (match_mp_tac TK >> decide_tac) >>
  pop_assum SUBST1_TAC >> qpat_assum `TAKE 2 ab = _` SUBST1_TAC >>
  FIRST [(EVAL_TAC >> NO_TAC), (simp [MarshallingTheory.w22n_n2w2] >> NO_TAC)];
val unfold_simp : tactic = simp_tac (srw_ss()) [VokY3_def];
val unfold_rw : tactic = rewrite_tac [VokY3_def];
fun rd_tac (unfold : tactic) : tactic =
  rpt gen_tac >> strip_tac >>
  qpat_x_assum `i = 0` SUBST_ALL_TAC >>
  `w2n (ms1.REG 1w) = 8` by metis_tac [MarshallingTheory.LENGTH_n2w8] >>
  `w2n (ms1.REG 3w) = 4100` by metis_tac [] >>
  `ms1.REG 1w = 8w` by metis_tac [wordsTheory.n2w_w2n] >>
  `ms1.REG 3w = 4100w` by metis_tac [wordsTheory.n2w_w2n] >>
  `ms1.MEM (ms1.REG 2w + 0w) = EL 0 ab` by mem_tac >>
  `ms1.MEM (ms1.REG 2w) = EL 0 ab` by metis_tac [wordsTheory.WORD_ADD_0] >>
  `ms1.MEM (ms1.REG 2w + 1w) = EL 1 ab` by mem_tac >>
  `w22n [EL 0 ab; EL 1 ab] = 4096` by w4096_tac >>
  unfold >> rpt conj_tac >> FIRST [c_acc, c_conf, c3r, c_msb, c_fs];
fun wr_tac (unfold : tactic) : tactic =
  rpt gen_tac >> strip_tac >>
  qpat_x_assum `i = 1` SUBST_ALL_TAC >>
  `w2n (ms1.REG 1w) = 8` by metis_tac [MarshallingTheory.LENGTH_n2w8] >>
  `w2n (ms1.REG 3w) = 2052` by metis_tac [] >>
  `ms1.REG 1w = 8w` by metis_tac [wordsTheory.n2w_w2n] >>
  `ms1.REG 3w = 2052w` by metis_tac [wordsTheory.n2w_w2n] >>
  `ms1.MEM (ms1.REG 2w + 0w) = EL 0 ab` by mem_tac >>
  `ms1.MEM (ms1.REG 2w) = EL 0 ab` by metis_tac [wordsTheory.WORD_ADD_0] >>
  `ms1.MEM (ms1.REG 2w + 1w) = EL 1 ab` by mem_tac >>
  `ms1.MEM (ms1.REG 2w + 2w) = EL 2 ab` by mem_tac >>
  `ms1.MEM (ms1.REG 2w + 3w) = EL 3 ab` by mem_tac >>
  unfold >> rpt conj_tac >> FIRST [c_acc, c_conf, c3w, c_msb, c_fs];
val R4R = thmA "valid_read_event_gives_VokY3"
  ``!i (ms1:arm8_state) c ab (nb:word8 list).
      i = 0 /\
      LENGTH c = w2n (ms1.REG 1w) /\ LENGTH ab = w2n (ms1.REG 3w) /\
      (!j. j < LENGTH c ==> ms1.MEM (ms1.REG 0w + n2w j) = EL j c) /\
      (!j. j < LENGTH ab ==> ms1.MEM (ms1.REG 2w + n2w j) = EL j ab) /\
      c = n2w8 0 /\ LENGTH ab = 4100 /\ TAKE 2 ab = n2w2 4096 ==> VokY3 i nb ms1``
  [rd_tac unfold_simp, rd_tac unfold_rw];
val R4W = thmA "valid_write_event_gives_VokY3"
  ``!i (ms1:arm8_state) c ab (nb:word8 list).
      i = 1 /\
      LENGTH c = w2n (ms1.REG 1w) /\ LENGTH ab = w2n (ms1.REG 3w) /\
      (!j. j < LENGTH c ==> ms1.MEM (ms1.REG 0w + n2w j) = EL j c) /\
      (!j. j < LENGTH ab ==> ms1.MEM (ms1.REG 2w + n2w j) = EL j ab) /\
      c = n2w8 1 /\ LENGTH ab = 2052 /\ w22n [EL 0 ab; EL 1 ab] + w22n [EL 2 ab; EL 3 ab] <= 2048 ==>
      VokY3 i nb ms1``
  [wr_tac unfold_simp, wr_tac unfold_rw];
val rd_fin : tactic =
  qspecl_then [`i`, `ms1`, `c`, `ab`, `nb`] mp_tac R4R >>
  impl_tac >- (rpt conj_tac >> first_assum ACCEPT_TAC) >> disch_then ACCEPT_TAC;
val wr_fin : tactic =
  qspecl_then [`i`, `ms1`, `c`, `ab`, `nb`] mp_tac R4W >>
  impl_tac >- (rpt conj_tac >> first_assum ACCEPT_TAC) >> disch_then ACCEPT_TAC;
val R4M_goal =
  ``!mc (ms1:arm8_state) i c ab (nb:word8 list).
      mc.target = arm8_target /\ mc.ptr_reg = 0 /\ mc.len_reg = 1 /\ mc.ptr2_reg = 2 /\ mc.len2_reg = 3 /\
      mc.ffi_names = ^NAMES4 /\ i < 4 /\
      read_ffi_bytearrays mc ms1 = (SOME c, SOME ab) /\ LENGTH nb = LENGTH ab /\
      refund_valid_event (IO_event (EL i mc.ffi_names) c (ZIP (ab,nb))) ==> VokY3 i nb ms1``;
val R4M = thmA "refund_valid_event_gives_VokY3" R4M_goal
  [(rpt gen_tac >> strip_tac >>
    qspecl_then [`i`, `c`, `ab`, `nb`] mp_tac EVI >>
    impl_tac >- (rpt conj_tac >> FIRST [first_assum ACCEPT_TAC,
                                        (qpat_x_assum `mc.ffi_names = _` (fn th => fs [th]) >> NO_TAC),
                                        metis_tac []]) >>
    qspecl_then [`mc`, `ms1`, `c`, `ab`] mp_tac RBA >>
    impl_tac >- (rpt conj_tac >> first_assum ACCEPT_TAC) >>
    rpt strip_tac >> FIRST [CL "R4M-read" rd_fin, CL "R4M-write" wr_fin]),
   (rpt gen_tac >> strip_tac >>
    `(i = 0 /\ c = n2w8 0 /\ LENGTH ab = 4100 /\ TAKE 2 ab = n2w2 4096) \/
     (i = 1 /\ c = n2w8 1 /\ LENGTH ab = 2052 /\ w22n [EL 0 ab; EL 1 ab] + w22n [EL 2 ab; EL 3 ab] <= 2048)` by
       (match_mp_tac EVI >> qexists_tac `nb` >> rfs []) >>
    `LENGTH c = w2n (ms1.REG 1w) /\ LENGTH ab = w2n (ms1.REG 3w) /\
     (!j. j < LENGTH c ==> ms1.MEM (ms1.REG 0w + n2w j) = EL j c) /\
     (!j. j < LENGTH ab ==> ms1.MEM (ms1.REG 2w + n2w j) = EL j ab)` by
       (match_mp_tac RBA >> qexists_tac `mc` >> simp []) >>
    metis_tac [R4R, R4W])];
val RMF2 = thmA "refund_mc_pointer_fields"
  ``!b envmc. (refund_mc b envmc).ptr_reg = 0 /\ (refund_mc b envmc).ptr2_reg = 2``
  [(simp [mc_def, fix_def]),
   (simp [mc_def, fix_def, NM] >> TRY EVAL_TAC),
   (rpt gen_tac >> rewrite_tac [mc_def, fix_def] >> simp [])];
(* ===== structure: terms from the stored theorems ===== *)
val _ = pr "MARK STRUCT";
val VokV = (case List.find (fn v => fst (dest_var v) = "Vok") (free_vars (concl RCH)) of
              SOME v => v | NONE => raise Fail "Vok is not free in refund_profile_a_sl_reach")
  handle e => (pr ("STRUCT_FAILED Vok " ^ General.exnMessage e); raise e);
val RCHY = INST [VokV |-> VokC] RCH;
val (rAnte, rConc) = dest_imp (concl RCHY);
val oldPrems = strip_conj rAnte;
val p3 = (case List.filter (has_const "ffi_calls_ok") oldPrems of
            [p] => p | ps => raise Fail ("premise-3 count " ^ Int.toString (length ps)))
  handle e => (pr ("STRUCT_FAILED p3 " ^ General.exnMessage e); raise e);
val (p3vs, p3body) = strip_forall p3;
val (runeq, callt) = dest_imp p3body;
val (_, cargs) = strip_comb callt;
val mcT = List.nth (cargs, 1);
val ffiT = List.nth (cargs, 2);
val kv = List.nth (cargs, 3);
val msv = List.nth (cargs, 4);
val R5i = ISPECL [VokC, EvC, kv, mcT, ffiT, msv] GEV
  handle e => (pr ("STRUCT_FAILED R5i " ^ General.exnMessage e); raise e);
val (r5a, r5c) = dest_imp (concl R5i);
val (iNames, iEvs, iCalls) = three (strip_conj r5a);
val (jv, evbody) = dest_forall iEvs;
val R6p = list_mk_forall ([msv, jv], mk_imp (runeq, evbody));
val newPrems = map (fn p => if aconv p p3 then R6p else p) oldPrems;
val (rmcC, rmcArgs) = strip_comb mcT;
val (Bt, envT) = (case rmcArgs of [x, y] => (x, y) | _ => raise Fail "refund_mc arguments");
val bV = mk_var ("b", type_of Bt);
val envV = mk_var ("envmc", type_of envT);
val ffiV = mk_var ("ffi", type_of ffiT);
val kV = mk_var ("k", ``:num``);
val msV = mk_var ("ms", type_of msv);
val mcG = list_mk_comb (rmcC, [bV, envV]);
val R5g = ISPECL [VokC, EvC, kV, mcG, ffiV, msV] GEV;
val (gNames, gEvs, gCalls) = three (strip_conj (fst (dest_imp (concl R5g))));
val _ = pr ("L2R_THIRD_PREMISE_WITH_VokY3 " ^ term_to_string p3);
val _ = if aconv r5c callt then pr "CONTROL_OK R5 instance concludes exactly the premise-3 body"
        else bad "R5-instance-conclusion";
(* ===== R4 in the form R5 consumes, and the names premise of R5 ===== *)
val _ = pr "MARK R5-HYPS";
val NAMES = thmA "refund_names_are_nonempty_ExtCall" (list_mk_forall ([bV, envV], gNames))
  [(rpt gen_tac >> simp [RMF] >> strip_tac >>
    `i = 0 \/ i = 1 \/ i = 2 \/ i = 3` by decide_tac >>
    pop_assum (REPEAT_TCL DISJ_CASES_THEN SUBST_ALL_TAC) >> simp [DIST]),
   (rpt gen_tac >> simp [RMF] >> strip_tac >>
    `i = 0 \/ i = 1 \/ i = 2 \/ i = 3` by decide_tac >>
    pop_assum (REPEAT_TCL DISJ_CASES_THEN SUBST_ALL_TAC) >>
    FIRST (map (fn q => qexists_tac q >> EVAL_TAC >> NO_TAC) [`«read»`, `«write»`, `«close»`, `«open_in»`]))];
val R4G = thmA "refund_calls_premise_VokY3" (list_mk_forall ([bV, envV, ffiV], gCalls))
  [(rpt gen_tac >> strip_tac >>
    qspecl_then [`refund_mc b envmc`, `ms1`, `i`, `c`, `ab`, `nb`] mp_tac R4M >>
    impl_tac >- (rpt conj_tac >> FIRST [first_assum ACCEPT_TAC,
                                        (simp [RMF, RMF2] >> NO_TAC),
                                        (fs [RMF] >> NO_TAC),
                                        metis_tac [CFLEN]]) >>
    disch_then ACCEPT_TAC),
   (rpt gen_tac >> strip_tac >> `LENGTH nb = LENGTH ab` by metis_tac [CFLEN] >>
    metis_tac [R4M, RMF, RMF2])];
val _ = if aconv (concl (SPECL [Bt, envT, ffiT] R4G)) iCalls
        then pr "CONTROL_OK R4 instance is term-identical to the third hypothesis of the R5 instance"
        else bad "R4-instance-not-R5-hypothesis";
val _ = if aconv (concl (SPECL [Bt, envT] NAMES)) iNames
        then pr "CONTROL_OK names instance is term-identical to the first hypothesis of the R5 instance"
        else bad "names-instance-not-R5-hypothesis";
(* ===== (d) premise 3 from R6, and the assembly ===== *)
val _ = pr "MARK ASSEMBLY";
fun build_p3l () =
  let val h = ASSUME R6p
      val re = ASSUME runeq
      val evth = GEN jv (MP (SPECL [msv, jv] h) re)
      val nmth = SPECL [Bt, envT] NAMES
      val clth = SPECL [Bt, envT, ffiT] R4G
      val c = MP R5i (LIST_CONJ [nmth, evth, clth])
  in DISCH R6p (GENL [msv, kv] (DISCH runeq c)) end;
val P3L = thmA "refund_events_premise_gives_l2r_third_premise" (mk_imp (R6p, p3))
  [fwd build_p3l,
   (strip_tac >> rpt gen_tac >> strip_tac >>
    match_mp_tac (ISPECL [VokC, EvC] GEV) >> rpt conj_tac >>
    FIRST [MATCH_ACCEPT_TAC NAMES, MATCH_ACCEPT_TAC R4G,
           (gen_tac >> first_x_assum irule >> first_assum ACCEPT_TAC),
           metis_tac []])];
val ASM_goal = mk_imp (list_mk_conj newPrems, rConc);
fun build_asm () =
  let val na = list_mk_conj newPrems
      val cs = CONJUNCTS (ASSUME na)
      fun find p = (case List.find (fn th => aconv (concl th) p) cs of
                      SOME th => th | NONE => raise Fail "assembly: premise not found")
      val th3 = MP P3L (find R6p)
      val olds = map (fn p => if aconv p p3 then th3 else find p) oldPrems
  in DISCH na (MP RCHY (LIST_CONJ olds)) end;
val ASM = thmA "refund_profile_a_sl_events" ASM_goal
  [fwd build_asm,
   (strip_tac >> mp_tac RCHY >> impl_tac
    >- (rpt conj_tac >> FIRST [first_assum ACCEPT_TAC,
                               (mp_tac P3L >> impl_tac >- first_assum ACCEPT_TAC >> disch_then ACCEPT_TAC)])
    >> disch_then ACCEPT_TAC),
   (metis_tac [RCHY, P3L])];
(* ===== (e) controls ===== *)
val _ = pr "MARK CONTROLS";
val NVR = thmA "valid_event_accepts_a_read_event"
  ``refund_valid_event (IO_event (ExtCall «read») (n2w8 0)
       (ZIP (16w::0w::REPLICATE 4098 (0w:word8), REPLICATE 4100 (0w:word8))))``
  [(rewrite_tac [EV_def] >> disj1_tac >>
    qexists_tac `16w::0w::REPLICATE 4098 0w` >> qexists_tac `REPLICATE 4100 0w` >>
    rpt conj_tac >> FIRST [REFL_TAC, (simp [] >> NO_TAC), (EVAL_TAC >> NO_TAC)]),
   (rewrite_tac [EV_def] >> disj1_tac >>
    qexists_tac `16w::0w::REPLICATE 4098 0w` >> qexists_tac `REPLICATE 4100 0w` >> EVAL_TAC)];
val NVW = thmA "valid_event_accepts_a_write_event"
  ``refund_valid_event (IO_event (ExtCall «write») (n2w8 1)
       (ZIP (REPLICATE 2052 (0w:word8), REPLICATE 2052 (0w:word8))))``
  [(rewrite_tac [EV_def] >> disj2_tac >>
    qexists_tac `REPLICATE 2052 0w` >> qexists_tac `REPLICATE 2052 0w` >>
    rpt conj_tac >> FIRST [REFL_TAC, (simp [] >> NO_TAC), (EVAL_TAC >> NO_TAC)]),
   (rewrite_tac [EV_def] >> disj2_tac >>
    qexists_tac `REPLICATE 2052 0w` >> qexists_tac `REPLICATE 2052 0w` >> EVAL_TAC)];
val NEGC = thmA "valid_event_rejects_a_close_event"
  ``~refund_valid_event (IO_event (ExtCall «close») (n2w8 3) (ZIP ([0w:word8], [0w:word8])))``
  [MATCH_ACCEPT_TAC EVC, (simp [EVC]), (metis_tac [EVC])];
(* the N4 witness of L2b-0003 (accepted there by the predicate WITHOUT LENGTH nb = LENGTH ab) *)
val NEGR = thmA "valid_event_rejects_the_N4_short_read_event"
  ``~refund_valid_event (IO_event (ExtCall «read») (n2w8 0) (ZIP (n2w2 4096, [0w:word8; 0w])))``
  [(strip_tac >> qspecl_then [`n2w8 0`, `n2w2 4096`, `[0w; 0w]`] mp_tac EVR >>
    simp [MarshallingTheory.LENGTH_n2w2]),
   (strip_tac >>
    `LENGTH [0w:word8; 0w] = LENGTH (n2w2 4096) /\ LENGTH (n2w2 4096) <> 4100` by
       simp [MarshallingTheory.LENGTH_n2w2] >>
    metis_tac [EVR])];
val _ = thmO "VokY3_rejects_close_and_open_in"
  ``!nb s. ~VokY3 2 nb s /\ ~VokY3 3 nb s``
  [(simp [VokY3_def]), (rw [VokY3_def])];
(* the literal L2b R4 text (STATEMENT_TYPECHECKS R4_valid_event_gives_Vok, L2b-0003 stdout) as a corollary *)
val R4lit_opt =
  (SOME ``!mc (ffi1:(mlstring list # IO_fs) ffi_state) ms1 i c ab ffi2 nb.
      mc.target = arm8_target /\ mc.ptr_reg = 0 /\ mc.len_reg = 1 /\ mc.ptr2_reg = 2 /\ mc.len2_reg = 3 /\
      mc.ffi_names = [ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»] /\ i < 4 /\
      read_ffi_bytearrays mc ms1 = (SOME c, SOME ab) /\ call_FFI ffi1 (EL i mc.ffi_names) c ab = FFI_return ffi2 nb /\
      ^EvLam (IO_event (EL i mc.ffi_names) c (ZIP (ab,nb))) ==> ^VokLam i nb ms1``)
  handle e => (pr ("OPTIONAL_FAILED R4_L2b_literal (statement) " ^ General.exnMessage e); NONE);
val _ = case R4lit_opt of
    SOME R4lit => (thmO "R4_L2b_literal" R4lit
      [(rewrite_tac [GSYM EVLAM, GSYM VOKLAM] >> rpt gen_tac >> strip_tac >>
        qspecl_then [`mc`, `ms1`, `i`, `c`, `ab`, `nb`] mp_tac R4M >>
        impl_tac >- (rpt conj_tac >> FIRST [first_assum ACCEPT_TAC, metis_tac [CFLEN]]) >>
        disch_then ACCEPT_TAC),
       (rewrite_tac [GSYM EVLAM, GSYM VOKLAM] >> rpt strip_tac >>
        `LENGTH nb = LENGTH ab` by metis_tac [CFLEN] >> metis_tac [R4M])]; ())
  | NONE => ();
(* structural checks of the assembly theorem against the stored refund_profile_a_sl_reach *)
val (asmAnte, asmConc) = dest_imp (concl ASM);
val newA = strip_conj asmAnte;
val origConc = snd (dest_imp (concl RCH));
val _ = if aconv asmConc origConc
        then pr "CONTROL_OK ASSEMBLY conclusion is term-identical to the conclusion of the stored refund_profile_a_sl_reach"
        else bad "ASSEMBLY-conclusion";
val _ = if not (free_in VokV origConc) then pr "CONTROL_OK conclusion of refund_profile_a_sl_reach does not mention Vok"
        else bad "conclusion-mentions-Vok";
val _ = if length newA = length oldPrems then pr ("CONTROL_OK ASSEMBLY premise count " ^ Int.toString (length newA))
        else bad "ASSEMBLY-premise-count";
val pairs = ListPair.zip (newA, oldPrems);
val diffs = List.filter (fn (x, y) => not (aconv x y)) pairs;
val _ = (case diffs of
           [(x, y)] => if aconv x R6p andalso aconv y p3
                       then pr "CONTROL_OK ASSEMBLY premises = premises of refund_profile_a_sl_reach with Vok := VokY3, exactly premise 3 replaced by R6"
                       else bad "ASSEMBLY-replaced-premise-is-not-R6-for-p3"
         | _ => bad ("ASSEMBLY-premise-differences-" ^ Int.toString (length diffs)));
val _ = if not (has_const "ffi_calls_ok" asmAnte) then pr "CONTROL_OK ASSEMBLY premises do not mention ffi_calls_ok"
        else bad "ASSEMBLY-ffi_calls_ok";
val _ = if not (has_const "CARD" (concl R4M)) andalso not (has_const "FINITE" (concl R4M)) andalso
           not (has_const "basis_ffi_oracle" (concl R4M)) andalso not (has_const "evaluate" (concl R4M))
        then pr "CONTROL_OK R4 has no domain-size premise (R3 not used), no oracle and no program behaviour"
        else bad "R4-scope";
val _ = if aconv (concl R4M) R4M_goal then pr "CONTROL_OK R4 statement is the literal statement of this file" else bad "R4-literal";
val _ = if List.all is_neg [concl NEGC, concl NEGR] andalso not (is_neg (concl NVR)) andalso not (is_neg (concl NVW))
        then pr "CONTROL_OK two positive events accepted; close event and N4 short read event rejected"
        else bad "event-controls";
val contractPs = List.filter (has_const "refund_ffi_contract_on") newA;
val _ = pr ("REMAINING_PREMISE_R6 " ^ term_to_string R6p);
val _ = List.app (fn t => pr ("REMAINING_PREMISE_CONTRACT " ^ term_to_string t)) contractPs;
val _ = if length contractPs = 1 then pr "CONTROL_OK exactly one contract premise" else bad "contract-premise-count";
val _ = pr ("ASSEMBLY_FREE_VARS " ^ String.concatWith " " (map (fst o dest_var) (free_vars (concl ASM))));
val _ = pr "R3_STATUS NOT_NEEDED: R4 derives ~word_msb (REG 3w) from w2n (REG 3w) = 4100 or 2052 (read_bytearray_LENGTH and the exact array length of a valid event); premise 2 receives VokY3 (with ~word_msb) as its own hypothesis";
(* ===== checks ===== *)
val _ = pr "MARK CHECKS";
val _ = pr ("FAILED_LIST " ^ String.concatWith " " (rev (!failed)));
val _ = pr ("DIAG_OK_UNDER_LIST " ^ String.concatWith " " (rev (!diag)));
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = pr ("PARENTS " ^ String.concatWith " " (Theory.parents "forge_refundRouteA2c"));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundRouteA2c" @ DB.definitions "forge_refundRouteA2c");
val closure = "forge_refundRouteA2c" :: Theory.ancestry "forge_refundRouteA2c";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = if List.exists (fn n => n = "forge_refundRouteA2b") closure andalso List.exists (fn n => n = "forge_refundRouteA2") closure
        then pr "CONTROL_OK closure contains forge_refundRouteA2 and forge_refundRouteA2b" else raise Fail "parents missing";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundRouteA2c")));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions "forge_refundRouteA2c")));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

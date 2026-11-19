(* round12 (worker A37), after R6rx-0001 (stdout.log of attempt-0001/R6rx-0001, read while its last walk was still running).
   Changed against round10: (1) INSTREAM_STR_V_IMP: new structural step list (round10 candidates failed, stdout 192-198);
   (2) refillBuffer_with_read_spec_V: the round10 step 2 "B1 open" ran out of 240 s (stdout 222, 776; in the split walk it
   ran past 13 min without a STEP line); it is cut into eof / xmatch (on the FOLDED precondition) / open / xpull, and the
   read_into call + tail stay one closing step in the PROOF list only; (3) refillBuffer_with_read_spec_STR_V: the PROOF
   list is the round10 one (xapp_spec of the REAL V-spec, then EX_INV); its round10 failure "Could not apply specification"
   (stdout 320, 933) came from the ASSUMEd V-spec (GEN_ALL cannot generalise variables free in the ASSUME hypothesis, so
   is, Inv, p stay fixed); (4) new exploration-only walks. The six closed lemmas and INSTREAM_BUFFERED_FD_V_IMP: unchanged.
   Every new tactic UNCHECKED (none of them ever ran). Round 10 header follows. *)
(* r6r_steps.sml (worker A35, round 10). The ONE file of step lists, read with use by BOTH R6rx-0001.sml (exploration)
   and R6r-0001.sml (proof). Needs r6r_common.sml (read before). Every tactic UNCHECKED (none of them ever ran).
   Method = round9/r6w_steps.sml: a step = (label, main, alternatives); exploration prints goals; the proof takes
   FIRST (main :: alternatives) on the head goal. Source of each copied step list: TextIOProofScript.sml
   (cakeml/basis), line numbers in the comments. Quotations as Q "..." (ASCII only; no backquotes; no $).
   HOL infix rule (HOL src/thm/Overlay.sml lines 9 and 18): THEN, THEN1, \\, >>, >- are ALL "infix" = infixl 0. So
   "a \\ b >- c \\ d" = "((a \\ b) >- c) \\ d". Copied chains are therefore copied WITHOUT added parentheses, and a
   chain is cut into steps only where the original has exactly one goal (after a closing >- or at a branch start).
   Changes against the originals, everywhere: IOFS -> IOFS_V Inv (IOFS_def -> IOFS_V_def), STDIO_def -> STDIO_V_def,
   INSTREAM_STR'_def -> INSTREAM_STRP_V_def, INSTREAM_BUFFERED_FD_def -> INSTREAM_BUFFERED_FD_V_def +
   INSTREAM_BUFFERED_BL_FD_def, specs from the DB (xlet_auto/xapp_spec) -> the explicit V-specs through TH. *)
open preamble cfLib basisFunctionsLib cfLetAutoLib;
open cfHeapsBaseTheory set_sepTheory cfMainTheory cfLetAutoTheory;
open ml_translatorTheory mlstringTheory llistTheory miscTheory alistTheory stringTheory arithmeticTheory
     fsFFITheory fsFFIPropsTheory Word8ArrayProofTheory TextIOProgTheory TextIOProofTheory MarshallingTheory;
fun Q (s : string) : term quotation = [QUOTE s];
val _ = pr "R6R_STEPS opened";
(* the simpset of TextIOProofScript.sml line 13 *)
val _ = (temp_delsimps ["NORMEQ_CONV", "TAKE_LENGTH_ID_rwt2"]; pr "DELSIMPS_OK")
  handle e => pr ("DELSIMPS_FAILED " ^ trunc 300 (General.exnMessage e));
fun closing (t : tactic) : tactic = t \\ NO_TAC;
type step = string * tactic * tactic list;
(* round9/r6w_steps.sml EX_INV, unchanged: after xapp_spec of a REAL V-spec, move existentials of type
   io_event -> bool first and instantiate them with the goal's Inv; on a goal without one it does nothing. *)
val EX_INV : tactic = fn (g as (_, w)) =>
  let val ity = Parse.Type [QUOTE ":io_event -> bool"]
      val (vs, _) = strip_exists w
      fun isi v = type_of v = ity
  in if List.exists isi vs
     then (CONV_TAC (RESORT_EXISTS_CONV (fn l => List.filter isi l @ List.filter (not o isi) l)) \\
           rpt (qexists_tac (Q "Inv"))) g
     else ALL_TAC g
  end;

(* ================= helper lemmas ================= *)
(* read_event_ok_read_into: the H_inv of read_into_spec_V from read_event_ok *)
val ROK_READ_INTO_STEPS : step list =
  [("close", closing (rpt strip_tac \\ fs [read_event_ok_def]),
      [closing (metis_tac [read_event_ok_def]),
       closing (rpt strip_tac \\ rveq \\ fs [read_event_ok_def] \\ first_x_assum irule \\ fs []),
       closing (rw [read_event_ok_def] \\ first_x_assum irule \\ fs [])])];

(* read_event_ok refund_valid_event 0: the read clause of refund_valid_event_def (L2c-0001 stdout 34-44).
   After intro: n = 4096 is eliminated; ASM LENGTH rest = 4096, LENGTH nb = 4 + LENGTH rest, HD nb = 0w.
   unfold: the write disjunct needs ExtCall <<read>> = ExtCall <<write>>, which simp reduces to F. *)
val ROK_REFUND_STEPS : step list =
  [("intro", rw [read_event_ok_def], [simp [read_event_ok_def] \\ rpt strip_tac \\ rveq]),
   ("unfold", simp [RVE_def] \\ TRY disj1_tac, [simp [RVE_def, PULL_EXISTS] \\ TRY disj1_tac, rw [RVE_def]]),
   ("witness", qexists_tac (Q "n2w2 4096 ++ h3::h4::rest") \\ qexists_tac (Q "nb"),
      [qexistsl [Q "n2w2 4096 ++ h3::h4::rest", Q "nb"]]),
   ("close", closing (fs [n2w2_def]),
      [closing (simp [n2w2_def, LENGTH_n2w2] \\ fs []),
       closing (rw [n2w2_def] \\ fs []),
       closing (fs [n2w2_def] \\ EVAL_TAC \\ fs [])])];

(* STD_streams_fd0 (round9 attempt failed twice: R6wx-0002 lines 245-252 and 712-729, "metis: no solution found" in
   step 2 "content"; goal: ASM STD_streams fs, ASM wfFS fs, CONCL get_fd_content fs 0 <> NONE).
   Repair: open STD_streams_def only inside a by (so its existentials are chosen there), get the stdin lookup at fd = 0
   by rewriting with the stdin conjunct (fd = 0, md = ReadMode, off = inp), then specialise the FIRST conjunct of
   wfFS_def (fsFFIPropsScript.sml 221-227) at fd = 0 explicitly. The proof pattern of
   openStdInSetBufferSize_spec_str (TextIOProofScript.sml 6264-6276) is the model. FDOM_alist_to_fmap is [simp]
   (HOL src/finite_maps/alistScript.sml 153); ALOOKUP_NONE (53): ALOOKUP l x = NONE <=> ~MEM x (MAP FST l). *)
val fd0_content =
  Q "?inp. ALOOKUP fs.infds 0 = SOME (UStream \194\171stdin\194\187,ReadMode,inp)" by
    (qpat_x_assum (Q "STD_streams fs") (strip_assume_tac o REWRITE_RULE [STD_streams_def]) \\
     qexists_tac (Q "inp") \\ asm_rewrite_tac []) \\
  pop_assum strip_assume_tac \\
  qpat_x_assum (Q "wfFS fs") (mp_tac o CONJUNCT1 o REWRITE_RULE [wfFS_def]) \\
  disch_then (qspec_then (Q "0") mp_tac) \\
  impl_tac >- (simp [MEM_MAP, EXISTS_PROD] \\ metis_tac [ALOOKUP_MEM]) \\
  strip_tac \\
  Q "ino = UStream \194\171stdin\194\187" by fs [] \\
  rveq \\
  Cases_on (Q "ALOOKUP fs.inode_tbl (UStream \194\171stdin\194\187)") \\
  fs [get_fd_content_def, ALOOKUP_NONE];
val fd0_content_alt =
  Q "?inp. ALOOKUP fs.infds 0 = SOME (UStream \194\171stdin\194\187,ReadMode,inp)" by
    (fs [STD_streams_def] \\ metis_tac []) \\
  pop_assum strip_assume_tac \\
  qpat_x_assum (Q "wfFS fs") (mp_tac o CONJUNCT1 o REWRITE_RULE [wfFS_def]) \\
  disch_then (qspec_then (Q "0") mp_tac) \\
  impl_tac >- (CCONTR_TAC \\ fs [] \\ rfs [GSYM ALOOKUP_NONE]) \\
  strip_tac \\
  Q "ino = UStream \194\171stdin\194\187" by metis_tac [SOME_11, PAIR_EQ] \\
  rveq \\
  simp [get_fd_content_def] \\
  Cases_on (Q "ALOOKUP fs.inode_tbl (UStream \194\171stdin\194\187)") \\ gvs [ALOOKUP_NONE];
val FD0_STEPS : step list =
  [("intro", rpt gen_tac \\ strip_tac \\ conj_tac, []),
   ("content", closing fd0_content, [closing fd0_content_alt, closing (fd0_content \\ gvs [])]),
   ("mode", closing (metis_tac [STD_streams_get_mode]),
      [closing (imp_res_tac STD_streams_get_mode), closing (drule STD_streams_get_mode \\ simp [])])];

(* INSTREAM_STRP_V_F_F: TextIOProofScript.sml 5821-5826 (INSTREAM_STR'_F_F, [local]), proof copied *)
val STRP_FF_STEPS : step list =
  [("close (5825)", closing (gvs [INSTREAM_STRP_V_def, INSTREAM_STR_V_def]),
      [closing (rw [INSTREAM_STRP_V_def, INSTREAM_STR_V_def]),
       closing (simp [FUN_EQ_THM, INSTREAM_STRP_V_def, INSTREAM_STR_V_def])])];

(* weakening lemmas (NEW, optional) *)
val FDV_IMP_STEPS : step list =
  [("close", closing (rw [INSTREAM_BUFFERED_FD_V_def, INSTREAM_BUFFERED_FD_def, INSTREAM_BUFFERED_BL_FD_def] \\
                      xsimpl \\ rw [] \\ metis_tac []),
      [closing (rw [INSTREAM_BUFFERED_FD_V_def, INSTREAM_BUFFERED_FD_def, INSTREAM_BUFFERED_BL_FD_def] \\
                xpull \\ xsimpl \\ rw [] \\ instantiate),
       closing (rw [INSTREAM_BUFFERED_FD_V_def, INSTREAM_BUFFERED_FD_def, INSTREAM_BUFFERED_BL_FD_def,
                    SEP_IMP_def, SEP_EXISTS_THM, cond_STAR] \\ metis_tac [])])];
(* round12: INSTREAM_STR_V_IMP. R6rx-0001 stdout 518-535: goal "!fd is s fs. INSTREAM_STR_V fd is s fs ==>> INSTREAM_STR fd
   is s fs"; round10 candidate 0 "no solution found" (metis), candidate 1 NO_TAC. Repair by structure: both definitions
   (r6r_common.sml INSTREAM_STR_V_def; TextIOProofScript.sml 5773-5780) have the same three SEP_EXISTS (read active left)
   and the same pure conjunct; they differ only in INSTREAM_BUFFERED_FD_V vs INSTREAM_BUFFERED_FD. So:
   SEP_IMP_EXISTS_EXISTS three times (HOL examples/machine-code/hoare-triple/set_sepScript.sml 186), then SEP_IMP_FRAME
   (143) or SEP_IMP_STAR (168), then the closed lemma INSTREAM_BUFFERED_FD_V_IMP (stdout 190, TRY_HELPER_CLOSED). *)
val STRV_IMP_STEPS : step list =
  [("unfold", rpt gen_tac \\ rewrite_tac [INSTREAM_STR_V_def, INSTREAM_STR_def],
      [rpt gen_tac \\ simp_tac bool_ss [INSTREAM_STR_V_def, INSTREAM_STR_def]]),
   ("three SEP_EXISTS", rpt (ho_match_mp_tac SEP_IMP_EXISTS_EXISTS \\ gen_tac \\ BETA_TAC),
      [rpt (irule SEP_IMP_EXISTS_EXISTS \\ gen_tac \\ BETA_TAC)]),
   ("frame, INSTREAM_BUFFERED_FD_V_IMP",
      closing (irule SEP_IMP_FRAME \\ LATE (fn () => MATCH_ACCEPT_TAC (TH "INSTREAM_BUFFERED_FD_V_IMP"))),
      [closing (irule SEP_IMP_STAR \\ rpt conj_tac \\ TRY (MATCH_ACCEPT_TAC SEP_IMP_REFL) \\
                LATE (fn () => MATCH_ACCEPT_TAC (TH "INSTREAM_BUFFERED_FD_V_IMP")))])];
(* ================= read_into_spec_R (corollary of read_into_spec_V) ================= *)
(* pattern = round9 writei_spec_W (R6w-0004 stdout 273-277: step 3 candidate 1 = imp_res_tac, step 4 candidate 0) *)
val READ_INTO_R_STEPS : step list =
  [("intro", rpt strip_tac, []),
   ("H_inv from read_event_ok", LATE (fn () => imp_res_tac (TH "read_event_ok_read_into")),
      [LATE (fn () => drule_all (TH "read_event_ok_read_into")) \\ strip_tac]),
   ("apply read_into_spec_V",
      closing (mp_tac (SPEC_ALL READ_INTO_V_TH) \\ rpt (impl_tac >- (fs [] \\ NO_TAC)) \\ simp []),
      [closing (irule READ_INTO_V_TH \\ fs []),
       closing (mp_tac (SPEC_ALL READ_INTO_V_TH) \\ rpt (impl_tac >- (rw [] \\ fs [] \\ NO_TAC)) \\ simp []),
       closing (metis_tac [READ_INTO_V_TH])])];

(* ================= refillBuffer_with_read_spec_V (TextIOProofScript.sml 2744-2796) ================= *)
fun RI_G () = GEN_ALL (TH "read_into_spec_R");
(* 2745-2748: one goal -> two goals (reverse: branch 1 = ~(pos <= LENGTH content) first) *)
val rf_setup =
  rpt strip_tac
  \\ xcf.xcf_with_def TextIO_refillBuffer_with_read_v_def
  \\ fs [explode_fromI_def, take_fromI_def]
  \\ reverse (Cases_on (Q "pos <= LENGTH content"));
(* branch 1, 2749-2752 (IOFS_def -> IOFS_V_def) *)
val rf1_open =
  imp_res_tac get_fd_content_eof \\ rfs []
  \\ fs [MAX_DEF, MIN_DEF, IOFS_V_def,
         INSTREAM_BUFFERED_BL_FD_def, instream_buffered_inv_def]
  \\ xpull \\ xmatch;
(* both branches, 2753-2755 = 2775-2777 *)
val rf_xlets =
  xlet_auto >- xsimpl
  \\ xlet_auto >- xsimpl
  \\ fs [INSTREAM_def] \\ xlet_auto >- xsimpl;
(* both branches, 2756-2760 = 2778-2782; with LENGTH bcontent = 4100 the nil cases close by fs and LENGTH t = 4096 *)
val rf_split =
  fs [get_in_def] \\ Q "FD fd sv" by fs [FD_def]
  \\ Cases_on (Q "bcontent") \\ fs [] \\ qmatch_goalsub_rename_tac (Q "h1::t")
  \\ Cases_on (Q "t") \\ fs [] \\ qmatch_goalsub_rename_tac (Q "h1::h2::t")
  \\ Cases_on (Q "t") \\ fs [] \\ qmatch_goalsub_rename_tac (Q "h1::h2::h3::t")
  \\ Cases_on (Q "t") \\ fs [] \\ qmatch_goalsub_rename_tac (Q "h1::h2::h3::h4::t");
(* branch 1, 2761 (xlet_auto -> xlet_auto_spec read_into_spec_R) *)
val rf1_call =
  LATE (fn () => xlet_auto_spec (SOME (RI_G ()))) >- xsimpl \\ xsimpl \\ xsimpl;
(* branch 1, 2762-2770 *)
val rf1_tail =
  fs [REF_NUM_def] \\ xpull
  \\ xlet_auto >- xsimpl
  \\ xlet_auto >- xsimpl
  \\ xlet_auto >- xsimpl
  \\ xlet_auto >- xsimpl
  \\ xapp \\ xsimpl
  \\ qexists_tac (Q "4") \\ rpt strip_tac >- fs [NUM_def]
  \\ fs [NUM_def]
  \\ map_every qexists_tac [Q "4"] \\ fs [];
(* branch 2, 2771-2774 *)
val rf2_open =
  imp_res_tac get_fd_content_eof \\ rfs []
  \\ fs [IOFS_V_def,
         INSTREAM_BUFFERED_BL_FD_def, instream_buffered_inv_def]
  \\ xpull \\ xmatch;
(* branch 2, 2783-2784 *)
val rf2_call =
  LATE (fn () => xlet_auto_spec (SOME (RI_G ())))
  >- (xsimpl \\ rpt strip_tac \\ qexists_tac (Q "x") \\ xsimpl) \\ xsimpl;
(* branch 2, 2785-2795 *)
val rf2_tail =
  xlet_auto >- xsimpl
  \\ fs [REF_NUM_def] \\ xpull
  \\ xlet_auto >- xsimpl
  \\ xlet_auto >- xsimpl
  \\ xlet_auto >- xsimpl
  \\ xapp \\ xsimpl \\ fs [NUM_def]
  \\ qexists_tac (Q "&(nr + 4)") \\ fs [] \\ rpt strip_tac
  \\ qabbrev_tac (Q "buff_size = SUC (SUC (SUC (SUC (LENGTH t))))")
  \\ map_every qexists_tac [Q "nr", Q "&(nr+4)"] \\ xsimpl
  \\ fs [integerTheory.INT_SUB_CALCULATE, integerTheory.INT_ADD_CALCULATE]
  \\ fs [MAP_TAKE, TAKE_APPEND1, MAP_DROP, TAKE_TAKE];
(* ---------- round12: refillBuffer_with_read_spec_V, new cut of the round10 steps 2-5 and 6-9 ----------
   Goal before the old step 2 (R6rx-0001 stdout 270-316, branch 1; branch 2 the same with ASM 0 pos <= STRLEN content):
     ASM ~(pos <= STRLEN content); read_event_ok Inv fd; LENGTH bcontent = 4100; get_mode fs fd = SOME ReadMode;
         get_fd_content fs fd = SOME (content,pos); is = Conv (SOME (TypeStamp <<InstreamBuffered>> 15)) [fdv; rr; wr; isbuff]
     CONCL cf_match (Var (Short <<is>>)) [(Pcon .. [Pvar fd; Pvar rref; Pvar wref; Pvar surplus], cf_let ..)]
           (extend_env_rec .. [<<is>>] [Conv ..] (merge_env TextIOProg_env_35 ..))
           (IOFS_V Inv fs * INSTREAM_BUFFERED_BL_FD bcontent bactive fd (Conv ..))
           (POSTv wv. SEP_EXISTS nr h4 rest. &(NUM nr wv /\ 4100 = SUC (SUC (SUC (SUC (LENGTH rest)))) /\ ..) *
              INSTREAM_BUFFERED_BL_FD (0w::..) (TAKE nr (DROP pos ..)) fd (Conv ..) * IOFS_V Inv (bumpFD fd fs nr))
   The old step (2749-2752: imp_res_tac + rfs + fs [MAX_DEF, MIN_DEF, IOFS_V_def, BL_FD_def, inv_def] + xpull + xmatch)
   timed out; the log does not show which part. The stdout "Adding nsLookup representation thms" lines (210-221) come
   after STEP_USED 1, so the old step 2 reached at least one env evaluation. Differences against the original: IOFS_V_def
   opens to IOxV Inv fs * (SEP_EXISTS v. W8ARRAY iobuff_loc v * &(LENGTH v = 2052)) * &wfFS fs (original: IOx .. *
   IOFS_iobuff * &wfFS fs, IOFS_iobuff NOT unfolded there), the extra ASM LENGTH bcontent = 4100 and read_event_ok.
   New cut (each part has its own 240 s): eof fact without goal simplification; xmatch while the precondition is still
   FOLDED (xmatch = xpull_check_not_needed + cf_match unfold + reduce_tac + xcases with asm_simp_tac (srw_ss()),
   cfTacticsLib.sml 600-672; here with 6-7 small assumptions); then the unfold fs and xpull as separate steps. *)
val rf1_eof = Q "eof fd fs = SOME T" by (imp_res_tac get_fd_content_eof \\ fs []);
val rf1_eof_alt = imp_res_tac get_fd_content_eof \\ rfs [];
val rf2_eof = imp_res_tac get_fd_content_eof;
val rf2_eof_alt = imp_res_tac get_fd_content_eof \\ rfs [];
(* xmatch alternative = the original order (unfold, xpull, xmatch); after it the open and xpull steps fall back to
   ALL_TAC (their last alternative), because there is nothing left to open *)
val rf1_xmatch_alt =
  fs [MAX_DEF, MIN_DEF, IOFS_V_def, INSTREAM_BUFFERED_BL_FD_def, instream_buffered_inv_def] \\ xpull \\ xmatch;
val rf2_xmatch_alt =
  fs [IOFS_V_def, INSTREAM_BUFFERED_BL_FD_def, instream_buffered_inv_def] \\ xpull \\ xmatch;
(* open: main = the original fs (opens the precondition AND the postcondition, as the original tail expects);
   alternative = pure rewriting (no arithmetic; the post stays unsimplified) *)
val rf1_unfold = fs [MAX_DEF, MIN_DEF, IOFS_V_def, INSTREAM_BUFFERED_BL_FD_def, instream_buffered_inv_def];
val rf2_unfold = fs [IOFS_V_def, INSTREAM_BUFFERED_BL_FD_def, instream_buffered_inv_def];
val rf_unfold_pure = rewrite_tac [IOFS_V_def, INSTREAM_BUFFERED_BL_FD_def, instream_buffered_inv_def];
(* the three xlets of 2753-2755 (= 2775-2777) as three steps *)
val rf_len = xlet_auto >- xsimpl;
val rf_minus4 = xlet_auto >- xsimpl;
val rf_getin = fs [INSTREAM_def] \\ xlet_auto >- xsimpl;
val rf_getin_alt =
  qpat_x_assum (Q "INSTREAM fd _") (strip_assume_tac o REWRITE_RULE [INSTREAM_def]) \\ rveq \\ (xlet_auto >- xsimpl);
(* NEW: the read_into_spec_R hypotheses n = LENGTH rest and LENGTH rest = 4096 need LENGTH t = 4096 as an assumption
   (bcontent = h1::h2::h3::h4::t, LENGTH bcontent = 4100); the same pattern closed in round9 ("LENGTH t = 2048 (NEW)",
   R6w-0004 stdout 394) *)
val rf_lt = Q "LENGTH t = 4096" by fs [];
val rf_lt_alt = Q "LENGTH t = 4096" by (rveq \\ fs []);
(* tail parts (2762-2770 and 2785-2795), used ONLY in the exploration walk *)
val rf1_t_ref = fs [REF_NUM_def] \\ xpull;
val rf_xl = xlet_auto >- xsimpl;
val rf1_t_xapp = xapp \\ xsimpl;
val rf1_t_close =
  qexists_tac (Q "4") \\ rpt strip_tac >- fs [NUM_def]
  \\ fs [NUM_def]
  \\ map_every qexists_tac [Q "4"] \\ fs [];
val rf2_t_xapp = xapp \\ xsimpl \\ fs [NUM_def];
val rf2_t_close =
  qexists_tac (Q "&(nr + 4)") \\ fs [] \\ rpt strip_tac
  \\ qabbrev_tac (Q "buff_size = SUC (SUC (SUC (SUC (LENGTH t))))")
  \\ map_every qexists_tac [Q "nr", Q "&(nr+4)"] \\ xsimpl
  \\ fs [integerTheory.INT_SUB_CALCULATE, integerTheory.INT_ADD_CALCULATE]
  \\ fs [MAP_TAKE, TAKE_APPEND1, MAP_DROP, TAKE_TAKE];
fun rf_front (b : string) (eof : tactic) (eof_alt : tactic) (xm_alt : tactic) (unf : tactic) : step list =
  [(b ^ " eof fact (" ^ (if b = "B1" then "2749" else "2771") ^ ")", eof, [eof_alt]),
   (b ^ " xmatch, precondition folded", xmatch, [xm_alt]),
   (b ^ " open IOFS_V, BL_FD, inv (" ^ (if b = "B1" then "2750-2751" else "2772-2773") ^ ")", unf,
      [rf_unfold_pure, ALL_TAC]),
   (b ^ " xpull", xpull, [ALL_TAC]),
   (b ^ " Word8Array.length", rf_len, []),
   (b ^ " minus 4", rf_minus4, []),
   (b ^ " get_in", rf_getin, [rf_getin_alt]),
   (b ^ " FD, split bcontent", rf_split, []),
   (b ^ " LENGTH t = 4096 (NEW)", rf_lt, [rf_lt_alt])];
val RF1_FRONT = rf_front "B1" rf1_eof rf1_eof_alt rf1_xmatch_alt rf1_unfold;
val RF2_FRONT = rf_front "B2" rf2_eof rf2_eof_alt rf2_xmatch_alt rf2_unfold;
(* PROOF step list. The call and the tail of each branch stay ONE closing step (original \\ semantics), because the goal
   count after the call is still unknown (no log shows it). *)
val REFILL_V_STEPS : step list =
  [("setup, case split (2745-2748)", rf_setup, [])] @ RF1_FRONT @
  [("B1 read_into_spec_R + tail (2761-2770)", closing (rf1_call \\ rf1_tail),
      [closing (rf1_call \\ rf1_tail \\ fs []),
       closing (LATE (fn () => xlet_auto_spec (SOME (RI_G ()))) >- (xsimpl \\ fs []) \\ xsimpl \\ xsimpl \\ rf1_tail)])] @
  RF2_FRONT @
  [("B2 read_into_spec_R + tail (2783-2795)", closing (rf2_call \\ rf2_tail),
      [closing (rf2_call \\ rf2_tail \\ fs []),
       closing (LATE (fn () => xlet_auto_spec (SOME (RI_G ())))
                >- (xsimpl \\ rpt strip_tac \\ qexists_tac (Q "x") \\ xsimpl \\ fs []) \\ xsimpl \\ rf2_tail)])];
(* EXPLORATION ONLY: the same front, then the call and every tail part as its own step (head-goal semantics; NOT the
   original semantics when a part leaves more than one goal; the printed goal counts show it) *)
val REFILL_V_SPLIT_STEPS : step list =
  [("setup, case split (2745-2748)", rf_setup, [])] @ RF1_FRONT @
  [("B1 read_into_spec_R call only (2761)", rf1_call, []),
   ("B1 REF_NUM, xpull (2762)", rf1_t_ref, []),
   ("B1 xlet 1 (2763)", rf_xl, []),
   ("B1 xlet 2 (2764)", rf_xl, []),
   ("B1 xlet 3 (2765)", rf_xl, []),
   ("B1 xlet 4 (2766)", rf_xl, []),
   ("B1 xapp, xsimpl (2767)", rf1_t_xapp, []),
   ("B1 witness 4, close (2768-2770)", rf1_t_close, [])] @
  RF2_FRONT @
  [("B2 read_into_spec_R call only (2783-2784)", rf2_call, []),
   ("B2 xlet (2785)", rf_xl, []),
   ("B2 REF_NUM, xpull (2786)", rf1_t_ref, []),
   ("B2 xlet 1 (2787)", rf_xl, []),
   ("B2 xlet 2 (2788)", rf_xl, []),
   ("B2 xlet 3 (2789)", rf_xl, []),
   ("B2 xapp, xsimpl, NUM_def (2790)", rf2_t_xapp, []),
   ("B2 witnesses, close (2791-2795)", rf2_t_close, [])];

(* ================= refillBuffer_with_read_spec_STR_V (TextIOProofScript.sml 6832-6869) ================= *)
fun REFILL_V_G () = GEN_ALL (TH "refillBuffer_with_read_spec_V");
(* EXPLORATION ONLY: the V statement ASSUMEd as its universal CLOSURE. The hypothesis then has no free variables, so GEN_ALL
   generalises is, Inv, p, rr, wr, isbuff, bcontent, bactive and xapp_spec can instantiate them. The result carries the
   hypothesis; it is only used in an explore_head walk (goals printed, nothing saved). Never used by the PROOF list. *)
fun REFILL_V_G_CLOSED_ASSUME () =
  GEN_ALL (SPEC_ALL (ASSUME (list_mk_forall (free_vars REFILL_V, REFILL_V))));
(* 6833-6835; strip_tac first (the V statement has the hypothesis read_event_ok Inv fd) *)
val rs_open =
  strip_tac
  \\ simp [Once STDIO_V_def]
  \\ gvs [INSTREAM_STRP_V_def] \\ rw [] \\ xpull \\ gvs []
  \\ gvs [INSTREAM_BUFFERED_FD_V_def, INSTREAM_BUFFERED_BL_FD_def] \\ rw [] \\ xpull \\ gvs [];
(* 6836-6841 (xapp_spec refillBuffer_with_read_spec -> refillBuffer_with_read_spec_V, then EX_INV).
   round12: the same tactic text as round10, written as four parts (rs_xapp = their THEN chain, so the PROOF semantics is
   unchanged); the spec is a parameter, so that the exploration can also use REFILL_V_G_CLOSED_ASSUME.
   Goal before it (R6rx-0001 stdout 905-931): ASM LENGTH bcontent = 4100, instream_buffered_inv r w bcontent [],
   INSTREAM fd fdv, get_mode fs fd = SOME ReadMode, get_fd_content fs fd = SOME (STRCAT read' input,STRLEN read'),
   STD_streams fs, read_event_ok Inv fd; CONCL app p TextIO_refillBuffer_with_read_v [Conv (..) [fdv; rr; wr; buff]]
   (IOFS_V Inv (fs with numchars := ll) * REF_NUM rr r * REF_NUM wr w * W8ARRAY buff bcontent) (POSTv retv. ..).
   The V-spec hypotheses LENGTH bcontent = 4100 and read_event_ok Inv fd are ASM 0 and ASM 6 there, so the
   "rpt (first_assum (irule_at (Pos hd)))" of 6841 can discharge them after EX_INV has fixed Inv. *)
fun rs_p_xapp (specf : unit -> thm) : tactic = LATE (fn () => xapp_spec (specf ()));
val rs_p_exinv = EX_INV;
val rs_p_facts =
  gvs []
  \\ Q ("get_mode (fs with numchars := ll) fd = SOME ReadMode /\\ " ^
        "get_fd_content (fs with numchars := ll) fd = SOME (STRCAT read' input,STRLEN read')")
     by gvs [get_mode_def, get_fd_content_def];
val rs_p_irule = rpt (first_assum (irule_at (Pos hd)));
fun rs_xapp_with (specf : unit -> thm) : tactic = rs_p_xapp specf \\ rs_p_exinv \\ rs_p_facts \\ rs_p_irule;
val rs_xapp = rs_xapp_with REFILL_V_G;
(* 6842-6869, round10 text, written as five parts; rs_rest = r1 \\ r2 \\ r3 >- r4 \\ r5 is the round10 chain
   (THEN and >- are infixl 0, HOL src/thm/Overlay.sml 9 and 18) *)
val rs_r1 =
  gvs [INSTREAM_BUFFERED_BL_FD_def]
  \\ xsimpl \\ gvs [PULL_EXISTS]
  \\ rpt (first_assum (irule_at (Pos hd)));
val rs_r2 =
  qexists_tac (Q "emp") \\ gvs [SEP_CLAUSES]
  \\ gvs [REF_NUM_def] \\ xsimpl \\ rw [];
val rs_r3 = Cases_on (Q "x = 0") \\ gvs [NULL_EQ];
val rs_r4 =
  first_x_assum (irule_at (Pos hd)) \\ rw []
  \\ gvs [bumpFD_0, STDIO_V_def] \\ xsimpl
  \\ qexists_tac (Q "THE (LTL ll)") \\ gvs [] \\ xsimpl;
val rs_r5 =
  drule LESS_EQ_LENGTH \\ strip_tac \\ gvs []
  \\ irule_at Any EQ_REFL
  \\ qsuff_tac (Q ("explode_fromI (STRLEN ys1) (STRCAT (STRCAT read' ys1) ys2) " ^
                   "(STRLEN read') = MAP (n2w o ORD) ys1"))
  >- (rw [] \\ gvs [] \\ first_x_assum (irule_at (Pos hd)) \\ rw []
      \\ gvs [bumpFD_forwardFD, fsFFIPropsTheory.forwardFD_numchars, STDIO_V_def]
      \\ xsimpl \\ qexists_tac (Q "THE (LTL ll)") \\ xsimpl
      \\ DEP_REWRITE_TAC [STD_streams_forwardFD] \\ gvs []
      \\ gvs [get_fd_content_def] \\ PairCases_on (Q "x")
      \\ gvs [get_mode_def]
      \\ gvs [STD_streams_def]
      \\ CCONTR_TAC \\ gvs []
      \\ first_x_assum (qspecl_then [Q "2", Q "WriteMode", Q "STRLEN err"] mp_tac)
      \\ first_x_assum (qspecl_then [Q "1", Q "WriteMode", Q "STRLEN out"] mp_tac)
      \\ gvs [])
  \\ gvs [explode_fromI_def, take_fromI_def]
  \\ Q "STRLEN read' = LENGTH ((MAP (n2w o ORD) read'):word8 list)" by gvs []
  \\ asm_rewrite_tac [DROP_LENGTH_APPEND, listTheory.TAKE_LENGTH_ID_rwt2, GSYM APPEND_ASSOC]
  \\ Q "STRLEN ys1 = LENGTH ((MAP (n2w o ORD) ys1):word8 list)" by simp []
  \\ asm_rewrite_tac [TAKE_LENGTH_APPEND, GSYM APPEND_ASSOC];
val rs_rest = rs_r1 \\ rs_r2 \\ rs_r3 >- rs_r4 \\ rs_r5;
(* PROOF list: as round10 (one closing step after the open, because the goal count after xapp_spec is unknown) *)
val REFILL_STR_V_STEPS : step list =
  [("open STDIO_V, INSTREAM_STRP_V, INSTREAM_BUFFERED_FD_V (6833-6835)", rs_open, []),
   ("xapp refillBuffer_with_read_spec_V + rest (6836-6869)", closing (rs_xapp \\ rs_rest),
      [closing (rs_xapp \\ rs_rest \\ gvs [])])];
(* EXPLORATION ONLY: every part as its own step (head-goal semantics); the spec is a parameter *)
fun rs_split_steps (tag : string) (specf : unit -> thm) : step list =
  [("open (6833-6835)", rs_open, []),
   ("xapp_spec " ^ tag ^ " (6836)", rs_p_xapp specf, []),
   ("EX_INV (NEW)", rs_p_exinv, []),
   ("gvs, mode/content facts (6836-6840)", rs_p_facts, []),
   ("irule_at assumptions (6841)", rs_p_irule, []),
   ("BL_FD open, xsimpl, irule_at (6842-6844)", rs_r1, []),
   ("emp frame, REF_NUM, xsimpl (6845-6846)", rs_r2, []),
   ("case x = 0 (6847)", rs_r3, []),
   ("x = 0 branch (6848-6850)", rs_r4, []),
   ("x <> 0 branch (6851-6869)", rs_r5, [])];
val REFILL_STR_V_SPLIT_STEPS = rs_split_steps "V-spec (real)" REFILL_V_G;
val REFILL_STR_V_CA_STEPS = rs_split_steps "V-spec (closed ASSUME)" REFILL_V_G_CLOSED_ASSUME;

(* ================= the lemma list (order = dependency order; true = required) ================= *)
val R6R_LEMMAS : (string * term * step list * bool) list =
  [("read_event_ok_read_into", ROK_READ_INTO, ROK_READ_INTO_STEPS, true),
   ("read_event_ok_refund", ROK_REFUND, ROK_REFUND_STEPS, true),
   ("STD_streams_fd0", FD0, FD0_STEPS, true),
   ("INSTREAM_STRP_V_F_F", STRP_FF, STRP_FF_STEPS, true),
   ("INSTREAM_BUFFERED_FD_V_IMP", FDV_IMP, FDV_IMP_STEPS, false),
   ("INSTREAM_STR_V_IMP", STRV_IMP, STRV_IMP_STEPS, false),
   ("read_into_spec_R", READ_INTO_R, READ_INTO_R_STEPS, true),
   ("refillBuffer_with_read_spec_V", REFILL_V, REFILL_V_STEPS, true),
   ("refillBuffer_with_read_spec_STR_V", REFILL_STR_V, REFILL_STR_V_STEPS, false)];
(* exploration-only head-goal walks (never stored); r6r_explore_calls.sml (round12) runs them at fixed points *)
val R6R_LATE_LEMMAS = ["refillBuffer_with_read_spec_V", "refillBuffer_with_read_spec_STR_V"];
val R6R_EXPLORE_STR_CA = ("refillBuffer_with_read_spec_STR_V__closedassume", REFILL_STR_V, REFILL_STR_V_CA_STEPS);
val R6R_EXPLORE_V_SPLIT = ("refillBuffer_with_read_spec_V__split", REFILL_V, REFILL_V_SPLIT_STEPS);
val R6R_EXPLORE_STR_SPLIT = ("refillBuffer_with_read_spec_STR_V__split", REFILL_STR_V, REFILL_STR_V_SPLIT_STEPS);
(* frame theorems registered after a save (the [hprop_inj] attribute of the originals): none new in this theory *)
val R6R_HPROP_INJ = [] : string list;
val _ = pr "R6R_STEPS loaded";

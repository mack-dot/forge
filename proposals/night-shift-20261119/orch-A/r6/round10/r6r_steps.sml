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
val STRV_IMP_STEPS : step list =
  [("close", closing (rw [INSTREAM_STR_V_def, INSTREAM_STR_def, INSTREAM_BUFFERED_FD_V_def,
                          INSTREAM_BUFFERED_FD_def, INSTREAM_BUFFERED_BL_FD_def] \\
                      xsimpl \\ rw [] \\ metis_tac []),
      [closing (rw [INSTREAM_STR_V_def, INSTREAM_STR_def, INSTREAM_BUFFERED_FD_V_def,
                    INSTREAM_BUFFERED_FD_def, INSTREAM_BUFFERED_BL_FD_def] \\ xpull \\ xsimpl \\ rw [] \\ instantiate)])];

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
(* PROOF step list: cut only where the original has one goal; the call and the tail of each branch stay ONE closing
   step, because the goal count after "xlet_auto >- xsimpl \\ xsimpl \\ xsimpl" is unknown (the tail applies to all). *)
val REFILL_V_STEPS : step list =
  [("setup, case split (2745-2748)", rf_setup, []),
   ("B1 open (2749-2752; IOFS_V_def)", rf1_open, []),
   ("B1 length, -4, get_in (2753-2755)", rf_xlets, []),
   ("B1 FD, split bcontent (2756-2760)", rf_split, []),
   ("B1 read_into_spec_R + tail (2761-2770)", closing (rf1_call \\ rf1_tail),
      [closing (rf1_call \\ rf1_tail \\ fs []),
       closing (LATE (fn () => xlet_auto_spec (SOME (RI_G ()))) >- (xsimpl \\ fs []) \\ xsimpl \\ xsimpl \\ rf1_tail)]),
   ("B2 open (2771-2774; IOFS_V_def)", rf2_open, []),
   ("B2 length, -4, get_in (2775-2777)", rf_xlets, []),
   ("B2 FD, split bcontent (2778-2782)", rf_split, []),
   ("B2 read_into_spec_R + tail (2783-2795)", closing (rf2_call \\ rf2_tail),
      [closing (rf2_call \\ rf2_tail \\ fs []),
       closing (LATE (fn () => xlet_auto_spec (SOME (RI_G ())))
                >- (xsimpl \\ rpt strip_tac \\ qexists_tac (Q "x") \\ xsimpl \\ fs []) \\ xsimpl \\ rf2_tail)])];
(* EXPLORATION ONLY: the same proof cut after each call, so that the goals after the read_into call are printed.
   Head-goal stepping here is NOT the semantics of the original chain when the call leaves more than one goal. *)
val REFILL_V_SPLIT_STEPS : step list =
  [("setup, case split (2745-2748)", rf_setup, []),
   ("B1 open (2749-2752; IOFS_V_def)", rf1_open, []),
   ("B1 length, -4, get_in (2753-2755)", rf_xlets, []),
   ("B1 FD, split bcontent (2756-2760)", rf_split, []),
   ("B1 read_into_spec_R call only (2761)", rf1_call, []),
   ("B1 tail (2762-2770)", rf1_tail, []),
   ("B2 open (2771-2774; IOFS_V_def)", rf2_open, []),
   ("B2 length, -4, get_in (2775-2777)", rf_xlets, []),
   ("B2 FD, split bcontent (2778-2782)", rf_split, []),
   ("B2 read_into_spec_R call only (2783-2784)", rf2_call, []),
   ("B2 tail (2785-2795)", rf2_tail, [])];

(* ================= refillBuffer_with_read_spec_STR_V (TextIOProofScript.sml 6832-6869) ================= *)
fun REFILL_V_G () = GEN_ALL (TH "refillBuffer_with_read_spec_V");
(* 6833-6835; strip_tac first (the V statement has the hypothesis read_event_ok Inv fd) *)
val rs_open =
  strip_tac
  \\ simp [Once STDIO_V_def]
  \\ gvs [INSTREAM_STRP_V_def] \\ rw [] \\ xpull \\ gvs []
  \\ gvs [INSTREAM_BUFFERED_FD_V_def, INSTREAM_BUFFERED_BL_FD_def] \\ rw [] \\ xpull \\ gvs [];
(* 6836-6841 (xapp_spec refillBuffer_with_read_spec -> refillBuffer_with_read_spec_V, then EX_INV) *)
val rs_xapp =
  LATE (fn () => xapp_spec (REFILL_V_G ())) \\ EX_INV \\ gvs []
  \\ Q ("get_mode (fs with numchars := ll) fd = SOME ReadMode /\\ " ^
        "get_fd_content (fs with numchars := ll) fd = SOME (STRCAT read' input,STRLEN read')")
     by gvs [get_mode_def, get_fd_content_def]
  \\ rpt (first_assum (irule_at (Pos hd)));
(* 6842-6869 *)
val rs_rest =
  gvs [INSTREAM_BUFFERED_BL_FD_def]
  \\ xsimpl \\ gvs [PULL_EXISTS]
  \\ rpt (first_assum (irule_at (Pos hd)))
  \\ qexists_tac (Q "emp") \\ gvs [SEP_CLAUSES]
  \\ gvs [REF_NUM_def] \\ xsimpl \\ rw []
  \\ Cases_on (Q "x = 0") \\ gvs [NULL_EQ]
  >- (first_x_assum (irule_at (Pos hd)) \\ rw []
      \\ gvs [bumpFD_0, STDIO_V_def] \\ xsimpl
      \\ qexists_tac (Q "THE (LTL ll)") \\ gvs [] \\ xsimpl)
  \\ drule LESS_EQ_LENGTH \\ strip_tac \\ gvs []
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
val REFILL_STR_V_STEPS : step list =
  [("open STDIO_V, INSTREAM_STRP_V, INSTREAM_BUFFERED_FD_V (6833-6835)", rs_open, []),
   ("xapp refillBuffer_with_read_spec_V + rest (6836-6869)", closing (rs_xapp \\ rs_rest),
      [closing (rs_xapp \\ rs_rest \\ gvs [])])];
(* EXPLORATION ONLY: cut after the xapp part *)
val REFILL_STR_V_SPLIT_STEPS : step list =
  [("open (6833-6835)", rs_open, []),
   ("xapp refillBuffer_with_read_spec_V (6836-6841)", rs_xapp, []),
   ("rest (6842-6869)", rs_rest, [])];

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
(* exploration-only head-goal walks (never stored) *)
val R6R_EXPLORE_EXTRA : (string * term * step list) list =
  [("refillBuffer_with_read_spec_V__split", REFILL_V, REFILL_V_SPLIT_STEPS),
   ("refillBuffer_with_read_spec_STR_V__split", REFILL_STR_V, REFILL_STR_V_SPLIT_STEPS)];
(* frame theorems registered after a save (the [hprop_inj] attribute of the originals): none new in this theory *)
val R6R_HPROP_INJ = [] : string list;
val _ = pr "R6R_STEPS loaded";

(* round8 changes (after R6wx-0002): EX_INV after each xapp_spec of a REAL V-spec (output_spec_V, output_STDIO_spec_V,
   print_spec_V steps; the round7 tactics kept as alternatives); STD_streams_fd0 removed from R6W_LEMMAS.
   r6w_steps.sml (worker A33, round 7 = round 6 + four repairs after R6wx-0001; every step that passed is unchanged:
   STD_streams_fd0 step 2, write_spec_V old step 2 deleted, output_aux_spec_V new step 10 + changed call step,
   print_spec_refund step 1). Round 6 header follows.
   (round 6:) The ONE file of step lists, read with use by BOTH R6wx-0001.sml (exploration)
   and R6w-0001.sml (proof). Needs r6w_common.sml (read before). Every tactic UNCHECKED (none of them ever ran).
   Method as round5: a step = (label, main, alternatives); exploration prints goals; the proof takes
   FIRST (main :: alternatives) on the head goal. Source of each original step list: TextIOProofScript.sml
   (cakeml/basis), line numbers in the comments. Quotations as Q "..." (ASCII only; no backquotes; no $).
   Changes against the originals, everywhere: IOFS -> IOFS_V Inv, IOx _ -> IOxV _, STDIO -> STDIO_V Inv,
   IOFS_def/IOFS_iobuff_def -> IOFS_V_def, STDIO_def -> STDIO_V_def, specs from the DB (xlet_auto/xapp) -> the
   explicit V-specs through TH (DB.matchp would also find the original specs), SEG_APPEND3 -> SEG_APPEND3_W. *)
open preamble cfLib basisFunctionsLib cfLetAutoLib;
open cfHeapsBaseTheory set_sepTheory cfMainTheory cfLetAutoTheory;
open ml_translatorTheory mlstringTheory llistTheory miscTheory alistTheory stringTheory arithmeticTheory
     fsFFITheory fsFFIPropsTheory Word8ArrayProofTheory TextIOProgTheory TextIOProofTheory MarshallingTheory;
fun Q (s : string) : term quotation = [QUOTE s];
val _ = pr "R6W_STEPS opened";
(* the simpset of TextIOProofScript.sml line 13 *)
val _ = (temp_delsimps ["NORMEQ_CONV", "TAKE_LENGTH_ID_rwt2"]; pr "DELSIMPS_OK")
  handle e => pr ("DELSIMPS_FAILED " ^ trunc 300 (General.exnMessage e));
fun closing (t : tactic) : tactic = t \\ NO_TAC;
type step = string * tactic * tactic list;

(* ================= helper lemmas ================= *)
val WOK_WRITEI_STEPS : step list =
  [("close", closing (rw [write_event_ok_def] \\ first_x_assum irule \\ fs []),
      [closing (metis_tac [write_event_ok_def]),
       closing (rpt strip_tac \\ fs [write_event_ok_def])])];

(* write_event_ok refund_valid_event 1: the write clause of refund_valid_event_def (L2c-0001 stdout 23-44) *)
val WOK_REFUND_STEPS : step list =
  [("intro", rw [write_event_ok_def], [simp [write_event_ok_def] \\ rpt strip_tac]),
   ("nums", Q "n < 2 ** (2 * 8)" by fs [] \\ Q "i < 2 ** (2 * 8)" by fs [] \\ imp_res_tac w22n_n2w2,
      [Q "n < 2 ** (2 * 8)" by (rw [] \\ fs []) \\ Q "i < 2 ** (2 * 8)" by (rw [] \\ fs []) \\ imp_res_tac w22n_n2w2]),
   ("unfold", simp [RVE_def] \\ TRY disj2_tac, [simp [RVE_def, PULL_EXISTS] \\ TRY disj2_tac]),
   ("witness", qexists_tac (Q "n2w2 n ++ n2w2 i ++ rest") \\ qexists_tac (Q "nb"),
      [qexistsl [Q "n2w2 n ++ n2w2 i ++ rest", Q "nb"]]),
   ("close", closing (fs [n2w2_def]),
      [closing (simp [n2w2_def] \\
                Q "w22n [n2w (n DIV 256); n2w n] = n" by metis_tac [w22n_n2w2, n2w2_def] \\
                Q "w22n [n2w (i DIV 256); n2w i] = i" by metis_tac [w22n_n2w2, n2w2_def] \\ simp [])])];

(* TextIOProofScript.sml SEG_APPEND3 (local there), proof copied (one step: the original is one >> chain) *)
val SEG3_STEPS : step list =
  [("all", closing (rpt Induct \\ rw [SEG] >- (last_x_assum (qspec_then (Q "0") mp_tac) \\ simp [SEG_SUC_CONS]) \\
                    fs [ADD_CLAUSES, SEG_SUC_CONS]),
      [closing (rpt Induct \\ rw [SEG] \\ fs [ADD_CLAUSES, SEG_SUC_CONS] \\ TRY (last_x_assum (qspec_then (Q "0") mp_tac) \\
                simp [SEG_SUC_CONS]))])];

(* cfLetAutoScript.sml 274-278 (FFI_PORT_IN_HEAP_LEM, local there) adapted to IOxV *)
val FFIIN_STEPS : step list =
  [("close", closing (rw [IOxV_def, SEP_CLAUSES, SEP_EXISTS_THM, GSYM STAR_ASSOC, one_STAR] \\ metis_tac []),
      [closing (fs [IOxV_def, SEP_CLAUSES, SEP_EXISTS_THM] \\ fs [GSYM STAR_ASSOC, one_STAR] \\ metis_tac []),
       closing (fs [IOxV_def, SEP_EXISTS_THM, STAR_def, one_def, SPLIT_def, cond_def] \\ rw [] \\ fs [IN_DEF] \\
                metis_tac [])])];

(* TextIOProofScript.sml 40-48 (UNIQUE_IOFS): there FRAME_UNIQUE_IO on IO; here NON_OVERLAP_FFI_PART on the FFI parts *)
val UNIQ_STEPS : step list =
  [("unfold", rpt strip_tac \\ fs [IOFS_V_def, GSYM STAR_ASSOC] \\ LATE (fn () => imp_res_tac (TH "IOxV_FFI_part_IN")),
      [rpt strip_tac \\ fs [IOFS_V_def] \\ fs [GSYM STAR_ASSOC] \\ LATE (fn () => imp_res_tac (TH "IOxV_FFI_part_IN"))]),
   ("close", closing (Q "MEM \194\171write\194\187 (MAP FST (SND (SND fs_ffi_part)))" by simp [fs_ffi_part_def] \\
                      metis_tac [NON_OVERLAP_FFI_PART, encode_11]),
      [closing (Q "MEM \194\171write\194\187 (MAP FST (SND (SND fs_ffi_part)))" by EVAL_TAC \\
                drule NON_OVERLAP_FFI_PART \\ metis_tac [encode_11])])];

(* TextIOProofScript.sml 64-71 (IOFS_iobuff_HPROP_INJ); cfLetAutoScript.sml 158-159 (prove_hprop_inj_tac) *)
val HINJ_STEPS : step list =
  [("close", closing (rw [HPROP_INJ_def, GSYM STAR_ASSOC, SEP_CLAUSES, SEP_EXISTS_THM, HCOND_EXTRACT] \\
                      LATE (fn () => metis_tac [TH "UNIQUE_IOFS_V"])),
      [closing (rw [HPROP_INJ_def, GSYM STAR_ASSOC, SEP_CLAUSES, SEP_EXISTS_THM, HCOND_EXTRACT] \\
                EQ_TAC \\ rpt DISCH_TAC \\ fs [] \\ LATE (fn () => metis_tac [TH "UNIQUE_IOFS_V"]))])];

(* TextIOProofScript.sml 106-109 (STDIO_numchars) *)
val NUMCH_STEPS : step list =
  [("close", closing (rw [STDIO_V_def, GSYM STD_streams_numchars]),
      [closing (rw [STDIO_V_def, STD_streams_numchars]), closing (rpt gen_tac \\ simp [STDIO_V_def, STD_streams_numchars])])];

(* TextIOProofScript.sml 118-132 (UNIQUE_STDIO) *)
val USTDIO_STEPS : step list =
  [("close", closing (rw [STDIO_V_def, STD_streams_def, SEP_CLAUSES, SEP_EXISTS_THM, STAR_COMM, STAR_ASSOC, cond_STAR] \\
                      fs [Once STAR_COMM] \\ LATE (fn () => imp_res_tac (TH "UNIQUE_IOFS_V")) \\
                      Cases_on (Q "fs1") \\ Cases_on (Q "fs2") \\ fs [recordtype_IO_fs_seldef_numchars_fupd_def]),
      [closing (rw [STDIO_V_def, SEP_CLAUSES, SEP_EXISTS_THM, cond_STAR] \\ fs [Once STAR_COMM] \\
                fs [GSYM STAR_ASSOC] \\ LATE (fn () => imp_res_tac (TH "UNIQUE_IOFS_V")) \\
                fs [IO_fs_component_equality])])];

(* TextIOProofScript.sml 135-163 (STDIO_HPROP_INJ), copied; IOFS -> IOFS_V _, UNIQUE_STDIO -> UNIQUE_STDIO_V *)
fun shinj_branch () : tactic =
  fs [STDIO_V_def, STD_streams_def, STAR_def, SEP_EXISTS, cond_def] \\
  qmatch_assum_rename_tac (Q "IOFS_V _ (fs2 with numchars := ll) u1") \\
  qmatch_assum_rename_tac (Q "SPLIT u0 (u1, _)") \\
  qmatch_assum_rename_tac (Q "SPLIT s (u0, v0)") \\
  qexists_tac (Q "u0") \\ qexists_tac (Q "v0") \\ fs [] \\
  qexists_tac (Q "u1") \\ fs [PULL_EXISTS] \\ qexists_tac (Q "ll") \\ fs [] \\
  Cases_on (Q "fs1") \\ Cases_on (Q "fs2") \\ fs [recordtype_IO_fs_seldef_numchars_fupd_def] \\
  metis_tac [];
fun shinj_branch2 () : tactic =
  fs [STDIO_V_def, STD_streams_def, STAR_def, SEP_EXISTS, cond_def] \\
  qmatch_assum_rename_tac (Q "IOFS_V _ (fs1 with numchars := ll) u1") \\
  qmatch_assum_rename_tac (Q "SPLIT u0 (u1, _)") \\
  qmatch_assum_rename_tac (Q "SPLIT s (u0, v0)") \\
  qexists_tac (Q "u0") \\ qexists_tac (Q "v0") \\ fs [] \\
  qexists_tac (Q "u1") \\ fs [PULL_EXISTS] \\ qexists_tac (Q "ll") \\ fs [] \\
  Cases_on (Q "fs1") \\ Cases_on (Q "fs2") \\ fs [recordtype_IO_fs_seldef_numchars_fupd_def] \\
  metis_tac [];
val SHINJ_STEPS : step list =
  [("split", rpt gen_tac \\ rw [HPROP_INJ_def, GSYM STAR_ASSOC, SEP_CLAUSES, SEP_EXISTS_THM, HCOND_EXTRACT] \\
             EQ_TAC \\ rpt DISCH_TAC, []),
   ("=> (lines 141-153)",
      closing (LATE (fn () => mp_tac (TH "UNIQUE_STDIO_V")) \\ disch_then drule \\ strip_tac \\
               first_x_assum (qspecl_then [Q "fs1", Q "fs2"] mp_tac) \\
               rpt (disch_then drule) \\ fs [cond_def] \\ rw [] \\ LATE shinj_branch),
      [closing (LATE (fn () => mp_tac (TH "UNIQUE_STDIO_V")) \\ disch_then drule \\ strip_tac \\
                first_x_assum (qspecl_then [Q "fs1", Q "fs2"] mp_tac) \\
                rpt (disch_then drule) \\ fs [cond_def] \\ rw [] \\ fs [] \\ LATE shinj_branch)]),
   ("<= (lines 154-162)", closing (LATE shinj_branch2), [closing (rw [] \\ LATE shinj_branch2)])];

(* NEW (read side, Orchestrator A note): descriptor 0 has content and ReadMode under wfFS and STD_streams
   (STD_streams_def fsFFIPropsScript.sml 1314; STD_streams_get_mode 1527; wfFS_def 221-227) *)
val FD0_STEPS : step list =
  [("intro", rpt gen_tac \\ strip_tac \\ conj_tac, []),
   (* round7: R6wx-0001 line 523: the old main failed in DISCH_THEN (first_x_assum picked the wrong forall);
      alt 1 metis: no solution. New: open wfFS only by SIMP_RULE std_ss and take its first conjunct at fd = 0. *)
   ("content",
      closing (fs [STD_streams_def] \\
               Q "ALOOKUP fs.infds 0 = SOME (UStream \194\171stdin\194\187, ReadMode, inp)" by metis_tac [] \\
               strip_tac \\ fs [get_fd_content_def, ALOOKUP_NONE] \\
               qpat_x_assum (Q "wfFS fs") (mp_tac o SIMP_RULE std_ss [wfFS_def]) \\
               disch_then (qspec_then (Q "0") mp_tac o CONJUNCT1) \\
               (impl_tac >- (simp [MEM_MAP, EXISTS_PROD] \\ metis_tac [ALOOKUP_MEM])) \\
               strip_tac \\ fs []),
      [closing (fs [STD_streams_def] \\
                Q "ALOOKUP fs.infds 0 = SOME (UStream \194\171stdin\194\187, ReadMode, inp)" by metis_tac [] \\
                strip_tac \\ fs [get_fd_content_def, ALOOKUP_NONE] \\
                qpat_x_assum (Q "wfFS fs") (mp_tac o SIMP_RULE std_ss [wfFS_def]) \\
                disch_then (qspec_then (Q "0") mp_tac o CONJUNCT1) \\
                simp [MEM_MAP, EXISTS_PROD] \\ rpt strip_tac \\ rfs [] \\ metis_tac [ALOOKUP_MEM, SOME_11, PAIR_EQ])]),
   ("mode", closing (metis_tac [STD_streams_get_mode]), [closing (imp_res_tac STD_streams_get_mode)])];

(* ================= writei_spec_W (corollary of writei_spec_V) ================= *)
val WRITEI_W_STEPS : step list =
  [("intro", rpt strip_tac, []),
   ("bound", Q "i + n <= 2048" by fs [MAX_LE], [Q "i + n <= 2048" by (fs [MAX_DEF] \\ rw [] \\ fs [])]),
   ("H_inv from write_event_ok", LATE (fn () => drule_all (TH "write_event_ok_writei")) \\ strip_tac,
      [LATE (fn () => imp_res_tac (TH "write_event_ok_writei"))]),
   ("apply writei_spec_V", closing (mp_tac WRITEI_V_TH \\ rpt (impl_tac >- (fs [] \\ NO_TAC)) \\ simp []),
      [closing (metis_tac [WRITEI_V_TH]),
       closing (irule WRITEI_V_TH \\ fs [])])];

(* ================= write_spec_V (TextIOProofScript.sml 1567-1606) ================= *)
(* lines 1576-1578, IOFS_def/IOFS_iobuff_def -> IOFS_V_def; LENGTH bc = 2052 follows from LENGTH rest = 2048 *)
val w_zero =
  TRY instantiate \\ xcon \\
  simp [IOFS_V_def] \\ xsimpl \\ qexists_tac (Q "0") \\
  fs [fsupdate_unchanged, insert_atI_def] \\ xsimpl;
(* lines 1568-1578 as ONE step (the original applies the xcf/xif part to both induction goals) *)
val w_setup =
  strip_tac \\ Q "?N. n <= N" by (qexists_tac (Q "n") \\ fs []) \\
  FIRST_X_ASSUM MP_TAC \\ qid_spec_tac (Q "n") \\
  Induct_on (Q "N") \\
  rpt strip_tac \\
  xcf.xcf_with_def TextIO_write_v_def \\
  (((xlet_auto >- xsimpl) \\ xif) >- w_zero);
fun WRITEI_W_G () = GEN_ALL (TH "writei_spec_W");
(* lines 1579-1580: the writei call; NEW: the spec is writei_spec_W, given explicitly *)
val w_writei =
  ((LATE (fn () => xlet_auto_spec (SOME (WRITEI_W_G ()))) \\ xsimpl) >-
   (simp [] \\ xsimpl \\ rw [] \\ instantiate \\ xsimpl));
val w_writei_alt =
  ((LATE (fn () => xlet_auto_spec (SOME (WRITEI_W_G ()))) \\ xsimpl) >-
   (simp [] \\ xsimpl \\ rw [] \\ TRY instantiate \\ TRY xsimpl \\ fs [MAX_LE]));
(* lines 1581-1587 *)
val w_done =
  reverse xif >-
  (xcon \\ xsimpl \\ fs [IOFS_V_def] \\ xsimpl \\
   qexists_tac (Q "(Lnext_pos fs.numchars + 1)") \\ Q "nw = n" by fs [] \\ xsimpl \\
   imp_res_tac get_fd_content_validFD \\
   fs [wfFS_fsupdate, validFD_def, always_DROP, AFUPDKEY_ALOOKUP,
       liveFS_fsupdate, get_fd_content_def, LENGTH_n2w2]);
val w_done_alt =
  reverse xif >-
  (xcon \\ xsimpl \\ fs [IOFS_V_def] \\ xsimpl \\
   qexists_tac (Q "(Lnext_pos fs.numchars + 1)") \\ Q "nw = n" by fs [] \\ xsimpl \\
   imp_res_tac get_fd_content_validFD \\
   fs [wfFS_fsupdate, validFD_def, always_DROP, AFUPDKEY_ALOOKUP,
       liveFS_fsupdate, get_fd_content_def, LENGTH_n2w2] \\ rw [] \\ fs [LENGTH_n2w2]);
(* lines 1588-1594 *)
val w_ih =
  qmatch_goalsub_abbrev_tac (Q "IOxV _ fs'") \\
  Q "n - nw <= N" by fs [] \\
  FIRST_X_ASSUM (ASSUME_TAC o Q.SPECL [Q "n-nw"]) \\ rfs [] \\
  FIRST_X_ASSUM (ASSUME_TAC o Q.SPECL [Q "fs'", Q "fd", Q "nw + i", Q "pos+nw"]) \\
  FIRST_X_ASSUM xapp_spec \\ xsimpl \\ fs [n2w2_def] \\
  qexists_tac (Q "insert_atI (TAKE nw (MAP (CHR o w2n) (DROP i rest))) pos content");
(* lines 1595-1601 *)
val w_side1 =
  imp_res_tac get_fd_content_validFD \\
  fs [Abbr (Q "fs'"), liveFS_def, live_numchars_def, LDROP_1, wfFS_fsupdate, validFD_def,
      always_DROP, AFUPDKEY_ALOOKUP, get_fd_content_def, get_mode_def] \\
  pairarg_tac \\ fs [fsupdate_def, always_DROP, AFUPDKEY_ALOOKUP] \\
  imp_res_tac NOT_LFINITE_DROP \\
  FIRST_X_ASSUM (ASSUME_TAC o Q.SPEC (Q "(Lnext_pos fs.numchars + 1)")) \\
  fs [] \\ imp_res_tac NOT_LFINITE_DROP_LFINITE;
val w_sides = NTAC 3 (strip_tac >- w_side1);
(* lines 1602-1606 *)
val w_final =
  rw [] \\ qexists_tac (Q "Lnext_pos fs.numchars + 1 + x") \\
  fs [wfFS_def, fsupdate_o, Abbr (Q "fs'"), insert_atI_insert_atI] \\
  qmatch_abbrev_tac (Q "_ (_ _ _ _ _ (_ c1 _ _)) ==>> _ (_ _ _ _ _ (_ c2 _ _)) * _") \\
  Q "c1 = c2" suffices_by xsimpl \\ fs [Abbr (Q "c1"), Abbr (Q "c2")] \\
  PURE_REWRITE_TAC [Once (Q.SPECL [Q "i", Q "nw"] ADD_COMM)] \\
  fs [Once ADD_COMM, GSYM DROP_DROP_T, take_drop_partition, MAP_DROP];
val WRITE_STEPS : step list =
  [("setup+n=0 (1568-1578)", w_setup, []),
   (* round7: old step 2 "base case, n <> 0 branch" DELETED. R6wx-0001 line 764: step 1 leaves ONE goal, the
      induction STEP case (ASM 13 n <= SUC N, ASM 14 the IH, ASM 0 n <> 0, ASM 1 BOOL (n = 0) bv); the base case
      was already closed inside step 1. *)
   ("writei call (1579-1580, writei_spec_W)", w_writei, [w_writei_alt]),
   ("nw < n test (1581)", xlet_auto >- xsimpl, []),
   ("done branch (1581-1587)", w_done, [w_done_alt]),
   ("n-nw, i+nw (1588)", NTAC 2 (xlet_auto >- xsimpl), []),
   ("IH (1589-1594)", w_ih, [w_ih \\ fs []]),
   ("IH side conditions (1595-1601)", w_sides,
      [fs [] \\ w_sides, NTAC 3 (strip_tac >- (fs [] \\ NO_TAC ORELSE w_side1))]),
   ("final (1602-1606)", closing w_final, [closing (w_final \\ rw [] \\ fs [])])];

(* ================= output_aux_spec_V (TextIOProofScript.sml 1743-1815) ================= *)
val oa_done =
  xcon \\ xsimpl \\ sg (Q "z = i") >- fs [] \\ simp [] \\
  qexists (Q "0") \\ simp [Req0 fsupdate_unchanged, insert_atI_NIL] \\ xsimpl;
val oa_done_alt =
  xcon \\ xsimpl \\ Q "z = i" by fs [] \\ rveq \\
  qexists_tac (Q "0") \\ simp [fsupdate_unchanged, insert_atI_NIL] \\ xsimpl;
val oa_min =
  xlet (Q "POSTv nv. &NUM (MIN (z:num - i) 2048) nv * IOFS_V Inv fs") >-
  (xif >- (xvar \\ xsimpl \\ fs [MIN_DEF, NUM_def, INT_def]) \\ xlit \\ xsimpl \\ fs [MIN_DEF]);
fun WRITE_V_G () = GEN_ALL (TH "write_spec_V");
val oa_xapp =
  xapp \\
  qpat_assum (Q "NUM _ _") (irule_at Any) \\
  qpat_assum (Q "NUM _ _") (irule_at Any) \\
  qpat_assum (Q "z <= strlen s") (irule_at Any) \\
  simp [] \\
  qmatch_goalsub_abbrev_tac (Q "IOFS_V _ fs'") \\
  sg (Q "get_mode fs' fd = SOME WriteMode") >- simp [Abbr (Q "fs'")] \\
  qpat_assum (Q "get_mode fs' fd = _") (irule_at Any) \\
  simp [Abbr (Q "fs'")] \\
  irule_at Any get_fd_content_fsupdate \\ simp [] \\
  xsimpl;
val oa_post =
  rpt strip_tac \\
  qmatch_goalsub_abbrev_tac (Q "fsupdate (fsupdate _ _ _ (pos + off) _) _") \\
  sg (Q "liveFS fs") >- fs [wfFS_def] \\
  drule_then assume_tac fsupdate_o \\ simp [] \\
  qmatch_goalsub_abbrev_tac (Q "insert_atI sfx _ (insert_atI pfx _ _)") \\
  sg (Q "off + pos = pos + STRLEN pfx") >- simp [Abbr (Q "off"), Abbr (Q "pfx"), LENGTH_TAKE_EQ, strlen_substring] \\
  simp [Req0 insert_atI_insert_atI];
val oa_pfx =
  sg (Q "pfx ++ sfx = explode (substring s i (z - i))") >-
  (simp [Abbr (Q "pfx"), Abbr (Q "sfx")] \\
   simp [MAP_MAP_o, CHR_w2n_n2w_ORD, TAKE_APPEND] \\
   namedCases_on (Q "s") ["l"] \\ simp [substring_def] \\
   IF_CASES_TAC \\ gvs [] >-
   (sg (Q "LENGTH (SEG off i l) = off") >- simp [LENGTH_SEG] \\
    simp [TAKE_SEG, SEG_SEG, SEG] \\
    LATE (fn () => irule (TH "SEG_APPEND3_W")) \\
    simp [Abbr (Q "off")]) \\
   fs [Abbr (Q "off")]);
val oa_close =
  simp [] \\
  qmatch_goalsub_abbrev_tac (Q "IOFS_V _ (fsupdate fs fd k' _ _)") \\
  qexists (Q "k'") \\ xsimpl;
val OUTPUT_AUX_STEPS : step list =
  [("induct (1743)", completeInduct_on (Q "z:num - i") \\ rw [], []),
   ("xcf, z <= i test, xif (1744-1746)", xcf.xcf_with_def TextIO_output_aux_v_def \\ (xlet_auto >- xsimpl) \\ xif, []),
   ("done branch (1747-1753)", closing oa_done, [closing oa_done_alt]),
   ("left, n (1754-1755)", (xlet_auto >- xsimpl) \\ (xlet_auto >- xsimpl), []),
   ("xlet MIN (1756-1760; IOFS -> IOFS_V Inv)", oa_min,
      [xlet (Q "POSTv nv. &NUM (MIN (z:num - i) 2048) nv * IOFS_V Inv fs") >-
       (xif >- (xvar \\ xsimpl \\ fs [MIN_DEF, NUM_def, INT_def] \\ rw [] \\ fs []) \\ xlit \\ xsimpl \\ fs [MIN_DEF] \\ rw [])]),
   ("open IOFS_V in the precondition (1766-1767)", rewrite_tac [Once IOFS_V_def] \\ xpull \\ rename1 (Q "W8ARRAY _ buff"),
      [qpat_abbrev_tac (Q "Q = $POSTv _") \\ simp [IOFS_V_def] \\ xpull \\ qunabbrev_tac (Q "Q") \\
       rename1 (Q "W8ARRAY _ buff")]),
   ("copyVec (1768)", xlet_auto >- xsimpl, []),
   ("get_out (1769-1770)", drule (iffLR OUTSTREAM_def) \\ strip_tac \\ (xlet_auto >- xsimpl), []),
   ("buff split (1772-1773)",
      sg (Q "?h1 h2 h3 h4 t. buff = h1::h2::h3::h4::t") >-
        ntac 4 (Cases_on (Q "buff") \\ fs [] \\ rename1 (Q "buff = _::_")),
      [sg (Q "?h1 h2 h3 h4 t. buff = h1::h2::h3::h4::t") >-
         (ntac 4 (Cases_on (Q "buff") \\ fs [] \\ rename1 (Q "buff = _::_")) \\ fs [])]),
   (* round7 NEW: LENGTH t = 2048 from ASM buff = h1::h2::h3::h4::t and ASM LENGTH buff = 2052 (IOFS_V pins it);
      with it LENGTH rest = 2048 for rest = MAP (n2w o ORD) (explode (substring s i N)) ++ DROP N t (+ LENGTH_DROP) *)
   ("LENGTH t = 2048 (NEW)", Q "LENGTH t = 2048" by fs [], [Q "LENGTH t = 2048" by (rveq \\ fs [])]),
   (* round7: R6wx-0001 line 1673 failed in MP_ASSUML ("Could not find the hypothesis: !n fs fd ...") because
      write_spec_V was an ASSUME there (exploration artifact). The side tactic now also closes LENGTH rest = 2048. *)
   ("write call (1774-1775; write_spec_V; side condition LENGTH rest = 2048)",
      LATE (fn () => xlet_auto_spec (SOME (WRITE_V_G ()))) >-
        (xsimpl \\ fs [strlen_substring, FD_def, get_out_def] \\ rw [] \\
         fs [LENGTH_explode, strlen_substring] \\ rw [] \\ fs []),
      [LATE (fn () => xlet_auto_spec (SOME (WRITE_V_G ()))) >-
         (xsimpl \\ fs [strlen_substring, FD_def, get_out_def, LENGTH_explode, MIN_DEF] \\ rw [] \\ fs [])]),
   ("i + n (1776)", xlet_auto >- xsimpl, []),
   ("recursive call (1777-1789)", oa_xapp, [oa_xapp \\ fs []]),
   ("post: fsupdate_o, insert_atI (1790-1798)", oa_post, [oa_post \\ fs []]),
   ("pfx ++ sfx (1799-1810; SEG_APPEND3_W)", oa_pfx, []),
   ("close (1811-1814)", closing oa_close, [closing (oa_close \\ rw [] \\ fs [])])];

(* ================= output_spec_V (TextIOProofScript.sml 1826-1835) ================= *)
fun OUTPUT_AUX_V_G () = GEN_ALL (TH "output_aux_spec_V");
(* round8 EX_INV: with a REAL V-spec, irule/irule_ecc (IRULE_CANON = GEN_ALL, HOL Drule.sml 2229) also generalises
   the free Inv, which can then stay as an outer existential of type io_event -> bool (with the ASSUMEd spec of
   R6wx-0001 Inv was fixed by the hypothesis, and the step closed). EX_INV moves such existentials first and
   instantiates them with the goal's Inv; on a goal without one it does nothing. UNCHECKED diagnosis. *)
val EX_INV : tactic = fn (g as (_, w)) =>
  let val ity = Parse.Type [QUOTE ":io_event -> bool"]
      val (vs, _) = strip_exists w
      fun isi v = type_of v = ity
  in if List.exists isi vs
     then (CONV_TAC (RESORT_EXISTS_CONV (fn l => List.filter isi l @ List.filter (not o isi) l)) \
           rpt (qexists_tac (Q "Inv"))) g
     else ALL_TAC g
  end;
val o_app_r8 =
  LATE (fn () => xapp_spec (OUTPUT_AUX_V_G ())) \\ EX_INV \\
  qpat_assum (Q "get_fd_content _ _ = _") (irule_at Any) \\
  qpat_assum (Q "NUM _ nv") (irule_at Any) \\
  qexistsl [Q "s", Q "0"] \\ simp [] \\ EX_INV \\ xsimpl;
val o_app =
  LATE (fn () => xapp_spec (OUTPUT_AUX_V_G ())) \\
  qpat_assum (Q "get_fd_content _ _ = _") (irule_at Any) \\
  qpat_assum (Q "NUM _ nv") (irule_at Any) \\
  qexistsl [Q "s", Q "0"] \\ simp [] \\ xsimpl;
val OUTPUT_STEPS : step list =
  [("xcf, size (1826-1829)", rw [] \\ xcf.xcf_with_def TextIO_output_v_def \\ (xlet_auto >- xsimpl), []),
   ("call output_aux_spec_V (1830-1835)", closing o_app_r8, [closing o_app, closing (o_app \\ fs [])])];

(* ================= output_STDIO_spec_V (TextIOProofScript.sml 1844-1866) ================= *)
fun OUTPUT_V_G () = GEN_ALL (TH "output_spec_V");
val os_app_r8 =
  LATE (fn () => xapp_spec (OUTPUT_V_G ())) \\ EX_INV \\
  first_x_assum (assume_tac o CONV_RULE (LAND_CONV (REWR_CONV get_fd_content_numchars))) \\
  first_x_assum (assume_tac o CONV_RULE (LAND_CONV (REWR_CONV (SYM get_mode_with_numchars)))) \\
  instantiate \\ xsimpl;
val os_app =
  LATE (fn () => xapp_spec (OUTPUT_V_G ())) \\
  first_x_assum (assume_tac o CONV_RULE (LAND_CONV (REWR_CONV get_fd_content_numchars))) \\
  first_x_assum (assume_tac o CONV_RULE (LAND_CONV (REWR_CONV (SYM get_mode_with_numchars)))) \\
  instantiate \\ xsimpl;
fun os_tail () : tactic =
  fs [get_fd_content_def] \\
  simp [Once fsupdate_0_numchars, SimpR (Parse.Term (Q "$/\\"))] \\
  simp [fsupdate_numchars] \\
  rw [] \\
  qmatch_goalsub_abbrev_tac (Q "_ with numchars := ns") \\
  qexists_tac (Q "ns") \\ xsimpl \\
  DEP_REWRITE_TAC [STD_streams_fsupdate] \\ fs [] \\
  pairarg_tac \\ fs [] \\ rveq \\
  Q "fd = 1 \\/ fd = 2 ==> off = LENGTH content" by
    (fs [STD_streams_def] \\ metis_tac [SOME_11, PAIR, FST, SND]) \\
  rw [] \\ fs [] \\ simp [insert_atI_end, LENGTH_explode];
val OUTPUT_STDIO_STEPS : step list =
  [("unfold STDIO_V (1845-1847)", rpt strip_tac \\ fs [STDIO_V_def] \\ xpull, []),
   ("call output_spec_V (1848-1851)", os_app_r8, [os_app]),
   ("post (1852-1866, one >> chain)", closing (LATE os_tail), [closing (LATE os_tail \\ fs [])])];

(* ================= print_spec_V (TextIOProofScript.sml 1874-1880; tac = 1700-1712) ================= *)
fun print_tac () : tactic =
  simp [w82n_n2w8, FD_def, LENGTH_n2w8, STRING_TYPE_def] \\ xsimpl
  \\ imp_res_tac STD_streams_stdout
  \\ imp_res_tac STD_streams_stderr
  \\ simp [add_stdo_def, up_stdo_def]
  \\ SELECT_ELIM_TAC \\ (conj_tac >- metis_tac [])
  \\ rw [] \\ imp_res_tac stdo_UNICITY_R \\ rveq
  \\ fs [stdo_def, get_fd_content_def, get_mode_def, STRING_TYPE_def, PULL_EXISTS]
  \\ instantiate \\ xsimpl
  \\ (conj_tac >- (EVAL_TAC \\ simp [EVAL_RULE stdout_v_thm, EVAL_RULE stderr_v_thm]))
  \\ simp [Q.ISPEC (Q "explode x") (Q.GEN (Q "l2") insert_atI_end) |> SIMP_RULE (srw_ss ()) []]
  \\ xsimpl;
fun OUTPUT_STDIO_V_G () = GEN_ALL (TH "output_STDIO_spec_V");
val PRINT_STEPS : step list =
  [("xcf, STD_streams case (1875-1877)",
      rpt strip_tac \\ xcf.xcf_with_def TextIO_print_v_def \\
      (reverse (Cases_on (Q "STD_streams fs")) >- (fs [STDIO_V_def] \\ xpull)), []),
   ("call output_STDIO_spec_V + tac (1878-1879)",
      closing (LATE (fn () => xapp_spec (OUTPUT_STDIO_V_G ())) \\ EX_INV \\ LATE print_tac),
      [closing (LATE (fn () => xapp_spec (OUTPUT_STDIO_V_G ())) \\ LATE print_tac),
       closing (LATE (fn () => xapp_spec (OUTPUT_STDIO_V_G ())) \\ LATE print_tac \\ rw [] \\ fs []),
       closing (LATE (fn () => xapp_spec (OUTPUT_STDIO_V_G ())) \\ simp [] \\ LATE print_tac)])];

(* ================= print_spec_refund (NEW: instance Inv := refund_valid_event) ================= *)
(* round7: R6wx-0001 line 1959: irule (GEN_ALL print_spec_V) "No match": with an ASSUMEd print_spec_V, Inv is free
   in the hypothesis, so GEN_ALL cannot generalise it. New: instantiate Inv explicitly (INST also acts on hypotheses).
   Shapes: print_spec_V = !fs sv s. STRING_TYPE s sv ==> write_event_ok Inv 1 ==> app p TextIO_print_v [sv]
   (STDIO_V Inv fs) (POSTv uv. &UNIT_TYPE () uv * STDIO_V Inv (add_stdout fs s)); write_event_ok_refund =
   write_event_ok refund_valid_event 1; print_spec_refund = print_spec_V at Inv := refund_valid_event without the
   second hypothesis. *)
fun PRINT_INST () : thm =
  INST [mk_var ("Inv", Parse.Type [QUOTE ":io_event -> bool"]) |-> Parse.Term [QUOTE "refund_valid_event"]]
       (SPEC_ALL (TH "print_spec_V"));
val PRINT_R_STEPS : step list =
  [("instance", closing (rpt strip_tac \\ LATE (fn () => irule (PRINT_INST ())) \\
                         LATE (fn () => fs [TH "write_event_ok_refund"])),
      [closing (rpt strip_tac \\ LATE (fn () => mp_tac (PRINT_INST ())) \\
                LATE (fn () => simp [TH "write_event_ok_refund"]))])];

(* ================= the lemma list (order = dependency order; true = required) ================= *)
val R6W_LEMMAS : (string * term * step list * bool) list =
  [("write_event_ok_writei", WOK_WRITEI, WOK_WRITEI_STEPS, true),
   ("write_event_ok_refund", WOK_REFUND, WOK_REFUND_STEPS, true),
   ("SEG_APPEND3_W", SEG3, SEG3_STEPS, true),
   ("IOxV_FFI_part_IN", FFIIN, FFIIN_STEPS, true),
   ("UNIQUE_IOFS_V", UNIQ, UNIQ_STEPS, true),
   ("IOFS_V_HPROP_INJ", HINJ, HINJ_STEPS, true),
   ("STDIO_V_numchars", NUMCH, NUMCH_STEPS, false),
   ("UNIQUE_STDIO_V", USTDIO, USTDIO_STEPS, false),
   ("STDIO_V_HPROP_INJ", SHINJ, SHINJ_STEPS, false),
   (* round8: STD_streams_fd0 removed (stuck twice; read side; a fresh worker should specialise the
      STD_streams_def iff at fd = 0 with qspecl_then instead of metis) *)
   ("writei_spec_W", WRITEI_W, WRITEI_W_STEPS, true),
   ("write_spec_V", WRITE_V, WRITE_STEPS, true),
   ("output_aux_spec_V", OUTPUT_AUX_V, OUTPUT_AUX_STEPS, true),
   ("output_spec_V", OUTPUT_V, OUTPUT_STEPS, true),
   ("output_STDIO_spec_V", OUTPUT_STDIO_V, OUTPUT_STDIO_STEPS, true),
   ("print_spec_V", PRINT_V, PRINT_STEPS, true),
   ("print_spec_refund", PRINT_R, PRINT_R_STEPS, true)];
(* frame theorems for xlet_auto/xsimpl (the [hprop_inj] attribute of the originals) *)
val R6W_HPROP_INJ = ["IOFS_V_HPROP_INJ", "STDIO_V_HPROP_INJ"];
val _ = pr "R6W_STEPS loaded";

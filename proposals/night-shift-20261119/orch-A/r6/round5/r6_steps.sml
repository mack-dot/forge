(* r6_steps.sml (worker A30, round 4). The ONE file of step lists, read with use by BOTH
   R6x-0004.sml (exploration: explore_head prints every step, tries the alternatives in order) and
   R6ffi-0001.sml (proof: each step = FIRST (main :: alternatives), each candidate under the same time limit,
   applied to the head goal with THEN_LT HEADGOAL; i.e. the same choice as the exploration).
   Needs r6_common.sml (read before) and cfLib. Every tactic UNCHECKED.
   Sources: R6x-0003-writei.sml / R6x-0003-readinto.sml (round3) with these changes (R6x-0003 log =
   attempt-0001/R6x-0003/stdout.log):
   - post_close and the "invariant" steps use INV_ALL (r6_common.sml; NEW INV_Z1-3 first). The R6x-0003 alt 1 of the
     invariant steps (INV_DIAG) did NOT close the goal (it only unfolded the Abbrev); it is removed. One alternative
     INV_Z4C (below).
   - writei step 11 and read_into step 13 failed only because the invariant goal was still at the head (log 2262-2275,
     4110-4140 show CONCL Inv (IO_event ...)). Their tactics are the original ones; the patterns match the printed
     continuation goals (log 1600-1660: pre W8ARRAY iobuff_loc (0w::n2w (MIN n k DIV 256)::...) * IOxV Inv (fsupdate ...);
     read: pre IOxV Inv (bumpFD fd fs nr) * W8ARRAY buf (...)). Each not-yet-run step now has one alternative.
   - X9 and X8 (round3 main file lines 311-317 and R6x-0003-x8.sml) are here as step lists, head mode (one goal per
     step in R6x-0003: log 62-98, 177-226). *)
open preamble cfLib basisFunctionsLib ml_translatorTheory mlstringTheory llistTheory miscTheory alistTheory stringTheory
     arithmeticTheory fsFFITheory fsFFIPropsTheory TextIOProgTheory TextIOProofTheory MarshallingTheory;
fun Q (s : string) : term quotation = [QUOTE s];
val _ = pr "R6_STEPS opened";
(* the simpset of TextIOProofScript.sml line 13 *)
val _ = (temp_delsimps ["NORMEQ_CONV", "TAKE_LENGTH_ID_rwt2"]; pr "DELSIMPS_OK")
  handle e => pr ("DELSIMPS_FAILED " ^ trunc 300 (General.exnMessage e));
(* alternative for the invariant obligation: same SPEC idea, one rw pass *)
val INV_Z4C : tactic =
  closing (fs [ABD, EVA] \\ ZIP_SPEC_TAC \\ rw [ZIPD, LTE, MIND] \\ fs [] \\ rw [] \\ fs [ZIPD]);

val X9_STEPS : (string * tactic * tactic list) list =
  [("intro", rpt gen_tac, []),
   ("unfold", rw [FPH, IOFS_V_def, IOxV_def, SEPC, SEPE, W8AD, CELLD], [simp [FPH, IOFS_V_def, IOxV_def, SEPE]]),
   ("split", fs [ONES, STARD, SPLD, CONDD, ONED], []),
   ("close", rveq \\ fs [INU] \\ metis_tac [],
      [qpat_x_assum (Q "_ UNION _ = h") (SUBST_ALL_TAC o SYM) \\ simp [INU] \\ metis_tac [],
       metis_tac [INU]])];
val X8_STEPS : (string * tactic * tactic list) list =
  [("intro", rpt gen_tac, []),
   ("unfold", simp [IOxV_def, IOxD, IOD, FFP], [rw [IOxV_def, IOxD, IOD, FFP]]),
   ("xsimpl", xsimpl, []),
   ("close", rpt strip_tac \\ qexists_tac (Q "x") \\ simp [SIR],
      [metis_tac [SIR], rw [SIR] \\ metis_tac [SIR]])];

(* ================= writei_spec_V (TextIOProofScript.sml 1422-1552) ================= *)
(* prelude = lines 1423-1438 (quotations rewritten), then xcf with the single-argument xcf.xcf_with_def *)
val prelude =
  strip_tac \\
  Q "?ll. fs.numchars = ll" by simp[] \\ fs[] \\
  Q "ll <> [||]" by (Cases_on (Q "ll") \\ fs[wfFS_def,liveFS_def,live_numchars_def]) \\
  Q "always (eventually (\\ll. ?k. LHD ll = SOME k /\\ k <> 0)) ll" by fs[wfFS_def,liveFS_def,live_numchars_def] \\
  reverse(Cases_on (Q "validFD fd fs")) >- metis_tac[get_fd_content_validFD] \\
  pop_assum mp_tac \\
  UNDISCH_TAC (Parse.Term (Q "fs.numchars = ll")) \\ LAST_X_ASSUM MP_TAC \\
  LAST_ASSUM MP_TAC \\
  map_every qid_spec_tac [Q "bc", Q "h4", Q "h3", Q "h2", Q "h1", Q "fs"] \\
  NTAC 2 (FIRST_X_ASSUM MP_TAC) \\ qid_spec_tac (Q "ll") \\
  HO_MATCH_MP_TAC always_eventually_ind \\
  rpt strip_tac \\
  xcf.xcf_with_def TextIO_writei_v_def \\ fs[FD_def];

(* ---------- branch 1 ---------- *)
val ffi_post1 =
  "POSTv uv. &(UNIT_TYPE () uv) * W8ARRAY iobuff_loc ((0w :: n2w (MIN n k DIV 256)::n2w (MIN n k) :: n2w i :: rest)) * " ^
  "IOxV Inv (fsupdate fs fd 1 (MIN n k + pos) (TAKE pos content ++ " ^
  "TAKE (MIN n k) (MAP (CHR o w2n) (DROP i rest)) ++ DROP (MIN n k + pos) content))";
val b1_unfold_pre =
  qmatch_goalsub_abbrev_tac (Q " _ * _ * IOxV _ fs'") \\
  qpat_abbrev_tac (Q "Q = $POSTv _") \\
  simp [fs_ffi_part_def, IOxV_def, IOx_def, IO_def] \\
  xpull \\ qunabbrev_tac (Q "Q");
val open_post =
  fs[IOxV_def,IOFS_def,IOx_def,fs_ffi_part_def,mk_ffi_next_def,IO_def] \\
  qmatch_goalsub_abbrev_tac (Q "FFI_part st f ns") \\
  CONV_TAC(RESORT_EXISTS_CONV List.rev) \\
  map_every qexists_tac[Q "events", Q "ns", Q "f", Q "st"] \\ xsimpl \\
  qexists_tac (Q "n2w8 fd");
(* lines 1462-1467 *)
val b1_fs_big =
  fs[Abbr (Q "f"),Abbr (Q "st"),Abbr (Q "ns"),mk_ffi_next_def,w82n_n2w8,LENGTH_n2w8,
     ffi_write_def,MEM_MAP, ORD_BOUND,ORD_eq_0,wfFS_LDROP,
     dimword_8, MAP_MAP_o,o_DEF,char_BIJ,implode_explode,LENGTH_explode,
     HD_LUPDATE,LUPDATE_def,option_eq_some,validFD_def,write_def,
     get_fd_content_def] \\
  pairarg_tac \\ fs[] \\ xsimpl;
(* lines 1468-1477 up to qexists_tac new_events *)
val b1_rest =
  Q "MEM fd (MAP FST fs.infds)" by (metis_tac[MEM_MAP]) \\
  rw[] \\ TRY(metis_tac[STRING_TYPE_def,wfFS_fsupdate,liveFS_fsupdate]) \\
  Cases_on (Q "fs.numchars") \\ fs[Abbr (Q "fs'"),fsupdate_def] \\
  fs[GSYM n2w2_def] \\
  Q "i < 2 ** (2 * 8)" by fs[] \\ imp_res_tac w22n_n2w2 \\
  Q "n < 2 ** (2 * 8)" by fs[] \\ imp_res_tac w22n_n2w2 \\
  rw[] \\ rfs[]
  \\ Cases_on (Q "md") \\ fs[]
  >- rfs[get_mode_def]
  \\ xsimpl \\ simp[n2w2_def] \\
  qpat_abbrev_tac (Q "new_events = events ++ _") \\
  qexists_tac (Q "new_events");
(* the last xsimpl of line 1477, then the NEW invariant obligation on every copy *)
val post_close = xsimpl \\ TRY (ON_INV INV_ALL);

(* ---------- branch 2 ---------- *)
val ffi_post2 =
  "POSTv uv. &(UNIT_TYPE () uv) * W8ARRAY iobuff_loc (0w:: 0w :: 0w :: n2w i :: rest) * " ^
  "IOxV Inv (fsupdate fs fd 1 pos (TAKE pos content ++ TAKE 0 (MAP (CHR o w2n) (DROP i rest)) ++ DROP pos content))";
(* line 1499: the original uses fs here, not simp *)
val b2_unfold_pre =
  qmatch_goalsub_abbrev_tac (Q " _ * _ * IOxV _ fs'") \\
  qpat_abbrev_tac (Q "Q = $POSTv _") \\
  fs [fs_ffi_part_def, IOxV_def, IOx_def, IO_def] \\
  xpull \\ qunabbrev_tac (Q "Q");
(* lines 1509-1515 *)
val b2_fs_big =
  fs[Abbr (Q "f"),Abbr (Q "st"),Abbr (Q "ns"),mk_ffi_next_def,
     ffi_write_def,MEM_MAP, ORD_BOUND,ORD_eq_0,wfFS_LDROP,
     dimword_8, MAP_MAP_o,o_DEF,char_BIJ,implode_explode,LENGTH_explode,
     HD_LUPDATE,LUPDATE_def,option_eq_some,validFD_def,write_def,
     get_fd_content_def,w82n_n2w8,LENGTH_n2w8] \\
  pairarg_tac \\ xsimpl;
(* lines 1516-1528 up to qexists_tac new_events *)
val b2_rest =
  Q "MEM fd (MAP FST fs.infds)" by (metis_tac[MEM_MAP]) \\
  rw[] \\ TRY(metis_tac[STRING_TYPE_def,wfFS_fsupdate,liveFS_fsupdate,Abbr (Q "fs'")]) \\
  fs[Abbr (Q "fs'"),fsupdate_def,insert_atI_def,n2w2_def] \\
  fs[GSYM n2w2_def] \\
  Q "i < 2 ** (2 * 8)" by fs[] \\ imp_res_tac w22n_n2w2 \\
  Q "n < 2 ** (2 * 8)" by fs[] \\ imp_res_tac w22n_n2w2 \\
  rw[] \\ rfs[]
  \\ Cases_on (Q "md") \\ fs[]
  >- rfs[get_mode_def]
  \\ xsimpl \\
  qpat_abbrev_tac (Q "new_events = events ++ _") \\
  qexists_tac (Q "new_events");
(* lines 1546-1549; the IH now has the extra antecedent H_inv (same n, i, rest, fd), see ALT *)
val b2_close =
  Q "Lnext_pos (0:::t) = SUC(Lnext_pos t)" by (fs[Lnext_pos_def,Once Lnext_def]) \\
  csimp[ADD] \\ xsimpl \\ Cases_on (Q "t") \\
  fs[get_mode_def] \\ rw[] \\ instantiate \\ xsimpl;
val b2_close_alt1 =
  Q "Lnext_pos (0:::t) = SUC(Lnext_pos t)" by (fs[Lnext_pos_def,Once Lnext_def]) \\
  csimp[ADD] \\ xsimpl \\ Cases_on (Q "t") \\
  fs[get_mode_def] \\ rw[] \\ TRY instantiate \\ TRY xsimpl \\
  TRY (first_x_assum MATCH_ACCEPT_TAC) \\ TRY (ON_INV (fs [] \\ NO_TAC)) \\ TRY (metis_tac []);
val b2_close_alt2 =
  Q "Lnext_pos (0:::t) = SUC(Lnext_pos t)" by (fs[Lnext_pos_def,Once Lnext_def]) \\
  csimp[ADD] \\ xsimpl \\ Cases_on (Q "t") \\ fs[get_mode_def] \\ rw[];


val WRITEI_STEPS : (string * tactic * tactic list) list =
  [("prelude", prelude, []),
   (* branch 1 *)
   ("B1 lnext0", sg (Q "Lnext_pos ll = 0") >-
                (fs[Lnext_pos_def,Once Lnext_def,liveFS_def,live_numchars_def,always_thm] \\ Cases_on (Q "ll") \\ fs[]), []),
   ("B1 n2w2_into_iobuff", NTAC 2 ((xlet_auto \\ fs[n2w2_def,insert_atI_def]) >- xsimpl),
      [NTAC 2 (xlet_auto >- xsimpl) \\ fs[n2w2_def,insert_atI_def]]),
   ("B1 xlet_ffi", xlet (Q ffi_post1), []),
   ("B1 unfold_pre (IOxV_def NEW)", b1_unfold_pre,
      [qpat_abbrev_tac (Q "Q = $POSTv _") \\ simp [fs_ffi_part_def, IOxV_def, IOx_def, IO_def] \\ xpull \\
       qunabbrev_tac (Q "Q")]),
   ("B1 xffi", xffi \\ xsimpl, [xffi]),
   ("B1 open_post (IOxV_def NEW)", open_post, []),
   ("B1 post_ffi + invariant (NEW)", b1_fs_big \\ b1_rest \\ post_close,
      [b1_fs_big \\ b1_rest \\ xsimpl \\ TRY (ON_INV INV_Z4C)]),
   ("B1 invariant (NEW, leftover copy 1)", ON_INV INV_ALL, [ON_INV INV_Z4C]),
   ("B1 invariant (NEW, leftover copy 2)", ON_INV INV_ALL, [ON_INV INV_Z4C]),
   (* lines 1478-1488: continuation after the write call *)
   ("B1 cont abbrev", qmatch_goalsub_abbrev_tac (Q " _ * IOxV _ fs'") \\
                      qmatch_goalsub_abbrev_tac (Q "W8ARRAY _ (_::m1 :: m0 :: n2w i :: rest)") \\ fs[],
      [qmatch_goalsub_abbrev_tac (Q "IOxV _ fs'") \\ fs[]]),
   ("B1 cont reads", NTAC 3 (xlet_auto >- xsimpl) \\ xif \\ fs[FALSE_def] \\ instantiate \\
                     NTAC 2 (xlet_auto >- xsimpl) \\ fs[GSYM n2w2_def],
      [NTAC 3 (xlet_auto >- xsimpl) \\ xif \\ fs[FALSE_def] \\ TRY instantiate \\
       NTAC 2 (xlet_auto >- xsimpl) \\ fs[GSYM n2w2_def]]),
   ("B1 cont w22n", Q "(if n < k then n else k) < (2**(2*8))" by fs[] \\ progress w22n_n2w2,
      [Q "MIN n k < (2**(2*8))" by fs[MIN_DEF] \\ progress w22n_n2w2]),
   ("B1 cont close", xif \\ fs[FALSE_def] \\ xvar \\ xsimpl \\
                     fs[IOFS_def,wfFS_fsupdate,liveFS_fsupdate] \\
                     instantiate \\ fs[Abbr (Q "fs'"),MIN_DEF,insert_atI_def] \\ xsimpl,
      [xif \\ fs[FALSE_def] \\ xvar \\ xsimpl \\ fs[Abbr (Q "fs'"),MIN_DEF,insert_atI_def] \\ xsimpl \\ rw[] \\ fs[]]),
   (* branch 2 *)
   ("B2 cases_ll", Cases_on (Q "ll") >- fs[liveFS_def,live_numchars_def],
      [Cases_on (Q "ll") >- fs[liveFS_def,live_numchars_def,wfFS_def]]),
   ("B2 n2w2_into_iobuff", NTAC 2 (xlet_auto >- (xsimpl \\ EVAL_TAC \\ fs[LUPDATE_def])),
      [NTAC 2 ((xlet_auto \\ fs[n2w2_def,insert_atI_def]) >- (xsimpl \\ EVAL_TAC \\ fs[LUPDATE_def]))]),
   ("B2 xlet_ffi", xlet (Q ffi_post2), [xlet (Q ffi_post2) \\ fs[]]),
   ("B2 unfold_pre (IOxV_def NEW)", b2_unfold_pre,
      [qmatch_goalsub_abbrev_tac (Q " _ * _ * IOxV _ fs'") \\ qpat_abbrev_tac (Q "Q = $POSTv _") \\
       simp [fs_ffi_part_def, IOxV_def, IOx_def, IO_def] \\ xpull \\ qunabbrev_tac (Q "Q")]),
   ("B2 xffi", xffi \\ xsimpl, [xffi]),
   ("B2 open_post (IOxV_def NEW)", open_post, []),
   ("B2 post_ffi + invariant (NEW)", b2_fs_big \\ b2_rest \\ post_close,
      [b2_fs_big \\ b2_rest \\ xsimpl \\ TRY (ON_INV INV_Z4C)]),
   ("B2 invariant (NEW, leftover copy 1)", ON_INV INV_ALL, [ON_INV INV_Z4C]),
   ("B2 invariant (NEW, leftover copy 2)", ON_INV INV_ALL, [ON_INV INV_Z4C]),
   (* lines 1530-1549: continuation, recursive call through the induction hypothesis *)
   ("B2 cont reads", NTAC 3 (xlet_auto >- xsimpl) \\ xif \\ fs[FALSE_def] \\ instantiate \\
                     NTAC 2 (xlet_auto >- xsimpl) \\ fs[w22n_def] \\ xif \\ fs[TRUE_def] \\ instantiate,
      [NTAC 3 (xlet_auto >- xsimpl) \\ xif \\ fs[FALSE_def] \\ TRY instantiate \\
       NTAC 2 (xlet_auto >- xsimpl) \\ fs[w22n_def] \\ xif \\ fs[TRUE_def] \\ TRY instantiate]),
   ("B2 xapp IH", qmatch_goalsub_abbrev_tac (Q " _ * IOxV _ fs'") \\ xapp \\ xsimpl \\
                  CONV_TAC(RESORT_EXISTS_CONV List.rev) \\ qexists_tac (Q "fs'") \\ xsimpl,
      [qmatch_goalsub_abbrev_tac (Q "IOxV _ fs'") \\ xapp \\ xsimpl \\
       CONV_TAC(RESORT_EXISTS_CONV List.rev) \\ qexists_tac (Q "fs'") \\ xsimpl \\ fs []]),
   ("B2 numchars", sg (Q "t = fs'.numchars") >-
                     (fs[Abbr (Q "fs'"),fsupdate_def,get_fd_content_def] \\ pairarg_tac \\ fs[LDROP_1]),
      [sg (Q "t = fs'.numchars") >- (fs[Abbr (Q "fs'"),fsupdate_def,get_fd_content_def] \\ rpt (pairarg_tac \\ fs[]) \\ fs[LDROP_1])]),
   ("B2 fs_eq", sg (Q "fs' = fs with numchars := t") >-
                  (imp_res_tac validFD_ALOOKUP \\ fs[wfFS_def,Abbr (Q "fs'"),fsupdate_def] \\
                   fs[IO_fs_component_equality] \\ fs[wfFS_def,get_fd_content_def] \\
                   pairarg_tac \\ fs[AFUPDKEY_unchanged,LDROP_1]),
      [sg (Q "fs' = fs with numchars := t") >-
         (imp_res_tac validFD_ALOOKUP \\ fs[Abbr (Q "fs'"),fsupdate_def,IO_fs_component_equality,get_fd_content_def] \\
          rpt (pairarg_tac \\ fs[]) \\ fs[AFUPDKEY_unchanged,LDROP_1])]),
   ("B2 side", fs[Abbr (Q "fs'"),get_fd_content_def,liveFS_def,live_numchars_def,fsupdate_def,LDROP_1,
                  wfFS_fsupdate,validFD_def,liveFS_fsupdate,IOFS_def] \\
               pairarg_tac \\ fs[AFUPDKEY_unchanged] \\
               fs[wfFS_def,liveFS_def,live_numchars_def] \\
               imp_res_tac always_thm,
      [fs[Abbr (Q "fs'"),get_fd_content_def,liveFS_def,live_numchars_def,fsupdate_def,LDROP_1,
          wfFS_fsupdate,validFD_def,liveFS_fsupdate] \\ rpt (pairarg_tac \\ fs[AFUPDKEY_unchanged]) \\
       fs[wfFS_def,liveFS_def,live_numchars_def] \\ imp_res_tac always_thm]),
   ("B2 close (IH antecedent H_inv: see alt 1)", b2_close, [b2_close_alt1, b2_close_alt2])];

(* ================= read_into_spec_V (TextIOProofScript.sml 2150-2244; success path incl. zero bytes) ================= *)
val succ_post =
  "POSTve (\\uv. SEP_EXISTS nr nrv . &(NUM nr nrv) * " ^
  "SEP_EXISTS content pos.  &(get_fd_content fs fd = SOME(content, pos) /\\ " ^
  "get_mode fs fd = SOME ReadMode /\\ (nr <= MIN n (LENGTH content - pos)) /\\ " ^
  "(nr <= LENGTH content - pos) /\\ (nr = 0 <=> eof fd fs = SOME T \\/ n = 0)) * " ^
  "IOxV Inv (bumpFD fd fs nr) * " ^
  "W8ARRAY buf (0w :: n2w (nr DIV 256) :: n2w nr :: h4 :: " ^
  "(MAP (n2w o ORD) (TAKE nr (DROP pos content))++DROP nr rest))) " ^
  "(\\e. &(get_fd_content fs fd = NONE))";
val r_unfold_pre =
  qpat_abbrev_tac (Q "Q = POSTve _ _") \\
  simp [fs_ffi_part_def, IOxV_def, IOx_def, IO_def] \\
  xpull \\ qunabbrev_tac (Q "Q");
val r_open_post =
  fs[IOxV_def,IOFS_def,IOx_def,fs_ffi_part_def, mk_ffi_next_def,IO_def] \\
  qmatch_goalsub_abbrev_tac (Q "FFI_part st f ns") \\
  CONV_TAC(RESORT_EXISTS_CONV List.rev) \\
  map_every qexists_tac[Q "events", Q "ns", Q "f", Q "st"] \\
  xsimpl \\ qexists_tac (Q "n2w8 fd");
(* lines 2225-2230 *)
val r_fs_big =
  fs[Abbr (Q "f"),Abbr (Q "st"),Abbr (Q "ns"),mk_ffi_next_def,
     ffi_read_def,w82n_n2w8,LENGTH_n2w8,MEM_MAP, ORD_BOUND,ORD_eq_0,wfFS_LDROP,
     dimword_8, MAP_MAP_o,o_DEF,char_BIJ,implode_explode,LENGTH_explode,
     HD_LUPDATE,LUPDATE_def,option_eq_some,validFD_def,read_def,
     get_fd_content_def,FD_def,STRING_TYPE_def] \\ rfs[get_mode_def];
(* lines 2231-2239 up to qexists_tac new_events *)
val r_rest =
  simp[GSYM n2w2_def,w22n_n2w2] \\
  pairarg_tac \\ xsimpl \\ fs[] \\ rw[] \\
  Cases_on (Q "fs.numchars") \\ fs[wfFS_def,liveFS_def,live_numchars_def] \\
  fs[n2w2_def,DIV_MOD_MOD_DIV,DIV_DIV_DIV_MULT] \\ xsimpl \\
  qmatch_goalsub_abbrev_tac (Q "(k DIV 256) MOD 256 = _ MOD 256") \\ qexists_tac (Q "k") \\
  xsimpl \\ fs[MIN_LE,eof_def,Abbr (Q "k"),NUM_def,INT_def] \\
  qpat_abbrev_tac (Q "new_events = events ++ _") \\
  qexists_tac (Q "new_events");
val r_post_close = xsimpl \\ TRY (ON_INV INV_ALL);
(* lines 2241-2243 *)
val r_continuation =
  rpt(xlet_auto >- xsimpl) \\
  xif \\ instantiate \\ xapp \\ xsimpl \\ rw[] \\ instantiate \\
  simp[GSYM n2w2_def,w22n_n2w2] \\ xsimpl \\ gvs [];
val r_continuation_alt1 =
  rpt(xlet_auto >- xsimpl) \\
  xif \\ instantiate \\ xapp \\ xsimpl \\ rw[] \\ instantiate \\
  simp[GSYM n2w2_def,w22n_n2w2] \\ xsimpl \\ fs [];
val r_continuation_alt2 =
  rpt(xlet_auto >- xsimpl) \\
  xif \\ instantiate \\ xapp \\ xsimpl \\ rw[] \\ TRY instantiate \\
  simp[GSYM n2w2_def,w22n_n2w2] \\ TRY xsimpl;


val READ_INTO_STEPS : (string * tactic * tactic list) list =
  [("intro", rpt strip_tac, []),
   ("xcf", xcf.xcf_with_def TextIO_read_into_v_def, []),
   ("n2w2_into_buf", fs[IOFS_WO_iobuff_def] \\ xlet_auto >- xsimpl, [xlet_auto >- xsimpl]),
   ("simp", simp[insert_atI_def,n2w2_def], []),
   ("cases (NEW: both error paths closed by the new hypotheses)",
      Cases_on (Q "get_fd_content fs fd") >- fs [] \\ Cases_on (Q "x") \\ fs [],
      [Cases_on (Q "get_fd_content fs fd") \\ fs [] \\ Cases_on (Q "x") \\ fs [],
       Cases_on (Q "get_fd_content fs fd") >- (rfs [] \\ fs []) \\ Cases_on (Q "x") \\ fs []]),
   ("xlet_succ", xlet (Q succ_post) \\ xsimpl, [xlet (Q succ_post)]),
   ("unfold_pre (IOxV_def NEW)", r_unfold_pre,
      [qpat_abbrev_tac (Q "Q = POSTve _ _") \\ fs [fs_ffi_part_def, IOxV_def, IOx_def, IO_def] \\ xpull \\
       qunabbrev_tac (Q "Q")]),
   ("xffi", xffi \\ xsimpl, [xffi]),
   ("open_post (IOxV_def NEW)", r_open_post, []),
   ("post_ffi + invariant (NEW)", r_fs_big \\ r_rest \\ r_post_close, [r_fs_big \\ r_rest \\ xsimpl \\ TRY (ON_INV INV_Z4C)]),
   ("invariant (NEW, leftover copy 1)", ON_INV INV_ALL, [ON_INV INV_Z4C]),
   ("invariant (NEW, leftover copy 2)", ON_INV INV_ALL, [ON_INV INV_Z4C]),
   ("continuation", r_continuation, [r_continuation_alt1, r_continuation_alt2])];
val _ = pr "R6_STEPS loaded";

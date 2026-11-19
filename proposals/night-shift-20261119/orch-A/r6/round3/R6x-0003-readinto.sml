(* R6x-0003-readinto.sml (worker A30). NOT RUN. Read by R6x-0003.sml with use, inside a handler. Needs cfLib.
   read_into_spec_V, head-goal mode. Base: R6x-0002-readinto.sml (91d7311a...f601); its steps 1-2 ran in R6x-0002
   (log lines 844, 881). Source: read_into_spec's proof, TextIOProofScript.sml 2150-2244.
   - Success path = source lines 2209-2243 (xlet with the success post, xffi block, continuation). It covers the
     zero-byte case too (nr = 0 when eof fd fs = SOME T or n = 0): there is no separate branch in the code.
   - The two error paths of the source (2156-2180: get_fd_content fs fd = NONE; 2182-2208: get_mode fs fd <> SOME
     ReadMode) are EXCLUDED by the two new hypotheses of read_into_spec_V and closed by fs at step "cases".
     Each of them makes the FFI return LUPDATE 1w 0 bytes (fsFFIScript.sml ffi_read_def 307-323), so HD nb = 1w and
     the event is not a refund_valid_event (L2c definition: HD nb = 0w). The program-level proof must discharge
     the two hypotheses for fd 0 from STD_streams (fsFFIPropsScript.sml 1314) and wfFS (221-227), or directly from
     INSTREAM_STR (TextIOProofScript.sml 5773-5780), which already contains both facts.
   Steps COPIED with IOx fs_ffi_part replaced by IOxV Inv and IOxV_def added; inserted steps marked NEW.
   Quotations as [QUOTE "..."]. Every tactic UNCHECKED. *)
open preamble cfLib basisFunctionsLib ml_translatorTheory mlstringTheory llistTheory miscTheory alistTheory stringTheory
     arithmeticTheory fsFFITheory fsFFIPropsTheory TextIOProgTheory TextIOProofTheory MarshallingTheory;
fun Q (s : string) : term quotation = [QUOTE s];
val _ = pr "READ_INTO_PART opened";
(* the simpset of TextIOProofScript.sml line 13 (already applied by the writei part; repeated, harmless) *)
val _ = (temp_delsimps ["NORMEQ_CONV", "TAKE_LENGTH_ID_rwt2"]; pr "DELSIMPS_OK")
  handle e => pr ("DELSIMPS_FAILED " ^ trunc 300 (General.exnMessage e));

val succ_post =
  "POSTve (\\uv. SEP_EXISTS nr nrv . &(NUM nr nrv) * " ^
  "SEP_EXISTS content pos.  &(get_fd_content fs fd = SOME(content, pos) /\\ " ^
  "get_mode fs fd = SOME ReadMode /\\ (nr <= MIN n (LENGTH content - pos)) /\\ " ^
  "(nr <= LENGTH content - pos) /\\ (nr = 0 <=> eof fd fs = SOME T \\/ n = 0)) * " ^
  "IOxV Inv (bumpFD fd fs nr) * " ^
  "W8ARRAY buf (0w :: n2w (nr DIV 256) :: n2w nr :: h4 :: " ^
  "(MAP (n2w o ORD) (TAKE nr (DROP pos content))++DROP nr rest))) " ^
  "(\\e. &(get_fd_content fs fd = NONE))";
val unfold_pre =
  qpat_abbrev_tac (Q "Q = POSTve _ _") \\
  simp [fs_ffi_part_def, IOxV_def, IOx_def, IO_def] \\
  xpull \\ qunabbrev_tac (Q "Q");
val open_post =
  fs[IOxV_def,IOFS_def,IOx_def,fs_ffi_part_def, mk_ffi_next_def,IO_def] \\
  qmatch_goalsub_abbrev_tac (Q "FFI_part st f ns") \\
  CONV_TAC(RESORT_EXISTS_CONV List.rev) \\
  map_every qexists_tac[Q "events", Q "ns", Q "f", Q "st"] \\
  xsimpl \\ qexists_tac (Q "n2w8 fd");
(* lines 2225-2230 *)
val fs_big =
  fs[Abbr (Q "f"),Abbr (Q "st"),Abbr (Q "ns"),mk_ffi_next_def,
     ffi_read_def,w82n_n2w8,LENGTH_n2w8,MEM_MAP, ORD_BOUND,ORD_eq_0,wfFS_LDROP,
     dimword_8, MAP_MAP_o,o_DEF,char_BIJ,implode_explode,LENGTH_explode,
     HD_LUPDATE,LUPDATE_def,option_eq_some,validFD_def,read_def,
     get_fd_content_def,FD_def,STRING_TYPE_def] \\ rfs[get_mode_def];
(* lines 2231-2239 up to qexists_tac new_events *)
val rest =
  simp[GSYM n2w2_def,w22n_n2w2] \\
  pairarg_tac \\ xsimpl \\ fs[] \\ rw[] \\
  Cases_on (Q "fs.numchars") \\ fs[wfFS_def,liveFS_def,live_numchars_def] \\
  fs[n2w2_def,DIV_MOD_MOD_DIV,DIV_DIV_DIV_MULT] \\ xsimpl \\
  qmatch_goalsub_abbrev_tac (Q "(k DIV 256) MOD 256 = _ MOD 256") \\ qexists_tac (Q "k") \\
  xsimpl \\ fs[MIN_LE,eof_def,Abbr (Q "k"),NUM_def,INT_def] \\
  qpat_abbrev_tac (Q "new_events = events ++ _") \\
  qexists_tac (Q "new_events");
val post_close = xsimpl \\ TRY (ON_INV INV_CLOSE);
(* lines 2241-2243 *)
val continuation =
  rpt(xlet_auto >- xsimpl) \\
  xif \\ instantiate \\ xapp \\ xsimpl \\ rw[] \\ instantiate \\
  simp[GSYM n2w2_def,w22n_n2w2] \\ xsimpl \\ gvs [];
val continuation_alt1 =
  rpt(xlet_auto >- xsimpl) \\
  xif \\ instantiate \\ xapp \\ xsimpl \\ rw[] \\ instantiate \\
  simp[GSYM n2w2_def,w22n_n2w2] \\ xsimpl \\ fs [];
val continuation_alt2 =
  rpt(xlet_auto >- xsimpl) \\
  xif \\ instantiate \\ xapp \\ xsimpl \\ rw[] \\ TRY instantiate \\
  simp[GSYM n2w2_def,w22n_n2w2] \\ TRY xsimpl;

val _ = explore_head "READ_INTO_V_success_and_zero" (goal_of READ_INTO_V)
  [("intro", rpt strip_tac, []),
   ("xcf", xcf.xcf_with_def TextIO_read_into_v_def, []),
   ("n2w2_into_buf", fs[IOFS_WO_iobuff_def] \\ xlet_auto >- xsimpl, [xlet_auto >- xsimpl]),
   ("simp", simp[insert_atI_def,n2w2_def], []),
   ("cases (NEW: both error paths closed by the new hypotheses)",
      Cases_on (Q "get_fd_content fs fd") >- fs [] \\ Cases_on (Q "x") \\ fs [],
      [Cases_on (Q "get_fd_content fs fd") \\ fs [] \\ Cases_on (Q "x") \\ fs [],
       Cases_on (Q "get_fd_content fs fd") >- (rfs [] \\ fs []) \\ Cases_on (Q "x") \\ fs []]),
   ("xlet_succ", xlet (Q succ_post) \\ xsimpl, [xlet (Q succ_post)]),
   ("unfold_pre (IOxV_def NEW)", unfold_pre,
      [qpat_abbrev_tac (Q "Q = POSTve _ _") \\ fs [fs_ffi_part_def, IOxV_def, IOx_def, IO_def] \\ xpull \\
       qunabbrev_tac (Q "Q")]),
   ("xffi", xffi \\ xsimpl, [xffi]),
   ("open_post (IOxV_def NEW)", open_post, []),
   ("post_ffi + invariant (NEW)", fs_big \\ rest \\ post_close, [fs_big \\ rest, fs_big]),
   ("invariant (NEW, leftover copy 1)", ON_INV INV_CLOSE, [ON_INV INV_DIAG]),
   ("invariant (NEW, leftover copy 2)", ON_INV INV_CLOSE, [ON_INV INV_DIAG]),
   ("continuation", continuation, [continuation_alt1, continuation_alt2])];

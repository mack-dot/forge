(* R6x-0002-readinto.sml (worker A25). NOT RUN. Read by R6x-0002.sml with use, inside a handler. Needs cfLib.
   S4 part 2: read_into_spec_V, success branch (TextIOProofScript.sml 2209-2248) through its xffi block, then the
   continuation. The two error branches of the original (2161-2207: get_fd_content = NONE; mode <> ReadMode) are excluded
   by the two new hypotheses of read_into_spec_V and closed by fs (step "cases"). Steps COPIED from read_into_spec's
   proof with IOx fs_ffi_part replaced by IOxV Inv and IOxV_def added; inserted steps marked NEW.
   Quotations as [QUOTE "..."]. Every tactic UNCHECKED. Head-goal mode. *)
open preamble cfLib basisFunctionsLib ml_translatorTheory mlstringTheory llistTheory miscTheory alistTheory stringTheory
     arithmeticTheory fsFFITheory fsFFIPropsTheory TextIOProgTheory TextIOProofTheory MarshallingTheory;
fun Q (s : string) : term quotation = [QUOTE s];
val _ = pr "READ_INTO_PART opened";
val succ_post =
  "POSTve (\\uv. SEP_EXISTS nr nrv . &(NUM nr nrv) * " ^
  "SEP_EXISTS content pos.  &(get_fd_content fs fd = SOME(content, pos) /\\ " ^
  "get_mode fs fd = SOME ReadMode /\\ (nr <= MIN n (LENGTH content - pos)) /\\ " ^
  "(nr <= LENGTH content - pos) /\\ (nr = 0 <=> eof fd fs = SOME T \\/ n = 0)) * " ^
  "IOxV Inv (bumpFD fd fs nr) * " ^
  "W8ARRAY buf (0w :: n2w (nr DIV 256) :: n2w nr :: h4 :: " ^
  "(MAP (n2w o ORD) (TAKE nr (DROP pos content))++DROP nr rest))) " ^
  "(\\e. &(get_fd_content fs fd = NONE))";
val _ = explore_head "READ_INTO_V_success_xffi" (goal_of READ_INTO_V)
  [("intro", rpt strip_tac, []),
   ("xcf", xcf.xcf_with_def TextIO_read_into_v_def, []),
   ("n2w2_into_buf", fs[IOFS_WO_iobuff_def] \\ xlet_auto >- xsimpl, [xlet_auto >- xsimpl]),
   ("simp", simp[insert_atI_def,n2w2_def], []),
   ("cases (NEW: error branches by the new hypotheses)",
      Cases_on (Q "get_fd_content fs fd") \\ fs [] \\ Cases_on (Q "x") \\ fs [], []),
   ("xlet_succ", xlet (Q succ_post) \\ xsimpl, []),
   ("unfold_pre (IOxV_def NEW)",
      qpat_abbrev_tac (Q "Q = POSTve _ _") \\
      simp [fs_ffi_part_def, IOxV_def, IOx_def, IO_def] \\
      xpull \\ qunabbrev_tac (Q "Q"), []),
   ("xffi", xffi \\ xsimpl, []),
   ("open_post (IOxV_def NEW)",
      fs[IOxV_def,IOFS_def,IOx_def,fs_ffi_part_def, mk_ffi_next_def,IO_def] \\
      qmatch_goalsub_abbrev_tac (Q "FFI_part st f ns") \\
      CONV_TAC(RESORT_EXISTS_CONV List.rev) \\
      map_every qexists_tac[Q "events", Q "ns", Q "f", Q "st"] \\
      xsimpl \\ qexists_tac (Q "n2w8 fd"), []),
   ("rest_to_new_events",
      fs[Abbr (Q "f"),Abbr (Q "st"),Abbr (Q "ns"),mk_ffi_next_def,
         ffi_read_def,w82n_n2w8,LENGTH_n2w8,MEM_MAP, ORD_BOUND,ORD_eq_0,wfFS_LDROP,
         dimword_8, MAP_MAP_o,o_DEF,char_BIJ,implode_explode,LENGTH_explode,
         HD_LUPDATE,LUPDATE_def,option_eq_some,validFD_def,read_def,
         get_fd_content_def,FD_def,STRING_TYPE_def] \\ rfs[get_mode_def] \\
      simp[GSYM n2w2_def,w22n_n2w2] \\
      pairarg_tac \\ xsimpl \\ fs[] \\ rw[] \\
      Cases_on (Q "fs.numchars") \\ fs[wfFS_def,liveFS_def,live_numchars_def] \\
      fs[n2w2_def,DIV_MOD_MOD_DIV,DIV_DIV_DIV_MULT] \\ xsimpl \\
      qmatch_goalsub_abbrev_tac (Q "(k DIV 256) MOD 256 = _ MOD 256") \\ qexists_tac (Q "k") \\
      xsimpl \\ fs[MIN_LE,eof_def,Abbr (Q "k"),NUM_def,INT_def] \\
      qpat_abbrev_tac (Q "new_events = events ++ _") \\
      qexists_tac (Q "new_events"), []),
   ("xsimpl_after", xsimpl, []),
   ("invariant (NEW)",
      simp [Abbr (Q "new_events"), EVERY_APPEND] \\ first_x_assum irule \\ simp [],
      [fs [Abbr (Q "new_events"), EVERY_APPEND] \\ metis_tac [],
       rw [Abbr (Q "new_events"), EVERY_APPEND] \\ first_x_assum match_mp_tac \\ rw [] \\ fs [n2w2_def]]),
   ("continuation",
      rpt(xlet_auto >- xsimpl) \\
      xif \\ instantiate \\ xapp \\ xsimpl \\ rw[] \\ instantiate \\
      simp[GSYM n2w2_def,w22n_n2w2] \\ xsimpl \\ gvs [], [])];

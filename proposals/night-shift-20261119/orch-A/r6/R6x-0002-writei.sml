(* R6x-0002-writei.sml (worker A25). NOT RUN. Read by R6x-0002.sml with use, inside a handler. Needs cfLib.
   S4 part 1: writei_spec_V, first branch ("next el is <> 0", TextIOProofScript.sml 1439-1475) through its xffi block.
   Every step is COPIED from writei_spec's proof (lines 1423-1475) with IOx fs_ffi_part replaced by IOxV Inv and IOxV_def
   added where IOx_def is unfolded; inserted steps are marked NEW. Quotations are written as [QUOTE "..."] (no backquotes),
   so this file does not depend on the quotation filter of use. Every tactic UNCHECKED. Head-goal mode. *)
open preamble cfLib basisFunctionsLib ml_translatorTheory mlstringTheory llistTheory miscTheory alistTheory stringTheory
     arithmeticTheory fsFFITheory fsFFIPropsTheory TextIOProgTheory TextIOProofTheory MarshallingTheory;
fun Q (s : string) : term quotation = [QUOTE s];
val _ = pr "WRITEI_PART opened";
(* prelude = lines 1423-1438 verbatim (quotations rewritten), then xcf with the single-argument xcf.xcf_with_def *)
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
val ffi_post =
  "POSTv uv. &(UNIT_TYPE () uv) * W8ARRAY iobuff_loc ((0w :: n2w (MIN n k DIV 256)::n2w (MIN n k) :: n2w i :: rest)) * " ^
  "IOxV Inv (fsupdate fs fd 1 (MIN n k + pos) (TAKE pos content ++ " ^
  "TAKE (MIN n k) (MAP (CHR o w2n) (DROP i rest)) ++ DROP (MIN n k + pos) content))";
val _ = explore_head "WRITEI_V_branch1_xffi" (goal_of WRITEI_V)
  [("prelude", prelude, []),
   ("lnext0", sg (Q "Lnext_pos ll = 0") >-
                (fs[Lnext_pos_def,Once Lnext_def,liveFS_def,live_numchars_def,always_thm] \\ Cases_on (Q "ll") \\ fs[]), []),
   ("n2w2_into_iobuff", NTAC 2 ((xlet_auto \\ fs[n2w2_def,insert_atI_def]) >- xsimpl), []),
   ("xlet_ffi", xlet (Q ffi_post), []),
   ("unfold_pre (IOxV_def NEW)",
      qmatch_goalsub_abbrev_tac (Q " _ * _ * IOxV _ fs'") \\
      qpat_abbrev_tac (Q "Q = $POSTv _") \\
      simp [fs_ffi_part_def, IOxV_def, IOx_def, IO_def] \\
      xpull \\ qunabbrev_tac (Q "Q"), []),
   ("xffi", xffi \\ xsimpl, []),
   ("open_post (IOxV_def NEW)",
      fs[IOxV_def,IOFS_def,IOx_def,fs_ffi_part_def,mk_ffi_next_def,IO_def] \\
      qmatch_goalsub_abbrev_tac (Q "FFI_part st f ns") \\
      CONV_TAC(RESORT_EXISTS_CONV List.rev) \\
      map_every qexists_tac[Q "events", Q "ns", Q "f", Q "st"] \\ xsimpl \\
      qexists_tac (Q "n2w8 fd"), []),
   ("fs_big",
      fs[Abbr (Q "f"),Abbr (Q "st"),Abbr (Q "ns"),mk_ffi_next_def,w82n_n2w8,LENGTH_n2w8,
         ffi_write_def,MEM_MAP, ORD_BOUND,ORD_eq_0,wfFS_LDROP,
         dimword_8, MAP_MAP_o,o_DEF,char_BIJ,implode_explode,LENGTH_explode,
         HD_LUPDATE,LUPDATE_def,option_eq_some,validFD_def,write_def,
         get_fd_content_def] \\
      pairarg_tac \\ fs[] \\ xsimpl, []),
   ("rest_to_new_events",
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
      qexists_tac (Q "new_events"), []),
   ("xsimpl_after", xsimpl, []),
   ("invariant (NEW)",
      simp [Abbr (Q "new_events"), EVERY_APPEND] \\ first_x_assum irule \\ simp [],
      [fs [Abbr (Q "new_events"), EVERY_APPEND] \\ metis_tac [],
       rw [Abbr (Q "new_events"), EVERY_APPEND] \\ first_x_assum match_mp_tac \\ rw [] \\ fs [n2w2_def]])];

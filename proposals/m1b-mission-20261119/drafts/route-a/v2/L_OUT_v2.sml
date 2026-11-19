(* L-OUT at no_ext, v2 (worker Z6, graph link X9). DRAFT: NOT RUN. No HOL process was started.
   Nothing here is proved until a run ends with exit 0, EXACT_COMPLETE, no LEMMA_FAILED, no
   UNEXPECTED_CONTROL_ACCEPTANCE, the tag check and exactly four CLOSURE_AXIOM lines.
   Kind: MODEL. It relates the model's io_events to the model's stdout inode. The bytes of the REAL process on
   descriptor 1 are a different object (native relation, an ASSUMPTION). Not "verified native execution".

   Base: Y4 draft L_OUT_DRAFT.sml. Changes:
   - fd1_written now calls a helper write_chunk; same meaning as Y4 (MAP (\b. CHR (w2n (FST b))) is Y4's
     MAP (CHR o w2n o FST)); the conditions are Y4's: name «write», LENGTH conf = 8, w82n conf = 1,
     4 <= LENGTH bs, first returned byte 0w.
   - the replay invariant extract_no_ext_stdout (Y4's statement, unchanged) now has a full proof built from
     one lemma per FFI function of fs_ffi_part (open_in, open_out, read, write, close: the five names that
     extract_fs_with_numchars replays through fs_ffi_part) plus the two other branches of
     extract_fs_with_numchars: a basis name outside fs_ffi_part (get_arg_count, get_arg_length, get_arg, exit:
     state unchanged, no bytes) and a non-basis name or SharedMem (ext = no_ext answers Oracle_final, so the
     replay is NONE and the case is vacuous).
   - refund_L_OUT, refund_L_OUT_prefix, refund_profile_a_sl_fd1: Y4's statements; the last one is BUILT from
     the stored theorem's premise term (no retyping).
   Stored lemmas used (file:line in the pinned CakeML, CK = .toolchain/experiments/refund-cakeml-20261104/cakeml):
     basis_ffi.extract_fs_with_numchars_def  CK/basis/basis_ffiScript.sml 154-180
     basis_ffi.extract_fs_def                CK/basis/basis_ffiScript.sml 182-186 (OPTION_MAP numchars_fupd o SND)
     basis_ffi.no_ext_def                    CK/basis/basis_ffiScript.sml 115-118
     basis_ffi.is_basis_ffi_name_def         CK/basis/basis_ffiScript.sml 64-68
     fsFFI.fs_ffi_part_def                   CK/basis/fsFFIScript.sml 475-482
     fsFFI.ffi_write_def 333-349, ffi_read_def 307-327, ffi_close_def 351-363, ffi_open_in_def 265-280,
     ffi_open_out_def 288-301, write_def 214-230, read_def 187-197, closeFD_def 234-241, openFile_def 126-136,
     openFile_truncate_def 164-174, openFileFS_def 138-142, fsupdate_def 201-207, bumpFD_def 181-184,
     with_same_numchars 97-101, IO_fs_component_equality (datatype), inode_distinct (datatype)
     fsFFIProps.STD_streams_def 1310-1317, STD_streams_fsupdate 1319-1340, STD_streams_openFileFS 1344-1353,
     STD_streams_bumpFD 1397-1402, STD_streams_emptyFile 1750-1754, emptyFile_UStream 1709-1715,
     fastForwardFD_numchars 575-579                (CK/basis/fsFFIPropsScript.sml)
     TextIOProof.stdo_def 242-246, STD_streams_stdout 425-430, stdo_add_stdo 309-316, stdo_fastForwardFD
     695-705, add_stdo_numchars 361-365         (CK/basis/TextIOProofScript.sml)
     Marshalling.w22n_def 25-27, n2w2_def 12-14, w22n_n2w2 35-41 (CK/basis/MarshallingScript.sml)
     misc.OPTION_CHOICE_EQUALS_OPTION 2351-2356, misc.w2n_lt_256 1867-1869 (CK/misc/miscScript.sml)
     alist.AFUPDKEY_ALOOKUP, alist.ALOOKUP_ADELKEY (HOL/src/finite_maps/alistScript.sml 707, 785)
     forge_refundSlideProfileA.refund_profile_a_sl_every_machine_run (stored E4; e4-0001/stdout.log 296-331) *)
open preamble basis_ffiTheory fsFFITheory fsFFIPropsTheory TextIOProofTheory MarshallingTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (500, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundLOut";
val failed = ref ([] : string list);
val problems = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goalf tacf = (let val g = goalf () val th = save_thm (name, Tactical.TAC_PROOF (([], g), tacf ())) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
fun try_all name tacs =
  FIRST (map (fn t => t \\ NO_TAC) tacs)
  ORELSE (hd tacs \\ show_tac ("REMAINING " ^ name) \\ NO_TAC);
fun defn name q = (let val th = Define q in pr ("DEFINITION " ^ name ^ "\n" ^ thm_to_string th); th end)
  handle e => (pr ("DEFINITION_FAILED " ^ name ^ " " ^ General.exnMessage e); raise e);
val one_ne_zero8 = EVAL ``(1w:word8) = 0w``;
val CHOICE = miscTheory.OPTION_CHOICE_EQUALS_OPTION;
val SPE = DB.fetch "forge_refundSlideProfileA" "refund_profile_a_sl_every_machine_run";
val _ = pr ("USED refund_profile_a_sl_every_machine_run\n" ^ thm_to_string SPE);

(* ================= definitions ================= *)
val wc_def = defn "write_chunk"
  `write_chunk (conf:word8 list) (bs:(word8 # word8) list) =
     if LENGTH conf = 8 /\ w82n conf = 1 /\ 4 <= LENGTH bs /\ SND (HD bs) = 0w then
       TAKE (w22n [SND (EL 1 bs); SND (EL 2 bs)])
            (DROP (w22n [FST (EL 2 bs); FST (EL 3 bs)]) (MAP (\b. CHR (w2n (FST b))) (DROP 4 bs)))
     else []`;
val fdw_def = defn "fd1_written"
  `(fd1_written [] = []) /\
   (fd1_written (IO_event (ExtCall n) conf bs :: rest) =
      (if n = «write» then write_chunk conf bs else []) ++ fd1_written rest) /\
   (fd1_written (IO_event (SharedMem op) conf bs :: rest) = fd1_written rest)`;

val FDA = thm "fd1_written_APPEND"
  (fn () => ``!xs ys. fd1_written (xs ++ ys) = fd1_written xs ++ fd1_written ys``)
  (fn () => Induct \\ simp[fdw_def] \\ Cases \\ Cases_on `f` \\ simp[fdw_def]);
val FDP = thm "fd1_written_prefix"
  (fn () => ``!io' io. io' <<= io ==> fd1_written io' <<= fd1_written io``)
  (fn () => try_all "fd1_written_prefix"
     [rw[rich_listTheory.IS_PREFIX_APPEND] \\ simp[FDA],
      rpt strip_tac \\ fs[rich_listTheory.IS_PREFIX_APPEND] \\ simp[FDA],
      metis_tac[rich_listTheory.IS_PREFIX_APPEND, FDA]]);

(* ================= standard-stream facts ================= *)
val STDF = thm "STD_streams_facts"
  (fn () => ``!fs. STD_streams fs ==> ?inp out err.
       ALOOKUP fs.inode_tbl (UStream «stdout») = SOME out /\ ALOOKUP fs.inode_tbl (UStream «stderr») = SOME err /\
       ALOOKUP fs.infds 0 = SOME (UStream «stdin», ReadMode, inp) /\
       ALOOKUP fs.infds 1 = SOME (UStream «stdout», WriteMode, LENGTH out) /\
       ALOOKUP fs.infds 2 = SOME (UStream «stderr», WriteMode, LENGTH err) /\
       (!fd md off. ALOOKUP fs.infds fd = SOME (UStream «stdout», md, off) ==> fd = 1)``)
  (fn () => try_all "STD_streams_facts"
     [rw[STD_streams_def] \\ qexistsl_tac [`inp`,`out`,`err`] \\ simp[],
      rw[STD_streams_def] \\ metis_tac[]]);

val FD012 = thm "STD_streams_File_fd"
  (fn () => ``!fs fd f md off. STD_streams fs /\ ALOOKUP fs.infds fd = SOME (File f, md, off) ==>
                fd <> 0 /\ fd <> 1 /\ fd <> 2``)
  (fn () => rpt gen_tac \\ strip_tac \\ drule STDF \\ strip_tac \\ rpt conj_tac \\ strip_tac \\ gvs[]);

(* ================= write ================= *)
val W22LT = thm "w22n_lt"
  (fn () => ``!a b. w22n [a; b] < 65536``)
  (fn () => rw[w22n_def] \\ `w2n a < 256 /\ w2n b < 256` by simp[miscTheory.w2n_lt_256] \\ decide_tac);
val W22 = thm "w22n_n2w2_bytes"
  (fn () => ``!i. i < 65536 ==> w22n [n2w (i DIV 256); n2w i] = i``)
  (fn () => try_all "w22n_n2w2_bytes"
     [rpt strip_tac \\ mp_tac (Q.SPEC `i` w22n_n2w2) \\ simp[n2w2_def],
      rpt strip_tac \\ mp_tac (SIMP_RULE (srw_ss()) [n2w2_def] (Q.SPEC `i` w22n_n2w2)) \\ simp[]]);

val WRITE_STDOUT = thm "write_stdout"
  (fn () => ``!fd n chars fs nw fs1. STD_streams fs /\ fsFFI$write fd n chars fs = SOME (nw, fs1) ==>
       STD_streams fs1 /\ nw <= n /\
       !c0. ALOOKUP fs.inode_tbl (UStream «stdout») = SOME c0 ==>
            ALOOKUP fs1.inode_tbl (UStream «stdout») = SOME (if fd = 1 then c0 ++ TAKE nw chars else c0)``)
  (fn () => rpt gen_tac \\ strip_tac \\ drule STDF \\ strip_tac
     \\ gvs[fsFFITheory.write_def] \\ rpt (pairarg_tac \\ gvs[])
     \\ Cases_on `fd = 1`
     >- (gvs[] \\ rpt conj_tac
         >- (irule STD_streams_fsupdate \\ simp[listTheory.LENGTH_TAKE_EQ, listTheory.DROP_LENGTH_TOO_LONG, MIN_DEF] \\
             rw[] \\ gvs[MIN_DEF])
         \\ rpt strip_tac \\ gvs[fsupdate_def, alistTheory.AFUPDKEY_ALOOKUP, listTheory.DROP_LENGTH_TOO_LONG])
     \\ `ino <> UStream «stdout»` by (strip_tac \\ gvs[] \\ metis_tac[])
     \\ rpt conj_tac
     >- (irule STD_streams_fsupdate \\ simp[] \\ rw[] \\ gvs[] \\
         simp[listTheory.LENGTH_TAKE_EQ, listTheory.DROP_LENGTH_TOO_LONG, MIN_DEF] \\ rw[] \\ gvs[MIN_DEF])
     \\ rpt strip_tac \\ gvs[fsupdate_def, alistTheory.AFUPDKEY_ALOOKUP]);

val WCASES = thm "ffi_write_cases"
  (fn () => ``!conf bs fs fs1. ffi_write conf (MAP FST bs) fs = SOME (FFIreturn (MAP SND bs) fs1) ==>
       (?x0 x1 x2 x3 xs nw. bs = x0::x1::x2::x3::xs /\ LENGTH conf = 8 /\
          fsFFI$write (w82n conf) (w22n [FST x0; FST x1])
                (MAP (CHR o w2n) (DROP (w22n [FST x2; FST x3]) (MAP FST xs))) fs = SOME (nw, fs1) /\
          SND x0 = 0w /\ SND x1 = n2w (nw DIV 256) /\ SND x2 = n2w nw) \/
       (fs1 = fs /\ ?x0 xs. bs = x0::xs /\ SND x0 = 1w)``)
  (fn () => try_all "ffi_write_cases"
     [rpt gen_tac \\ strip_tac \\
        gvs[ffi_write_def, AllCaseEqs(), listTheory.MAP_EQ_CONS, CHOICE, n2w2_def] \\
        rpt (pairarg_tac \\ gvs[n2w2_def]) \\ simp[],
      rpt gen_tac \\ strip_tac \\
        gvs[ffi_write_def, AllCaseEqs(), listTheory.MAP_EQ_CONS, CHOICE, n2w2_def] \\
        rpt (pairarg_tac \\ gvs[n2w2_def]) \\ metis_tac[],
      rpt gen_tac \\ simp[ffi_write_def] \\ every_case_tac \\ simp[CHOICE] \\ strip_tac \\
        gvs[listTheory.MAP_EQ_CONS, n2w2_def] \\ rpt (pairarg_tac \\ gvs[n2w2_def]) \\ simp[]]);

val WSTEP = thm "ffi_write_stdout_step"
  (fn () => ``!conf bs fs fs1. STD_streams fs /\ ffi_write conf (MAP FST bs) fs = SOME (FFIreturn (MAP SND bs) fs1) ==>
       STD_streams fs1 /\ !c0. ALOOKUP fs.inode_tbl (UStream «stdout») = SOME c0 ==>
            ALOOKUP fs1.inode_tbl (UStream «stdout») = SOME (c0 ++ write_chunk conf bs)``)
  (fn () => rpt gen_tac \\ strip_tac \\ drule WCASES \\ strip_tac
     >- (gvs[] \\ drule_all WRITE_STDOUT \\ strip_tac \\ simp[] \\ rpt strip_tac
         \\ qpat_x_assum `!c0. _ ==> _` drule \\ disch_then SUBST1_TAC
         \\ `nw < 65536` by (qspecl_then [`FST x0`, `FST x1`] assume_tac W22LT \\ decide_tac)
         \\ simp[wc_def, W22] \\ rw[]
         \\ simp[listTheory.MAP_DROP, listTheory.MAP_MAP_o, combinTheory.o_DEF])
     \\ gvs[wc_def, one_ne_zero8]);

(* ================= read, open_in, open_out, close ================= *)
val READ_STDOUT = thm "read_stdout"
  (fn () => ``!fd n fs l fs1. STD_streams fs /\ fsFFI$read fd fs n = SOME (l, fs1) ==>
       STD_streams fs1 /\ fs1.inode_tbl = fs.inode_tbl``)
  (fn () => rpt gen_tac \\ strip_tac \\ drule STDF \\ strip_tac
     \\ gvs[fsFFITheory.read_def] \\ rpt (pairarg_tac \\ gvs[])
     \\ `fd <> 1 /\ fd <> 2` by (rpt strip_tac \\ gvs[])
     \\ conj_tac >- simp[STD_streams_bumpFD]
     \\ simp[bumpFD_def]);

val RSTEP = thm "ffi_read_stdout_step"
  (fn () => ``!conf bytes out fs fs1. STD_streams fs /\ ffi_read conf bytes fs = SOME (FFIreturn out fs1) ==>
       STD_streams fs1 /\ ALOOKUP fs1.inode_tbl (UStream «stdout») = ALOOKUP fs.inode_tbl (UStream «stdout»)``)
  (fn () => try_all "ffi_read_stdout_step"
     [rpt gen_tac \\ strip_tac \\ gvs[ffi_read_def, AllCaseEqs(), CHOICE] \\ rpt (pairarg_tac \\ gvs[]) \\
        FIRST [drule_all READ_STDOUT \\ simp[] \\ NO_TAC, gvs[] \\ NO_TAC],
      rpt gen_tac \\ simp[ffi_read_def] \\ every_case_tac \\ simp[CHOICE] \\ strip_tac \\ gvs[] \\
        rpt (pairarg_tac \\ gvs[]) \\ FIRST [drule_all READ_STDOUT \\ simp[] \\ NO_TAC, gvs[] \\ NO_TAC]]);

val OPENF = thm "openFile_stdout"
  (fn () => ``!s fs md pos fd fs1. STD_streams fs /\ openFile s fs md pos = SOME (fd, fs1) ==>
       STD_streams fs1 /\ fs1.inode_tbl = fs.inode_tbl``)
  (fn () => rpt gen_tac \\ strip_tac \\ conj_tac
     >- (`fs1 = openFileFS s fs md pos` by simp[openFileFS_def] \\ pop_assum SUBST1_TAC \\
         irule (GEN_ALL STD_streams_openFileFS) \\ simp[])
     \\ gvs[openFile_def]);

val OPENT = thm "openFile_truncate_stdout"
  (fn () => ``!s fs md fd fs1. STD_streams fs /\ openFile_truncate s fs md = SOME (fd, fs1) ==>
       STD_streams fs1 /\ ALOOKUP fs1.inode_tbl (UStream «stdout») = ALOOKUP fs.inode_tbl (UStream «stdout»)``)
  (fn () => rpt gen_tac \\ strip_tac
     \\ `openFile s (emptyFile fs s) md 0 = SOME (fd, fs1)` by
          (qpat_x_assum `openFile_truncate _ _ _ = _` mp_tac \\ simp[openFile_truncate_def, openFile_def])
     \\ `STD_streams (emptyFile fs s)` by simp[]
     \\ drule_all OPENF \\ simp[]);

val OISTEP = thm "ffi_open_in_stdout_step"
  (fn () => ``!conf bytes out fs fs1. STD_streams fs /\ ffi_open_in conf bytes fs = SOME (FFIreturn out fs1) ==>
       STD_streams fs1 /\ ALOOKUP fs1.inode_tbl (UStream «stdout») = ALOOKUP fs.inode_tbl (UStream «stdout»)``)
  (fn () => rpt gen_tac \\ strip_tac \\ gvs[ffi_open_in_def, CHOICE] \\ rpt (pairarg_tac \\ gvs[]) \\
     FIRST [drule_all OPENF \\ simp[] \\ NO_TAC, gvs[] \\ NO_TAC]);

val OOSTEP = thm "ffi_open_out_stdout_step"
  (fn () => ``!conf bytes out fs fs1. STD_streams fs /\ ffi_open_out conf bytes fs = SOME (FFIreturn out fs1) ==>
       STD_streams fs1 /\ ALOOKUP fs1.inode_tbl (UStream «stdout») = ALOOKUP fs.inode_tbl (UStream «stdout»)``)
  (fn () => rpt gen_tac \\ strip_tac \\ gvs[ffi_open_out_def, CHOICE] \\ rpt (pairarg_tac \\ gvs[]) \\
     FIRST [drule_all OPENT \\ simp[] \\ NO_TAC, gvs[] \\ NO_TAC]);

val ADEL = thm "STD_streams_ADELKEY_File"
  (fn () => ``!fs fd f md off. STD_streams fs /\ ALOOKUP fs.infds fd = SOME (File f, md, off) ==>
       STD_streams (fs with infds := ADELKEY fd fs.infds)``)
  (fn () => rpt gen_tac \\ strip_tac \\ drule_all FD012 \\ strip_tac \\
     try_all "STD_streams_ADELKEY_File"
       [gvs[STD_streams_def] \\ qexistsl_tac [`inp`,`out`,`err`] \\ simp[alistTheory.ALOOKUP_ADELKEY] \\ rw[] \\ gvs[],
        gvs[STD_streams_def] \\ qexistsl_tac [`inp`,`out`,`err`] \\ simp[alistTheory.ALOOKUP_ADELKEY] \\
          rw[] \\ rw[EQ_IMP_THM] \\ gvs[] \\ metis_tac[],
        fs[STD_streams_def] \\ simp[alistTheory.ALOOKUP_ADELKEY] \\ metis_tac[]]);

val CLOSEF = thm "closeFD_stdout"
  (fn () => ``!fd fs x fs1. STD_streams fs /\ closeFD fd fs = SOME (x, fs1) ==>
       STD_streams fs1 /\ fs1.inode_tbl = fs.inode_tbl``)
  (fn () => rpt gen_tac \\ strip_tac \\ gvs[closeFD_def] \\ rpt (pairarg_tac \\ gvs[]) \\
     try_all "closeFD_stdout" [drule_all ADEL \\ simp[], simp[] \\ irule ADEL \\ simp[] \\ metis_tac[], metis_tac[ADEL]]);

val CSTEP = thm "ffi_close_stdout_step"
  (fn () => ``!conf bytes out fs fs1. STD_streams fs /\ ffi_close conf bytes fs = SOME (FFIreturn out fs1) ==>
       STD_streams fs1 /\ ALOOKUP fs1.inode_tbl (UStream «stdout») = ALOOKUP fs.inode_tbl (UStream «stdout»)``)
  (fn () => rpt gen_tac \\ strip_tac \\ gvs[ffi_close_def, CHOICE] \\ rpt (pairarg_tac \\ gvs[]) \\
     FIRST [drule_all CLOSEF \\ simp[] \\ NO_TAC, gvs[] \\ NO_TAC]);

(* ================= dispatch over fs_ffi_part ================= *)
val AFP = thm "ALOOKUP_fs_ffi_part"
  (fn () => ``!n f. ALOOKUP (SND (SND fs_ffi_part)) n = SOME f <=>
       (n = «open_in» /\ f = ffi_open_in) \/ (n = «open_out» /\ f = ffi_open_out) \/
       (n = «read» /\ f = ffi_read) \/ (n = «write» /\ f = ffi_write) \/ (n = «close» /\ f = ffi_close)``)
  (fn () => try_all "ALOOKUP_fs_ffi_part"
     [rpt gen_tac \\ simp[fs_ffi_part_def] \\ rw[] \\ gvs[] \\ metis_tac[],
      rpt gen_tac \\ simp[fs_ffi_part_def] \\ rw[] \\ eq_tac \\ rw[] \\ gvs[],
      rpt gen_tac \\ simp[fs_ffi_part_def, AllCaseEqs()] \\ eq_tac \\ rw[] \\ gvs[]]);

val FSTEP = thm "fs_ffi_part_stdout_step"
  (fn () => ``!n f conf bs fs fs1. STD_streams fs /\ ALOOKUP (SND (SND fs_ffi_part)) n = SOME f /\
       f conf (MAP FST bs) fs = SOME (FFIreturn (MAP SND bs) fs1) ==>
       STD_streams fs1 /\ !c0. ALOOKUP fs.inode_tbl (UStream «stdout») = SOME c0 ==>
         ALOOKUP fs1.inode_tbl (UStream «stdout») = SOME (c0 ++ (if n = «write» then write_chunk conf bs else []))``)
  (fn () => rpt gen_tac \\ strip_tac \\ gvs[AFP] \\
     FIRST (map (fn th => drule_all th \\ simp[] \\ NO_TAC) [WSTEP, RSTEP, OISTEP, OOSTEP, CSTEP]));

(* ================= one replay step, and the invariant ================= *)
val EXTC = thm "extract_no_ext_ExtCall"
  (fn () => ``!n conf bs io st r.
       extract_fs_with_numchars no_ext st (IO_event (ExtCall n) conf bs :: io) = SOME r ==>
       (?f fs1. ALOOKUP (SND (SND fs_ffi_part)) n = SOME f /\
                f conf (MAP FST bs) (SND st) = SOME (FFIreturn (MAP SND bs) fs1) /\
                extract_fs_with_numchars no_ext (FST st, fs1) io = SOME r) \/
       (ALOOKUP (SND (SND fs_ffi_part)) n = NONE /\ is_basis_ffi_name n /\
        extract_fs_with_numchars no_ext st io = SOME r)``)
  (fn () => try_all "extract_no_ext_ExtCall"
     [rpt gen_tac \\ simp[Once extract_fs_with_numchars_def, no_ext_def] \\ every_case_tac \\ simp[],
      rpt gen_tac \\ simp[Once extract_fs_with_numchars_def, no_ext_def] \\ every_case_tac \\ rw[] \\ metis_tac[],
      rpt gen_tac \\ simp[Once extract_fs_with_numchars_def, no_ext_def] \\ strip_tac \\ gvs[AllCaseEqs()]]);

(* Y4's statement, unchanged *)
val INV = thm "extract_no_ext_stdout"
  (fn () => ``!io cls fs cls' fs'.
       extract_fs_with_numchars no_ext (cls,fs) io = SOME (cls',fs') /\ STD_streams fs ==>
       STD_streams fs' /\
       !c0. ALOOKUP fs.inode_tbl (UStream «stdout») = SOME c0 ==>
            ALOOKUP fs'.inode_tbl (UStream «stdout») = SOME (c0 ++ fd1_written io)``)
  (fn () => Induct
     >- try_all "extract_no_ext_stdout_nil" [simp[extract_fs_with_numchars_def, fdw_def],
                                              rw[extract_fs_with_numchars_def, fdw_def] \\ gvs[]]
     \\ Cases \\ Cases_on `f`
     >- ((* ExtCall: through fs_ffi_part, or a basis name outside it *)
         rename1 `IO_event (ExtCall nm) cf bs0`
         \\ rpt gen_tac \\ strip_tac \\ drule EXTC \\ strip_tac
         >- (gvs[] \\ drule_all FSTEP \\ strip_tac
             \\ first_x_assum drule_all \\ strip_tac
             \\ conj_tac >- simp[]
             \\ rpt strip_tac \\ simp[fdw_def]
             \\ qpat_x_assum `!c0. ALOOKUP fs.inode_tbl _ = SOME c0 ==> _` drule \\ strip_tac
             \\ qpat_x_assum `!c0. ALOOKUP fs1.inode_tbl _ = SOME c0 ==> _` drule \\ simp[])
         \\ `nm <> «write»` by (strip_tac \\ gvs[fs_ffi_part_def])
         \\ gvs[] \\ first_x_assum drule_all \\ simp[fdw_def])
     \\ (* SharedMem: no_ext answers Oracle_final, the replay is NONE *)
     rpt gen_tac \\ simp[Once extract_fs_with_numchars_def, no_ext_def]);

val EFS = thm "extract_fs_inode_tbl"
  (fn () => ``!cl fs io fsx. extract_fs no_ext (cl,fs) io = SOME fsx ==>
       ?cls' fs'. extract_fs_with_numchars no_ext (cl,fs) io = SOME (cls',fs') /\ fsx.inode_tbl = fs'.inode_tbl``)
  (fn () => try_all "extract_fs_inode_tbl"
     [rw[extract_fs_def] \\ rename1 `SOME zz` \\ PairCases_on `zz` \\ gvs[],
      rpt gen_tac \\ simp[extract_fs_def, PULL_EXISTS] \\ Cases \\ simp[],
      rw[extract_fs_def] \\ Cases_on `extract_fs_with_numchars no_ext (cl,fs) io` \\ gvs[] \\
        rename1 `SOME zz` \\ PairCases_on `zz` \\ gvs[]]);

(* L-OUT (Y4's statement, unchanged) *)
val LOUT = thm "refund_L_OUT"
  (fn () => ``!cl fs io out. STD_streams fs /\
       extract_fs no_ext (cl,fs) io = SOME (add_stdout (fastForwardFD fs 0) out) ==>
       fd1_written io = explode out``)
  (fn () => rpt gen_tac \\ strip_tac
     \\ drule EFS \\ strip_tac
     \\ drule_all INV \\ strip_tac
     \\ drule STD_streams_stdout \\ disch_then (qx_choose_then `init` assume_tac)
     \\ `ALOOKUP fs.inode_tbl (UStream «stdout») = SOME (explode init)` by fs[stdo_def]
     \\ qpat_x_assum `!c0. _ ==> _` drule \\ strip_tac
     \\ `stdo 1 "stdout" (fastForwardFD fs 0) init` by simp[stdo_fastForwardFD]
     \\ `stdo 1 "stdout" (add_stdo 1 "stdout" (fastForwardFD fs 0) out) (strcat init out)` by
          (irule (GEN_ALL stdo_add_stdo) \\ simp[])
     \\ try_all "refund_L_OUT_end"
          [gvs[stdo_def, mlstringTheory.strcat_thm],
           fs[stdo_def, mlstringTheory.strcat_thm] \\ rfs[] \\ gvs[]]);

val LOUTP = thm "refund_L_OUT_prefix"
  (fn () => ``!cl fs io io' out. STD_streams fs /\ io' <<= io /\
       extract_fs no_ext (cl,fs) io = SOME (add_stdout (fastForwardFD fs 0) out) ==>
       fd1_written io' <<= explode out``)
  (fn () => try_all "refund_L_OUT_prefix"
     [rpt strip_tac \\ drule_all LOUT \\ disch_then (SUBST1_TAC o SYM) \\ irule FDP \\ simp[],
      metis_tac[LOUT, FDP]]);

(* ================= composition with the stored final theorem, ext := no_ext ================= *)
val (PREM, _) = dest_imp (concl (SPEC_ALL SPE));
val EXTV = valOf (List.find (fn v => fst (dest_var v) = "ext") (free_vars (concl (SPEC_ALL SPE))));
val _ = pr ("EXT_VARIABLE " ^ term_to_string EXTV ^ " : " ^ type_to_string (type_of EXTV));
val R = find_term (fn t => (fst (dest_const (fst (strip_comb t))) = "refund_render_fields") handle _ => false) (concl SPE);
val _ = pr ("RENDER_TERM " ^ term_to_string R);
val FD1 = thm "refund_profile_a_sl_fd1"
  (fn () => ``^PREM ==>
     ?ms. (arm8_run 27 s = SOME ms /\ ms.PC = sl + 0x1000040D0w) /\
       !b. machine_sem (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi no_ext cl fs) ms b ==>
         ?t io. b = Terminate t io /\
           ((t = Success /\ fd1_written io = explode ^R) \/
            (t = Resource_limit_hit /\ fd1_written io <<= explode ^R))``)
  (fn () => strip_tac
     \\ mp_tac (INST [EXTV |-> ``no_ext``] (SPEC_ALL SPE))
     \\ impl_tac >- simp[]
     \\ strip_tac \\ qexists_tac `ms` \\ simp[]
     \\ qx_gen_tac `bb` \\ strip_tac
     \\ qpat_x_assum `!b. _` (qspec_then `bb` mp_tac) \\ simp[]
     \\ strip_tac \\ gvs[]
     \\ try_all "refund_profile_a_sl_fd1_end" [metis_tac[LOUT, LOUTP], simp[] \\ metis_tac[LOUT, LOUTP]]);

(* ================= NEGATIVE CONTROLS ================= *)
val fs0_def = defn "fs0"
  `fs0 = <| inode_tbl := [(UStream «stdin», ""); (UStream «stdout», ""); (UStream «stderr», "")];
            files := []; infds := [(0,(UStream «stdin»,ReadMode,0)); (1,(UStream «stdout»,WriteMode,0));
                                   (2,(UStream «stderr»,WriteMode,0))];
            numchars := LNIL; maxFD := 3 |>`;
val ext_bad_def = defn "ext_bad"
  `ext_bad = \(n:ffiname) (st:mlstring list # IO_fs) (c:word8 list) (b:word8 list).
               Oracle_return (FST st, add_stdout (fastForwardFD (SND st) 0) «a») ([]:word8 list)`;
val STD0 = thm "STD_streams_fs0" (fn () => ``STD_streams fs0``)
  (fn () => rw[STD_streams_def] \\ qexists_tac `0` \\ rw[fs0_def] \\ rw[] \\ rw[EQ_IMP_THM]);
(* N-O1: with a free ext, L-OUT is FALSE (one non-basis event rewrites stdout; fd1_written sees nothing) *)
val NO1 = thm "N_O1_free_ext_breaks"
  (fn () => ``STD_streams fs0 /\
     extract_fs ext_bad ([],fs0) [IO_event (ExtCall «x») [] []] = SOME (add_stdout (fastForwardFD fs0 0) «a») /\
     fd1_written [IO_event (ExtCall «x») [] []] <> explode «a»``)
  (fn () => rpt conj_tac
     >- ACCEPT_TAC STD0
     >- try_all "N_O1_replay"
          [simp[extract_fs_def, extract_fs_with_numchars_def, ext_bad_def, is_basis_ffi_name_def, fs_ffi_part_def,
                IO_fs_component_equality],
           simp[extract_fs_def, extract_fs_with_numchars_def, ext_bad_def, is_basis_ffi_name_def, fs_ffi_part_def] \\
             simp[IO_fs_component_equality]]
     \\ simp[fdw_def]);
(* N-O2: dropping the success test counts a FAILED write (fs0 has numchars = LNIL, so write fails) *)
val wcns_def = defn "write_chunk_nosucc"
  `write_chunk_nosucc (conf:word8 list) (bs:(word8 # word8) list) =
     if LENGTH conf = 8 /\ w82n conf = 1 /\ 4 <= LENGTH bs then
       TAKE (w22n [SND (EL 1 bs); SND (EL 2 bs)])
            (DROP (w22n [FST (EL 2 bs); FST (EL 3 bs)]) (MAP (\b. CHR (w2n (FST b))) (DROP 4 bs)))
     else []`;
val wcnf_def = defn "write_chunk_nofd"
  `write_chunk_nofd (conf:word8 list) (bs:(word8 # word8) list) =
     if LENGTH conf = 8 /\ 4 <= LENGTH bs /\ SND (HD bs) = 0w then
       TAKE (w22n [SND (EL 1 bs); SND (EL 2 bs)])
            (DROP (w22n [FST (EL 2 bs); FST (EL 3 bs)]) (MAP (\b. CHR (w2n (FST b))) (DROP 4 bs)))
     else []`;
val NO2 = thm "N_O2_failed_write_counted_without_success_test"
  (fn () => ``extract_fs_with_numchars no_ext ([],fs0)
       [IO_event (ExtCall «write») (n2w8 1) (ZIP ([0w;1w;0w;0w;97w],[1w;1w;0w;0w;97w]))] = SOME ([],fs0) /\
     write_chunk (n2w8 1) (ZIP ([0w;1w;0w;0w;97w],[1w;1w;0w;0w;97w])) = "" /\
     write_chunk_nosucc (n2w8 1) (ZIP ([0w;1w;0w;0w;97w],[1w;1w;0w;0w;97w])) = "a"``)
  (fn () => try_all "N_O2"
     [EVAL_TAC,
      simp[extract_fs_with_numchars_def, fs_ffi_part_def, ffi_write_def, write_def, fs0_def, n2w8_def, w82n_def,
           w22n_def, CHOICE, wc_def, wcns_def] \\ EVAL_TAC]);
(* N-O3: dropping the descriptor test counts an fd-2 (stderr) write. Chunk-level witness: a successful
   fd-2 event (after-bytes 0w :: n2w2 1 ++ [0w; 97w]) gives "a" without the fd test and "" with it.
   That an fd-2 write leaves stdout unchanged is the fd <> 1 branch of write_stdout above. *)
val NO3 = thm "N_O3_fd2_write_counted_without_fd_test"
  (fn () => ``write_chunk (n2w8 2) (ZIP ([0w;1w;0w;0w;97w],[0w;0w;1w;0w;97w])) = "" /\
              write_chunk_nofd (n2w8 2) (ZIP ([0w;1w;0w;0w;97w],[0w;0w;1w;0w;97w])) = "a"``)
  (fn () => EVAL_TAC);

(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
fun lit name th tm = if aconv (concl th) tm then pr ("CONTROL_OK " ^ name ^ " statement is the literal planned statement")
                     else bad (name ^ "-literal");
val _ = lit "refund_L_OUT" LOUT ``!cl fs io out. STD_streams fs /\
       extract_fs no_ext (cl,fs) io = SOME (add_stdout (fastForwardFD fs 0) out) ==> fd1_written io = explode out``;
val _ = if aconv (fst (dest_imp (concl FD1))) PREM then pr "CONTROL_OK refund_profile_a_sl_fd1 premise is the stored premise term"
        else bad "FD1-premise";
val _ = if Term.free_in ``no_ext`` (concl FD1) andalso not (Lib.mem "ext" (map (fst o dest_var) (free_vars (concl FD1))))
        then pr "CONTROL_OK refund_profile_a_sl_fd1 is at ext := no_ext (no free ext)" else bad "FD1-ext";
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundLOut" @ DB.definitions "forge_refundLOut");
val closure = "forge_refundLOut" :: Theory.ancestry "forge_refundLOut";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundLOut")));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions "forge_refundLOut")));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

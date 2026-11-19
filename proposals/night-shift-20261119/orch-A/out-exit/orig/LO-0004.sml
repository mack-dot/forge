(* L-OUT at no_ext, v5 (worker A3). DRAFT: NOT RUN. Base: LO-0003.sml (SHA-256 4bc9910a7b17a735c340ab8e27d728587a3a5db497b70e4a3ba68ceefbfd5cc7,
   = v4 + orchestrator ML edits). Changes marked (* A3 tactic-only v5 *); no statement changed; every tactic UNCHECKED.
   Real failures repaired: read_stdout (stdout:140), refund_profile_a_sl_fd1 (stdout:249). Failed lemmas now become
   ASSUME of their statement (diagnostic; never stored; export still forbidden after any failure). *)
(* L-OUT at no_ext, v4 (worker A3). DRAFT: NOT RUN. v4 = v3 (SHA-256 553233ce...0a61, run as LO-0001: CPU limit,
   stdout ends after CHECKED STD_streams_facts) with changes marked (* A3 tactic-only v4 *): flushed output,
   BEGIN/END lines, Timeout.apply limits per lemma (240 s) and per alternative (60 s), and tame_uniq after
   every drule STDF. No statement changed. Every tactic is UNCHECKED.
   ---------------------------------------------------------------------------------------------------
   L-OUT at no_ext, v3 (worker A3, Night-Shift Orchestrator A). No HOL process was started.
   v3 = v2 (SHA-256 153885ba70f3e451f2f1516d36e617dec214fd9ed3be781b1b04de99e72a3c0d) with tactic/ML repairs.
   Every repair is marked (* A3 tactic-only *). No statement of a v2 lemma changed. One lemma was ADDED:
   P_O4_partial_write_counts_nw (a positive control; statement in the A3 report (handback text)). Every tactic is UNCHECKED.
   Repairs (details and file:line evidence in the A3 report (handback text)):
   - D1 (certain): v2 instantiated ext with ``no_ext`` parsed alone. no_ext is polymorphic (result type
     'a oracle_result, basis_ffiTheory.html / basis_ffiScript.sml 103-106), so INST fails on the type.
     v3 builds NOEXT with mk_thy_const at the type of the variable ext. The free_in check uses NOEXT too.
   - D2 (high): v2 refund_L_OUT used drule STD_streams_stdout after drule_all INV; drule takes the newest
     STD_streams assumption (fs', not fs). v3 picks STD_streams fs by name.
   - D3 (medium): ffi_write_cases needs LUPDATE_def (tagged [userdef], not [simp]; listScript.sml 3944).
   - D4 (medium): Cases_on `f` relies on the auto-name of the ffiname variable; v3 renames first.
   - D5 (low): gvs[AFP] must split a 5-way disjunction; v3 splits it with strip_assume_tac first.
   - D6 (low): impl_tac >- simp[] replaced by MP with the stored premise term (exact).
   v2 header follows.
   ---------------------------------------------------------------------------------------------------
   L-OUT at no_ext, v2 (worker Z6, graph link X9). DRAFT: NOT RUN. No HOL process was started.
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
(* A3 tactic-only v4: flush after every line, so a stopped run shows where it stopped. *)
fun pr s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut);
(* A3 tactic-only v4: time limits. Timeout.apply is HOL's portable timeout
   (HOL/src/portableML/poly/concurrent/Timeout.sml:12-31; sig HOL/sigobj/Timeout.sig). It raises
   Timeout.TIMEOUT. A failed load stops the script here, before any proof, with a clear line. *)
val _ = (load "Timeout"; pr "TIMEOUT_HELPER Timeout.apply loaded")
  handle e => (pr ("TIMEOUT_LOAD_FAILED " ^ General.exnMessage e); raise e);
val ALT_SECS = 60;     (* one try_all alternative *)
val LEMMA_SECS = 240;  (* one whole lemma *)
(* Orchestrator A, LO-0003 (ML-only): a tactic is goal -> Context.t -> ...; the limit must cover the application to the context. *)
(* A3 tactic-only v5: the whole application (tac g ctxt) runs inside the limit; type tactic =
   goal -> Context.t -> goal list * validation (HOL/src/1/Abbrev.sig:10). *)
fun tlim secs (tac : tactic) : tactic = fn g => fn ctxt =>
  Timeout.apply (Time.fromSeconds (Int.toLarge secs)) (fn () => tac g ctxt) ()
  handle Timeout.TIMEOUT _ => (pr ("TIMEOUT_ALT after " ^ Int.toString secs ^ " s");
                               raise mk_HOL_ERR "A3" "tlim" "time limit");
(* The timer interrupts this thread; make sure interrupts are delivered asynchronously (Poly/ML Thread API). *)
(* Orchestrator A, LO-0003 (ML-only): the line that set thread attributes is removed (Thread.Thread is not declared in
   this context; LO-0002 static error). Timeout.apply restores the caller's attributes itself (Timeout.sml:13-22). *)
val _ = pr "INTERRUPTS not changed by the script";
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
(* A3 tactic-only v5: helpers as in A2's prefix_lemma_v4.sml:56-71 (same types).
   metisTools.limit : {time : real option, infs : int option} ref (A2: HOL/src/metis/metisTools.sml 281). *)
val _ = metisTools.limit := {time = SOME 30.0, infs = NONE};
fun trunc n s = if size s <= n then s else String.substring (s, 0, n) ^ " ...";
fun showg tag (asl, w) = (pr ("SHOW " ^ tag);
   List.app (fn a => pr ("  ASM " ^ trunc 700 (term_to_string a))) asl;
   pr ("  GOAL " ^ trunc 3000 (term_to_string w)));
(* show_tac : string -> tactic *)
fun show_tac tag g = (showg tag g; ALL_TAC g);
(* ST : string -> tactic -> tactic. Runs tac; on an exception prints the goal of that stage, then re-raises. *)
fun ST tag (tac : tactic) : tactic = fn g => fn ctxt => tac g ctxt
  handle e => (showg ("STAGE_FAILED " ^ tag ^ " : " ^ trunc 300 (General.exnMessage e)) g; raise e);
(* CL : string -> tactic -> tactic. tac must close the goal; else print every goal left and fail (HOL_ERR). *)
fun CL tag (tac : tactic) : tactic = fn g => fn ctxt =>
  let val r as (gs, _) = ST tag tac g ctxt in
    if null gs then r
    else (List.app (showg ("UNSOLVED " ^ tag)) gs; raise mk_HOL_ERR "A3" "CL" ("unsolved goals at " ^ tag))
  end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundLOut";
val failed = ref ([] : string list);
val problems = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
(* A3 tactic-only v5: BEGIN/END lines; a time limit per lemma; a failed lemma becomes ASSUME of its own
   statement (a theorem WITH a hypothesis), as in A2's prefix_lemma_v4.sml:79-97. A later proof that closes only
   through such a hypothesis prints DIAG_OK_UNDER and is NOT stored (it is counted as failed). Nothing with a
   hypothesis is saved; the run raises Fail before export_theory when any lemma failed.
   TAC_PROOF does not check hypotheses (HOL/src/1/Tactical.sml:75-89), so the hypothesis survives to this test. *)
val failed_stmts = ref ([] : (string * term) list);
val diag = ref ([] : string list);
fun names_of_hyps th = map (fn h => case List.find (fn (_, t) => aconv t h) (!failed_stmts) of
                                      SOME (n, _) => n | NONE => "?" ^ trunc 80 (term_to_string h)) (hyp th);
(* thm : string -> (unit -> term) -> (unit -> tactic) -> thm *)
fun thm name goalf tacf =
  let val _ = pr ("BEGIN " ^ name)
      val t0 = Time.now ()
      val g = goalf ()
      fun fail_with msg = (pr ("LEMMA_FAILED " ^ name ^ " " ^ msg); failed := name :: !failed;
                           failed_stmts := (name, g) :: !failed_stmts; ASSUME g)
      val pf = Timeout.apply (Time.fromSeconds (Int.toLarge LEMMA_SECS)) Tactical.TAC_PROOF
  in
    (let val th0 = pf (([], g), tacf ()) in
       if null (hyp th0) then
         (let val th = save_thm (name, th0) in
            chk name th; pr ("END " ^ name ^ " " ^ Time.toString (Time.- (Time.now (), t0)) ^ " s"); th end)
       else (pr ("DIAG_OK_UNDER " ^ name ^ " assumed: " ^ String.concatWith " " (names_of_hyps th0));
             diag := name :: !diag; fail_with "(diagnostic only: proved only under the failed lemmas above)")
     end)
    handle Timeout.TIMEOUT _ => fail_with ("TIMEOUT " ^ Int.toString LEMMA_SECS ^ " s")
         | e => fail_with (General.exnMessage e)
  end
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " (statement) " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
(* try_all : string -> tactic list -> tactic. Each alternative under ALT_SECS. Only HOL_ERR is caught, so a
   lemma-level interrupt is never swallowed. On failure: print the entry goal, then what the first alternative leaves. *)
fun try_all name (tacs : tactic list) : tactic = fn g => fn ctxt =>
  FIRST (map (fn t => tlim ALT_SECS (t \\ NO_TAC)) tacs) g ctxt
  handle e as HOL_ERR _ => (showg ("TRY_ALL_ENTRY " ^ name) g;
                            tlim ALT_SECS (hd tacs \\ show_tac ("REMAINING " ^ name) \\ NO_TAC) g ctxt);
fun defn name q = (let val _ = pr ("BEGIN_DEFINITION " ^ name) val th = Define q in pr ("DEFINITION " ^ name ^ "\n" ^ thm_to_string th); th end)
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
  (fn () => try_all "fd1_written_APPEND"   (* A3 tactic-only: rename before the case split (D4) *)
     [Induct \\ simp[fdw_def] \\ Cases \\ rename1 `IO_event ff _ _` \\ Cases_on `ff` \\ simp[fdw_def],
      Induct \\ simp[fdw_def] \\ Cases \\ Cases_on `f` \\ simp[fdw_def],
      Induct \\ rw[fdw_def] \\ Cases_on `h` \\ rename1 `IO_event ff _ _` \\ Cases_on `ff` \\ simp[fdw_def]]);
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

(* A3 tactic-only v4. CAUSE of the LO-0001 stop (CPU limit, stdout ends after CHECKED STD_streams_facts):
   STDF's last conjunct, once an assumption, is  !fd md off. ALOOKUP fs.infds fd = SOME (UStream «stdout»,md,off)
   ==> fd = 1 . Its conclusion has a bare VARIABLE (fd) on the left. gvs/fs/simp turn it into a conditional
   rewrite of any number to 1, and the side condition is again an ALOOKUP term with numbers in it: the most
   probable non-terminating rewrite. v4 replaces it, right after drule STDF, by its contrapositive
   !fd md off. fd <> 1 ==> ALOOKUP fs.infds fd <> SOME (UStream «stdout»,md,off)
   (left-hand side ALOOKUP ...; no variable LHS). Same content (CONTRAPOS, GENL). *)
val tame_uniq : tactic =
  qpat_x_assum `!fd md off. _ ==> fd = 1`
    (fn th => let val (vs, _) = strip_forall (concl th)
              in assume_tac (GENL vs (CONTRAPOS (SPEC_ALL th))) end);
val FD012 = thm "STD_streams_File_fd"
  (fn () => ``!fs fd f md off. STD_streams fs /\ ALOOKUP fs.infds fd = SOME (File f, md, off) ==>
                fd <> 0 /\ fd <> 1 /\ fd <> 2``)
  (fn () => try_all "STD_streams_File_fd"   (* A3 tactic-only v4: tame_uniq; no gvs *)
     [rpt gen_tac \\ strip_tac \\ drule STDF \\ strip_tac \\ tame_uniq
        \\ rpt conj_tac \\ strip_tac \\ rveq \\ fs[],
      rpt gen_tac \\ strip_tac \\ drule STDF \\ strip_tac \\ tame_uniq
        \\ rpt conj_tac \\ strip_tac \\ rveq
        \\ metis_tac[optionTheory.SOME_11, pairTheory.PAIR_EQ, fsFFITheory.inode_distinct]]);

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
  (fn () => rpt gen_tac \\ strip_tac \\ drule STDF \\ strip_tac \\ tame_uniq   (* A3 tactic-only v4 *)
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
     [(* A3 tactic-only: LUPDATE_def is [userdef], not [simp] (D3) *)
      rpt gen_tac \\ strip_tac \\
        gvs[ffi_write_def, AllCaseEqs(), listTheory.MAP_EQ_CONS, CHOICE, n2w2_def, listTheory.LUPDATE_def] \\
        rpt (pairarg_tac \\ gvs[n2w2_def, listTheory.LUPDATE_def]) \\ simp[listTheory.LUPDATE_def],
      rpt gen_tac \\ strip_tac \\
        gvs[ffi_write_def, AllCaseEqs(), listTheory.MAP_EQ_CONS, CHOICE, n2w2_def, listTheory.LUPDATE_def] \\
        rpt (pairarg_tac \\ gvs[n2w2_def, listTheory.LUPDATE_def]) \\ metis_tac[],
      rpt gen_tac \\ strip_tac \\
        gvs[ffi_write_def, AllCaseEqs(), listTheory.MAP_EQ_CONS, CHOICE, n2w2_def] \\
        rpt (pairarg_tac \\ gvs[n2w2_def]) \\ simp[],
      rpt gen_tac \\ strip_tac \\
        gvs[ffi_write_def, AllCaseEqs(), listTheory.MAP_EQ_CONS, CHOICE, n2w2_def] \\
        rpt (pairarg_tac \\ gvs[n2w2_def]) \\ metis_tac[],
      rpt gen_tac \\ simp[ffi_write_def] \\ every_case_tac \\ simp[CHOICE] \\ strip_tac \\
        gvs[listTheory.MAP_EQ_CONS, n2w2_def, listTheory.LUPDATE_def] \\
        rpt (pairarg_tac \\ gvs[n2w2_def, listTheory.LUPDATE_def]) \\ simp[]]);

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
  (fn () => rpt gen_tac \\ strip_tac \\ drule STDF \\ strip_tac \\ tame_uniq   (* A3 tactic-only v4 *)
     \\ gvs[fsFFITheory.read_def] \\ rpt (pairarg_tac \\ gvs[])
     \\ `fd <> 1 /\ fd <> 2` by (rpt strip_tac \\ gvs[])
     \\ (* A3 tactic-only v5. LO-0003 stdout:140, CONJ_TAC failed: gvs had already closed the conjunct
           fs1.inode_tbl = fs.inode_tbl with the [simp] lemma bumpFD_inode_tbl (fsFFIPropsScript.sml:109-113),
           so the goal was only STD_streams (bumpFD ...). One simp call covers both shapes. *)
        CL "read_stdout_end" (simp[STD_streams_bumpFD, fsFFIPropsTheory.bumpFD_inode_tbl, bumpFD_def]));

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
       [(* A3 tactic-only: added first alternative; REWRITE_TAC keeps the existential shape for qexistsl_tac *)
        qpat_x_assum `STD_streams fs` (strip_assume_tac o REWRITE_RULE [STD_streams_def])
          \\ REWRITE_TAC [STD_streams_def] \\ qexistsl_tac [`inp`,`out`,`err`]
          \\ simp[alistTheory.ALOOKUP_ADELKEY] \\ rw[] \\ gvs[] \\ rw[EQ_IMP_THM] \\ gvs[],
        gvs[STD_streams_def] \\ qexistsl_tac [`inp`,`out`,`err`] \\ simp[alistTheory.ALOOKUP_ADELKEY] \\ rw[] \\ gvs[],
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
  (fn () => try_all "fs_ffi_part_stdout_step"
     [(* A3 tactic-only: split the 5-way disjunction explicitly (D5) *)
      rpt gen_tac \\ strip_tac \\
        qpat_x_assum `ALOOKUP _ _ = SOME _` (strip_assume_tac o ONCE_REWRITE_RULE [AFP]) \\ gvs[] \\
        FIRST (map (fn th => drule_all th \\ simp[] \\ NO_TAC) [WSTEP, RSTEP, OISTEP, OOSTEP, CSTEP]),
      rpt gen_tac \\ strip_tac \\ gvs[AFP] \\
        FIRST (map (fn th => drule_all th \\ simp[] \\ NO_TAC) [WSTEP, RSTEP, OISTEP, OOSTEP, CSTEP])]);

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
  (fn () =>
   let (* A3 tactic-only: the v2 tactic is kept as inv_tac with the v2 case split; a second copy renames
          the ffiname variable before Cases_on (D4). Nothing else differs between the two copies. *)
     fun inv_tac casetac =
       Induct
       >- try_all "extract_no_ext_stdout_nil" [simp[extract_fs_with_numchars_def, fdw_def],
                                                rw[extract_fs_with_numchars_def, fdw_def] \\ gvs[]]
       \\ casetac
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
       rpt gen_tac \\ simp[Once extract_fs_with_numchars_def, no_ext_def]
   in
     try_all "extract_no_ext_stdout"
       [inv_tac (Cases \\ rename1 `IO_event ff _ _` \\ Cases_on `ff`),
        inv_tac (Cases \\ Cases_on `f`)]
   end);

val EFS = thm "extract_fs_inode_tbl"
  (fn () => ``!cl fs io fsx. extract_fs no_ext (cl,fs) io = SOME fsx ==>
       ?cls' fs'. extract_fs_with_numchars no_ext (cl,fs) io = SOME (cls',fs') /\ fsx.inode_tbl = fs'.inode_tbl``)
  (fn () => try_all "extract_fs_inode_tbl"
     [(* A3 tactic-only: added first alternative; the case split is on the replay result itself *)
      rpt gen_tac \\ simp[extract_fs_def] \\
        Cases_on `extract_fs_with_numchars no_ext (cl,fs) io` \\ simp[] \\
        rename1 `extract_fs_with_numchars _ _ _ = SOME pp` \\ PairCases_on `pp` \\ simp[] \\ rpt strip_tac \\ gvs[],
      rw[extract_fs_def] \\ rename1 `SOME zz` \\ PairCases_on `zz` \\ gvs[],
      rpt gen_tac \\ simp[extract_fs_def, PULL_EXISTS] \\ Cases \\ simp[],
      rw[extract_fs_def] \\ Cases_on `extract_fs_with_numchars no_ext (cl,fs) io` \\ gvs[] \\
        rename1 `SOME zz` \\ PairCases_on `zz` \\ gvs[]]);

(* L-OUT (Y4's statement, unchanged) *)
val LOUT = thm "refund_L_OUT"
  (fn () => ``!cl fs io out. STD_streams fs /\
       extract_fs no_ext (cl,fs) io = SOME (add_stdout (fastForwardFD fs 0) out) ==>
       fd1_written io = explode out``)
  (fn () =>
   let (* A3 tactic-only (D2): v2 called drule STD_streams_stdout after drule_all INV. drule takes the newest
          matching assumption, which is STD_streams fs' (from INV), not STD_streams fs. v3 names fs. *)
     val pick_init =
       qpat_assum `STD_streams fs` (qx_choose_then `init` assume_tac o MATCH_MP STD_streams_stdout)
     val end_alts =
       [gvs[stdo_def, mlstringTheory.strcat_thm],
        qpat_x_assum `stdo _ _ (add_stdo _ _ _ _) _` (strip_assume_tac o REWRITE_RULE [stdo_def])
          \\ qpat_x_assum `(add_stdo _ _ _ _).inode_tbl = _` (fn th => RULE_ASSUM_TAC (REWRITE_RULE [th]))
          \\ gvs[mlstringTheory.strcat_thm],
        fs[stdo_def, mlstringTheory.strcat_thm] \\ rfs[] \\ gvs[]]
   in
     rpt gen_tac \\ strip_tac
     \\ pick_init
     \\ drule EFS \\ strip_tac
     \\ drule_all INV \\ strip_tac
     \\ `ALOOKUP fs.inode_tbl (UStream «stdout») = SOME (explode init)` by fs[stdo_def]
     \\ qpat_x_assum `!c0. _ ==> _` drule \\ strip_tac
     \\ `stdo 1 "stdout" (fastForwardFD fs 0) init` by simp[stdo_fastForwardFD]
     \\ `stdo 1 "stdout" (add_stdo 1 "stdout" (fastForwardFD fs 0) out) (strcat init out)` by
          (irule (GEN_ALL stdo_add_stdo) \\ simp[])
     \\ try_all "refund_L_OUT_end" end_alts
   end);

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
(* A3 tactic-only (D1): no_ext is polymorphic (no_ext : ffiname -> mlstring list # IO_fs -> word8 list ->
   word8 list -> 'a oracle_result). ``no_ext`` parsed alone keeps 'a, so INST [EXTV |-> ``no_ext``] fails on the
   type and Term.free_in ``no_ext`` is false. NOEXT is the constant at the exact type of the variable ext. *)
val NOEXT = mk_thy_const {Thy = "basis_ffi", Name = "no_ext", Ty = type_of EXTV}
  handle e => (pr ("NOEXT_FAILED " ^ General.exnMessage e); raise e);
val _ = pr ("NOEXT_TERM " ^ term_to_string NOEXT ^ " : " ^ type_to_string (type_of NOEXT));
val SPE_NOEXT = INST [EXTV |-> NOEXT] (SPEC_ALL SPE)
  handle e => (pr ("SPE_NOEXT_FAILED " ^ General.exnMessage e); TRUTH);
val FD1 = thm "refund_profile_a_sl_fd1"
  (fn () => ``^PREM ==>
     ?ms. (arm8_run 27 s = SOME ms /\ ms.PC = sl + 0x1000040D0w) /\
       !b. machine_sem (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi no_ext cl fs) ms b ==>
         ?t io. b = Terminate t io /\
           ((t = Success /\ fd1_written io = explode ^R) \/
            (t = Resource_limit_hit /\ fd1_written io <<= explode ^R))``)
  (fn () =>
   let (* A3 tactic-only v5. LO-0003 stdout:249: both v4 alternatives failed at a ">- simp[]" before any use of
          LOUT (no SHOW line from the inner try_all): conj_tac >- simp[] (alt 1) and impl_tac >- simp[] (alt 2).
          The goals there are assumptions verbatim (arm8_run 27 s = SOME ms; ms.PC = ...; the PREM conjuncts);
          simp normalises the goal side and did not close it. v5 closes them with ACCEPT_TAC / ASM_REWRITE_TAC
          (no normalisation) and finishes each case with drule_all; metis only as a bounded fallback. *)
     val fd1_case =
       FIRST [qexistsl_tac [`Success`, `io`] \\ simp[] \\ drule_all LOUT \\ simp[] \\ NO_TAC,
              qexistsl_tac [`Resource_limit_hit`, `io'`] \\ simp[] \\ drule_all LOUTP \\ simp[] \\ NO_TAC,
              metis_tac[LOUT, LOUTP]]
     val end_alts =
       [metis_tac[LOUT, LOUTP],
        FIRST [drule_all LOUT \\ simp[] \\ NO_TAC, drule_all LOUTP \\ simp[] \\ NO_TAC]]
   in
     try_all "refund_profile_a_sl_fd1"
       [DISCH_THEN (fn th => STRIP_ASSUME_TAC th \\ STRIP_ASSUME_TAC (MP SPE_NOEXT th))
          \\ ST "fd1_witness" (qexists_tac `ms`)
          \\ conj_tac >- CL "fd1_ms" (conj_tac \\ FIRST [first_assum ACCEPT_TAC, ASM_REWRITE_TAC []])
          \\ qx_gen_tac `bb` \\ strip_tac
          \\ ST "fd1_spec" (qpat_x_assum `!b. _` (qspec_then `bb` mp_tac))
          \\ impl_tac >- CL "fd1_sem" (first_assum ACCEPT_TAC)
          \\ rpt strip_tac \\ rveq
          \\ CL "fd1_case" fd1_case,
        DISCH_THEN (fn th => STRIP_ASSUME_TAC th \\ STRIP_ASSUME_TAC (MP SPE_NOEXT th))
          \\ qexists_tac `ms` \\ conj_tac >- ASM_REWRITE_TAC []
          \\ qx_gen_tac `bb` \\ strip_tac
          \\ qpat_x_assum `!b. _` (qspec_then `bb` mp_tac) \\ ASM_REWRITE_TAC []
          \\ rpt strip_tac \\ gvs[]
          \\ try_all "refund_profile_a_sl_fd1_end" end_alts]
   end);

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
(* P-O4 (A3 addition, positive control; no v2 statement changed): a PARTIAL write counts exactly the returned
   count nw, not the requested count n. Request n = 2 bytes "ab" on fd 1; after-bytes 0w :: n2w2 1 ++ ...
   (nw = 1) gives "a"; after-bytes 0w :: n2w2 2 ++ ... (nw = 2) gives "ab". The model admits nw < n
   (fsFFI write_def: k = MIN n strm, strm from numchars). *)
val PO4 = thm "P_O4_partial_write_counts_nw"
  (fn () => ``fd1_written [IO_event (ExtCall «write») (n2w8 1) (ZIP ([0w;2w;0w;0w;97w;98w],[0w;0w;1w;0w;97w;98w]))] = "a" /\
              fd1_written [IO_event (ExtCall «write») (n2w8 1) (ZIP ([0w;2w;0w;0w;97w;98w],[0w;0w;2w;0w;97w;98w]))] = "ab"``)
  (fn () => try_all "P_O4" [EVAL_TAC, simp[fdw_def, wc_def, n2w8_def, w82n_def, w22n_def] \\ EVAL_TAC]);

(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = pr ("FAILED_LIST " ^ String.concatWith " " (rev (!failed)));          (* A3 tactic-only v5 *)
val _ = pr ("DIAG_OK_UNDER_LIST " ^ String.concatWith " " (rev (!diag)));
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
fun lit name th tm = if aconv (concl th) tm then pr ("CONTROL_OK " ^ name ^ " statement is the literal planned statement")
                     else bad (name ^ "-literal");
val _ = lit "refund_L_OUT" LOUT ``!cl fs io out. STD_streams fs /\
       extract_fs no_ext (cl,fs) io = SOME (add_stdout (fastForwardFD fs 0) out) ==> fd1_written io = explode out``;
val _ = if aconv (fst (dest_imp (concl FD1))) PREM then pr "CONTROL_OK refund_profile_a_sl_fd1 premise is the stored premise term"
        else bad "FD1-premise";
val _ = if Term.free_in NOEXT (concl FD1)   (* A3 tactic-only (D1): typed constant *)
        andalso not (Lib.mem "ext" (map (fst o dest_var) (free_vars (concl FD1))))
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

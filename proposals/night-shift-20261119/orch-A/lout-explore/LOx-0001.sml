(* LOx-0001.sml: L-OUT EXPLORATION run (worker A16, Night-Shift Orchestrator A). NOT RUN. NOT a proof attempt.
   Lines below up to "PART 2" = LO-0005.sml lines 1-404 (SHA-256 9db45d735cf891429a6d9e80454ddf7c07d49b9a2a4030aca57d61c14571bb30),
   byte-identical except one line: new_theory "forge_refundLOut" -> new_theory "forge_refundLOutExplore" (scratch; never exported).
   No export_theory. No open lemma is stored. Ends with EXPLORE_COMPLETE. Every tactic UNCHECKED. *)
(* L-OUT at no_ext, v6 (worker A3). DRAFT: NOT RUN. Base LO-0004.sml (= v5, SHA-256 fcc80fb8...b8b4). Changes marked
   (* A3 tactic-only v6 *) / "A3 addition v6": AGREE for the two arm8_run constants (refund_profile_a_sl_fd1);
   an explicit step lemma extract_no_ext_stdout_step and an explicit induction for extract_no_ext_stdout.
   No existing statement changed. Every tactic UNCHECKED.
   ---------------------------------------------------------------------------------------------------
   v5 header: L-OUT at no_ext, v5 (worker A3). DRAFT: NOT RUN. Base: LO-0003.sml (SHA-256 4bc9910a7b17a735c340ab8e27d728587a3a5db497b70e4a3ba68ceefbfd5cc7,
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
val _ = new_theory "forge_refundLOutExplore";
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
(* A3 tactic-only v6. Two constants are named arm8_run in the deps: forge_refundCmlMainStep$arm8_run (used by the
   stored theorem: E4/proof.sml:172 qualifies it) and forge_refundCmlMainSlide$arm8_run. The unqualified
   `arm8_run` in the FD1 quotation may parse to the other one: LO-0004 stdout:323/393 show the goal
   "arm8_run 27 s = SOME ms" left open next to an assumption that prints identically. The stored theorem
   forge_refundSlideEntry.arm8_run_constants_agree (results/refund-slide-local-20261117/attempt-0001/s2-0003/
   stdout.log:18-19; source s2-0003.sml:40: !n s. run_new n s = run_old n s) bridges the two. No statement change. *)
val AGREE = DB.fetch "forge_refundSlideEntry" "arm8_run_constants_agree";
val _ = pr ("USED arm8_run_constants_agree\n" ^ thm_to_string AGREE);
val _ = List.app (fn t => pr ("ARM8_RUN_IN_STORED " ^ (#Thy (dest_thy_const t))))
          (find_terms (fn t => is_const t andalso fst (dest_const t) = "arm8_run") (concl SPE));
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

(* ===================================================================================================
   LOx-0001 PART 2 (worker A16, Night-Shift Orchestrator A). EXPLORATION ONLY. NOT RUN. Every tactic UNCHECKED.
   - Part 1 above = LO-0005.sml lines 1-404 (through extract_no_ext_ExtCall, the last lemma that passed in
     LO-0005), unchanged except the new_theory name (scratch theory, never exported).
   - Nothing below stores a theorem: no save_thm, no thm, no export_theory. The open lemmas are only explored.
   - Where an exploration needs an open lemma (or an open sub-case), it uses ASSUME of its statement. A closed
     exploration prints VALIDATION ... hyps N; N > 0 means "closed only under the ASSUMEd statements".
   - Stepper: a step is (label, tactic, alternatives). For step i the cumulative prefix
     ALL_TAC \\ t1 \\ ... \\ ti is applied afresh to the start goal as  prefix g ctxt  (no TAC_PROOF;
     type tactic = goal -> Context.t -> goal list * validation, HOL/src/1/Abbrev.sig:10), under Timeout.apply. *)
val _ = pr "EXPLORE_MODE nothing is exported; the open lemmas are never stored";
val _ = metisTools.limit := {time = SOME 20.0, infs = NONE};
val STEP_SECS = 60;
type step = string * tactic * tactic list;

(* ---------- printing ---------- *)
val NAMED_CONSTS = ["arm8_run", "no_ext"];
fun named_consts (tms : term list) : term list =
  op_mk_set aconv
    (List.concat (map (find_terms (fn t => is_const t andalso Lib.mem (fst (dest_const t)) NAMED_CONSTS)) tms));
fun const_line (loc : string) (c : term) : string =
  let val {Thy = thy, Name = nm, Ty = ty} = dest_thy_const c
  in "    CONST_IN_" ^ loc ^ " " ^ thy ^ "$" ^ nm ^ " " ^ trunc 300 (type_to_string ty) end;
fun var_line (v : term) : string =
  let val (n, ty) = dest_var v in n ^ trunc 200 (type_to_string ty) end;
fun show_goal (lemma : string) (k : int) ((asl, w) : goal) : unit =
  let
    fun asm_loop _ [] = ()
      | asm_loop j (a :: rest) =
          (pr ("    ASM " ^ Int.toString j ^ " " ^ trunc 1500 (term_to_string a));
           List.app (fn c => pr (const_line ("ASM_" ^ Int.toString j) c)) (named_consts [a]);
           asm_loop (j + 1) rest)
  in
    pr ("  GOAL_BEGIN " ^ lemma ^ " #" ^ Int.toString k ^ " assumptions " ^ Int.toString (length asl) ^
        " (ASM 0 = newest)");
    asm_loop 0 asl;
    pr ("    CONCL " ^ trunc 4000 (term_to_string w));
    List.app (fn c => pr (const_line "CONCL" c)) (named_consts [w]);
    pr ("    FREE_VARS " ^ trunc 1500 (String.concatWith ", " (map var_line (free_varsl (w :: asl)))));
    pr ("  GOAL_END " ^ lemma ^ " #" ^ Int.toString k)
  end;
fun show_goals (lemma : string) (gs : goal list) : unit =
  let
    fun loop _ [] = ()
      | loop k (g :: rest) = (show_goal lemma k g; loop (k + 1) rest)
  in
    pr ("  GOAL_COUNT " ^ Int.toString (length gs));
    loop 1 gs
  end;

(* ---------- the stepper ---------- *)
fun prefix_of (ts : tactic list) : tactic = List.foldl (fn (t, acc) => acc \\ t) ALL_TAC ts;
fun run_ts (ts : tactic list) (g : goal) : goal list * (thm list -> thm) =
  let val ctxt = Context.snapshot ()
  in Timeout.apply (Time.fromSeconds (Int.toLarge STEP_SECS)) (fn () => prefix_of ts g ctxt) () end;
fun check_validation (lemma : string) (gt : term) (v : thm list -> thm) : unit =
  (let val th = v [] in
     pr ("VALIDATION " ^ lemma ^ " concl_aconv_goal " ^ Bool.toString (aconv (concl th) gt) ^
         " hyps " ^ Int.toString (length (hyp th)));
     List.app (fn h => pr ("  VALIDATION_HYP " ^ trunc 400 (term_to_string h))) (hyp th)
   end)
  handle e => pr ("VALIDATION_FAILED " ^ lemma ^ " " ^ trunc 600 (General.exnMessage e));
fun explore0 (lemma : string) (gt : term) (steps : step list) : unit =
  let
    val g0 : goal = ([], gt)
    fun attempt (ts : tactic list) : (goal list * (thm list -> thm)) option * string =
      (SOME (run_ts ts g0), "")
      handle Timeout.TIMEOUT _ => (NONE, "TIMEOUT after " ^ Int.toString STEP_SECS ^ " s")
           | e => (NONE, General.exnMessage e)
    fun finish (n : int) (gs : goal list) (v : thm list -> thm) : unit =
      if null gs then
        (pr ("EXPLORE_CLOSED " ^ lemma ^ " after_steps " ^ Int.toString n);
         check_validation lemma gt v)
      else pr ("EXPLORE_OPEN " ^ lemma ^ " goals " ^ Int.toString (length gs))
    fun loop (i : int) (chosen : tactic list) (gs : goal list) (v : thm list -> thm) (rest : step list) : unit =
      case rest of
        [] => finish (i - 1) gs v
      | ((label, tac, alts) :: more) =>
          (case attempt (chosen @ [tac]) of
             (SOME (gs1, v1), _) =>
               (pr ("STEP " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " goals " ^ Int.toString (length gs1));
                show_goals lemma gs1;
                loop (i + 1) (chosen @ [tac]) gs1 v1 more)
           | (NONE, msg) =>
               (pr ("STEP_FAILED " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " " ^ trunc 800 msg);
                pr ("GOALS_BEFORE_STEP " ^ lemma ^ " " ^ Int.toString i ^ " count " ^ Int.toString (length gs));
                show_goals lemma gs;
                alt_loop i label chosen more 1 alts))
    and alt_loop (i : int) (label : string) (chosen : tactic list) (more : step list) (k : int)
                 (alts : tactic list) : unit =
      case alts of
        [] => pr ("STEP_STUCK " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label)
      | (a :: others) =>
          (case attempt (chosen @ [a]) of
             (SOME (gs1, v1), _) =>
               (pr ("ALT_WORKS " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " alt " ^ Int.toString k);
                pr ("STEP " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " goals " ^ Int.toString (length gs1) ^
                    " (alt " ^ Int.toString k ^ ")");
                show_goals lemma gs1;
                loop (i + 1) (chosen @ [a]) gs1 v1 more)
           | (NONE, msg) =>
               (pr ("ALT_FAILED " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " alt " ^ Int.toString k ^ " " ^
                    trunc 800 msg);
                alt_loop i label chosen more (k + 1) others))
    val v0 = (fn (_ : thm list) => raise mk_HOL_ERR "LOx" "explore" "no step was run") : thm list -> thm
  in
    pr ("EXPLORE_BEGIN " ^ lemma ^ " steps " ^ Int.toString (length steps));
    show_goals lemma [g0];
    loop 1 [] [g0] v0 steps;
    pr ("EXPLORE_END " ^ lemma)
  end;
(* explore : string -> (unit -> term) -> (unit -> step list) -> unit. A parse error or any other exception in
   one exploration prints EXPLORE_ERROR and the script goes on with the next one. *)
fun explore (lemma : string) (goalf : unit -> term) (stepsf : unit -> step list) : unit =
  explore0 lemma (goalf ()) (stepsf ())
  handle e => pr ("EXPLORE_ERROR " ^ lemma ^ " " ^ trunc 800 (General.exnMessage e));

(* ---------- statements (copied from LO-0005.sml; the case statements are new sub-goals) ---------- *)
fun istep_tm () = ``!e io cls fs cls' fs'.
       extract_fs_with_numchars no_ext (cls,fs) (e::io) = SOME (cls',fs') /\ STD_streams fs ==>
       ?cls1 fs1. extract_fs_with_numchars no_ext (cls1,fs1) io = SOME (cls',fs') /\ STD_streams fs1 /\
         !c0. ALOOKUP fs.inode_tbl (UStream «stdout») = SOME c0 ==>
              ALOOKUP fs1.inode_tbl (UStream «stdout») = SOME (c0 ++ fd1_written [e])``;
fun event_tm () = ``!ff cf bs0 io cls fs cls' fs'.
       extract_fs_with_numchars no_ext (cls,fs) (IO_event ff cf bs0::io) = SOME (cls',fs') /\ STD_streams fs ==>
       ?cls1 fs1. extract_fs_with_numchars no_ext (cls1,fs1) io = SOME (cls',fs') /\ STD_streams fs1 /\
         !c0. ALOOKUP fs.inode_tbl (UStream «stdout») = SOME c0 ==>
              ALOOKUP fs1.inode_tbl (UStream «stdout») = SOME (c0 ++ fd1_written [IO_event ff cf bs0])``;
fun extcall_tm () = ``!nm cf bs0 io cls fs cls' fs'.
       extract_fs_with_numchars no_ext (cls,fs) (IO_event (ExtCall nm) cf bs0::io) = SOME (cls',fs') /\
       STD_streams fs ==>
       ?cls1 fs1. extract_fs_with_numchars no_ext (cls1,fs1) io = SOME (cls',fs') /\ STD_streams fs1 /\
         !c0. ALOOKUP fs.inode_tbl (UStream «stdout») = SOME c0 ==>
              ALOOKUP fs1.inode_tbl (UStream «stdout») = SOME (c0 ++ fd1_written [IO_event (ExtCall nm) cf bs0])``;
fun shared_tm () = ``!op cf bs0 io cls fs cls' fs'.
       extract_fs_with_numchars no_ext (cls,fs) (IO_event (SharedMem op) cf bs0::io) = SOME (cls',fs') /\
       STD_streams fs ==>
       ?cls1 fs1. extract_fs_with_numchars no_ext (cls1,fs1) io = SOME (cls',fs') /\ STD_streams fs1 /\
         !c0. ALOOKUP fs.inode_tbl (UStream «stdout») = SOME c0 ==>
              ALOOKUP fs1.inode_tbl (UStream «stdout») = SOME (c0 ++ fd1_written [IO_event (SharedMem op) cf bs0])``;
(* case A: the name is one of the five fs_ffi_part names (open_in, open_out, read, write, close); shape = EXTC disjunct 1 *)
fun sga_tm () = ``!nm f cf bs0 io cls fs cls' fs' fs2.
       ALOOKUP (SND (SND fs_ffi_part)) nm = SOME f /\
       f cf (MAP FST bs0) fs = SOME (FFIreturn (MAP SND bs0) fs2) /\
       extract_fs_with_numchars no_ext (cls,fs2) io = SOME (cls',fs') /\ STD_streams fs ==>
       ?cls1 fs1. extract_fs_with_numchars no_ext (cls1,fs1) io = SOME (cls',fs') /\ STD_streams fs1 /\
         !c0. ALOOKUP fs.inode_tbl (UStream «stdout») = SOME c0 ==>
              ALOOKUP fs1.inode_tbl (UStream «stdout») = SOME (c0 ++ fd1_written [IO_event (ExtCall nm) cf bs0])``;
(* case B: a basis name outside fs_ffi_part (get_arg_count, get_arg_length, get_arg, exit); shape = EXTC disjunct 2.
   A non-basis name is vacuous at no_ext (Oracle_final): EXTC (proved) already excludes it. *)
fun sgb_tm () = ``!nm cf bs0 io cls fs cls' fs'.
       ALOOKUP (SND (SND fs_ffi_part)) nm = NONE /\ is_basis_ffi_name nm /\
       extract_fs_with_numchars no_ext (cls,fs) io = SOME (cls',fs') /\ STD_streams fs ==>
       ?cls1 fs1. extract_fs_with_numchars no_ext (cls1,fs1) io = SOME (cls',fs') /\ STD_streams fs1 /\
         !c0. ALOOKUP fs.inode_tbl (UStream «stdout») = SOME c0 ==>
              ALOOKUP fs1.inode_tbl (UStream «stdout») = SOME (c0 ++ fd1_written [IO_event (ExtCall nm) cf bs0])``;
fun inv_tm () = ``!io cls fs cls' fs'.
       extract_fs_with_numchars no_ext (cls,fs) io = SOME (cls',fs') /\ STD_streams fs ==>
       STD_streams fs' /\
       !c0. ALOOKUP fs.inode_tbl (UStream «stdout») = SOME c0 ==>
            ALOOKUP fs'.inode_tbl (UStream «stdout») = SOME (c0 ++ fd1_written io)``;
fun inv_nil_tm () = ``!cls fs cls' fs'.
       extract_fs_with_numchars no_ext (cls,fs) [] = SOME (cls',fs') /\ STD_streams fs ==>
       STD_streams fs' /\
       !c0. ALOOKUP fs.inode_tbl (UStream «stdout») = SOME c0 ==>
            ALOOKUP fs'.inode_tbl (UStream «stdout») = SOME (c0 ++ fd1_written [])``;
fun inv_cons_tm () = ``!io.
       (!cls fs cls' fs'.
          extract_fs_with_numchars no_ext (cls,fs) io = SOME (cls',fs') /\ STD_streams fs ==>
          STD_streams fs' /\
          !c0. ALOOKUP fs.inode_tbl (UStream «stdout») = SOME c0 ==>
               ALOOKUP fs'.inode_tbl (UStream «stdout») = SOME (c0 ++ fd1_written io)) ==>
       !e cls fs cls' fs'.
          extract_fs_with_numchars no_ext (cls,fs) (e::io) = SOME (cls',fs') /\ STD_streams fs ==>
          STD_streams fs' /\
          !c0. ALOOKUP fs.inode_tbl (UStream «stdout») = SOME c0 ==>
               ALOOKUP fs'.inode_tbl (UStream «stdout») = SOME (c0 ++ fd1_written (e::io))``;
fun lout_tm () = ``!cl fs io out. STD_streams fs /\
       extract_fs no_ext (cl,fs) io = SOME (add_stdout (fastForwardFD fs 0) out) ==>
       fd1_written io = explode out``;
fun loutp_tm () = ``!cl fs io io' out. STD_streams fs /\ io' <<= io /\
       extract_fs no_ext (cl,fs) io = SOME (add_stdout (fastForwardFD fs 0) out) ==>
       fd1_written io' <<= explode out``;

(* ---------- (1a) extract_no_ext_stdout_step: diagnostic replay of the LO-0005 first alternative ---------- *)
(* LO-0005 stdout:261: HOL_ERR origin FIRST_ASSUM, empty message, no STAGE_FAILED line, so the failing tactic was one
   not wrapped by ST/CL. Two unwrapped candidates raise exactly this: rename1 (its last selection mode "sa" is
   FIRST_ASSUM, HOL/src/q/Q.sml:647-650, 676-689) and qpat_x_assum (Q.sml:364-367 -> Tactical.PAT_X_ASSUM =
   gen FIRST_X_ASSUM, Tactical.sml:941; FIRST_ASSUM raises with origin "FIRST_ASSUM", Tactical.sml:874-875). *)
val _ = explore "extract_no_ext_stdout_step/A3_path" istep_tm (fn () =>
  [("gen", rpt gen_tac, []),
   ("cases_e", Cases_on `e`, []),
   ("rename_event", rename1 `IO_event ff cf bs0`, [rename1 `IO_event ff _ _`]),
   ("cases_ff", Cases_on `ff`, [Cases_on `f`]),
   ("strip", strip_tac, []),
   ("pat_extract_mp", qpat_x_assum `extract_fs_with_numchars _ _ _ = _` mp_tac,
      [qpat_x_assum `extract_fs_with_numchars _ _ (_ :: _) = _` mp_tac]),
   ("strip_again", strip_tac, []),
   ("rename_extcall_TRY", TRY (rename1 `IO_event (ExtCall nm) cf bs0`), []),
   ("extc_TRY", TRY (qpat_x_assum `extract_fs_with_numchars _ _ _ = _` (strip_assume_tac o MATCH_MP EXTC)), []),
   ("pairs", RULE_ASSUM_TAC (REWRITE_RULE [pairTheory.FST, pairTheory.SND]), [])]);

(* ---------- (1b) case A: fs_ffi_part name ---------- *)
val _ = explore "extract_no_ext_stdout_step/ExtCall_fs_ffi_part" sga_tm (fn () =>
  [("intro", rpt gen_tac \\ strip_tac, []),
   ("fstep", drule_all FSTEP,
      [qspecl_then [`nm`, `f`, `cf`, `bs0`, `fs`, `fs2`] mp_tac FSTEP \\ ASM_REWRITE_TAC [],
       (qspecl_then [`nm`, `f`, `cf`, `bs0`, `fs`, `fs2`] mp_tac FSTEP \\ impl_tac) >- ASM_REWRITE_TAC []]),
   ("fstep_strip", strip_tac, []),
   ("witness", qexistsl_tac [`cls`, `fs2`], []),
   ("conj", rpt conj_tac, []),
   ("accept_asms_TRY", TRY (first_assum ACCEPT_TAC), []),
   ("gen_c0", rpt strip_tac, []),
   ("use_c0", qpat_x_assum `!c0. _ ==> _` (qspec_then `c0` mp_tac), [first_x_assum (qspec_then `c0` mp_tac)]),
   ("c0_rw", ASM_REWRITE_TAC [], []),
   ("subst", disch_then SUBST1_TAC, []),
   ("end", simp[fdw_def],
      [REWRITE_TAC [fdw_def, listTheory.APPEND_NIL],
       rw[fdw_def],
       Cases_on `nm = «write»` \\ ASM_REWRITE_TAC [fdw_def, listTheory.APPEND_NIL]])]);

(* ---------- (1c) case B: basis name outside fs_ffi_part ---------- *)
val _ = explore "extract_no_ext_stdout_step/ExtCall_basis_other" sgb_tm (fn () =>
  [("intro", rpt gen_tac \\ strip_tac, []),
   ("notwrite", (`nm <> «write»` by (strip_tac \\ rveq \\ qpat_x_assum `ALOOKUP _ _ = NONE` mp_tac \\
                                      simp[fs_ffi_part_def])),
      [(`nm <> «write»` by (strip_tac \\ rveq \\ qspecl_then [`«write»`, `ffi_write`] mp_tac AFP \\
                            ASM_REWRITE_TAC [] \\ simp[])),
       (`nm <> «write»` by (CCONTR_TAC \\ gvs[fs_ffi_part_def])),
       (`nm <> «write»` by (strip_tac \\ gvs[fs_ffi_part_def, alistTheory.ALOOKUP_def]))]),
   ("witness", qexistsl_tac [`cls`, `fs`], []),
   ("conj", rpt conj_tac, []),
   ("accept_asms_TRY", TRY (first_assum ACCEPT_TAC), []),
   ("gen_c0", rpt strip_tac, []),
   ("end", simp[fdw_def],
      [gvs[fdw_def], rw[fdw_def] \\ gvs[], ASM_REWRITE_TAC [fdw_def, listTheory.APPEND_NIL]])]);

(* ---------- (1d) ExtCall, from EXTC (proved) and the two cases (ASSUMEd) ---------- *)
val _ = explore "extract_no_ext_stdout_step/ExtCall" extcall_tm (fn () =>
  let val SGA_A = ASSUME (sga_tm ())
      val SGB_A = ASSUME (sgb_tm ())
  in
  [("intro", rpt gen_tac \\ strip_tac, []),
   ("extc", qpat_x_assum `extract_fs_with_numchars _ _ _ = _` (strip_assume_tac o MATCH_MP EXTC),
      [drule EXTC \\ strip_tac,
       first_x_assum (strip_assume_tac o MATCH_MP EXTC)]),
   ("pairs", RULE_ASSUM_TAC (REWRITE_RULE [pairTheory.FST, pairTheory.SND]), [fs []]),
   ("close_by_cases", FIRST [drule_all SGA_A \\ disch_then MATCH_ACCEPT_TAC,
                             drule_all SGB_A \\ disch_then MATCH_ACCEPT_TAC],
      [metis_tac [SGA_A, SGB_A]])]
  end);

(* ---------- (1e) SharedMem: no_ext answers Oracle_final, the replay is NONE ---------- *)
val _ = explore "extract_no_ext_stdout_step/SharedMem" shared_tm (fn () =>
  [("intro", rpt gen_tac \\ strip_tac, []),
   ("pat_extract_mp", qpat_x_assum `extract_fs_with_numchars _ _ _ = _` mp_tac, [rpt (pop_assum mp_tac)]),
   ("eval", simp[Once extract_fs_with_numchars_def, no_ext_def],
      [simp[extract_fs_with_numchars_def, no_ext_def],
       rw[Once extract_fs_with_numchars_def, no_ext_def],
       fs[Once extract_fs_with_numchars_def, no_ext_def]])]);

(* ---------- (1f) one io_event: split the ffiname (no variable names needed) ---------- *)
val _ = explore "extract_no_ext_stdout_step/event" event_tm (fn () =>
  let val EXT_A = ASSUME (extcall_tm ())
      val SH_A = ASSUME (shared_tm ())
  in
  [("cases_name", Cases, [gen_tac \\ Cases_on `ff`]),
   ("close_by_cases", FIRST [MATCH_ACCEPT_TAC EXT_A, MATCH_ACCEPT_TAC SH_A], [metis_tac [EXT_A, SH_A]])]
  end);

(* ---------- (1g) the step lemma itself ---------- *)
val _ = explore "extract_no_ext_stdout_step" istep_tm (fn () =>
  let val EV_A = ASSUME (event_tm ())
  in
  [("cases_e", Cases, [gen_tac \\ Cases_on `e`]),
   ("close_by_event", MATCH_ACCEPT_TAC EV_A, [metis_tac [EV_A]])]
  end);

(* ---------- (2a) the invariant, nil case ---------- *)
val _ = explore "extract_no_ext_stdout/nil" inv_nil_tm (fn () =>
  [("intro", rpt gen_tac \\ strip_tac, []),
   ("unfold", qpat_x_assum `extract_fs_with_numchars _ _ _ = _`
                (strip_assume_tac o SIMP_RULE (srw_ss()) [extract_fs_with_numchars_def]),
      [gvs[extract_fs_with_numchars_def], fs[extract_fs_with_numchars_def]]),
   ("rveq", rveq, []),
   ("end", simp[fdw_def], [rw[fdw_def], gvs[fdw_def]])]);

(* ---------- (2b) the invariant, cons case, with the step lemma ASSUMEd ---------- *)
val _ = explore "extract_no_ext_stdout/cons" inv_cons_tm (fn () =>
  let val ISTEP_A = ASSUME (istep_tm ())
  in
  [("intro_io", gen_tac \\ DISCH_TAC, []),
   ("intro_e", rpt gen_tac \\ strip_tac, []),
   ("istep", qspecl_then [`e`, `io`, `cls`, `fs`, `cls'`, `fs'`] mp_tac ISTEP_A, []),
   ("istep_rw", ASM_REWRITE_TAC [], [impl_tac >- ASM_REWRITE_TAC []]),
   ("istep_strip", strip_tac, []),
   ("ih", qpat_x_assum `!cls fs cls' fs'. _` (qspecl_then [`cls1`, `fs1`, `cls'`, `fs'`] mp_tac),
      [last_x_assum (qspecl_then [`cls1`, `fs1`, `cls'`, `fs'`] mp_tac),
       first_x_assum (qspecl_then [`cls1`, `fs1`, `cls'`, `fs'`] mp_tac)]),
   ("ih_rw", ASM_REWRITE_TAC [], [impl_tac >- ASM_REWRITE_TAC []]),
   ("ih_strip", strip_tac, []),
   ("conj", conj_tac, []),
   ("accept_std_TRY", TRY (first_assum ACCEPT_TAC), []),
   ("gen_c0", rpt strip_tac, []),
   ("c0_fs", qpat_x_assum `!c0. ALOOKUP fs.inode_tbl _ = SOME c0 ==> _` (qspec_then `c0` mp_tac),
      [qpat_x_assum `!c0. ALOOKUP fs.inode_tbl (UStream «stdout») = SOME c0 ==> _` (qspec_then `c0` mp_tac)]),
   ("c0_fs_rw", ASM_REWRITE_TAC [], []),
   ("c0_fs_strip", strip_tac, []),
   ("c1_fs1", qpat_x_assum `!c0. ALOOKUP fs1.inode_tbl _ = SOME c0 ==> _` (qspec_then `c0 ++ fd1_written [e]` mp_tac),
      [qpat_x_assum `!c0. ALOOKUP fs1.inode_tbl (UStream «stdout») = SOME c0 ==> _`
         (qspec_then `c0 ++ fd1_written [e]` mp_tac)]),
   ("c1_fs1_rw", ASM_REWRITE_TAC [], []),
   ("subst", disch_then SUBST1_TAC, []),
   ("append_fact", (`fd1_written (e::io) = fd1_written [e] ++ fd1_written io` by
                      (qspecl_then [`[e]`, `io`] mp_tac FDA \\ simp[])),
      [(`fd1_written (e::io) = fd1_written [e] ++ fd1_written io` by simp[GSYM FDA]),
       (`fd1_written (e::io) = fd1_written [e] ++ fd1_written io` by metis_tac [FDA, listTheory.APPEND])]),
   ("end", ASM_REWRITE_TAC [listTheory.APPEND_ASSOC], [simp[], metis_tac [listTheory.APPEND_ASSOC]])]
  end);

(* ---------- (2c) the invariant itself, from the two ASSUMEd cases ---------- *)
val _ = explore "extract_no_ext_stdout" inv_tm (fn () =>
  let val NIL_A = ASSUME (inv_nil_tm ())
      val CONS_A = ASSUME (inv_cons_tm ())
  in
  [("induct", Induct, [Induct_on `io`]),
   ("close_cases", FIRST [MATCH_ACCEPT_TAC NIL_A, first_assum (fn ih => MATCH_ACCEPT_TAC (MATCH_MP CONS_A ih))],
      [metis_tac [NIL_A, CONS_A]])]
  end);

(* ================= (3) refund_profile_a_sl_fd1 ================= *)
(* Copied verbatim from LO-0005.sml:575-587 (ran in LO-0004: stdout EXT_VARIABLE / RENDER_TERM / NOEXT_TERM lines). *)
val (PREM, _) = dest_imp (concl (SPEC_ALL SPE));
val EXTV = valOf (List.find (fn v => fst (dest_var v) = "ext") (free_vars (concl (SPEC_ALL SPE))));
val _ = pr ("EXT_VARIABLE " ^ term_to_string EXTV ^ " : " ^ type_to_string (type_of EXTV));
val R = find_term (fn t => (fst (dest_const (fst (strip_comb t))) = "refund_render_fields") handle _ => false) (concl SPE);
val _ = pr ("RENDER_TERM " ^ term_to_string R);
val NOEXT = mk_thy_const {Thy = "basis_ffi", Name = "no_ext", Ty = type_of EXTV}
  handle e => (pr ("NOEXT_FAILED " ^ General.exnMessage e); raise e);
val _ = pr ("NOEXT_TERM " ^ term_to_string NOEXT ^ " : " ^ type_to_string (type_of NOEXT));
val SPE_NOEXT = INST [EXTV |-> NOEXT] (SPEC_ALL SPE)
  handle e => (pr ("SPE_NOEXT_FAILED " ^ General.exnMessage e); TRUTH);
(* Which arm8_run constants exist, and which one an unqualified quotation picks. *)
val _ = List.app (fn c => pr (const_line "UNQUALIFIED_PARSE" c)) (named_consts [``arm8_run``])
  handle e => pr ("UNQUALIFIED_PARSE_FAILED arm8_run " ^ General.exnMessage e);
val _ = List.app (fn c => pr (const_line "QUALIFIED_SLIDE" c)) (named_consts [``forge_refundCmlMainSlide$arm8_run``])
  handle e => pr ("QUALIFIED_PARSE_FAILED forge_refundCmlMainSlide$arm8_run " ^ General.exnMessage e);
val _ = List.app (fn c => pr (const_line "QUALIFIED_STEP" c)) (named_consts [``forge_refundCmlMainStep$arm8_run``])
  handle e => pr ("QUALIFIED_PARSE_FAILED forge_refundCmlMainStep$arm8_run " ^ General.exnMessage e);
val _ = List.app (fn c => pr (const_line "AGREE_THEOREM" c)) (named_consts [concl AGREE]);
val _ = List.app (fn c => pr (const_line "SPE_NOEXT_THEOREM" c)) (named_consts [concl SPE_NOEXT]);

fun fd1_tm () = ``^PREM ==>
     ?ms. (arm8_run 27 s = SOME ms /\ ms.PC = sl + 0x1000040D0w) /\
       !b. machine_sem (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi no_ext cl fs) ms b ==>
         ?t io. b = Terminate t io /\
           ((t = Success /\ fd1_written io = explode ^R) \/
            (t = Resource_limit_hit /\ fd1_written io <<= explode ^R))``;
fun fd1_ms_tm () = ``^PREM ==> ?ms. arm8_run 27 s = SOME ms /\ ms.PC = sl + 0x1000040D0w``;
fun fd1_succ_tm () = ``!io. extract_fs no_ext (cl,fs) io = SOME (add_stdout (fastForwardFD fs 0) ^R) /\ STD_streams fs ==>
     ?t io'. Terminate Success io = Terminate t io' /\
       ((t = Success /\ fd1_written io' = explode ^R) \/
        (t = Resource_limit_hit /\ fd1_written io' <<= explode ^R))``;
fun fd1_rlh_tm () = ``!io io'. io' <<= io /\
       extract_fs no_ext (cl,fs) io = SOME (add_stdout (fastForwardFD fs 0) ^R) /\ STD_streams fs ==>
     ?t io''. Terminate Resource_limit_hit io' = Terminate t io'' /\
       ((t = Success /\ fd1_written io'' = explode ^R) \/
        (t = Resource_limit_hit /\ fd1_written io'' <<= explode ^R))``;
val _ = (pr ("FD1_STATEMENT_PARSED " ^ trunc 400 (term_to_string (fd1_tm ())));
         List.app (fn c => pr (const_line "FD1_STATEMENT" c)) (named_consts [fd1_tm ()]))
  handle e => pr ("FD1_STATEMENT_FAILED " ^ General.exnMessage e);

(* (3a)-(3c) the arm8_run conjunct: three closing tactics, each tried alone after the same prefix. *)
fun fd1_ms_prefix () : step list =
  [("disch_spec", DISCH_THEN (fn th => STRIP_ASSUME_TAC th \\ STRIP_ASSUME_TAC (MP SPE_NOEXT th)),
      [DISCH_TAC \\ first_assum (fn th => STRIP_ASSUME_TAC (MP SPE_NOEXT th))]),
   ("witness", qexists_tac `ms`, []),
   ("conj", conj_tac, [])];
val _ = explore "refund_profile_a_sl_fd1/ms_first_assum_ACCEPT" fd1_ms_tm (fn () =>
  fd1_ms_prefix () @ [("close_first_assum_ACCEPT_TAC", first_assum ACCEPT_TAC, [])]);
val _ = explore "refund_profile_a_sl_fd1/ms_ASM_REWRITE_AGREE" fd1_ms_tm (fn () =>
  fd1_ms_prefix () @ [("close_ASM_REWRITE_TAC_AGREE", ASM_REWRITE_TAC [AGREE], [])]);
val _ = explore "refund_profile_a_sl_fd1/ms_ASM_REWRITE_GSYM_AGREE" fd1_ms_tm (fn () =>
  fd1_ms_prefix () @ [("close_ASM_REWRITE_TAC_GSYM_AGREE", ASM_REWRITE_TAC [GSYM AGREE], [])]);

(* (3d) Success case, refund_L_OUT ASSUMEd (it is proved only under the open invariant, LO-0004 stdout DIAG_OK_UNDER) *)
val _ = explore "refund_profile_a_sl_fd1/Success" fd1_succ_tm (fn () =>
  let val LOUT_A = ASSUME (lout_tm ())
  in
  [("intro", rpt strip_tac, []),
   ("witness", qexistsl_tac [`Success`, `io`], []),
   ("simp_shape", simp[], []),
   ("lout", drule_all LOUT_A, [irule LOUT_A \\ metis_tac [], metis_tac [LOUT_A]]),
   ("close", disch_then MATCH_ACCEPT_TAC, [simp[], strip_tac \\ first_assum ACCEPT_TAC])]
  end);

(* (3e) Resource_limit_hit case, refund_L_OUT_prefix ASSUMEd *)
val _ = explore "refund_profile_a_sl_fd1/Resource_limit_hit" fd1_rlh_tm (fn () =>
  let val LOUTP_A = ASSUME (loutp_tm ())
  in
  [("intro", rpt strip_tac, []),
   ("witness", qexistsl_tac [`Resource_limit_hit`, `io'`], []),
   ("simp_shape", simp[], []),
   ("loutp", drule_all LOUTP_A, [irule LOUTP_A \\ metis_tac [], metis_tac [LOUTP_A]]),
   ("close", disch_then MATCH_ACCEPT_TAC, [simp[], strip_tac \\ first_assum ACCEPT_TAC])]
  end);

(* (3f) the lemma itself; the two cases ASSUMEd *)
val _ = explore "refund_profile_a_sl_fd1" fd1_tm (fn () =>
  let val SUCC_A = ASSUME (fd1_succ_tm ())
      val RLH_A = ASSUME (fd1_rlh_tm ())
  in
  [("disch_spec", DISCH_THEN (fn th => STRIP_ASSUME_TAC th \\ STRIP_ASSUME_TAC (MP SPE_NOEXT th)),
      [DISCH_TAC \\ first_assum (fn th => STRIP_ASSUME_TAC (MP SPE_NOEXT th))]),
   ("witness", qexists_tac `ms`, []),
   ("conj_top", conj_tac, []),
   ("split_ms_TRY", TRY conj_tac, []),
   ("close_ms_TRY", TRY (FIRST [first_assum ACCEPT_TAC,
                                ASM_REWRITE_TAC [AGREE] \\ NO_TAC,
                                ASM_REWRITE_TAC [GSYM AGREE] \\ NO_TAC]), []),
   ("gen_b", qx_gen_tac `bb`, []),
   ("strip_b", strip_tac, []),
   ("spec_b", qpat_x_assum `!b. _` (qspec_then `bb` mp_tac), [first_x_assum (qspec_then `bb` mp_tac)]),
   ("sem_rw", ASM_REWRITE_TAC [], [impl_tac >- first_assum ACCEPT_TAC]),
   ("strip_cases", rpt strip_tac, []),
   ("rveq", rveq, []),
   ("close_cases", FIRST [drule_all SUCC_A \\ disch_then MATCH_ACCEPT_TAC,
                          drule_all RLH_A \\ disch_then MATCH_ACCEPT_TAC],
      [metis_tac [SUCC_A, RLH_A]])]
  end);

val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

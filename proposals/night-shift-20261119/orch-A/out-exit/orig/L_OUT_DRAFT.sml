(* DRAFT. NOT RUN. Worker Y4, graph link X9 (L-OUT). No HOL process was started.
   Read: CK/basis/basis_ffiScript.sml 19-181 (basis_ffi_oracle_def, is_basis_ffi_name_def,
   basis_ffi_def, no_ext_def, extract_fs_with_numchars_def, extract_fs_with_numchars_APPEND,
   extract_fs_def); CK/basis/fsFFIScript.sml 121-240, 300-360, 475-482 (nextFD, openFile, read,
   fsupdate, write, closeFD [asserts isFile], ffi_read, ffi_write, ffi_close, fs_ffi_part);
   CK/basis/fsFFIPropsScript.sml 1310-1440 (STD_streams_def and preservation lemmas);
   CK/basis/TextIOProofScript.sml 242-345, 425-430, 695-726 (stdo_def, add_stdo_def,
   stdo_add_stdo, STD_streams_stdout, stdo_fastForwardFD); CK/basis/MarshallingScript.sml
   (w22n_def, n2w2_def, w82n_def, w22n_n2w2); CK/semantics/ffi/ffiScript.sml 38-80 (io_event,
   call_FFI). Names confirmed in the stored .sig files of CK/basis/.hol/objs.

   FINDING: the X1 draft of L-OUT (M1_EXACT_CLAIM.md §3.1) quantifies over a FREE ext.
   That form is FALSE (control N-O1). An event whose name is not a basis name is replayed by
   ext, and ext may rewrite the stdout inode. Two repairs: (a) instantiate the stored theorem
   at ext := no_ext (it is universal in ext); then a SOME replay forces basis names; or
   (b) add a basis-names premise. (b) does NOT cover the resource-stop disjunct, whose `io` is
   only existential (not a machine trace). So (a) is the form used below. *)

Theory forge_refundLOut
Ancestors
  basis_ffi fsFFI fsFFIProps TextIOProof Marshalling forge_refundSlideProfileA
Libs
  preamble

(* bytes of this trace that successful fd-1 write events appended (as model chars) *)
Definition fd1_written_def:
  (fd1_written [] = []) ∧
  (fd1_written (IO_event (ExtCall n) conf bs :: rest) =
     (if n = «write» ∧ LENGTH conf = 8 ∧ w82n conf = 1 ∧ 4 ≤ LENGTH bs ∧ SND (HD bs) = 0w
      then TAKE (w22n [SND (EL 1 bs); SND (EL 2 bs)])
                (DROP (w22n [FST (EL 2 bs); FST (EL 3 bs)]) (MAP (CHR o w2n o FST) (DROP 4 bs)))
      else []) ++ fd1_written rest) ∧
  (fd1_written (IO_event (SharedMem op) conf bs :: rest) = fd1_written rest)
End
(* type: io_event list -> string *)

Theorem fd1_written_APPEND:
  ∀xs ys. fd1_written (xs ++ ys) = fd1_written xs ++ fd1_written ys
Proof
  Induct \\ simp[fd1_written_def] \\ Cases \\ Cases_on ‘f’ \\ simp[fd1_written_def]
QED

Theorem fd1_written_prefix:
  ∀io' io. io' ≼ io ⇒ fd1_written io' ≼ fd1_written io
Proof
  rw[rich_listTheory.IS_PREFIX_APPEND] \\ simp[fd1_written_APPEND]
QED

(* a SOME replay under no_ext uses only basis names *)
Theorem extract_no_ext_basis_names:
  ∀io st st'. extract_fs_with_numchars no_ext st io = SOME st' ⇒
    EVERY (λe. ∃n c b. e = IO_event (ExtCall n) c b ∧ is_basis_ffi_name n) io
Proof
  Induct \\ simp[] \\ Cases \\ Cases_on ‘f’
  \\ rw[extract_fs_with_numchars_def, no_ext_def, AllCaseEqs()]
  \\ gvs[fs_ffi_part_def, is_basis_ffi_name_def, AllCaseEqs()] \\ metis_tac[]
QED

(* INVARIANT (the hard step of X9): replay keeps STD_streams and appends exactly fd1_written.
   Cases: write fd 1 (append: off = LENGTH content by STD_streams; k ≤ n < 65536 so
   w22n (n2w2 k) = k; MAP/DROP commute), write fd 2 (stderr only), write other fd (File
   inode; STD_streams uniqueness), failed write (code 1w, fs unchanged), read (bumpFD; fd 1
   is WriteMode so a read on fd 1 fails), open_in/open_out (new File fd at nextFD ∉ {0,1,2}),
   close (closeFD asserts isFile, so fd 0/1/2 are never closed), other basis names (skipped). *)
Theorem extract_no_ext_stdout:
  ∀io cls fs cls' fs'.
    extract_fs_with_numchars no_ext (cls,fs) io = SOME (cls',fs') ∧ STD_streams fs ⇒
    STD_streams fs' ∧
    ∀init. ALOOKUP fs.inode_tbl (UStream «stdout») = SOME init ⇒
           ALOOKUP fs'.inode_tbl (UStream «stdout») = SOME (init ++ fd1_written io)
Proof
  Induct >- simp[extract_fs_with_numchars_def, fd1_written_def]
  \\ Cases \\ Cases_on ‘f’
  \\ rw[Once extract_fs_with_numchars_def, no_ext_def, AllCaseEqs()]
  \\ gvs[fs_ffi_part_def, AllCaseEqs()]
  (* one goal per FFI function; each: show STD_streams of the one-step fs, the one-step
     stdout content, then apply the IH (first_x_assum drule_all) and APPEND_ASSOC *)
  \\ cheat_free_placeholder_PER_CASE   (* NOT WRITTEN: about 5 cases x 10-30 tactic lines *)
QED

(* L-OUT *)
Theorem refund_L_OUT:
  ∀cl fs io out.
    STD_streams fs ∧
    extract_fs no_ext (cl,fs) io = SOME (add_stdout (fastForwardFD fs 0) out) ⇒
    fd1_written io = explode out
Proof
  rw[extract_fs_def] \\ PairCases_on ‘x’ \\ gvs[]
  \\ drule_all extract_no_ext_stdout \\ strip_tac
  \\ drule STD_streams_stdout \\ strip_tac
  \\ ‘stdout (fastForwardFD fs 0) out'’ by simp[stdo_fastForwardFD]
  \\ drule stdo_add_stdo \\ disch_then (qspec_then ‘out’ assume_tac)
  \\ gvs[stdo_def, IO_fs_component_equality]   (* inode_tbl of the numchars update is the same *)
QED

Theorem refund_L_OUT_prefix:
  ∀cl fs io io' out.
    STD_streams fs ∧ io' ≼ io ∧
    extract_fs no_ext (cl,fs) io = SOME (add_stdout (fastForwardFD fs 0) out) ⇒
    fd1_written io' ≼ explode out
Proof
  metis_tac[refund_L_OUT, fd1_written_prefix]
QED

(* COMPOSITION with the stored final theorem (E4 lines 298-331), ext := no_ext *)
Theorem refund_profile_a_sl_fd1:
  refund_entry_pre_sl sl s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ∧
  refund_heap_clear_sl sl h e ∧ envmc.prog_addresses = refund_mem_dm_sl sl h e ∧
  refund_env_ok_sl sl envmc ∧
  stdin_content fs = SOME (explode (sexp_to_string (refund_request charge request original
      remaining enabled opened candidate amount reason))) ∧ wfcl cl ∧ wfFS fs ∧ STD_streams fs ⇒
  ∃ms. (arm8_run 27 s = SOME ms ∧ ms.PC = sl + 0x1000040D0w) ∧
    ∀b. machine_sem (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi no_ext cl fs) ms b ⇒
      ∃t io. b = Terminate t io ∧
        ((t = Success ∧ fd1_written io = explode (refund_render_fields (refund_fields charge
            request original remaining enabled opened candidate amount reason))) ∨
         (t = Resource_limit_hit ∧ fd1_written io ≼ explode (refund_render_fields (refund_fields
            charge request original remaining enabled opened candidate amount reason))))
Proof
  strip_tac
  \\ mp_tac (Q.INST [‘ext’ |-> ‘no_ext’] (SPEC_ALL refund_profile_a_sl_every_machine_run))
  \\ impl_tac >- simp[] \\ strip_tac \\ qexists_tac ‘ms’ \\ simp[]
  \\ rpt strip_tac \\ first_x_assum drule \\ strip_tac \\ gvs[]
  \\ metis_tac[refund_L_OUT, refund_L_OUT_prefix]
QED

(* ---------- NEGATIVE CONTROLS ---------- *)
(* N-O1: with a free ext the lemma is false. fs0: stdin/stdout/stderr empty, fd 0/1/2. *)
Definition fs0_def:
  fs0 = <| inode_tbl := [(UStream «stdin», ""); (UStream «stdout», ""); (UStream «stderr», "")];
           files := []; infds := [(0,(UStream «stdin»,ReadMode,0));
             (1,(UStream «stdout»,WriteMode,0)); (2,(UStream «stderr»,WriteMode,0))];
           numchars := [||]; maxFD := 3 |>
End
Definition ext_bad_def:
  ext_bad = λ(n:ffiname) (st:mlstring list # IO_fs) (c:word8 list) (b:word8 list).
              Oracle_return (FST st, add_stdout (fastForwardFD (SND st) 0) «a») ([]:word8 list)
End
Theorem N_O1_free_ext_breaks:
  STD_streams fs0 ∧
  extract_fs ext_bad ([],fs0) [IO_event (ExtCall «x») [] []] =
    SOME (add_stdout (fastForwardFD fs0 0) «a») ∧
  fd1_written [IO_event (ExtCall «x») [] []] ≠ explode «a»
Proof
  EVAL_TAC   (* may need simp[add_stdo_def, stdo_def, up_stdo_def, fsupdate_def] for the @-term *)
QED
(* N-O2: dropping the success test counts a FAILED write (numchars = [||] makes write fail). *)
(* N-O3: dropping the fd test counts an fd-2 (stderr) write. Each as an EVAL'd witness event
   whose replay under no_ext from fs0 (with numchars := [|5|] for N-O3) is SOME and leaves
   stdout empty while the weakened fd1_written gives a non-empty string. *)

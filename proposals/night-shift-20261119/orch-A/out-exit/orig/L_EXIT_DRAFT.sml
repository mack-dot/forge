(* DRAFT. NOT RUN. Worker Y4, graph link X10 (L-EXIT). No HOL process was started.
   Read: CK/compiler/backend/semantics/targetSemScript.sml 118-232 (evaluate_def, machine_sem_def;
   evaluate_ind in targetSemTheory.sig); CK/semantics/proofs/semanticsPropsScript.sml 219-226
   (extend_with_resource_limit: io_list ≼ l, NOT strict); CK/compiler/encoders/arm8/
   arm8_targetScript.sml 371-377 (get_pc = PC, get_reg s r = s.REG (n2w r));
   CK/compiler/backend/lab_to_targetScript.sml 15-16 (ffi_offset = 16); E4 stdout.log 86-93
   (refund_mc_register_fields_sl: ptr_reg = 0); CK/basis/basis_ffi.c 59, 721-742 (cml_exit);
   stored disassembly of b8ed5ec2...7bb8: installation-premise-20261104/records/otool.stdout
   lines 58 (0x1000040C0 cake_exit: b _cml_exit) and 34662-34677 (_cml_exit: cbz w0 -> skip
   fwrite "Program exited with nonzero exit code.\n" to stderr; mov x0,x19; bl _exit);
   compiler halt sites: stack_removeScript.sml 56-57, 74, 330-331 (halt_inst 0, halt_inst 2),
   stack_allocScript.sml 469, 507, 634 (const 1), data_to_wordScript.sml 67-73 (GiveUp = Alloc -1). *)

Theory forge_refundLExit
Ancestors
  targetSem arm8_target forge_refundSlideProfileA forge_refundLOut
Libs
  preamble

(* L-EXIT-0 (model half, generic; expected easy). The Halt outcome is fixed by the halt
   register: Success iff ptr_reg = 0w; otherwise Resource_limit_hit; else an FFI outcome. *)
Theorem evaluate_Halt_reg:
  ∀mc ffi k ms t ms' ffi'.
    evaluate mc ffi k ms = (Halt t, ms', ffi') ⇒
    (∃e. t = FFI_outcome e) ∨
    (mc.target.get_pc ms' = mc.halt_pc ∧
     ((t = Success ∧ mc.target.get_reg ms' mc.ptr_reg = 0w) ∨
      (t = Resource_limit_hit ∧ mc.target.get_reg ms' mc.ptr_reg ≠ 0w)))
Proof
  recInduct evaluate_ind \\ rpt gen_tac \\ strip_tac \\ rpt gen_tac
  \\ once_rewrite_tac[evaluate_def] \\ rw[]
  \\ gvs[AllCaseEqs(), UNCURRY] \\ rpt (pairarg_tac \\ gvs[])
  \\ res_tac \\ gvs[]       (* the recursive mc differs only in *_interfer fields *)
QED

(* Instance at the M1 record and the stored theorem: halt state, x0 and output together. *)
Theorem refund_profile_a_sl_halt:
  [the 11 premises of refund_profile_a_sl, verbatim as in L_OUT_DRAFT.sml] ⇒
  ∃ms. (arm8_run 27 s = SOME ms ∧ ms.PC = sl + 0x1000040D0w) ∧
    ∀k t ms' st'.
      evaluate (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi no_ext cl fs) k ms =
        (Halt t, ms', st') ⇒
      ms'.PC = sl + 0x1000040C0w ∧
      ((ms'.REG 0w = 0w ∧ t = Success ∧ fd1_written st'.io_events = explode R) ∨
       (ms'.REG 0w ≠ 0w ∧ t = Resource_limit_hit ∧ fd1_written st'.io_events ≼ explode R))
  (* R abbreviates refund_render_fields (refund_fields charge ... reason) *)
Proof
  (* refund_profile_a_sl_fd1 + machine_sem_def (Terminate t st'.io_events) + evaluate_Halt_reg +
     refund_mc_register_fields_sl (ptr_reg = 0) + refund_mc_fields (halt_pc = base - n2w 16)
     + arm8_target_def; FFI_outcome is excluded because every behaviour is Success or RLH. *)
  NOT_WRITTEN
QED

(* L-EXIT-V (the HARD step; OPEN). Not exported by backendProof.compile_correct'. *)
(* Theorem refund_halt_x0_small:
     [11 premises] ⇒ ∃ms. ... ∧ ∀k t ms' st'. evaluate (refund_mc ...) (basis_ffi no_ext cl fs) k ms
       = (Halt t, ms', st') ⇒ ms'.REG 0w ∈ {0w; 1w; 2w}
   Route 1: a stackLang syntactic invariant (every Halt r follows const_inst r w, w ∈ {0,1,2})
   carried through stack_names / stack_to_lab, plus a lab_to_target simulation that EXPOSES the
   ptr_reg value at halt (today it exposes only the outcome). Re-opens lab_to_targetProof.
   Route 2: a byte-level argument on the 163840 code bytes; it needs a bound on the targets of
   indirect branches (br / blr / ret) reaching 0x1000040C0 + sl; no such bound exists. *)

(* Native half: an ASSUMPTION, written as definitions for the native relation (Option A). *)
Definition cml_exit_status_def:      (* POSIX wait: low 8 bits of the int argument (w0) *)
  cml_exit_status (x0 : word64) = w2n ((w2w x0) : word8)
End
Definition cml_exit_stderr_def:      (* otool line 34666: cbz w0 *)
  cml_exit_stderr (x0 : word64) =
    if ((w2w x0) : word32) = 0w then "" else "Program exited with nonzero exit code.\n"
End

(* ---------- NEGATIVE CONTROLS ---------- *)
(* N-E1: the real map is not injective at 0: model RLH can give exit status 0. *)
Theorem N_E1_status_collision:
  cml_exit_status 256w = 0 ∧ cml_exit_status 0x100000000w = 0 ∧
  256w ≠ (0w:word64) ∧ 0x100000000w ≠ (0w:word64)
Proof EVAL_TAC QED
(* N-E2: case x0 = 2^32 is ALSO silent on stderr (indistinguishable from Success). *)
Theorem N_E2_silent_stop:
  cml_exit_stderr 0x100000000w = "" ∧ cml_exit_stderr 256w ≠ ""
Proof EVAL_TAC QED
(* N-E3: the swapped statement (Success iff reg ≠ 0w) is refuted by a one-step machine at
   halt_pc with reg 0w: evaluate mc ffi 1 ms = (Halt Success, ms, ffi) when
   get_pc ms = halt_pc, get_pc ms ∉ prog_addresses, get_reg ms ptr_reg = 0w. *)

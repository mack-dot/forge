open HolKernel boolLib bossLib;
val _ = Globals.max_print_depth := 1000;
val expected = ``
  STD_streams fs ∧
  (stdin_content fs = SOME text ∧ refund_run_wire (implode text) = INL err) ⇒
  ∃h1 h2.
    (SPLIT (st2heap (basis_proj1,basis_proj2)
       (SexpProg$SexpProg_st_2 (basis_ffi ext cl fs,K (K F)))) (h1,h2) ∧
     STDIO fs h1) ∧
    sem_satisfies
      (semantics_dec_list (init_state (basis_ffi ext cl fs)) init_env refund_prog)
      (λbehavior. ∃st3 exn.
        behavior = Terminate Success st3.ffi.io_events ∧
        (∃h3 h4. SPLIT3 (st2heap (basis_proj1,basis_proj2) st3) (h3,h2,h4) ∧
          (&Fail_exn err exn * STDIO (fastForwardFD fs 0)) h3) ∧
        RTC call_FFI_rel (basis_ffi ext cl fs) st3.ffi ∧
        extract_fs ext (cl,fs) st3.ffi.io_events = SOME (fastForwardFD fs 0))``;
val _ = if aconv expected
  (concl forge_refundRejectBasisTheory.refund_error_initialized_semantics)
  then () else raise Fail "Exact initialized exception statement mismatch";
val (program_lhs,program_rhs) = dest_eq
  (concl forge_refundRejectBasisTheory.refund_error_program_identity);
val _ = if aconv program_rhs ``refund_prog`` andalso null (free_vars program_lhs)
  then () else raise Fail "Program identity does not bind exact closed refund_prog";
val (snoc,args) = strip_comb program_lhs;
val _ = if same_const snoc ``SNOC`` andalso length args = 2 andalso
  aconv (hd args) ``Dlet NoLocs (Pcon NONE [])
    (App Opapp [Var (Short «refund_main»); Con NONE []])``
  then () else raise Fail "Exact appended entry declaration mismatch";

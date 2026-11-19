(* DRAFT. NOT RUN. NOT EVIDENCE. Worker Z7, 2026-11-19.
   P9a: the smallest progress theorem worth proving first. It replaces compile_correct by the stored
   backendProofTheory.compile_correct_is_safe_for_space in the M1 chain, so the resource stop becomes
   EXCLUDED under ONE named HOL premise (A-SPACE), instead of ALLOWED as a disjunct.
   Names checked by reading backendProofTheory.sig (compile_correct_is_safe_for_space,
   IMP_is_safe_for_space, is_safe_for_space_def, read_limits_def) and the final statements in
   e4-0001/stdout.log lines 240-331. refund_asm_conf / refund_backend_conf / refund_prog are
   PLACEHOLDERS for the constants of forge_refundArm8Compile (not checked).

   Target statement (shape):

   refund_entry_pre_sl sl s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ∧
   refund_heap_clear_sl sl h e ∧ envmc.prog_addresses = refund_mem_dm_sl sl h e ∧
   refund_env_ok_sl sl envmc ∧
   stdin_content fs = SOME (explode (sexp_to_string (refund_request charge request original
       remaining enabled opened candidate amount reason))) ∧
   wfcl cl ∧ wfFS fs ∧ STD_streams fs ∧
   (* A-SPACE, the new and only extra premise *)
   (∀ms. arm8_run 27 s = SOME ms ⇒
      ∀po. is_safe_for_space (:64) (basis_ffi ext cl fs) po refund_asm_conf refund_backend_conf
             refund_prog (read_limits refund_asm_conf refund_backend_conf
                            (refund_mc (sl + 0x1000040D0w) envmc) ms))
   ⇒
   ∃ms. arm8_run 27 s = SOME ms ∧ ms.PC = sl + 0x1000040D0w ∧
     ∃io. machine_sem (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi ext cl fs) ms =
            {Terminate Success io} ∧
          extract_fs ext (cl,fs) io =
            SOME (add_stdout (fastForwardFD fs 0)
              (refund_render_fields (refund_fields charge request original remaining enabled
                 opened candidate amount reason)))

   Route: MATCH_MP compile_correct_is_safe_for_space refund_arm8_compiled, then the same
   discharges as forge_refundArm8ProofScript.sml (refund_terminate gives semantics_prog =
   {Terminate Success io}; machine_sem_total gives non-emptiness), then the same slide steps.

   Controls (to run with it):
   N1  the same script with the A-SPACE premise deleted must FAIL to close the "=" conclusion
       (weak: a failed tactic is not a refutation; record the failing goal).
   N2  non-vacuity, part 1: EVAL refund_backend_conf.data_conf.gc_kind gives a value <> None
       (by reading arm8_configScript.sml line 43: gc_kind := Simple).
   N3  (optional, cost unknown) A-SPACE is FALSE for (stack_limit, heap_limit) = (0, 0): shows the
       premise is a real constraint. Needs symbolic dataSem evaluation of the program start.
   Limits: stored theories only; 600 CPU s per attempt; at most five attempts; one HOL process.
   What it does NOT give: A-SPACE itself (data_lang_safe_for_space for the refund data program,
   link P9: MISSING), any time bound, anything about the real process. *)

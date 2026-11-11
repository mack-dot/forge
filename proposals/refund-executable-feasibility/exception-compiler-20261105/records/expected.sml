open preamble;
val expected_event_witness = ``
  sem_satisfies source_behaviors
    (λb. ∃x y. b = Terminate outcome (event_of x) ∧ P x y) ⇒
  sem_satisfies source_behaviors
    (λb. ∃io. b = Terminate outcome io ∧ ∃x y. io = event_of x ∧ P x y)``;
val expected_compiled = ``
  targetSem$installed forge_refundArm8Compile$code cbspace
    forge_refundArm8Compile$data data_sp forge_refundArm8Compile$info.lab_conf.ffi_names
    (backendProof$heap_regs arm8_config$arm8_backend_config.stack_conf.reg_names) mc
    forge_refundArm8Compile$info.lab_conf.shmem_extra ms ∧
  backendProof$read_limits arm8_target$arm8_config
    (backend$set_oracle arm8_config$arm8_backend_config oracle) mc ms =
    (stack_limit,heap_limit) ∧
  wfFS fs ∧ STD_streams fs ∧
  TextIOProof$stdin_content fs = SOME text ∧
  forge_refundWireProg$refund_run_wire (implode text) = INL err ∧
  arm8_configProof$is_arm8_machine_config mc ∧
  (∀po. backendProof$is_safe_for_space (:64) (basis_ffi$basis_ffi ext cl fs) po
    arm8_target$arm8_config (backend$set_oracle arm8_config$arm8_backend_config oracle)
    forge_refundWholeProg$refund_prog (stack_limit,heap_limit)) ⇒
  ∃h1 h2.
    SPLIT (st2heap (basis_proj1,basis_proj2)
      (SexpProg$SexpProg_st_2 (basis_ffi ext cl fs,K (K F)))) (h1,h2) ∧
    STDIO fs h1 ∧
    ∃io.
      targetSem$machine_sem mc (basis_ffi ext cl fs) ms = {Terminate Success io} ∧
      ∃st3 exn.
        io = st3.ffi.io_events ∧
        (∃h3 h4. SPLIT3 (st2heap (basis_proj1,basis_proj2) st3) (h3,h2,h4) ∧
          (&Fail_exn err exn * STDIO (fastForwardFD fs 0)) h3) ∧
        RTC call_FFI_rel (basis_ffi ext cl fs) st3.ffi ∧
        extract_fs ext (cl,fs) st3.ffi.io_events = SOME (fastForwardFD fs 0)``;

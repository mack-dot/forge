open preamble;
val required_behavior = ``
  arm8_configProof$is_arm8_machine_config mc /\
  targetSem$installed forge_refundArm8Compile$code cbspace
    forge_refundArm8Compile$data data_sp forge_refundArm8Compile$info.lab_conf.ffi_names
    (backendProof$heap_regs arm8_config$arm8_backend_config.stack_conf.reg_names) mc
    forge_refundArm8Compile$info.lab_conf.shmem_extra ms /\
  TextIOProof$stdin_content fs = SOME (explode (sexp_to_string
    (forge_refund_io$refund_request charge request original remaining enabled opened candidate amount reason))) /\
  wfcl cl /\ wfFS fs /\ STD_streams fs ==>
  ?io_events.
    targetSem$machine_sem mc (basis_ffi$basis_ffi ext cl fs) ms SUBSET
    extend_with_resource_limit {Terminate Success io_events} /\
    basis_ffi$extract_fs ext (cl,fs) io_events = SOME
      (add_stdout (fastForwardFD fs 0)
        (forge_refundWireProg$refund_render_fields
          (forge_refundCertifiedProg$refund_fields charge request original remaining
             enabled opened candidate amount reason)))``;

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
        io = [] ∧
        (∃h3 h4. SPLIT3 (st2heap (basis_proj1,basis_proj2) st3) (h3,h2,h4) ∧
          (&Fail_exn err exn * STDIO (fastForwardFD fs 0)) h3) ∧
        RTC call_FFI_rel (basis_ffi ext cl fs) st3.ffi ∧
        extract_fs ext (cl,fs) st3.ffi.io_events = SOME (fastForwardFD fs 0)``;
val checks = [
  ("exception_event_witness",expected_event_witness,
    forge_refundRejectCompiledTheory.exception_event_witness),
  ("refund_error_compiled_precise",expected_compiled,
    forge_refundRejectCompiledTheory.refund_error_compiled_precise)];
val _ = Globals.max_print_depth := 1000;
val _ = List.app (fn (name,expected,th) =>
  let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
    if aconv expected (concl th) then ()
    else raise Fail ("Exact statement mismatch: " ^ name);
    if null (hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
    then () else raise Fail ("Unexpected dependency: " ^ name);
    print ("IMPORTED_THEOREM " ^ name ^ "\n" ^ Parse.thm_to_string th ^ "\n");
    print ("IMPORTED_ORACLES " ^ String.concatWith "," ors ^ "\n");
    print "IMPORTED_HYPOTHESES 0\nIMPORTED_TAGGED_AXIOMS 0\n"
  end) checks;
val _ = if length (DB.theorems "forge_refundRejectCompiled") = 2
  then () else raise Fail "Unexpected theorem count";
val closure = "forge_refundRejectCompiled" :: Theory.ancestry "forge_refundRejectCompiled";
val _ = List.app (fn name => print ("CLOSURE_NODE " ^ name ^ ":" ^
  String.concatWith "," (Theory.parents name) ^ "\n")) closure;
val _ = List.app (fn name => List.app (fn (a,_) =>
  print ("CLOSURE_AXIOM " ^ name ^ "." ^ a ^ "\n")) (DB.axioms name)) closure;
val _ = print "EXACT_EXPECTED_STATEMENTS true\nERROR_COMPILER_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

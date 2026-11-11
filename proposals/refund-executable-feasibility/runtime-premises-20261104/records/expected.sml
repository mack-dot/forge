open preamble forge_refundPreciseBehaviorTheory;
val expected_precise = ``
  targetSem$installed forge_refundArm8Compile$code cbspace
    forge_refundArm8Compile$data data_sp forge_refundArm8Compile$info.lab_conf.ffi_names
    (backendProof$heap_regs arm8_config$arm8_backend_config.stack_conf.reg_names) mc
    forge_refundArm8Compile$info.lab_conf.shmem_extra ms /\
  backendProof$read_limits arm8_target$arm8_config
    (backend$set_oracle arm8_config$arm8_backend_config oracle) mc ms =
    (stack_limit,heap_limit) /\
  TextIOProof$stdin_content fs = SOME (explode (sexp_to_string
    (forge_refund_io$refund_request charge request original remaining enabled opened candidate amount reason))) /\
  wfcl cl /\ wfFS fs /\ STD_streams fs /\
  arm8_configProof$is_arm8_machine_config mc /\
  (!po. backendProof$is_safe_for_space (:64) (basis_ffi$basis_ffi ext cl fs) po
    arm8_target$arm8_config (backend$set_oracle arm8_config$arm8_backend_config oracle)
    forge_refundWholeProg$refund_prog (stack_limit,heap_limit)) ==>
  ?io_events.
    targetSem$machine_sem mc (basis_ffi$basis_ffi ext cl fs) ms = {Terminate Success io_events} /\
    basis_ffi$extract_fs ext (cl,fs) io_events = SOME
      (add_stdout (fastForwardFD fs 0)
        (forge_refundWireProg$refund_render_fields
          (forge_refundCertifiedProg$refund_fields charge request original remaining
            enabled opened candidate amount reason)))``;
val checks = [
  ("refund_compiled_precise",expected_precise,refund_compiled_precise),
  ("precise_sem_satisfies_IMP_Terminate",``
    sem_satisfies (semantics_dec_list s init_env prog)
      (\b. ?io. b = Terminate outcome io /\ p io) ==>
    prog_syntax_ok prog ==>
    candidate_behaviours SUBSET semantics_prog s init_env prog ==>
    (?b. candidate_behaviours = {b}) ==>
    ?io. candidate_behaviours = {Terminate outcome io} /\ p io``,
    precise_sem_satisfies_IMP_Terminate),
  ("empty_resource_prefix_allowed",``
    Terminate Resource_limit_hit [] IN extend_with_resource_limit {Terminate Success io}``,
    empty_resource_prefix_allowed)];
val _=List.app(fn(name,expected,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if aconv expected (concl th) then () else raise Fail("Exact statement mismatch: "^name);
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("IMPORTED "^name^" EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0\n") end) checks;
val _=if length(DB.theorems "forge_refundPreciseBehavior")=3 then () else raise Fail "Unexpected theorem count";
val closure="forge_refundPreciseBehavior"::Theory.ancestry "forge_refundPreciseBehavior";
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith ","(Theory.parents n)^"\n")) closure;
val _=List.app(fn n=>List.app(fn(a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"\n"))(DB.axioms n)) closure;
val _=print "RUNTIME_IMPORT_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

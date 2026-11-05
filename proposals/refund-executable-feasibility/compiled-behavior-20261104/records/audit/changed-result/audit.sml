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
             enabled opened candidate (amount+1) reason)))``;

val th = forge_refundArm8ProofTheory.refund_compiled_behavior;
val _ = if aconv required_behavior (concl th) then print "EXACT_BEHAVIOR_BINDING\n"
 else raise Fail "Exact compiler behavior statement mismatch";
val (ors,axs)=Tag.dest_tag(Thm.tag th);
val _=if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors
 then () else raise Fail "Unexpected hypotheses or oracle tags";
val _=if length(DB.theorems "forge_refundArm8Proof")=1 then ()
 else raise Fail "Unexpected own theorem count";
val _=print("CHECKED_ORACLES "^String.concatWith "," ors^"\nCHECKED_HYPOTHESES 0\nCHECKED_TAGGED_AXIOMS 0\n");
val closure="forge_refundArm8Proof"::Theory.ancestry "forge_refundArm8Proof";
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith ","(Theory.parents n)^"\n")) closure;
val _=List.app(fn n=>List.app(fn(a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"\n"))(DB.axioms n)) closure;
val _=print "BEHAVIOR_AUDIT_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

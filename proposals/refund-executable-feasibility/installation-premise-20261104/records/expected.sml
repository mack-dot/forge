open preamble forge_refundInstallPremiseTheory forge_refundDataOracleTheory;
val checks=[
 ("emitted_install_jump",``TAKE 4 (DROP 4660 forge_refundArm8Compile$code) =
   arm8_target$arm8_enc (asm$Jump (-4692))``,emitted_install_jump),
 ("install_jump_offset",``lab_to_target$get_jump_offset labLang$Install ffi_names_arg label_map_arg 4660 = -4692``,install_jump_offset),
 ("install_jump_destination",``
   (asmSem$asm (asm$Jump (-4692)) next_pc ((s:64 asm_state) with pc := entry + 4660w)).pc = entry - 32w``,install_jump_destination),
 ("stub_contains_install",``~wordConvs$no_install (data_to_word$Install_code c)``,stub_contains_install),
 ("standard_stubs_require_reachability",``
   ~EVERY (\(name,arity,body). wordConvs$no_install body) (data_to_word$stubs c)``,standard_stubs_require_reachability),
 ("install_safety_cannot_recover",``
   dataSem$evaluate (prog,dataSem$install_sfs closLang$Install s) = (res,s1) ==> ~s1.safe_for_space``,install_safety_cannot_recover),
 ("initial_oracle_relation",``
   dataProps$cc_co_only_diff
     ((dataSem$initial_state ffi dcode ARB ARB pe T lims ss k):(unit,'ffi) dataSem$state)
     (dataSem$initial_state ffi dcode coracle cc pe T lims ss k)``,initial_oracle_relation),
 ("safe_data_execution",``
   dataSem$data_lang_safe_for_space ffi pe dcode lims ss start /\
   dataSem$evaluate
     (dataLang$Call NONE (SOME start) [] NONE,
      ((dataSem$initial_state ffi dcode ARB ARB pe T lims ss k):(unit,'ffi) dataSem$state)) = (res,s1)
   ==> ?t1.
     dataSem$evaluate
       (dataLang$Call NONE (SOME start) [] NONE,
        dataSem$initial_state ffi dcode coracle cc pe T lims ss k) = (res,t1) /\
     dataProps$cc_co_only_diff s1 t1``,safe_data_execution),
 ("refund_data_oracle_independence",``
   let cfg = backend$set_oracle arm8_config$arm8_backend_config oracle;
       dcode = sptree$fromAList (SND(backend$to_data cfg forge_refundWholeProg$refund_prog));
       lims = dataSem$compute_limits cfg.data_conf.len_size (backendProof$is_64_bits (:64))
         cfg.data_conf.has_fp_ops cfg.data_conf.has_fp_tern stack_heap_limit;
       frames = backendProof$compute_stack_frame_sizes arm8_target$arm8_config
         (SND(backend$to_word arm8_target$arm8_config cfg forge_refundWholeProg$refund_prog))
   in
     backendProof$is_safe_for_space (:64) ffi pe arm8_target$arm8_config cfg
       forge_refundWholeProg$refund_prog stack_heap_limit /\
     dataSem$evaluate
       (dataLang$Call NONE (SOME bvl_to_bvi$InitGlobals_location) [] NONE,
        ((dataSem$initial_state ffi dcode ARB ARB pe T lims frames k):(unit,'ffi) dataSem$state)) = (res,s1)
     ==> ?t1.
       dataSem$evaluate
         (dataLang$Call NONE (SOME bvl_to_bvi$InitGlobals_location) [] NONE,
          dataSem$initial_state ffi dcode coracle cc pe T lims frames k) = (res,t1) /\
       dataProps$cc_co_only_diff s1 t1``,refund_data_oracle_independence)];
val _=List.app(fn(name,expected,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if aconv expected (concl th) then () else raise Fail("Exact statement mismatch: "^name);
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("IMPORTED "^name^" EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0\n") end) checks;
val _=if length(DB.theorems "forge_refundInstallPremise")=6 andalso
  length(DB.theorems "forge_refundDataOracle")=3 then () else raise Fail "Unexpected theorem count";
val closure=Lib.mk_set(["forge_refundInstallPremise","forge_refundDataOracle"] @
  Theory.ancestry "forge_refundInstallPremise" @ Theory.ancestry "forge_refundDataOracle");
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith ","(Theory.parents n)^"\n")) closure;
val _=List.app(fn n=>List.app(fn(a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"\n"))(DB.axioms n)) closure;
val _=print "INSTALL_IMPORT_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

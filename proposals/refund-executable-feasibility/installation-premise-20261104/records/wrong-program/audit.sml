open preamble forge_refundDataOracleTheory;
val checks=[
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
       dcode = sptree$fromAList (SND(backend$to_data cfg ([]:ast$dec list)));
       lims = dataSem$compute_limits cfg.data_conf.len_size (backendProof$is_64_bits (:64))
         cfg.data_conf.has_fp_ops cfg.data_conf.has_fp_tern stack_heap_limit;
       frames = backendProof$compute_stack_frame_sizes arm8_target$arm8_config
         (SND(backend$to_word arm8_target$arm8_config cfg ([]:ast$dec list)))
   in
     backendProof$is_safe_for_space (:64) ffi pe arm8_target$arm8_config cfg
       ([]:ast$dec list) stack_heap_limit /\
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
val _=if length(DB.theorems "forge_refundDataOracle")=3 then () else raise Fail "Unexpected theorem count";
val closure="forge_refundDataOracle"::Theory.ancestry "forge_refundDataOracle";
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith ","(Theory.parents n)^"\n")) closure;
val _=List.app(fn n=>List.app(fn(a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"\n"))(DB.axioms n)) closure;
val _=print "INSTALL_IMPORT_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

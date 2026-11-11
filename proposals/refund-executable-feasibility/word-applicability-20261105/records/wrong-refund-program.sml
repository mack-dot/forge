open preamble forge_refundDataBehaviorTheory;
val contract = ``stdin_content fs = SOME(explode(sexp_to_string
 (refund_request charge request original remaining enabled opened candidate amount reason))) /\
 wfcl cl /\ wfFS fs /\ STD_streams fs``;
val source_behavior = ``semantics$semantics_determ
 (ml_prog$init_state (basis_ffi$basis_ffi ext cl fs) with ptr_eq_oracle := po)
 ml_prog$init_env forge_refundWholeProg$refund_prog``;
val data_result = ``dataSem$semantics (basis_ffi$basis_ffi ext cl fs)
 (sptree$fromAList(SND(backend$to_data
   (backend$set_oracle arm8_config$arm8_backend_config oracle) [])))
 (backendProof$cake_orac (:'a) arm8_target$arm8_config info syn
   (SND o SND o SND o SND o SND o backendProof$config_tuple2) (\ps. ps.data_prog))
 (backendProof$backend_from_data_tuple_cc (:'a) arm8_target$arm8_config
   (backend$set_oracle arm8_config$arm8_backend_config oracle)) po
 dataProps$zero_limits sptree$LN bvl_to_bvi$InitGlobals_location``;
val expected_behavior = ``^contract ==> ^source_behavior = {^data_result}``;
val checks=[("compiled_source_data",``
 backend$compile asm_conf cfg prog = SOME(bytes,bitmaps,cfg') ==>
 let (s0,env) = THE(primTypes$prim_sem_env ffi) in
 ~semantics$semantics_prog s0 env prog ffi$Fail /\
 backendProof$backend_config_ok asm_conf cfg ==>
 semantics$semantics_determ (s0 with ptr_eq_oracle := po) env prog =
 {dataSem$semantics ffi (sptree$fromAList(SND(backend$to_data cfg prog)))
   (backendProof$cake_orac (:'a) asm_conf cfg' syn
     (SND o SND o SND o SND o SND o backendProof$config_tuple2) (\ps. ps.data_prog))
   (backendProof$backend_from_data_tuple_cc (:'a) asm_conf cfg) po
   dataProps$zero_limits sptree$LN bvl_to_bvi$InitGlobals_location}``,compiled_source_data),
 ("refund_data_behavior",expected_behavior,refund_data_behavior)];
val _=List.app(fn(name,expected,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if aconv expected (concl th) then () else raise Fail("Exact statement mismatch: "^name);
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("IMPORTED "^name^" EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0\n") end) checks;
val _=if length(DB.theorems "forge_refundDataBehavior")=2 then () else raise Fail "Unexpected theorem count";
val closure=Lib.mk_set("forge_refundDataBehavior"::Theory.ancestry "forge_refundDataBehavior");
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith ","(Theory.parents n)^"\n")) closure;
val _=List.app(fn n=>List.app(fn(a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"\n"))(DB.axioms n)) closure;
val _=print "CONFIG_IMPORT_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

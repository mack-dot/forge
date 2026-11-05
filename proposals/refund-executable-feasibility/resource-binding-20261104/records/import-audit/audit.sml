open preamble;
val expected_config = ``
  find_name (backend$set_oracle arm8_config$arm8_backend_config oracle).stack_conf.reg_names 2 = 1 /\
  find_name (backend$set_oracle arm8_config$arm8_backend_config oracle).stack_conf.reg_names 3 = 2 /\
  find_name (backend$set_oracle arm8_config$arm8_backend_config oracle).stack_conf.reg_names 4 = 3 /\
  2 * max_heap_limit 64 (backend$set_oracle arm8_config$arm8_backend_config oracle).data_conf - 1 = 9007199254740991``;
val expected_limits = ``
  stack_removeProof$get_stack_heap_limit 9007199254740991
    (496542679040w,496811114496w,497079549952w:word64) = (33554384,16777216)``;
val expected_read_limits = ``
  (mc.target.get_reg ms 1:word64) = 496542679040w /\
  mc.target.get_reg ms 2 = 496811114496w /\
  mc.target.get_reg ms 3 = 497079549952w ==>
  backendProof$read_limits arm8_target$arm8_config
    (backend$set_oracle arm8_config$arm8_backend_config oracle) mc ms = (33554384,16777216)``;

val checked = [
 ("recorded_config",expected_config,forge_refundResourceBindingTheory.recorded_config),
 ("recorded_limits",expected_limits,forge_refundResourceBindingTheory.recorded_limits),
 ("recorded_read_limits",expected_read_limits,forge_refundResourceBindingTheory.recorded_read_limits)];
val _ = if length(DB.theorems "forge_refundResourceBinding")=3 then ()
 else raise Fail "Unexpected own theorem count";
val _ = List.app (fn (name,expected,th) =>
 let val (ors,axs)=Tag.dest_tag(Thm.tag th) in
  if aconv expected (concl th) then () else raise Fail("Statement mismatch: "^name);
  if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors
  then () else raise Fail("Unexpected assumption or oracle: "^name);
  print("IMPORTED_THEOREM "^name^" EXACT_STATEMENT true HYPOTHESES 0 TAGGED_AXIOMS 0 ORACLES "^String.concatWith "," ors^"\n")
 end) checked;
val closure="forge_refundResourceBinding"::Theory.ancestry "forge_refundResourceBinding";
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith "," (Theory.parents n)^"\n")) closure;
val _=List.app(fn n=>List.app(fn (a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"\n")) (DB.axioms n)) closure;
val _=print "RESOURCE_IMPORT_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

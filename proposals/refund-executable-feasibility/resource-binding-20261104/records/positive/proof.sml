load "backendProofTheory";
load "arm8_configTheory";
open preamble backendProofTheory;
val _ = OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RESOURCE_OUT"));
val _ = new_theory "forge_refundResourceBinding";
val recorded_config = store_thm("recorded_config", ``
  find_name (backend$set_oracle arm8_config$arm8_backend_config oracle).stack_conf.reg_names 2 = 1 /  find_name (backend$set_oracle arm8_config$arm8_backend_config oracle).stack_conf.reg_names 3 = 2 /  find_name (backend$set_oracle arm8_config$arm8_backend_config oracle).stack_conf.reg_names 4 = 3 /  2 * max_heap_limit 64 (backend$set_oracle arm8_config$arm8_backend_config oracle).data_conf - 1 = 9007199254740991``, EVAL_TAC);
val recorded_limits = store_thm("recorded_limits", ``
  stack_removeProof$get_stack_heap_limit 9007199254740991
    (496542679040w,496811114496w,497079549952w:word64) = (33554384,16777216)``, EVAL_TAC);
val recorded_read_limits = store_thm("recorded_read_limits", ``
  (mc.target.get_reg ms 1:word64) = 496542679040w /  mc.target.get_reg ms 2 = 496811114496w /  mc.target.get_reg ms 3 = 497079549952w ==>
  read_limits arm8_target$arm8_config
    (backend$set_oracle arm8_config$arm8_backend_config oracle) mc ms = (33554384,16777216)``,
  simp[read_limits_def,recorded_config,recorded_limits]);
val _ = List.app (fn (name,th) =>
  let val (ors,axs)=Tag.dest_tag(Thm.tag th) in
    if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
    else raise Fail "Unexpected assumptions or oracle tags";
    print("CHECKED "^name^" "^Parse.thm_to_string th^"\n")
  end) [("recorded_config",recorded_config),("recorded_limits",recorded_limits),("recorded_read_limits",recorded_read_limits)];
val _ = export_theory();
val _ = print "RESOURCE_BINDING_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

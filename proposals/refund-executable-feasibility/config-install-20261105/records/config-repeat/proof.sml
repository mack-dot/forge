open preamble forge_refundClosureInstallTheory;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_refundConfigInstall";
val to_clos_set_oracle = store_thm("to_clos_set_oracle",``
 !c p oracle.
   SND(backend$to_clos (backend$set_oracle c oracle) p) =
   SND(backend$to_clos c p)``,
 rpt gen_tac >> simp[backendTheory.to_clos_def,backendTheory.to_flat_def,
   backendTheory.set_oracle_def,LET_THM] >>
 rpt(pairarg_tac >> fs[]));
val refund_config_no_install = store_thm("refund_config_no_install",``
 !oracle. ~closLang$has_install_list
   (SND(backend$to_clos (backend$set_oracle arm8_config$arm8_backend_config oracle)
     forge_refundWholeProg$refund_prog))``,
 simp[to_clos_set_oracle,refund_closure_no_install]);
val _=List.app(fn(name,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("CHECKED "^name^"\n"^Parse.thm_to_string th^"\n") end)
 [("to_clos_set_oracle",to_clos_set_oracle),("refund_config_no_install",refund_config_no_install)];
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

load "forge_refundArm8CompileTheory";
load "cv_transLib";
open preamble;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_refundClosureInstall";
val input=``closLang$has_install_list
  (SND(backend$to_clos arm8_config$arm8_backend_config
    forge_refundWholeProg$refund_prog))``;
val expanded=REWRITE_CONV[arm8_configTheory.arm8_backend_config_def] input;
val computed=cv_transLib.cv_eval(rhs(concl expanded));
val exact=TRANS expanded computed;
val _=print("REFUND_CLOS_HAS_INSTALL "^term_to_string(rhs(concl exact))^"\n");
val refund_closure_no_install=save_thm("refund_closure_no_install",EQF_ELIM exact);
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

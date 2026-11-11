load "targetPropsTheory";
use "/Users/mackianni/forge/results/refund-target-install-bridge-2026-11-05/attempt-0001/bridge-0005/forge_targetInstallBridgeTheory.sig";
use "/Users/mackianni/forge/results/refund-target-install-bridge-2026-11-05/attempt-0001/bridge-0005/forge_targetInstallBridgeTheory.sml";
open preamble targetSemTheory targetPropsTheory forge_targetInstallBridgeTheory;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_completeInstallExclusion";
val complete_prefix_suffices = store_thm("complete_prefix_suffices",``
  targetSem$evaluate mc ffi k ms = (targetSem$Halt outcome,final_ms,final_ffi) /\
  (!j ms' ffi'. j < k /\
    targetSem$evaluate mc ffi j ms = (targetSem$TimeOut,ms',ffi') ==>
    mc.target.get_pc ms' <> mc.install_pc) ==>
  targetSem$machine_sem (mc with install_interfer := handler) ffi ms =
  targetSem$machine_sem mc ffi ms``,
  strip_tac >> irule machine_sem_install_irrelevant
  >> qx_genl_tac [`j`,`ms'`,`ffi'`] >> strip_tac
  >> Cases_on `j < k` >- metis_tac[]
  >> `?d. j = k + d` by omega
  >> gvs[]
  >> `targetSem$evaluate mc ffi (k+d) ms =
      (targetSem$Halt outcome,final_ms,final_ffi)` by
    metis_tac[targetPropsTheory.evaluate_add_clock,targetSemTheory.machine_result_distinct]
  >> gvs[]);
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

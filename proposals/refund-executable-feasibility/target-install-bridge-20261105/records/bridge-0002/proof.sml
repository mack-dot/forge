load "targetPropsTheory";
open preamble targetSemTheory targetPropsTheory;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_targetInstallBridge";

(* Existing evaluator only. The premise concerns its actual clock prefixes. *)
val evaluate_install_irrelevant = store_thm("evaluate_install_irrelevant",``
  !k mc ffi ms.
    (!j ms' ffi'. j < k /\
      targetSem$evaluate mc ffi j ms = (targetSem$TimeOut,ms',ffi') ==>
      mc.target.get_pc ms' <> mc.install_pc) ==>
    !handler.
      targetSem$evaluate (mc with install_interfer := handler) ffi k ms =
      targetSem$evaluate mc ffi k ms``,
  Induct
  >- simp[targetSemTheory.evaluate_def]
  >> rpt gen_tac >> strip_tac >> gen_tac
  >> `mc.target.get_pc ms <> mc.install_pc` by
    (qpat_x_assum `!j ms' ffi'. _`
       (qspecl_then [`0`,`ms`,`ffi`] mp_tac)
     >> simp[Once targetSemTheory.evaluate_def])
  >> once_rewrite_tac[targetSemTheory.evaluate_def]
  >> simp[targetSemTheory.apply_oracle_def]
  >> rpt (TOP_CASE_TAC >> fs[])
  >> qpat_x_assum `!mc ffi ms. _` irule
  >> rpt gen_tac >> strip_tac
  >> qpat_x_assum `!j ms' ffi'. _`
       (qspecl_then [`SUC j`,`ms'`,`ffi'`] mp_tac)
  >> simp[Once targetSemTheory.evaluate_def,targetSemTheory.apply_oracle_def]);

val machine_sem_install_irrelevant = store_thm("machine_sem_install_irrelevant",``
  (!j ms' ffi'.
    targetSem$evaluate mc ffi j ms = (targetSem$TimeOut,ms',ffi') ==>
    mc.target.get_pc ms' <> mc.install_pc) ==>
  targetSem$machine_sem (mc with install_interfer := handler) ffi ms =
  targetSem$machine_sem mc ffi ms``,
  strip_tac
  >> `!k. targetSem$evaluate (mc with install_interfer := handler) ffi k ms =
           targetSem$evaluate mc ffi k ms` by
    (gen_tac >> irule evaluate_install_irrelevant >> metis_tac[])
  >> rw[FUN_EQ_THM]
  >> Cases_on `x` >> fs[targetSemTheory.machine_sem_def]);

val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

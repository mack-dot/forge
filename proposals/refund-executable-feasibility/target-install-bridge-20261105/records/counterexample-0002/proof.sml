load "targetPropsTheory";
open preamble targetSemTheory targetPropsTheory;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_installExclusionControl";
(* A witness in the published target semantics, not the refund executable. *)
val installer_changes_outcome = store_thm("installer_changes_outcome",``
  let mc = (ARB:(64,num,unit) targetSem$machine_config) with
    <| prog_addresses := {}; ffi_entry_pcs := [];
       halt_pc := 1w; install_pc := 0w;
       target := (ARB:(64,num,unit) asmProps$target) with
         <| get_pc := (\s. n2w s); get_reg := (\s r. 0w) |>;
       install_interfer := (\k x. 1) |>
  in targetSem$evaluate mc ffi 2 0 = (targetSem$Halt ffi$Success,1,ffi) /\
     targetSem$evaluate (mc with install_interfer := (\k x. 2)) ffi 2 0 =
       (targetSem$Error,2,ffi)``,
  simp[targetSemTheory.evaluate_def,targetSemTheory.read_ffi_bytearray_def,
       targetSemTheory.apply_oracle_def,miscTheory.read_bytearray_def,
       miscTheory.find_index_def]);
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

open preamble forge_targetInstallBridgeTheory forge_installExclusionControlTheory;
val checks=[
 ("evaluate_install_irrelevant",``
  !k mc ffi ms.
    (!j ms' ffi'. j < k /\
      targetSem$evaluate mc ffi j ms = (targetSem$TimeOut,ms',ffi') ==>
      mc.target.get_pc ms' <> mc.install_pc) ==>
    !handler.
      targetSem$evaluate (mc with install_interfer := handler) ffi k ms =
      targetSem$evaluate mc ffi k ms``,evaluate_install_irrelevant),
 ("machine_sem_install_irrelevant",``
  (!j ms' ffi'.
    targetSem$evaluate mc ffi j ms = (targetSem$TimeOut,ms',ffi') ==>
    mc.target.get_pc ms' <> mc.install_pc) ==>
  targetSem$machine_sem (mc with install_interfer := handler) ffi ms =
  targetSem$machine_sem mc ffi ms``,machine_sem_install_irrelevant),
 ("installer_changes_outcome",``
  let mc = (ARB:(64,num,unit) targetSem$machine_config) with
    <| prog_addresses := {}; ffi_entry_pcs := [];
       halt_pc := 1w; install_pc := 0w;
       target := (ARB:(64,num,unit) asmProps$target) with
         <| get_pc := (\s. n2w s); get_reg := (\s r. 0w) |>;
       install_interfer := (\k x. 1) |>
  in targetSem$evaluate mc ffi 2 0 = (targetSem$Halt ffi$Success,1,ffi) /\
     targetSem$evaluate (mc with install_interfer := (\k x. 2)) ffi 2 0 =
       (targetSem$Error,2,ffi)``,installer_changes_outcome)];
val _=List.app(fn(name,expected,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if aconv expected (concl th) then () else raise Fail("Exact statement mismatch: "^name);
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("IMPORTED "^name^" EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0\n") end) checks;
val _=if length(DB.theorems "forge_targetInstallBridge")=2 andalso
         length(DB.theorems "forge_installExclusionControl")=1
      then () else raise Fail "Unexpected theorem count";
val closure=Lib.mk_set (["forge_targetInstallBridge","forge_installExclusionControl"] @
 Theory.ancestry "forge_targetInstallBridge" @ Theory.ancestry "forge_installExclusionControl");
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith ","(Theory.parents n)^"\n")) closure;
val _=List.app(fn n=>List.app(fn(a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"\n"))(DB.axioms n)) closure;
val _=print "INSTALL_IMPORT_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;

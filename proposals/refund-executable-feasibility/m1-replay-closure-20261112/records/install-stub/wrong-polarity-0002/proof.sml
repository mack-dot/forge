val _ = load "data_to_wordTheory";
val _ = load "wordConvsTheory";
val _ = load "wordPropsTheory";
open preamble data_to_wordTheory wordConvsTheory wordPropsTheory forge_refundInstallStubTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val t1 = forge_refundInstallStubTheory.install_stub_has_install;
val t2 = forge_refundInstallStubTheory.stubs_contain_install;
val _ = if aconv ``~wordConvs$no_install (data_to_word$Install_code c)`` (concl t1) then () else raise Fail "Exact statement mismatch: install_stub_has_install";
val _ = if aconv ``MEM (data_to_word$Install_location, 3n, data_to_word$Install_code c) (data_to_word$stubs c)`` (concl t2) then () else raise Fail "Exact statement mismatch: stubs_contain_install";
val _ = tags "install_stub_has_install" t1;
val _ = tags "stubs_contain_install" t2;
val _ = if length (DB.theorems "forge_refundInstallStub") = 2 then () else raise Fail "Unexpected theorem count";
val _ = pr ("IMPORTED_THEOREM install_stub_has_install\n" ^ thm_to_string t1);
val _ = pr ("IMPORTED_THEOREM stubs_contain_install\n" ^ thm_to_string t2);
val closure = Lib.mk_set ("forge_refundInstallStub" :: Theory.ancestry "forge_refundInstallStub");
val _ = List.app (fn n => pr ("CLOSURE_NODE " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n))) closure;
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "AFTER_POSITIVE_AUDIT";
(* Altered claim: the stub body satisfies no_install. *)
val _ = if aconv ``wordConvs$no_install (data_to_word$Install_code c)`` (concl t1) then ()
        else raise Fail "Exact statement mismatch: stub claimed install-free";
val _ = pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val _ = OS.Process.exit OS.Process.success;

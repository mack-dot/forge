(* U298, first executable obligation.  Two lemmas about the published stub list.
   The third lemma of stub-0001 is omitted: its attempt ended at the CPU limit. *)
val _ = load "data_to_wordTheory";
val _ = load "wordConvsTheory";
val _ = load "wordPropsTheory";
open preamble data_to_wordTheory wordConvsTheory wordPropsTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_READ_OUT"));
val _ = new_theory "forge_refundInstallStub";
val install_stub_has_install = store_thm ("install_stub_has_install", ``~wordConvs$no_install (data_to_word$Install_code c)``,
  FIRST [simp [Install_code_def, list_Seq_def, wordConvsTheory.no_install_def] >> NO_TAC,
         EVAL_TAC >> NO_TAC,
         rw [Install_code_def, list_Seq_def, wordConvsTheory.no_install_subprogs_def,
             wordConvsTheory.not_created_subprogs_def] >> EVAL_TAC]);
val stubs_contain_install = store_thm ("stubs_contain_install", ``MEM (data_to_word$Install_location, 3n, data_to_word$Install_code c) (data_to_word$stubs c)``,
  FIRST [simp [stubs_def] >> NO_TAC, EVAL_TAC]);
val _ = tags "install_stub_has_install" install_stub_has_install;
val _ = tags "stubs_contain_install" stubs_contain_install;
val _ = pr ("CHECKED install_stub_has_install\n" ^ thm_to_string install_stub_has_install);
val _ = pr ("CHECKED stubs_contain_install\n" ^ thm_to_string stubs_contain_install);
val _ = export_theory ();
val _ = pr "INSTALL_STUB_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

(* U298, first executable obligation: is the premise of the published
   syntactic no-install chain true for the published stub list?
   Each lemma is stored only when its tactic proves it; outcomes are printed. *)
val _ = load "data_to_wordTheory";
val _ = load "wordConvsTheory";
val _ = load "wordPropsTheory";
open preamble data_to_wordTheory wordConvsTheory wordPropsTheory;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_READ_OUT"));
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
val _ = new_theory "forge_refundInstallStub";
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
fun attempt name goal tac =
  (let val th = prove (goal, tac)
       val _ = tags name th
       val th' = save_thm (name, th)
   in pr ("LEMMA_PROVED " ^ name ^ "\n" ^ thm_to_string th') end)
  handle ex => pr ("LEMMA_NOT_PROVED " ^ name ^ " :: " ^ exn_to_string ex);
val _ = pr ("STUBS_MD_DEF\n" ^ thm_to_string stubs_md_def) handle _ => pr "STUBS_MD_DEF unavailable";
val _ = attempt "install_stub_has_install"
  ``~wordConvs$no_install (data_to_word$Install_code c)``
  (FIRST [simp [Install_code_def, list_Seq_def, wordConvsTheory.no_install_def] >> NO_TAC,
          EVAL_TAC >> NO_TAC,
          rw [Install_code_def, list_Seq_def, wordConvsTheory.no_install_subprogs_def,
              wordConvsTheory.not_created_subprogs_def] >> EVAL_TAC]);
val _ = attempt "stubs_contain_install"
  ``MEM (data_to_word$Install_location, 3n, data_to_word$Install_code c) (data_to_word$stubs c)``
  (FIRST [simp [stubs_def] >> NO_TAC, EVAL_TAC]);
val _ = attempt "stub_list_not_no_install_code"
  ``~wordProps$no_install_code (fromAList (data_to_word$stubs_md c))``
  (simp [wordPropsTheory.no_install_code_def] >>
   qexists_tac `data_to_word$Install_location` >>
   FIRST [EVAL_TAC >> NO_TAC,
          simp [stubs_md_def, stubs_def, lookup_fromAList] >> EVAL_TAC >> NO_TAC,
          simp [lookup_fromAList] >> EVAL_TAC >>
          simp [Install_code_def, list_Seq_def, wordConvsTheory.no_install_def]]);
val _ = pr ("THEOREM_COUNT " ^ Int.toString (length (DB.theorems "forge_refundInstallStub")));
val _ = export_theory ();
val _ = pr "INSTALL_STUB_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

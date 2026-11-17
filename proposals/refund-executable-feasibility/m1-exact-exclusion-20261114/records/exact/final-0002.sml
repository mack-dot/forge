(* Exact-program exclusion in the form that install_exclusion_suffices needs, for any installer handler. *)
open preamble targetSemTheory targetPropsTheory lab_to_targetProofTheory
     forge_targetInstallPrefixTheory forge_simReplayTheory forge_refundExactExclusionTheory
     forge_refundExclusionChainTheory forge_installHandlerIrrelevantTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundExclusionFinal";
val exact = DB.fetch "forge_refundExclusionChain" "refund_compile_install_exclusion";
val (ante, conc) = dest_imp (concl exact);
fun fv tm n = valOf (List.find (fn v => fst (dest_var v) = n) (free_vars tm));
val mc2 = fv ante "mc_conf"; val ffi = fv conc "ffi"; val ms = fv conc "ms";
val mc = mk_var ("mc", type_of mc2);
val u298 = ``!j ms' ffi'. targetSem$evaluate ^mc ^ffi j ^ms = (TimeOut,ms',ffi') ==> (^mc).target.get_pc ms' <> (^mc).install_pc``;
val goal = mk_imp (mk_conj (``same_but_install ^mc ^mc2``, ante),
                   mk_conj (u298, ``!k. targetSem$evaluate ^mc ^ffi k ^ms = targetSem$evaluate ^mc2 ^ffi k ^ms``));
val final_thm = store_thm ("refund_install_exclusion_any_handler", goal,
  strip_tac >>
  `^conc` by (match_mp_tac exact >> rpt conj_tac >> first_assum ACCEPT_TAC) >>
  drule_all no_install_prefix_same_but_install >> strip_tac >>
  conj_tac >- (first_x_assum (fn th => ACCEPT_TAC (REWRITE_RULE [no_install_prefix_all] th))) >> first_assum ACCEPT_TAC);
val _ = (tags "refund_install_exclusion_any_handler" final_thm; pr ("CHECKED refund_install_exclusion_any_handler\n" ^ thm_to_string final_thm));
(* Control: the conclusion is exactly the exclusion premise of install_exclusion_suffices (the U298 form). *)
val _ = pr ("U298_FORM " ^ term_to_string u298);
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

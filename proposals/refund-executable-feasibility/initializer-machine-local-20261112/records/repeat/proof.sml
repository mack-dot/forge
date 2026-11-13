load "forge_refundArm8ProofTheory";
open preamble backendProofTheory arm8_configProofTheory forge_refundSuccessfulInitializationTheory
     forge_refundInitializationStaticTheory forge_refundInitialStackCodeTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
(* Construction of the statement from the audited 14-condition theorem (U347). *)
val base = forge_refundInitialStackCodeTheory.refund_initialization_code;
val pred = ``arm8_configProof$is_arm8_machine_config``;
val mc0 = hd (List.filter (fn v => fst (dest_var v) = "mc") (free_vars (concl base)));
val theta = match_type (type_of mc0) (fst (dom_rng (type_of pred)));
val base1 = INST_TYPE theta base;
val mc = inst theta mc0;
val save = hd (List.filter (fn v => fst (dest_var v) = "save_regs") (free_vars (concl base1)));
val base2 = INST [save |-> ``set (^mc).callee_saved_regs``] base1;
val (ante, conclusion) = dest_imp (concl base2);
val conds = strip_conj ante;
val _ = if length conds = 14 then () else raise Fail "Base theorem does not have 14 conditions";
fun only_mc t = List.all (fn v => aconv v mc) (free_vars t);
val kept = List.filter (not o only_mc) conds;
val discharged = List.filter only_mc conds;
val _ = if length kept = 5 andalso length discharged = 9 then () else raise Fail "Unexpected condition split";
val goal = mk_imp (list_mk_conj (mk_comb (pred, mc) :: kept), conclusion);
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _ = new_theory "forge_refundInitializerMachine";
val refund_initialization_machine = store_thm ("refund_initialization_machine", goal,
  strip_tac >> match_mp_tac base2 >> rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >>
  fs [is_arm8_machine_config_def] >> EVAL_TAC);
val _ = tags "refund_initialization_machine" refund_initialization_machine;
val _ = pr ("REMAINING_ANTECEDENTS " ^
  Int.toString (length (strip_conj (fst (dest_imp (concl refund_initialization_machine))))));
val _ = List.app (fn c => pr ("DISCHARGED_CONDITION " ^ term_to_string c)) discharged;
val _ = pr ("CHECKED refund_initialization_machine\n" ^ thm_to_string refund_initialization_machine);
val _ = export_theory ();
val _ = pr "RUNTIME_PROOF_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

load "forge_refundArm8ProofTheory";
open preamble backendProofTheory arm8_configProofTheory targetPropsTheory
     forge_refundSuccessfulInitializationTheory forge_refundInitializationStaticTheory
     forge_refundInitialStackCodeTheory forge_refundInitializerMachineTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
(* Construction of the statement from the audited six-premise theorem (U349). *)
val base = forge_refundInitializerMachineTheory.refund_initialization_machine;
fun var name = hd (List.filter (fn v => fst (dest_var v) = name) (free_vars (concl base)));
val dm = var "dm";
val sdm = var "sdm";
val base2 = INST [dm |-> ``^dm INTER byte_aligned``, sdm |-> ``^sdm INTER byte_aligned``] base;
val (ante, conclusion) = dest_imp (concl base2);
val conds = strip_conj ante;
val _ = if length conds = 6 then () else raise Fail "Base theorem does not have 6 premises";
fun has_const name t = can (find_term (fn c => is_const c andalso fst (dest_const c) = name)) t;
fun is_kept t = has_const "is_arm8_machine_config" t orelse has_const "memory_assumption" t;
val kept = List.filter is_kept conds;
val discharged = List.filter (not o is_kept) conds;
val _ = if length kept = 2 andalso length discharged = 4 then () else raise Fail "Unexpected premise split";
val goal = mk_imp (list_mk_conj kept, conclusion);
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val aligned_mod = MATCH_MP (INST_TYPE [alpha |-> ``:64``] backendProofTheory.byte_aligned_MOD)
                           (EQT_ELIM (EVAL ``good_dimindex (:64)``)) |> SIMP_RULE (srw_ss()) [];
val _ = pr ("ALIGNED_MOD " ^ thm_to_string aligned_mod);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _ = new_theory "forge_refundInitializerAligned";
val refund_initialization_aligned = store_thm ("refund_initialization_aligned", goal,
  strip_tac >> match_mp_tac base2 >> rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >>
  FIRST [metis_tac [GEN_ALL targetPropsTheory.target_io_regs_callee_saved,
                    GEN_ALL targetPropsTheory.target_cc_regs_callee_saved, aligned_mod, IN_INTER],
         (rw [IN_INTER] >> fs [targetPropsTheory.target_io_regs_callee_saved,
                               targetPropsTheory.target_cc_regs_callee_saved] >>
          imp_res_tac aligned_mod >> fs [])]);
val _ = tags "refund_initialization_aligned" refund_initialization_aligned;
val _ = pr ("REMAINING_ANTECEDENTS " ^
  Int.toString (length (strip_conj (fst (dest_imp (concl refund_initialization_aligned))))));
val _ = List.app (fn c => pr ("DISCHARGED_CONDITION " ^ term_to_string c)) discharged;
val _ = pr ("CHECKED refund_initialization_aligned\n" ^ thm_to_string refund_initialization_aligned);
val _ = export_theory ();
val _ = pr "RUNTIME_PROOF_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

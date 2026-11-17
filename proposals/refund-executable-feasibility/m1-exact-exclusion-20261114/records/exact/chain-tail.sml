
val _ = pr "GENERIC_CHAIN_PROVED";
(* Exact instance: code := the exact refund lab program, Inv := the exact-program invariant.
   The two Forge premises are discharged; the remaining premises are those of the published compile-level lemma. *)
val L_tm = ``SND (SND (backend$to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))``;
val gen64 = INST_TYPE [alpha |-> ``:64``] compile_install_exclusion;
fun fv th n = valOf (List.find (fn v => fst (dest_var v) = n) (free_vars (concl th)));
val inv_v = fv gen64 "Inv"; val code_v = fv gen64 "code";
val inv_c = let val c0 = ``refund_lab_inv`` in inst (match_type (type_of c0) (type_of inv_v)) c0 end;
val inst_thm = INST [inv_v |-> inv_c, code_v |-> L_tm] gen64;
val (ante, conc) = dest_imp (concl inst_thm);
val cs = strip_conj ante;
val pub_cs = List.take (cs, length cs - 2);
val _ = if same_const (rator (el 1 (List.drop (cs, length cs - 2)))) ``lab_step_closed`` then () else raise Fail "Unexpected premise order";
val exact_goal = mk_imp (list_mk_conj pub_cs, conc);
val exact_thm = store_thm ("refund_compile_install_exclusion", exact_goal,
  strip_tac >> match_mp_tac inst_thm >> rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >>
  TRY (rewrite_tac [refund_lab_step_closed] >> NO_TAC) >>
  qpat_assum `good_init_state _ _ _ _ _ _ _ _` (fn g => rewrite_tac [MATCH_MP (GEN_ALL refund_lab_inv_init) g]));
val _ = (tags "refund_compile_install_exclusion" exact_thm; pr ("CHECKED refund_compile_install_exclusion\n" ^ thm_to_string exact_thm));
(* Fidelity: the exact theorem has the premises of the generic one, minus the two Forge premises, at the exact program. *)
val _ = pr ("EXACT_PREMISE_COUNT " ^ Int.toString (length pub_cs) ^ " GENERIC_PREMISE_COUNT " ^ Int.toString (length cs));
val _ = if List.exists (fn c => can (find_term (fn x => aconv x inv_c orelse (is_const x andalso fst (dest_const x) = "lab_step_closed"))) c) pub_cs
        then raise Fail "An invariant premise remains" else pr "CONTROL_OK no invariant premise remains in the exact theorem";

val _ = List.app (fn n => let val th = DB.fetch "forge_refundExclusionChain" n in tags n th; pr ("CHECKED " ^ n ^ "\n" ^ thm_to_string th) end)
  ["exclusion_mid", "IMP_state_rel_make_init", "compile_install_exclusion"];
fun origin_check n = let val th = DB.fetch "forge_refundExclusionChain" n
      val bad = List.filter (fn c => let val {Thy,...} = dest_thy_const c in Thy = "backend_asm" orelse Thy = "forge_refundArm8Compile" end) (find_terms is_const (concl th))
  in if null bad then pr ("ORIGIN_OK " ^ n) else raise Fail ("Statement of " ^ n ^ " uses an unexpected constant: " ^ term_to_string (hd bad)) end;
val _ = List.app origin_check ["exclusion_mid", "IMP_state_rel_make_init", "nip_make_init", "compile_install_exclusion", "refund_compile_install_exclusion"];
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

(* Static layout invariant for the installer entry and the corrected strengthened statement. *)
load "lab_to_targetProofTheory";
open preamble labSemTheory targetSemTheory targetPropsTheory asmPropsTheory lab_to_targetProofTheory
     forge_targetInstallPrefixTheory forge_simZeroCaseTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_simLayout";
(* Static layout bound: the encoded program plus the distance to the installer entry does not wrap. *)
val layout_def = Define `code_layout_ok (:'a) code2 <=> LENGTH (prog_to_bytes code2) + 2 * ffi_offset < dimword (:'a)`;
(* Every target state that is state_rel-related to SOME lab state of this code is off the installer entry. *)
val static_goal = ``state_rel (mc_conf,code2,labs,(p:'a word)) s1 t1 ms1 /\ code_layout_ok (:'a) code2 ==>
   no_install_prefix mc_conf ffi 0 (ms1:'state)``;
val static_tac = strip_tac >> match_mp_tac (GEN_ALL state_rel_no_install_prefix_zero) >>
   qexistsl_tac [`t1`,`s1`,`p`,`labs`,`code2`] >> simp[] >>
   `pos_val s1.pc 0 code2 <= LENGTH (prog_to_bytes code2)` by
      (qpat_x_assum `state_rel _ _ _ _` mp_tac >> simp[state_rel_def] >> rpt strip_tac >>
       drule pos_val_bound >> disch_then (qspecl_then [`s1.pc`,`0`] mp_tac) >> simp[]) >>
   fs[layout_def];
(* The bound that the published installed predicate states implies the layout bound. *)
val installed_goal = ``cbspace + LENGTH (prog_to_bytes code2) + ffi_offset * (i + 3) < dimword (:'a) ==> code_layout_ok (:'a) code2``;
val installed_tac = simp[layout_def, lab_to_targetTheory.ffi_offset_def];
val static_thm = store_thm ("state_rel_no_install_prefix_layout", static_goal, static_tac);
val installed_thm = store_thm ("installed_bound_code_layout", installed_goal, installed_tac);
val _ = List.app (fn (n, th) => (tags n th; pr ("CHECKED " ^ n ^ "\n" ^ thm_to_string th)))
   [("state_rel_no_install_prefix_layout", static_thm), ("installed_bound_code_layout", installed_thm)];
(* Corrected strengthened simulation statement: PROPOSED, NOT PROVED. *)
val published = lab_to_targetProofTheory.compile_correct;
val (vars, body) = strip_forall (concl published);
val (ante, conc) = dest_imp body;
val s1 = hd vars; val mc = el 3 vars; val code2 = el 5 vars; val ms1 = List.last vars;
val _ = if fst (dest_var code2) = "code2" then () else raise Fail "Unexpected variable order in the published statement";
val p_var = hd (free_vars (concl published));
val _ = if type_of p_var = ``:'a word`` then () else raise Fail "The code start is not an 'a word";
val (exvars, exbody) = strip_exists conc;
val clock_tm = el 3 (snd (strip_comb (lhs (hd (strip_conj exbody)))));
val lab_premise = ``!k r t. labSem$evaluate (^s1 with clock := k) = (r,t) ==> !i bs n. labSem$asm_fetch t <> SOME (LabAsm Install i bs n)``;
val layout_premise = ``code_layout_ok (:'a) ^code2``;
val prefix_concl = ``no_install_prefix ^mc (^s1).ffi ^clock_tm ^ms1``;
val strengthened = list_mk_forall (vars, mk_imp (list_mk_conj [ante, lab_premise, layout_premise],
                                                 list_mk_exists (exvars, mk_conj (exbody, prefix_concl))));
val _ = pr ("STRENGTHENED_STATEMENT_V2 (PROPOSED, NOT PROVED)\n" ^ term_to_string strengthened);
val (v2, b2) = strip_forall strengthened; val (a2, c2) = dest_imp b2; val (ev2, eb2) = strip_exists c2;
val back = list_mk_forall (v2, mk_imp (hd (strip_conj a2) |> (fn _ => fst (dest_conj a2)), list_mk_exists (ev2, list_mk_conj (butlast (strip_conj eb2)))));
val _ = if aconv back (concl published) then pr "FIDELITY published statement recovered by removing the three additions"
        else raise Fail "Fidelity check failed";
val _ = export_theory ();
val _ = pr "P3_PROOF_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

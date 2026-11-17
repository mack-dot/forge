(* The strengthened simulation statement: type-checked and compared with the published one. NOT proved here.
   Also the first link of the backend chain for refund_alloc_oracle. *)
load "forge_refundArm8ProofTheory"; load "lab_to_targetProofTheory"; load "backendProofTheory"; load "arm8_configProofTheory";
open preamble labSemTheory targetSemTheory forge_targetInstallPrefixTheory forge_refundLabClosureTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundAllocBackend";
val published = lab_to_targetProofTheory.compile_correct;
val (vars, body) = strip_forall (concl published);
val (ante, conc) = dest_imp body;
val s1 = hd vars;
val (exvars, exbody) = strip_exists conc;
val mc = el 3 vars;  val ms1 = List.last vars;
val ffi_tm = ``(^s1).ffi``;
val clock_tm = rand (rator (rand (rator (lhs exbody))))   (* the clock argument of the target evaluator *)
  handle _ => raise Fail "Unexpected shape of the published conclusion";
val lab_premise = ``!k r t. labSem$evaluate (^s1 with clock := k) = (r,t) ==> !i bs n. labSem$asm_fetch t <> SOME (LabAsm Install i bs n)``;
val prefix_concl = ``no_install_prefix ^mc ^ffi_tm ^clock_tm ^ms1``;
val strengthened = list_mk_forall (vars, mk_imp (mk_conj (ante, lab_premise), list_mk_exists (exvars, mk_conj (exbody, prefix_concl))));
val _ = pr ("STRENGTHENED_STATEMENT (PROPOSED, NOT PROVED)\n" ^ term_to_string strengthened);
(* Fidelity: removing the two additions gives exactly the published statement. *)
val (v2, b2) = strip_forall strengthened;
val (a2, c2) = dest_imp b2;
val (ev2, eb2) = strip_exists c2;
val back = list_mk_forall (v2, mk_imp (fst (dest_conj a2) |> (fn _ => list_mk_conj (butlast (strip_conj a2))),
                                       list_mk_exists (ev2, list_mk_conj (butlast (strip_conj eb2)))));
val _ = if aconv back (concl published) then pr "FIDELITY published statement recovered by removing the two additions"
        else raise Fail "Fidelity check failed";
val _ = pr ("PUBLISHED_FREE_VARS " ^ String.concatWith "," (map (fst o dest_var) (free_vars (concl published))));
(* First link of the oracle-specific chain: the published backend theorem at the exact configuration. *)
val c1 = mk_var ("c1", type_of (rand (rand (rand (rhs (snd (dest_exists (concl refund_alloc_compiled))))))) handle _ => type_of ``c:backend$config``);
val eq_tm = snd (dest_exists (concl refund_alloc_compiled));
val (c1v, _) = dest_exists (concl refund_alloc_compiled);
val eq = ASSUME eq_tm;
val backend_alloc = MATCH_MP backendProofTheory.compile_correct eq |> DISCH eq_tm |> GEN c1v;
val _ = tags "refund_alloc_backend_correct" backend_alloc;
val _ = save_thm ("refund_alloc_backend_correct", backend_alloc);
val s = thm_to_string backend_alloc;
val _ = pr ("CHECKED refund_alloc_backend_correct\n" ^ String.substring (s, 0, Int.min (2600, size s)));
val consts = find_terms (fn t => is_const t andalso String.isSubstring "oracle" (fst (dest_const t))) (concl backend_alloc);
val _ = pr ("ORACLE_CONSTANTS " ^ String.concatWith "," (Lib.mk_set (map (fn c => #Thy (dest_thy_const c) ^ "$" ^ #Name (dest_thy_const c)) consts)));
val _ = export_theory ();
val _ = pr "P3_PROOF_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

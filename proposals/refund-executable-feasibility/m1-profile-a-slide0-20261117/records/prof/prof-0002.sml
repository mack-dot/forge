(* U404: (1) A3 as an exact HOL predicate on the environment record (refund_env_ok); (2) the slide-0 composition that joins the
   U387 output equation to the entry-state result, for EVERY environment record that satisfies the predicate, and for the
   abstract environment as an instance; (3) the output equation for every terminating run of that same machine.
   NOT proved: that any real environment satisfies refund_env_ok; the entry state; any slide other than 0; the contract link.
   No profile is approved by this file. *)
open preamble targetSemTheory targetPropsTheory ffiTheory semanticsPropsTheory fsFFITheory basis_ffiTheory TextIOProofTheory
     arm8Theory arm8_targetTheory forge_refundSourceNonFailTheory forge_refundStartupBridgeTheory forge_refundResidualTheory forge_refundEnvModelTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (400, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundProfileA";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
(* mk_thm is used ONLY to let later lemmas be explored after a failure; the run raises Fail before export if any lemma failed,
   and every stored theorem is tag-checked. *)
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; mk_thm ([], goal));
fun instn th l = INST (map (fn (n, tm) => let val v = valOf (List.find (fn v => fst (dest_var v) = n) (free_vars (concl th))) in
     if type_of v = type_of tm then () else (pr ("INSTN_TYPE_MISMATCH " ^ n ^ " : " ^ type_to_string (type_of v) ^ " VERSUS " ^ type_to_string (type_of tm));
                                             raise Fail ("instantiation type mismatch: " ^ n)); v |-> tm end) l) th;
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val envmc = mk_var ("envmc", mcty);
val B = ``0x1000040D0w:word64``;
val MC = ``refund_mc ^B ^envmc``;
val mc_def = DB.fetch "forge_refundStartupBridge" "refund_mc_def";
val fix_def = DB.fetch "forge_refundStartupClause" "arm8_fix_def";
val is_arm8 = DB.fetch "forge_refundStartupBridge" "refund_mc_is_arm8";
val rest2_def = DB.fetch "forge_refundResidual" "refund_installed_rest2_def";
val inst_red = DB.fetch "forge_refundResidual" "refund_installed_from_entry_reduced";
val FC = DB.fetch "forge_refundEnvModel" "ffi_interfer_ok_iff_contract";
val flds2 = DB.fetch "forge_refundEnvModel" "refund_mc_register_fields";
val env_def = DB.fetch "forge_refundEnvModel" "refund_abs_env_def";
val I1 = DB.fetch "forge_refundEnvModel" "refund_id_interfer_ok";
val AB = DB.fetch "forge_refundEnvModel" "refund_abs_ffi_contract";
val beh = DB.fetch "forge_refundSourceNonFail" "refund_behavior_valid_request_no_handler";
val exc = DB.fetch "forge_refundSourceNonFail" "refund_u298_exclusion_valid_request";
val _ = List.app (fn (n, th) => pr ("USED " ^ n ^ "\n" ^ thm_to_string th)) [("refund_installed_from_entry_reduced", inst_red), ("refund_mc_is_arm8", is_arm8),
          ("refund_behavior_valid_request_no_handler", beh), ("refund_u298_exclusion_valid_request", exc)];
(* ---- 1. A3 as a predicate on the environment record. ---- *)
val ok_def = new_definition ("refund_env_ok_def",
  ``refund_env_ok ^envmc <=>
      interference_ok (^envmc).next_interfer (arm8_target.proj (^envmc).prog_addresses) /\
      refund_ffi_contract (^envmc).prog_addresses (^envmc).ffi_interfer``);
val _ = pr ("DEFINITION " ^ thm_to_string ok_def);
val _ = pr "MARK E1";
val mcf = thm "refund_mc_environment_fields"
  ``(^MC).next_interfer = (^envmc).next_interfer /\ (^MC).target = arm8_target /\ (^MC).prog_addresses = (^envmc).prog_addresses``
  (simp [mc_def, fix_def] >> show_tac "MCF");
val E1 = thm "refund_env_ok_iff_installed_residual"
  ``!ms. ms.PC = ^B ==> (refund_installed_rest2 ^MC ms <=> refund_env_ok ^envmc)``
  (rpt strip_tac >> asm_rewrite_tac [rest2_def, ok_def, FC, mcf] >> show_tac "E1");
val E2 = thm "refund_abs_env_is_ok" ``refund_env_ok (refund_abs_env ^envmc)``
  (simp [ok_def, env_def, I1, AB] >> show_tac "E2");
val env_prog = prove (``(refund_abs_env ^envmc).prog_addresses = (^envmc).prog_addresses``, simp [env_def]);
(* ---- 2. The composition at slide 0. ---- *)
val (red_ante, red_conc) = dest_imp (concl inst_red);
val (beh_ante, beh_conc) = dest_imp (concl beh);
val (exc_ante, exc_conc) = dest_imp (concl exc);
val input_prems = List.drop (strip_conj beh_ante, 2);   (* stdin, wfcl, wfFS, STD_streams *)
val _ = List.app (fn t => pr ("INPUT_PREMISE " ^ term_to_string t)) input_prems;
val msv = valOf (List.find (fn v => fst (dest_var v) = "ms") (free_vars beh_ante));
val beh_i = instn beh [("mc0", MC), ("cbspace", ``428n``), ("data_sp", ``0n``)];
val exc_i = instn exc [("mc0", MC), ("cbspace", ``428n``), ("data_sp", ``0n``)];
val (_, beh_ci) = dest_imp (concl beh_i); val (_, exc_ci) = dest_imp (concl exc_i);
val prem_g = list_mk_conj (strip_conj red_ante @ [``refund_env_ok ^envmc``] @ input_prems);
val run_c = ``arm8_run 27 s = SOME ^msv /\ (^msv).PC = ^B``;
val _ = pr "MARK TA0";
val TA0g = thm "refund_profile_a_slide0"
  (mk_imp (prem_g, mk_exists (msv, list_mk_conj [run_c, exc_ci, beh_ci])))
  (strip_tac >> mp_tac inst_red >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
   `refund_installed_rest2 ^MC ms` by (mp_tac (SPEC msv E1) >> asm_rewrite_tac [] >> show_tac "TA0-rest2") >>
   `refund_installed_no_handler ^MC ms 428 0` by res_tac >>
   qexists_tac `ms` >> asm_rewrite_tac [] >> conj_tac
   >- (match_mp_tac exc_i >> asm_rewrite_tac [is_arm8] >> show_tac "TA0-exc")
   >- (match_mp_tac beh_i >> asm_rewrite_tac [is_arm8] >> show_tac "TA0-beh"));
(* The abstract environment as an instance. *)
val TA0a = thm "refund_profile_a_slide0_abstract_env"
  (let val th = INST [envmc |-> ``refund_abs_env ^envmc``] TA0g |> REWRITE_RULE [env_prog, E2] in concl th end)
  (ACCEPT_TAC (INST [envmc |-> ``refund_abs_env ^envmc``] TA0g |> REWRITE_RULE [env_prog, E2]));
(* ---- 3. The output equation belongs to the runs of this machine from this state. ---- *)
val (iov, beh_body) = dest_exists beh_ci;
val [beh_sub, beh_fs] = strip_conj beh_body;
val msem = rand (rator beh_sub);        (* machine_sem MC (basis_ffi ext cl fs) ms *)
val _ = pr ("MACHINE_SEM_TERM " ^ term_to_string msem);
val out_fs = rhs beh_fs;
val every_run = ``!b. ^msem b ==>
     (?io. b = Terminate Success io /\ extract_fs ext (cl, fs) io = ^out_fs) \/
     (?io io'. b = Terminate Resource_limit_hit io' /\ io' ≼ io /\ extract_fs ext (cl, fs) io = ^out_fs)``;
val _ = pr "MARK RUNS";
val RUNS = thm "refund_profile_a_slide0_every_machine_run"
  (mk_imp (prem_g, mk_exists (msv, list_mk_conj [run_c, every_run, ``?b. ^msem b``, ``~^msem Fail``])))
  (strip_tac >> mp_tac TA0g >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
   qexists_tac `ms` >> asm_rewrite_tac [machine_sem_total] >> conj_tac
   >- (rpt strip_tac >> `b IN extend_with_resource_limit {Terminate Success io_events}` by (fs [SUBSET_DEF, IN_DEF] >> show_tac "RUNS-in") >>
       pop_assum mp_tac >> simp [extend_with_resource_limit_def] >> strip_tac >> rveq >> fs [] >> metis_tac [] )
   >- (strip_tac >> `Fail IN extend_with_resource_limit {Terminate Success io_events}` by (fs [SUBSET_DEF, IN_DEF] >> show_tac "RUNS-fail") >>
       pop_assum mp_tac >> simp [extend_with_resource_limit_def] >> show_tac "RUNS-nofail"));
(* ---- 4. Negative controls for the predicate. ---- *)
val _ = pr "MARK K";
val N1 = DB.fetch "forge_refundEnvModel" "pc_change_breaks_interference";
val K1 = thm "pc_changing_environment_is_not_ok"
  ``~refund_env_ok (^envmc with next_interfer := (\(i:num) ms. ms with PC := ms.PC + 4w))``
  (simp [ok_def, N1] >> show_tac "K1");
val wr = DB.fetch "forge_refundEnvModel" "wrong_return_address_ffi_rejected";
val _ = pr ("USED wrong_return_address_ffi_rejected\n" ^ thm_to_string wr);
val K2 = thm "env_ok_needs_both_clauses"
  ``refund_env_ok ^envmc ==> interference_ok (^envmc).next_interfer (arm8_target.proj (^envmc).prog_addresses) /\
                             refund_ffi_contract (^envmc).prog_addresses (^envmc).ffi_interfer``
  (simp [ok_def]);
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
(* ---- 5. Structural checks on the stored statements (the output specification is not weakened or assumed). ---- *)
val problems = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun has_const n tm = can (find_term (fn t => is_const t andalso fst (dest_const t) = n)) tm;
val (ta_ante, ta_conc) = dest_imp (concl TA0g);
val (_, ta_body) = dest_exists ta_conc;
val ta_conjs = strip_conj ta_body;
val ta_beh = List.last ta_conjs;
val (io2, bb) = dest_exists ta_beh; val [sub2, fs2] = strip_conj bb;
val _ = if aconv (rhs fs2) (rhs (List.nth (strip_conj (snd (dest_exists beh_conc)), 1)))
        then pr "CONTROL_OK the output term of the composed theorem is syntactically the U387 output term (not weakened, not restated)" else bad "output-term";
val _ = if free_in io2 (rand sub2) andalso free_in io2 (lhs fs2) then pr "CONTROL_OK one io_events is bound for both the machine_sem inclusion and the extract_fs equation"
        else bad "shared-io";
val _ = if aconv (rand (rator sub2)) msem andalso free_in msv msem andalso can (find_term (aconv MC)) msem
        then pr "CONTROL_OK the machine_sem term is for refund_mc 0x1000040D0w envmc, the basis oracle, and the state ms reached by arm8_run 27 s" else bad "machine-term";
val _ = if not (has_const "extract_fs" ta_ante) andalso not (has_const "machine_sem" ta_ante) andalso not (has_const "refund_installed_no_handler" ta_ante)
           andalso has_const "refund_env_ok" ta_ante andalso has_const "refund_entry_pre" ta_ante andalso has_const "stdin_content" ta_ante
        then pr "CONTROL_OK premises: entry state, refund_env_ok, input; no premise mentions extract_fs, machine_sem or refund_installed_no_handler" else bad "premises";
val _ = if not (has_const "semantics_prog" (concl TA0g)) andalso not (has_const "semantics_dec_list" (concl TA0g))
        then pr "CONTROL_OK the composed statement mentions no source-semantics constant: the conclusion is about the machine run only" else bad "source-constant";
val _ = if not (has_const "refund_env_ok" (concl TA0a)) andalso has_const "refund_abs_env" (concl TA0a) then pr "CONTROL_OK the abstract-environment instance has no environment premise"
        else bad "abstract-instance";
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundProfileA" @ DB.definitions "forge_refundProfileA");
val closure = "forge_refundProfileA" :: Theory.ancestry "forge_refundProfileA";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundProfileA")));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = pr ("CLOSURE_HAS_COMPILE_CORRECT_CONTROL " ^ Bool.toString (Lib.mem "forge_compileCorrectControl" closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

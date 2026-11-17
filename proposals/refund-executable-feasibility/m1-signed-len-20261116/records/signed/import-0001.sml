(* Fresh import: control replay, lab facts, exact source-level exclusion. Exact statements, tags, closure, controls. *)
open preamble backendTheory semanticsPropsTheory labSemTheory targetSemTheory targetPropsTheory
     lab_to_targetTheory lab_to_targetProofTheory backendProofTheory arm8_configProofTheory
     forge_targetInstallPrefixTheory forge_simZeroCaseTheory forge_simRootTheory forge_refundExactExclusionTheory
     forge_refundLabFilteredTheory forge_installHandlerIrrelevantTheory forge_refundCompileFactsTheory
     forge_refundExclusionArm8Theory forge_compileCorrectLabFactsTheory forge_refundExclusionSourceTheory
     forge_refundInstallHandlerTheory forge_refundExclusionRealTheory
     forge_refundWholeProgTheory forge_refundSourceNonFailTheory forge_refundStartupClauseTheory
     forge_refundRejectNonFailTheory forge_refundCmlMainStepTheory forge_refundCmlMainSatTheory forge_refundStartupBridgeTheory
     forge_refundCmlMainFrameTheory forge_loaderMemLemmasTheory forge_refundImageTheory forge_refundLoaderMemoryTheory forge_refundEntrySatTheory
     forge_refundInstalledDomainsTheory forge_refundInstalledAssemblyTheory
     forge_refundFfiFactsTheory forge_refundResidualTheory forge_refundEnvModelTheory
     forge_refundFficloseStepTheory forge_refundFficloseBridgeTheory
     forge_refundFficloseAssertTheory forge_refundFficloseComposeTheory forge_refundCallSiteTheory forge_refundSignedLenTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = List.app (fn c => (let val {Name,Thy,...} = dest_thy_const c in Parse.temp_remove_ovl_mapping Name {Name=Name,Thy=Thy} end handle _ => ()))
          (Theory.constants "backend_asm");
fun same a b =
  let fun ok x y = let val (ts, _) = match_term x y in
        List.all (fn {redex, residue} => is_var residue andalso fst (dest_var redex) = fst (dest_var residue)) ts end
  in aconv a b orelse ((ok a b andalso ok b a) handle HOL_ERR _ => false) end;
(* 1. The control replay is the published statement. *)
val pub = DB.fetch "backendProof" "compile_correct'";
val ctl = DB.fetch "forge_compileCorrectControl" "compile_correct'";
val _ = tags "control compile_correct'" ctl;
val _ = if aconv (concl pub) (concl ctl) then pr "IMPORTED forge_compileCorrectControl.compile_correct' IDENTICAL_TO_PUBLISHED true HYPOTHESES 0 TAGGED_AXIOMS 0"
        else raise Fail "control statement differs";
val fid = DB.fetch "forge_compileCorrectLabFacts" "compile_correct_from_guard";
val _ = tags "compile_correct_from_guard" fid;
val _ = if aconv (concl pub) (concl fid) then pr "IMPORTED forge_compileCorrectLabFacts.compile_correct_from_guard IDENTICAL_TO_PUBLISHED true"
        else raise Fail "fidelity statement differs";
(* 2. Exact statements. *)
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val MC = mk_var ("mc_conf", mcty); val MC0 = mk_var ("mc0", mcty);
val cfg = ``set_oracle arm8_backend_config refund_alloc_oracle``;
val CODE = ``forge_refundArm8Compile$code``; val DATA = ``forge_refundArm8Compile$data``;
val nofail = ``~semantics_prog (FST (THE (prim_sem_env (ffi:'ffi ffi_state)))) (SND (THE (prim_sem_env ffi))) refund_prog Fail``;
val inst = ``installed ^CODE cbspace ^DATA data_sp refund_lab_conf2.ffi_names (heap_regs (^cfg).stack_conf.reg_names) (^MC)
               refund_lab_conf2.shmem_extra ms``;
val excl = ``!n. no_install_prefix (^MC) (ffi:'ffi ffi_state) n ms``;
val src_expected = ``is_arm8_machine_config (^MC) /\ ^nofail /\ ^inst ==> ^excl``;
val any_expected = ``same_but_install (^MC0) (^MC) /\ is_arm8_machine_config (^MC) /\ ^nofail /\ ^inst ==>
  (!j ms' ffi'. targetSem$evaluate (^MC0) (ffi:'ffi ffi_state) j ms = (TimeOut,ms',ffi') ==> (^MC0).target.get_pc ms' <> (^MC0).install_pc) /\
  (!k. targetSem$evaluate (^MC0) ffi k ms = targetSem$evaluate (^MC) ffi k ms)``;
val facts_expected = ``backend$compile (asm_conf:asm_config) (c:backend$config) prog = SOME (bytes,bitmaps,c') ==>
   let (s0,env) = THE (prim_sem_env (ffi:'ffi ffi_state)) in
   let s = add_eval_state ev s0 in
   ~semantics_prog s env prog Fail /\
   backend_config_ok asm_conf c /\ lab_to_targetProof$mc_conf_ok (mc:('a,'b,'c) machine_config) /\ mc_init_ok asm_conf c mc /\
   opt_eval_config_wf (:'a) asm_conf c' ev /\
   installed bytes cbspace bitmaps data_sp c'.lab_conf.ffi_names (heap_regs c.stack_conf.reg_names) mc
      c'.lab_conf.shmem_extra ms ==>
   lab_facts asm_conf c prog bytes c' mc ffi ms cbspace``;
val facts_def_expected = ``!asm_conf c prog bytes c' (mc:('a,'b,'c) machine_config) (ffi:'ffi ffi_state) ms cbspace.
    lab_facts asm_conf c prog bytes c' mc ffi ms cbspace <=>
    ?t m dm sdm coracle tl.
      tl = backend$to_lab asm_conf c prog /\
      good_init_state mc ms bytes cbspace t m dm sdm /\
      lab_to_targetProof$compiler_oracle_ok coracle c'.lab_conf.labels (LENGTH bytes) asm_conf mc.ffi_names /\
      lab_to_target$compile asm_conf (FST (SND tl)).lab_conf (SND (SND tl)) = SOME (bytes, c'.lab_conf) /\
      labSem$semantics
        (lab_to_targetProof$make_init mc ffi t m dm sdm ms (SND (SND tl))
           (lab_to_target$compile asm_conf) (mc.target.get_pc ms + n2w (LENGTH bytes)) cbspace coracle) <> Fail``;
val expected = [
 ("forge_compileCorrectLabFacts", "compile_correct_lab_facts", facts_expected),
 ("forge_compileCorrectLabFacts", "lab_facts_def", facts_def_expected),
 ("forge_compileCorrectLabFacts", "lab_guard_def", ``!x Q. lab_guard x Q = if Q then x else x UNION {Fail}``),
 ("forge_refundExclusionSource", "refund_install_exclusion_source", src_expected),
 ("forge_refundExclusionSource", "refund_u298_exclusion_source_any_handler", any_expected)];
val _ = List.app (fn (thy, n, tm) =>
  let val th = DB.fetch thy n in
    if same tm (concl th) then () else (pr ("STORED " ^ n ^ "\n" ^ thm_to_string th); raise Fail ("Exact statement mismatch: " ^ n));
    tags n th; pr ("IMPORTED " ^ thy ^ "." ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end) expected;

(* Real-record theorems: no installer-handler clause. *)
val u298r = ``!j ms' ffi'. targetSem$evaluate (^MC0) (ffi:'ffi ffi_state) j ms = (TimeOut,ms',ffi') ==> (^MC0).target.get_pc ms' <> (^MC0).install_pc``;
val real_expected = ``is_arm8_machine_config (^MC0) /\ ^nofail /\ refund_installed_no_handler (^MC0) ms cbspace data_sp ==> ^u298r``;
val incl_expected = ``is_arm8_machine_config (^MC0) /\ ^nofail /\ refund_installed_no_handler (^MC0) ms cbspace data_sp ==>
   machine_sem (^MC0) (ffi:'ffi ffi_state) ms SUBSET
   extend_with_resource_limit (semantics_prog (FST (THE (prim_sem_env ffi))) (SND (THE (prim_sem_env ffi))) refund_prog)``;
val _ = List.app (fn (thy, n, tm) =>
  let val th = DB.fetch thy n in
    if same tm (concl th) then () else (pr ("STORED " ^ n ^ "\n" ^ thm_to_string th); raise Fail ("Exact statement mismatch: " ^ n));
    tags n th; pr ("IMPORTED " ^ thy ^ "." ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end)
  [("forge_refundExclusionReal", "refund_u298_exclusion_real", real_expected),
   ("forge_refundExclusionReal", "refund_compile_correct_no_handler", incl_expected)];
val wdef = DB.fetch "forge_refundExclusionReal" "refund_installed_no_handler_def";
val _ = tags "refund_installed_no_handler_def" wdef;
val wrhs = rhs (snd (strip_forall (concl wdef)));
fun has_const nm tm = can (find_term (fn t => is_const t andalso fst (dest_const t) = nm)) tm;
val _ = if has_const "install_interfer_ok" wrhs orelse has_const "installed" wrhs orelse has_const "good_init_state" wrhs
        then raise Fail "weak predicate mentions the installer clause" else pr "CONTROL_OK refund_installed_no_handler has no install_interfer_ok, installed or good_init_state constant";
val _ = if has_const "install_interfer_ok" (concl targetSemTheory.good_init_state_def)
        then pr "CONTROL_OK published good_init_state does contain install_interfer_ok" else raise Fail "published definition changed";
val _ = if has_const "code" wrhs andalso has_const "data" wrhs then pr "CONTROL_OK weak predicate names the stored code and data constants"
        else raise Fail "weak predicate does not name the stored constants";
val _ = pr ("DEFINITION " ^ thm_to_string wdef);
val _ = pr ("KEPT " ^ String.concatWith " " (map (fn n => (tags n (DB.fetch "forge_refundInstallHandler" n); n))
   ["arm8_install_handler_ok", "installed_modulo_install_handler", "install_exclusion_suffices"]));
val thys = ["forge_compileCorrectControl", "forge_compileCorrectLabFacts", "forge_refundExclusionSource", "forge_refundExclusionReal"];
val _ = List.app (fn thy => (List.app (fn (n, th) => tags (thy ^ "." ^ n) th) (DB.theorems thy @ DB.definitions thy);
   pr ("STORED_THEOREMS " ^ thy ^ " " ^ Int.toString (length (DB.theorems thy)) ^ " STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions thy)) ^
       " AXIOMS " ^ Int.toString (length (DB.axioms thy))))) thys;
val _ = pr ("STORED heap_regs " ^ thm_to_string ((SIMP_CONV (srw_ss()) [set_oracle_def, heap_regs_def] THENC EVAL) ``heap_regs (^cfg).stack_conf.reg_names``));
(* 3. Earlier theorems and negative controls are still stored. *)
val _ = pr ("KEPT " ^ String.concatWith " " (map (fn (t,n) => (tags n (DB.fetch t n); n))
  [("forge_refundExclusionArm8","refund_install_exclusion_arm8"), ("forge_refundExclusionArm8","refund_install_exclusion_installed"),
   ("forge_refundExclusionArm8","refund_u298_exclusion_any_handler"), ("forge_refundCompileFacts","refund_lab_good_code"),
   ("forge_refundCompileFacts","refund_lab_compile"), ("forge_refundCompileFacts","refund_lab_bitmaps")]));
val _ = pr ("NEGATIVE_CONTROL_KEPT wraparound " ^ thm_to_string (DB.fetch "forge_simZeroCase" "install_entry_wrap_example"));
val _ = pr ("NEGATIVE_CONTROL_KEPT interior " ^ thm_to_string (DB.fetch "forge_simRoot" "endpoint_correspondence_insufficient"));
val _ = pr ("NEGATIVE_CONTROL_KEPT invariant " ^ thm_to_string (DB.fetch "forge_refundExactExclusion" "trivial_invariant_not_closed"));
val _ = pr ("NEGATIVE_CONTROL_KEPT sharemem " ^ thm_to_string (DB.fetch "forge_refundExactExclusion" "sharemem_line_detected"));
val _ = pr ("NEGATIVE_CONTROL_KEPT region29 " ^ thm_to_string (DB.fetch "forge_refundLabFiltered" "filt_walk_single_eval"));
val _ = pr ("NEGATIVE_CONTROL_KEPT handler " ^ thm_to_string (DB.fetch "forge_installHandlerIrrelevant" "handler_matters_when_installer_reached"));
val _ = pr ("NEGATIVE_CONTROL_KEPT good_code " ^ thm_to_string (DB.fetch "forge_refundCompileFacts" "gc_check_rejects_undefined_label"));

(* U387: source non-Fail on valid-request input; start-up clause; machine record. *)
val inp = ``stdin_content fs = SOME (explode (sexp_to_string (refund_request charge request original remaining enabled opened candidate amount reason))) /\
            wfcl cl /\ wfFS fs /\ STD_streams fs``;
val bffi = ``basis_ffi ext cl fs``;
val nofail_b = ``~semantics_prog (FST (THE (prim_sem_env ^bffi))) (SND (THE (prim_sem_env ^bffi))) refund_prog Fail``;
val u298b = ``!j ms' ffi'. targetSem$evaluate (^MC0) ^bffi j ms = (TimeOut,ms',ffi') ==> (^MC0).target.get_pc ms' <> (^MC0).install_pc``;
val weakp = ``refund_installed_no_handler (^MC0) ms cbspace data_sp``;
val outp = ``extract_fs ext (cl,fs) io_events = SOME (add_stdout (fastForwardFD fs 0)
     (refund_render_fields (refund_fields charge request original remaining enabled opened candidate amount reason)))``;
val beh = ``?io_events. machine_sem (^MC0) ^bffi ms SUBSET extend_with_resource_limit {Terminate Success io_events} /\ ^outp``;
val relp = ``is_arm8_machine_config (^MC0) /\ target_state_rel (^MC0).target (t:64 asm_state) ms /\ target_configured t (^MC0)``;
val red_expected = ``^relp ==>
  (refund_startup_clause (^MC0) ms t m bitmap_ptr cbspace data_sp <=>
   3w && ms.PC = 0w /\ 7w && ms.REG 1w = 0w /\ 7w && ms.REG 3w = 0w /\
   ms.REG 1w <=+ ms.REG 3w /\ 8192w <=+ -1w * ms.REG 1w + ms.REG 3w /\
   m (ms.REG 1w) = Word bitmap_ptr /\
   m (ms.REG 1w + 8w) = Word (bitmap_ptr + 20248w) /\
   m (ms.REG 1w + 16w) = Word (bitmap_ptr + n2w (8 * data_sp) + 20248w) /\
   m (ms.REG 1w + 24w) = Word (ms.PC + 0x1FD84w) /\
   m (ms.REG 1w + 32w) = Word (n2w cbspace + ms.PC + 0x1FD84w))``;
val _ = List.app (fn (thy, n, tm) =>
  let val th = DB.fetch thy n in
    if same tm (concl th) then () else (pr ("STORED " ^ n ^ "\n" ^ thm_to_string th); raise Fail ("Exact statement mismatch: " ^ n));
    tags n th; pr ("IMPORTED " ^ thy ^ "." ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end)
  [("forge_refundSourceNonFail", "refund_source_nonfail", ``^inp ==> ^nofail_b``),
   ("forge_refundSourceNonFail", "refund_u298_exclusion_valid_request", ``is_arm8_machine_config (^MC0) /\ ^weakp /\ ^inp ==> ^u298b``),
   ("forge_refundSourceNonFail", "refund_behavior_valid_request_no_handler", ``is_arm8_machine_config (^MC0) /\ ^weakp /\ ^inp ==> ^beh``),
   ("forge_refundSourceNonFail", "semantics_prog_Fail_expanded",
     ``semantics_prog (st:'ffi semanticPrimitives$state) env prog Fail <=>
       ?po k. SND (evaluate_prog_with_clock (st with ptr_eq_oracle := po) env k prog) = Rerr (Rabort Rtype_error)``),
   ("forge_refundStartupClause", "refund_installed_startup", ``^weakp ==> ?t m bitmap_ptr. refund_startup_clause (^MC0) ms t m bitmap_ptr cbspace data_sp``),
   ("forge_refundStartupClause", "refund_startup_clause_arm8", red_expected),
   ("forge_refundStartupClause", "arm8_fix_is_arm8", ``is_arm8_machine_config (arm8_fix (^MC0))``),
   ("forge_refundStartupClause", "is_arm8_iff_fix", ``is_arm8_machine_config (^MC0) <=> arm8_fix (^MC0) = (^MC0)``)];
val _ = List.app (fn thy => (List.app (fn (n, th) => tags (thy ^ "." ^ n) th) (DB.theorems thy @ DB.definitions thy);
   pr ("STORED_THEOREMS " ^ thy ^ " " ^ Int.toString (length (DB.theorems thy)) ^ " STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions thy)) ^
       " AXIOMS " ^ Int.toString (length (DB.axioms thy))))) ["forge_refundSourceNonFail", "forge_refundStartupClause"];
val sdef = DB.fetch "forge_refundStartupClause" "refund_startup_clause_def";
val _ = pr ("DEFINITION " ^ thm_to_string sdef);
val _ = pr ("DEFINITION " ^ thm_to_string (DB.fetch "forge_refundStartupClause" "arm8_fix_def"));
(* Scope controls for U387. *)
val nfc = concl (DB.fetch "forge_refundSourceNonFail" "refund_source_nonfail");
val ffi_arg = rand (rand (rand (rand (rator (rator (rator (dest_neg (snd (dest_imp nfc)))))))));
val _ = if is_var ffi_arg then raise Fail "non-Fail is stated for a variable ffi" else pr ("CONTROL_OK source non-Fail is stated only for " ^ term_to_string ffi_arg);
val _ = if List.exists (fn t => same t nfc) [nofail_b, nofail] then pr "UNEXPECTED_CONTROL_ACCEPTANCE"
        else pr "CONTROL_OK source non-Fail without the input premises, or for a general ffi, is not the stored statement";
val s1c = concl (DB.fetch "forge_refundStartupClause" "refund_installed_startup");
val _ = if is_imp s1c andalso not (has_const "refund_installed_no_handler" (snd (dest_imp s1c))) andalso
           not (List.exists (fn (n, th) => same (snd (strip_forall (concl th))) ``refund_startup_clause (^MC0) ms t m bitmap_ptr cbspace data_sp``)
                  (DB.theorems "forge_refundStartupClause"))
        then pr "CONTROL_OK no stored theorem states the start-up clause without premises" else pr "UNEXPECTED_CONTROL_ACCEPTANCE";

(* U388: reject path, every present standard input, machine record, cml_main step proof, bridge. *)
val inpS = ``stdin_content fs = SOME text /\ wfcl cl /\ wfFS fs /\ STD_streams fs``;
val inpR = ``stdin_content fs = SOME text /\ refund_run_wire (implode text) = INL err /\ wfcl cl /\ wfFS fs /\ STD_streams fs``;
val RMC = ``refund_mc base0 (envmc:^(ty_antiq mcty))``;
val u298m = ``!j ms' ffi'. targetSem$evaluate (^RMC) ^bffi j ms = (TimeOut,ms',ffi') ==> (^RMC).target.get_pc ms' <> (^RMC).install_pc``;
val weakm = ``refund_installed_no_handler (^RMC) ms cbspace data_sp``;
val _ = List.app (fn (thy, n, tm) =>
  let val th = DB.fetch thy n in
    if same tm (concl th) then () else (pr ("STORED " ^ n ^ "\n" ^ thm_to_string th); raise Fail ("Exact statement mismatch: " ^ n));
    tags n th; pr ("IMPORTED " ^ thy ^ "." ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end)
  [("forge_refundRejectNonFail", "refund_source_nonfail_reject", ``^inpR ==> ^nofail_b``),
   ("forge_refundRejectNonFail", "refund_source_nonfail_stdin", ``^inpS ==> ^nofail_b``),
   ("forge_refundRejectNonFail", "refund_u298_exclusion_stdin", ``is_arm8_machine_config (^MC0) /\ ^weakp /\ ^inpS ==> ^u298b``),
   ("forge_refundRejectNonFail", "refund_behavior_stdin_no_handler", ``is_arm8_machine_config (^MC0) /\ ^weakp /\ ^inpS ==>
       ?io_events. machine_sem (^MC0) ^bffi ms SUBSET extend_with_resource_limit {Terminate Success io_events}``),
   ("forge_refundStartupBridge", "refund_mc_is_arm8", ``is_arm8_machine_config (^RMC)``),
   ("forge_refundStartupBridge", "refund_mc_u298_exclusion_stdin", ``^weakm /\ ^inpS ==> ^u298m``),
   ("forge_refundStartupBridge", "refund_mc_behavior_stdin_no_handler", ``^weakm /\ ^inpS ==>
       ?io_events. machine_sem (^RMC) ^bffi ms SUBSET extend_with_resource_limit {Terminate Success io_events}``),
   ("forge_refundStartupBridge", "stdin_absent_characterised",
     ``STD_streams fs ==> (stdin_content fs = NONE <=> ?off. off <> 0 /\ ALOOKUP fs.infds 0 = SOME (UStream «stdin»,ReadMode,off))``),
   ("forge_refundCmlMainStep", "cml_main_run", ``cml_main_pre s h stk e ==>
       ?s1. arm8_run 27 s = SOME s1 /\ s1.PC = 0x1000040D0w /\ s1.REG 0w = 0x1000040D0w /\ s1.REG 1w = h /\ s1.REG 2w = stk /\ s1.REG 3w = e /\
            mem_dword s1.MEM h = 0x10002C018w /\ mem_dword s1.MEM (h + 8w) = 0x100030F30w /\ mem_dword s1.MEM (h + 16w) = 0x100030F30w /\
            mem_dword s1.MEM (h + 24w) = 0x100023E54w /\ mem_dword s1.MEM (h + 32w) = 0x100024000w``),
   ("forge_refundCmlMainStep", "cml_main_wrong_target_refuted", ``cml_main_pre s h stk e ==> ~(?s1. arm8_run 27 s = SOME s1 /\ s1.PC = 0x1000040D4w)``),
   ("forge_refundCmlMainSat", "cml_main_pre_satisfiable", ``?s h stk e. cml_main_pre s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h``),
   ("forge_refundStartupBridge", "refund_startup_established", ``cml_main_pre s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h ==>
       ?ms. arm8_run 27 s = SOME ms /\ ms.PC = 0x1000040D0w /\
            !mc0 t. is_arm8_machine_config (mc0:^(ty_antiq mcty)) /\ target_state_rel mc0.target t ms /\ target_configured t mc0 ==>
                    refund_startup_clause mc0 ms t (\a. Word (mem_dword ms.MEM a)) 0x10002C018w 428 0``)];
val u388 = ["forge_refundRejectNonFail", "forge_refundCmlMainStep", "forge_refundCmlMainSat", "forge_refundStartupBridge"];
val _ = List.app (fn thy => (List.app (fn (n, th) => tags (thy ^ "." ^ n) th) (DB.theorems thy @ DB.definitions thy);
   pr ("STORED_THEOREMS " ^ thy ^ " " ^ Int.toString (length (DB.theorems thy)) ^ " STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions thy)) ^
       " AXIOMS " ^ Int.toString (length (DB.axioms thy))))) u388;
(* Scope controls for U388. *)
val all_thms = List.concat (map DB.theorems (u388 @ ["forge_refundSourceNonFail"]));
fun mentions_nofail th = can (find_term (fn t => same_const t ``Fail:behaviour``)) (concl th) andalso
                         can (find_term (fn t => is_const t andalso fst (dest_const t) = "semantics_prog")) (concl th);
val nf_thms = List.filter (fn (_, th) => mentions_nofail th andalso is_imp (concl th)) all_thms;
val _ = if List.all (fn (n, th) => can (find_term (fn t => is_const t andalso fst (dest_const t) = "stdin_content")) (fst (dest_imp (concl th)))) nf_thms
           andalso length nf_thms >= 3
        then pr ("CONTROL_OK every stored source non-Fail theorem (" ^ Int.toString (length nf_thms) ^ ") has a stdin_content premise; none covers absent input or a general ffi")
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val est = concl (DB.fetch "forge_refundStartupBridge" "refund_startup_established");
val _ = if has_const "cml_main_pre" (fst (dest_imp est)) andalso not (has_const "refund_installed_no_handler" est) andalso not (has_const "installed" est)
        then pr "CONTROL_OK the start-up theorem assumes cml_main_pre and concludes only the start-up clause, not the installed-state predicate"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val mcd = concl (DB.fetch "forge_refundStartupBridge" "refund_mc_def");
val _ = if has_const "install_interfer_ok" mcd then pr "UNEXPECTED_CONTROL_ACCEPTANCE" else pr "CONTROL_OK refund_mc fixes no installer handler; install_interfer stays a parameter";

(* U389: executable bytes against stored code and bitmaps; loader-memory clauses composed with the 27 steps. *)
val main_expected = ``refund_entry_pre s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h ==>
  ?ms. arm8_run 27 s = SOME ms /\ ms.PC = 0x1000040D0w /\ ms.REG 1w = h /\ ms.REG 3w = e /\
       refund_image_mem 0w ms.MEM /\ bytes_in_memory ms.PC ^CODE ms.MEM UNIV /\
       (!md k. (!i. i < LENGTH ^CODE ==> ms.PC + n2w i IN md /\ ms.PC + n2w i NOTIN k) ==> bytes_in_mem ms.PC ^CODE ms.MEM md k) /\
       (!mc0:^(ty_antiq mcty). is_arm8_machine_config mc0 /\ (!i. i < LENGTH ^CODE ==> ms.PC + n2w i IN mc0.prog_addresses) ==> code_loaded ^CODE mc0 ms) /\
       (word_list 0x10002C018w (MAP (Word o n2w) ^DATA) * word_list_exists (0x10002C018w + bytes_in_word * n2w (LENGTH ^DATA)) 0)
          (fun2set ((\a. Word (mem_dword ms.MEM a)), byte_aligned INTER refund_bitmaps_dm)) /\
       (!a. ?w. ms.MEM a = get_byte a w F /\ Word (mem_dword ms.MEM (byte_align a)) = Word w) /\
       !mc0 t. is_arm8_machine_config (mc0:^(ty_antiq mcty)) /\ target_state_rel mc0.target t ms /\ target_configured t mc0 ==>
               refund_startup_clause mc0 ms t (\a. Word (mem_dword ms.MEM a)) 0x10002C018w 428 0``;
val bmc = ``\(m:word64 -> word8) dm r. (word_list 0x10002C018w (MAP (Word o n2w) ^DATA) * r) (fun2set ((\a. Word (mem_dword m a)), dm))``;
val _ = List.app (fn (thy, n, tm) =>
  let val th = DB.fetch thy n in
    if same tm (concl th) then () else (pr ("STORED " ^ n ^ "\n" ^ thm_to_string th); raise Fail ("Exact statement mismatch: " ^ n));
    tags n th; pr ("IMPORTED " ^ thy ^ "." ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end)
  [("forge_refundLoaderMemory", "refund_loader_startup", main_expected),
   ("forge_refundImage", "refund_file_code", ``TAKE (LENGTH ^CODE) (DROP 16592 refund_file) = ^CODE``),
   ("forge_refundImage", "refund_file_bitmaps", ``TAKE 20248 (DROP 180248 refund_file) = FLAT (MAP dword_bytes (MAP n2w ^DATA))``),
   ("forge_refundImage", "refund_file_length", ``LENGTH refund_file = 238776``),
   ("forge_refundImage", "refund_image_mem_def", ``!sl m. refund_image_mem sl m <=>
        bytes_in_memory (0x100000000w + sl) (TAKE 163840 refund_file) m UNIV /\
        bytes_in_memory (0x10002C018w + sl) (TAKE 20248 (DROP 180248 refund_file)) m UNIV``),
   ("forge_refundImage", "refund_image_code", ``!sl m. refund_image_mem sl m ==> bytes_in_memory (0x1000040D0w + sl) ^CODE m UNIV``),
   ("forge_refundImage", "refund_image_bitmaps", ``!sl m i. refund_image_mem sl m /\ i < LENGTH ^DATA ==>
        mem_dword m (0x10002C018w + sl + n2w (8 * i)) = n2w (EL i ^DATA)``),
   ("forge_refundLoaderMemory", "refund_entry_pre_def", ``!s h stk e. refund_entry_pre s h stk e <=>
        ~s.SCTLR_EL1.E0E /\ ~s.SCTLR_EL1.SA0 /\ ~s.TCR_EL1.TBI0 /\ ~s.TCR_EL1.TBI1 /\ s.PSTATE.EL = 0w /\ s.exception = NoException /\
        s.PC = 0x100004000w /\ mem_dword s.MEM 0x10002C000w = h /\ mem_dword s.MEM 0x10002C008w = stk /\ mem_dword s.MEM 0x10002C010w = e /\
        aligned 3 h /\ (!i a. i < 40 /\ 0x100000000w <=+ a /\ a <+ 0x100030F30w ==> h + n2w i <> a) /\ refund_image_mem 0w s.MEM``),
   ("forge_refundLoaderMemory", "refund_entry_pre_IMP_cml_main_pre", ``refund_entry_pre s h stk e ==> cml_main_pre s h stk e``),
   ("forge_refundLoaderMemory", "refund_image_preserved", ``!m m' h. refund_image_mem 0w m /\
        (!i a. i < 40 /\ 0x100000000w <=+ a /\ a <+ 0x100030F30w ==> h + n2w i <> a) /\
        (!a. (!i. i < 40 ==> a <> h + n2w i) ==> m' a = m a) ==> refund_image_mem 0w m'``),
   ("forge_refundLoaderMemory", "code_byte_change_rejected",
      ``!i a (m:word64 -> word8) md k. i < LENGTH ^CODE /\ m (a + n2w i) <> EL i ^CODE ==> ~bytes_in_mem a ^CODE m md k``),
   ("forge_refundLoaderMemory", "code_overlap_rejected",
      ``!i a (m:word64 -> word8) md k. i < LENGTH ^CODE /\ a + n2w i IN k ==> ~bytes_in_mem a ^CODE m md k``),
   ("forge_refundLoaderMemory", "bitmap_word_change_rejected",
      ``!m dm r i. i < LENGTH ^DATA /\ mem_dword m (0x10002C018w + n2w (8 * i)) <> n2w (EL i ^DATA) ==> ~(word_list 0x10002C018w (MAP (Word o n2w) ^DATA) * r) (fun2set ((\a. Word (mem_dword m a)), dm))``),
   ("forge_refundLoaderMemory", "code_wrong_offset_rejected", ``!m md k. refund_image_mem 0w m ==> ~bytes_in_mem 0x1000040D4w ^CODE m md k``),
   ("forge_refundLoaderMemory", "bitmap_wrong_offset_rejected", ``!m dm r. refund_image_mem 0w m ==>
        ~(word_list 0x10002C020w (MAP (Word o n2w) ^DATA) * r) (fun2set ((\a. Word (mem_dword m a)), dm))``),
   ("forge_refundLoaderMemory", "header_on_bitmaps_refuted", ``cml_main_pre s 0x10002C018w stk e ==>
        ?ms. arm8_run 27 s = SOME ms /\ !dm r. ~(word_list 0x10002C018w (MAP (Word o n2w) ^DATA) * r) (fun2set ((\a. Word (mem_dword ms.MEM a)), dm))``),
   ("forge_refundEntrySat", "refund_entry_pre_satisfiable", ``?s h stk e. refund_entry_pre s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h``)];
val u389 = ["forge_refundCmlMainFrame", "forge_loaderMemLemmas", "forge_refundImage", "forge_refundLoaderMemory", "forge_refundEntrySat"];
val _ = List.app (fn thy => (List.app (fn (n, th) => tags (thy ^ "." ^ n) th) (DB.theorems thy @ DB.definitions thy);
   pr ("STORED_THEOREMS " ^ thy ^ " " ^ Int.toString (length (DB.theorems thy)) ^ " STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions thy)) ^
       " AXIOMS " ^ Int.toString (length (DB.axioms thy))))) u389;
val framec = concl (DB.fetch "forge_refundCmlMainFrame" "cml_main_run_frame");
val _ = if has_const "cml_main_pre" (fst (dest_imp framec)) andalso
           List.exists (same ``!a. (!i. i < 40 ==> a <> h + n2w i) ==> (s1:arm8_state).MEM a = (s:arm8_state).MEM a``) (strip_conj (snd (dest_exists (snd (dest_imp framec)))))
        then pr "IMPORTED forge_refundCmlMainFrame.cml_main_run_frame has the frame conjunct for the 40 header bytes" else raise Fail "frame conjunct";
(* Scope controls for U389. *)
val mainc = concl (DB.fetch "forge_refundLoaderMemory" "refund_loader_startup");
val new_thms = List.concat (map (fn t => map (fn (n, th) => (t ^ "." ^ n, th)) (DB.theorems t)) u389);
val _ = if has_const "refund_entry_pre" (fst (dest_imp mainc)) andalso not (has_const "refund_installed_no_handler" mainc) andalso not (has_const "installed" mainc)
           andalso not (List.exists (fn (_, th) => has_const "refund_installed_no_handler" (concl th) orelse has_const "installed" (concl th)) new_thms)
        then pr "CONTROL_OK the loader theorem assumes refund_entry_pre; no U389 theorem states the installed-state predicate"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
fun prem_has nm c = let val b = snd (strip_forall c) in is_imp b andalso has_const nm (fst (dest_imp b)) end;
val unassumed = List.filter (fn (n, th) => has_const "refund_image_mem" (concl th) andalso
     not (prem_has "refund_image_mem" (concl th)) andalso not (prem_has "refund_entry_pre" (concl th))) new_thms;
val _ = if map fst unassumed = ["forge_refundEntrySat.sat_mem_image"]
        then pr "CONTROL_OK the image predicate is a premise in every U389 theorem that uses it; the only unconditional instance is the witness memory sat_mem of the non-vacuity control"
        else (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ String.concatWith " " (map fst unassumed)));
val runs = List.filter (fn (_, th) => has_const "arm8_run" (concl th)) new_thms;
val _ = if List.all (fn (_, th) => not (List.exists (fn v => fst (dest_var v) = "sl") (all_vars (concl th)))) runs andalso
           can (find_term (same ``refund_image_mem 0w (ms:arm8_state).MEM``)) mainc
        then pr ("CONTROL_OK every U389 theorem about arm8_run (" ^ Int.toString (length runs) ^ ") is at slide 0; no theorem composes the steps with a non-zero slide")
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val idef = concl (DB.fetch "forge_refundImage" "refund_image_mem_def");
val _ = if has_const "arm8_run" idef orelse has_const "NextStateARM8" idef then pr "UNEXPECTED_CONTROL_ACCEPTANCE"
        else pr "CONTROL_OK refund_image_mem is a predicate on a memory function only; it contains no loader or step model";
val _ = pr ("NEGATIVE_CONTROL_KEPT " ^ String.concatWith " " ["code_byte_change_rejected", "code_overlap_rejected", "bitmap_word_change_rejected",
            "code_wrong_offset_rejected", "bitmap_wrong_offset_rejected", "header_on_bitmaps_refuted"]);

(* U390: explicit asm state and domains; conditional assembly of the installed-state predicate. *)
val pre390 = ``refund_entry_pre s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h /\ refund_heap_clear h e``;
val RMC0 = ``refund_mc base0 (envmc:^(ty_antiq mcty))``;
val ant390 = list_mk_conj (strip_conj pre390 @ [``(envmc:^(ty_antiq mcty)).prog_addresses = refund_mem_dm h e``] @ strip_conj inpS);
val _ = List.app (fn (thy, n, tm) =>
  let val th = DB.fetch thy n in
    if same tm (concl th) then () else (pr ("STORED " ^ n ^ "\n" ^ thm_to_string th); raise Fail ("Exact statement mismatch: " ^ n));
    tags n th; pr ("IMPORTED " ^ thy ^ "." ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end)
  [("forge_refundInstalledDomains", "refund_code_dm_def", ``refund_code_dm = {a:word64 | 0x1000040D0w <=+ a /\ a <+ 0x100024000w}``),
   ("forge_refundInstalledDomains", "refund_mem_dm_def",
      ``!h e. refund_mem_dm h e = refund_code_dm UNION {w | h <=+ w /\ w <+ e} UNION refund_bitmaps_dm``),
   ("forge_refundInstalledDomains", "refund_heap_clear_def",
      ``!h e. refund_heap_clear h e <=> !a. h <=+ a /\ a <+ e ==> ~(0x100000000w <=+ a /\ a <+ 0x100030F30w)``),
   ("forge_refundInstalledDomains", "refund_t_def", ``!ms. refund_t ms =
      <| regs := (\i. ms.REG (n2w i)); fp_regs := (\i. 0w); mem := ms.MEM; mem_domain := refund_mem_dm (ms.REG 1w) (ms.REG 3w);
         pc := ms.PC; lr := 30; align := 2; be := F; failed := F |>``),
   ("forge_refundInstalledDomains", "refund_t_target_state_rel", ``!ms. refund_end_state ms ==> target_state_rel arm8_target (refund_t ms) ms``),
   ("forge_refundInstalledDomains", "refund_t_target_configured", ``!ms (mc0:^(ty_antiq mcty)). is_arm8_machine_config mc0 /\
        mc0.prog_addresses = refund_mem_dm (ms.REG 1w) (ms.REG 3w) ==> target_configured (refund_t ms) mc0``),
   ("forge_refundInstalledDomains", "refund_code_bytes_in_mem", ``!m h e. refund_heap_clear h e /\ refund_image_mem 0w m ==>
        bytes_in_mem 0x1000040D0w ^CODE m (refund_mem_dm h e) ({w | h <=+ w /\ w <+ e} UNION refund_bitmaps_dm)``),
   ("forge_refundInstalledDomains", "refund_heap_bitmaps_disjoint", ``refund_heap_clear h e ==> DISJOINT {w | h <=+ w /\ w <+ e} refund_bitmaps_dm``),
   ("forge_refundInstalledDomains", "refund_end_state_established", ``^pre390 ==>
        ?ms. arm8_run 27 s = SOME ms /\ ms.REG 1w = h /\ ms.REG 3w = e /\ refund_end_state ms``),
   ("forge_refundInstalledAssembly", "refund_installed_from_end_state", ``is_arm8_machine_config (^MC0) /\
        (^MC0).prog_addresses = refund_mem_dm (ms.REG 1w) (ms.REG 3w) /\ refund_end_state ms /\ refund_installed_rest (^MC0) ms ==>
        refund_installed_no_handler (^MC0) ms 428 0``),
   ("forge_refundInstalledAssembly", "refund_installed_from_entry", ``^pre390 ==>
        ?ms. arm8_run 27 s = SOME ms /\
             !mc0:^(ty_antiq mcty). is_arm8_machine_config mc0 /\ mc0.prog_addresses = refund_mem_dm h e /\ refund_installed_rest mc0 ms ==>
                   refund_installed_no_handler mc0 ms 428 0``),
   ("forge_refundInstalledAssembly", "refund_behavior_from_entry", mk_imp (ant390, ``?ms. arm8_run 27 s = SOME ms /\ (refund_installed_rest (^RMC0) ms ==>
             ?io_events. machine_sem (^RMC0) ^bffi ms SUBSET extend_with_resource_limit {Terminate Success io_events})``)),
   ("forge_refundInstalledAssembly", "refund_u298_exclusion_from_entry", mk_imp (ant390, ``?ms. arm8_run 27 s = SOME ms /\ (refund_installed_rest (^RMC0) ms ==>
             !j ms' ffi'. targetSem$evaluate (^RMC0) ^bffi j ms = (TimeOut,ms',ffi') ==> (^RMC0).target.get_pc ms' <> (^RMC0).install_pc)``)),
   ("forge_refundInstalledAssembly", "heap_on_code_rejected", ``h <=+ 0x1000040D0w /\ 0x1000040D0w <+ e ==> ~refund_heap_clear h e /\
        !m md. ~bytes_in_mem 0x1000040D0w ^CODE m md ({w | h <=+ w /\ w <+ e} UNION refund_bitmaps_dm)``),
   ("forge_refundInstalledAssembly", "heap_on_bitmaps_rejected",
      ``h <=+ 0x10002C018w /\ 0x10002C018w <+ e ==> ~DISJOINT {w | h <=+ w /\ w <+ e} refund_bitmaps_dm``),
   ("forge_refundInstalledAssembly", "code_outside_domain_rejected",
      ``!i a (m:word64 -> word8) md k. i < LENGTH ^CODE /\ a + n2w i NOTIN md ==> ~bytes_in_mem a ^CODE m md k``),
   ("forge_refundInstalledAssembly", "prog_addresses_mismatch_rejected",
      ``!ms mc0. mc0.prog_addresses <> (refund_t ms).mem_domain ==> ~target_configured (refund_t ms) mc0``),
   ("forge_refundInstalledAssembly", "unaligned_heap_end_not_closed",
      ``~(!a:word64. byte_align a IN {w | 0w <=+ w /\ w <+ 1w} ==> a IN {w | 0w <=+ w /\ w <+ 1w})``),
   ("forge_refundInstalledAssembly", "refund_entry_and_heap_premises_satisfiable", ``?s h stk e. ^pre390``)];
val u390 = ["forge_refundInstalledDomains", "forge_refundInstalledAssembly"];
val _ = List.app (fn thy => (List.app (fn (n, th) => tags (thy ^ "." ^ n) th) (DB.theorems thy @ DB.definitions thy);
   pr ("STORED_THEOREMS " ^ thy ^ " " ^ Int.toString (length (DB.theorems thy)) ^ " STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions thy)) ^
       " AXIOMS " ^ Int.toString (length (DB.axioms thy))))) u390;
val thms390 = List.concat (map (fn t => map (fn (n, th) => (n, th)) (DB.theorems t)) u390);
val restd = concl (DB.fetch "forge_refundInstalledAssembly" "refund_installed_rest_def");
val _ = if List.all (fn n => has_const n restd) ["start_pc_ok", "interference_ok", "ffi_interfer_ok", "mmio_pcs_min_index"] andalso
           length (strip_conj (rhs (snd (strip_forall restd)))) = 7
        then pr "CONTROL_OK refund_installed_rest holds the seven unproved clauses: start_pc_ok, interference_ok, ffi_interfer_ok, two shared-address clauses, ffi_names, the mmio clause"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val with_rest = Lib.sort (fn a => fn b => a <= b) (map fst (List.filter (fn (_, th) => has_const "refund_installed_rest" (concl th)) thms390));
val _ = if with_rest = ["refund_behavior_from_entry", "refund_installed_from_end_state", "refund_installed_from_entry", "refund_u298_exclusion_from_entry"]
           andalso List.all (fn (n, th) => not (has_const "refund_installed_no_handler" (concl th)) orelse has_const "refund_installed_rest" (concl th)) thms390
           andalso not (List.exists (fn (_, th) => same (snd (strip_forall (concl th))) ``refund_installed_rest (mc0:^(ty_antiq mcty)) ms``) thms390)
        then pr "CONTROL_OK the residual predicate is only a premise (four theorems); no U390 theorem states the installed-state predicate without it; none proves the residual"
        else pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ String.concatWith " " with_rest);
val runs390 = List.filter (fn (_, th) => has_const "arm8_run" (concl th)) thms390;
val _ = if List.all (fn (_, th) => not (List.exists (fn v => fst (dest_var v) = "sl") (all_vars (concl th))) andalso
                                    (has_const "refund_heap_clear" (fst (dest_imp (concl th))) handle HOL_ERR _ => false)) runs390 andalso length runs390 = 4
        then pr "CONTROL_OK every U390 theorem about arm8_run (4) is at slide 0 and has refund_heap_clear as a premise"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val exc = concl (DB.fetch "forge_refundInstalledAssembly" "refund_u298_exclusion_from_entry");
val _ = if has_const "machine_sem" exc orelse has_const "extend_with_resource_limit" exc then pr "UNEXPECTED_CONTROL_ACCEPTANCE"
        else pr "CONTROL_OK the exclusion theorem from entry states only the installer-entry exclusion; it contains no behaviour-set statement";
val _ = pr ("NEGATIVE_CONTROL_KEPT " ^ String.concatWith " " ["heap_on_code_rejected", "heap_on_bitmaps_rejected", "code_outside_domain_rejected",
            "prog_addresses_mismatch_rejected", "unaligned_heap_end_not_closed"]);

(* U391: five residual clauses discharged at refund_mc 0x1000040D0w envmc; two kept, unproved. *)
val BMC = ``refund_mc 0x1000040D0w (envmc:^(ty_antiq mcty))``;
val pre391 = strip_conj pre390 @ [``(envmc:^(ty_antiq mcty)).prog_addresses = refund_mem_dm h e``];
val u298_391 = ``!j ms' ffi'. targetSem$evaluate (^BMC) ^bffi j ms = (TimeOut,ms',ffi') ==> (^BMC).target.get_pc ms' <> (^BMC).install_pc``;
fun ex391 c = ``?ms. arm8_run 27 s = SOME ms /\ ms.PC = 0x1000040D0w /\ (refund_installed_rest2 (^BMC) ms ==> ^c)``;
val _ = List.app (fn (thy, n, tm) =>
  let val th = DB.fetch thy n in
    if same tm (concl th) then () else (pr ("STORED " ^ n ^ "\n" ^ thm_to_string th); raise Fail ("Exact statement mismatch: " ^ n));
    tags n th; pr ("IMPORTED " ^ thy ^ "." ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end)
  [("forge_refundFfiFacts", "refund_ffi_names", ``?names. refund_lab_conf2.ffi_names = SOME names /\ LENGTH names = 4 /\
        mmio_pcs_min_index names = SOME 4 /\ ffinames_to_string_list names = [«read»; «write»; «close»; «open_in»] /\
        refund_lab_conf2.shmem_extra = []``),
   ("forge_refundResidual", "refund_installed_rest2_def", ``!(mc0:^(ty_antiq mcty)) ms. refund_installed_rest2 mc0 ms <=>
        interference_ok mc0.next_interfer (mc0.target.proj mc0.prog_addresses) /\ ffi_interfer_ok ms.PC mc0``),
   ("forge_refundResidual", "refund_stub_outside_domain",
      ``!a h e. refund_heap_clear h e /\ 0x100000000w <=+ a /\ a <+ 0x1000040D0w ==> a NOTIN refund_mem_dm h e``),
   ("forge_refundResidual", "refund_installed_rest_reduced", ``refund_heap_clear h e /\ (envmc:^(ty_antiq mcty)).prog_addresses = refund_mem_dm h e /\
        ms.PC = 0x1000040D0w /\ refund_installed_rest2 (^BMC) ms ==> refund_installed_rest (^BMC) ms``),
   ("forge_refundResidual", "refund_installed_from_entry_reduced",
      mk_imp (list_mk_conj pre391, ex391 ``refund_installed_no_handler (^BMC) ms 428 0``)),
   ("forge_refundResidual", "refund_behavior_from_entry_reduced",
      mk_imp (list_mk_conj (pre391 @ strip_conj inpS),
              ex391 ``?io_events. machine_sem (^BMC) ^bffi ms SUBSET extend_with_resource_limit {Terminate Success io_events}``)),
   ("forge_refundResidual", "refund_u298_exclusion_from_entry_reduced", mk_imp (list_mk_conj (pre391 @ strip_conj inpS), ex391 u298_391)),
   ("forge_refundResidual", "wrong_base0_rejected", ``!base0 pc. base0 <> pc ==> ~start_pc_ok (refund_mc base0 (envmc:^(ty_antiq mcty))) pc``),
   ("forge_refundResidual", "halt_stub_in_domain_rejected",
      ``!base0 pc. base0 - n2w ffi_offset IN (envmc:^(ty_antiq mcty)).prog_addresses ==> ~start_pc_ok (refund_mc base0 envmc) pc``),
   ("forge_refundResidual", "heap_on_halt_stub_rejected", ``h <=+ 0x1000040C0w /\ 0x1000040C0w <+ e /\
        (envmc:^(ty_antiq mcty)).prog_addresses = refund_mem_dm h e ==> ~start_pc_ok (^BMC) 0x1000040D0w``),
   ("forge_refundResidual", "ffi_entry_stub_in_domain_rejected",
      ``0x1000040A0w IN (envmc:^(ty_antiq mcty)).prog_addresses ==> ~start_pc_ok (^BMC) 0x1000040D0w``)];
val u391 = ["forge_refundFfiFacts", "forge_refundResidual"];
val _ = List.app (fn thy => (List.app (fn (n, th) => tags (thy ^ "." ^ n) th) (DB.theorems thy @ DB.definitions thy);
   pr ("STORED_THEOREMS " ^ thy ^ " " ^ Int.toString (length (DB.theorems thy)) ^ " STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions thy)) ^
       " AXIOMS " ^ Int.toString (length (DB.axioms thy))))) u391;
val thms391 = List.concat (map DB.theorems u391);
val r2d = concl (DB.fetch "forge_refundResidual" "refund_installed_rest2_def");
val with_r2 = Lib.sort (fn a => fn b => a <= b) (map fst (List.filter (fn (_, th) => has_const "refund_installed_rest2" (concl th)) thms391));
val _ = if length (strip_conj (rhs (snd (strip_forall r2d)))) = 2 andalso has_const "interference_ok" r2d andalso has_const "ffi_interfer_ok" r2d andalso
           with_r2 = ["refund_behavior_from_entry_reduced", "refund_installed_from_entry_reduced", "refund_installed_rest_reduced", "refund_u298_exclusion_from_entry_reduced"]
           andalso not (List.exists (fn (_, th) => has_const "interference_ok" (concl th) orelse has_const "ffi_interfer_ok" (concl th)) thms391)
           andalso List.all (fn (n, th) => not (has_const "refund_installed_no_handler" (concl th)) orelse has_const "refund_installed_rest2" (concl th)) thms391
        then pr "CONTROL_OK refund_installed_rest2 is exactly interference_ok and ffi_interfer_ok; it is only a premise (four theorems); no U391 theorem states interference_ok, ffi_interfer_ok, or the installed-state predicate without it"
        else pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ String.concatWith " " with_r2);
val runs391 = List.filter (fn (_, th) => has_const "arm8_run" (concl th)) thms391;
val _ = if length runs391 = 3 andalso List.all (fn (_, th) => not (List.exists (fn v => fst (dest_var v) = "sl") (all_vars (concl th))) andalso
                                    has_const "refund_heap_clear" (fst (dest_imp (concl th))) andalso has_const "refund_entry_pre" (fst (dest_imp (concl th)))) runs391
        then pr "CONTROL_OK every U391 theorem about arm8_run (3) is at slide 0 and keeps refund_entry_pre and refund_heap_clear as premises"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val exc391 = concl (DB.fetch "forge_refundResidual" "refund_u298_exclusion_from_entry_reduced");
val _ = if has_const "machine_sem" exc391 orelse has_const "extend_with_resource_limit" exc391 then pr "UNEXPECTED_CONTROL_ACCEPTANCE"
        else pr "CONTROL_OK the reduced exclusion theorem states only the installer-entry exclusion";
val _ = pr ("NEGATIVE_CONTROL_KEPT " ^ String.concatWith " " ["wrong_base0_rejected", "halt_stub_in_domain_rejected", "heap_on_halt_stub_rejected", "ffi_entry_stub_in_domain_rejected"]);

(* U392: identity environment; exact interference condition; FFI contract; abstract FFI model. *)
val EMC = ``envmc:^(ty_antiq mcty)``;
val AMC = ``refund_mc 0x1000040D0w (refund_abs_env ^EMC)``;
fun ex392 c = ``?ms. arm8_run 27 s = SOME ms /\ ms.PC = 0x1000040D0w /\ ^c``;
fun bad f = ``ffi_interfer_ok 0x1000040D0w (refund_mc 0x1000040D0w (^EMC with ffi_interfer := ^f))``;
val _ = List.app (fn (thy, n, tm) =>
  let val th = DB.fetch thy n in
    if same tm (concl th) then () else (pr ("STORED " ^ n ^ "\n" ^ thm_to_string th); raise Fail ("Exact statement mismatch: " ^ n));
    tags n th; pr ("IMPORTED " ^ thy ^ "." ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end)
  [("forge_refundEnvModel", "refund_id_interfer_def", ``!i ms. refund_id_interfer i ms = ms``),
   ("forge_refundEnvModel", "refund_id_interfer_ok", ``!proj:arm8_state -> 'p. interference_ok refund_id_interfer proj``),
   ("forge_refundEnvModel", "interference_ok_arm8_iff", ``!env dm. interference_ok env (arm8_target.proj dm) <=>
        !i ms. (env i ms).PSTATE = ms.PSTATE /\ (env i ms).SCTLR_EL1 = ms.SCTLR_EL1 /\ (env i ms).TCR_EL1 = ms.TCR_EL1 /\
               (env i ms).exception = ms.exception /\ (env i ms).REG = ms.REG /\ (env i ms).PC = ms.PC /\
               !a. a IN dm ==> (env i ms).MEM a = ms.MEM a``),
   ("forge_refundEnvModel", "refund_outside_interfer_ok", ``!dm f. interference_ok (refund_outside_interfer dm f) (arm8_target.proj dm)``),
   ("forge_refundEnvModel", "refund_ffi_contract_def", ``!dm ffi_i. refund_ffi_contract dm ffi_i <=>
        !k index new_bytes ms2 (t1:64 asm_state) bytes bytes2.
          index < 4 /\ t1.mem_domain = dm /\
          read_bytearray (ms2.REG 0w) (w2n (ms2.REG 1w)) (\a. if a IN dm then SOME (ms2.MEM a) else NONE) = SOME bytes /\
          read_bytearray (ms2.REG 2w) (w2n (ms2.REG 3w)) (\a. if a IN dm then SOME (ms2.MEM a) else NONE) = SOME bytes2 /\
          LENGTH new_bytes = LENGTH bytes2 /\
          target_state_rel arm8_target (t1 with pc := 0x1000040D0w - n2w ((3 + index) * 16)) ms2 /\ aligned 2 (t1.regs 30) ==>
          arm8_ok (ffi_i k (index,new_bytes,ms2)) /\ (ffi_i k (index,new_bytes,ms2)).PC = t1.regs 30 /\
          (!a. a IN dm ==> (ffi_i k (index,new_bytes,ms2)).MEM a = asm_write_bytearray (t1.regs 2) new_bytes t1.mem a) /\
          (!r. MEM r [19;20;21;22;23;24;25;27;28] ==> (ffi_i k (index,new_bytes,ms2)).REG (n2w r) = t1.regs r)``),
   ("forge_refundEnvModel", "ffi_interfer_ok_iff_contract",
      ``ffi_interfer_ok 0x1000040D0w (refund_mc 0x1000040D0w ^EMC) <=> refund_ffi_contract (^EMC).prog_addresses (^EMC).ffi_interfer``),
   ("forge_refundEnvModel", "refund_abs_ffi_def", ``!k x. refund_abs_ffi k x =
        (SND (SND x)) with <| PC := (SND (SND x)).REG 30w; MEM := asm_write_bytearray ((SND (SND x)).REG 2w) (FST (SND x)) (SND (SND x)).MEM |>``),
   ("forge_refundEnvModel", "refund_abs_ffi_contract", ``!dm. refund_ffi_contract dm refund_abs_ffi``),
   ("forge_refundEnvModel", "refund_abs_env_def",
      ``!envmc:^(ty_antiq mcty). refund_abs_env envmc = envmc with <| next_interfer := refund_id_interfer; ffi_interfer := refund_abs_ffi |>``),
   ("forge_refundEnvModel", "refund_abs_env_rest2", ``!ms. ms.PC = 0x1000040D0w ==> refund_installed_rest2 (^AMC) ms``),
   ("forge_refundEnvModel", "refund_installed_abstract_env", mk_imp (list_mk_conj pre391, ex392 ``refund_installed_no_handler (^AMC) ms 428 0``)),
   ("forge_refundEnvModel", "refund_behavior_abstract_env", mk_imp (list_mk_conj (pre391 @ strip_conj inpS),
        ex392 ``?io_events. machine_sem (^AMC) ^bffi ms SUBSET extend_with_resource_limit {Terminate Success io_events}``)),
   ("forge_refundEnvModel", "refund_u298_exclusion_abstract_env", mk_imp (list_mk_conj (pre391 @ strip_conj inpS),
        ex392 ``!j ms' ffi'. targetSem$evaluate (^AMC) ^bffi j ms = (TimeOut,ms',ffi') ==> (^AMC).target.get_pc ms' <> (^AMC).install_pc``)),
   ("forge_refundEnvModel", "protected_write_breaks_interference", ``!dm a. a IN dm ==>
        ~interference_ok (\(i:num) ms. ms with MEM := (a =+ ms.MEM a + 1w) ms.MEM) (arm8_target.proj dm)``),
   ("forge_refundEnvModel", "pc_change_breaks_interference", ``!dm. ~interference_ok (\(i:num) ms. ms with PC := ms.PC + 4w) (arm8_target.proj dm)``),
   ("forge_refundEnvModel", "wrong_return_address_ffi_rejected", ``~^(bad ``refund_bad_return_ffi``)``),
   ("forge_refundEnvModel", "protected_memory_write_ffi_rejected", ``!a. a IN (^EMC).prog_addresses ==> ~^(bad ``refund_bad_memory_ffi a``)``),
   ("forge_refundEnvModel", "clobbered_callee_saved_register_ffi_rejected", ``~^(bad ``refund_bad_register_ffi``)``)];
val u392 = ["forge_refundEnvModel"];
val _ = List.app (fn thy => (List.app (fn (n, th) => tags (thy ^ "." ^ n) th) (DB.theorems thy @ DB.definitions thy);
   pr ("STORED_THEOREMS " ^ thy ^ " " ^ Int.toString (length (DB.theorems thy)) ^ " STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions thy)) ^
       " AXIOMS " ^ Int.toString (length (DB.axioms thy))))) u392;
val thms392 = List.concat (map DB.theorems u392);
val strong = List.filter (fn (_, th) => has_const "refund_installed_no_handler" (concl th) orelse has_const "machine_sem" (concl th) orelse has_const "evaluate" (concl th)) thms392;
val _ = if length strong = 3 andalso List.all (fn (_, th) => has_const "refund_abs_env" (concl th) andalso
              has_const "refund_entry_pre" (fst (dest_imp (concl th))) andalso has_const "refund_heap_clear" (fst (dest_imp (concl th))) andalso
              not (List.exists (fn v => fst (dest_var v) = "sl") (all_vars (concl th)))) strong
        then pr "CONTROL_OK the three U392 theorems without a residual are stated only for the abstract record refund_abs_env; they keep refund_entry_pre and refund_heap_clear and are at slide 0"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val absd = concl (DB.fetch "forge_refundEnvModel" "refund_abs_ffi_def");
val _ = if has_const "basis_ffi" absd orelse List.exists (fn (_, th) => has_const "refund_file" (concl th) orelse has_const "refund_image_mem" (concl th)) thms392
        then pr "UNEXPECTED_CONTROL_ACCEPTANCE"
        else pr "CONTROL_OK refund_abs_ffi is a state function with no oracle; no U392 theorem relates it to executable bytes: the C functions are not modelled";
val gen = concl (DB.fetch "forge_refundEnvModel" "ffi_interfer_ok_iff_contract");
val _ = if is_eq gen andalso not (has_const "refund_abs_ffi" gen) andalso not (has_const "refund_abs_env" gen)
        then pr "CONTROL_OK the contract equivalence is for a general envmc; ffi_interfer_ok is not proved for a general or real ffi_interfer"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val exc392 = concl (DB.fetch "forge_refundEnvModel" "refund_u298_exclusion_abstract_env");
val _ = if has_const "machine_sem" exc392 orelse has_const "extend_with_resource_limit" exc392 then pr "UNEXPECTED_CONTROL_ACCEPTANCE"
        else pr "CONTROL_OK the abstract-environment exclusion theorem states only the installer-entry exclusion";
val _ = pr ("NEGATIVE_CONTROL_KEPT " ^ String.concatWith " " ["protected_write_breaks_interference", "pc_change_breaks_interference",
            "wrong_return_address_ffi_rejected", "protected_memory_write_ffi_rejected", "clobbered_callee_saved_register_ffi_rejected"]);

(* U393: exact steps of the entry stub cake_fficlose, of fficlose up to the import branch, and after an assumed return. *)
val stub_post = ``?s1. arm8_run 1 s = SOME s1 /\ s1.PC = 0x100025260w /\ s1.REG = s.REG /\ s1.MEM = s.MEM /\ s1.SP_EL0 = s.SP_EL0 /\
         s1.PSTATE = s.PSTATE /\ s1.SCTLR_EL1 = s.SCTLR_EL1 /\ s1.TCR_EL1 = s.TCR_EL1 /\ s1.exception = s.exception``;
val _ = List.app (fn (thy, n, tm) =>
  let val th = DB.fetch thy n in
    if same tm (concl th) then () else (pr ("STORED " ^ n ^ "\n" ^ thm_to_string th); raise Fail ("Exact statement mismatch: " ^ n));
    tags n th; pr ("IMPORTED " ^ thy ^ "." ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end)
  [("forge_refundFficloseStep", "arm8_user_def", ``!s. arm8_user s <=> ~s.SCTLR_EL1.E0E /\ ~s.SCTLR_EL1.SA0 /\ ~s.TCR_EL1.TBI0 /\ ~s.TCR_EL1.TBI1 /\
        s.PSTATE.EL = 0w /\ s.exception = NoException``),
   ("forge_refundFficloseStep", "fficlose_stub_pre_def", ``!s. fficlose_stub_pre s <=> arm8_user s /\ s.PC = 0x100004080w /\ fficlose_code_bytes s.MEM``),
   ("forge_refundFficloseStep", "cake_fficlose_stub_run", ``fficlose_stub_pre s ==> ^stub_post``),
   ("forge_refundFficloseStep", "cake_fficlose_stub_wrong_target_refuted",
      ``fficlose_stub_pre s ==> ~(?s1. arm8_run 1 s = SOME s1 /\ s1.PC = 0x100025264w)``),
   ("forge_refundFficloseStep", "cake_fficlose_stub_does_not_return",
      ``fficlose_stub_pre s /\ s.REG 30w <> 0x100025260w ==> ?s1. arm8_run 1 s = SOME s1 /\ s1.PC <> s.REG 30w``),
   ("forge_refundFficloseStep", "fficlose_suffix_wrong_return_refuted",
      ``fficlose_return_pre s b a v20 v19 v29 v30 /\ x <> v30 ==> ~(?s1. arm8_run 6 s = SOME s1 /\ s1.PC = x)``),
   ("forge_refundFficloseStep", "fficlose_corrupted_frame_slot_clobbers_x19",
      ``fficlose_return_pre s b a v20 v19 v29 v30 /\ v19 <> orig ==> ?s1. arm8_run 6 s = SOME s1 /\ s1.REG 19w <> orig``),
   ("forge_refundFficloseBridge", "refund_image_fficlose_code", ``!m. refund_image_mem 0w m ==> fficlose_code_bytes m``),
   ("forge_refundFficloseBridge", "cake_fficlose_stub_exact", ``arm8_user s /\ s.PC = 0x100004080w /\ refund_image_mem 0w s.MEM ==> ^stub_post``),
   ("forge_refundFficloseBridge", "stub_only_ffi_rejected",
      ``~ffi_interfer_ok 0x1000040D0w (refund_mc 0x1000040D0w (^EMC with ffi_interfer := refund_stub_only_ffi))``),
   ("forge_refundFficloseBridge", "altered_stub_byte_rejected", ``!m. m 0x100004080w <> 0x78w ==> ~refund_image_mem 0w m``),
   ("forge_refundFficloseBridge", "altered_stub_word_not_in_file", ``TAKE 4 (DROP 16512 refund_file) <> [0x79w; 0x84w; 0w; 0x14w:word8]``)];
val u393 = ["forge_refundFficloseStep", "forge_refundFficloseBridge"];
val _ = List.app (fn thy => (List.app (fn (n, th) => tags (thy ^ "." ^ n) th) (DB.theorems thy @ DB.definitions thy);
   pr ("STORED_THEOREMS " ^ thy ^ " " ^ Int.toString (length (DB.theorems thy)) ^ " STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions thy)) ^
       " AXIOMS " ^ Int.toString (length (DB.axioms thy))))) u393;
val thms393 = List.concat (map DB.theorems u393);
fun fetch393 n = concl (valOf (Option.map #2 (List.find (fn (m, _) => m = n) thms393)));
val pfx = fetch393 "fficlose_prefix_run"; val sfx = fetch393 "fficlose_suffix_run"; val ext = fetch393 "cake_fficlose_to_import_branch";
fun conjs c = strip_conj (snd (dest_exists (snd (dest_imp c))));
val _ = if List.exists (same ``arm8_run 14 s = SOME (s1:arm8_state)``) (conjs pfx) andalso List.exists (same ``(s1:arm8_state).PC = (g:word64)``) (conjs pfx) andalso
           List.exists (same ``(s1:arm8_state).REG 30w = 0x10002528Cw``) (conjs pfx) andalso
           List.exists (same ``!q. (!i. i < 32 ==> q <> (b:word64) + n2w i) ==> (s1:arm8_state).MEM q = (s:arm8_state).MEM q``) (conjs pfx) andalso
           has_const "fficlose_entry_pre" (fst (dest_imp pfx))
        then pr "IMPORTED forge_refundFficloseStep.fficlose_prefix_run: 14 steps, pc = value of the got slot, link register 0x10002528C, frame of 32 bytes"
        else raise Fail "prefix statement";
val _ = if List.exists (same ``arm8_run 6 s = SOME (s1:arm8_state)``) (conjs sfx) andalso List.exists (same ``(s1:arm8_state).PC = (v30:word64)``) (conjs sfx) andalso
           List.exists (same ``!q. (!i. i < 1 ==> q <> (a:word64) + n2w i) ==> (s1:arm8_state).MEM q = (s:arm8_state).MEM q``) (conjs sfx) andalso
           has_const "fficlose_return_pre" (fst (dest_imp sfx))
        then pr "IMPORTED forge_refundFficloseStep.fficlose_suffix_run: 6 steps from an assumed post-call state, pc = saved link value, one byte written"
        else raise Fail "suffix statement";
val _ = if List.exists (same ``arm8_run 15 s = SOME (s1:arm8_state)``) (conjs ext) andalso List.exists (same ``(s1:arm8_state).PC = (g:word64)``) (conjs ext) andalso
           has_const "refund_image_mem" (fst (dest_imp ext)) andalso
           List.exists (same ``mem_dword (s:arm8_state).MEM 0x100028020w = (g:word64)``) (strip_conj (fst (dest_imp ext)))
        then pr "IMPORTED forge_refundFficloseBridge.cake_fficlose_to_import_branch: 15 steps on the image from 0x100004080; pc = value of the got slot 0x100028020"
        else raise Fail "exit statement";
(* Scope controls for U393. *)
val with_ffi = List.filter (fn (_, th) => has_const "ffi_interfer_ok" (concl th) orelse has_const "refund_ffi_contract" (concl th)) thms393;
val _ = if map fst with_ffi = ["stub_only_ffi_rejected"] andalso is_neg (concl (snd (hd with_ffi))) andalso
           not (List.exists (fn (_, th) => has_const "machine_sem" (concl th) orelse has_const "basis_ffi" (concl th) orelse has_const "refund_installed_no_handler" (concl th)) thms393)
        then pr "CONTROL_OK no U393 theorem states ffi_interfer_ok or the FFI contract for the real stub or C function; the only mention is a refutation; no U393 theorem mentions the oracle or machine_sem"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val joined = List.filter (fn (_, th) => has_const "fficlose_return_pre" (concl th) andalso
                 (has_const "fficlose_entry_pre" (concl th) orelse has_const "refund_image_mem" (concl th) orelse has_const "fficlose_stub_pre" (concl th))) thms393;
val _ = if null joined then pr "CONTROL_OK no U393 theorem joins the steps before the libSystem call to the steps after it; the call is not modelled"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val _ = if List.all (fn (_, th) => not (List.exists (fn v => fst (dest_var v) = "sl") (all_vars (concl th)))) thms393 andalso
           can (find_term (same ``refund_image_mem 0w (s:arm8_state).MEM``)) (fetch393 "cake_fficlose_stub_exact")
        then pr "CONTROL_OK every U393 theorem is at slide 0"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val _ = pr ("NEGATIVE_CONTROL_KEPT " ^ String.concatWith " " ["cake_fficlose_stub_wrong_target_refuted", "cake_fficlose_stub_does_not_return",
            "fficlose_suffix_wrong_return_refuted", "fficlose_corrupted_frame_slot_clobbers_x19", "stub_only_ffi_rejected",
            "altered_stub_byte_rejected", "altered_stub_word_not_in_file"]);

(* U394: the complete cake_fficlose path with an explicit relation for the external call. *)
val regs394 = ``[19w;20w;21w;22w;23w;24w;25w;26w;27w;28w] : word5 list``;
val post394 = ``s3.PC = s.REG 30w /\ s3.SP_EL0 = s.SP_EL0 /\ arm8_user s3 /\ (!r. MEM r ^regs394 ==> s3.REG r = s.REG r) /\
                (!q. q IN dm ==> s3.MEM q = if q = s.REG 2w then close_result_byte (s2.REG 0w) else s.MEM q)``;
val _ = List.app (fn (thy, n, tm) =>
  let val th = DB.fetch thy n in
    if same tm (concl th) then () else (pr ("STORED " ^ n ^ "\n" ^ thm_to_string th); raise Fail ("Exact statement mismatch: " ^ n));
    tags n th; pr ("IMPORTED " ^ thy ^ "." ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end)
  [("forge_refundFficloseCompose", "close_call_rel_def", ``!dm s1 s2. close_call_rel dm s1 s2 <=>
        arm8_user s2 /\ s2.PC = s1.REG 30w /\ s2.SP_EL0 = s1.SP_EL0 /\ (!r. MEM r ^regs394 ==> s2.REG r = s1.REG r) /\
        (!i. i < 32 ==> s2.MEM (s1.SP_EL0 + n2w i) = s1.MEM (s1.SP_EL0 + n2w i)) /\
        (!q. 0x100000000w <=+ q /\ q <+ 0x100030F30w ==> s2.MEM q = s1.MEM q) /\ (!q. q IN dm ==> s2.MEM q = s1.MEM q)``),
   ("forge_refundFficloseCompose", "fficlose_path_def", ``!dm s s3. fficlose_path dm s s3 <=>
        ?s1 s2. arm8_run 15 s = SOME s1 /\ close_call_rel dm s1 s2 /\ arm8_run 6 s2 = SOME s3``),
   ("forge_refundFficloseCompose", "close_result_byte_def", ``!x0. close_result_byte x0 = if (w2w (x0:word64) : word32) = 0w then 0w else 1w : word8``),
   ("forge_refundFficloseCompose", "cake_fficlose_path", ``fficlose_call_pre dm s b c g ==>
        ?s1. arm8_run 15 s = SOME s1 /\ s1.PC = g /\ s1.REG 30w = 0x10002528Cw /\
             !s2. close_call_rel dm s1 s2 ==> ?s3. arm8_run 6 s2 = SOME s3 /\ ^post394``),
   ("forge_refundFficloseCompose", "cake_fficlose_path_contract_instance",
      ``(t1:64 asm_state).mem_domain = dm /\
        read_bytearray (s.REG 2w) (w2n (s.REG 3w)) (\a. if a IN dm then SOME (s.MEM a) else NONE) = SOME bytes2 /\
        target_state_rel arm8_target (t1 with pc := 0x1000040D0w - n2w ((3 + 2) * 16)) s /\ aligned 2 (t1.regs 30) /\
        fficlose_call_pre dm s b c g /\ fficlose_path dm s s3 ==>
        ?v. (v = 0w \/ v = 1w) /\ arm8_ok s3 /\ s3.PC = t1.regs 30 /\
            (!a. a IN dm ==> s3.MEM a = asm_write_bytearray (t1.regs 2) (v :: TL bytes2) t1.mem a) /\
            (!r. MEM r [19;20;21;22;23;24;25;27;28] ==> s3.REG (n2w r) = t1.regs r)``),
   ("forge_refundFficloseCompose", "close_call_rel_inhabited", ``!dm s1. arm8_user s1 ==> close_call_rel dm s1 (s1 with PC := s1.REG 30w)``),
   ("forge_refundFficloseCompose", "fficlose_call_pre_satisfiable", ``?dm s b c g. fficlose_call_pre dm s b c g``),
   ("forge_refundFficloseCompose", "cake_fficlose_path_inhabited", ``?dm s b c g s3. fficlose_call_pre dm s b c g /\ fficlose_path dm s s3``),
   ("forge_refundFficloseCompose", "ffi_close_accepts_only_valid_lengths", ``ffi_close (cfg8:word8 list) (arr:word8 list) fsys = SOME (FFIreturn nb fsys') ==>
        LENGTH cfg8 = 8 /\ 1 <= LENGTH arr /\ ?v. (v = 0w \/ v = 1w) /\ nb = v :: TL arr``),
   ("forge_refundFficloseCompose", "invalid_arguments_not_covered",
      ``(s.REG 1w <> 8w \/ s.REG 3w = 0w \/ word_msb (s.REG 3w)) ==> ~fficlose_call_pre dm s b c g``),
   ("forge_refundFficloseCompose", "corrupted_return_state_not_in_relation",
      ``(s2.PC <> s1.REG 30w \/ s2.SP_EL0 <> s1.SP_EL0 \/ s2.REG 19w <> s1.REG 19w \/
         (?i. i < 32 /\ s2.MEM (s1.SP_EL0 + n2w i) <> s1.MEM (s1.SP_EL0 + n2w i))) ==> ~close_call_rel dm s1 s2``),
   ("forge_refundFficloseCompose", "frame_in_protected_domain_not_covered", ``i < 32 /\ b + n2w i IN dm ==> ~fficlose_call_pre dm s b c g``),
   ("forge_refundFficloseCompose", "prefix_writes_the_frame", ``fficlose_call_pre dm s b c g /\ mem_dword s.MEM b <> s.REG 20w ==>
        ?s1. arm8_run 15 s = SOME s1 /\ mem_dword s1.MEM b <> mem_dword s.MEM b``),
   ("forge_refundFficloseCompose", "overlapping_configuration_is_vacuous_case", ``~fficlose_call_pre dm s b b g``),
   ("forge_refundFficloseAssert", "fficlose_alen_zero_reaches_assert", ``fficlose_alen_zero_pre s b ==>
        ?s1. arm8_run 5 s = SOME s1 /\ s1.PC = 0x1000252A4w /\ s1.REG 30w = s.REG 30w``),
   ("forge_refundFficloseAssert", "fficlose_clen_bad_reaches_assert", ``fficlose_clen_bad_pre s b ==>
        ?s1. arm8_run 7 s = SOME s1 /\ s1.PC = 0x1000252A8w /\ s1.REG 30w = s.REG 30w``)];
val u394 = ["forge_refundFficloseAssert", "forge_refundFficloseCompose"];
val _ = List.app (fn thy => (List.app (fn (n, th) => tags (thy ^ "." ^ n) th) (DB.theorems thy @ DB.definitions thy);
   pr ("STORED_THEOREMS " ^ thy ^ " " ^ Int.toString (length (DB.theorems thy)) ^ " STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions thy)) ^
       " AXIOMS " ^ Int.toString (length (DB.axioms thy))))) u394;
val thms394 = List.concat (map DB.theorems u394);
fun f394 n = concl (valOf (Option.map #2 (List.find (fn (m, _) => m = n) thms394)));
val pred394 = concl (DB.fetch "forge_refundFficloseCompose" "fficlose_call_pre_def");
val _ = if List.all (fn n => has_const n pred394) ["refund_image_mem", "arm8_user"] andalso
           can (find_term (same ``(s:arm8_state).REG 1w = 8w``)) pred394 andalso can (find_term (same ``~word_msb ((s:arm8_state).REG 3w)``)) pred394 andalso
           can (find_term (same ``!i. i < 32 ==> (b:word64) + n2w i NOTIN (dm:word64 set)``)) pred394
        then pr "IMPORTED forge_refundFficloseCompose.fficlose_call_pre_def: image, user state, clen = 8, alen positive, frame outside the protected domain are explicit conjuncts"
        else raise Fail "premise predicate";
val _ = if same (fst (dest_imp (f394 "cake_fficlose_path"))) ``fficlose_call_pre dm s b c g`` andalso
           same (snd (strip_exists (f394 "fficlose_call_pre_satisfiable"))) ``fficlose_call_pre dm s b c g``
        then pr "CONTROL_OK the composed theorem's premise is exactly the predicate that fficlose_call_pre_satisfiable shows inhabited; cake_fficlose_path_inhabited gives a complete instance of the path"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val with_rel = Lib.sort (fn a => fn b => a <= b) (map fst (List.filter (fn (_, th) => has_const "close_call_rel" (concl th)) thms394));
val _ = if with_rel = ["cake_fficlose_path", "close_call_rel_gives_return_state", "close_call_rel_inhabited", "corrupted_return_state_not_in_relation", "fficlose_after_call"]
        then pr "CONTROL_OK close_call_rel occurs only as a premise, in a refutation, and in the constructed-inhabitant lemma; no theorem derives it from an implementation"
        else pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ String.concatWith " " with_rel);
val _ = if not (List.exists (fn (_, th) => has_const "ffi_interfer_ok" (concl th) orelse has_const "refund_ffi_contract" (concl th) orelse
                                           has_const "machine_sem" (concl th) orelse has_const "basis_ffi" (concl th)) thms394) andalso
           not (List.exists (fn (_, th) => has_const "ffi_close" (concl th) andalso has_const "arm8_run" (concl th)) thms394)
        then pr "CONTROL_OK no U394 theorem states ffi_interfer_ok or refund_ffi_contract; none relates the oracle function ffi_close to machine steps (conformance is not claimed)"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val _ = if List.all (fn (_, th) => not (List.exists (fn v => fst (dest_var v) = "sl") (all_vars (concl th)))) thms394
        then pr "CONTROL_OK every U394 theorem is at slide 0" else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val _ = pr ("NEGATIVE_CONTROL_KEPT " ^ String.concatWith " " ["invalid_arguments_not_covered", "invalid_clen_reaches_assert_block", "zero_alen_reaches_assert_block",
            "corrupted_return_state_not_in_relation", "frame_in_protected_domain_not_covered", "prefix_writes_the_frame", "overlapping_configuration_is_vacuous_case"]);

(* U395: argument validity at reachable close call states of the model machine. *)
val bty395 = type_of ``basis_ffi ext cl fs``;
val MCv = mk_var ("mc", mcty); val MC1v = mk_var ("mc1", mcty);
val _ = List.app (fn (thy, n, tm) =>
  let val th = DB.fetch thy n in
    if same tm (concl th) then () else (pr ("STORED " ^ n ^ "\n" ^ thm_to_string th); raise Fail ("Exact statement mismatch: " ^ n));
    tags n th; pr ("IMPORTED " ^ thy ^ "." ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end)
  [("forge_refundCallSite", "machine_step_def", ``!(mc:^(ty_antiq mcty)) (ffi:'ffi ffi_state) ms mc' ffi' ms'. machine_step mc ffi ms mc' ffi' ms' <=>
        (!k. targetSem$evaluate mc ffi (k + 1) ms = targetSem$evaluate mc' ffi' k ms') /\ ffi'.oracle = ffi.oracle /\ mc_static_eq mc mc'``),
   ("forge_refundCallSite", "machine_reach_def", ``!(mc:^(ty_antiq mcty)) (ffi:'ffi ffi_state) ms mc1 ffi1 ms1.
        machine_reach mc ffi ms mc1 ffi1 ms1 <=> ?n. machine_reach_n n mc ffi ms mc1 ffi1 ms1``),
   ("forge_refundCallSite", "close_call_site_arguments",
      ``machine_reach ^MCv (ffi:^(ty_antiq bty395)) ms ^MC1v ffi1 ms1 /\ refund_static mc dm /\ ffi.oracle = basis_ffi_oracle ext /\
        machine_sem mc ffi ms SUBSET extend_with_resource_limit {Terminate Success io} /\ ms1.PC = 0x100004080w ==>
        ms1.REG 1w = 8w /\ ms1.REG 3w <> 0w /\
        ?cbytes abytes. read_ffi_bytearrays mc1 ms1 = (SOME cbytes, SOME abytes) /\ LENGTH cbytes = 8 /\ 1 <= LENGTH abytes``),
   ("forge_refundCallSite", "close_call_site_arguments_model", mk_imp (list_mk_conj (pre391 @ strip_conj inpS),
      ``?ms. arm8_run 27 s = SOME ms /\ ms.PC = 0x1000040D0w /\
           !mc1 ffi1 ms1. machine_reach (^AMC) ^bffi ms mc1 ffi1 ms1 /\ ms1.PC = 0x100004080w ==> ms1.REG 1w = 8w /\ ms1.REG 3w <> 0w``)),
   ("forge_refundCallSite", "machine_reach_refl", ``machine_reach ^MCv (ffi:'ffi ffi_state) ms mc ffi ms``),
   ("forge_refundCallSite", "fail_not_in_success_limit", ``Fail NOTIN extend_with_resource_limit {Terminate Success io}``),
   ("forge_refundCallSite", "ffi_outcome_not_in_success_limit", ``Terminate (FFI_outcome fo) l NOTIN extend_with_resource_limit {Terminate Success io}``),
   ("forge_refundCallSite", "resource_limit_is_in_success_limit", ``Terminate Resource_limit_hit [] IN extend_with_resource_limit {Terminate Success io}``),
   ("forge_refundCallSite", "ffi_close_rejects_invalid_lengths",
      ``(LENGTH (cfg8:word8 list) <> 8 \/ (arr:word8 list) = []) ==> ffi_close cfg8 arr fsys = NONE``),
   ("forge_refundCallSite", "invalid_clen_call_halts_in_model",
      ``refund_static ^MC1v dm /\ ms1.PC = 0x100004080w /\ (ffi1:^(ty_antiq bty395)).oracle = basis_ffi_oracle ext /\
        read_ffi_bytearrays mc1 ms1 = (SOME cbytes, SOME abytes) /\ LENGTH cbytes <> 8 ==>
        ?fo. targetSem$evaluate mc1 ffi1 1 ms1 = (Halt (FFI_outcome fo), ms1, ffi1)``),
   ("forge_refundCallSite", "fficlose_call_pre_no_len_weaker", ``fficlose_call_pre dm s b c g ==> fficlose_call_pre_no_len dm s b c g``)];
val u395 = ["forge_refundCallSite"];
val _ = List.app (fn thy => (List.app (fn (n, th) => tags (thy ^ "." ^ n) th) (DB.theorems thy @ DB.definitions thy);
   pr ("STORED_THEOREMS " ^ thy ^ " " ^ Int.toString (length (DB.theorems thy)) ^ " STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions thy)) ^
       " AXIOMS " ^ Int.toString (length (DB.axioms thy))))) u395;
val thms395 = List.concat (map DB.theorems u395);
fun f395 n = concl (valOf (Option.map #2 (List.find (fn (m, _) => m = n) thms395)));
val weakd = concl (DB.fetch "forge_refundCallSite" "fficlose_call_pre_no_len_def");
val _ = if not (can (find_term (same ``(s:arm8_state).REG 1w = 8w``)) weakd) andalso not (can (find_term (same ``(s:arm8_state).REG 3w <> 0w``)) weakd) andalso
           can (find_term (same ``~word_msb ((s:arm8_state).REG 3w)``)) weakd andalso has_const "refund_image_mem" weakd andalso
           length (strip_conj (rhs (snd (strip_forall weakd)))) = 14
        then pr "IMPORTED forge_refundCallSite.fficlose_call_pre_no_len_def: 14 conjuncts; clen = 8 and alen <> 0 removed; the sign condition, image, user state and separations kept"
        else raise Fail "weak premise";
val G395 = f395 "cake_fficlose_path_at_reachable_call";
val _ = if has_const "close_call_rel" G395 andalso has_const "machine_reach" G395 andalso has_const "fficlose_call_pre_no_len" G395 andalso
           not (has_const "fficlose_call_pre" G395) andalso has_const "refund_abs_env" G395 andalso has_const "refund_entry_pre" (fst (dest_imp G395))
        then pr "IMPORTED forge_refundCallSite.cake_fficlose_path_at_reachable_call: model record, reachable call state, reduced premise, close_call_rel still an explicit premise"
        else raise Fail "composed statement";
val dthm = f395 "close_call_site_arguments";
val _ = if has_const "machine_sem" (fst (dest_imp dthm)) andalso has_const "machine_reach" (fst (dest_imp dthm)) andalso
           not (has_const "call_FFI" (fst (dest_imp dthm))) andalso not (has_const "ffi_close" (fst (dest_imp dthm)))
        then pr "CONTROL_OK the call-site theorem assumes reachability and the behaviour inclusion; it does not assume a successful oracle call"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val args_thms = List.filter (fn (_, th) => can (find_term (same ``(ms1:arm8_state).REG 1w = 8w``)) (concl th)) thms395;
val _ = if List.all (fn (_, th) => has_const "machine_reach" (concl th) orelse has_const "machine_reach_n" (concl th)) args_thms andalso length args_thms = 2
        then pr "CONTROL_OK the two theorems that conclude x1 = 8 are stated for reachable states only; none states it for an arbitrary state"
        else pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ String.concatWith " " (map fst args_thms));
val _ = if not (List.exists (fn (_, th) => has_const "ffi_interfer_ok" (concl th) orelse has_const "refund_ffi_contract" (concl th)) thms395) andalso
           List.all (fn (_, th) => not (List.exists (fn v => fst (dest_var v) = "sl") (all_vars (concl th)))) thms395
        then pr "CONTROL_OK no U395 theorem states ffi_interfer_ok or refund_ffi_contract; every U395 theorem is at slide 0"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val _ = pr ("NEGATIVE_CONTROL_KEPT " ^ String.concatWith " " ["ffi_close_rejects_invalid_lengths", "invalid_clen_call_halts_in_model",
            "fail_not_in_success_limit", "ffi_outcome_not_in_success_limit", "resource_limit_is_in_success_limit"]);

(* U396: signed alen under an explicit low-half premise; reachability of a close call is not established. *)
val HALF396 = ``0x8000000000000000w:word64``;
val sgn_post = ``ms1.REG 1w = 8w /\ ms1.REG 3w <> 0w /\ ~word_msb (ms1.REG 3w) /\ 0w < ms1.REG 3w``;
val _ = List.app (fn (thy, n, tm) =>
  let val th = DB.fetch thy n in
    if same tm (concl th) then () else (pr ("STORED " ^ n ^ "\n" ^ thm_to_string th); raise Fail ("Exact statement mismatch: " ^ n));
    tags n th; pr ("IMPORTED " ^ thy ^ "." ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end)
  [("forge_refundSignedLen", "addresses_below_half_def", ``!dm. addresses_below_half dm <=> !a. a IN dm ==> a <+ ^HALF396``),
   ("forge_refundSignedLen", "heap_premises_admit_huge_heap",
      ``?h e:word64. aligned 3 h /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h /\ refund_heap_clear h e /\ ^HALF396 <=+ e - h``),
   ("forge_refundSignedLen", "read_bytearray_below_half_bound",
      ``!x n (m:word64 -> word8) dm bs q. read_bytearray x n (\a. if a IN dm then SOME (m a) else NONE) = SOME bs /\
          addresses_below_half dm /\ q NOTIN dm /\ q <+ ^HALF396 ==> n < 2 ** 63``),
   ("forge_refundSignedLen", "close_call_site_signed_alen",
      ``machine_reach ^MCv (ffi:^(ty_antiq bty395)) ms ^MC1v ffi1 ms1 /\ refund_static mc dm /\ ffi.oracle = basis_ffi_oracle ext /\
        machine_sem mc ffi ms SUBSET extend_with_resource_limit {Terminate Success io} /\ ms1.PC = 0x100004080w /\
        addresses_below_half dm ==> ^sgn_post``),
   ("forge_refundSignedLen", "refund_mem_dm_below_half", ``!h e. e <=+ ^HALF396 ==> addresses_below_half (refund_mem_dm h e)``),
   ("forge_refundSignedLen", "close_call_site_signed_alen_model",
      mk_imp (list_mk_conj (pre391 @ strip_conj inpS @ [``(e:word64) <=+ ^HALF396``]),
      ``?ms. arm8_run 27 s = SOME ms /\ ms.PC = 0x1000040D0w /\
           !mc1 ffi1 ms1. machine_reach (^AMC) ^bffi ms mc1 ffi1 ms1 /\ ms1.PC = 0x100004080w ==> ^sgn_post``)),
   ("forge_refundSignedLen", "negative_alen_not_covered", ``word_msb (s.REG 3w) ==> ~fficlose_call_pre_no_len dm s b c g``),
   ("forge_refundSignedLen", "arbitrary_state_can_violate_arguments",
      ``?ms1:arm8_state. ms1.PC = 0x100004080w /\ ms1.REG 1w <> 8w /\ word_msb (ms1.REG 3w)``),
   ("forge_refundSignedLen", "universe_not_below_half", ``~addresses_below_half (UNIV:word64 set)``),
   ("forge_refundSignedLen", "high_heap_end_not_below_half", ``!h e. h <=+ ^HALF396 /\ ^HALF396 <+ e ==> ~addresses_below_half (refund_mem_dm h e)``)];
val u396 = ["forge_refundSignedLen"];
val _ = List.app (fn thy => (List.app (fn (n, th) => tags (thy ^ "." ^ n) th) (DB.theorems thy @ DB.definitions thy);
   pr ("STORED_THEOREMS " ^ thy ^ " " ^ Int.toString (length (DB.theorems thy)) ^ " STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions thy)) ^
       " AXIOMS " ^ Int.toString (length (DB.axioms thy))))) u396;
val thms396 = List.concat (map DB.theorems u396);
fun f396 n = concl (valOf (Option.map #2 (List.find (fn (m, _) => m = n) thms396)));
val w13d = concl (DB.fetch "forge_refundSignedLen" "fficlose_call_pre_no_len_sign_def");
val _ = if length (strip_conj (rhs (snd (strip_forall w13d)))) = 13 andalso not (has_const "word_msb" w13d) andalso has_const "refund_image_mem" w13d
        then pr "IMPORTED forge_refundSignedLen.fficlose_call_pre_no_len_sign_def: 13 conjuncts; the sign condition removed; image, user state, stack and separations kept"
        else raise Fail "premise definition";
val G396 = f396 "cake_fficlose_path_at_reachable_call_signed";
val _ = if has_const "close_call_rel" G396 andalso has_const "machine_reach" G396 andalso has_const "fficlose_call_pre_no_len_sign" G396 andalso
           List.exists (same ``(e:word64) <=+ ^HALF396``) (strip_conj (fst (dest_imp G396)))
        then pr "IMPORTED forge_refundSignedLen.cake_fficlose_path_at_reachable_call_signed: reduced premise (13), explicit premise e <=+ 2^63, close_call_rel still a premise"
        else raise Fail "composed statement";
val signed_thms = List.filter (fn (_, th) => can (find_term (same ``0w < (ms1:arm8_state).REG 3w``)) (concl th)) thms396;
val _ = if length signed_thms = 2 andalso List.all (fn (_, th) => let val a = fst (dest_imp (concl th)) in
              has_const "addresses_below_half" a orelse List.exists (same ``(e:word64) <=+ ^HALF396``) (strip_conj a) end) signed_thms
        then pr "CONTROL_OK both theorems that conclude the signed bound have the low-half premise; the bound is not stated without it"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val all_site = thms396 @ thms395;
val reach_pos = List.filter (fn (n, th) => has_const "machine_reach" (concl th) andalso
                   not (is_imp (snd (strip_forall (concl th)))) andalso n <> "machine_reach_refl") all_site;
val _ = if null reach_pos
        then pr "CONTROL_OK no stored theorem asserts that a close call state is reachable; machine_reach occurs only as a premise and in the reflexivity lemma"
        else pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ String.concatWith " " (map fst reach_pos));
val wit394 = concl (DB.fetch "forge_refundFficloseCompose" "fficlose_call_pre_witness");
val _ = if not (has_const "machine_reach" wit394) andalso has_const "sat_mem" wit394
        then pr "CONTROL_OK the U394 witness is a constructed state (sat_mem); no theorem relates it to machine_reach"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val _ = if not (List.exists (fn (_, th) => has_const "ffi_interfer_ok" (concl th) orelse has_const "refund_ffi_contract" (concl th)) thms396) andalso
           List.all (fn (_, th) => not (List.exists (fn v => fst (dest_var v) = "sl") (all_vars (concl th)))) thms396
        then pr "CONTROL_OK no U396 theorem states ffi_interfer_ok or refund_ffi_contract; every U396 theorem is at slide 0"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val _ = pr ("NEGATIVE_CONTROL_KEPT " ^ String.concatWith " " ["negative_alen_not_covered", "arbitrary_state_can_violate_arguments",
            "universe_not_below_half", "high_heap_end_not_below_half", "heap_premises_admit_huge_heap"]);
val _ = pr "AFTER_POSITIVE_AUDIT";
(* 4. Controls. The guard is not vacuous: when the lab facts fail, the guarded set contains Fail. *)
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_importScratch";
val guard_ctl = prove (``~Q ==> Fail IN lab_guard x Q``, simp [lab_guard_def]);
val _ = pr ("CONTROL_OK guard not vacuous " ^ thm_to_string guard_ctl);
val stored = concl (DB.fetch "forge_refundExclusionSource" "refund_install_exclusion_source");
val no_installed = ``is_arm8_machine_config (^MC) /\ ^nofail ==> ^excl``;
val no_source = ``is_arm8_machine_config (^MC) /\ ^inst ==> ^excl``;
val no_premise = excl;
val stored_real = concl (DB.fetch "forge_refundExclusionReal" "refund_u298_exclusion_real");
val real_no_source = ``is_arm8_machine_config (^MC0) /\ refund_installed_no_handler (^MC0) ms cbspace data_sp ==> ^u298r``;
val real_no_inst = ``is_arm8_machine_config (^MC0) /\ ^nofail ==> ^u298r``;
val _ = if List.exists (fn t => same t stored_real) [real_no_source, real_no_inst, u298r] then pr "UNEXPECTED_CONTROL_ACCEPTANCE"
        else pr "CONTROL_OK real-record statements without source non-Fail, without the installed-state predicate, or without premises are not the stored one";
val _ = if List.exists (fn t => same t stored) [no_installed, no_source, no_premise] then pr "UNEXPECTED_CONTROL_ACCEPTANCE"
        else pr "CONTROL_OK statements without installed, without source non-Fail, or without premises are not the stored one";
val _ = pr ("CONTROL_OK empty behaviour set does not satisfy " ^ thm_to_string (prove (``~sem_satisfies {} P``, simp [sem_satisfies_def])));
val closure = Lib.mk_set (List.concat (map (fn t => t :: Theory.ancestry t) ["forge_refundSourceNonFail", "forge_refundStartupClause", "forge_refundRejectNonFail", "forge_refundCmlMainSat", "forge_refundStartupBridge", "forge_refundLoaderMemory", "forge_refundEntrySat", "forge_refundInstalledAssembly", "forge_refundResidual", "forge_refundEnvModel", "forge_refundFficloseBridge", "forge_refundFficloseCompose", "forge_refundCallSite", "forge_refundSignedLen"]));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = pr ("CLOSURE_FORGE " ^ String.concatWith " " (List.filter (String.isPrefix "forge_") closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "P3_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

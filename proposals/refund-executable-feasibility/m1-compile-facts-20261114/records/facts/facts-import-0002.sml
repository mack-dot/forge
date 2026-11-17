(* Fresh import of the exact compiler facts and the ARMv8 composition: exact statements, tags, closure, controls. *)
open preamble backendTheory labSemTheory labLangTheory labPropsTheory lab_filterTheory targetSemTheory targetPropsTheory
     lab_to_targetTheory lab_to_targetProofTheory arm8_configProofTheory
     forge_targetInstallPrefixTheory forge_simZeroCaseTheory forge_simRootTheory forge_refundExactExclusionTheory
     forge_refundLabFilteredTheory forge_installHandlerIrrelevantTheory forge_refundCompileFactsTheory forge_refundExclusionArm8Theory;
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
val T3 = ``backend$to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog``;
val L = ``SND (SND ^T3)``;
val labc = ``(FST (SND ^T3)).lab_conf``;
val CODE = ``forge_refundArm8Compile$code``;
val MC = mk_var ("mc_conf", fst (dom_rng (type_of ``is_arm8_machine_config``)));
val sem = ``labSem$semantics (make_init (^MC) (ffi:'ffi ffi_state) t m dm sdm ms ^L (lab_to_target$compile arm8_config)
     ((^MC).target.get_pc ms + n2w (LENGTH ^CODE)) cbspace coracle) <> Fail``;
val orac = ``compiler_oracle_ok coracle refund_lab_conf2.labels (LENGTH ^CODE) arm8_config (^MC).ffi_names``;
val inst_expected = ``is_arm8_machine_config (^MC) /\
  installed ^CODE cbspace bitmaps data_sp refund_lab_conf2.ffi_names (r1,r2) (^MC) refund_lab_conf2.shmem_extra ms /\
  (!t m dm sdm. good_init_state (^MC) ms ^CODE cbspace t m dm sdm ==> ^orac /\ ^sem) ==>
  !n. no_install_prefix (^MC) (ffi:'ffi ffi_state) n ms``;
val any_expected = ``same_but_install mc0 (^MC) /\ is_arm8_machine_config (^MC) /\
  installed ^CODE cbspace bitmaps data_sp refund_lab_conf2.ffi_names (r1,r2) (^MC) refund_lab_conf2.shmem_extra ms /\
  (!t m dm sdm. good_init_state (^MC) ms ^CODE cbspace t m dm sdm ==> ^orac /\ ^sem) ==>
  (!j ms' ffi'. targetSem$evaluate mc0 (ffi:'ffi ffi_state) j ms = (TimeOut,ms',ffi') ==> mc0.target.get_pc ms' <> mc0.install_pc) /\
  (!k. targetSem$evaluate mc0 ffi k ms = targetSem$evaluate (^MC) ffi k ms)``;
val expected = [
 ("forge_refundCompileFacts", "refund_lab_good_code", ``lab_to_targetProof$good_code arm8_config LN ^L``),
 ("forge_refundCompileFacts", "refund_lab_conf_facts", ``(^labc).labels = LN /\ (^labc).pos = 0 /\ (^labc).ffi_names = NONE``),
 ("forge_refundCompileFacts", "refund_lab_compile", ``lab_to_target$compile arm8_config ^labc ^L = SOME (^CODE, refund_lab_conf2)``),
 ("forge_refundCompileFacts", "refund_lab_bitmaps", ``FST ^T3 = forge_refundArm8Compile$data``),
 ("forge_refundCompileFacts", "refund_lab_ffi_names",
    ``?ffi_names. refund_lab_conf2.ffi_names = SOME ffi_names /\ mmio_pcs_min_index ffi_names = SOME (LENGTH ffi_names)``),
 ("forge_refundCompileFacts", "gc_check_good_code", ``!secs. gc_check secs ==> lab_to_targetProof$good_code arm8_config LN secs``),
 ("forge_refundCompileFacts", "asm_ok_arm8_link", ``!a. asm_ok_arm8 a <=> asm_ok a arm8_config``),
 ("forge_refundExclusionArm8", "refund_install_exclusion_installed", inst_expected),
 ("forge_refundExclusionArm8", "refund_u298_exclusion_any_handler", any_expected)];
val _ = List.app (fn (thy, n, tm) =>
  let val th = DB.fetch thy n in
    if same tm (concl th) then () else (pr ("STORED " ^ n ^ "\n" ^ thm_to_string th); raise Fail ("Exact statement mismatch: " ^ n));
    tags n th; pr ("IMPORTED " ^ thy ^ "." ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end) expected;
val thys = ["forge_refundCompileFacts", "forge_refundExclusionArm8"];
val _ = List.app (fn thy => (List.app (fn (n, th) => tags (thy ^ "." ^ n) th) (DB.theorems thy @ DB.definitions thy);
   pr ("STORED_THEOREMS " ^ thy ^ " " ^ Int.toString (length (DB.theorems thy)) ^ " STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions thy))))) thys;
val arm8 = DB.fetch "forge_refundExclusionArm8" "refund_install_exclusion_arm8";
val _ = (tags "refund_install_exclusion_arm8" arm8; pr ("ARM8_PREMISES " ^ Int.toString (length (strip_conj (fst (dest_imp (concl arm8)))))));
val _ = pr ("DEFINITION " ^ thm_to_string (DB.fetch "forge_refundCompileFacts" "refund_lab_conf2_def"));
val _ = pr ("NEGATIVE_CONTROL_KEPT wraparound " ^ thm_to_string (DB.fetch "forge_simZeroCase" "install_entry_wrap_example"));
val _ = pr ("NEGATIVE_CONTROL_KEPT interior " ^ thm_to_string (DB.fetch "forge_simRoot" "endpoint_correspondence_insufficient"));
val _ = pr ("NEGATIVE_CONTROL_KEPT invariant " ^ thm_to_string (DB.fetch "forge_refundExactExclusion" "trivial_invariant_not_closed"));
val _ = pr ("NEGATIVE_CONTROL_KEPT sharemem " ^ thm_to_string (DB.fetch "forge_refundExactExclusion" "sharemem_line_detected"));
val _ = pr ("NEGATIVE_CONTROL_KEPT region29 " ^ thm_to_string (DB.fetch "forge_refundLabFiltered" "filt_walk_single_eval"));
val _ = pr ("NEGATIVE_CONTROL_KEPT handler " ^ thm_to_string (DB.fetch "forge_installHandlerIrrelevant" "handler_matters_when_installer_reached"));
val _ = pr ("NEGATIVE_CONTROL_KEPT good_code " ^ thm_to_string (DB.fetch "forge_refundCompileFacts" "gc_check_rejects_undefined_label"));
val _ = pr "AFTER_POSITIVE_AUDIT";
(* Statement controls: without the installed premise, or without the semantic premise, the terms are not the stored theorem. *)
val no_installed = ``is_arm8_machine_config (^MC) /\
  (!t m dm sdm. good_init_state (^MC) ms ^CODE cbspace t m dm sdm ==> ^orac /\ ^sem) ==>
  !n. no_install_prefix (^MC) (ffi:'ffi ffi_state) n ms``;
val no_sem = ``is_arm8_machine_config (^MC) /\
  installed ^CODE cbspace bitmaps data_sp refund_lab_conf2.ffi_names (r1,r2) (^MC) refund_lab_conf2.shmem_extra ms ==>
  !n. no_install_prefix (^MC) (ffi:'ffi ffi_state) n ms``;
val stored = concl (DB.fetch "forge_refundExclusionArm8" "refund_install_exclusion_installed");
val _ = if same no_installed stored orelse same no_sem stored then pr "UNEXPECTED_CONTROL_ACCEPTANCE"
        else pr "CONTROL_OK statements without the installed premise or without the semantic premise are not the stored one";
val closure = "forge_refundExclusionArm8" :: Theory.ancestry "forge_refundExclusionArm8";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "P3_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

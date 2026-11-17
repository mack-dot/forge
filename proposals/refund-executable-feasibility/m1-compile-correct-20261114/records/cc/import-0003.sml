(* Fresh import: control replay, lab facts, exact source-level exclusion. Exact statements, tags, closure, controls. *)
open preamble backendTheory semanticsPropsTheory labSemTheory targetSemTheory targetPropsTheory
     lab_to_targetTheory lab_to_targetProofTheory backendProofTheory arm8_configProofTheory
     forge_targetInstallPrefixTheory forge_simZeroCaseTheory forge_simRootTheory forge_refundExactExclusionTheory
     forge_refundLabFilteredTheory forge_installHandlerIrrelevantTheory forge_refundCompileFactsTheory
     forge_refundExclusionArm8Theory forge_compileCorrectLabFactsTheory forge_refundExclusionSourceTheory;
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
val thys = ["forge_compileCorrectControl", "forge_compileCorrectLabFacts", "forge_refundExclusionSource"];
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
val _ = if List.exists (fn t => same t stored) [no_installed, no_source, no_premise] then pr "UNEXPECTED_CONTROL_ACCEPTANCE"
        else pr "CONTROL_OK statements without installed, without source non-Fail, or without premises are not the stored one";
val closure = "forge_refundExclusionSource" :: Theory.ancestry "forge_refundExclusionSource";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = pr ("CLOSURE_PARENTS " ^ String.concatWith " " (Theory.parents "forge_refundExclusionSource"));
val _ = pr ("CLOSURE_FORGE " ^ String.concatWith " " (List.filter (String.isPrefix "forge_") closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "P3_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

(* Exact refund program: the two semantic premises of the exclusion are discharged through the replayed compile_correct'. *)
open preamble backendTheory semanticsPropsTheory labSemTheory targetSemTheory targetPropsTheory
     lab_to_targetTheory lab_to_targetProofTheory backendProofTheory arm8_configProofTheory
     forge_targetInstallPrefixTheory forge_installHandlerIrrelevantTheory forge_refundLabClosureTheory
     forge_refundCompileFactsTheory forge_refundExclusionArm8Theory forge_compileCorrectLabFactsTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (500, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2500, size (term_to_string w)))); ALL_TAC g);
val _ = List.app (fn c => (let val {Name,Thy,...} = dest_thy_const c in Parse.temp_remove_ovl_mapping Name {Name=Name,Thy=Thy} end handle _ => ()))
          (Theory.constants "backend_asm");
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundExclusionSource";
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val mc = mk_var ("mc_conf", mcty);
val cfg = ``set_oracle arm8_backend_config refund_alloc_oracle``;
val CODE = ``forge_refundArm8Compile$code``; val DATA = ``forge_refundArm8Compile$data``;
val arm8_thm = DB.fetch "forge_refundExclusionArm8" "refund_install_exclusion_arm8";
val facts0 = DB.fetch "forge_compileCorrectLabFacts" "compile_correct_lab_facts";
fun fv tm n = valOf (List.find (fn v => fst (dest_var v) = n) (free_vars tm));
val ffi = fv (snd (dest_imp (concl arm8_thm))) "ffi";
val facts1a = INST_TYPE (match_type (type_of (fv (concl facts0) "mc")) mcty) facts0;
val facts1 = INST_TYPE (match_type (type_of (fv (concl facts1a) "ffi")) (type_of ffi)) facts1a;
val _ = if type_of (fv (concl facts1) "mc") = mcty then () else raise Fail "machine type instance";
val b1 = concl facts1;
val c1v = mk_var ("c1", type_of (fv b1 "c'"));
val facts = INST [fv b1 "mc" |-> mc, fv b1 "asm_conf" |-> ``arm8_config``, fv b1 "c" |-> cfg, fv b1 "prog" |-> ``refund_prog``,
                  fv b1 "bytes" |-> CODE, fv b1 "bitmaps" |-> DATA, fv b1 "c'" |-> c1v,
                  fv b1 "ev" |-> mk_const ("NONE", type_of (fv b1 "ev"))] facts1;
val _ = pr ("INSTANCE compile_correct_lab_facts\n" ^ thm_to_string facts);

(* Definitional link: the lab-level compile equation and the bitmaps follow from the backend compile equation. *)
val link = store_thm ("compile_lab_conf",
  ``backend$compile asm_conf c prog = SOME (bytes,bitmaps,c') ==>
    lab_to_target$compile asm_conf (FST (SND (backend$to_lab asm_conf c prog))).lab_conf
       (SND (SND (backend$to_lab asm_conf c prog))) = SOME (bytes, c'.lab_conf) /\
    FST (backend$to_lab asm_conf c prog) = bitmaps``,
  rw [compile_eq_to_target, to_target_def] >> pairarg_tac >> fs [] >>
  Cases_on `lab_to_target$compile asm_conf c''.lab_conf p` >> fs [attach_bitmaps_def] >>
  PairCases_on `x` >> fs [attach_bitmaps_def] >> rveq >> fs []);
val _ = (tags "compile_lab_conf" link; pr ("CHECKED compile_lab_conf\n" ^ thm_to_string link));

val nofail = ``~semantics_prog (FST (THE (prim_sem_env ^ffi))) (SND (THE (prim_sem_env ^ffi))) refund_prog Fail``;
val conc = snd (dest_imp (concl arm8_thm));
val ms = fv conc "ms";
val goalA = ``is_arm8_machine_config ^mc /\
  backend$compile arm8_config ^cfg refund_prog = SOME (^CODE, ^DATA, ^c1v) /\
  ^nofail /\
  installed ^CODE cbspace ^DATA data_sp (^c1v).lab_conf.ffi_names (heap_regs (^cfg).stack_conf.reg_names) ^mc
     (^c1v).lab_conf.shmem_extra ^ms ==> ^conc``;
val thmA = store_thm ("refund_install_exclusion_compiled", goalA,
  strip_tac >>
  `lab_to_targetProof$mc_conf_ok ^mc` by (irule arm8_machine_config_ok >> first_assum ACCEPT_TAC) >>
  `mc_init_ok arm8_config ^cfg ^mc` by (imp_res_tac arm8_init_ok >> fs [set_oracle_def]) >>
  `backend_config_ok arm8_config ^cfg` by (assume_tac arm8_backend_config_ok >> fs [set_oracle_def]) >>
  `lab_facts arm8_config ^cfg refund_prog ^CODE ^c1v ^mc ^ffi ^ms cbspace` by
     (mp_tac facts >> Cases_on `THE (prim_sem_env ^ffi)` >> fs [add_eval_state_def, opt_eval_config_wf_def] >>
      show_tac "FACTS" >> NO_TAC) >>
  qpat_x_assum `installed _ _ _ _ _ _ _ _ _` mp_tac >> rewrite_tac [heap_regs_def, installed_def, LET_THM] >> BETA_TAC >> strip_tac >>
  qpat_x_assum `good_init_state _ _ _ _ _ _ _ _` kall_tac >>
  fs [LET_THM, lab_facts_def] >>
  `(^c1v).lab_conf = refund_lab_conf2` by (assume_tac refund_lab_compile >> gvs []) >>
  `mmio_pcs_min_index (^mc).ffi_names = SOME (LENGTH (^mc).ffi_names)` by (strip_assume_tac refund_lab_ffi_names >> gvs []) >>
  qpat_x_assum `!i. mmio_pcs_min_index _ = SOME i ==> _` drule >> strip_tac >>
  irule (GEN_ALL arm8_thm) >> rpt (first_assum (irule_at Any)) >> gvs [] >> qexists_tac `coracle` >> asm_simp_tac (srw_ss()) []);
val _ = (tags "refund_install_exclusion_compiled" thmA; pr ("CHECKED refund_install_exclusion_compiled\n" ^ thm_to_string thmA));

(* The configuration c1 exists and its lab configuration is the stored one. *)
val goalB = ``is_arm8_machine_config ^mc /\ ^nofail /\
  installed ^CODE cbspace ^DATA data_sp refund_lab_conf2.ffi_names (heap_regs (^cfg).stack_conf.reg_names) ^mc
     refund_lab_conf2.shmem_extra ^ms ==> ^conc``;
val thmB = store_thm ("refund_install_exclusion_source", goalB,
  strip_tac >> strip_assume_tac refund_alloc_compiled >>
  drule link >> strip_tac >>
  `c1.lab_conf = refund_lab_conf2` by (assume_tac refund_lab_compile >> gvs []) >>
  match_mp_tac (GEN_ALL thmA) >> qexistsl_tac [`data_sp`, `cbspace`, `c1`] >>
  asm_simp_tac (srw_ss()) [] >> fs []);
val _ = (tags "refund_install_exclusion_source" thmB; pr ("CHECKED refund_install_exclusion_source\n" ^ thm_to_string thmB));

(* Any installer handler: the U298 form for a machine that differs only in install_interfer. *)
val mc0 = mk_var ("mc0", mcty);
val (anteB, _) = dest_imp (concl thmB);
val u298 = ``!j ms' ffi'. targetSem$evaluate ^mc0 ^ffi j ^ms = (TimeOut,ms',ffi') ==> (^mc0).target.get_pc ms' <> (^mc0).install_pc``;
val goalC = mk_imp (mk_conj (``same_but_install ^mc0 ^mc``, anteB),
                    mk_conj (u298, ``!k. targetSem$evaluate ^mc0 ^ffi k ^ms = targetSem$evaluate ^mc ^ffi k ^ms``));
val thmC = store_thm ("refund_u298_exclusion_source_any_handler", goalC,
  strip_tac >>
  `^conc` by (match_mp_tac thmB >> rpt conj_tac >> first_assum ACCEPT_TAC) >>
  drule_all no_install_prefix_same_but_install >> strip_tac >>
  conj_tac >- (first_x_assum (fn th => ACCEPT_TAC (REWRITE_RULE [no_install_prefix_all] th))) >> first_assum ACCEPT_TAC);
val _ = (tags "refund_u298_exclusion_source_any_handler" thmC; pr ("CHECKED refund_u298_exclusion_source_any_handler\n" ^ thm_to_string thmC));
val hr = (SIMP_CONV (srw_ss()) [set_oracle_def, heap_regs_def] THENC EVAL) ``heap_regs (^cfg).stack_conf.reg_names``
         handle _ => TRUTH;
val _ = pr ("HEAP_REGS " ^ thm_to_string hr);
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

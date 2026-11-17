(* Exact refund program on the real machine record: no installer-handler clause. Applies U360 to the source-level exclusion. *)
open preamble backendTheory semanticsPropsTheory labSemTheory targetSemTheory targetPropsTheory
     lab_to_targetTheory lab_to_targetProofTheory backendProofTheory arm8_configProofTheory
     forge_targetInstallPrefixTheory forge_installHandlerIrrelevantTheory forge_refundInstallHandlerTheory
     forge_refundCompileFactsTheory forge_refundExclusionSourceTheory forge_refundLabClosureTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (400, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = List.app (fn c => (let val {Name,Thy,...} = dest_thy_const c in Parse.temp_remove_ovl_mapping Name {Name=Name,Thy=Thy} end handle _ => ()))
          (Theory.constants "backend_asm");
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundExclusionReal";
fun fv tm n = valOf (List.find (fn v => fst (dest_var v) = n) (free_vars tm));
val cfg = ``set_oracle arm8_backend_config refund_alloc_oracle``;
val hr = (SIMP_CONV (srw_ss()) [set_oracle_def, heap_regs_def] THENC EVAL) ``heap_regs (^cfg).stack_conf.reg_names``;
val _ = pr ("HEAP_REGS " ^ thm_to_string hr);
val (r1n, r2n) = pairSyntax.dest_pair (rhs (concl hr));
val thmC = DB.fetch "forge_refundExclusionSource" "refund_u298_exclusion_source_any_handler";
val modulo = DB.fetch "forge_refundInstallHandler" "installed_modulo_install_handler";
val suffices = DB.fetch "forge_refundInstallHandler" "install_exclusion_suffices";
(* Variables of thmC. *)
val cC = concl thmC;
val mc0 = fv cC "mc0"; val mcC = fv cC "mc_conf"; val ffi = fv cC "ffi"; val ms = fv cC "ms";
val cbspace = fv cC "cbspace"; val data_sp = fv cC "data_sp";
(* The weak installed predicate of U360 at the exact code, bitmaps and configuration. *)
val mm = concl modulo; val (mante, mconc) = dest_imp mm;
val msub = [fv mm "mc" |-> mc0, fv mm "bytes" |-> ``forge_refundArm8Compile$code``, fv mm "bitmaps" |-> ``forge_refundArm8Compile$data``,
            fv mm "ffi_names" |-> ``refund_lab_conf2.ffi_names``, fv mm "shmem" |-> ``refund_lab_conf2.shmem_extra``,
            fv mm "r1" |-> r1n, fv mm "r2" |-> r2n, fv mm "ms" |-> ms, fv mm "cbspace" |-> cbspace, fv mm "data_sp" |-> data_sp];
val modulo_i = INST msub modulo;
val weak = el 2 (strip_conj (fst (dest_imp (concl modulo_i))));
val weak_def = new_definition ("refund_installed_no_handler_def",
  ``refund_installed_no_handler ^mc0 ^ms ^cbspace ^data_sp = ^weak``);
val _ = pr ("DEFINITION " ^ thm_to_string weak_def);
val nofail = el 3 (strip_conj (fst (dest_imp cC)));
val u298 = ``!j ms' ffi'. targetSem$evaluate ^mc0 ^ffi j ^ms = (TimeOut,ms',ffi') ==> (^mc0).target.get_pc ms' <> (^mc0).install_pc``;
val handler = rand (rator (rator (rand (rator (rator mconc)))))  handle _ => ``ARB:num``;
val mc2 = rand (rator (rator (snd (dest_imp (concl modulo_i)))));
val _ = pr ("HANDLER_RECORD " ^ term_to_string mc2);
val goalR = ``is_arm8_machine_config ^mc0 /\ ^nofail /\ refund_installed_no_handler ^mc0 ^ms ^cbspace ^data_sp ==> ^u298``;
val thmR = store_thm ("refund_u298_exclusion_real", goalR,
  strip_tac >>
  qpat_x_assum `refund_installed_no_handler _ _ _ _` (assume_tac o PURE_REWRITE_RULE [weak_def]) >>
  `installed forge_refundArm8Compile$code ^cbspace forge_refundArm8Compile$data ^data_sp refund_lab_conf2.ffi_names (^r1n,^r2n) ^mc2
      refund_lab_conf2.shmem_extra ^ms` by
     (match_mp_tac modulo_i >> conj_tac >> first_assum ACCEPT_TAC) >>
  `is_arm8_machine_config ^mc2` by fs [is_arm8_machine_config_def] >>
  `same_but_install ^mc0 ^mc2` by (simp [same_but_install_def] >> metis_tac []) >>
  mp_tac (INST [mcC |-> mc2] thmC) >>
  impl_tac >- (asm_rewrite_tac [hr] >> show_tac "IMPL" >> NO_TAC) >>
  strip_tac >> first_assum ACCEPT_TAC);
val _ = (tags "refund_u298_exclusion_real" thmR; pr ("CHECKED refund_u298_exclusion_real\n" ^ thm_to_string thmR));

(* Apply install_exclusion_suffices (U360) and the published compile_correct: behaviour inclusion for the real record. *)
val s0 = INST_TYPE (match_type (type_of (fv (concl suffices) "ffi")) (type_of ffi)) suffices handle _ => suffices;
val sm = concl s0;
val suff_i = INST [fv sm "mc" |-> mc0, fv sm "bytes" |-> ``forge_refundArm8Compile$code``, fv sm "bitmaps" |-> ``forge_refundArm8Compile$data``,
            fv sm "ffi_names" |-> ``refund_lab_conf2.ffi_names``, fv sm "shmem" |-> ``refund_lab_conf2.shmem_extra``,
            fv sm "r1" |-> r1n, fv sm "r2" |-> r2n, fv sm "ms" |-> ms, fv sm "cbspace" |-> cbspace, fv sm "data_sp" |-> data_sp,
            fv sm "ffi" |-> ffi] s0;
val mcty = type_of mc0;
val cc0 = DB.fetch "backendProof" "compile_correct";
val cc1 = INST_TYPE (match_type (type_of (fv (concl cc0) "mc")) mcty) cc0;
val cc2 = INST_TYPE (match_type (type_of (fv (concl cc1) "ffi")) (type_of ffi)) cc1;
val b2 = concl cc2;
val mc2v = mk_var ("mc2", mcty);
val c1v = mk_var ("c1", type_of (fv b2 "c'"));
val cc = INST [fv b2 "mc" |-> mc2v, fv b2 "asm_conf" |-> ``arm8_config``, fv b2 "c" |-> cfg, fv b2 "prog" |-> ``refund_prog``,
               fv b2 "bytes" |-> ``forge_refundArm8Compile$code``, fv b2 "bitmaps" |-> ``forge_refundArm8Compile$data``, fv b2 "c'" |-> c1v,
               fv b2 "ffi" |-> ffi, fv b2 "ms" |-> ms, fv b2 "cbspace" |-> cbspace, fv b2 "data_sp" |-> data_sp] cc2;
val hr2 = EVAL ``heap_regs arm8_backend_config.stack_conf.reg_names``;
val link = DB.fetch "forge_refundExclusionSource" "compile_lab_conf";
val goalF = ``is_arm8_machine_config ^mc0 /\ ^nofail /\ refund_installed_no_handler ^mc0 ^ms ^cbspace ^data_sp ==>
   machine_sem ^mc0 ^ffi ^ms SUBSET
   extend_with_resource_limit (semantics_prog (FST (THE (prim_sem_env ^ffi))) (SND (THE (prim_sem_env ^ffi))) refund_prog)``;
val thmF = store_thm ("refund_compile_correct_no_handler", goalF,
  strip_tac >>
  `^u298` by (match_mp_tac thmR >> rpt conj_tac >> first_assum ACCEPT_TAC) >>
  qpat_x_assum `refund_installed_no_handler _ _ _ _` (assume_tac o PURE_REWRITE_RULE [weak_def]) >>
  mp_tac suff_i >> impl_tac >- (rpt conj_tac >> first_assum ACCEPT_TAC) >> strip_tac >>
  qpat_x_assum `?t m bitmap_ptr bitmaps_dm sdm. _` kall_tac >>
  strip_assume_tac forge_refundLabClosureTheory.refund_alloc_compiled >> drule link >> strip_tac >>
  `c1.lab_conf = refund_lab_conf2` by (assume_tac refund_lab_compile >> gvs []) >>
  `lab_to_targetProof$mc_conf_ok mc2` by (irule arm8_machine_config_ok >> first_assum ACCEPT_TAC) >>
  `mc_init_ok arm8_config ^cfg mc2` by (imp_res_tac arm8_init_ok >> fs [set_oracle_def]) >>
  `backend_config_ok arm8_config ^cfg` by (assume_tac arm8_backend_config_ok >> fs [set_oracle_def]) >>
  mp_tac cc >> Cases_on `THE (prim_sem_env ^ffi)` >> fs [hr, hr2]);
val _ = (tags "refund_compile_correct_no_handler" thmF; pr ("CHECKED refund_compile_correct_no_handler\n" ^ thm_to_string thmF));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

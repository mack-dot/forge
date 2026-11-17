(* Exact refund program at the ARMv8 configuration: the compile-level premises that are computable are discharged. *)
load "backendProofTheory"; load "arm8_configProofTheory";
open preamble backendTheory labSemTheory labLangTheory labPropsTheory lab_filterTheory targetSemTheory targetPropsTheory
     lab_to_targetTheory lab_to_targetProofTheory arm8_configProofTheory
     forge_targetInstallPrefixTheory forge_refundExactExclusionTheory forge_refundExclusionChainTheory
     forge_installHandlerIrrelevantTheory forge_refundExclusionFinalTheory forge_refundCompileFactsTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundExclusionArm8";
val exact0 = DB.fetch "forge_refundExclusionChain" "refund_compile_install_exclusion";
(* The ARMv8 machine configuration type fixes the machine state and projection types. *)
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val mc0v = valOf (List.find (fn v => fst (dest_var v) = "mc_conf") (free_vars (concl exact0)));
val exact = INST_TYPE (match_type (type_of mc0v) mcty) exact0;
fun fv tm n = valOf (List.find (fn v => fst (dest_var v) = n) (free_vars tm));
val body = concl exact;
val mc = fv body "mc_conf";
val labc_tm = ``(FST (SND (backend$to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))).lab_conf``;
val inst_thm = INST [fv body "asm_conf" |-> ``arm8_config``, fv body "c" |-> labc_tm,
                     fv body "bytes" |-> ``forge_refundArm8Compile$code``, fv body "c'" |-> ``refund_lab_conf2``,
                     fv body "i" |-> ``LENGTH (^mc).ffi_names``] exact;
val (ante, conc) = dest_imp (concl inst_thm);
val cs = strip_conj ante;
val _ = pr ("PREMISES_AFTER_INSTANTIATION " ^ Int.toString (length cs));
val _ = ListPair.app (fn (k, t) => pr ("PREMISE " ^ Int.toString k ^ " " ^ String.substring (term_to_string t, 0, Int.min (150, size (term_to_string t))))) (List.tabulate (length cs, fn k => k + 1), cs);
(* Premises kept: 2 (consequent only), 8, 9, 10, 11, 14, 16. Premise 1 is replaced by is_arm8_machine_config. *)
val keep = [snd (dest_imp (el 2 cs)), el 8 cs, el 9 cs, el 10 cs, el 11 cs, el 14 cs, el 16 cs];
val goal = mk_imp (list_mk_conj (``is_arm8_machine_config ^mc`` :: keep), conc);
val arm8_thm = store_thm ("refund_install_exclusion_arm8", goal,
  strip_tac >>
  `(^mc).target.config = arm8_config` by (fs[is_arm8_machine_config_def] >> simp[arm8_targetTheory.arm8_target_def]) >>
  `mmio_pcs_min_index (^mc).ffi_names = SOME (LENGTH (^mc).ffi_names)` by (strip_assume_tac refund_lab_ffi_names >> gvs[]) >>
  `EVERY (\x. ?s. x = ExtCall s) (^mc).ffi_names` by (drule mmio_pcs_min_index_is_SOME >> rw[EVERY_EL]) >>
  `mc_conf_ok ^mc` by (irule arm8_machine_config_ok >> first_assum ACCEPT_TAC) >>
  match_mp_tac inst_thm >>
  rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >>
  asm_simp_tac (srw_ss()) [refund_lab_good_code, refund_lab_conf_facts, refund_lab_compile, refund_lab_no_share_mem,
                            no_install_or_no_share_mem_def]);
val _ = (tags "refund_install_exclusion_arm8" arm8_thm; pr ("CHECKED refund_install_exclusion_arm8\n" ^ thm_to_string arm8_thm));
(* The installed form: the installed-state clauses come from the published installed predicate. *)
val coracle = fv (concl arm8_thm) "coracle"; val ffi = fv conc "ffi"; val ms = fv conc "ms";
val cbspace = fv (concl arm8_thm) "cbspace";
val sem_tm = el 7 keep; val orac_tm = el 1 keep;
val tv = fv sem_tm "t"; val mv = fv sem_tm "m"; val dmv = fv sem_tm "dm"; val sdmv = fv sem_tm "sdm";
val gis = el 3 keep;
val sem_prem = list_mk_forall ([tv, mv, dmv, sdmv], mk_imp (gis, mk_conj (orac_tm, sem_tm)));
val inst_goal = mk_imp (list_mk_conj [``is_arm8_machine_config ^mc``,
    ``installed forge_refundArm8Compile$code ^cbspace bitmaps data_sp refund_lab_conf2.ffi_names (r1,r2) ^mc refund_lab_conf2.shmem_extra ^ms``,
    sem_prem], conc);
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (300, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val installed_thm = store_thm ("refund_install_exclusion_installed", inst_goal,
  rewrite_tac [installed_def] >> BETA_TAC >> strip_tac >> fs[LET_THM] >>
  `mmio_pcs_min_index (^mc).ffi_names = SOME (LENGTH (^mc).ffi_names)` by (strip_assume_tac refund_lab_ffi_names >> gvs[]) >>
  qpat_x_assum `!i. mmio_pcs_min_index _ = SOME i ==> _` drule >> strip_tac >>
  qpat_x_assum `!t m dm sdm. good_init_state _ _ _ _ _ _ _ _ ==> _` drule >> strip_tac >>
  irule (GEN_ALL arm8_thm) >> rpt (first_assum (irule_at Any)) >> fs[] >> show_tac "INSTALLED_RESIDUE");
val _ = (tags "refund_install_exclusion_installed" installed_thm; pr ("CHECKED refund_install_exclusion_installed\n" ^ thm_to_string installed_thm));
(* Any installer handler: the U298 form for a machine that differs from an installed one only in install_interfer. *)
val mc0 = mk_var ("mc0", type_of mc);
val (iante, _) = dest_imp (concl installed_thm);
val u298 = ``!j ms' ffi'. targetSem$evaluate ^mc0 ^ffi j ^ms = (TimeOut,ms',ffi') ==> (^mc0).target.get_pc ms' <> (^mc0).install_pc``;
val any_goal = mk_imp (mk_conj (``same_but_install ^mc0 ^mc``, iante),
                       mk_conj (u298, ``!k. targetSem$evaluate ^mc0 ^ffi k ^ms = targetSem$evaluate ^mc ^ffi k ^ms``));
val any_thm = store_thm ("refund_u298_exclusion_any_handler", any_goal,
  strip_tac >>
  `^conc` by (match_mp_tac installed_thm >> rpt conj_tac >> first_assum ACCEPT_TAC) >>
  drule_all no_install_prefix_same_but_install >> strip_tac >>
  conj_tac >- (first_x_assum (fn th => ACCEPT_TAC (REWRITE_RULE [no_install_prefix_all] th))) >> first_assum ACCEPT_TAC);
val _ = (tags "refund_u298_exclusion_any_handler" any_thm; pr ("CHECKED refund_u298_exclusion_any_handler\n" ^ thm_to_string any_thm));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

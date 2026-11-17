(* Exact compiler facts for the refund lab program: good_code, configuration, compile equation, ffi-name facts. *)
load "backendProofTheory"; load "arm8_configProofTheory";
open preamble cv_transLib backendTheory backend_asmTheory labSemTheory labLangTheory labPropsTheory lab_filterTheory
     asmTheory lab_to_targetTheory lab_to_targetProofTheory backendPropsTheory backend_arm8Theory
     forge_refundLabClosureTheory forge_refundLabFilteredTheory forge_refundExactExclusionTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundCompileFacts";
(* Executable form of the published good_code at the ARMv8 configuration and empty label table. *)
val refs_line_def = Define `
  refs_line l = case l of
      LabAsm a _ _ _ => (case a of LocValue _ (Lab n1 n2) => [(n1,n2)]
                                 | Jump (Lab n1 n2) => [(n1,n2)]
                                 | JumpCmp _ _ _ (Lab n1 n2) => [(n1,n2)]
                                 | _ => [])
    | _ => []`;
val has_label_def = Define `has_label (b:num) ls = EXISTS (\l. case l of Label _ l2 _ => l2 = b | _ => F) ls`;
val lab_defined_def = Define `lab_defined a b secs = EXISTS (\sec. Section_num sec = a /\ has_label b (Section_lines sec)) secs`;
val refs_ok_def = Define `
  refs_ok whole secs = EVERY (\sec. EVERY (\l. EVERY (\p. SND p = 0 \/ lab_defined (FST p) (SND p) whole) (refs_line l)) (Section_lines sec)) secs`;
val line_ok_pre8_def = Define `line_ok_pre8 l = case l of Asm b _ _ => asm_ok_arm8 (compile_shmem b) | _ => T`;
val ends_label_def = Define `
  (ends_label [] = F) /\ (ends_label [x] = is_Label x) /\ (ends_label (x::y::ys) = ends_label (y::ys))`;
val ends_label_thm = prove (``!ls. ends_label ls <=> ~NULL ls /\ is_Label (LAST ls)``,
  ho_match_mp_tac (theorem "ends_label_ind") >> rw[ends_label_def]);
val gc_check_def = Define `
  gc_check secs <=>
    EVERY (\s. ends_label (Section_lines s)) secs /\ EVERY sec_labels_ok secs /\ ALL_DISTINCT (MAP Section_num secs) /\
    EVERY (\s. ALL_DISTINCT (extract_labels (Section_lines s))) secs /\ refs_ok secs secs /\
    EVERY (\s. EVERY line_ok_pre8 (Section_lines s)) secs`;
val L1_goal = ``!l x. MEM x (refs_line l) <=> x IN line_get_labels l``;
val L2_goal = ``!ls b. has_label b ls ==> b IN BIGUNION (IMAGE line_get_code_labels (set ls))``;
val L3_goal = ``!secs a b. lab_defined a b secs ==> (a,b) IN get_code_labels secs``;
val L4_goal = ``!secs. refs_ok secs secs ==> restrict_nonzero (get_labels secs) SUBSET get_code_labels secs``;
val L5_goal = ``!a. asm_ok_arm8 a <=> asm_ok a arm8_config``;
val L6_goal = ``!secs. EVERY (\s. EVERY line_ok_pre8 (Section_lines s)) secs ==> all_enc_ok_pre arm8_config secs``;
val main_goal = ``!secs. gc_check secs ==> lab_to_targetProof$good_code arm8_config LN secs``;

val L1 = prove (L1_goal, Cases >> simp[refs_line_def, line_get_labels_def] >> rpt (CASE_TAC >> simp[]));
val L2 = prove (L2_goal, simp[has_label_def, EXISTS_MEM, PULL_EXISTS] >> rpt strip_tac >> qexists_tac `l` >> Cases_on `l` >> fs[]);
val L3 = prove (L3_goal, simp[lab_defined_def, EXISTS_MEM, get_code_labels_def, PULL_EXISTS] >> rpt strip_tac >> qexists_tac `sec` >> Cases_on `sec` >> fs[sec_get_code_labels_def] >> disj2_tac >> drule L2 >> simp[]);
val cfg = arm8_targetTheory.arm8_config_def;
val adefs = [asmTheory.reg_ok_def, asmTheory.fp_reg_ok_def, asmTheory.reg_imm_ok_def, asmTheory.arith_ok_def, asmTheory.cmp_ok_def,
   asmTheory.fp_ok_def, asmTheory.inst_ok_def, asmTheory.asm_ok_def, cfg];
val k_reg = prove (``!r. reg_ok_arm8 r <=> reg_ok r arm8_config``, simp ([reg_ok_arm8_def] @ adefs));
val k_fp = prove (``!d. fp_reg_ok_arm8 d <=> fp_reg_ok d arm8_config``, simp ([fp_reg_ok_arm8_def] @ adefs));
val k_ri = prove (``!b v. reg_imm_ok_arm8 b v <=> reg_imm_ok b v arm8_config``, gen_tac >> Cases >> simp ([reg_imm_ok_arm8_def, k_reg] @ adefs));
val subs = [k_reg, k_fp, k_ri];
val k_ar = prove (``!a. arith_ok_arm8 a <=> arith_ok a arm8_config``, Cases >> simp ([arith_ok_arm8_def] @ subs @ adefs));
val k_cmp = prove (``!c r ri. cmp_ok_arm8 c r ri <=> cmp_ok c r ri arm8_config``, simp ([cmp_ok_arm8_def] @ subs @ adefs));
val k_fpo = prove (``!f. fp_ok_arm8 f <=> fp_ok f arm8_config``, Cases >> simp ([fp_ok_arm8_def] @ subs @ adefs));
val subs2 = subs @ [k_ar, k_cmp, k_fpo];
val k_inst = prove (``!i. inst_ok_arm8 i <=> inst_ok i arm8_config``, Cases >> simp ([inst_ok_arm8_def] @ subs2 @ adefs) >> rpt (CASE_TAC >> simp (subs2 @ adefs)));
val L5 = store_thm ("asm_ok_arm8_link", L5_goal, Cases >> simp ([asm_ok_arm8_def, k_inst] @ subs2 @ adefs));
val L4 = prove (L4_goal,
  rpt strip_tac >> fs[refs_ok_def, restrict_nonzero_def, SUBSET_DEF, get_labels_def, EVERY_MEM, PULL_EXISTS] >> rpt strip_tac >>
  rename1 `MEM sec secs` >> Cases_on `sec` >> fs[sec_get_labels_def] >>
  first_x_assum (qspec_then `Section n l m` mp_tac) >> simp[] >> disch_then (qspec_then `x'` mp_tac) >> simp[] >>
  disch_then (qspec_then `x` mp_tac) >> gvs[L1] >> strip_tac >> Cases_on `x` >> fs[] >> drule L3 >> simp[]);
val L6 = prove (L6_goal,
  rw[EVERY_MEM] >> rename1 `MEM sc secs` >> Cases_on `sc` >> fs[sec_ok_pre_def, EVERY_MEM] >> rw[] >> first_x_assum drule >> simp[] >> disch_then drule >>
  rename1 `line_ok_pre8 ln` >> Cases_on `ln` >> simp[line_ok_pre8_def, line_ok_pre_def, L5]);
val L0 = prove (``!secs. EVERY (\s. ends_label (Section_lines s)) secs ==> EVERY sec_ends_with_label secs``,
  rw[EVERY_MEM] >> res_tac >> rename1 `MEM sc secs` >> Cases_on `sc` >> fs[sec_ends_with_label_def, ends_label_thm]);
val gc_sound = store_thm ("gc_check_good_code", main_goal,
  rw[gc_check_def, good_code_def]
  >- (irule L0 >> simp[])
  >- fs[EVERY_MEM, combinTheory.o_DEF] >- (irule L4 >> simp[]) >- (irule L6 >> simp[]));
val _ = pr "SOUNDNESS_PROVED";
(* Configuration facts. *)
val L_tm = ``SND (SND (backend$to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))``;
val cnf_tm = ``FST (SND (backend$to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))``;
val labc_tm = ``(^cnf_tm).lab_conf``;
val lab_conf_goal = ``!asm_conf c p. (FST (SND (backend$to_lab asm_conf c p))).lab_conf = c.lab_conf``;
val lab_conf_thm = store_thm ("to_lab_lab_conf", lab_conf_goal,
  rpt gen_tac >> simp[to_lab_def, to_stack_def] >> rpt (pairarg_tac >> fs[]) >> rveq >> fs[] >>
  drule backendProofTheory.to_word_lab_conf >> simp[]);
val base = EVAL ``arm8_backend_config.lab_conf``;
val _ = pr ("EVAL_LAB_CONF " ^ thm_to_string base);
val conf_goal = ``(^labc_tm).labels = LN /\ (^labc_tm).pos = 0 /\ (^labc_tm).ffi_names = NONE``;
val conf_thm = store_thm ("refund_lab_conf_facts", conf_goal,
  simp[lab_conf_thm, set_oracle_def] >> EVAL_TAC);
(* Compile equation without attach_bitmaps. *)
val target = DB.fetch "forge_refundLabClosure" "refund_alloc_target";
val conf2_def = new_definition ("refund_lab_conf2_def", ``refund_lab_conf2 = SND (THE (lab_to_target$compile arm8_config ^labc_tm ^L_tm))``);
val compile_goal = ``lab_to_target$compile arm8_config ^labc_tm ^L_tm = SOME (forge_refundArm8Compile$code, refund_lab_conf2)``;
val compile_thm = store_thm ("refund_lab_compile", compile_goal,
  strip_assume_tac target >> drule backendProofTheory.attach_bitmaps_SOME >> strip_tac >> gvs[conf2_def]);
val bitmaps_goal = ``FST (backend$to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog) = forge_refundArm8Compile$data``;
val bitmaps_thm = store_thm ("refund_lab_bitmaps", bitmaps_goal,
  strip_assume_tac target >> drule backendProofTheory.attach_bitmaps_SOME >> strip_tac >> gvs[]);
(* FFI-name facts from the published lemma, with the exact no-ShareMem fact. *)
val ffi_goal = ``?ffi_names. refund_lab_conf2.ffi_names = SOME ffi_names /\ mmio_pcs_min_index ffi_names = SOME (LENGTH ffi_names)``;
val ffi_thm = store_thm ("refund_lab_ffi_names", ffi_goal,
  irule backendProofTheory.compile_lab_no_share_mem_IMP_mmio_pcs_min_index >>
  mp_tac compile_thm >> simp[lab_to_targetTheory.compile_def] >> strip_tac >>
  goal_assum (first_assum o mp_then Any mp_tac) >>
  simp[refund_lab_no_share_mem, conf_thm]);
val _ = pr "CONFIG_FACTS_PROVED";
(* good_code by in-logic evaluation. *)
val gc_eval_def = Define `gc_eval c p = case lab_forge8 c p of NONE => F | SOME L => gc_check L`;
val _ = List.app (fn th => (cv_auto_trans th; ())) [ends_label_def, refs_line_def, has_label_def, lab_defined_def, refs_ok_def, line_ok_pre8_def, gc_check_def, gc_eval_def];
val prog_def = DB.fetch "forge_refundWholeProg" "refund_prog_def";
val _ = Feedback.trace ("Theory.allow_rebinds", 1) (cv_trans_deep_embedding EVAL) prog_def;
val c = EVAL ``arm8_config$arm8_backend_config``;
val c_oracle_tm = ``set_oracle ^(rhs (concl c)) refund_alloc_oracle``;
val gc_ev = cv_eval ``gc_eval ^c_oracle_tm refund_prog`` |> REWRITE_RULE [GSYM c];
val _ = pr ("EVAL_GC " ^ thm_to_string gc_ev);
val _ = save_thm ("gc_eval_result", gc_ev);
val lab_link = DB.fetch "forge_refundLabClosure" "lab_forge8_to_lab";
val gc_L = prove (``gc_check ^L_tm``,
  mp_tac gc_ev >> simp[gc_eval_def] >> CASE_TAC >> simp[] >> strip_tac >> drule lab_link >> strip_tac >> gvs[]);
val good_code_thm = store_thm ("refund_lab_good_code", ``lab_to_targetProof$good_code arm8_config LN ^L_tm``,
  irule gc_sound >> rewrite_tac [gc_L]);
(* Negative control: the check rejects a section that refers to an undefined label. *)
val control = store_thm ("gc_check_rejects_undefined_label",
  ``~gc_check [Section 5 [LabAsm (Jump (Lab 7 1)) 0 [] 0; Label 5 1 0] ARB]``,
  EVAL_TAC);
val all = [("asm_ok_arm8_link", L5), ("gc_check_good_code", gc_sound), ("to_lab_lab_conf", lab_conf_thm), ("refund_lab_conf_facts", conf_thm),
  ("refund_lab_compile", compile_thm), ("refund_lab_bitmaps", bitmaps_thm), ("refund_lab_ffi_names", ffi_thm),
  ("refund_lab_good_code", good_code_thm), ("gc_check_rejects_undefined_label", control)];
val _ = List.app (fn (n, th) => (tags n th; let val t = thm_to_string th in pr ("CHECKED " ^ n ^ "\n" ^ String.substring (t, 0, Int.min (1500, size t))) end)) all;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

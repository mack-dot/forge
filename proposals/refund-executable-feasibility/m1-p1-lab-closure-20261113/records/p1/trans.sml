(* cv translations of the re-specialised functions; tactics as in the published backend_arm8_cvScript. *)
val pre = cv_auto_trans_pre "" (comp_f8 |> arch_spec);
val comp_pre = store_thm ("comp_forge8_pre[cv_pre]", ``!perf v bs kf. comp_forge8_pre perf v bs kf``,
  gen_tac \\ gen_tac \\ completeInduct_on `prog_size v`
  \\ rw [] \\ gvs [PULL_FORALL] \\ rw [] \\ simp [Once pre] \\ rw [] \\ gvs [] \\ last_x_assum irule \\ gvs []);
val _ = cv_auto_trans (compile_prog_f8 |> arch_spec);
val pre = cv_auto_trans_pre "" (cwts_f8 |> arch_spec);
val cwts_pre = store_thm ("compile_word_to_stack_forge8_pre[cv_pre]",
  ``!perf k v bitmaps. compile_word_to_stack_forge8_pre perf k v bitmaps``, Induct_on `v` \\ rw [] \\ simp [Once pre]);
val pre = cv_trans_pre "" (get_forced_f8 |> arch_spec);
val get_forced_pre = store_thm ("get_forced_forge8_pre[cv_pre]", ``!v acc. get_forced_forge8_pre v acc``,
  gen_tac \\ completeInduct_on `prog_size v` \\ rw [] \\ gvs [PULL_FORALL] \\ simp [Once pre] \\ rw [] \\ gvs [] \\ last_x_assum $ irule \\ gvs []);
val _ = cv_trans (word_alloc_f8 |> arch_spec);
val pre = cv_trans_pre "" (inst_select_exp_f8 |> arch_spec);
val inst_select_exp_pre = store_thm ("inst_select_exp_forge8_pre[cv_pre]",
  ``!bits v tar temp. inst_select_exp_forge8_pre bits tar temp v``,
  gen_tac \\ gen_tac \\ completeInduct_on `exp_size v` \\ rw [] \\ gvs [PULL_FORALL] \\ rw [] \\ simp [Once pre] \\ rw [] \\ gvs []
  \\ last_x_assum irule \\ gvs []);
val pre = cv_trans_pre "" (inst_select_f8 |> arch_spec);
val inst_select_pre = store_thm ("inst_select_forge8_pre[cv_pre]", ``!bits v temp. inst_select_forge8_pre bits temp v``,
  gen_tac \\ gen_tac \\ completeInduct_on `prog_size v` \\ rw [] \\ gvs [PULL_FORALL] \\ simp [Once pre] \\ rw []
  \\ first_x_assum irule \\ gvs []);
val pre = (each_f8 |> arch_spec) |> cv_trans_pre "";
val each_pre = store_thm ("each_inlogic_forge8_pre[cv_pre]", ``!v. each_inlogic_forge8_pre v``, Induct \\ rw [] \\ simp [Once pre]);
val _ = cv_trans (w2w_f8 |> arch_spec);
(* The lab program of the published pipeline, computed with the in-logic word_to_word check. *)
val lab_forge8_def = Define `lab_forge8 c p =
  let (c0,p0) = to_word_0_arm8 c p in
  case word_to_word_inlogic_forge8 c0.word_to_word_conf p0 of
    NONE => NONE
  | SOME (col,wp) =>
     let perf = c0.stack_conf.perf_calls in
     let (progs,fs,bitmaps) = compile_word_to_stack_forge8 perf 24 wp (if perf then (List [16],1) else (List [4],1)) in
     let sp = (raise_stub_location,raise_stub perf 24,Metadata (strlit "_Raise") [Stub])::
              (store_consts_stub_location,store_consts_stub 24,Metadata (strlit "_StoreConsts") [Stub])::progs in
       SOME (stack_to_lab$compile (arch_wordsize ARMv8) c0.stack_conf c0.data_conf
               (2 * max_heap_limit 64 c0.data_conf - 1) 26 (-4351,4350) sp)`;
val arm8_link = prove (``to_word_0_arm8 c p = to_word_0 arm8_config c p``,
  simp[backend_arm8Theory.to_word_0_arm8_def, to_word_0_def, backend_arm8Theory.compile_0_arm8_def,
       data_to_wordTheory.compile_0_def, arm8_targetTheory.arm8_config_def]);
(* The published lemma word_to_word_inlogic_thm is local to backend_asmScript; same statement and tactic. *)
val w2w_inlogic_thm = prove (``word_to_word_inlogic asm_conf c.word_to_word_conf p = SOME (col,prog) ==>
  word_to_word$compile c.word_to_word_conf asm_conf p = (col,prog)``,
  gvs [word_to_word_inlogic_def,word_to_wordTheory.compile_def]
  \\ pairarg_tac \\ gvs [AllCaseEqs()] \\ rw []
  \\ last_x_assum kall_tac
  \\ pop_assum mp_tac
  \\ qspec_tac (`ZIP (p,n_oracles)`,`xs`)
  \\ qid_spec_tac `prog`
  \\ Induct_on `xs`
  \\ gvs [each_inlogic_def]
  \\ PairCases
  \\ gvs [each_inlogic_def,AllCaseEqs(),word_alloc_inlogic_def]
  \\ rpt strip_tac \\ gvs []
  \\ gvs [word_to_wordTheory.full_compile_single_def]
  \\ gvs [word_to_wordTheory.compile_single_def]
  \\ rw [] \\ gvs [word_allocTheory.word_alloc_def]);
val lab_link_goal = ``lab_forge8 c p = SOME L ==> SND (SND (to_lab arm8_config c p)) = L``;

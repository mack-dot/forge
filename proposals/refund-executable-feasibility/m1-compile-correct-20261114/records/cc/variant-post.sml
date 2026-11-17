
val guard_thm = DB.fetch "forge_compileCorrectLabFacts" "compile_correct_lab_guard";
val _ = (tags "compile_correct_lab_guard" guard_thm; pr ("CHECKED compile_correct_lab_guard\n" ^ thm_to_string guard_thm));

Theorem determ_not_fail:
  ~semantics_prog s env prog Fail ==> Fail NOTIN semantics_determ (s with ptr_eq_oracle := po) env prog
Proof
  strip_tac \\ strip_tac
  \\ assume_tac (Q.INST [`e` |-> `env`, `p` |-> `prog`] semantics_determ_SUBSET_semantics_prog)
  \\ fs [SUBSET_DEF] \\ res_tac \\ fs [IN_DEF]
QED

(* The lab facts hold under the published premises of compile_correct'. *)
Theorem compile_correct_lab_facts:
  compile (asm_conf:asm_config) (c:config) prog = SOME (bytes,bitmaps,c') ⇒
   let (s0,env) = THE (prim_sem_env (ffi:'ffi ffi_state)) in
   let s = add_eval_state ev s0 in
   ¬semantics_prog s env prog Fail ∧
   backend_config_ok asm_conf c ∧ lab_to_targetProof$mc_conf_ok (mc:('a,'b,'c) machine_config) ∧ mc_init_ok asm_conf c mc ∧
   opt_eval_config_wf (:'a) asm_conf c' ev ∧
   installed bytes cbspace bitmaps data_sp c'.lab_conf.ffi_names (heap_regs c.stack_conf.reg_names) mc
      c'.lab_conf.shmem_extra ms ⇒
   lab_facts asm_conf c prog bytes c' mc ffi ms cbspace
Proof
  rw [] \\ pairarg_tac \\ fs [] \\ rw []
  \\ mp_tac compile_correct_lab_guard \\ fs [] \\ strip_tac
  \\ drule lab_guard_elim
  \\ impl_tac >- (irule determ_not_fail \\ first_assum ACCEPT_TAC)
  \\ simp []
QED
val _ = (tags "compile_correct_lab_facts" compile_correct_lab_facts; pr ("CHECKED compile_correct_lab_facts\n" ^ thm_to_string compile_correct_lab_facts));

(* Fidelity: the guarded theorem gives the published statement again. *)
Theorem compile_correct_from_guard:
  compile (asm_conf:asm_config) (c:config) prog = SOME (bytes,bitmaps,c') ⇒
   let (s0,env) = THE (prim_sem_env (ffi:'ffi ffi_state)) in
   let s = add_eval_state ev s0 in
   ¬semantics_prog s env prog Fail ∧
   backend_config_ok asm_conf c ∧ lab_to_targetProof$mc_conf_ok (mc:('a,'b,'c) machine_config) ∧ mc_init_ok asm_conf c mc ∧
   opt_eval_config_wf (:'a) asm_conf c' ev ∧
   installed bytes cbspace bitmaps data_sp c'.lab_conf.ffi_names (heap_regs c.stack_conf.reg_names) mc
      c'.lab_conf.shmem_extra ms ⇒
   ∃po.
     machine_sem (mc:(α,β,γ) machine_config) ffi ms ⊆
       extend_with_resource_limit'
         (is_safe_for_space (:'a) ffi po asm_conf c prog (read_limits asm_conf c mc ms))
         (semantics_determ (s with ptr_eq_oracle := po) env prog)
Proof
  rw [] \\ pairarg_tac \\ fs [] \\ rw []
  \\ mp_tac compile_correct_lab_guard \\ fs [] \\ strip_tac
  \\ qexists_tac `po`
  \\ drule lab_guard_elim
  \\ impl_tac >- (irule determ_not_fail \\ first_assum ACCEPT_TAC)
  \\ simp []
QED
val pub = DB.fetch "backendProof" "compile_correct'";
val _ = if aconv (concl pub) (concl compile_correct_from_guard) then pr "FIDELITY published statement recovered from the guarded theorem: true"
        else raise Fail "fidelity statement differs";
val _ = pr ("DEFINITION " ^ thm_to_string lab_facts_def);
val _ = pr ("DEFINITION " ^ thm_to_string lab_guard_def);
val closure = "forge_compileCorrectLabFacts" :: Theory.ancestry "forge_compileCorrectLabFacts";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = export_theory ();
val _ = pr "REPLAY_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

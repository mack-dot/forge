
(* The exclusion conclusion with its three Forge premises, kept opaque while published tactics run. *)
Definition nip_goal_def:
  nip_goal Inv (mc:('a,'state,'b) machine_config) io ms s (code2:sec list) <=>
    (lab_step_closed Inv /\ (!k. Inv (s with clock := k)) /\ code_layout_ok (:'a) code2 ==>
     !n. no_install_prefix mc io n ms)
End

(* Same antecedent chain as the published intermediate form of machine_sem_EQ_sem. *)
Theorem exclusion_mid:
  !mc_conf p ms ^s1 code2 labs t1 Inv.
    encoder_correct mc_conf.target ==>
    state_rel (mc_conf,code2,labs,p) s1 t1 ms ==>
    oracle_tie mc_conf ms s1 ==>
    semantics s1 <> Fail ==>
    nip_goal Inv mc_conf s1.ffi (ms:'state) s1 code2
Proof
  rw[nip_goal_def]
  \\ qspecl_then [`Inv`,`s1`,`mc_conf`,`ms`,`code2`,`labs`,`p`,`t1`] mp_tac
       (Q.GENL [`Inv`,`s1`,`mc_conf`,`ms1`,`code2`,`labs`,`p`,`t1`] target_install_exclusion_conditional)
  \\ impl_tac
  >- (simp[] \\ qpat_x_assum `semantics _ <> Fail` mp_tac \\ simp[labSemTheory.semantics_def] \\ rw[] \\ fs[])
  \\ simp[]
QED


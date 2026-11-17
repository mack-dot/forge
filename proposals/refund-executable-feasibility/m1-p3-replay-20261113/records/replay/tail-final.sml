
Finalise compile_no_install_prefix;

(* The published conclusion and the prefix property together. The first conjunct is the published theorem. *)
Theorem compile_correct_no_install_prefix:
  lab_step_closed Inv ==>
  !^s1 res (mc_conf: ('a,'state,'b) machine_config) s2 code2 labs t1 ms1.
     oracle_tie mc_conf ms1 s1 /\
     (evaluate s1 = (res,s2)) /\ (res <> Error) /\
     encoder_correct mc_conf.target /\
     state_rel (mc_conf,code2,labs,p) s1 t1 ms1 /\
     Inv s1 /\ code_layout_ok (:'a) code2 ==>
     (?k t2 ms2. evaluate mc_conf s1.ffi (s1.clock + k) ms1 = (res,ms2,s2.ffi)) /\
     no_install_prefix mc_conf s1.ffi s1.clock ms1
Proof
  rpt strip_tac
  >- (mp_tac (Q.SPECL [`s1`,`res`,`mc_conf`,`s2`,`code2`,`labs`,`t1`,`ms1`] lab_to_targetProofTheory.compile_correct)
      \\ simp[])
  \\ qpat_x_assum `lab_step_closed _` (fn c => mp_tac (MATCH_MP compile_no_install_prefix c))
  \\ disch_then (fn th => mp_tac (SPEC_ALL th))
  \\ simp[]
QED

(* All-clock form: a conditional target-level exclusion for the run from ms1. *)
Theorem target_install_exclusion_conditional:
  lab_step_closed Inv /\
  (!k. Inv (^s1 with clock := k)) /\
  (!k. FST (labSem$evaluate (s1 with clock := k)) <> Error) /\
  oracle_tie (mc_conf: ('a,'state,'b) machine_config) ms1 s1 /\ encoder_correct mc_conf.target /\
  state_rel (mc_conf,code2,labs,p) s1 t1 ms1 /\ code_layout_ok (:'a) code2 ==>
  !n. no_install_prefix mc_conf s1.ffi n ms1
Proof
  rpt strip_tac
  \\ qpat_x_assum `lab_step_closed _` (fn c => assume_tac (MATCH_MP compile_no_install_prefix c))
  \\ first_x_assum (qspecl_then [`s1 with clock := n`,`FST (evaluate (s1 with clock := n))`,`mc_conf`,
        `SND (evaluate (s1 with clock := n))`,`code2`,`labs`,`t1`,`ms1`] mp_tac)
  \\ simp[]
  \\ disch_then irule
  \\ conj_tac >- (irule oracle_tie_clock \\ first_assum ACCEPT_TAC)
  \\ irule state_rel_clock \\ first_assum ACCEPT_TAC
QED

val _ = List.app (fn n => let val th = DB.fetch "forge_simReplay" n in tags n th; pr ("CHECKED " ^ n ^ "\n" ^ thm_to_string th) end)
  ["lab_step_evaluate", "seg_finish", "state_rel_ctx", "step_nip", "final_nip", "compile_no_install_prefix", "compile_correct_no_install_prefix", "target_install_exclusion_conditional"];
val _ = List.app (fn n => pr ("DEFINITION " ^ n ^ "\n" ^ thm_to_string (DB.fetch "forge_simReplay" n)))
  ["lab_step_closed_def", "nip_ctx_def", "halt_ctx_def"];
(* Fidelity: the premises before the two added ones are the published premises, and the first conclusion is the published one. *)
val _ = let
    val pub = concl lab_to_targetProofTheory.compile_correct
    val (pv, pb) = strip_forall pub; val (pa, pc) = dest_imp pb
    val mine = snd (dest_imp (concl (DB.fetch "forge_simReplay" "compile_correct_no_install_prefix")))
    val (mv, mb) = strip_forall mine; val (ma, mc) = dest_imp mb
    val mcs = strip_conj ma
    val back = list_mk_forall (mv, mk_imp (list_mk_conj (List.take (mcs, length mcs - 2)), hd (strip_conj mc)))
  in if aconv back pub then pr "FIDELITY published compile_correct recovered by removing the two added premises and the added conclusion"
     else raise Fail "Fidelity check failed" end;
val _ = export_theory ();
val _ = pr "REPLAY_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

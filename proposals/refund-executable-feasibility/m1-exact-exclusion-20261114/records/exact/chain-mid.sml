
(* The published pipeline of semantics_make_init, applied to the exclusion form. *)
val mid = exclusion_mid |> SPEC_ALL |> UNDISCH;
val nip_make_init =
  mid |> Q.GEN `s1` |> Q.GEN `p`
  |> Q.GEN `t1` |> Q.SPEC `t`
  |> Q.SPEC `(mc_conf: ('a,'state,'b) machine_config).target.get_pc ms`
  |> Q.SPEC `make_init (mc_conf: ('a,'state,'b) machine_config)
       ffi t m dm sdm (ms:'state) code
       (compile_lab mc_conf.target.config) (mc_conf.target.get_pc ms + (n2w (LENGTH (prog_to_bytes (code2:labLang$prog)))))
       cbspace coracle`
  |> SIMP_RULE std_ss [make_init_simp]
  |> MATCH_MP (MATCH_MP IMP_LEMMA IMP_state_rel_make_init)
  |> DISCH_ALL |> REWRITE_RULE [AND_IMP_INTRO,GSYM CONJ_ASSOC]
  |> REWRITE_RULE [oracle_tie_make_init];
val _ = save_thm ("nip_make_init", nip_make_init);
val _ = pr ("NIP_MAKE_INIT\n" ^ thm_to_string nip_make_init);
(* Fail closed: the antecedents must be those of the published semantics_make_init, before and after SRULE. *)
val _ = if aconv (fst (dest_imp (concl nip_make_init))) (fst (dest_imp (concl semantics_make_init)))
        then pr "FIDELITY antecedent of nip_make_init equals antecedent of the published semantics_make_init"
        else raise Fail "Antecedent differs from the published semantics_make_init";
val nip_use = SRULE [] nip_make_init;
val pub_use = SRULE [] semantics_make_init;
val _ = if aconv (fst (dest_imp (concl nip_use))) (fst (dest_imp (concl pub_use)))
        then pr "FIDELITY simplified antecedents equal"
        else raise Fail "Simplified antecedent differs from the published one";


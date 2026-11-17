(* New: the main call ends with an uncaught exception. Adapted from published call_main_thm1 and call_main_thm2. *)
val main_call = ``Dlet NoLocs (Pcon NONE []) (App Opapp [Var (Short (fname:mlstring)); Con NONE []])``;
Theorem call_main_exn1:
  Decls env1 st1 prog env2 st2 ==>
  lookup_var fname env2 = SOME mainv ==>
  app p mainv [Conv NONE []] P (POSTe exn. Q exn) ==>
  SPLIT (st2heap p st2) (h1,h2) /\ P h1 ==>
  ∃st3 exn ck1 ck2.
     evaluate_dec_list (st1 with clock := ck1) env1 (SNOC ^main_call prog) =
       (st3 with clock := ck2, Rerr (Rraise exn))
Proof
  rw [app_def,app_basic_def]
  \\ first_x_assum drule \\ fs [] \\ strip_tac \\ fs []
  \\ fs [cfHeapsBaseTheory.POSTe_def, cfHeapsBaseTheory.POST_def]
  \\ Cases_on `r` \\ fs [cond_STAR] \\ fs [cond_def]
  \\ fs [Decls_def,evaluate_to_heap_def, evaluate_ck_def]
  \\ drule evaluate_add_to_clock
  \\ disch_then (qspec_then `ck2` mp_tac) \\ simp []
  \\ qpat_x_assum `_ env1 prog = _` assume_tac
  \\ drule evaluate_dec_list_add_to_clock
  \\ disch_then (qspec_then `ck + 1` mp_tac) \\ simp []
  \\ rpt strip_tac
  \\ MAP_EVERY qexists_tac [`st'`, `v`, `ck + (ck1 + 1)`, `ck2 + st'.clock`]
  \\ simp [SNOC_APPEND,evaluate_dec_list_append,extend_dec_env_def]
  \\ simp [evaluate_dec_list_def,astTheory.pat_bindings_def]
  \\ NTAC 3 (simp [Once evaluate_def])
  \\ simp [do_con_check_def,build_conv_def]
  \\ fs [Once evaluate_def,lookup_var_def,nsLookup_nsAppend_Short]
  \\ simp [dec_clock_def,pmatch_def,combine_dec_result_def, merge_env_def,empty_env_def]
QED
val _ = (tags "call_main_exn1" call_main_exn1; pr ("CHECKED call_main_exn1\n" ^ thm_to_string call_main_exn1));

Theorem call_main_exn2:
  Decls env1 st1 prog env2 st2 ⇒
  lookup_var fname env2 = SOME mainv ⇒
  app (proj1,proj2) mainv [Conv NONE []] P (POSTe exn. Q exn) ⇒
  SPLIT (st2heap (proj1,proj2) st2) (h1,h2) ∧ P h1 ⇒
  sem_satisfies (semantics_dec_list st1 env1 (SNOC ^main_call prog))
    (λbehavior. ∃io_events. behavior = Terminate Success io_events)
Proof
  rpt strip_tac
  \\ simp [semanticsPropsTheory.sem_satisfies_def, IN_DEF]
  \\ ho_match_mp_tac semantics_dec_list_all_terminate
  \\ gen_tac
  \\ ‘Decls env1 (st1 with ptr_eq_oracle := po) prog env2
             (st2 with ptr_eq_oracle := po)’ by metis_tac [Decls_with_oracle]
  \\ ‘SPLIT (st2heap (proj1,proj2) (st2 with ptr_eq_oracle := po)) (h1,h2)’
       by fs [cfStoreTheory.st2heap_def]
  \\ drule_all (GEN_ALL call_main_exn1)
  \\ strip_tac
  \\ MAP_EVERY qexists_tac [`Success`, `st3.ffi.io_events`]
  \\ simp [semantics_dec_list_determ_def, evaluate_dec_list_with_clock_def]
  \\ qexists_tac `ck1` \\ simp []
QED
val _ = (tags "call_main_exn2" call_main_exn2; pr ("CHECKED call_main_exn2\n" ^ thm_to_string call_main_exn2));
val exn2 = call_main_exn2 |> Q.GENL [`env1`,`st1`,`prog`,`env2`,`st2`,`fname`,`mainv`,`proj1`,`proj2`,`P`,`Q`,`h1`,`h2`];

Theorem star_split_lemma:
  SPLIT s (hi,hk) ∧ (A * B * &T) hi ⇒ ∃h1 h2. SPLIT s (h1,h2) ∧ B h1
Proof
  rw [STAR_def, cond_def] \\ irule SPLIT_eq_SUBSET
  \\ qpat_assum `B _` (irule_at Any)
  \\ fs [SPLIT_def, SUBSET_DEF, EXTENSION] \\ metis_tac []
QED

(* Shape of published whole_prog_spec_IMP, for an exception post-condition. *)
Theorem exn_spec_IMP:
  app (basis_proj1,basis_proj2) main_v [Conv NONE []] (STDIO fs) (POSTe exn. Q exn) ∧
  Decls init_env (init_state (basis_ffi ext cl fs)) decs res_env res_st
  ⇒
  ∀main_name.
    let all_decs = SNOC (Dlet NoLocs (Pcon NONE [])
                     (App Opapp [Var (Short main_name); Con NONE []])) decs in
    nsLookup res_env.v (Short main_name) = SOME main_v
    ⇒
    res_st.ffi = basis_ffi ext cl fs
    ⇒
    is_refs_basis res_st.refs
    ⇒
    wfcl cl ∧ wfFS fs ∧ STD_streams fs ⇒
    sem_satisfies
      (semantics_dec_list (init_state (basis_ffi ext cl fs)) init_env all_decs)
      (λbehavior. ∃io_events. behavior = Terminate Success io_events)
Proof
  simp [] \\ rpt strip_tac
  \\ drule_all IMP_STDIO \\ strip_tac
  \\ drule_all star_split_lemma \\ strip_tac
  \\ qspecl_then [`init_env`,`init_state (basis_ffi ext cl fs)`,`decs`,`res_env`,`res_st`,`main_name`,`main_v`,
                  `basis_proj1`,`basis_proj2`,`STDIO fs`,`Q`,`h1`,`h2`] mp_tac exn2
  \\ simp [lookup_var_def]
QED
val _ = (tags "exn_spec_IMP" exn_spec_IMP; pr ("CHECKED exn_spec_IMP\n" ^ thm_to_string exn_spec_IMP));

(* Pipeline of published prove_sem_thm (basis_ffiLib.sml), with the stored refund_prog_def in place of a new definition. *)
val Decls_lemma = get_ml_prog_state () |> get_thm |> REWRITE_RULE [ML_code_def, ML_code_env_def];
val basis_ffi_term = whole_prog_spec_IMP |> concl |> rator |> rand |> rand |> rator |> rator |> rator |> rand |> rand;
val lem_vs = free_vars (concl Decls_lemma);
val ffi_var = hd (filter (fn v => fst (dest_var v) = "ffi") lem_vs);
val po_var = hd (filter (fn v => fst (dest_var v) = "po") lem_vs);
val th0 = Decls_lemma |> GEN ffi_var |> ISPEC basis_ffi_term |> SPEC_ALL |> GEN po_var
            |> (fn th => HO_MATCH_MP FORALL_po_Decls th handle HOL_ERR _ => HO_MATCH_MP FORALL_po_Decls_eval th);
val code_def = DB.fetch "forge_refundWholeProg" "refund_prog_def";
fun finish th2 = let
  val remove_snocs_conv = PURE_REWRITE_CONV [listTheory.SNOC_APPEND] THENC PURE_REWRITE_CONV [GSYM listTheory.APPEND_ASSOC] THENC
                          PURE_REWRITE_CONV [listTheory.APPEND]
  val th3 = SPEC (mlstringSyntax.mk_mlstring "refund_main") th2 |> CONV_RULE (RAND_CONV remove_snocs_conv)
  val code_tm = th3 |> concl |> rand
  val _ = if aconv code_tm (rhs (concl code_def)) then pr "CODE_IDENTICAL_TO_refund_prog true" else raise Fail "declaration list differs from refund_prog"
  val th4 = th3 |> CONV_RULE (RAND_CONV (K (SYM code_def))) |> CONV_RULE (REWR_CONV LET_THM THENC BETA_CONV)
  val th5 = let val g1 = th4 |> concl |> dest_imp |> fst
                val l = dest_eq g1 |> fst |> nsLookup_conv
            in MP th4 (prove (g1, REWRITE_TAC [l])) end
  val th6 = let val g2 = th5 |> concl |> dest_imp |> fst in MP th5 (prove (g2, EVAL_TAC)) end
  val th7 = let val g2 = th6 |> concl |> dest_imp |> fst
            in MP th6 (prove (g2, EVAL_TAC \\ REWRITE_TAC [semanticPrimitivesTheory.store_v_11, APPEND, CONS_11, basis_ffiTheory.basis_refs_eqs]
                                  \\ simp_tac std_ss [] \\ EVAL_TAC)) end
  in th7 |> DISCH_ALL |> SIMP_RULE bool_ss [GSYM CONJ_ASSOC, AND_IMP_INTRO] end;
val pp = ``(basis_proj1,basis_proj2)``;
val err_thm = DB.fetch "forge_refundStdioProg" "refund_main_error";
val _ = tags "refund_main_error" err_thm;
val _ = pr ("STORED refund_main_error\n" ^ thm_to_string err_thm);
fun pvar th = hd (filter (fn v => fst (dest_var v) = "p") (free_vars (concl th)));
val specE = err_thm |> INST_TYPE (match_type (type_of (pvar err_thm)) (type_of pp)) |> (fn th => INST [pvar th |-> pp] th) |> UNDISCH_ALL;
val rejS = finish (HO_MATCH_MP exn_spec_IMP (CONJ specE th0));
val _ = pr ("REJ_DEC " ^ thm_to_string rejS);
val specA = DB.fetch "forge_refundWholeProg" "refund_whole_prog_spec" |> UNDISCH_ALL;
val accS = finish (MATCH_MP whole_prog_spec_IMP (CONJ specA th0));
val _ = pr ("ACC_DEC " ^ thm_to_string accS);
val syn = valOf (List.find (fn th => aconv (concl th) ``prog_syntax_ok refund_prog``)
                 (CONJUNCTS (DB.fetch "forge_refundArm8Compile" "refund_arm8_compiled")));
val bffi = basis_ffi_term;
val post = ``\behavior. ?io_events. behavior = Terminate Success (io_events:io_event list)``;
val decsem = ``sem_satisfies (semantics_dec_list (init_state ^bffi) init_env refund_prog) ^post``;
val wf = ``wfcl cl /\ wfFS fs /\ STD_streams fs``;
Theorem sem_sat_weaken:
  sem_satisfies s P ∧ (∀b. P b ⇒ Q b) ⇒ sem_satisfies s Q
Proof
  rw [sem_satisfies_def] \\ res_tac
QED
(* R1. Rejected request: the program ends with an uncaught exception; the behaviour is Terminate Success. *)
val thmRej = store_thm ("refund_reject_semantics",
  ``stdin_content fs = SOME text /\ refund_run_wire (implode text) = INL err /\ ^wf ==> ^decsem``,
  strip_tac \\ mp_tac rejS \\ asm_rewrite_tac [] \\ show_tac "REJ" \\ simp []);
val _ = (tags "refund_reject_semantics" thmRej; pr ("CHECKED refund_reject_semantics\n" ^ thm_to_string thmRej));
val thmAcc = store_thm ("refund_accept_semantics",
  ``stdin_content fs = SOME text /\ refund_run_wire (implode text) = INR output /\ ^wf ==> ^decsem``,
  strip_tac \\ mp_tac accS \\ asm_rewrite_tac [] \\ strip_tac
  \\ match_mp_tac (GEN_ALL sem_sat_weaken) \\ first_assum (irule_at Any) \\ simp [PULL_EXISTS]);
val _ = (tags "refund_accept_semantics" thmAcc; pr ("CHECKED refund_accept_semantics\n" ^ thm_to_string thmAcc));
val inpS = ``stdin_content fs = SOME text /\ ^wf``;
val thmDec = store_thm ("refund_stdin_semantics", ``^inpS ==> ^decsem``,
  strip_tac \\ Cases_on `refund_run_wire (implode text)`
  >| [match_mp_tac (GEN_ALL thmRej), match_mp_tac (GEN_ALL thmAcc)] \\ asm_rewrite_tac [] \\ metis_tac []);
val _ = (tags "refund_stdin_semantics" thmDec; pr ("CHECKED refund_stdin_semantics\n" ^ thm_to_string thmDec));
val pubT = sem_satisfies_IMP_Terminate |> Q.INST [`p` |-> `\io. T`, `outcome` |-> `Success`] |> SIMP_RULE std_ss [];
val _ = pr ("PUBT " ^ thm_to_string pubT);
fun both d = MATCH_MP pubT (UNDISCH_ALL d) |> C MP syn;
fun nonfail_of bffi = ``~semantics_prog (FST (THE (prim_sem_env ^bffi))) (SND (THE (prim_sem_env ^bffi))) refund_prog Fail``;
val nofail = nonfail_of bffi;
val thmNR = store_thm ("refund_source_nonfail_reject",
  ``stdin_content fs = SOME text /\ refund_run_wire (implode text) = INL err /\ ^wf ==> ^nofail``,
  rewrite_tac [init_state_env_thm, FST, SND] \\ ACCEPT_TAC (both thmRej |> CONJUNCT1 |> DISCH_ALL));
val _ = (tags "refund_source_nonfail_reject" thmNR; pr ("CHECKED refund_source_nonfail_reject\n" ^ thm_to_string thmNR));
val thmNS = store_thm ("refund_source_nonfail_stdin", ``^inpS ==> ^nofail``,
  rewrite_tac [init_state_env_thm, FST, SND] \\ ACCEPT_TAC (both thmDec |> CONJUNCT1 |> DISCH_ALL));
val _ = (tags "refund_source_nonfail_stdin" thmNS; pr ("CHECKED refund_source_nonfail_stdin\n" ^ thm_to_string thmNS));
(* Composition with the U386 real-record theorems. *)
fun fvn tm n = valOf (List.find (fn v => fst (dest_var v) = n) (free_vars tm));
val thmR = DB.fetch "forge_refundExclusionReal" "refund_u298_exclusion_real";
val thmF = DB.fetch "forge_refundExclusionReal" "refund_compile_correct_no_handler";
fun at_basis th = let val f = fvn (concl th) "ffi" val ty = match_type (type_of f) (type_of bffi) in
   INST [inst ty f |-> bffi] (INST_TYPE ty th) end;
val thmRb = at_basis thmR; val thmFb = at_basis thmF;
val (antR, u298) = dest_imp (concl thmRb);
val [arm, nf, inst_p] = strip_conj antR;
val _ = if aconv nf nofail then pr "PREMISE_FORM_IDENTICAL true" else raise Fail "non-Fail premise form differs from U386";
val thmU = store_thm ("refund_u298_exclusion_stdin", mk_imp (list_mk_conj [arm, inst_p, inpS], u298),
  strip_tac \\ match_mp_tac thmRb \\ rpt conj_tac \\ TRY (first_assum ACCEPT_TAC)
  \\ match_mp_tac thmNS \\ asm_rewrite_tac []);
val _ = (tags "refund_u298_exclusion_stdin" thmU; pr ("CHECKED refund_u298_exclusion_stdin\n" ^ thm_to_string thmU));
val mc0 = fvn antR "mc0"; val ms = fvn antR "ms";
val t2 = both thmDec |> CONJUNCT2;
val msem = fst (dest_comb (snd (dest_imp (concl thmFb)))) |> rand;
val semv = valOf (List.find (fn v => type_of v = type_of msem) (free_vars (concl t2)));
val _ = pr ("MSEM " ^ term_to_string msem ^ " : " ^ type_to_string (type_of msem) ^ " / " ^ type_to_string (type_of semv));
val term2 = t2 |> INST [semv |-> msem] |> DISCH_ALL;
val beh = ``?io_events. ^msem SUBSET extend_with_resource_limit {Terminate Success (io_events:io_event list)}``;
val thmB = store_thm ("refund_behavior_stdin_no_handler", mk_imp (list_mk_conj [arm, inst_p, inpS], beh),
  strip_tac
  \\ mp_tac thmFb
  \\ impl_tac >- (rpt conj_tac \\ TRY (first_assum ACCEPT_TAC) \\ match_mp_tac thmNS \\ asm_rewrite_tac [])
  \\ rewrite_tac [init_state_env_thm, FST, SND] \\ strip_tac
  \\ mp_tac term2 \\ asm_rewrite_tac [targetPropsTheory.machine_sem_sing]
  \\ TRY (disch_then ACCEPT_TAC));
val _ = (tags "refund_behavior_stdin_no_handler" thmB; pr ("CHECKED refund_behavior_stdin_no_handler\n" ^ thm_to_string thmB));
val closure = "forge_refundRejectNonFail" :: Theory.ancestry "forge_refundRejectNonFail";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

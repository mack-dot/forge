(* PREPARED ONLY. NOT RUN until the initial STDIO heap lemma is checked. *)
load "ml_translatorLib";
val _ = ml_translatorLib.translation_extends "forge_refundStdioProg";
val raw_refund_decls = ml_translatorLib.get_ml_prog_state () |> ml_progLib.get_thm
  |> REWRITE_RULE [ml_progTheory.ML_code_def,ml_progTheory.ML_code_env_def];
val decl_vars = free_vars (concl raw_refund_decls);
val decl_ffi = hd (List.filter (fn v => fst (dest_var v) = "ffi") decl_vars);
val decl_po = hd (List.filter (fn v => fst (dest_var v) = "po") decl_vars);
val refund_decls = raw_refund_decls |> GEN decl_ffi
  |> ISPEC ``basis_ffi ext cl fs`` |> SPEC_ALL |> GEN decl_po
  |> (fn th => HO_MATCH_MP FORALL_po_Decls th
       handle HOL_ERR _ => HO_MATCH_MP FORALL_po_Decls_eval th);
val [decl_env0,decl_st0,decl_prog,decl_env2,decl_st2] = snd (strip_comb (concl refund_decls));
val _ = if null (free_vars decl_prog) then () else raise Fail "Program prefix is not closed";
val refund_lookup = prove (``lookup_var «refund_main» ^decl_env2 = SOME refund_main_v``,
  REWRITE_TAC [lookup_var_def] >>
  CONV_TAC (LAND_CONV ml_progLib.nsLookup_conv) >> REWRITE_TAC []);
val refund_ffi_initial = prove (``(^decl_st2).ffi = basis_ffi ext cl fs``, EVAL_TAC);
val refund_refs_initial = prove (``is_refs_basis ((^decl_st2).refs)``,
  EVAL_TAC >> REWRITE_TAC [semanticPrimitivesTheory.store_v_11,APPEND,CONS_11,basis_refs_eqs] >>
  simp_tac std_ss [] >> EVAL_TAC);
val remove_snocs = PURE_REWRITE_CONV [SNOC_APPEND] THENC
  PURE_REWRITE_CONV [GSYM APPEND_ASSOC] THENC PURE_REWRITE_CONV [APPEND];
val refund_error_program_identity = store_thm ("refund_error_program_identity", ``
  SNOC (Dlet NoLocs (Pcon NONE [])
    (App Opapp [Var (Short «refund_main»); Con NONE []])) ^decl_prog = refund_prog``,
  REWRITE_TAC [refund_prog_def] >>
  CONV_TAC (LAND_CONV remove_snocs THENC RAND_CONV remove_snocs) >> REFL_TAC);
val basis_same_eval = refund_error_basis_semantics
  |> Q.INST [‘es’ |-> ‘(init_state (basis_ffi ext cl fs)).eval_state’]
  |> SIMP_RULE std_ss [same_eval_state];
val refund_partial = MATCH_MP (MATCH_MP basis_same_eval refund_decls) refund_lookup
  |> REWRITE_RULE [refund_error_program_identity];
val (refund_input_cond,refund_partial_rest) = dest_imp (concl refund_partial);
val (refund_heap_cond,refund_sem_claim) = dest_imp refund_partial_rest;
val heap_vars = free_vars refund_heap_cond;
fun named_heap_var name = hd (List.filter (fn v => fst (dest_var v) = name) heap_vars);
val refund_h1 = named_heap_var "h1";
val refund_h2 = named_heap_var "h2";
val refund_wellformed = ``wfFS fs ∧ STD_streams fs``;
val refund_initial_heap = prove
  (mk_imp (refund_wellformed,list_mk_exists ([refund_h1,refund_h2],refund_heap_cond)),
   rpt strip_tac >> irule refund_initial_stdio >>
   metis_tac [refund_ffi_initial,refund_refs_initial]);
val refund_initialized_statement = mk_imp
  (mk_conj (refund_wellformed,refund_input_cond),
   list_mk_exists ([refund_h1,refund_h2],mk_conj (refund_heap_cond,refund_sem_claim)));
val refund_error_initialized_semantics = store_thm
  ("refund_error_initialized_semantics",refund_initialized_statement,
   metis_tac [refund_initial_heap,refund_partial]);
val _ = ml_translatorLib.reset_translation ();

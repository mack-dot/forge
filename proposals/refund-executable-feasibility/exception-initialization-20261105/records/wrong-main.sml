open preamble;
open forge_refundRejectSemanticsTheory forge_refundWholeProgTheory
     forge_refundStdioProgTheory forge_refundWireProgTheory
     basis_ffiTheory TextIOProofTheory fsFFITheory fsFFIPropsTheory
     set_sepTheory cfHeapsBaseTheory cfHeapsTheory cfStoreTheory
     evaluatePropsTheory evaluate_decTheory ml_progTheory
     semanticPrimitivesTheory;
open finite_mapTheory clFFITheory runtimeFFITheory;
val _ = Globals.max_print_depth := 1000;
val _ = new_theory "forge_refundRejectBasis";

val refund_stdio_extract_fs = store_thm ("refund_stdio_extract_fs", ``
  RTC call_FFI_rel (basis_ffi ext cl fs) st.ffi ∧
  SPLIT3 (st2heap (basis_proj1,basis_proj2) st) (h1,h2,h3) ∧
  STDIO fs' h1 ⇒
  extract_fs ext (cl,fs) st.ffi.io_events =
    SOME (fs' with numchars := fs.numchars)``,
  rpt strip_tac >>
  ‘extract_fs_with_numchars ext (cl,fs) st.ffi.io_events = SOME st.ffi.ffi_state’
    by (mp_tac (Q.SPECL [‘(cl,fs)’,‘ext’,‘basis_ffi ext cl fs’,‘st.ffi’]
          RTC_call_FFI_rel_IMP_basis_events) >>
        simp [basis_ffi_def,extract_fs_with_numchars_def]) >>
  simp [extract_fs_def] >>
  ‘∃ll. SND st.ffi.ffi_state = fs' with numchars := ll’
    suffices_by (rw [] >> rw []) >>
  fs [STDIO_def, IOFS_def,cfHeapsBaseTheory.IO_def,
      cfHeapsBaseTheory.IOx_def,SEP_CLAUSES,SEP_EXISTS_THM,fs_ffi_part_def] >>
  fs [GSYM STAR_ASSOC] >> fs [Once STAR_def] >> fs [one_STAR] >>
  qmatch_assum_abbrev_tac ‘one ffip _’ >> fs [one_def] >>
  ‘ffip ∈ st2heap (basis_proj1,basis_proj2) st’ by
    (fs [SPLIT_def,SPLIT3_def,SUBSET_DEF,DISJOINT_DEF,DELETE_DEF,
         IN_INSERT,UNION_DEF,SEP_EQ_def,EXTENSION,NOT_IN_EMPTY,
         IN_DEF,IN_UNION,IN_INTER,IN_DIFF] >> metis_tac []) >>
  fs [st2heap_def,FFI_part_NOT_IN_store2heap,Abbr ‘ffip’,ffi2heap_def] >>
  Cases_on ‘parts_ok st.ffi (basis_proj1,basis_proj2)’ >>
  fs [finite_mapTheory.FLOOKUP_DEF,MAP_MAP_o,n2w_ORD_CHR_w2n,basis_proj1_write] >>
  FIRST_X_ASSUM (ASSUME_TAC o Q.SPEC ‘«write»’) >>
  fs [basis_proj1_write,STAR_def,cond_def] >> metis_tac []);

val refund_sem_satisfies_imp = store_thm ("refund_sem_satisfies_imp", ``
  sem_satisfies s P ⇒
  (∀behavior. P behavior ⇒ Q behavior) ⇒
  sem_satisfies s Q``,
  rw [semanticsPropsTheory.sem_satisfies_def] >> res_tac);

val refund_error_basis_semantics = store_thm ("refund_error_basis_semantics", ``
  Decls env1 (init_state (basis_ffi ext cl fs) with eval_state := es) prog env2 st2 ⇒
  lookup_var «refund_main» env2 = SOME refund_main_v ⇒
  stdin_content fs = SOME text ∧
  refund_run_wire (implode text) = INL err ⇒
  SPLIT (st2heap (basis_proj1,basis_proj2) st2) (h1,h2) ∧ STDIO fs h1 ⇒
  sem_satisfies
    (semantics_dec_list (init_state (basis_ffi ext cl fs) with eval_state := es) env1
      (SNOC (Dlet NoLocs (Pcon NONE [])
        (App Opapp [Var (Short «refund_main»); Con NONE []])) prog))
    (λbehavior. ∃st3 exn.
      behavior = Terminate Success st3.ffi.io_events ∧
      (∃h3 h4. SPLIT3 (st2heap (basis_proj1,basis_proj2) st3) (h3,h2,h4) ∧
        (&Fail_exn err exn * STDIO (fastForwardFD fs 0)) h3) ∧
      RTC call_FFI_rel (basis_ffi ext cl fs) st3.ffi ∧
      extract_fs ext (cl,fs) st3.ffi.io_events = SOME (fastForwardFD fs 0))``,
  rpt strip_tac >>
  irule refund_sem_satisfies_imp >>
  qexists_tac ‘λbehavior. ∃st3 exn.
    behavior = Terminate Success st3.ffi.io_events ∧
    (∃h3 h4. SPLIT3 (st2heap (basis_proj1,basis_proj2) st3) (h3,h2,h4) ∧
      (&Fail_exn err exn * STDIO (fastForwardFD fs 0)) h3) ∧
    RTC call_FFI_rel
      (init_state (basis_ffi ext cl fs) with eval_state := es).ffi st3.ffi’ >>
  reverse conj_tac
  >- (irule refund_error_stdio_semantics >> metis_tac []) >>
  rw [] >> fs [init_state_def] >>
  ‘STDIO (fastForwardFD fs 0) h3’ by fs [cond_STAR] >>
  ‘extract_fs ext (cl,fs) st3.ffi.io_events =
     SOME ((fastForwardFD fs 0) with numchars := fs.numchars)’
    by (irule refund_stdio_extract_fs >> metis_tac []) >>
  fs [GSYM fastForwardFD_with_numchars,with_same_numchars] >> metis_tac []);

val basis_field = concl parts_ok_basis_st |> rator |> rand;
val basis_value = find_term (fn tm =>
  same_const (fst (strip_comb tm)) ``basis_ffi`` handle HOL_ERR _ => false) basis_field;
val basis_field_eq = prove (mk_eq (basis_field,basis_value), EVAL_TAC);
val refund_basis_parts_ok = save_thm ("refund_basis_parts_ok",
  REWRITE_RULE [basis_field_eq] parts_ok_basis_st);

val refund_basis_fs_projection = store_thm ("refund_basis_fs_projection", ``
  MEM n (MAP FST (SND (SND fs_ffi_part))) ⇒
  FLOOKUP (basis_proj1 (cl,fs)) n = SOME (encode fs)``,
  rw [fs_ffi_part_def] >> EVAL_TAC);

val refund_split_from_subset = store_thm ("refund_split_from_subset", ``
  (∃h_i. h_i ⊆ s ∧ P h_i) ⇒
  (∃h_i h_k. SPLIT s (h_i,h_k) ∧ P h_i)``,
  rw [] >> pop_assum (irule_at Any) >>
  qexists_tac ‘s DIFF h_i’ >>
  fs [SPLIT_def,IN_DISJOINT,EXTENSION,SUBSET_DEF] >> metis_tac []);

val refund_initial_stdio = store_thm ("refund_initial_stdio", ``
  res_st.ffi = basis_ffi ext cl fs ∧ wfFS fs ∧ STD_streams fs ∧
  is_refs_basis res_st.refs ⇒
  ∃h_i h_k.
    SPLIT (st2heap (basis_proj1,basis_proj2) res_st) (h_i,h_k) ∧ STDIO fs h_i``,
  rw [is_refs_basis_def] >>
  ‘parts_ok (basis_ffi ext cl fs) (basis_proj1,basis_proj2)’ by metis_tac [refund_basis_parts_ok] >>
  ‘∀n. MEM n (MAP FST (SND (SND fs_ffi_part))) ⇒
       FLOOKUP (basis_proj1 (cl,fs)) n = SOME (encode fs)’
    by metis_tac [refund_basis_fs_projection] >>
  irule refund_split_from_subset >>
  qexists_tac ‘{FFI_part (encode fs) (mk_ffi_next fs_ffi_part)
      (MAP FST (SND (SND fs_ffi_part))) []} ∪ {Mem 1 (W8array bs2)}’ >>
  conj_tac
  >- (fs [st2heap_def,store2heap_def,store2heap_aux_def,ffi2heap_def] >>
      fs [basis_ffi_def,basis_proj2_def,mk_proj2_def,
          cl_ffi_part_def,fs_ffi_part_def,runtime_ffi_part_def,
          APPEND,SUBSET_DEF] >>
      metis_tac []) >>
  irule (DISCH_ALL STDIO_precond) >> simp []);

(* Concrete composition after checked initial-heap-0005. *)
load "ml_translatorLib";
open boolSyntax;
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
    (App Opapp [Var (Short «refund_other»); Con NONE []])) ^decl_prog = refund_prog``,
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

val checked = [("refund_stdio_extract_fs",refund_stdio_extract_fs),
               ("refund_sem_satisfies_imp",refund_sem_satisfies_imp),
               ("refund_error_basis_semantics",refund_error_basis_semantics),
               ("refund_basis_parts_ok",refund_basis_parts_ok),
               ("refund_basis_fs_projection",refund_basis_fs_projection),
               ("refund_split_from_subset",refund_split_from_subset),
               ("refund_initial_stdio",refund_initial_stdio),
               ("refund_error_program_identity",refund_error_program_identity),
               ("refund_error_initialized_semantics",refund_error_initialized_semantics)];
val _ = List.app (fn (name,th) =>
  let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
    if null (hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
    then () else raise Fail ("Unexpected trust dependency: " ^ name);
    print ("CHECKED_THEOREM " ^ name ^ "\n" ^ Parse.thm_to_string th ^ "\n");
    print ("CHECKED_ORACLES " ^ String.concatWith "," ors ^ "\n");
    print "CHECKED_HYPOTHESES 0\nCHECKED_TAGGED_AXIOMS 0\n"
  end) checked;
val _ = export_theory ();
val _ = print "EXCEPTION_BASIS_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

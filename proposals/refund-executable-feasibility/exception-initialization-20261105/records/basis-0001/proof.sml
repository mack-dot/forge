open preamble;
open forge_refundRejectSemanticsTheory forge_refundWholeProgTheory
     forge_refundStdioProgTheory forge_refundWireProgTheory
     basis_ffiTheory TextIOProofTheory fsFFITheory fsFFIPropsTheory
     set_sepTheory cfHeapsBaseTheory cfHeapsTheory cfStoreTheory
     evaluatePropsTheory evaluate_decTheory ml_progTheory
     semanticPrimitivesTheory;
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
  conj_tac
  >- (irule refund_error_stdio_semantics >> metis_tac []) >>
  rw [] >> fs [init_state_def] >>
  ‘STDIO (fastForwardFD fs 0) h3’ by fs [cond_STAR] >>
  ‘extract_fs ext (cl,fs) st3.ffi.io_events =
     SOME ((fastForwardFD fs 0) with numchars := fs.numchars)’
    by (irule refund_stdio_extract_fs >> metis_tac []) >>
  fs [GSYM fastForwardFD_with_numchars,with_same_numchars] >> metis_tac []);

val checked = [("refund_stdio_extract_fs",refund_stdio_extract_fs),
               ("refund_sem_satisfies_imp",refund_sem_satisfies_imp),
               ("refund_error_basis_semantics",refund_error_basis_semantics)];
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

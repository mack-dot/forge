open HolKernel boolLib bossLib;
val _ = Globals.max_print_depth := 1000;
val expected = ``
  STD_streams fs ∧
  (stdin_content fs = SOME text ∧ refund_run_wire (implode text) = INL err) ⇒
  ∃h1 h2.
    (SPLIT (st2heap (basis_proj1,basis_proj2)
       (SexpProg$SexpProg_st_2 (basis_ffi ext cl fs,K (K F)))) (h1,h2) ∧
     STDIO fs h1) ∧
    sem_satisfies
      (semantics_dec_list (init_state (basis_ffi ext cl fs)) init_env refund_prog)
      (λbehavior. ∃st3 exn.
        behavior = Terminate Success st3.ffi.io_events ∧
        (∃h3 h4. SPLIT3 (st2heap (basis_proj1,basis_proj2) st3) (h3,h2,h4) ∧
          (&Fail_exn err exn * STDIO (fastForwardFD fs 0)) h3) ∧
        RTC call_FFI_rel (basis_ffi ext cl fs) st3.ffi ∧
        extract_fs ext (cl,fs) st3.ffi.io_events = SOME (fastForwardFD fs 0))``;
val _ = if aconv expected
  (concl forge_refundRejectBasisTheory.refund_error_initialized_semantics)
  then () else raise Fail "Exact initialized exception statement mismatch";
val (program_lhs,program_rhs) = dest_eq
  (concl forge_refundRejectBasisTheory.refund_error_program_identity);
val _ = if aconv program_rhs ``refund_prog`` andalso null (free_vars program_lhs)
  then () else raise Fail "Program identity does not bind exact closed refund_prog";
val (snoc,args) = strip_comb program_lhs;
val _ = if same_const snoc ``SNOC`` andalso length args = 2 andalso
  aconv (hd args) ``Dlet NoLocs (Pcon NONE [])
    (App Opapp [Var (Short «refund_main»); Con NONE []])``
  then () else raise Fail "Exact appended entry declaration mismatch";

val checked = [("refund_stdio_extract_fs",forge_refundRejectBasisTheory.refund_stdio_extract_fs),
("refund_sem_satisfies_imp",forge_refundRejectBasisTheory.refund_sem_satisfies_imp),
("refund_error_basis_semantics",forge_refundRejectBasisTheory.refund_error_basis_semantics),
("refund_basis_parts_ok",forge_refundRejectBasisTheory.refund_basis_parts_ok),
("refund_basis_fs_projection",forge_refundRejectBasisTheory.refund_basis_fs_projection),
("refund_split_from_subset",forge_refundRejectBasisTheory.refund_split_from_subset),
("refund_initial_stdio",forge_refundRejectBasisTheory.refund_initial_stdio),
("refund_error_program_identity",forge_refundRejectBasisTheory.refund_error_program_identity),
("refund_error_initialized_semantics",forge_refundRejectBasisTheory.refund_error_initialized_semantics)];
val _ = List.app (fn (name,th) =>
 let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
  then () else raise Fail ("Unexpected dependency: " ^ name);
  print ("IMPORTED_THEOREM " ^ name ^ "\n");
  if name = "refund_error_program_identity" then print "EXACT_CLOSED_PROGRAM_IDENTITY_CHECKED\n"
  else print (Parse.thm_to_string th ^ "\n");
  print ("IMPORTED_ORACLES " ^ String.concatWith "," ors ^ "\n");
  print "IMPORTED_HYPOTHESES 0\nIMPORTED_TAGGED_AXIOMS 0\n"
 end) checked;
val closure = "forge_refundRejectBasis" :: Theory.ancestry "forge_refundRejectBasis";
val _ = List.app (fn n => print ("CLOSURE_NODE " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n) ^ "\n")) closure;
val _ = List.app (fn n => List.app (fn (a,_) => print ("CLOSURE_AXIOM " ^ n ^ "." ^ a ^ "\n")) (DB.axioms n)) closure;
val _ = print "EXACT_EXPECTED_STATEMENT true\nFINAL_IMPORT_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

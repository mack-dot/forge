val _ = load "cfLib";
open preamble cfLib cfTheory cfHeapsBaseTheory set_sepTheory
  TextIOProofTheory TextIOProgTheory MarshallingTheory ml_translatorTheory
  fsFFITheory fsFFIPropsTheory forge_refundGenericReadErrorTheory forge_refundFfiOracleTheory forge_refundFfiInstanceTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val expected_instance = ``
  FD fd fdv /\ NUM n nv /\ n < 256**2 /\ MAX n 2048 <= LENGTH rest /\
  MEM «read» ns /\ ~MEM «» ns /\ read fd fs n = NONE ==>
  app (p:'ffi ffi_proj) TextIO_read_v [fdv;nv]
    (W8ARRAY iobuff_loc (h1::h2::h3::h4::rest) *
     one (FFI_part (encode fs) (mk_ffi_next fs_ffi_part) ns events))
    (POSTe e.
      &InvalidFD_exn e * W8ARRAY iobuff_loc (1w::n2w n::h3::h4::rest) *
      one (FFI_part (encode fs) (mk_ffi_next fs_ffi_part) ns
        (events ++ [IO_event (ExtCall «read») (n2w8 fd)
          (ZIP (n2w2 n ++ h3::h4::rest,1w::n2w n::h3::h4::rest))])))``;
val expected_oracle = ``
  fd < 256 ** 8 /\ n < 2 ** (2 * 8) /\ n <= LENGTH rest /\ read fd fs n = NONE ==>
  mk_ffi_next fs_ffi_part «read» (n2w8 fd) (n2w2 n ++ h3::h4::rest) (encode fs) =
  SOME (FFIreturn (1w::n2w n::h3::h4::rest) (encode fs))``;
val th_i = forge_refundFfiInstanceTheory.read_error_basis_instance;
val th_o = forge_refundFfiOracleTheory.basis_read_error_oracle;
val _ = if aconv expected_instance (concl th_i) then () else raise Fail "Exact statement mismatch: read_error_basis_instance";
val _ = if aconv expected_oracle (concl th_o) then () else raise Fail "Exact statement mismatch: basis_read_error_oracle";
val _ = tags "read_error_basis_instance" th_i;
val _ = tags "basis_read_error_oracle" th_o;
val _ = if length (DB.theorems "forge_refundFfiInstance") = 1 andalso length (DB.theorems "forge_refundFfiOracle") = 1
  then () else raise Fail "Unexpected theorem count";
val _ = pr ("IMPORTED_THEOREM read_error_basis_instance\n" ^ thm_to_string th_i);
val _ = pr ("IMPORTED_THEOREM basis_read_error_oracle\n" ^ thm_to_string th_o);
val _ = pr "IMPORTED_ORACLES DISK_THM\nIMPORTED_HYPOTHESES 0\nIMPORTED_TAGGED_AXIOMS 0";
val closure = Lib.mk_set ("forge_refundFfiInstance" :: Theory.ancestry "forge_refundFfiInstance");
val _ = List.app (fn n => pr ("CLOSURE_NODE " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n))) closure;
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "AFTER_POSITIVE_AUDIT";
val _ = new_theory "forge_refundFfiControl";
(* The unchanged tactic must prove the unchanged statement in this context first. *)
val _ = prove (``
  fd < 256 ** 8 /\ n < 2 ** (2 * 8) /\ n <= LENGTH rest /\ read fd fs n = NONE ==>
  mk_ffi_next fs_ffi_part «read» (n2w8 fd) (n2w2 n ++ h3::h4::rest) (encode fs) =
  SOME (FFIreturn (1w::n2w n::h3::h4::rest) (encode fs))``,
  strip_tac >> imp_res_tac w22n_n2w2 >>
  simp [fs_ffi_part_def, mk_ffi_next_def, ffi_read_def, fsFFITheory.decode_encode,
        w82n_n2w8, LENGTH_n2w8, n2w2_def, LUPDATE_def] >>
  fs [n2w2_def, w22n_def, LUPDATE_def, w82n_n2w8, LENGTH_n2w8]);
val _ = pr "CONTROL_HARNESS_PROVES_ORIGINAL";
(* Altered claim: the premise read fd fs n = NONE is removed. *)
val _ = prove (``
  fd < 256 ** 8 /\ n < 2 ** (2 * 8) /\ n <= LENGTH rest ==>
  mk_ffi_next fs_ffi_part «read» (n2w8 fd) (n2w2 n ++ h3::h4::rest) (encode fs) =
  SOME (FFIreturn (1w::n2w n::h3::h4::rest) (encode fs))``,
  strip_tac >> imp_res_tac w22n_n2w2 >>
  simp [fs_ffi_part_def, mk_ffi_next_def, ffi_read_def, fsFFITheory.decode_encode,
        w82n_n2w8, LENGTH_n2w8, n2w2_def, LUPDATE_def] >>
  fs [n2w2_def, w22n_def, LUPDATE_def, w82n_n2w8, LENGTH_n2w8]);
val _ = pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val _ = OS.Process.exit OS.Process.success;

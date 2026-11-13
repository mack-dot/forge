open preamble cfTheory cfHeapsBaseTheory set_sepTheory TextIOProofTheory TextIOProgTheory MarshallingTheory ml_translatorTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
val expected = ``
  FD fd fdv ∧ NUM n nv ∧ n < 256**2 ∧ MAX n 2048 <= LENGTH rest ∧
  MEM «read» ns ∧ ¬MEM «» ns ∧
  u «read» (n2w8 fd) (n2w2 n ++ h3::h4::rest) s =
    SOME (FFIreturn (1w::n2w n::h3::h4::rest) s') ⇒
  app (p:'ffi ffi_proj) TextIO_read_v [fdv;nv]
    (W8ARRAY iobuff_loc (h1::h2::h3::h4::rest) *
     one (FFI_part s u ns events))
    (POSTe e.
      &InvalidFD_exn e * W8ARRAY iobuff_loc (1w::n2w n::h3::h4::rest) *
      one (FFI_part s' u ns
        events))``;
val th = forge_refundGenericReadErrorTheory.read_error_generic;
val _ = if aconv expected (concl th) then () else raise Fail "Exact generic read statement mismatch";
val (ors,axs) = Tag.dest_tag (Thm.tag th);
val _ = if null (hyp th) andalso null axs andalso List.all (fn s => s="DISK_THM") ors
  then () else raise Fail "Unexpected generic read theorem dependency";
val _ = print ("IMPORTED_THEOREM read_error_generic\n" ^ thm_to_string th ^ "\n");
val _ = print ("IMPORTED_ORACLES " ^ String.concatWith "," ors ^ "\n");
val _ = print "IMPORTED_HYPOTHESES 0\nIMPORTED_TAGGED_AXIOMS 0\n";
val _ = if length (DB.theorems "forge_refundGenericReadError")=1 then () else raise Fail "Unexpected theorem count";
val closure = "forge_refundGenericReadError" :: Theory.ancestry "forge_refundGenericReadError";
val _ = List.app (fn n => print ("CLOSURE_NODE " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n) ^ "\n")) closure;
val _ = List.app (fn n => List.app (fn (a,_) => print ("CLOSURE_AXIOM " ^ n ^ "." ^ a ^ "\n")) (DB.axioms n)) closure;
val _ = print "GENERIC_IMPORT_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

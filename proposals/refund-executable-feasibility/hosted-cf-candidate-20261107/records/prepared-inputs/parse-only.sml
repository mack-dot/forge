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
        (events ++ [IO_event (ExtCall «read») (n2w8 fd)
          (ZIP (n2w2 n ++ h3::h4::rest,1w::n2w n::h3::h4::rest))])))``;
val _ = print ("CANDIDATE_TERM_PARSED\n" ^ term_to_string expected ^ "\n");
val _ = print "NO_THEOREM_ATTEMPTED\n";

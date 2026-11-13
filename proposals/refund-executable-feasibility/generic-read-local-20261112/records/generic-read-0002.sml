val _ = load "cfLib";
open preamble cfLib cfTheory cfHeapsBaseTheory set_sepTheory
  TextIOProofTheory TextIOProgTheory MarshallingTheory ml_translatorTheory;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_READ_OUT"));
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
val _ = new_theory "forge_refundGenericReadError";
fun report_goal label (asms,g) ctxt =
  (print ("RESIDUAL " ^ label ^ "\n");
   List.app (fn t => print ("ASSUMPTION " ^ term_to_string t ^ "\n")) asms;
   print ("GOAL " ^ term_to_string g ^ "\n");
   ALL_TAC (asms,g) ctxt);

val read_error_generic = store_thm ("read_error_generic", ``
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
          (ZIP (n2w2 n ++ h3::h4::rest,1w::n2w n::h3::h4::rest))])))``,
  rpt strip_tac >>
  xcf_with_def TextIO_read_v_def >>
  xlet_auto >- xsimpl >>
  simp [insert_atI_def,n2w2_def] >>
  xlet `POSTv v.
    W8ARRAY iobuff_loc (1w::n2w n::h3::h4::rest) *
    one (FFI_part s' u ns
      (events ++ [IO_event (ExtCall «read») (n2w8 fd)
        (ZIP (n2w2 n ++ h3::h4::rest,1w::n2w n::h3::h4::rest))]))`
  >- (xffi >> report_goal "generic-ffi" >> xsimpl >>
      CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
      map_every qexists_tac [`events`,`ns`,`u`,`s`] >> xsimpl >>
      qexists_tac `n2w8 fd` >> fs [FD_def,STRING_TYPE_def,n2w2_def] >> xsimpl) >>
  rpt (xlet_auto >- xsimpl) >> xif >> instantiate >>
  xlet_auto >- (xcon >> xsimpl >> instantiate >> xsimpl) >>
  xraise >> fs [InvalidFD_exn_def,n2w2_def] >> xsimpl);
val (ors,axs) = Tag.dest_tag (Thm.tag read_error_generic);
val _ = if null (hyp read_error_generic) andalso null axs andalso
  List.all (fn s => s="DISK_THM") ors then () else raise Fail "Unexpected assumptions";
val _ = print ("CHECKED read_error_generic\n" ^ thm_to_string read_error_generic ^ "\n");
val _ = export_theory ();
val _ = print "READ_EVENT_GAP_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

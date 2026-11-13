(* Instance of read_error_generic for the published basis oracle.  The
   statement is parsed as one quotation; the tactic is the tactic of U351. *)
val _ = load "cfLib";
open preamble cfLib cfTheory cfHeapsBaseTheory set_sepTheory
  TextIOProofTheory TextIOProgTheory MarshallingTheory ml_translatorTheory
  fsFFITheory fsFFIPropsTheory forge_refundGenericReadErrorTheory forge_refundFfiOracleTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_READ_OUT"));
val _ = new_theory "forge_refundFfiInstance";
val inst = Q.INST [`u` |-> `mk_ffi_next fs_ffi_part`, `s` |-> `encode fs`, `s'` |-> `encode fs`]
             forge_refundGenericReadErrorTheory.read_error_generic;
val read_error_basis_instance = store_thm ("read_error_basis_instance", ``
  FD fd fdv /\ NUM n nv /\ n < 256**2 /\ MAX n 2048 <= LENGTH rest /\
  MEM «read» ns /\ ~MEM «» ns /\ read fd fs n = NONE ==>
  app (p:'ffi ffi_proj) TextIO_read_v [fdv;nv]
    (W8ARRAY iobuff_loc (h1::h2::h3::h4::rest) *
     one (FFI_part (encode fs) (mk_ffi_next fs_ffi_part) ns events))
    (POSTe e.
      &InvalidFD_exn e * W8ARRAY iobuff_loc (1w::n2w n::h3::h4::rest) *
      one (FFI_part (encode fs) (mk_ffi_next fs_ffi_part) ns
        (events ++ [IO_event (ExtCall «read») (n2w8 fd)
          (ZIP (n2w2 n ++ h3::h4::rest,1w::n2w n::h3::h4::rest))])))``,
  strip_tac >> match_mp_tac inst >> rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >>
  match_mp_tac basis_read_error_oracle >> fs [FD_def]);
val _ = tags "read_error_basis_instance" read_error_basis_instance;
val _ = pr ("CHECKED read_error_basis_instance\n" ^ thm_to_string read_error_basis_instance);
val _ = export_theory ();
val _ = pr "FFI_INSTANCE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

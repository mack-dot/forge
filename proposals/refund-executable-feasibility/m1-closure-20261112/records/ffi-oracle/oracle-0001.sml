(* The published basis file-system oracle satisfies the oracle equation of
   read_error_generic when the descriptor cannot be read. *)
val _ = load "cfLib";
open preamble cfLib cfTheory cfHeapsBaseTheory set_sepTheory
  TextIOProofTheory TextIOProgTheory MarshallingTheory ml_translatorTheory
  fsFFITheory fsFFIPropsTheory forge_refundGenericReadErrorTheory;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_READ_OUT"));
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
val _ = new_theory "forge_refundFfiOracle";
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val basis_read_error_oracle = store_thm ("basis_read_error_oracle", ``
  fd < 256 ** 8 /\ n < 2 ** (2 * 8) /\ n <= LENGTH rest /\ read fd fs n = NONE ==>
  mk_ffi_next fs_ffi_part «read» (n2w8 fd) (n2w2 n ++ h3::h4::rest) (encode fs) =
  SOME (FFIreturn (1w::n2w n::h3::h4::rest) (encode fs))``,
  strip_tac >> imp_res_tac w22n_n2w2 >>
  simp [fs_ffi_part_def, mk_ffi_next_def, ffi_read_def, fsFFITheory.decode_encode,
        w82n_n2w8, LENGTH_n2w8, n2w2_def, LUPDATE_def] >>
  fs [n2w2_def, w22n_def, LUPDATE_def, w82n_n2w8, LENGTH_n2w8]);
val _ = tags "basis_read_error_oracle" basis_read_error_oracle;
val _ = pr ("CHECKED basis_read_error_oracle\n" ^ thm_to_string basis_read_error_oracle);
(* Instance of read_error_generic for the published oracle.  It is stored only
   when the unchanged tactic below proves it; the outcome is printed. *)
val inst = Q.INST [`u` |-> `mk_ffi_next fs_ffi_part`, `s` |-> `encode fs`, `s'` |-> `encode fs`]
             forge_refundGenericReadErrorTheory.read_error_generic;
val instance_goal = mk_imp (``
  FD fd fdv /\ NUM n nv /\ n < 256**2 /\ MAX n 2048 <= LENGTH rest /\
  MEM «read» ns /\ ~MEM «» ns /\ read fd fs n = NONE``, snd (dest_imp (concl inst)));
val _ = (let val th = prove (instance_goal,
            strip_tac >> match_mp_tac inst >> rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >>
            match_mp_tac basis_read_error_oracle >> fs [FD_def])
             val _ = tags "read_error_basis_instance" th
             val th' = save_thm ("read_error_basis_instance", th)
         in pr ("INSTANCE_PROVED\nCHECKED read_error_basis_instance\n" ^ thm_to_string th') end)
        handle ex => pr ("INSTANCE_NOT_PROVED " ^ exn_to_string ex);
val _ = pr ("THEOREM_COUNT " ^ Int.toString (length (DB.theorems "forge_refundFfiOracle")));
val _ = export_theory ();
val _ = pr "FFI_ORACLE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

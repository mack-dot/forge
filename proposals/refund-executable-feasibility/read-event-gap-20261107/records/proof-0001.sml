open preamble fsFFITheory fsFFIPropsTheory basis_ffiTheory
  forge_refundStdinDomainTheory;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_READ_OUT"));
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
val _ = new_theory "forge_refundReadEventGap";

val basis_read_ignores_ext = store_thm ("basis_read_ignores_ext", ``
  basis_ffi_oracle ext (ExtCall «read») st conf bytes =
  basis_ffi_oracle ext' (ExtCall «read») st conf bytes``,
  match_mp_tac basis_ffi_oracle_is_basis_ffi_name >>
  simp [is_basis_ffi_name_def]);

val basis_stdin_read_total = store_thm ("basis_stdin_read_total", ``
  wfFS fs ∧ STD_streams fs ∧ LENGTH conf = 8 ∧ w82n conf = 0 ∧
  LENGTH read_tail ≥ w22n [n1;n0] ⇒
  ∃bytes' fs'.
    basis_ffi_oracle ext (ExtCall «read») (cl,fs) conf
      (n1::n0::pad1::pad2::read_tail) = Oracle_return (cl,fs') bytes' ∧
    HD bytes' = 0w``,
  rpt strip_tac >>
  `∃bytes' fs'. ffi_read conf (n1::n0::pad1::pad2::read_tail) fs =
     SOME (FFIreturn bytes' fs') ∧ HD bytes' = 0w`
    by metis_tac [stdin_ffi_read_total] >>
  simp [basis_ffi_oracle_def] >> metis_tac []);

val stdin_error_event_rejected = store_thm ("stdin_error_event_rejected", ``
  wfFS fs ∧ STD_streams fs ∧ LENGTH conf = 8 ∧ w82n conf = 0 ∧
  LENGTH read_tail ≥ w22n [n1;n0] ∧
  MAP FST pairs = n1::n0::pad1::pad2::read_tail ∧
  HD (MAP SND pairs) = 1w ⇒
  extract_fs_with_numchars ext (cl,fs)
    (IO_event (ExtCall «read») conf pairs :: suffix) = NONE``,
  rpt strip_tac >>
  `∃bytes' fs'. ffi_read conf (n1::n0::pad1::pad2::read_tail) fs =
     SOME (FFIreturn bytes' fs') ∧ HD bytes' = 0w`
    by metis_tac [stdin_ffi_read_total] >>
  `bytes' ≠ MAP SND pairs` by (CCONTR_TAC >> fs []) >>
  simp [Once extract_fs_with_numchars_def,fs_ffi_part_def,ALOOKUP_def]);

val stdin_error_complete_trace_rejected = store_thm
  ("stdin_error_complete_trace_rejected", ``
  extract_fs_with_numchars ext (cl0,fs0) prefix = SOME (cl,fs) ∧
  wfFS fs ∧ STD_streams fs ∧ LENGTH conf = 8 ∧ w82n conf = 0 ∧
  LENGTH read_tail ≥ w22n [n1;n0] ∧
  MAP FST pairs = n1::n0::pad1::pad2::read_tail ∧
  HD (MAP SND pairs) = 1w ⇒
  extract_fs ext (cl0,fs0)
    (prefix ++ IO_event (ExtCall «read») conf pairs :: suffix) = NONE``,
  rpt strip_tac >>
  `extract_fs_with_numchars ext (cl,fs)
     (IO_event (ExtCall «read») conf pairs :: suffix) = NONE`
    by metis_tac [stdin_error_event_rejected] >>
  simp [extract_fs_def,extract_fs_with_numchars_APPEND]);

val checked = [("basis_read_ignores_ext",basis_read_ignores_ext),
  ("basis_stdin_read_total",basis_stdin_read_total),
  ("stdin_error_event_rejected",stdin_error_event_rejected),
  ("stdin_error_complete_trace_rejected",stdin_error_complete_trace_rejected)];
val _ = List.app (fn (name,th) =>
  let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
    if null (hyp th) andalso null axs andalso
      List.all (fn s => s="DISK_THM") ors then ()
    else raise Fail ("Unexpected assumptions: " ^ name);
    print ("CHECKED " ^ name ^ "\n" ^ thm_to_string th ^ "\n")
  end) checked;
val _ = export_theory ();
val _ = print "READ_EVENT_GAP_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

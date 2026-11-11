open preamble fsFFITheory fsFFIPropsTheory forge_refundReadBoundaryTheory;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_READ_OUT"));
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
val _ = new_theory "forge_refundStdinDomain";

val wf_read_inputs = store_thm ("wf_read_inputs", ``
  wfFS fs ∧ ALOOKUP fs.infds fd = SOME (ino,ReadMode,off) ⇒
  ∃content quota. ALOOKUP fs.inode_tbl ino = SOME content ∧
    LHD fs.numchars = SOME quota``,
  rw [wfFS_def,liveFS_def,live_numchars_def] >>
  `MEM fd (MAP FST fs.infds)` by metis_tac [ALOOKUP_NONE] >>
  `MEM ino (MAP FST fs.inode_tbl)` by metis_tac [] >>
  `∃content. ALOOKUP fs.inode_tbl ino = SOME content`
    by metis_tac [ALOOKUP_NONE, optionTheory.option_CASES] >>
  Cases_on `fs.numchars` >> fs [] >> metis_tac []);

val stdin_read_inputs = store_thm ("stdin_read_inputs", ``
  wfFS fs ∧ STD_streams fs ⇒
  ∃off content quota.
    ALOOKUP fs.infds 0 = SOME (UStream «stdin»,ReadMode,off) ∧
    ALOOKUP fs.inode_tbl (UStream «stdin») = SOME content ∧
    LHD fs.numchars = SOME quota``,
  rw [STD_streams_def] >> metis_tac [wf_read_inputs]);

val stdin_ffi_read_status_zero = store_thm ("stdin_ffi_read_status_zero", ``
  wfFS fs ∧ STD_streams fs ∧ LENGTH conf = 8 ∧ w82n conf = 0 ∧
  LENGTH read_tail ≥ w22n [n1;n0] ∧
  ffi_read conf (n1::n0::pad1::pad2::read_tail) fs =
    SOME (FFIreturn bytes' fs') ⇒ HD bytes' = 0w``,
  metis_tac [stdin_read_inputs,ffi_read_ready_status]);

val checked = [("wf_read_inputs",wf_read_inputs),
  ("stdin_read_inputs",stdin_read_inputs),
  ("stdin_ffi_read_status_zero",stdin_ffi_read_status_zero)];
val _ = List.app (fn (name,th) =>
  let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
    if null (hyp th) andalso null axs andalso
      List.all (fn s => s = "DISK_THM") ors then ()
    else raise Fail ("Unexpected assumptions: " ^ name);
    print ("CHECKED " ^ name ^ "\n" ^ Parse.thm_to_string th ^ "\n")
  end) checked;
val _ = export_theory ();
val _ = print "STDIN_DOMAIN_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

open preamble fsFFITheory fsFFIPropsTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
val checks = [
 ("wf_read_inputs", ``wfFS fs ∧
    ALOOKUP fs.infds fd = SOME (ino,ReadMode,off) ⇒
    ∃content quota. ALOOKUP fs.inode_tbl ino = SOME content ∧
      LHD fs.numchars = SOME quota``,
    forge_refundStdinDomainTheory.wf_read_inputs),
 ("stdin_read_inputs", ``wfFS fs ∧ STD_streams fs ⇒
    ∃off content quota.
      ALOOKUP fs.infds 0 = SOME (UStream «stdin»,ReadMode,off) ∧
      ALOOKUP fs.inode_tbl (UStream «stdin») = SOME content ∧
      LHD fs.numchars = SOME quota``,
    forge_refundStdinDomainTheory.stdin_read_inputs),
 ("stdin_ffi_read_status_zero", ``wfFS fs ∧ STD_streams fs ∧
    LENGTH conf = 8 ∧ LENGTH read_tail ≥ w22n [n1;n0] ∧
    ffi_read conf (n1::n0::pad1::pad2::read_tail) fs =
      SOME (FFIreturn bytes' fs') ⇒ HD bytes' = 0w``,
    forge_refundStdinDomainTheory.stdin_ffi_read_status_zero),
 ("stdin_ffi_read_total", ``wfFS fs ∧ STD_streams fs ∧
    LENGTH conf = 8 ∧ w82n conf = 0 ∧ LENGTH read_tail ≥ w22n [n1;n0] ⇒
    ∃bytes' fs'. ffi_read conf (n1::n0::pad1::pad2::read_tail) fs =
      SOME (FFIreturn bytes' fs') ∧ HD bytes' = 0w``,
    forge_refundStdinDomainTheory.stdin_ffi_read_total)];
fun check (name,expected,th) =
  let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
    if aconv expected (concl th) then ()
    else raise Fail ("Exact statement mismatch: " ^ name);
    if null (hyp th) andalso null axs andalso List.all (fn s => s="DISK_THM") ors
    then () else raise Fail ("Unexpected dependency: " ^ name);
    print ("IMPORTED_THEOREM " ^ name ^ "\n" ^ thm_to_string th ^ "\n");
    print ("IMPORTED_ORACLES " ^ String.concatWith "," ors ^ "\n");
    print "IMPORTED_HYPOTHESES 0\nIMPORTED_TAGGED_AXIOMS 0\n"
  end;
val _ = List.app check checks;
val _ = if length (DB.theorems "forge_refundStdinDomain")=4 then ()
  else raise Fail "Unexpected theorem count";
val closure = "forge_refundStdinDomain" :: Theory.ancestry "forge_refundStdinDomain";
val _ = List.app (fn name => print ("CLOSURE_NODE " ^ name ^ ":" ^
  String.concatWith "," (Theory.parents name) ^ "\n")) closure;
val _ = List.app (fn name => List.app (fn (a,_) =>
  print ("CLOSURE_AXIOM " ^ name ^ "." ^ a ^ "\n")) (DB.axioms name)) closure;
val _ = print "EXACT_EXPECTED_STATEMENTS true\nSTDIN_DOMAIN_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

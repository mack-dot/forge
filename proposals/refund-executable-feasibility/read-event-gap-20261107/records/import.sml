open preamble fsFFITheory fsFFIPropsTheory basis_ffiTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
val checks = [
 ("basis_read_ignores_ext", ``
    basis_ffi_oracle ext (ExtCall «read») st conf bytes =
    basis_ffi_oracle ext' (ExtCall «read») st conf bytes``,
    forge_refundReadEventGapTheory.basis_read_ignores_ext),
 ("basis_stdin_read_total", ``
    wfFS fs ∧ STD_streams fs ∧ LENGTH conf = 8 ∧ w82n conf = 0 ∧
    LENGTH read_tail ≥ w22n [n1;n0] ⇒
    ∃bytes' fs'. basis_ffi_oracle ext (ExtCall «read») (cl,fs) conf
      (n1::n0::pad1::pad2::read_tail) = Oracle_return (cl,fs') bytes' ∧
      HD bytes' = 0w``,
    forge_refundReadEventGapTheory.basis_stdin_read_total),
 ("stdin_error_event_rejected", ``
    wfFS fs ∧ STD_streams fs ∧ LENGTH conf = 8 ∧ w82n conf = 0 ∧
    LENGTH read_tail ≥ w22n [n1;n0] ∧
    MAP FST pairs = n1::n0::pad1::pad2::read_tail ∧
    HD (MAP SND pairs) = 1w ⇒
    extract_fs_with_numchars ext (cl,fs)
      (IO_event (ExtCall «read») conf pairs :: suffix) = NONE``,
    forge_refundReadEventGapTheory.stdin_error_event_rejected),
 ("stdin_error_complete_trace_rejected", ``
    extract_fs_with_numchars ext (cl0,fs0) prefix = SOME (cl,fs) ∧
    wfFS fs ∧ STD_streams fs ∧ LENGTH conf = 8 ∧ w82n conf = 0 ∧
    LENGTH read_tail ≥ w22n [n1;n0] ∧
    MAP FST pairs = n1::n0::pad1::pad2::read_tail ∧
    HD (MAP SND pairs) = 1w ⇒
    extract_fs ext (cl0,fs0)
      (prefix ++ IO_event (ExtCall «read») conf pairs :: suffix) = NONE``,
    forge_refundReadEventGapTheory.stdin_error_complete_trace_rejected)];
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
val _ = if length (DB.theorems "forge_refundReadEventGap")=4 then ()
  else raise Fail "Unexpected theorem count";
val closure = "forge_refundReadEventGap" :: Theory.ancestry "forge_refundReadEventGap";
val _ = List.app (fn name => print ("CLOSURE_NODE " ^ name ^ ":" ^
  String.concatWith "," (Theory.parents name) ^ "\n")) closure;
val _ = List.app (fn name => List.app (fn (a,_) =>
  print ("CLOSURE_AXIOM " ^ name ^ "." ^ a ^ "\n")) (DB.axioms name)) closure;
val _ = print "EXACT_EXPECTED_STATEMENTS true\nREAD_EVENT_GAP_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

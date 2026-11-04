(* Whole-program source semantics through the published basis bridge.
   This is not a native executable theorem. *)
Theory forge_refundWholeProg
Ancestors
  forge_refundStdioProg forge_refundWireProg basis_ffi
Libs
  preamble basis

val _ = translation_extends "forge_refundStdioProg";
val st = get_ml_prog_state ();

Theorem refund_whole_prog_spec:
  stdin_content fs = SOME text ∧
  refund_run_wire (implode text) = INR output ⇒
  whole_prog_spec refund_main_v cl fs NONE
    ((=) (add_stdout (fastForwardFD fs 0) output))
Proof
  disch_then assume_tac >> simp [whole_prog_spec_def] >>
  qexists_tac ‘add_stdout (fastForwardFD fs 0) output’ >>
  simp [GSYM add_stdo_with_numchars,GSYM fastForwardFD_with_numchars,with_same_numchars] >>
  match_mp_tac (MP_CANON (MATCH_MP app_wgframe (UNDISCH refund_main_valid))) >>
  xsimpl
QED

Theorem refund_request_whole_prog_spec:
  stdin_content fs = SOME (explode (sexp_to_string
    (refund_request charge request original remaining enabled opened candidate amount reason))) ⇒
  whole_prog_spec refund_main_v cl fs NONE
    ((=) (add_stdout (fastForwardFD fs 0)
      (refund_render_fields
        (refund_fields charge request original remaining enabled opened candidate amount reason))))
Proof
  strip_tac >> irule refund_whole_prog_spec >>
  qexists_tac ‘explode (sexp_to_string
    (refund_request charge request original remaining enabled opened candidate amount reason))’ >>
  simp [refund_run_wire_valid]
QED

Theorem refund_semantics =
  prove_sem_thm "refund_dispatch" "refund_prog" refund_request_whole_prog_spec;

val _ = Globals.max_print_depth := 1000;
val _ = List.app (fn (name,th) =>
  let val (oracles,axioms) = Tag.dest_tag (Thm.tag th) in
    print ("FORGE_THEOREM " ^ name ^ "\n");
    print ("FORGE_ORACLES " ^ String.concatWith "," oracles ^ "\n");
    print ("FORGE_AXIOMS " ^ String.concatWith "," axioms ^ "\n");
    print ("FORGE_HYPOTHESES " ^ Int.toString (length (hyp th)) ^ "\n");
    print ("FORGE_STATEMENT " ^ Parse.thm_to_string th ^ "\n")
  end) [("refund_whole_prog_spec",refund_whole_prog_spec),
        ("refund_request_whole_prog_spec",refund_request_whole_prog_spec),
        ("refund_semantics",refund_semantics)];

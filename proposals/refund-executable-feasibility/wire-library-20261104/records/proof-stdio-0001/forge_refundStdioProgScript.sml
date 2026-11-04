(* Compose the exact proposed dispatcher with published modeled I/O rules.
   Physical stdin/stdout and native execution remain separate obligations. *)
Theory forge_refundStdioProg
Ancestors
  forge_refundWireProg TextIOProof mlbasicsProg
Libs
  preamble ml_translatorLib ml_progLib basisFunctionsLib cfLib

val _ = translation_extends "forge_refundWireProg";

Quote add_cakeml:
  fun refund_main u =
    case TextIO.inputAllFrom NONE of
      NONE => raise Fail "refund: stdin unavailable"
    | SOME wire => TextIO.print (refund_dispatch wire);
End

val st = get_ml_prog_state ();

Theorem refund_main_valid:
  stdin_content fs = SOME text ∧
  refund_run_wire (implode text) = INR output ⇒
  app (p:'ffi ffi_proj) refund_main_v [Conv NONE []] (STDIO fs)
    (POSTv v. &UNIT_TYPE () v * STDIO (add_stdout (fastForwardFD fs 0) output))
Proof
  rw [] >> xcf "refund_main" st >>
  xlet ‘POSTv v. &OPTION_TYPE FILENAME NONE v * STDIO fs’
  >- (xcon >> xsimpl >> simp [std_preludeTheory.OPTION_TYPE_def]) >>
  xlet ‘POSTv v. &OPTION_TYPE STRING_TYPE (SOME (implode text)) v *
                STDIO (fastForwardFD fs 0)’
  >- (xapp_spec inputAllFrom_NONE_spec >> xsimpl) >>
  gvs [std_preludeTheory.OPTION_TYPE_def] >> xmatch >>
  xlet ‘POSTv v. &STRING_TYPE output v * STDIO (fastForwardFD fs 0)’
  >- (xapp_spec refund_dispatch_valid >> xsimpl) >>
  xapp_spec print_spec >> xsimpl
QED

Theorem refund_main_error:
  stdin_content fs = SOME text ∧
  refund_run_wire (implode text) = INL err ⇒
  app (p:'ffi ffi_proj) refund_main_v [Conv NONE []] (STDIO fs)
    (POSTe exn. &Fail_exn err exn * STDIO (fastForwardFD fs 0))
Proof
  rw [] >> xcf "refund_main" st >>
  xlet ‘POSTv v. &OPTION_TYPE FILENAME NONE v * STDIO fs’
  >- (xcon >> xsimpl >> simp [std_preludeTheory.OPTION_TYPE_def]) >>
  xlet ‘POSTv v. &OPTION_TYPE STRING_TYPE (SOME (implode text)) v *
                STDIO (fastForwardFD fs 0)’
  >- (xapp_spec inputAllFrom_NONE_spec >> xsimpl) >>
  gvs [std_preludeTheory.OPTION_TYPE_def] >> xmatch >>
  xlet ‘POSTe exn. &Fail_exn err exn * STDIO (fastForwardFD fs 0)’
  >- (xapp_spec refund_dispatch_error >> xsimpl) >> xsimpl
QED

val _ = Globals.max_print_depth := 1000;
val _ = List.app (fn (name,th) =>
  let val (oracles,axioms) = Tag.dest_tag (Thm.tag th) in
    print ("FORGE_THEOREM " ^ name ^ "\n");
    print ("FORGE_ORACLES " ^ String.concatWith "," oracles ^ "\n");
    print ("FORGE_AXIOMS " ^ String.concatWith "," axioms ^ "\n");
    print ("FORGE_HYPOTHESES " ^ Int.toString (length (hyp th)) ^ "\n");
    print ("FORGE_STATEMENT " ^ Parse.thm_to_string th ^ "\n")
  end) [("refund_main_valid",refund_main_valid),
        ("refund_main_error",refund_main_error)];

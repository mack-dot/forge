(* Strict wire/result composition through published parser, serializer and
   translator. Proposed code only; no native or physical I/O claim. *)
Theory forge_refundWireProg
Ancestors
  forge_refund forge_refund_io forge_refundCertifiedProg SexpProg
  mlsexp result_monad sexp_to_dafny mlbasicsProg
Libs
  preamble ml_translatorLib ml_progLib basisFunctionsLib cfLib

Definition refund_render_fields_def:
  refund_render_fields fields =
    let (ok,a,r,c,q,n) = fields in
    sexp_to_string (refund_response ok a r c q n)
End

Definition refund_run_wire_def:
  refund_run_wire wire =
    case refund_decode_wire wire of
      INL err => INL err
    | INR (charge,request,original,remaining,enabled,opened,candidate,amount,reason) =>
        INR (refund_render_fields
          (refund_fields charge request original remaining enabled opened candidate amount reason))
End

Theorem refund_run_wire_valid:
  refund_run_wire (sexp_to_string
    (refund_request charge request original remaining enabled opened candidate amount reason)) =
  INR (refund_render_fields
    (refund_fields charge request original remaining enabled opened candidate amount reason))
Proof
  simp [refund_run_wire_def,refund_wire_roundtrip]
QED

Theorem refund_render_fields_roundtrip:
  parse (explode (refund_render_fields (ok,a,r,c,q,n))) =
    INR (refund_response ok a r c q n,[]) ∧
  refund_response_fields (refund_response ok a r c q n) = INR (ok,a,r,c,q,n)
Proof
  simp [refund_render_fields_def,refund_response_parse,refund_response_roundtrip]
QED

Theorem refund_run_wire_decode_error:
  refund_decode_wire wire = INL err ⇒ refund_run_wire wire = INL err
Proof
  simp [refund_run_wire_def]
QED

Theorem refund_run_wire_trailing:
  rest ≠ [] ∧ parse (explode wire) = INR (se,rest) ⇒
  refund_run_wire wire = INL «refund: trailing input»
Proof
  simp [refund_run_wire_def,refund_decode_wire_def]
QED

Theorem refund_run_wire_malformed:
  parse (explode wire) = INL err ⇒
  refund_run_wire wire = INL «refund: invalid S-expression»
Proof
  simp [refund_run_wire_def,refund_decode_wire_def]
QED

val _ = translation_extends "SexpProg";
val _ = translate result_monadTheory.bind_def;
val _ = translate sexp_to_dafnyTheory.to_mlstring_def;
val _ = translate sexp_to_dafnyTheory.to_bool_def;
val _ = translate sexp_to_dafnyTheory.to_int_def;
val _ = translate sexp_to_dafnyTheory.dest_expr_def;
val _ = translate sexp_to_dafnyTheory.dest_fail_def;
val _ = translate sexp_to_dafnyTheory.dest9_def;
val _ = translate refund_decode_def;
val _ = translate refund_decode_wire_def;
val _ = translate eligible_def;
val _ = translate refund_fields_def;
val _ = translate refund_response_def;
val _ = translate refund_render_fields_def;
val _ = translate refund_run_wire_def;

Quote add_cakeml:
  fun refund_dispatch wire =
    case refund_run_wire wire of
      Inl msg => raise Fail msg
    | Inr output => output;
End

val st = get_ml_prog_state ();

Theorem refund_dispatch_valid:
  refund_run_wire wire = INR output ⇒
  app (p:'ffi ffi_proj) refund_dispatch_v [Litv (StrLit wire)] emp
    (POSTv v. &STRING_TYPE output v)
Proof
  rw [] >> xcf "refund_dispatch" st >>
  xlet_auto >- (xsimpl >> simp [ml_translatorTheory.STRING_TYPE_def]) >>
  gvs [std_preludeTheory.SUM_TYPE_def] >> xmatch >> xvar >> xsimpl
QED

Theorem refund_dispatch_error:
  refund_run_wire wire = INL err ⇒
  app (p:'ffi ffi_proj) refund_dispatch_v [Litv (StrLit wire)] emp
    (POSTe exn. &Fail_exn err exn)
Proof
  rw [] >> xcf "refund_dispatch" st >>
  xlet_auto >- (xsimpl >> simp [ml_translatorTheory.STRING_TYPE_def]) >>
  gvs [std_preludeTheory.SUM_TYPE_def] >> xmatch >>
  xlet_autop >> xraise >> xsimpl >> simp [Fail_exn_def]
QED

val _ = Globals.max_print_depth := 1000;
val _ = List.app (fn (name,th) =>
  let val (oracles,axioms) = Tag.dest_tag (Thm.tag th) in
    print ("FORGE_THEOREM " ^ name ^ "\n");
    print ("FORGE_ORACLES " ^ String.concatWith "," oracles ^ "\n");
    print ("FORGE_AXIOMS " ^ String.concatWith "," axioms ^ "\n");
    print ("FORGE_HYPOTHESES " ^ Int.toString (length (hyp th)) ^ "\n");
    print ("FORGE_STATEMENT " ^ Parse.thm_to_string th ^ "\n")
  end) [("refund_run_wire_valid",refund_run_wire_valid),
        ("refund_render_fields_roundtrip",refund_render_fields_roundtrip),
        ("refund_run_wire_decode_error",refund_run_wire_decode_error),
        ("refund_run_wire_trailing",refund_run_wire_trailing),
        ("refund_run_wire_malformed",refund_run_wire_malformed),
        ("refund_dispatch_valid",refund_dispatch_valid),
        ("refund_dispatch_error",refund_dispatch_error)];

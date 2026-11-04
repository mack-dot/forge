(* Alternative local implementation through the existing proof-producing
   translator. The full result is related to the unchanged generated method.
   This is not adopted into the actual wrapper or an accepted native claim. *)
Theory forge_refundCertifiedProg
Ancestors
  forge_refund forge_refund_call forge_refund_io mlbasicsProg
Libs
  preamble ml_translatorLib ml_progLib basisFunctionsLib cfLib

Definition refund_fields_def:
  refund_fields charge request original remaining enabled opened candidate amount reason =
    let ok = eligible charge request original remaining enabled opened candidate amount reason in
    (ok, (if ok then amount else 0), (if ok then reason else «»),
         (if ok then charge else «»), (if ok then request else «»),
         (if ok then 1:int else 0))
End

Theorem refund_fields_original_method:
  refund_fields charge request original remaining enabled opened candidate amount reason =
    (ok,a,r,c,q,n) ⇒
  let result = evaluate_decs
      ((FST (THE (prim_sem_env ffi))) with clock := 32)
      (refund_argument_env ffi charge request original remaining enabled opened candidate amount reason)
      refund_program
  in
    case SND result of
      Rval env =>
        nsLookup env.v (Short «answer») =
          SOME (Conv NONE [Boolv ok; Litv (IntLit a); Litv (StrLit r);
                           Litv (StrLit c); Litv (StrLit q); Litv (IntLit n)]) ∧
        (FST result).ffi = ffi
    | Rerr err => F
Proof
  strip_tac >>
  mp_tac refund_caller_returns >>
  gvs [refund_fields_def,refund_expected_tuple_def,LET_THM]
QED

val _ = translation_extends "mlbasicsProg";
val _ = translate eligible_def;
val _ = translate refund_fields_def;

Quote add_cakeml:
  fun refund_verified charge request original remaining enabled opened candidate amount reason =
    refund_fields charge request original remaining enabled opened candidate amount reason;
End

val st = get_ml_prog_state ();

Theorem refund_verified_spec:
  app (p:'ffi ffi_proj) refund_verified_v
    [Litv (StrLit charge); Litv (StrLit request); Litv (IntLit original);
     Litv (IntLit remaining); Boolv enabled; Boolv opened; Boolv candidate;
     Litv (IntLit amount); Litv (StrLit reason)]
    emp
    (POSTv v. &PAIR_TYPE BOOL (PAIR_TYPE INT (PAIR_TYPE STRING_TYPE
      (PAIR_TYPE STRING_TYPE (PAIR_TYPE STRING_TYPE INT))))
      (refund_fields charge request original remaining enabled opened candidate amount reason) v)
Proof
  xcf "refund_verified" st >> xapp >> xsimpl >>
  simp [ml_translatorTheory.STRING_TYPE_def,ml_translatorTheory.INT_def,
        ml_translatorTheory.BOOL_def,semanticPrimitivesTheory.Boolv_def]
QED

val _ = List.app (fn (name,th) =>
  let val (oracles,axioms) = Tag.dest_tag (Thm.tag th) in
    print ("FORGE_THEOREM " ^ name ^ "\n");
    print ("FORGE_ORACLES " ^ String.concatWith "," oracles ^ "\n");
    print ("FORGE_AXIOMS " ^ String.concatWith "," axioms ^ "\n");
    print ("FORGE_HYPOTHESES " ^ Int.toString (length (hyp th)) ^ "\n");
    print ("FORGE_STATEMENT " ^ Parse.thm_to_string th ^ "\n")
  end) [("refund_fields_original_method",refund_fields_original_method),
        ("refund_verified_spec",refund_verified_spec)];

(* Fixed refund protocol: existing published parser and typed projections.
   This is application schema composition, not a new codec or machine semantics. *)
Theory forge_refund_io
Ancestors
  forge_refund_call mlsexp mlint sexp_to_dafny result_monad
Libs
  preamble evaluateComputeLib

Definition refund_request_def:
  refund_request charge request original remaining enabled opened candidate amount reason =
    Expr [Atom charge; Atom request; Atom (mlint$toString original);
          Atom (mlint$toString remaining);
          Atom (if enabled then «True» else «False»);
          Atom (if opened then «True» else «False»);
          Atom (if candidate then «True» else «False»);
          Atom (mlint$toString amount); Atom reason]
End

Definition refund_decode_def:
  refund_decode se =
    do xs <- dest_expr se;
       (a,b,c,d,e,f,g,h,i) <- dest9 xs;
       charge <- to_mlstring a; request <- to_mlstring b;
       original <- to_int c; remaining <- to_int d;
       enabled <- to_bool e; opened <- to_bool f; candidate <- to_bool g;
       amount <- to_int h; reason <- to_mlstring i;
       return (charge,request,original,remaining,enabled,opened,candidate,amount,reason)
    od
End

Definition refund_decode_wire_def:
  refund_decode_wire wire =
    case mlsexp$fromString wire of
      NONE => INL «refund: invalid S-expression»
    | SOME se => refund_decode se
End

Theorem refund_schema_roundtrip:
  refund_decode (refund_request charge request original remaining enabled opened candidate amount reason) =
    INR (charge,request,original,remaining,enabled,opened,candidate,amount,reason)
Proof
  Cases_on ‘enabled’ >> Cases_on ‘opened’ >> Cases_on ‘candidate’ >>
  simp [refund_decode_def,refund_request_def,dest_expr_def,dest9_def,
        to_mlstring_def,to_int_def,to_bool_def,bind_def,mlintTheory.fromString_toString]
QED

Theorem refund_wire_roundtrip:
  refund_decode_wire (sexp_to_string
      (refund_request charge request original remaining enabled opened candidate amount reason)) =
    INR (charge,request,original,remaining,enabled,opened,candidate,amount,reason)
Proof
  simp [refund_decode_wire_def,fromString_sexp_to_string,refund_schema_roundtrip]
QED

Theorem refund_stream_parse:
  parse (explode (sexp_to_string
      (refund_request charge request original remaining enabled opened candidate amount reason))) =
    INR (refund_request charge request original remaining enabled opened candidate amount reason, [])
Proof
  mp_tac (Q.SPEC ‘[]’ parse_sexp_to_string) >> simp []
QED

Definition refund_wire_model_def:
  refund_wire_model ffi wire =
    case refund_decode_wire wire of
      INL err => NONE
    | INR (charge,request,original,remaining,enabled,opened,candidate,amount,reason) =>
        SOME (evaluate_decs
          ((FST (THE (prim_sem_env ffi))) with clock := 32)
          (refund_argument_env ffi charge request original remaining enabled opened candidate amount reason)
          refund_program)
End

Theorem refund_wire_model_result:
  case refund_wire_model ffi (sexp_to_string
      (refund_request charge request original remaining enabled opened candidate amount reason)) of
    NONE => F
  | SOME result =>
      case SND result of
        Rval env =>
          nsLookup env.v (Short «answer») = SOME
            (refund_expected_tuple charge request original remaining enabled opened candidate amount reason) ∧
          (FST result).ffi = ffi
      | Rerr err => F
Proof
  simp [refund_wire_model_def,refund_wire_roundtrip] >>
  ACCEPT_TAC (SIMP_RULE std_ss [LET_THM] refund_caller_returns)
QED

Theorem refund_missing_field_rejected:
  refund_decode (Expr []) = INL «dest9: Expected length 9, received length 0»
Proof EVAL_TAC QED

Theorem refund_wrong_type_rejected:
  refund_decode (Expr [Expr []; Atom «r»; Atom «100»; Atom «60»;
      Atom «True»; Atom «True»; Atom «True»; Atom «40»; Atom «duplicate_charge»]) =
    INL «to_mlstring: Was not Atom»
Proof EVAL_TAC QED

Theorem refund_bad_integer_rejected:
  refund_decode (Expr [Atom «c»; Atom «r»; Atom «not-an-integer»; Atom «60»;
      Atom «True»; Atom «True»; Atom «True»; Atom «40»; Atom «duplicate_charge»]) =
    INL «to_int: fromString failed»
Proof EVAL_TAC QED

val _ = List.app (fn (name,th) =>
  let val (oracles,axioms) = Tag.dest_tag (Thm.tag th) in
    print ("FORGE_THEOREM " ^ name ^ "\n");
    print ("FORGE_ORACLES " ^ String.concatWith "," oracles ^ "\n");
    print ("FORGE_AXIOMS " ^ String.concatWith "," axioms ^ "\n");
    print ("FORGE_HYPOTHESES " ^ Int.toString (length (hyp th)) ^ "\n");
    print ("FORGE_STATEMENT " ^ Parse.thm_to_string th ^ "\n")
  end) (Theory.current_theorems ());

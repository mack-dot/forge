(* Construct a library-backed program with the exact Dafny-generated method.
   No native or whole-program behavior claim is made until proved. *)
Theory forge_refundProg
Ancestors
  forge_refund_io SexpProg
Libs
  preamble ml_translatorLib ml_progLib basisFunctionsLib cfLib

val _ = translation_extends "SexpProg";
val _ = translate refund_decode_wire_def;
val _ = translate refund_response_def;
val _ = ml_prog_update (add_Dexn “NoLocs” “«Return»” “[]:ast_t list”);
val _ = ml_prog_update (add_Dletrec “NoLocs”
  (rhs (concl (EVAL “ [refund_method_cml] ”))) ["refund_method_native_v"]);

Quote add_cakeml:
  fun refund_handle wire =
    case refund_decode_wire wire of
      Inl msg => raise Fail msg
    | Inr (charge, request, original, remaining, enabled, opened, candidate, amount, reason) =>
        let val (ok, approved_amount, approved_reason, approved_charge, approved_request, intent_count) =
          dfy_Refund reason amount candidate opened enabled remaining original request charge
        in Sexp.toString (refund_response ok approved_amount approved_reason
                            approved_charge approved_request intent_count)
        end;
  fun refund_main u =
    TextIO.print (refund_handle (TextIO.inputAll (TextIO.openStdIn ())));
End

val st = get_ml_prog_state ();
Definition refund_library_program_def:
  refund_library_program = ^(get_prog st)
End

val _ = print ("FORGE_PROGRAM_CONSTRUCTION_ONLY: no whole-program theorem or native artifact\n");

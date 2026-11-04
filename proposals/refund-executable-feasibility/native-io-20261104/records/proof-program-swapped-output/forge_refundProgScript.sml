(* Construct a library-backed program with the exact Dafny-generated method.
   No native or whole-program behavior claim is made until proved. *)
Theory forge_refundProg
Ancestors
  forge_refund_io SexpProg
Libs
  preamble ml_translatorLib ml_progLib basisFunctionsLib cfLib

val _ = translation_extends "SexpProg";
val _ = translate result_monadTheory.bind_def;
val _ = translate sexp_to_dafnyTheory.to_mlstring_def;
val _ = translate sexp_to_dafnyTheory.to_bool_def;
val _ = translate sexp_to_dafnyTheory.to_int_def;
val _ = translate sexp_to_dafnyTheory.dest_expr_def;
val _ = translate sexp_to_dafnyTheory.dest_fail_def;
val _ = translate sexp_to_dafnyTheory.dest9_def;
val _ = translate refund_decode_def;
val _ = translate refund_response_def;
val _ = ml_prog_update (add_Dexn “NoLocs” “«Return»” “[]:ast_t list”);
val _ = ml_prog_update (add_Dletrec “NoLocs”
  (rhs (concl (EVAL “ [refund_method_cml] ”))) ["refund_method_native_v"]);

Quote add_cakeml:
  fun refund_handle se =
    case refund_decode se of
      Inl msg => raise Fail msg
    | Inr (charge, (request, (original, (remaining, (enabled, (opened, (candidate, (amount, reason)))))))) =>
        let val (ok, approved_amount, approved_reason, approved_request, approved_charge, intent_count) =
          dfy_Refund reason amount candidate opened enabled remaining original request charge
        in Sexp.toString (refund_response ok approved_amount approved_reason
                            approved_charge approved_request intent_count)
        end;
  fun refund_main u =
    let val stream = TextIO.openStdIn ()
        val se = Sexp.inputSexp stream
        val rest = TextIO.inputAll stream
    in if rest = "" then TextIO.print (refund_handle se)
       else raise Fail "refund: trailing input"
    end;
End

val st = get_ml_prog_state ();
Definition refund_library_program_def:
  refund_library_program = ^(get_prog st)
End

(* The translated HOL product uses nested pairs. The generated Dafny method
   itself returns a six-field CakeML tuple; these are distinct conventions. *)
Theorem refund_sum_constructors_bound:
  IS_SOME (nsLookup (^(get_env st)).c (Short «Inl»)) ∧
  IS_SOME (nsLookup (^(get_env st)).c (Short «Inr»))
Proof
  EVAL_TAC
QED

Definition refund_executable_program_def:
  refund_executable_program = SNOC
    (Dlet NoLocs (Pcon NONE [])
      (App Opapp [Var (Short «refund_main»); Con NONE []]))
    refund_library_program
End

Theorem refund_entry_call:
  LAST refund_executable_program =
    Dlet NoLocs (Pcon NONE [])
      (App Opapp [Var (Short «refund_main»); Con NONE []])
Proof
  simp [refund_executable_program_def]
QED

(* Extract the actual wrapper patterns from the checked declaration. These
   are not independently supplied ideal patterns. Altering the wrapper changes
   the terms whose matching behavior must be proved below. *)
val handle_value = rhs (concl (fetch "-" "refund_handle_v_def"));
val handle_env = hd (snd (strip_comb handle_value));
val input_pattern = find_term
  (can (match_term “Pcon (SOME (Short «Inr»)) ps”)) handle_value;
val output_pattern = find_term
  (can (match_term “Pcon NONE (Pvar «ok»::ps)”)) handle_value;

Definition refund_handler_input_pattern_def:
  refund_handler_input_pattern = ^input_pattern
End

Definition refund_handler_output_pattern_def:
  refund_handler_output_pattern = ^output_pattern
End

Theorem refund_decoder_bindings:
  SUM_TYPE STRING_TYPE
    (PAIR_TYPE STRING_TYPE (PAIR_TYPE STRING_TYPE
      (PAIR_TYPE INT (PAIR_TYPE INT (PAIR_TYPE BOOL (PAIR_TYPE BOOL
        (PAIR_TYPE BOOL (PAIR_TYPE INT STRING_TYPE))))))))
    (INR (charge,request,original,remaining,enabled,opened,candidate,amount,reason)) dv ⇒
  pmatch (^(handle_env)).c refs refund_handler_input_pattern dv [] =
    Match [(«reason»,Litv (StrLit reason)); («amount»,Litv (IntLit amount));
      («candidate»,Boolv candidate); («opened»,Boolv opened); («enabled»,Boolv enabled);
      («remaining»,Litv (IntLit remaining)); («original»,Litv (IntLit original));
      («request»,Litv (StrLit request)); («charge»,Litv (StrLit charge))]
Proof
  rw [std_preludeTheory.SUM_TYPE_def,ml_translatorTheory.PAIR_TYPE_def,
      ml_translatorTheory.STRING_TYPE_def,ml_translatorTheory.INT_def,
      ml_translatorTheory.BOOL_def] >> EVAL_TAC
QED

Theorem refund_result_bindings:
  let ok = eligible charge request original remaining enabled opened candidate amount reason in
  pmatch (^(handle_env)).c refs refund_handler_output_pattern
    (refund_expected_tuple charge request original remaining enabled opened candidate amount reason) [] =
    Match [(«intent_count»,Litv (IntLit (if ok then 1 else 0)));
      («approved_request»,Litv (StrLit (if ok then request else «»)));
      («approved_charge»,Litv (StrLit (if ok then charge else «»)));
      («approved_reason»,Litv (StrLit (if ok then reason else «»)));
      («approved_amount»,Litv (IntLit (if ok then amount else 0)));
      («ok»,Boolv ok)]
Proof
  EVAL_TAC
QED

val _ = print ("FORGE_PROGRAM_CONSTRUCTION_ONLY: no whole-program theorem or native artifact\n");

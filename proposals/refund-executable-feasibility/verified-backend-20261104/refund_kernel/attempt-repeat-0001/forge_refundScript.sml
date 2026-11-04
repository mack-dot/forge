(* Local experiment in the published Dafny semantics. No new semantics or axiom.
   IMPORTANT: mlstring has 8-bit characters. Transfer from the approved Unicode
   input domain, native compilation and observable API behavior remain open. *)
Theory forge_refund
Ancestors
  dafny_ast dafny_semanticPrimitives dafny_evaluate mlstring
Libs
  preamble

(* These helpers construct an implementation AST; they do not check a proof. *)
fun all_exp [] = ``Lit (BoolL T)``
  | all_exp (x::xs) = ``BinOp And ^x ^(all_exp xs)``;
fun any_exp [] = ``Lit (BoolL F)``
  | any_exp (x::xs) = ``BinOp Or ^x ^(any_exp xs)``;

val guard = all_exp [
  ``BinOp Neq (Var «v0») (Lit (StrL «»))``,
  ``BinOp Neq (Var «v1») (Lit (StrL «»))``,
  ``Var «v4»``, ``Var «v5»``,
  ``BinOp Le (Lit (IntL 0)) (Var «v2») ``,
  ``BinOp Le (Var «v2») (Lit (IntL 9223372036854775807))``,
  ``BinOp Le (Lit (IntL 0)) (Var «v3») ``,
  ``BinOp Le (Var «v3») (Var «v2») ``,
  ``Var «v6»``,
  ``BinOp Le (Lit (IntL 0)) (Var «v7») ``,
  ``BinOp Le (Var «v7») (Var «v3») ``,
  any_exp [
    ``BinOp Eq (Var «v8») (Lit (StrL «duplicate_charge»))``,
    ``BinOp Eq (Var «v8») (Lit (StrL «service_not_delivered»))``,
    ``BinOp Eq (Var «v8») (Lit (StrL «returned_item»))``]];

Definition refund_guard_def:
  refund_guard = ^guard
End

Definition refund_body_def:
  refund_body =
    Then (Assign [(VarLhs «v9», ExpRhs refund_guard)])
      (Then
        (If (Var «v9»)
          (Assign [
            (VarLhs «v10», ExpRhs (Var «v7»));
            (VarLhs «v11», ExpRhs (Var «v8»));
            (VarLhs «v12», ExpRhs (Var «v0»));
            (VarLhs «v13», ExpRhs (Var «v1»));
            (VarLhs «v14», ExpRhs (Lit (IntL 1)))])
          (Assign [
            (VarLhs «v10», ExpRhs (Lit (IntL 0)));
            (VarLhs «v11», ExpRhs (Lit (StrL «»)));
            (VarLhs «v12», ExpRhs (Lit (StrL «»)));
            (VarLhs «v13», ExpRhs (Lit (StrL «»)));
            (VarLhs «v14», ExpRhs (Lit (IntL 0)))]))
        Return)
End

Definition eligible_def:
  eligible charge request (original:int) (remaining:int) enabled opened candidate (amount:int) reason ⇔
    charge ≠ «» ∧ request ≠ «» ∧ enabled ∧ opened ∧
    0 ≤ original ∧ original ≤ 9223372036854775807 ∧
    0 ≤ remaining ∧ remaining ≤ original ∧ candidate ∧
    0 ≤ amount ∧ amount ≤ remaining ∧
    (reason = «duplicate_charge» ∨ reason = «service_not_delivered» ∨
     reason = «returned_item»)
End

Definition refund_initial_def:
  refund_initial h charge request original remaining enabled opened candidate amount reason =
    (init_state 0) with <|
      heap := h;
      locals := [
        («v0», SOME (StrV charge)); («v1», SOME (StrV request));
        («v2», SOME (IntV original)); («v3», SOME (IntV remaining));
        («v4», SOME (BoolV enabled)); («v5», SOME (BoolV opened));
        («v6», SOME (BoolV candidate)); («v7», SOME (IntV amount));
        («v8», SOME (StrV reason));
        («v9», NONE); («v10», NONE); («v11», NONE);
        («v12», NONE); («v13», NONE); («v14», NONE)] |>
End

Theorem refund_guard_value:
  evaluate_exp
    (refund_initial h charge request original remaining enabled opened candidate amount reason)
    env refund_guard =
  (refund_initial h charge request original remaining enabled opened candidate amount reason,
   Rval (BoolV (eligible charge request original remaining enabled opened candidate amount reason)))
Proof
  EVAL_TAC
  >> rpt (IF_CASES_TAC >> fs [])
QED

val _ = computeLib.add_funs [assign_values_def, assign_value_def];

Theorem refund_full_result:
  let initial = refund_initial h charge request original remaining enabled opened candidate amount reason;
      result = evaluate_stmt initial env refund_body;
      final = FST result;
      ok = eligible charge request original remaining enabled opened candidate amount reason
  in
    SND result = Rstop Sret ∧
    final.heap = h ∧
    read_local final.locals «v9» = SOME (BoolV ok) ∧
    read_local final.locals «v10» = SOME (IntV (if ok then amount else 0)) ∧
    read_local final.locals «v11» = SOME (StrV (if ok then reason else «»)) ∧
    read_local final.locals «v12» = SOME (StrV (if ok then charge else «»)) ∧
    read_local final.locals «v13» = SOME (StrV (if ok then request else «»)) ∧
    read_local final.locals «v14» = SOME (IntV (if ok then 1 else 0))
Proof
  EVAL_TAC
  >> rpt (IF_CASES_TAC >> fs [] >> EVAL_TAC)
QED

val _ = List.app
  (fn (name, th) =>
    let val (oracles, axioms) = Tag.dest_tag (Thm.tag th)
    in
      print ("FORGE_THEOREM " ^ name ^ "\n");
      print ("FORGE_ORACLES " ^ String.concatWith "," oracles ^ "\n");
      print ("FORGE_AXIOMS " ^ String.concatWith "," axioms ^ "\n");
      print ("FORGE_HYPOTHESES " ^ Int.toString (length (hyp th)) ^ "\n")
    end)
  [("refund_guard_value", refund_guard_value),
   ("refund_full_result", refund_full_result)];

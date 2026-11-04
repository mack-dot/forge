(* Exact generated method and fixed model caller. No native/I-O claim. *)
Theory forge_refund_call
Ancestors
  forge_refund forge_refund_compile dafny_to_cakeml primTypes primSemEnv
  evaluate semanticPrimitives namespace
Libs
  preamble evaluateComputeLib

Definition refund_method_def:
  refund_method = Method «Refund»
    [(«v0»,StrT); («v1»,StrT); («v2»,IntT); («v3»,IntT);
     («v4»,BoolT); («v5»,BoolT); («v6»,BoolT); («v7»,IntT); («v8»,StrT)]
    [] [] [] []
    [(«v9»,BoolT); («v10»,IntT); («v11»,StrT); («v12»,StrT);
     («v13»,StrT); («v14»,IntT)] [] refund_body
End

val compiled = EVAL ``from_member_decl refund_method``;
val compiled_member = rand (rhs (concl compiled));

Definition refund_method_cml_def:
  refund_method_cml = ^compiled_member
End

Theorem refund_method_compilation:
  from_member_decl refund_method = INR refund_method_cml
Proof
  REWRITE_TAC [refund_method_cml_def] >> ACCEPT_TAC compiled
QED

Definition refund_call_def:
  refund_call = cml_fapp [] «dfy_Refund»
    (REVERSE [Var (Short «arg1»); Var (Short «arg0»); Var (Short «arg2»);
              Var (Short «arg3»); Var (Short «arg4»); Var (Short «arg5»);
              Var (Short «arg6»); Var (Short «arg7»); Var (Short «arg8»)])
End

Definition refund_program_def:
  refund_program =
    [Dexn NoLocs «Return» [];
     Dletrec NoLocs [refund_method_cml];
     Dlet NoLocs (Pvar «answer») refund_call]
End

Definition refund_argument_env_def:
  refund_argument_env (ffi:'ffi ffi_state) charge request original remaining enabled opened candidate amount reason =
    (SND (THE (prim_sem_env ffi))) with v :=
      alist_to_ns
        [(«arg0»,Litv (StrLit charge)); («arg1»,Litv (StrLit request));
         («arg2»,Litv (IntLit original)); («arg3»,Litv (IntLit remaining));
         («arg4»,Boolv enabled); («arg5»,Boolv opened); («arg6»,Boolv candidate);
         («arg7»,Litv (IntLit amount)); («arg8»,Litv (StrLit reason))]
End

Definition refund_expected_tuple_def:
  refund_expected_tuple charge request original remaining enabled opened candidate amount reason =
    let ok = eligible charge request original remaining enabled opened candidate amount reason in
    Conv NONE [Boolv ok; Litv (IntLit (if ok then amount else 0));
      Litv (StrLit (if ok then reason else «»));
      Litv (StrLit (if ok then charge else «»));
      Litv (StrLit (if ok then request else «»));
      Litv (IntLit (if ok then 1 else 0))]
End

Theorem concrete_bool_tests:
  (((if b then Conv (SOME (TypeStamp «True» 0)) []
       else Conv (SOME (TypeStamp «False» 0)) []) =
     Conv (SOME (TypeStamp «True» 0)) []) ⇔ b) ∧
  (((if b then Conv (SOME (TypeStamp «True» 0)) []
       else Conv (SOME (TypeStamp «False» 0)) []) =
     Conv (SOME (TypeStamp «False» 0)) []) ⇔ ¬b)
Proof
  Cases_on ‘b’ >> EVAL_TAC
QED

Theorem refund_caller_returns:
  let result = evaluate_decs
      ((FST (THE (prim_sem_env ffi))) with clock := 32)
      (refund_argument_env ffi charge request original remaining enabled opened candidate amount reason)
      refund_program
  in
    case SND result of
      Rval env =>
        nsLookup env.v (Short «answer») =
          SOME (refund_expected_tuple charge request original remaining enabled opened candidate amount reason) ∧
        (FST result).ffi = ffi
    | Rerr err => F
Proof
  EVAL_TAC >> gvs [concrete_bool_tests]
  >> rpt (IF_CASES_TAC >> gvs [concrete_bool_tests] >> EVAL_TAC)
  >> simp [concrete_bool_tests]
QED

val _ = List.app (fn (name,th) =>
  let val (oracles,axioms) = Tag.dest_tag (Thm.tag th) in
    print ("FORGE_THEOREM " ^ name ^ "\n");
    print ("FORGE_ORACLES " ^ String.concatWith "," oracles ^ "\n");
    print ("FORGE_AXIOMS " ^ String.concatWith "," axioms ^ "\n");
    print ("FORGE_HYPOTHESES " ^ Int.toString (length (hyp th)) ^ "\n");
    print ("FORGE_STATEMENT " ^ Parse.thm_to_string th ^ "\n")
  end) [("refund_method_compilation",refund_method_compilation),
        ("refund_caller_returns",refund_caller_returns)];

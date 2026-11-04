Theory forge_refundMethodProg
Ancestors
  forge_refund_call mlbasicsProg
Libs
  preamble ml_translatorLib ml_progLib basisFunctionsLib cfLib

val _ = translation_extends "mlbasicsProg";
val _ = ml_prog_update (add_Dexn “NoLocs” “«Return»” “[]:ast_t list”);
val _ = ml_prog_update (add_Dletrec “NoLocs”
  (rhs (concl (EVAL “[refund_method_cml]”))) ["refund_method_library_v"]);
val st = get_ml_prog_state ();

Theorem refund_method_library_spec:
  app (p:'ffi ffi_proj) ^(fetch_v "dfy_Refund" st)
    [Litv (StrLit reason); Litv (IntLit amount); Boolv candidate;
     Boolv opened; Boolv enabled; Litv (IntLit remaining);
     Litv (IntLit original); Litv (StrLit request); Litv (StrLit charge)]
    emp
    (POSTv answer. &(answer = refund_expected_tuple charge request original
      remaining enabled opened candidate amount reason))
Proof
  xcf "dfy_Refund" st >>
  (xlet ‘POSTv v0. REF v0 (Litv (StrLit charge))’ >- (xref >> xsimpl >> simp [semanticPrimitivesTheory.Boolv_def])) >>
  (xlet ‘POSTv v1. REF v0 (Litv (StrLit charge)) * REF v1 (Litv (StrLit request))’ >- (xref >> xsimpl >> simp [semanticPrimitivesTheory.Boolv_def])) >>
  (xlet ‘POSTv v2. REF v0 (Litv (StrLit charge)) * REF v1 (Litv (StrLit request)) * REF v2 (Litv (IntLit original))’ >- (xref >> xsimpl >> simp [semanticPrimitivesTheory.Boolv_def])) >>
  (xlet ‘POSTv v3. REF v0 (Litv (StrLit charge)) * REF v1 (Litv (StrLit request)) * REF v2 (Litv (IntLit original)) * REF v3 (Litv (IntLit remaining))’ >- (xref >> xsimpl >> simp [semanticPrimitivesTheory.Boolv_def])) >>
  (xlet ‘POSTv v4. REF v0 (Litv (StrLit charge)) * REF v1 (Litv (StrLit request)) * REF v2 (Litv (IntLit original)) * REF v3 (Litv (IntLit remaining)) * REF v4 (Boolv enabled)’ >- (xref >> xsimpl >> simp [semanticPrimitivesTheory.Boolv_def])) >>
  (xlet ‘POSTv v5. REF v0 (Litv (StrLit charge)) * REF v1 (Litv (StrLit request)) * REF v2 (Litv (IntLit original)) * REF v3 (Litv (IntLit remaining)) * REF v4 (Boolv enabled) * REF v5 (Boolv opened)’ >- (xref >> xsimpl >> simp [semanticPrimitivesTheory.Boolv_def])) >>
  (xlet ‘POSTv v6. REF v0 (Litv (StrLit charge)) * REF v1 (Litv (StrLit request)) * REF v2 (Litv (IntLit original)) * REF v3 (Litv (IntLit remaining)) * REF v4 (Boolv enabled) * REF v5 (Boolv opened) * REF v6 (Boolv candidate)’ >- (xref >> xsimpl >> simp [semanticPrimitivesTheory.Boolv_def])) >>
  (xlet ‘POSTv v7. REF v0 (Litv (StrLit charge)) * REF v1 (Litv (StrLit request)) * REF v2 (Litv (IntLit original)) * REF v3 (Litv (IntLit remaining)) * REF v4 (Boolv enabled) * REF v5 (Boolv opened) * REF v6 (Boolv candidate) * REF v7 (Litv (IntLit amount))’ >- (xref >> xsimpl >> simp [semanticPrimitivesTheory.Boolv_def])) >>
  (xlet ‘POSTv v8. REF v0 (Litv (StrLit charge)) * REF v1 (Litv (StrLit request)) * REF v2 (Litv (IntLit original)) * REF v3 (Litv (IntLit remaining)) * REF v4 (Boolv enabled) * REF v5 (Boolv opened) * REF v6 (Boolv candidate) * REF v7 (Litv (IntLit amount)) * REF v8 (Litv (StrLit reason))’ >- (xref >> xsimpl >> simp [semanticPrimitivesTheory.Boolv_def])) >>
  (xlet ‘POSTv v9. REF v0 (Litv (StrLit charge)) * REF v1 (Litv (StrLit request)) * REF v2 (Litv (IntLit original)) * REF v3 (Litv (IntLit remaining)) * REF v4 (Boolv enabled) * REF v5 (Boolv opened) * REF v6 (Boolv candidate) * REF v7 (Litv (IntLit amount)) * REF v8 (Litv (StrLit reason)) * REF v9 (Litv (IntLit 0))’ >- (xref >> xsimpl >> simp [semanticPrimitivesTheory.Boolv_def])) >>
  (xlet ‘POSTv v10. REF v0 (Litv (StrLit charge)) * REF v1 (Litv (StrLit request)) * REF v2 (Litv (IntLit original)) * REF v3 (Litv (IntLit remaining)) * REF v4 (Boolv enabled) * REF v5 (Boolv opened) * REF v6 (Boolv candidate) * REF v7 (Litv (IntLit amount)) * REF v8 (Litv (StrLit reason)) * REF v9 (Litv (IntLit 0)) * REF v10 (Litv (IntLit 0))’ >- (xref >> xsimpl >> simp [semanticPrimitivesTheory.Boolv_def])) >>
  (xlet ‘POSTv v11. REF v0 (Litv (StrLit charge)) * REF v1 (Litv (StrLit request)) * REF v2 (Litv (IntLit original)) * REF v3 (Litv (IntLit remaining)) * REF v4 (Boolv enabled) * REF v5 (Boolv opened) * REF v6 (Boolv candidate) * REF v7 (Litv (IntLit amount)) * REF v8 (Litv (StrLit reason)) * REF v9 (Litv (IntLit 0)) * REF v10 (Litv (IntLit 0)) * REF v11 (Litv (IntLit 0))’ >- (xref >> xsimpl >> simp [semanticPrimitivesTheory.Boolv_def])) >>
  (xlet ‘POSTv v12. REF v0 (Litv (StrLit charge)) * REF v1 (Litv (StrLit request)) * REF v2 (Litv (IntLit original)) * REF v3 (Litv (IntLit remaining)) * REF v4 (Boolv enabled) * REF v5 (Boolv opened) * REF v6 (Boolv candidate) * REF v7 (Litv (IntLit amount)) * REF v8 (Litv (StrLit reason)) * REF v9 (Litv (IntLit 0)) * REF v10 (Litv (IntLit 0)) * REF v11 (Litv (IntLit 0)) * REF v12 (Litv (IntLit 0))’ >- (xref >> xsimpl >> simp [semanticPrimitivesTheory.Boolv_def])) >>
  (xlet ‘POSTv v13. REF v0 (Litv (StrLit charge)) * REF v1 (Litv (StrLit request)) * REF v2 (Litv (IntLit original)) * REF v3 (Litv (IntLit remaining)) * REF v4 (Boolv enabled) * REF v5 (Boolv opened) * REF v6 (Boolv candidate) * REF v7 (Litv (IntLit amount)) * REF v8 (Litv (StrLit reason)) * REF v9 (Litv (IntLit 0)) * REF v10 (Litv (IntLit 0)) * REF v11 (Litv (IntLit 0)) * REF v12 (Litv (IntLit 0)) * REF v13 (Litv (IntLit 0))’ >- (xref >> xsimpl >> simp [semanticPrimitivesTheory.Boolv_def])) >>
  (xlet ‘POSTv v14. REF v0 (Litv (StrLit charge)) * REF v1 (Litv (StrLit request)) * REF v2 (Litv (IntLit original)) * REF v3 (Litv (IntLit remaining)) * REF v4 (Boolv enabled) * REF v5 (Boolv opened) * REF v6 (Boolv candidate) * REF v7 (Litv (IntLit amount)) * REF v8 (Litv (StrLit reason)) * REF v9 (Litv (IntLit 0)) * REF v10 (Litv (IntLit 0)) * REF v11 (Litv (IntLit 0)) * REF v12 (Litv (IntLit 0)) * REF v13 (Litv (IntLit 0)) * REF v14 (Litv (IntLit 0))’ >- (xref >> xsimpl >> simp [semanticPrimitivesTheory.Boolv_def])) >>
  xhandle ‘POSTe exn. &(exn = Conv (SOME (ExnStamp 5)) []) * REF v9 (Boolv (eligible charge request original remaining enabled opened candidate amount reason)) * REF v10 (Litv (IntLit (if eligible charge request original remaining enabled opened candidate amount reason then amount else 0))) * REF v11 (Litv (StrLit (if eligible charge request original remaining enabled opened candidate amount reason then reason else «»))) * REF v12 (Litv (StrLit (if eligible charge request original remaining enabled opened candidate amount reason then charge else «»))) * REF v13 (Litv (StrLit (if eligible charge request original remaining enabled opened candidate amount reason then request else «»))) * REF v14 (Litv (IntLit (if eligible charge request original remaining enabled opened candidate amount reason then 1 else 0)))’ >>
  rpt (FIRST [xlet_autop,xif,xlog,xraise,xcon,xvar,
    CHANGED_TAC xsimpl]) >>
  simp [refund_expected_tuple_def,forge_refundTheory.eligible_def]

QED

Theory forge_refundMethodProg
Ancestors
  forge_refund_call mlbasicsProg
Libs
  preamble ml_translatorLib ml_progLib basisFunctionsLib cfLib

val _ = translation_extends "mlbasicsProg";
val _ = ml_prog_update (add_Dexn “NoLocs” “«Return»” “[]”);
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
  xcf "dfy_Refund" st >> ntac 15 xlet_autop
QED

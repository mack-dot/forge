(* Published normalization proposes this exact AST. No semantic-preservation
   theorem is assumed. A complete direct behavior proof is still required. *)
Theory forge_refundNormProg
Ancestors
  forge_refund_call mlbasicsProg
Libs
  preamble ml_translatorLib ml_progLib basisFunctionsLib cfLib cfNormaliseLib

val raw_decl = rhs (concl (EVAL “Dletrec NoLocs [refund_method_cml]”));
val normalised_decl = cfNormaliseLib.normalise_decl raw_decl;
val (_,normalised_funs) = astSyntax.dest_Dletrec normalised_decl;

Definition refund_normalised_decl_def:
  refund_normalised_decl = ^normalised_decl
End

val ast_file = TextIO.openOut "normalised-method.ast.txt";
val _ = TextIO.output (ast_file, Parse.term_to_string normalised_decl ^ "\n");
val _ = TextIO.closeOut ast_file;

val _ = translation_extends "mlbasicsProg";
val _ = ml_prog_update (add_Dexn “NoLocs” “«Return»” “[]:ast_t list”);
val _ = ml_prog_update (add_Dletrec “NoLocs” normalised_funs ["refund_normalised_method_v"]);
val st = get_ml_prog_state ();

val _ = print ("FORGE_CANDIDATE_ONLY: normalized AST construction; behavior NOT_ESTABLISHED\n");

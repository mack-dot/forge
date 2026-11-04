(* Published normalization proposes this exact AST. No semantic-preservation
   theorem is assumed. A complete direct behavior proof is still required. *)
Theory forge_refundNormProg
Ancestors
  forge_refund_call mlbasicsProg
Libs
  preamble ml_translatorLib ml_progLib basisFunctionsLib cfLib cfNormaliseLib

val _ = print "FORGE_PREPARE_INPUT\n";
val raw_decl = rhs (concl (REWRITE_CONV [refund_method_cml_def]
  “Dletrec NoLocs [refund_method_cml]”));
val _ = print "FORGE_INPUT_READY\n";
val stripped_decl = cfNormaliseLib.strip_annot_decl raw_decl;
val _ = print "FORGE_ANNOTATIONS_STRIPPED\n";
val normalised_decl = cfNormaliseLib.normalise_decl stripped_decl;
val _ = print "FORGE_NORMALISED_AST_READY\n";
val (_,normalised_funs) = astSyntax.dest_Dletrec normalised_decl;

Definition refund_normalised_decl_def:
  refund_normalised_decl = ^normalised_decl
End

val _ = Globals.max_print_depth := 1000;
val ast_file = TextIO.openOut "normalised-method.ast.txt";
val _ = TextIO.output (ast_file, Parse.term_to_string normalised_decl ^ "\n");
val _ = TextIO.closeOut ast_file;

val _ = translation_extends "mlbasicsProg";
val _ = ml_prog_update (add_Dexn “NoLocs” “«Return»” “[]:ast_t list”);
val _ = ml_prog_update (add_Dletrec “NoLocs” normalised_funs ["refund_normalised_method_v"]);
val st = get_ml_prog_state ();

val _ = print ("FORGE_CANDIDATE_ONLY: normalized AST construction; behavior NOT_ESTABLISHED\n");

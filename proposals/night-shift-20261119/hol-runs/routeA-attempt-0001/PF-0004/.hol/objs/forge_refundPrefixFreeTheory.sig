signature forge_refundPrefixFreeTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val lexP_def : thm
    val lexPs_def : thm
    val refund_strict_parse_def : thm
  
  (*  Theorems  *)
    val N1_trailing_newline_breaks : thm
    val N2_atom_breaks : thm
    val N3_depth0_breaks : thm
    val atom_prefix_ISL : thm
    val char_escaped_strict_prefix : thm
    val every_isPREFIX : thm
    val lexP_Atom : thm
    val lexP_Expr : thm
    val lexP_all : thm
    val lexPs_cons : thm
    val lexPs_cons_in_v : thm
    val lexPs_cons_space : thm
    val lexPs_cons_split : thm
    val lexPs_nil : thm
    val lex_aux_prefix_ISL : thm
    val parse_ISL_of_lex : thm
    val prefix_append_strict : thm
    val read_string_aux_char_escaped : thm
    val read_string_aux_strict_prefix : thm
    val read_symbol_safe_nil : thm
    val refund_render_fields_prefix_code : thm
    val refund_render_fields_prefix_free : thm
    val refund_strict_parse_complete : thm
    val refund_strict_parse_no_strict_prefix : thm
    val sexp_print_eqs : thm
    val sexp_to_string_Expr_prefix_free : thm
end

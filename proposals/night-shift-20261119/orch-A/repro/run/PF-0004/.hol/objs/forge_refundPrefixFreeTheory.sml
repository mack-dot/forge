structure forge_refundPrefixFreeTheory :> forge_refundPrefixFreeTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundPrefixFreeTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundSlideProfileATheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundPrefixFree",
        hash = "f9a00a5a7dc6bad12ff3475b1fd1ef47c878a368",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundPrefixFree" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op sexp_to_string_Expr_prefix_free _ = ()
  val op sexp_to_string_Expr_prefix_free = TDB.find
    "sexp_to_string_Expr_prefix_free"
  fun op sexp_print_eqs _ = ()
  val op sexp_print_eqs = TDB.find "sexp_print_eqs"
  fun op refund_strict_parse_no_strict_prefix _ = ()
  val op refund_strict_parse_no_strict_prefix = TDB.find
    "refund_strict_parse_no_strict_prefix"
  fun op refund_strict_parse_def _ = ()
  val op refund_strict_parse_def = TDB.find "refund_strict_parse_def"
  fun op refund_strict_parse_complete _ = ()
  val op refund_strict_parse_complete = TDB.find
    "refund_strict_parse_complete"
  fun op refund_render_fields_prefix_free _ = ()
  val op refund_render_fields_prefix_free = TDB.find
    "refund_render_fields_prefix_free"
  fun op refund_render_fields_prefix_code _ = ()
  val op refund_render_fields_prefix_code = TDB.find
    "refund_render_fields_prefix_code"
  fun op read_symbol_safe_nil _ = ()
  val op read_symbol_safe_nil = TDB.find "read_symbol_safe_nil"
  fun op read_string_aux_strict_prefix _ = ()
  val op read_string_aux_strict_prefix = TDB.find
    "read_string_aux_strict_prefix"
  fun op read_string_aux_char_escaped _ = ()
  val op read_string_aux_char_escaped = TDB.find
    "read_string_aux_char_escaped"
  fun op prefix_append_strict _ = ()
  val op prefix_append_strict = TDB.find "prefix_append_strict"
  fun op parse_ISL_of_lex _ = ()
  val op parse_ISL_of_lex = TDB.find "parse_ISL_of_lex"
  fun op lex_aux_prefix_ISL _ = ()
  val op lex_aux_prefix_ISL = TDB.find "lex_aux_prefix_ISL"
  fun op lexPs_nil _ = () val op lexPs_nil = TDB.find "lexPs_nil"
  fun op lexPs_def _ = () val op lexPs_def = TDB.find "lexPs_def"
  fun op lexPs_cons_split _ = ()
  val op lexPs_cons_split = TDB.find "lexPs_cons_split"
  fun op lexPs_cons_space _ = ()
  val op lexPs_cons_space = TDB.find "lexPs_cons_space"
  fun op lexPs_cons_in_v _ = ()
  val op lexPs_cons_in_v = TDB.find "lexPs_cons_in_v"
  fun op lexPs_cons _ = () val op lexPs_cons = TDB.find "lexPs_cons"
  fun op lexP_def _ = () val op lexP_def = TDB.find "lexP_def"
  fun op lexP_all _ = () val op lexP_all = TDB.find "lexP_all"
  fun op lexP_Expr _ = () val op lexP_Expr = TDB.find "lexP_Expr"
  fun op lexP_Atom _ = () val op lexP_Atom = TDB.find "lexP_Atom"
  fun op every_isPREFIX _ = ()
  val op every_isPREFIX = TDB.find "every_isPREFIX"
  fun op char_escaped_strict_prefix _ = ()
  val op char_escaped_strict_prefix = TDB.find "char_escaped_strict_prefix"
  fun op atom_prefix_ISL _ = ()
  val op atom_prefix_ISL = TDB.find "atom_prefix_ISL"
  fun op N3_depth0_breaks _ = ()
  val op N3_depth0_breaks = TDB.find "N3_depth0_breaks"
  fun op N2_atom_breaks _ = ()
  val op N2_atom_breaks = TDB.find "N2_atom_breaks"
  fun op N1_trailing_newline_breaks _ = ()
  val op N1_trailing_newline_breaks = TDB.find "N1_trailing_newline_breaks"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundPrefixFree"

end

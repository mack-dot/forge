(* DRAFT. NOT RUN. Worker Y4, graph link X13. No HOL process was started.
   Names and types were checked by reading:
     CK/basis/pure/mlsexpScript.sml (lex_aux_def, read_string_aux_def, read_symbol_def,
       parse_def, lex_def, sexp_to_app_list_def/_ind, sexp_to_string_def, make_str_safe_def,
       is_safe_char_def, str_every_thm, read_symbol_thm, read_string_aux_thm,
       lex_aux_sexp_to_list); CK/basis/pure/.hol/objs/mlsexpTheory.sig (all names present);
     CK/basis/pure/mlstringScript.sml 1513-1534 (char_escape_seq_def, char_escaped_def, escape_str_def);
     replay-sources/forge_refundWireProg.sml (refund_render_fields_def, refund_render_fields_roundtrip);
     replay-sources/forge_refund_io.sml (refund_response_def, refund_response_fields_def);
     forge_refundWireProgTheory.sig (stdio-contract-20261104/records/proof-wire-repeat/objects).
   CK = .toolchain/experiments/refund-cakeml-20261104/cakeml
   Pitfall (memory note): simp with sexp_to_app_list_def on CONCRETE terms did not terminate.
   Use it only on variables (as the stored lex_aux_sexp_to_list proof does). *)

Theory forge_refundPrefixFree
Ancestors
  forge_refundWireProg forge_refund_io mlsexp mlstring rich_list
Libs
  preamble

(* ---------- the STRICT parser, in HOL ---------- *)
Definition refund_strict_parse_def:
  refund_strict_parse (s : string) =
    case parse s of
    | INL _ => NONE
    | INR (se, rest) =>
        if rest ≠ [] then NONE else
        case refund_response_fields se of
        | INL _ => NONE
        | INR f => if explode (refund_render_fields f) = s then SOME f else NONE
End
(* Type: string -> (bool # int # mlstring # mlstring # mlstring # int) option.
   It needs: one parse, no rest, the 7-field result shape, and canonical spelling
   (re-render equals the input byte for byte). *)

(* ---------- helpers ---------- *)
Theorem isPREFIX_APPEND_CASES:
  ∀a b p. p ≼ a ++ b ⇔ p ≼ a ∨ ∃q. p = a ++ q ∧ q ≼ b
Proof
  Induct >> rw[] >> Cases_on ‘p’ >> gvs[] >> metis_tac[]
QED

Theorem read_symbol_safe_nil:
  ∀t acc. EVERY is_safe_char t ⇒ read_symbol t acc = (implode (REVERSE acc ++ t), [])
Proof
  rpt strip_tac >> qspecl_then [‘t’,‘""’,‘acc’] mp_tac read_symbol_thm >> simp[]
QED

(* A strict prefix of an escaped string body plus its closing quote never closes. *)
Theorem read_string_aux_strict_prefix:
  ∀xs u acc. u ≼ CONCAT (MAP char_escaped xs) ++ "\"" ∧
             u ≠ CONCAT (MAP char_escaped xs) ++ "\"" ⇒ ISL (read_string_aux u acc)
Proof
  Induct
  >- (rw[] >> Cases_on ‘u’ >> gvs[read_string_aux_def])
  \\ rw[char_escaped_def, char_escape_seq_def] \\ gvs[]
  \\ Cases_on ‘u’ \\ gvs[read_string_aux_def]
  (* escape cases: u = "\\" or "\\" :: e :: u' *)
  \\ rpt (rename1 ‘read_string_aux (_ :: tl) _’ \\ Cases_on ‘tl’ \\ gvs[read_string_aux_def])
  \\ first_x_assum irule \\ simp[]
QED  (* HARD-ish: case explosion over the four escapes; may need per-case tactics. *)

(* ---------- atom at depth d ≠ 0 ---------- *)
Theorem lex_aux_atom_prefix:
  ∀m p d ts. d ≠ 0 ∧ p ≼ explode (make_str_safe m) ⇒ ISL (lex_aux d p ts)
Proof
  rpt strip_tac \\ gvs[make_str_safe_def] \\ every_case_tac \\ gvs[]
  >- (* «» prints as "" "" *)
     (Cases_on ‘p’ \\ gvs[lex_aux_def] \\ rename1 ‘lex_aux _ (_ :: tl) _’
      \\ Cases_on ‘tl’ \\ gvs[lex_aux_def, read_string_def, read_string_aux_def]
      \\ rename1 ‘_ :: tl2’ \\ Cases_on ‘tl2’ \\ gvs[read_string_aux_def, lex_aux_def])
  >- (* bare atom: every char safe *)
     (dxrule str_every_thm \\ Cases_on ‘m’ \\ gvs[] \\ strip_tac
      \\ ‘EVERY is_safe_char s’ by gvs[EVERY_EL]
      \\ ‘EVERY is_safe_char p’ by metis_tac[rich_listTheory.IS_PREFIX_APPEND, EVERY_APPEND]
      \\ Cases_on ‘p’ \\ gvs[lex_aux_def]
      \\ gvs[is_safe_char_def, read_symbol_safe_nil, lex_aux_def])
  (* quoted atom: "\"" ++ FLAT (MAP char_escaped (explode m)) ++ "\"" *)
  \\ gvs[escape_str_def] \\ Cases_on ‘p’ \\ gvs[lex_aux_def, read_string_def]
  \\ rename1 ‘read_string_aux u []’
  \\ Cases_on ‘u = CONCAT (MAP char_escaped (explode m)) ++ "\""’
  >- (qspecl_then [‘explode m’,‘""’,‘[]’] mp_tac read_string_aux_thm \\ gvs[lex_aux_def])
  \\ drule_all read_string_aux_strict_prefix \\ Cases_on ‘read_string_aux u []’ \\ gvs[]
QED

(* ---------- KEY LEMMA (mutual; the hard step of X13) ----------
   At depth d ≠ 0, ANY prefix (even the full printing) of a printed sexp or of a
   space-joined printed list lexes to INL: input ends before depth 0 comes back. *)
Theorem lex_aux_prefix_ISL:
  (∀x p d ts. d ≠ 0 ∧ p ≼ explode (concat (append (sexp_to_app_list x))) ⇒
              ISL (lex_aux d p ts)) ∧
  (∀xs p d ts. d ≠ 0 ∧ p ≼ explode (concat (append (sexps_to_app_list xs))) ⇒
               ISL (lex_aux d p ts))
Proof
  ho_match_mp_tac sexp_to_app_list_ind \\ rpt conj_tac
  >- (* Atom *) (rw[sexp_to_app_list_def, concat_def] \\ metis_tac[lex_aux_atom_prefix])
  >- (* Expr xs: "(" ++ J xs ++ ")" *)
     (rw[sexp_to_app_list_def, concat_def] \\ fs[concat_def]
      \\ Cases_on ‘p’ \\ gvs[lex_aux_def]                    (* [] : depth ≠ 0 gives INL *)
      \\ gvs[isPREFIX_APPEND_CASES]
      >- (first_x_assum irule \\ simp[])                    (* prefix of J xs at depth d+1 *)
      \\ gvs[isPREFIX_CONSR]                                  (* q = J xs or J xs ++ ")" *)
      >- (first_x_assum irule \\ simp[])
      \\ qspecl_then [‘xs’,‘")"’] mp_tac (cj 2 lex_aux_sexp_to_list) \\ simp[]
      \\ simp[Once lex_aux_def] \\ simp[lex_aux_def])       (* depth d+1 ≥ 2, then [] at d ≠ 0 *)
  >- (* [] *) (rw[sexp_to_app_list_def, concat_def] \\ gvs[lex_aux_def])
  (* x :: xs *)
  \\ qx_genl_tac [‘x’,‘xs’] \\ strip_tac \\ rw[sexp_to_app_list_def]
  >- (first_x_assum irule \\ gvs[NULL_EQ])
  \\ fs[concat_def] \\ gvs[isPREFIX_APPEND_CASES]
  >- (first_x_assum irule \\ simp[])
  \\ gvs[isPREFIX_CONSR]
  >- (first_x_assum irule \\ simp[])                          (* q = [] : prefix of P(x) *)
  \\ qspecl_then [‘x’,‘#" " :: xs'’] mp_tac (cj 1 lex_aux_sexp_to_list)
  \\ simp[] \\ simp[Once lex_aux_def] \\ strip_tac \\ first_x_assum irule \\ simp[]
QED

(* ---------- main lemma ---------- *)
Theorem sexp_to_string_Expr_prefix_free:
  ∀xs p. p ≼ explode (sexp_to_string (Expr xs)) ∧ p ≠ explode (sexp_to_string (Expr xs)) ⇒
         ISL (parse p)
Proof
  rw[sexp_to_string_def, Once sexp_to_app_list_def, concat_def]
  \\ Cases_on ‘p’ \\ gvs[parse_def, lex_def, lex_aux_def, parse_aux_def]   (* "" : empty input *)
  \\ rename1 ‘lex_aux 1 q [OPEN]’
  \\ ‘q ≼ explode (concat (append (sexps_to_app_list xs)))’
       by (gvs[isPREFIX_APPEND_CASES] \\ gvs[isPREFIX_CONSR])
  \\ drule_then (qspecl_then [‘1’,‘[OPEN]’] mp_tac) (cj 2 lex_aux_prefix_ISL)
  \\ Cases_on ‘lex_aux 1 q [OPEN]’ \\ gvs[] \\ rename1 ‘INL y’ \\ PairCases_on ‘y’ \\ simp[]
QED

Theorem refund_render_fields_prefix_free:
  ∀f p. p ≼ explode (refund_render_fields f) ∧ p ≠ explode (refund_render_fields f) ⇒
        ISL (parse p)
Proof
  rpt gen_tac \\ PairCases_on ‘f’
  \\ simp[refund_render_fields_def, refund_response_def]
  \\ metis_tac[sexp_to_string_Expr_prefix_free]
QED

(* the X13 statement under the STRICT parser *)
Theorem refund_strict_parse_no_strict_prefix:
  ∀f p. p ≼ explode (refund_render_fields f) ∧ p ≠ explode (refund_render_fields f) ⇒
        refund_strict_parse p = NONE
Proof
  rpt strip_tac \\ drule_all refund_render_fields_prefix_free
  \\ simp[refund_strict_parse_def] \\ Cases_on ‘parse p’ \\ gvs[]
QED

(* POSITIVE CONTROL P0 (required: the parser λs. NONE also meets the lemma above) *)
Theorem refund_strict_parse_complete:
  ∀f. refund_strict_parse (explode (refund_render_fields f)) = SOME f
Proof
  Cases \\ PairCases_on ‘r’ \\ simp[refund_strict_parse_def, refund_render_fields_roundtrip]
QED

(* ---------- NEGATIVE CONTROLS (each must be PROVED as stated; a run that fails one fails) ---------- *)
(* N1: a printer with a trailing newline is NOT prefix-free (witness: the frame itself). *)
Theorem N1_trailing_newline_breaks:
  ¬(∀f p. p ≼ explode (refund_render_fields f) ++ "\n" ∧
          p ≠ explode (refund_render_fields f) ++ "\n" ⇒ ISL (parse p))
Proof
  simp[] \\ qexists_tac ‘(T, 40, «returned_item», «c», «r», 1)’
  \\ qexists_tac ‘explode (refund_render_fields (T, 40, «returned_item», «c», «r», 1))’
  \\ simp[refund_render_fields_roundtrip]
QED
(* N2: a top-level atom is NOT prefix-free. *)
Theorem N2_atom_breaks:
  parse "ab" = INR (Atom «ab», []) ∧ "ab" ≼ explode (sexp_to_string (Atom «abc»))
Proof
  EVAL_TAC
QED
(* N3: the key lemma is false without d ≠ 0. *)
Theorem N3_depth0_breaks:
  lex_aux 0 "a" [] = INR ([SYMBOL «a»], []) ∧ "a" ≼ explode (sexp_to_string (Atom «a»))
Proof
  EVAL_TAC
QED
(* Checks to add when run: DISK_THM-only tags; closure axioms = the four of bool;
   print the exact statements. *)

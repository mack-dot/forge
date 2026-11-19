(* Strict-prefix lemma, v2 (worker Z6, graph link X13). DRAFT: NOT RUN. No HOL process was started.
   Nothing in this file is proved until a run ends with exit 0, marker EXACT_COMPLETE, no LEMMA_FAILED,
   no UNEXPECTED_CONTROL_ACCEPTANCE, the tag check and exactly four CLOSURE_AXIOM lines.
   Base: Y4 draft prefix_lemma_DRAFT.sml. Changes from Y4 (statements of the exported results are UNCHANGED):
     - script style of routeA-L1.sml (hol run, new_theory, thm helper with LEMMA_FAILED, no mk_thm); the
       goal and the tactic are thunks, so a failure in one lemma cannot stop the run before the report;
     - the mutual key lemma is proved through two predicate constants lexP / lexPs and four step lemmas, with
       the STORED induction theorem mlsexp$sexp_to_app_list_ind (its exact form read from
       CK/basis/pure/.hol/docs/mlsexpTheory.html):
         !P0 P1. (!s. P0 (Atom s)) /\ (!l. P1 l ==> P0 (Expr l)) /\ P1 [] /\
                 (!v vs. (NULL vs ==> P0 v) /\ (~NULL vs ==> P0 v) /\ (~NULL vs ==> P1 vs) ==> P1 (v::vs))
                 ==> (!v0. P0 v0) /\ !v0. P1 v0
       (NOT sexp_induction: that one is the MEM form for the nested type, not mutual);
     - the quoted-atom case uses a new one-character lemma read_string_aux_char_escaped instead of a
       four-escape case explosion;
     - one STRICT split lemma prefix_append_strict replaces Y4's isPREFIX_APPEND_CASES;
     - several alternatives per hard step (try_all); the first alternative that closes ALL goals is used.
   Exported results (exact statements; Y4's, unchanged):
     lex_aux_prefix_ISL, sexp_to_string_Expr_prefix_free, refund_render_fields_prefix_free,
     refund_strict_parse_no_strict_prefix, refund_strict_parse_complete (P0), N1, N2, N3.
   Kind: MODEL (HOL functions only). Says nothing about the real process, the pipe, or the native relation.
   Test of a mirror (NOT a proof): Z6/mirror_prefix_test.py, 605 rendered results, 78,357 strict prefixes,
   0 accepted; key-lemma mirror at depths 1 and 2 on 155,504 prefixes, 0 violations. *)
open preamble mlsexpTheory mlstringTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (500, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundPrefixFree";
val failed = ref ([] : string list);
val problems = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
(* goal and tactic are thunks: a parse error or a failed derived rule becomes LEMMA_FAILED, not a stop. *)
fun thm name goalf tacf = (let val g = goalf () val th = save_thm (name, Tactical.TAC_PROOF (([], g), tacf ())) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
(* the first alternative that closes every goal wins; if none does, print what the first one leaves *)
fun try_all name tacs =
  FIRST (map (fn t => t \\ NO_TAC) tacs)
  ORELSE (hd tacs \\ show_tac ("REMAINING " ^ name) \\ NO_TAC);
fun defn name q = (let val th = Define q in pr ("DEFINITION " ^ name ^ "\n" ^ thm_to_string th); th end)
  handle e => (pr ("DEFINITION_FAILED " ^ name ^ " " ^ General.exnMessage e); raise e);
val sp_open  = EVAL ``isSpace #"("``;
val sp_close = EVAL ``isSpace #")"``;
val sp_quote = EVAL ``isSpace #"\""``;
val sp_space = EVAL ``isSpace #" "``;
val sp_bs    = EVAL ``isSpace #"\\"``;
val SPS = [sp_open, sp_close, sp_quote, sp_space, sp_bs];
val _ = List.app (fn th => pr ("EVAL " ^ thm_to_string th)) SPS;
fun WP n = DB.fetch "forge_refundWireProg" n;
fun IO n = DB.fetch "forge_refund_io" n;
val render_def = WP "refund_render_fields_def";
val roundtrip  = WP "refund_render_fields_roundtrip";
val response_def = IO "refund_response_def";
val _ = List.app (fn (n, th) => pr ("USED " ^ n ^ "\n" ^ thm_to_string th))
  [("refund_render_fields_def", render_def), ("refund_render_fields_roundtrip", roundtrip),
   ("refund_response_def", response_def), ("sexp_to_app_list_ind", sexp_to_app_list_ind),
   ("lex_aux_sexp_to_list", lex_aux_sexp_to_list), ("read_string_aux_thm", read_string_aux_thm),
   ("read_symbol_thm", read_symbol_thm), ("make_str_safe_def", make_str_safe_def)];

(* ================= list helpers ================= *)
val PAS = thm "prefix_append_strict"
  (fn () => ``!a b (p:'a list). p <<= a ++ b <=> (p <<= a /\ p <> a) \/ ?q. p = a ++ q /\ q <<= b``)
  (fn () => Induct >- simp[] \\ rpt gen_tac \\ Cases_on `p` \\
     try_all "prefix_append_strict" [simp[] \\ metis_tac[], gvs[] \\ metis_tac[], rw[EQ_IMP_THM] \\ gvs[] \\ metis_tac[]]);

(* ================= printing equations (variables only; no concrete unfolding) ================= *)
val EQS = thm "sexp_print_eqs"
  (fn () => ``(!m. explode (concat (append (sexp_to_app_list (Atom m)))) = explode (make_str_safe m)) /\
     (!l. explode (concat (append (sexp_to_app_list (Expr l)))) =
          "(" ++ explode (concat (append (sexps_to_app_list l))) ++ ")") /\
     (explode (concat (append (sexps_to_app_list []))) = "") /\
     (!v vs. explode (concat (append (sexps_to_app_list (v::vs)))) =
          if NULL vs then explode (concat (append (sexp_to_app_list v)))
          else explode (concat (append (sexp_to_app_list v))) ++ " " ++
               explode (concat (append (sexps_to_app_list vs))))``)
  (fn () => try_all "sexp_print_eqs"
     [rw[sexp_to_app_list_def, concat_thm],
      rpt conj_tac \\ rpt gen_tac \\ simp[Once sexp_to_app_list_def, concat_thm] \\ rw[],
      rpt conj_tac \\ rpt gen_tac \\ simp[Once sexp_to_app_list_def, concat_def] \\ rw[] \\
        TRY (Cases_on `make_str_safe m`) \\ simp[]]);

(* ================= atoms ================= *)
val RSN = thm "read_symbol_safe_nil"
  (fn () => ``!t acc. EVERY is_safe_char t ==> read_symbol t acc = (implode (REVERSE acc ++ t), [])``)
  (fn () => try_all "read_symbol_safe_nil"
     [rpt strip_tac \\ qspecl_then [`t`,`""`,`acc`] mp_tac read_symbol_thm \\ simp[],
      Induct \\ simp[read_symbol_def] \\ rw[] \\ gvs[is_safe_char_def] \\ simp_tac std_ss [GSYM APPEND_ASSOC, APPEND]]);

val RCE = thm "read_string_aux_char_escaped"
  (fn () => ``!h u acc. read_string_aux (char_escaped h ++ u) acc = read_string_aux u (h::acc)``)
  (fn () => try_all "read_string_aux_char_escaped"
     [rpt gen_tac \\ gvs[char_escaped_def, char_escape_seq_def] \\ rw[] \\ gvs[read_string_aux_def],
      rpt gen_tac \\ simp[char_escaped_def, char_escape_seq_def] \\ rpt (IF_CASES_TAC \\ gvs[]) \\
        simp[read_string_aux_def],
      rpt gen_tac \\ Cases_on `char_escape_seq h` \\ gvs[char_escaped_def, char_escape_seq_def, AllCaseEqs()] \\
        simp[read_string_aux_def]]);

val CSP = thm "char_escaped_strict_prefix"
  (fn () => ``!h u acc. u <<= char_escaped h /\ u <> char_escaped h ==> ISL (read_string_aux u acc)``)
  (fn () => try_all "char_escaped_strict_prefix"
     [rpt gen_tac \\ simp[char_escaped_def, char_escape_seq_def] \\ rw[] \\ gvs[listTheory.isPREFIX_CONSR] \\
        simp[read_string_aux_def],
      rpt gen_tac \\ Cases_on `char_escape_seq h` \\ gvs[char_escaped_def, char_escape_seq_def, AllCaseEqs()] \\
        strip_tac \\ gvs[listTheory.isPREFIX_CONSR] \\ simp[read_string_aux_def],
      rpt gen_tac \\ simp[char_escaped_def, char_escape_seq_def] \\ rw[] \\
        Cases_on `u` \\ gvs[] \\ TRY (Cases_on `t`) \\ gvs[] \\ simp[read_string_aux_def]]);

(* a strict prefix of an escaped body plus its closing quote never closes the string *)
val RSP = thm "read_string_aux_strict_prefix"
  (fn () => ``!xs u acc. u <<= FLAT (MAP char_escaped xs) ++ "\"" /\ u <> FLAT (MAP char_escaped xs) ++ "\"" ==>
                ISL (read_string_aux u acc)``)
  (fn () => Induct
     >- (rpt gen_tac \\ Cases_on `u` \\ simp[read_string_aux_def] \\ rpt strip_tac \\ gvs[])
     \\ rpt gen_tac \\ strip_tac
     \\ `u <<= char_escaped h ++ (FLAT (MAP char_escaped xs) ++ "\"")` by fs[]
     \\ qpat_x_assum `u <<= char_escaped h ++ _` (strip_assume_tac o REWRITE_RULE [PAS])
     >- metis_tac[CSP]
     \\ gvs[RCE]
     \\ first_x_assum irule \\ fs[]);

val ATOM = thm "atom_prefix_ISL"
  (fn () => ``!m p d ts. d <> 0 /\ p <<= explode (make_str_safe m) ==> ISL (lex_aux d p ts)``)
  (fn () => rpt gen_tac \\ strip_tac
     \\ qpat_x_assum `_ <<= _` mp_tac
     \\ simp[make_str_safe_def] \\ IF_CASES_TAC
     >- (try_all "atom_empty"
           [strip_tac \\ gvs[listTheory.isPREFIX_CONSR] \\ simp(SPS @ [lex_aux_def, read_string_def, read_string_aux_def]),
            strip_tac \\ Cases_on `p` \\ gvs[] \\ TRY (Cases_on `t`) \\ gvs[] \\
              simp(SPS @ [lex_aux_def, read_string_def, read_string_aux_def])])
     \\ IF_CASES_TAC
     >- ((* every character is safe: a bare symbol *)
         strip_tac
         \\ `EVERY is_safe_char (explode m)` by
              (try_all "atom_safe_every" [drule str_every_thm \\ simp[listTheory.EVERY_EL],
                                          dxrule str_every_thm \\ Cases_on `m` \\ simp[listTheory.EVERY_EL]])
         \\ `EVERY is_safe_char p` by
              (try_all "atom_safe_prefix" [metis_tac[rich_listTheory.IS_PREFIX_APPEND, listTheory.EVERY_APPEND],
                                           fs[rich_listTheory.IS_PREFIX_APPEND] \\ fs[listTheory.EVERY_APPEND]])
         \\ Cases_on `p` >- simp[lex_aux_def]
         \\ `is_safe_char h /\ EVERY is_safe_char t` by fs[]
         \\ `~isSpace h /\ h <> #"(" /\ h <> #")" /\ h <> #"\""` by fs[is_safe_char_def]
         \\ simp[Once lex_aux_def, RSN] \\ simp[lex_aux_def])
     \\ (* quoted atom *)
     simp[escape_str_def] \\ strip_tac
     \\ Cases_on `p` >- simp[lex_aux_def]
     \\ gvs[]
     \\ simp(Once lex_aux_def :: read_string_def :: SPS)
     \\ Cases_on `t = FLAT (MAP char_escaped (explode m)) ++ "\""`
     >- (qspecl_then [`explode m`,`""`,`[]`] mp_tac read_string_aux_thm \\ simp[] \\ rpt strip_tac \\
         gvs[] \\ simp[lex_aux_def])
     \\ `ISL (read_string_aux t [])` by metis_tac[RSP]
     \\ try_all "atom_quoted_strict"
          [Cases_on `read_string_aux t []` \\ gvs[] \\ rename1 `INL z` \\ Cases_on `z` \\ simp[],
           every_case_tac \\ gvs[]]);

(* ================= KEY LEMMA through predicate constants ================= *)
val lexP_def = defn "lexP" `lexP x <=> !p d ts. d <> 0 /\ p <<= explode (concat (append (sexp_to_app_list x))) ==>
                                          ISL (lex_aux d p ts)`;
val lexPs_def = defn "lexPs" `lexPs xs <=> !p d ts. d <> 0 /\ p <<= explode (concat (append (sexps_to_app_list xs))) ==>
                                          ISL (lex_aux d p ts)`;

val S_ATOM = thm "lexP_Atom" (fn () => ``!s. lexP (Atom s)``)
  (fn () => rw[lexP_def, EQS] \\ metis_tac[ATOM]);

val S_NIL = thm "lexPs_nil" (fn () => ``lexPs []``)
  (fn () => rw[lexPs_def, EQS] \\ gvs[] \\ simp[lex_aux_def]);

val S_EXPR = thm "lexP_Expr" (fn () => ``!l. lexPs l ==> lexP (Expr l)``)
  (fn () => rw[lexP_def, lexPs_def, EQS]
     \\ Cases_on `p` >- simp[lex_aux_def]
     \\ gvs[]
     \\ simp(Once lex_aux_def :: SPS)
     \\ qpat_x_assum `_ <<= _ ++ _` (strip_assume_tac o REWRITE_RULE [PAS])
     >- (first_x_assum irule \\ simp[])
     \\ Cases_on `q` >- (gvs[] \\ first_x_assum irule \\ simp[])
     \\ gvs[]
     \\ try_all "lexP_Expr_close"
          [DEP_REWRITE_TAC [CONJUNCT2 lex_aux_sexp_to_list] \\ simp[] \\
             simp(Once lex_aux_def :: SPS) \\ simp[lex_aux_def],
           qmatch_goalsub_abbrev_tac `lex_aux (d + 1) (E ++ ")") TS` \\
             qspecl_then [`l`,`")"`,`TS`,`d + 1`] mp_tac (CONJUNCT2 lex_aux_sexp_to_list) \\
             simp[Abbr `E`] \\ disch_then (fn th => rewrite_tac [th]) \\
             simp(Once lex_aux_def :: SPS) \\ simp[lex_aux_def]]);

val S_CONS = thm "lexPs_cons"
  (fn () => ``!v vs. (NULL vs ==> lexP v) /\ (~NULL vs ==> lexP v) /\ (~NULL vs ==> lexPs vs) ==> lexPs (v::vs)``)
  (fn () => rpt gen_tac \\ strip_tac \\ Cases_on `NULL vs`
     >- (gvs[] \\ fs[lexP_def, lexPs_def, EQS])
     \\ gvs[] \\ fs[lexP_def, lexPs_def, EQS] \\ rpt strip_tac
     \\ qpat_x_assum `_ <<= _ ++ _` (strip_assume_tac o REWRITE_RULE [PAS])
     >- metis_tac[]
     \\ Cases_on `q` >- (gvs[] \\ metis_tac[listTheory.isPREFIX_REFL])
     \\ gvs[]
     \\ try_all "lexPs_cons_space"
          [DEP_REWRITE_TAC [CONJUNCT1 lex_aux_sexp_to_list] \\ simp SPS \\
             simp(Once lex_aux_def :: SPS) \\ metis_tac[],
           qmatch_goalsub_abbrev_tac `lex_aux d (E ++ #" " :: t) ts` \\
             qspecl_then [`v`,`#" " :: t`,`ts`,`d`] mp_tac (CONJUNCT1 lex_aux_sexp_to_list) \\
             simp(Abbr `E` :: SPS) \\ disch_then (fn th => rewrite_tac [th]) \\
             simp(Once lex_aux_def :: SPS) \\ metis_tac[]]);

val PRED = thm "lexP_all" (fn () => ``(!x. lexP x) /\ (!xs. lexPs xs)``)
  (fn () => ho_match_mp_tac sexp_to_app_list_ind \\
     try_all "lexP_all"
       [rpt conj_tac \\ FIRST (map MATCH_ACCEPT_TAC [S_ATOM, S_EXPR, S_NIL, S_CONS]),
        metis_tac[S_ATOM, S_EXPR, S_NIL, S_CONS],
        simp[S_ATOM, S_EXPR, S_NIL, S_CONS]]);

(* Y4's statement, unchanged *)
val KEY = thm "lex_aux_prefix_ISL"
  (fn () => ``(!x p d ts. d <> 0 /\ p <<= explode (concat (append (sexp_to_app_list x))) ==> ISL (lex_aux d p ts)) /\
              (!xs p d ts. d <> 0 /\ p <<= explode (concat (append (sexps_to_app_list xs))) ==> ISL (lex_aux d p ts))``)
  (fn () => try_all "lex_aux_prefix_ISL"
     [assume_tac PRED \\ fs[lexP_def, lexPs_def],
      metis_tac[PRED, lexP_def, lexPs_def],
      conj_tac \\ rpt gen_tac \\ strip_tac \\ metis_tac[PRED, lexP_def, lexPs_def]]);

(* ================= from lexing to parsing ================= *)
val PL = thm "parse_ISL_of_lex" (fn () => ``!s. ISL (lex s) ==> ISL (parse s)``)
  (fn () => try_all "parse_ISL_of_lex"
     [rw[parse_def] \\ every_case_tac \\ gvs[],
      rw[parse_def] \\ Cases_on `lex s` \\ gvs[] \\ rename1 `INL z` \\ Cases_on `z` \\ simp[]]);

val EXPR_PF = thm "sexp_to_string_Expr_prefix_free"
  (fn () => ``!xs p. p <<= explode (sexp_to_string (Expr xs)) /\ p <> explode (sexp_to_string (Expr xs)) ==>
                     ISL (parse p)``)
  (fn () => rpt gen_tac \\ simp[sexp_to_string_def, EQS] \\ strip_tac
     \\ Cases_on `p` >- simp[parse_def, lex_def, lex_aux_def, parse_aux_def]
     \\ gvs[]
     \\ irule PL \\ simp(lex_def :: Once lex_aux_def :: SPS)
     \\ `(1:num) <> 0` by simp[]
     \\ qpat_x_assum `_ <<= _ ++ _` (strip_assume_tac o REWRITE_RULE [PAS])
     >- metis_tac[KEY]
     \\ Cases_on `q` >- (gvs[] \\ metis_tac[KEY, listTheory.isPREFIX_REFL])
     \\ gvs[]);

val RENDER_PF = thm "refund_render_fields_prefix_free"
  (fn () => ``!f p. p <<= explode (refund_render_fields f) /\ p <> explode (refund_render_fields f) ==> ISL (parse p)``)
  (fn () => try_all "refund_render_fields_prefix_free"
     [rpt gen_tac \\ PairCases_on `f` \\ simp[render_def, response_def] \\ metis_tac[EXPR_PF],
      rpt gen_tac \\ `?xs. refund_render_fields f = sexp_to_string (Expr xs)` by
          (PairCases_on `f` \\ simp[render_def, response_def]) \\ simp[] \\ metis_tac[EXPR_PF],
      rpt gen_tac \\ PairCases_on `f` \\ rewrite_tac[render_def] \\ simp[response_def] \\ strip_tac \\
          drule_all EXPR_PF \\ simp[]]);

(* ================= the STRICT parser (Y4's definition, unchanged) ================= *)
val strict_def = defn "refund_strict_parse"
  `refund_strict_parse (s : string) =
     case parse s of
     | INL _ => NONE
     | INR (se, rest) =>
         if rest <> [] then NONE else
         case refund_response_fields se of
         | INL _ => NONE
         | INR f => if explode (refund_render_fields f) = s then SOME f else NONE`;

val NSP = thm "refund_strict_parse_no_strict_prefix"
  (fn () => ``!f p. p <<= explode (refund_render_fields f) /\ p <> explode (refund_render_fields f) ==>
                    refund_strict_parse p = NONE``)
  (fn () => rpt strip_tac \\ drule_all RENDER_PF \\ simp[strict_def] \\
     try_all "refund_strict_parse_no_strict_prefix"
       [Cases_on `parse p` \\ gvs[],
        strip_tac \\ Cases_on `parse p` \\ fs[],
        every_case_tac \\ gvs[]]);

(* POSITIVE CONTROL P0 (needed: the parser \s. NONE also satisfies the lemma above) *)
val P0 = thm "refund_strict_parse_complete"
  (fn () => ``!f. refund_strict_parse (explode (refund_render_fields f)) = SOME f``)
  (fn () => try_all "refund_strict_parse_complete"
     [rpt gen_tac \\ PairCases_on `f` \\ simp[strict_def, roundtrip],
      Cases \\ PairCases_on `r` \\ simp[strict_def, roundtrip]]);

(* ================= NEGATIVE CONTROLS (each is PROVED as stated; each is a falsity of a weakened claim) ======= *)
(* N1: a frame with a trailing newline is NOT prefix-free: the frame itself is a strict prefix that parses. *)
val N1 = thm "N1_trailing_newline_breaks"
  (fn () => ``~(!f p. p <<= explode (refund_render_fields f) ++ "\n" /\
                      p <> explode (refund_render_fields f) ++ "\n" ==> ISL (parse p))``)
  (fn () => strip_tac \\
     first_x_assum (qspecl_then [`(T,40,«returned_item»,«c»,«r»,1)`,
                                 `explode (refund_render_fields (T,40,«returned_item»,«c»,«r»,1))`] mp_tac) \\
     simp[roundtrip, listTheory.APPEND_EQ_SELF]);
(* N2: a top-level ATOM is NOT prefix-free ("ab" is a strict prefix of "abc" and parses). *)
val N2 = thm "N2_atom_breaks"
  (fn () => ``parse "ab" = INR (Atom «ab», "") /\ "ab" <<= explode (sexp_to_string (Atom «abc»)) /\
              "ab" <> explode (sexp_to_string (Atom «abc»))``)
  (fn () => EVAL_TAC);
(* N3: the key lemma is FALSE without d <> 0. *)
val N3 = thm "N3_depth0_breaks"
  (fn () => ``~(!x p (d:num) ts. p <<= explode (concat (append (sexp_to_app_list x))) ==> ISL (lex_aux d p ts))``)
  (fn () => strip_tac \\ first_x_assum (qspecl_then [`Atom «a»`, `"a"`, `0`, `[]`] mp_tac) \\ EVAL_TAC);

(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
fun lit name th tm = if aconv (concl th) tm then pr ("CONTROL_OK " ^ name ^ " statement is the literal planned statement")
                     else bad (name ^ "-literal");
val _ = lit "refund_strict_parse_no_strict_prefix" NSP
  ``!f p. p <<= explode (refund_render_fields f) /\ p <> explode (refund_render_fields f) ==> refund_strict_parse p = NONE``;
val _ = lit "refund_strict_parse_complete" P0 ``!f. refund_strict_parse (explode (refund_render_fields f)) = SOME f``;
val _ = if is_neg (concl N1) then pr "CONTROL_OK N1 is a proved negation" else bad "N1-not-negation";
val _ = if is_neg (concl N3) then pr "CONTROL_OK N3 is a proved negation" else bad "N3-not-negation";
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundPrefixFree" @ DB.definitions "forge_refundPrefixFree");
val closure = "forge_refundPrefixFree" :: Theory.ancestry "forge_refundPrefixFree";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundPrefixFree")));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions "forge_refundPrefixFree")));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

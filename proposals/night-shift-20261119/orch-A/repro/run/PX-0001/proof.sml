(* Exact acceptance set of refund_strict_parse, v1 (worker A15 of Orchestrator A, 2026-11-19).
   DRAFT: NOT RUN. No HOL process was started by A15. Every tactic below is UNCHECKED.
   Parent: theory forge_refundPrefixFree (case PF-0004, actual exit 0, EXACT_COMPLETE;
     .sig SHA-256 c99effd1...45d7, .sml fcf9f056...0fb4, .dat bddae16a...cdce7 per PF-0004.run.json).
   Purpose: the reviewer's MISSING item (review-PF/REPORT.md line 12): no stored theorem says that an
     over-long output (render f ++ junk, junk <> "") is rejected.
   Harness: the helper block of PF-0004.sml (pr with flush, tags, show_tac, ST, CL, try_all, thm with BEGIN
     lines, failed lemma -> ASSUME, DIAG_OK_UNDER, FAILED_LIST, tag check, 4 bool axioms, chDir to FORGE_P3_OUT,
     EXACT_COMPLETE only after export_theory). Not copied (unused here): useI, defn, the isSpace EVALs.
   Definition used (PF-0004 stdout.log, DEFINITION refund_strict_parse):
     refund_strict_parse s = case parse s of INL v1 => NONE
        | INR (se,rest) => if rest <> "" then NONE else
            case refund_response_fields se of INL v => NONE
            | INR f => if explode (refund_render_fields f) = s then SOME f else NONE
   The last line is a re-render check in char-list form (explode ... = s), so X1 holds as stated
   (no implode / mlstring adaptation needed).
   Exported (9 theorems, 0 definitions):
     refund_strict_parse_SOME_render (helper), refund_strict_parse_exact (X1),
     refund_strict_parse_accepts_only_one_frame (X3), refund_strict_parse_rejects_extension (X2),
     refund_frame_decision (X4), refund_strict_parse_witness (control C1),
     refund_strict_parse_not_reject_all (control C2), refund_frame_decision_needs_prefix (control C3),
     refund_strict_parse_extension_needs_nonempty (control C4).
   Kind: MODEL (HOL functions only). Says nothing about the real process, the pipe, or the native relation. *)
open preamble mlsexpTheory mlstringTheory;
val _ = Globals.max_print_depth := 60;
val _ = metisTools.limit := {time = SOME 30.0, infs = NONE};
fun pr s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut);
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun trunc n s = if size s <= n then s else String.substring (s, 0, n) ^ " ...";
fun showg tag (asl, w) = (pr ("SHOW " ^ tag);
   List.app (fn a => pr ("  ASM " ^ trunc 700 (term_to_string a))) asl;
   pr ("  GOAL " ^ trunc 3000 (term_to_string w)));
fun show_tac tag g = (showg tag g; ALL_TAC g);
(* In this HOL, tactic = goal -> Context.t -> goal list * validation (HOL/src/1/Abbrev.sig:10). *)
fun ST tag tac g ctxt = tac g ctxt
  handle e => (showg ("STAGE_FAILED " ^ tag ^ " : " ^ trunc 300 (General.exnMessage e)) g; raise e);
fun CL tag tac g ctxt =
  let val r as (gs, _) = ST tag tac g ctxt in
    if null gs then r
    else (List.app (showg ("UNSOLVED " ^ tag)) gs; raise mk_HOL_ERR "A15" "CL" ("unsolved goals at " ^ tag))
  end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundPrefixExact";
val failed = ref ([] : string list);
val problems = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
val failed_stmts = ref ([] : (string * term) list);
val diag = ref ([] : string list);
fun names_of_hyps th = map (fn h => case List.find (fn (_, t) => aconv t h) (!failed_stmts) of
                                      SOME (n, _) => n | NONE => "?" ^ trunc 80 (term_to_string h)) (hyp th);
fun thm name goalf tacf =
  let val _ = pr ("BEGIN " ^ name)
      val g = goalf ()
      fun fail_with msg = (pr ("LEMMA_FAILED " ^ name ^ " " ^ msg); failed := name :: !failed;
                           failed_stmts := (name, g) :: !failed_stmts; ASSUME g)
  in
    (let val th0 = Tactical.TAC_PROOF (([], g), tacf ()) in
       if null (hyp th0) then (let val th = save_thm (name, th0) in chk name th; th end)
       else (pr ("DIAG_OK_UNDER " ^ name ^ " assumed: " ^ String.concatWith " " (names_of_hyps th0));
             diag := name :: !diag; fail_with "(diagnostic only: proved only under the failed lemmas above)")
     end)
    handle e => fail_with (General.exnMessage e)
  end
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " (statement) " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
fun try_all name tacs g ctxt =
  FIRST (map (fn t => t \\ NO_TAC) tacs) g ctxt
  handle _ => (showg ("TRY_ALL_ENTRY " ^ name) g; (hd tacs \\ show_tac ("REMAINING " ^ name) \\ NO_TAC) g ctxt);

(* ================= parent results (names exactly as in forge_refundPrefixFreeTheory.sig) ================= *)
fun PFX n = DB.fetch "forge_refundPrefixFree" n;
val strict_def = PFX "refund_strict_parse_def";
val NSP   = PFX "refund_strict_parse_no_strict_prefix";
val P0    = PFX "refund_strict_parse_complete";
val PCODE = PFX "refund_render_fields_prefix_code";
val _ = List.app (fn (n, th) => pr ("USED " ^ n ^ "\n" ^ thm_to_string th))
  [("refund_strict_parse_def", strict_def), ("refund_strict_parse_no_strict_prefix", NSP),
   ("refund_strict_parse_complete", P0), ("refund_render_fields_prefix_code", PCODE)];
(* the imported statements must be the ones this script was written against (PF-0004 stdout.log) *)
fun imp name th tm = if aconv (concl th) tm then pr ("IMPORTED_OK " ^ name) else bad (name ^ "-import-mismatch");
val _ = imp "refund_strict_parse_complete" P0 ``!f. refund_strict_parse (explode (refund_render_fields f)) = SOME f``;
val _ = imp "refund_render_fields_prefix_code" PCODE
  ``!f g. explode (refund_render_fields g) <<= explode (refund_render_fields f) ==> g = f``;
val _ = imp "refund_strict_parse_no_strict_prefix" NSP
  ``!f p. p <<= explode (refund_render_fields f) /\ p <> explode (refund_render_fields f) ==> refund_strict_parse p = NONE``;
val _ = if mem "forge_refundPrefixFree" (Theory.ancestry "forge_refundPrefixExact")
        then pr "PARENT_OK forge_refundPrefixFree" else bad "parent-missing";

(* ================= H: every accepted string is the rendering of the decoded value ================= *)
(* Hand walk (primary), against the printed definition:
   goal  refund_strict_parse s = SOME f ==> s = explode (refund_render_fields f)
   simp[strict_def]: (case parse s of INL v1 => NONE | INR (se,rest) => if rest <> "" then NONE else
                      case refund_response_fields se of INL v => NONE
                      | INR f' => if explode (refund_render_fields f') = s then SOME f' else NONE) = SOME f ==> ...
   rpt TOP_CASE_TAC: splits parse s (INL/INR), the pair (se,rest), the guard on rest, the field decode, and the
     re-render guard (BasicProvers.sml 1065: case splits include is_cond). Leaves:
     NONE = SOME f ==> ...   (four leaves)   and
     [explode (refund_render_fields f') = s]  SOME f' = SOME f ==> s = explode (refund_render_fields f).
   rpt strip_tac \\ gvs[]: NONE = SOME f is F; SOME_11 gives f' = f; the assumption eliminates s; goal closes. *)
val SOMER = thm "refund_strict_parse_SOME_render"
  (fn () => ``!s f. refund_strict_parse s = SOME f ==> s = explode (refund_render_fields f)``)
  (fn () => try_all "refund_strict_parse_SOME_render"
     [rpt gen_tac \\ ST "somer.unfold" (simp[strict_def]) \\ rpt BasicProvers.TOP_CASE_TAC \\
        rpt strip_tac \\ gvs[],
      rpt gen_tac \\ simp[strict_def] \\ every_case_tac \\ rpt strip_tac \\ gvs[],
      rpt gen_tac \\ simp[strict_def] \\ Cases_on `parse s` \\ simp[] \\ rename1 `parse s = INR y` \\
        PairCases_on `y` \\ simp[] \\ Cases_on `y1` \\ simp[] \\
        Cases_on `refund_response_fields y0` \\ simp[] \\ IF_CASES_TAC \\ rpt strip_tac \\ gvs[],
      rpt strip_tac \\ gvs[strict_def, AllCaseEqs()]]);

(* ================= X1: the exact acceptance set ================= *)
(* Hand walk: eq_tac gives
     (1) refund_strict_parse s = SOME f ==> s = explode (refund_render_fields f)   : SOMER, verbatim (MATCH_ACCEPT_TAC);
     (2) s = explode (refund_render_fields f) ==> refund_strict_parse s = SOME f    : disch_then SUBST1_TAC gives
         refund_strict_parse (explode (refund_render_fields f)) = SOME f            : P0, verbatim. *)
val X1 = thm "refund_strict_parse_exact"
  (fn () => ``!s f. (refund_strict_parse s = SOME f) <=> (s = explode (refund_render_fields f))``)
  (fn () => try_all "refund_strict_parse_exact"
     [rpt gen_tac \\ eq_tac
        >- ST "x1.only_if" (MATCH_ACCEPT_TAC SOMER)
        \\ ST "x1.if" (disch_then SUBST1_TAC \\ MATCH_ACCEPT_TAC P0),
      metis_tac[SOMER, P0]]);

(* ================= X3: an extended rendering is accepted only if the extension is empty ================= *)
(* Hand walk (primary):
   goal  refund_strict_parse (explode (refund_render_fields f) ++ j) = SOME g ==> j = "" /\ g = f
   disch_then (assume_tac o MATCH_MP SOMER):
     [EQ: explode (refund_render_fields f) ++ j = explode (refund_render_fields g)]  j = "" /\ g = f
   by-step: goal explode (refund_render_fields f) <<= explode (refund_render_fields g);
     SUBST1_TAC (SYM EQ) gives explode (rrf f) <<= explode (rrf f) ++ j : IS_PREFIX_APPEND3 (!c a. a <<= a ++ c,
     rich_listScript.sml 3124-3128).
   qpat_x_assum _ <<= _ (assume_tac o MATCH_MP PCODE): PCODE with its f := g, g := f gives f = g.
   pop_assum SUBST_ALL_TAC (f := g): [EQ: explode (rrf g) ++ j = explode (rrf g)]  j = "" /\ g = g
   REWRITE_RULE [APPEND_EQ_SELF] EQ (listScript.sml 1109-1110, first conjunct) gives j = []; SUBST1_TAC gives
     [] = "" /\ g = g; "" is [] (PF-0004 printed rest <> [] as rest ≠ ""), so REWRITE_TAC [] closes. *)
val X3 = thm "refund_strict_parse_accepts_only_one_frame"
  (fn () => ``!f g j. refund_strict_parse (explode (refund_render_fields f) ++ j) = SOME g ==> j = "" /\ g = f``)
  (fn () => try_all "refund_strict_parse_accepts_only_one_frame"
     [rpt gen_tac \\ disch_then (assume_tac o MATCH_MP SOMER)
        \\ `explode (refund_render_fields f) <<= explode (refund_render_fields g)` by
             try_all "x3.prefix"
               [qpat_x_assum `_ = explode (refund_render_fields g)` (SUBST1_TAC o SYM) \\
                  MATCH_ACCEPT_TAC rich_listTheory.IS_PREFIX_APPEND3,
                qpat_x_assum `_ ++ _ = _` (fn th => rewrite_tac [GSYM th, rich_listTheory.IS_PREFIX_APPEND3]),
                metis_tac[rich_listTheory.IS_PREFIX_APPEND3]]
        \\ ST "x3.code" (qpat_x_assum `_ <<= _` (assume_tac o MATCH_MP PCODE))
        \\ ST "x3.subst" (pop_assum SUBST_ALL_TAC)
        \\ try_all "x3.tail"
             [qpat_x_assum `_ ++ _ = _` (SUBST1_TAC o REWRITE_RULE [listTheory.APPEND_EQ_SELF]) \\ REWRITE_TAC [],
              gvs[listTheory.APPEND_EQ_SELF]],
      rpt gen_tac \\ strip_tac \\ drule SOMER \\ strip_tac \\
        `f = g` by (irule PCODE \\ qpat_x_assum `_ ++ _ = _` (fn th => rewrite_tac [GSYM th]) \\
                    simp[rich_listTheory.IS_PREFIX_APPEND3]) \\
        gvs[listTheory.APPEND_EQ_SELF]]);

(* ================= X2: an over-long output is rejected ================= *)
(* Hand walk (primary):
   [j <> ""]  refund_strict_parse (explode (rrf f) ++ j) = NONE
   Cases_on the call: NONE branch goal NONE = NONE (simp[] closes);
     SOME x branch: [j <> "", call = SOME x]  SOME x = NONE; simp[] gives F.
   MATCH_MP X3 on the call assumption gives j = "" /\ x = f; strip_assume_tac adds j = "" (OPPOSITE_TAC may close
   against j <> "" at once); gvs[] closes what remains ("" <> "" is F). *)
val X2 = thm "refund_strict_parse_rejects_extension"
  (fn () => ``!f j. j <> "" ==> refund_strict_parse (explode (refund_render_fields f) ++ j) = NONE``)
  (fn () => try_all "refund_strict_parse_rejects_extension"
     [rpt strip_tac \\ Cases_on `refund_strict_parse (explode (refund_render_fields f) ++ j)` \\ simp[]
        \\ qpat_x_assum `refund_strict_parse _ = SOME _` (strip_assume_tac o MATCH_MP X3) \\ gvs[],
      rpt strip_tac \\ Cases_on `refund_strict_parse (explode (refund_render_fields f) ++ j)` \\ simp[]
        \\ drule X3 \\ rpt strip_tac \\ gvs[],
      metis_tac[X3, optionTheory.option_nchotomy]]);

(* ================= X4: consumer-facing decision ================= *)
(* Hand walk (primary):
   [P: out <<= explode (rrf f); A: refund_strict_parse out = SOME g]  out = explode (rrf f) /\ g = f
   qpat_assum A (assume_tac o MATCH_MP SOMER): new out = explode (rrf g); pop_assum SUBST_ALL_TAC:
     [explode (rrf g) <<= explode (rrf f); refund_strict_parse (explode (rrf g)) = SOME g]
     explode (rrf g) = explode (rrf f) /\ g = f
   MATCH_MP PCODE on the prefix assumption gives g = f (PCODE verbatim); pop_assum SUBST_ALL_TAC (g := f):
     explode (rrf f) = explode (rrf f) /\ f = f; REWRITE_TAC [] closes.
   The variable name out is bound in the statement; no tactic names it (a constant out cannot capture it). *)
val X4 = thm "refund_frame_decision"
  (fn () => ``!f out g. out <<= explode (refund_render_fields f) /\ refund_strict_parse out = SOME g ==>
                        out = explode (refund_render_fields f) /\ g = f``)
  (fn () => try_all "refund_frame_decision"
     [rpt gen_tac \\ strip_tac
        \\ ST "x4.render" (qpat_assum `refund_strict_parse _ = SOME _` (assume_tac o MATCH_MP SOMER))
        \\ ST "x4.subst1" (pop_assum SUBST_ALL_TAC)
        \\ ST "x4.code" (qpat_x_assum `_ <<= _` (assume_tac o MATCH_MP PCODE))
        \\ ST "x4.subst2" (pop_assum SUBST_ALL_TAC)
        \\ REWRITE_TAC [],
      metis_tac[SOMER, PCODE],
      rpt gen_tac \\ strip_tac \\ drule SOMER \\ strip_tac \\ gvs[] \\ drule PCODE \\ simp[]]);

(* ================= CONTROLS (each is a PROVED theorem) ================= *)
(* C1: a concrete accepted string (the parser is not reject-all), via P0. *)
val C1 = thm "refund_strict_parse_witness"
  (fn () => ``refund_strict_parse (explode (refund_render_fields (T,40,«returned_item»,«c»,«r»,1))) =
              SOME (T,40,«returned_item»,«c»,«r»,1)``)
  (fn () => try_all "refund_strict_parse_witness" [MATCH_ACCEPT_TAC P0, rewrite_tac [P0], simp[P0]]);
(* C2: the parser does not reject everything (the vacuous parser \s. NONE satisfies X2 and NSP). *)
val C2 = thm "refund_strict_parse_not_reject_all"
  (fn () => ``~(!s. refund_strict_parse s = NONE)``)
  (fn () => try_all "refund_strict_parse_not_reject_all"
     [strip_tac \\ first_x_assum (qspec_then `explode (refund_render_fields (T,40,«returned_item»,«c»,«r»,1))` mp_tac)
        \\ rewrite_tac [P0, optionTheory.NOT_SOME_NONE],
      strip_tac \\ first_x_assum (qspec_then `explode (refund_render_fields (T,40,«returned_item»,«c»,«r»,1))` mp_tac)
        \\ simp[P0]]);
(* C3: X4 is FALSE without the prefix premise (a different correct frame is accepted with other fields). *)
val C3 = thm "refund_frame_decision_needs_prefix"
  (fn () => ``~(!f out g. refund_strict_parse out = SOME g ==> g = f)``)
  (fn () => try_all "refund_frame_decision_needs_prefix"
     [strip_tac \\ first_x_assum (qspecl_then [`(F,40,«returned_item»,«c»,«r»,1)`,
                                               `explode (refund_render_fields (T,40,«returned_item»,«c»,«r»,1))`,
                                               `(T,40,«returned_item»,«c»,«r»,1)`] mp_tac)
        \\ rewrite_tac [P0, pairTheory.PAIR_EQ],
      strip_tac \\ first_x_assum (qspecl_then [`(F,40,«returned_item»,«c»,«r»,1)`,
                                               `explode (refund_render_fields (T,40,«returned_item»,«c»,«r»,1))`,
                                               `(T,40,«returned_item»,«c»,«r»,1)`] mp_tac)
        \\ simp[P0]]);
(* C4: X2 is FALSE without j <> "" (j = "" gives the complete frame, which P0 accepts). *)
val C4 = thm "refund_strict_parse_extension_needs_nonempty"
  (fn () => ``~(!f j. refund_strict_parse (explode (refund_render_fields f) ++ j) = NONE)``)
  (fn () => try_all "refund_strict_parse_extension_needs_nonempty"
     [strip_tac \\ first_x_assum (qspecl_then [`(T,40,«returned_item»,«c»,«r»,1)`, `""`] mp_tac)
        \\ rewrite_tac [listTheory.APPEND_NIL, P0, optionTheory.NOT_SOME_NONE],
      strip_tac \\ first_x_assum (qspecl_then [`(T,40,«returned_item»,«c»,«r»,1)`, `""`] mp_tac) \\ simp[P0]]);

(* ================= EVAL diagnostic (NOT stored, NOT a pass condition) ================= *)
(* Computes the parser on the concrete rendering without P0. Agreement with C1 is printed as EVAL_WITNESS_AGREES. *)
val _ = (let val tm = lhs (concl C1)
             val ev = EVAL tm
         in pr ("EVAL_DIAG " ^ trunc 2000 (thm_to_string ev));
            if aconv (rhs (concl ev)) (rhs (concl C1)) then pr "EVAL_WITNESS_AGREES"
            else pr "EVAL_WITNESS_INCONCLUSIVE"
         end) handle e => pr ("EVAL_WITNESS_INCONCLUSIVE " ^ trunc 300 (General.exnMessage e));

(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = pr ("FAILED_LIST " ^ String.concatWith " " (rev (!failed)));
val _ = pr ("DIAG_OK_UNDER_LIST " ^ String.concatWith " " (rev (!diag)));
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
fun lit name th tm = if aconv (concl th) tm then pr ("CONTROL_OK " ^ name ^ " statement is the literal planned statement")
                     else bad (name ^ "-literal");
val _ = lit "refund_strict_parse_exact" X1
  ``!s f. (refund_strict_parse s = SOME f) <=> (s = explode (refund_render_fields f))``;
val _ = lit "refund_strict_parse_rejects_extension" X2
  ``!f j. j <> "" ==> refund_strict_parse (explode (refund_render_fields f) ++ j) = NONE``;
val _ = lit "refund_strict_parse_accepts_only_one_frame" X3
  ``!f g j. refund_strict_parse (explode (refund_render_fields f) ++ j) = SOME g ==> j = "" /\ g = f``;
val _ = lit "refund_frame_decision" X4
  ``!f out g. out <<= explode (refund_render_fields f) /\ refund_strict_parse out = SOME g ==>
              out = explode (refund_render_fields f) /\ g = f``;
val _ = (let val (c, _) = dest_comb (rhs (concl C1)) in
           if fst (dest_const c) = "SOME" then pr "CONTROL_OK C1 witness is accepted (SOME)" else bad "C1-not-SOME" end)
        handle _ => bad "C1-shape";
val _ = if is_neg (concl C2) then pr "CONTROL_OK C2 is a proved negation" else bad "C2-not-negation";
val _ = if is_neg (concl C3) then pr "CONTROL_OK C3 is a proved negation" else bad "C3-not-negation";
val _ = if is_neg (concl C4) then pr "CONTROL_OK C4 is a proved negation" else bad "C4-not-negation";
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundPrefixExact" @ DB.definitions "forge_refundPrefixExact");
val closure = "forge_refundPrefixExact" :: Theory.ancestry "forge_refundPrefixExact";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundPrefixExact")));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions "forge_refundPrefixExact")));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

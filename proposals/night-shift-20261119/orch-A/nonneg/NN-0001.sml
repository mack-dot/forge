(* NN-0001: non-negative integers in every frame the proved program prints (worker W-nonneg of Orchestrator A,
   2026-11-19). DRAFT: NOT RUN. No HOL process was started by W-nonneg. Every tactic below is UNCHECKED.
   Question: END_TO_END_GAPS.md T14 part b. frame.py strict_parse (CANON_INT, line 199/255) refuses a frame whose
     amount or count atom is not (0|[1-9][0-9]*); HOL refund_strict_parse (PF-0004 stdout.log line 191) accepts the
     rendering of ANY 6-tuple, also a negative one (control C1 below proves this).
   Source facts (read, not retyped into any proof; fetched with DB.fetch):
     forge_refundCertifiedProg$refund_fields_def (CertifiedProgScript.sml lines 10-16):
       refund_fields charge request original remaining enabled opened candidate amount reason =
         let ok = eligible charge request original remaining enabled opened candidate amount reason in
         (ok, (if ok then amount else 0), (if ok then reason else «»), (if ok then charge else «»),
              (if ok then request else «»), (if ok then 1:int else 0))
     forge_refund$eligible_def (forge_refundScript.sml lines 56-63) contains the conjunct 0 ≤ amount.
     So the amount field is amount (with 0 ≤ amount) or 0, and the count field is 1 or 0: no clamp is needed.
   Parents: everything comes from the session that deps-MG.txt builds (MG-0001 ran with it, exit 0):
     preload-mf.sml loads forge_refundTheory and forge_refundCertifiedProgTheory; forge_refundWireProg is in the
     ancestry of forge_refundPrefixFree (MF-0002 stdout.log line 90: CONST refund_render_fields forge_refundWireProg);
     forge_refundPrefixFree (PF-0004), forge_refundPrefixExact (PX-0001), forge_refundModelFrame (MF-0002).
   Harness: the helper block of PX-0001.sml, byte for byte except the tag "A15" -> "WNN" in CL; plus opt_thm for the
     two OPTIONAL machine-level corollaries (a failure there prints OPTIONAL_FAILED, stores nothing, and does NOT
     block the export of the core results).
   Exported (core, 7 theorems, 0 definitions):
     N1  refund_fields_ints_bounded          (tuple form)
     N1P refund_fields_ints_bounded_proj     (projection form)
     N3  refund_run_wire_output_nonneg       (every output of the source dispatcher, for EVERY input wire)
     N4  refund_frame_decision_nonneg        (consumer corollary: accepted prefix of the program frame => ints >= 0)
     C1  refund_strict_parse_accepts_negative_frame   (control: the HOL parser alone does NOT give the bound)
     C2  refund_fields_negative_amount_rejected        (control: a negative request amount gives the rejection tuple)
     C3  refund_fields_positive_witness                (control: non-vacuity, an authorized tuple with amount 40)
   Exported (optional): O1 refund_model_frame_decision_nonneg, O2 refund_model_frame_decision_reach_nonneg
     (conclusion of MF-0002 M1 / M1b with the inner "g = refund_fields .. /\ fd1 = .." replaced by the bounds; the
      premises are those of M1 / M1b, term-identical, built by ML term surgery, not retyped).
   Kind: MODEL (HOL functions; O1/O2 at the machine model, no_ext, under all premises of M1/M1b, including
     refund_env_ok_sl, which U393 falsified for the real FFI). Says nothing about the Python code itself. *)
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
    else (List.app (showg ("UNSOLVED " ^ tag)) gs; raise mk_HOL_ERR "WNN" "CL" ("unsolved goals at " ^ tag))
  end;
fun thy_of c = #Thy (dest_thy_const c) handle _ => "?";
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundNonNeg";
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
(* OPTIONAL results: same checks as thm, but a failure is NOT added to failed (it never blocks the core export). *)
val optional_ok = ref ([] : string list);
fun opt_thm name goalf tacf =
  (pr ("BEGIN_OPTIONAL " ^ name);
   let val g = goalf ()
       val th0 = Tactical.TAC_PROOF (([], g), tacf ())
   in if null (hyp th0) then (let val th = save_thm (name, th0) in chk name th;
                                  pr ("OPTIONAL_OK " ^ name); optional_ok := name :: !optional_ok end)
      else pr ("OPTIONAL_FAILED " ^ name ^ " (hypotheses)")
   end)
  handle e => pr ("OPTIONAL_FAILED " ^ name ^ " " ^ trunc 600 (General.exnMessage e));

(* ================= parent results (names exactly as in the stored theories) ================= *)
val RF  = DB.fetch "forge_refundCertifiedProg" "refund_fields_def";
val EL  = DB.fetch "forge_refund" "eligible_def";
val RW  = DB.fetch "forge_refundWireProg" "refund_run_wire_def";
val P0  = DB.fetch "forge_refundPrefixFree" "refund_strict_parse_complete";
val X4  = DB.fetch "forge_refundPrefixExact" "refund_frame_decision";
val _ = List.app (fn (n, th) => pr ("USED " ^ n ^ "\n" ^ thm_to_string th))
  [("refund_fields_def", RF), ("eligible_def", EL), ("refund_run_wire_def", RW),
   ("refund_strict_parse_complete", P0), ("refund_frame_decision", X4)];
fun imp name th tm = if aconv (concl th) tm then pr ("IMPORTED_OK " ^ name) else bad (name ^ "-import-mismatch");
val _ = imp "refund_strict_parse_complete" P0 ``!f. refund_strict_parse (explode (refund_render_fields f)) = SOME f``;
val _ = imp "refund_frame_decision" X4
  ``!f out g. out <<= explode (refund_render_fields f) /\ refund_strict_parse out = SOME g ==>
              out = explode (refund_render_fields f) /\ g = f``;
(* the constant refund_fields in this script must be the compiled one (MF-0002 stdout.log line 89) *)
val RFC = ``refund_fields``;
val _ = if thy_of RFC = "forge_refundCertifiedProg" then pr "CONST_OK refund_fields forge_refundCertifiedProg"
        else bad ("refund_fields-theory-" ^ thy_of RFC);
val _ = if thy_of ``refund_render_fields`` = "forge_refundWireProg" then pr "CONST_OK refund_render_fields forge_refundWireProg"
        else bad "refund_render_fields-theory";
val _ = if thy_of ``eligible`` = "forge_refund" then pr "CONST_OK eligible forge_refund" else bad "eligible-theory";

(* ================= N1: the two printed integers of refund_fields are bounded ================= *)
(* Hand walk (primary):
   Cases_on `eligible ..` gives two goals with the assumption  eligible ..  or  ~eligible .. .
   simp[RF, LET_THM]: the let is reduced; each "if eligible .. then x else y" is decided by the assumption.
     T branch: (T,amount,reason,charge,request,1) = (ok,a,r,c,q,n) ==> 0 <= a /\ 0 <= n /\ n <= 1
     F branch: (F,0,«»,«»,«»,0)                 = (ok,a,r,c,q,n) ==> 0 <= a /\ 0 <= n /\ n <= 1
   rpt strip_tac \\ gvs[EL]: PAIR_EQ splits, the variable equations are eliminated (a := amount or 0, n := 1 or 0);
     T branch: the expanded eligible assumption has the conjunct 0 <= amount; 0 <= 1 /\ 1 <= 1 are literals.
     F branch: 0 <= 0 /\ 0 <= 0 /\ 0 <= 1 are literals.
   Literal int comparisons: srw_ss decides them (int reduction); fallback intLib.ARITH_TAC in alternative 2. *)
val N1 = thm "refund_fields_ints_bounded"
  (fn () => ``!charge request original remaining enabled opened candidate amount reason ok a r c q n.
                refund_fields charge request original remaining enabled opened candidate amount reason =
                  (ok,a,r,c,q,n) ==> 0 <= a /\ 0 <= n /\ n <= 1``)
  (fn () => try_all "refund_fields_ints_bounded"
     [rpt gen_tac
        \\ Cases_on `eligible charge request original remaining enabled opened candidate amount reason`
        \\ ST "n1.unfold" (simp[RF, LET_THM]) \\ rpt strip_tac \\ gvs[EL],
      rpt gen_tac
        \\ Cases_on `eligible charge request original remaining enabled opened candidate amount reason`
        \\ simp[RF, LET_THM] \\ rpt strip_tac \\ gvs[EL]
        \\ rpt conj_tac \\ TRY (first_assum ACCEPT_TAC) \\ intLib.ARITH_TAC,
      rw[RF, LET_THM] \\ gvs[EL],
      rw[RF, LET_THM] \\ fs[EL] \\ intLib.ARITH_TAC]);

(* N1P: the same bounds in projection form (FST (SND f) is the amount, SND^5 f is the count). Hand walk as N1:
   after simp[RF, LET_THM] the projections reduce to the components (FST / SND of a pair are in srw_ss). *)
val N1P = thm "refund_fields_ints_bounded_proj"
  (fn () => ``!charge request original remaining enabled opened candidate amount reason.
     0 <= FST (SND (refund_fields charge request original remaining enabled opened candidate amount reason)) /\
     0 <= SND (SND (SND (SND (SND (refund_fields charge request original remaining enabled opened candidate amount reason))))) /\
     SND (SND (SND (SND (SND (refund_fields charge request original remaining enabled opened candidate amount reason))))) <= 1``)
  (fn () => try_all "refund_fields_ints_bounded_proj"
     [rpt gen_tac
        \\ Cases_on `eligible charge request original remaining enabled opened candidate amount reason`
        \\ ST "n1p.unfold" (simp[RF, LET_THM]) \\ gvs[EL],
      rpt gen_tac
        \\ Cases_on `eligible charge request original remaining enabled opened candidate amount reason`
        \\ simp[RF, LET_THM] \\ fs[EL] \\ rpt conj_tac \\ TRY (first_assum ACCEPT_TAC) \\ intLib.ARITH_TAC,
      rw[RF, LET_THM] \\ fs[EL]]);
val N1P' = N1P;   (* let-free already; the name is kept for the uses below *)

(* ================= N3: every output of the source dispatcher, for EVERY input wire ================= *)
(* refund_run_wire wire = case refund_decode_wire wire of INL err => INL err
                         | INR (charge,..,reason) => INR (refund_render_fields (refund_fields charge .. reason)).
   This covers negative integers in the request: refund_decode uses sexp_to_dafny$to_int = mlint$fromString,
   which accepts a leading "~" or "-" (mlintScript.sml 475-483). The bound still holds: eligible needs 0 <= amount.
   Hand walk (primary): simp[RW]; every_case_tac splits the sum and the 9-tuple; INL branch: INL err = INR out is F;
   INR branch: rw[] substitutes out; goal ?f. render (refund_fields x0..x8) = render f /\ bounds(f);
   metis_tac[N1P'] takes f := refund_fields x0..x8 and N1P' at x0..x8. *)
val N3 = thm "refund_run_wire_output_nonneg"
  (fn () => ``!wire out. refund_run_wire wire = INR out ==>
       ?f. out = refund_render_fields f /\
           0 <= FST (SND f) /\ 0 <= SND (SND (SND (SND (SND f)))) /\ SND (SND (SND (SND (SND f)))) <= 1``)
  (fn () => try_all "refund_run_wire_output_nonneg"
     [rpt gen_tac \\ ST "n3.unfold" (simp[RW]) \\ every_case_tac \\ rw[] \\ metis_tac[N1P'],
      rpt gen_tac \\ simp[RW] \\ BasicProvers.TOP_CASE_TAC \\ simp[] \\ PairCases_on `y` \\ simp[]
        \\ qexists_tac `refund_fields y0 y1 y2 y3 y4 y5 y6 y7 y8` \\ simp[N1P'],
      rw[RW, AllCaseEqs()] \\ gvs[] \\ metis_tac[N1P']]);

(* ================= N4: the consumer corollary (T14 part b) ================= *)
(* If the consumer read a prefix out of the program's frame and refund_strict_parse accepted it with
   (ok,a,r,c,q,n), then a >= 0 and n >= 0 (and n <= 1): exactly the extra Python restriction. So on every program
   output the two parsers agree on the integer fields (the Python CANON_INT check is satisfied at the int level).
   Hand walk (primary): strip_tac; drule_all X4 gives  out = explode (..) /\ (ok,a,r,c,q,n) = refund_fields ..;
   strip_tac; the second equation is turned (SYM) and given to N1 (its antecedent, verbatim): MATCH_MP N1 closes. *)
val N4 = thm "refund_frame_decision_nonneg"
  (fn () => ``!charge request original remaining enabled opened candidate amount reason out ok a r c q n.
      out <<= explode (refund_render_fields
                 (refund_fields charge request original remaining enabled opened candidate amount reason)) /\
      refund_strict_parse out = SOME (ok,a,r,c,q,n) ==>
      0 <= a /\ 0 <= n /\ n <= 1``)
  (fn () => try_all "refund_frame_decision_nonneg"
     [rpt gen_tac \\ strip_tac \\ ST "n4.x4" (drule_all X4) \\ strip_tac
        \\ ST "n4.n1" (qpat_x_assum `_ = refund_fields _ _ _ _ _ _ _ _ _` (ACCEPT_TAC o MATCH_MP N1 o SYM)),
      rpt gen_tac \\ strip_tac \\ drule_all X4 \\ strip_tac
        \\ qpat_x_assum `_ = refund_fields _ _ _ _ _ _ _ _ _` (mp_tac o SYM) \\ MATCH_ACCEPT_TAC N1,
      metis_tac[X4, N1]]);

(* ================= CONTROLS (each is a PROVED theorem) ================= *)
(* C1: the HOL strict parser ALONE does not give the bound: it accepts the rendering of a frame with amount -1
   (rendered by mlint$toString as "~1", which frame.py CANON_INT refuses). This is the T14b difference, proved. *)
val C1 = thm "refund_strict_parse_accepts_negative_frame"
  (fn () => ``~(!s ok a r c q n. refund_strict_parse s = SOME (ok,a,r,c,q,n) ==> 0 <= a)``)
  (fn () => try_all "refund_strict_parse_accepts_negative_frame"
     [strip_tac \\ first_x_assum (qspecl_then [`explode (refund_render_fields (F,-1,«»,«»,«»,0))`,
                                               `F`, `-1`, `«»`, `«»`, `«»`, `0`] mp_tac)
        \\ rewrite_tac [P0] \\ intLib.ARITH_TAC,
      strip_tac \\ first_x_assum (qspecl_then [`explode (refund_render_fields (F,-1,«»,«»,«»,0))`,
                                               `F`, `-1`, `«»`, `«»`, `«»`, `0`] mp_tac)
        \\ simp[P0]]);
(* C2: a request with a NEGATIVE amount (the request parser accepts it) gives the rejection tuple, so the program
   prints  (refund-result-v1 False 0 "" "" "" 0). Concrete counterexample candidate, refuted. *)
val C2 = thm "refund_fields_negative_amount_rejected"
  (fn () => ``refund_fields «c» «r» 100 60 T T T (-5) «returned_item» = (F,0,«»,«»,«»,0)``)
  (fn () => try_all "refund_fields_negative_amount_rejected"
     [EVAL_TAC, simp[RF, EL, LET_THM], rw[RF, EL, LET_THM] \\ intLib.ARITH_TAC]);
(* C3: non-vacuity: an authorized tuple with a positive amount and count 1 exists. *)
val C3 = thm "refund_fields_positive_witness"
  (fn () => ``refund_fields «c» «r» 100 60 T T T 40 «returned_item» = (T,40,«returned_item»,«c»,«r»,1)``)
  (fn () => try_all "refund_fields_positive_witness"
     [EVAL_TAC, simp[RF, EL, LET_THM], rw[RF, EL, LET_THM] \\ intLib.ARITH_TAC]);

(* ================= OPTIONAL: machine-model corollaries of MF-0002 M1 and M1b ================= *)
(* Statement built from the stored conclusion: the innermost  !g. P g ==> Q g  is replaced by
   !g. P g ==> NN g  (NN = the three bounds on g). Premises and every other part stay term-identical. *)
fun nn_of g = ``0 <= FST (SND ^g) /\ 0 <= SND (SND (SND (SND (SND ^g)))) /\ SND (SND (SND (SND (SND ^g)))) <= 1``;
fun replace_inner tm =
  let val (vs, body) = strip_forall tm
      val (P, r1) = dest_imp body
      val (ms, r2) = dest_exists r1
      val (AB, r3) = dest_conj r2
      val (b, r4) = dest_forall r3
      val (Mb, r5) = dest_imp r4
      val (tio, r6) = strip_exists r5
      val (E, r7) = dest_conj r6
      val (g, r8) = dest_forall r7
      val (Pg, _) = dest_imp r8
  in list_mk_forall (vs, mk_imp (P, mk_exists (ms, mk_conj (AB, mk_forall (b, mk_imp (Mb,
       list_mk_exists (tio, mk_conj (E, mk_forall (g, mk_imp (Pg, nn_of g)))))))))) end;
(* Hand walk: rpt gen_tac (no-op if no outer forall); disch_then (strip_assume_tac o MATCH_MP M) gives ms, the two
   conjuncts, and  !b. Mb ==> ?t io. E /\ !g. Pg ==> g = refund_fields .. /\ fd1 = .. ;
   qexists_tac `ms`; the first conjunct from the assumptions; gen_tac/disch_tac for b; first_x_assum drule_then
   gives t io, E, !g..; qexists t io; E by assumption; gen_tac/disch_tac for g; drule_then gives g = refund_fields ..;
   SUBST1_TAC it; N1P' (let-free) closes by MATCH_ACCEPT_TAC. *)
fun nn_tac M () =
  try_all "nn_corollary"
   [rpt gen_tac \\ disch_then (strip_assume_tac o MATCH_MP M)
      \\ qexists_tac `ms` \\ conj_tac >- (rpt conj_tac \\ first_assum ACCEPT_TAC)
      \\ gen_tac \\ disch_tac \\ first_x_assum (drule_then strip_assume_tac)
      \\ MAP_EVERY qexists_tac [`t`, `io`] \\ conj_tac >- first_assum ACCEPT_TAC
      \\ gen_tac \\ disch_tac \\ first_x_assum (drule_then strip_assume_tac)
      \\ qpat_x_assum `_ = refund_fields _ _ _ _ _ _ _ _ _` SUBST1_TAC \\ MATCH_ACCEPT_TAC N1P',
    rpt gen_tac \\ strip_tac \\ drule_all M \\ strip_tac \\ qexists_tac `ms` \\ simp[]
      \\ rpt strip_tac \\ first_x_assum drule \\ strip_tac \\ simp[] \\ rpt strip_tac
      \\ first_x_assum drule \\ strip_tac \\ gvs[N1P'],
    metis_tac[M, N1P']];
fun opt_corollary src newname =
  (let val M = DB.fetch "forge_refundModelFrame" src
       val _ = pr ("USED " ^ src ^ "\n" ^ thm_to_string M)
       val stmt = replace_inner (concl M)
   in opt_thm newname (fn () => stmt) (nn_tac M) end)
  handle e => pr ("OPTIONAL_SKIPPED " ^ newname ^ " " ^ trunc 300 (General.exnMessage e));
val _ = opt_corollary "refund_model_frame_decision" "refund_model_frame_decision_nonneg";
val _ = opt_corollary "refund_model_frame_decision_reach" "refund_model_frame_decision_reach_nonneg";

(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = pr ("FAILED_LIST " ^ String.concatWith " " (rev (!failed)));
val _ = pr ("DIAG_OK_UNDER_LIST " ^ String.concatWith " " (rev (!diag)));
val _ = pr ("OPTIONAL_OK_LIST " ^ String.concatWith " " (rev (!optional_ok)));
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
fun lit name th tm = if aconv (concl th) tm then pr ("CONTROL_OK " ^ name ^ " statement is the literal planned statement")
                     else bad (name ^ "-literal");
val _ = lit "refund_fields_ints_bounded" N1
  ``!charge request original remaining enabled opened candidate amount reason ok a r c q n.
      refund_fields charge request original remaining enabled opened candidate amount reason =
        (ok,a,r,c,q,n) ==> 0 <= a /\ 0 <= n /\ n <= 1``;
val _ = lit "refund_frame_decision_nonneg" N4
  ``!charge request original remaining enabled opened candidate amount reason out ok a r c q n.
      out <<= explode (refund_render_fields
                 (refund_fields charge request original remaining enabled opened candidate amount reason)) /\
      refund_strict_parse out = SOME (ok,a,r,c,q,n) ==>
      0 <= a /\ 0 <= n /\ n <= 1``;
val _ = if is_neg (concl C1) then pr "CONTROL_OK C1 is a proved negation" else bad "C1-not-negation";
val _ = if aconv (rhs (concl C2)) ``(F,0:int,«»,«»,«»,0:int)`` then pr "CONTROL_OK C2 negative amount gives the rejection tuple"
        else bad "C2-shape";
val _ = if aconv (rhs (concl C3)) ``(T,40:int,«returned_item»,«c»,«r»,1:int)`` then pr "CONTROL_OK C3 authorized witness"
        else bad "C3-shape";
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundNonNeg" @ DB.definitions "forge_refundNonNeg");
val closure = "forge_refundNonNeg" :: Theory.ancestry "forge_refundNonNeg";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundNonNeg")));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions "forge_refundNonNeg")));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

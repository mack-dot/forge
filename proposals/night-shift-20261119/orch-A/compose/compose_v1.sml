(* compose_v1.sml: theory forge_refundModelFrame (worker A21, Night-Shift Orchestrator A, 2026-11-19).
   DRAFT: NOT RUN. No HOL process was started by A21. Every tactic below is UNCHECKED.
   Run as case MF-0001 (RUN_PLAN_compose.md). Harness: the helper block of PX-0001.sml (pr with flush, tags,
   showg/show_tac, ST, CL, try_all, thm with BEGIN lines and the ASSUME fallback that is never stored,
   DIAG_OK_UNDER, FAILED_LIST, tag check over all theorems and definitions, 4 bool axioms, chDir FORGE_P3_OUT,
   EXACT_COMPLETE only after export_theory).
   Parents (stored, read with DB.fetch; no statement retyped):
     forge_refundLOut (LO-0006): refund_profile_a_sl_fd1, refund_L_OUT, fd1_written_prefix
     forge_refundPrefixExact (PX-0001): refund_frame_decision
     forge_refundPrefixFree (PF-0004): refund_strict_parse_complete
     forge_refundRouteA2 (L2-0003): refund_profile_a_sl_reach   (for M1b)
     forge_refundSlideEntry: arm8_run_constants_agree             (for M1b, first conjunct)
     forge_refundExportedContract (link contract-0001): exported_contract_on_refund_fields, ONLY when it loads
       at run time (CONTRACT_MODE imported); else M3 is not attempted (CONTRACT_MODE absent).
   Exported:
     M1  refund_model_frame_decision        (premise = the stored premise of refund_profile_a_sl_fd1, term-identical)
     M2  refund_model_success_gives_frame   (non-vacuity: a Success run is accepted with the function's value)
     M1b refund_model_frame_decision_reach  (premise = the stored premise of refund_profile_a_sl_reach at ext := no_ext;
                                             conclusion term-identical to M1's)
     M3  refund_model_frame_meets_exported_contract (imported mode only)
     helpers and the control c2 (refund_strict_parse_empty_rejected).
   Kind: MODEL. Machine model at no_ext. Says nothing about the real process, the pipe, or the native relation.
   M1 and M2 inherit the stored all-states FFI premise refund_env_ok_sl (falsified for the real FFI by U393).
   M1b inherits the L2 premises; its premise ffi_calls_ok (lemma L3) is NOT proved anywhere. *)
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
    else (List.app (showg ("UNSOLVED " ^ tag)) gs; raise mk_HOL_ERR "A21" "CL" ("unsolved goals at " ^ tag))
  end;
fun thy_of c = #Thy (dest_thy_const c) handle _ => "?";
fun has_const n tm = can (find_term (fn t => is_const t andalso fst (dest_const t) = n)) tm;

(* ================= M3 precondition: try to load the exported-contract theory (before new_theory) =========
   load needs .ui/.uo files; contract-0001/.hol/objs holds only .sig/.sml/.dat, so load is expected to fail.
   The fallback uses the theory files the same way hol run uses a deps line (<dir>/<name>; QUse.use). Every
   failure is caught; the result only selects CONTRACT_MODE. FORGE_MF_NO_CONTRACT=1 forces absent mode. *)
val CONTRACT_DIR = "/Users/USER/forge/results/night-shift-20261119/orch-A/link/run/attempt-0001/contract-0001";
val CTHY = "forge_refundExportedContract";
fun try_use_contract () =
  (use (CONTRACT_DIR ^ "/" ^ CTHY ^ "Theory.sig"); use (CONTRACT_DIR ^ "/" ^ CTHY ^ "Theory.sml");
   pr "CONTRACT_LOAD via use <dir>/<name>")
  handle e => (pr ("CONTRACT_USE_FAILED " ^ trunc 300 (General.exnMessage e) ^ " ; trying .hol/objs paths");
               use (CONTRACT_DIR ^ "/.hol/objs/" ^ CTHY ^ "Theory.sig");
               use (CONTRACT_DIR ^ "/.hol/objs/" ^ CTHY ^ "Theory.sml");
               pr "CONTRACT_LOAD via use .hol/objs");
val contract_imported =
  if OS.Process.getEnv "FORGE_MF_NO_CONTRACT" = SOME "1"
  then (pr "CONTRACT_MODE absent (FORGE_MF_NO_CONTRACT=1)"; false)
  else
   ((let
       val _ = loadPath := CONTRACT_DIR :: !loadPath
       val _ = (load (CTHY ^ "Theory"); pr "CONTRACT_LOAD via load")
               handle e => (pr ("CONTRACT_LOAD_FAILED " ^ trunc 300 (General.exnMessage e)); try_use_contract ())
       val _ = DB.fetch CTHY "exported_contract_on_refund_fields"
     in pr "CONTRACT_MODE imported"; true end)
    handle e => (pr ("CONTRACT_MODE absent " ^ trunc 300 (General.exnMessage e)); false));

val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundModelFrame";
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

(* ================= parent results ================= *)
val FD1   = DB.fetch "forge_refundLOut" "refund_profile_a_sl_fd1";
val LOUT  = DB.fetch "forge_refundLOut" "refund_L_OUT";
val FDP   = DB.fetch "forge_refundLOut" "fd1_written_prefix";
val X4    = DB.fetch "forge_refundPrefixExact" "refund_frame_decision";
val P0    = DB.fetch "forge_refundPrefixFree" "refund_strict_parse_complete";
val L2R   = DB.fetch "forge_refundRouteA2" "refund_profile_a_sl_reach";
val AGREE = DB.fetch "forge_refundSlideEntry" "arm8_run_constants_agree";
val _ = List.app (fn (n, th) => pr ("USED " ^ n ^ "\n" ^ thm_to_string th))
  [("refund_profile_a_sl_fd1", FD1), ("refund_L_OUT", LOUT), ("fd1_written_prefix", FDP),
   ("refund_frame_decision", X4), ("refund_strict_parse_complete", P0),
   ("refund_profile_a_sl_reach", L2R), ("arm8_run_constants_agree", AGREE)];
fun imp name th tm = if aconv (concl th) tm then pr ("IMPORTED_OK " ^ name) else bad (name ^ "-import-mismatch");
val _ = imp "refund_frame_decision" X4
  ``!f out g. out <<= explode (refund_render_fields f) /\ refund_strict_parse out = SOME g ==>
              out = explode (refund_render_fields f) /\ g = f``;
val _ = imp "refund_strict_parse_complete" P0 ``!f. refund_strict_parse (explode (refund_render_fields f)) = SOME f``;
val _ = imp "fd1_written_prefix" FDP ``!io' io. io' <<= io ==> fd1_written io' <<= fd1_written io``;
(* refund_L_OUT: no_ext is polymorphic; a re-parse may differ only in a type variable, so this check only prints. *)
val _ = (if aconv (concl LOUT) ``!cl fs io out. STD_streams fs /\
       extract_fs no_ext (cl,fs) io = SOME (add_stdout (fastForwardFD fs 0) out) ==> fd1_written io = explode out``
         then pr "IMPORTED_OK refund_L_OUT" else pr "IMPORT_NOTE refund_L_OUT re-parse differs (not a pass condition)")
        handle e => pr ("IMPORT_NOTE refund_L_OUT parse " ^ trunc 200 (General.exnMessage e));

(* ================= pieces of the stored theorem (no retyping) ================= *)
(* concl FD1 = PREM ==> ?ms. C1 /\ !b. MSB ==> ?t io. BEQ /\ (D1 \/ D2)
   D1 = (t = Success /\ fd1_written io = EXPL), D2 = (t = Resource_limit_hit /\ fd1_written io <<= EXPL),
   EXPL = explode R, R = refund_render_fields FT, FT = refund_fields charge ... reason. *)
val (PREM, FD1C) = dest_imp (concl FD1);
val (msv, FD1B) = dest_exists FD1C;
val (C1, ALLB) = dest_conj FD1B;
val (bv, BIMP) = dest_forall ALLB;
val (MSB, EX2) = dest_imp BIMP;
val (tiov, TB) = strip_exists EX2;
val tv = List.nth (tiov, 0);
val iov = List.nth (tiov, 1);
val (BEQ, DJ) = dest_conj TB;
val (D1, D2) = dest_disj DJ;
val (TEQS, FDEQ) = dest_conj D1;
val SUCC_C = rhs TEQS;
val FDW = lhs FDEQ;
val EXPL = rhs FDEQ;
val R = rand EXPL;
val FT = rand R;
val PFXC = rator (rator (snd (dest_conj D2)));
val TERM_C = fst (strip_comb (rhs BEQ));
val SP = find_term (fn t => is_const t andalso fst (dest_const t) = "refund_strict_parse") (concl X4);
val _ = if aconv (rand MSB) bv then () else bad "MSB-not-applied-to-b";
val _ = pr ("PIECE FT " ^ term_to_string FT);
val _ = pr ("CONST refund_fields " ^ thy_of (fst (strip_comb FT)));
val _ = pr ("CONST refund_render_fields " ^ thy_of (fst (strip_comb R)));
val _ = pr ("CONST refund_strict_parse " ^ thy_of SP);
val _ = pr ("CONST Terminate " ^ thy_of TERM_C ^ " Success " ^ thy_of SUCC_C);
val _ = List.app (fn t => pr ("ARM8_RUN_IN_FD1 " ^ thy_of t))
          (find_terms (fn t => is_const t andalso fst (dest_const t) = "arm8_run") C1);
val gv = variant (free_vars (concl FD1) @ [msv, bv, tv, iov]) (mk_var ("g", type_of FT));
(* newc out = !g. refund_strict_parse out = SOME g ==> g = FT /\ out = EXPL *)
fun newc outT = mk_forall (gv, mk_imp (mk_eq (mk_comb (SP, outT), optionSyntax.mk_some gv),
                                       mk_conj (mk_eq (gv, FT), mk_eq (outT, EXPL))));
fun body_with nc = mk_exists (msv, mk_conj (C1, mk_forall (bv, mk_imp (MSB, list_mk_exists ([tv, iov], mk_conj (BEQ, nc))))));

(* ================= pure helper lemmas ================= *)
(* PFX_OF. Hand walk: STRIP_TAC gives two goals. (1) [p1, out = x] out <<= x: ASM_REWRITE_TAC rewrites out to x,
   isPREFIX_REFL (listScript.sml 3592) closes x <<= x. (2) [p2, out <<= x] out <<= x: the assumption closes it. *)
val PFX_OF = thm "refund_outcome_prefix"
  (fn () => ``!p1 p2 (out:'a list) x. (p1 /\ out = x \/ p2 /\ out <<= x) ==> out <<= x``)
  (fn () => try_all "refund_outcome_prefix"
     [rpt gen_tac \\ STRIP_TAC \\ ASM_REWRITE_TAC [listTheory.isPREFIX_REFL],
      metis_tac [listTheory.isPREFIX_REFL],
      rw [] \\ simp [listTheory.isPREFIX_REFL]]);

(* KEY0. Hand walk: [P: out <<= E f; A: rsp out = SOME g]  g = f /\ out = E f.
   qspecl_then [f,out,g] mp_tac X4: (P /\ A ==> out = E f /\ g = f) ==> goal; impl_tac: P /\ A by the assumptions;
   the remaining antecedent th : out = E f /\ g = f; CONJ (CONJUNCT2 th) (CONJUNCT1 th) is the goal. *)
val KEY0 = thm "refund_frame_accept_of_prefix"
  (fn () => ``!f out. out <<= explode (refund_render_fields f) ==>
              !g. refund_strict_parse out = SOME g ==> g = f /\ out = explode (refund_render_fields f)``)
  (fn () => try_all "refund_frame_accept_of_prefix"
     [rpt gen_tac \\ DISCH_TAC \\ gen_tac \\ DISCH_TAC
        \\ qspecl_then [`f`, `out`, `g`] mp_tac X4
        \\ ST "key0.impl" (impl_tac >- (CONJ_TAC \\ FIRST_ASSUM ACCEPT_TAC))
        \\ DISCH_THEN (fn th => ACCEPT_TAC (CONJ (CONJUNCT2 th) (CONJUNCT1 th))),
      metis_tac [X4],
      rpt strip_tac \\ drule_all X4 \\ strip_tac \\ ASM_REWRITE_TAC []]);

(* KEY. Hand walk: DISCH_THEN th = the disjunction; MATCH_MP PFX_OF th : out <<= E f;
   MATCH_MP KEY0 that : !g. rsp out = SOME g ==> g = f /\ out = E f, which is the goal (MATCH_ACCEPT_TAC). *)
val KEY = thm "refund_frame_accept_of_outcome"
  (fn () => ``!p1 p2 out f.
       (p1 /\ out = explode (refund_render_fields f) \/ p2 /\ out <<= explode (refund_render_fields f)) ==>
       !g. refund_strict_parse out = SOME g ==> g = f /\ out = explode (refund_render_fields f)``)
  (fn () => try_all "refund_frame_accept_of_outcome"
     [rpt gen_tac \\ DISCH_THEN (fn th => MATCH_ACCEPT_TAC (MATCH_MP KEY0 (MATCH_MP PFX_OF th))),
      metis_tac [PFX_OF, KEY0]]);

(* SUCC. Hand walk: STRIP_TAC gives two goals with [Terminate Success io0 = Terminate t io].
   (1) [t = Success; fd1_written io = E f]: gvs uses behaviour injectivity (io0 = io), rewrites the goal to
       rsp (E f) = SOME f; P0 closes it. (2) [t = Resource_limit_hit; ...]: injectivity gives Success = t, so
       Success = Resource_limit_hit, false by outcome distinctness; gvs closes it. No assumption of shape ==> var = c. *)
val SUCC = thm "refund_success_accept"
  (fn () => ``!io0 f. (?t io. Terminate Success io0 = Terminate t io /\
                 (t = Success /\ fd1_written io = explode (refund_render_fields f) \/
                  t = Resource_limit_hit /\ fd1_written io <<= explode (refund_render_fields f))) ==>
               refund_strict_parse (fd1_written io0) = SOME f``)
  (fn () => try_all "refund_success_accept"
     [rpt gen_tac \\ STRIP_TAC \\ gvs [P0],
      rpt strip_tac \\ fs [] \\ rveq \\ fs [P0],
      rpt strip_tac \\ fs [] \\ rfs [P0]]);

(* ERL (as the stored E4 RUNS step, e4-0001/proof.sml 196-197). extend_with_resource_limit_def:
   CK/semantics/proofs/semanticsPropsScript.sml 219-226. *)
val ERL = thm "extend_with_resource_limit_single_success"
  (fn () => ``!M io0 b. M SUBSET extend_with_resource_limit {Terminate Success io0} /\ M b ==>
                b = Terminate Success io0 \/ ?io'. b = Terminate Resource_limit_hit io' /\ io' <<= io0``)
  (fn () => try_all "extend_with_resource_limit_single_success"
     [rpt strip_tac
        \\ `b IN extend_with_resource_limit {Terminate Success io0}` by
             fs [pred_setTheory.SUBSET_DEF, boolTheory.IN_DEF]
        \\ pop_assum mp_tac \\ simp [semanticsPropsTheory.extend_with_resource_limit_def]
        \\ rpt strip_tac \\ rveq \\ fs [] \\ metis_tac [],
      rpt strip_tac
        \\ `b IN M` by simp [boolTheory.IN_DEF]
        \\ `b IN extend_with_resource_limit {Terminate Success io0}` by metis_tac [pred_setTheory.SUBSET_DEF]
        \\ fs [semanticsPropsTheory.extend_with_resource_limit_def] \\ metis_tac []]);

(* FIN. Hand walk: STRIP_TAC gives (1) [b = Terminate Success io0; FD: fd1_written io0 = E f] and
   (2) [b = Terminate Resource_limit_hit io'; io' <<= io0; FD].
   (1) witnesses Success (the constant term of the stored theorem) and io0; the first conjunct is an assumption;
       MATCH_MP_TAC KEY0 leaves fd1_written io0 <<= E f; SUBST1_TAC FD gives E f <<= E f; isPREFIX_REFL.
   (2) witnesses Resource_limit_hit and io'; MATCH_MP_TAC KEY0; SUBST1_TAC (SYM FD) turns E f into fd1_written io0;
       MATCH_MP_TAC FDP leaves io' <<= io0, an assumption. *)
val RLH_C = rhs (fst (dest_conj D2));
val FIN = thm "refund_fd1_frame_of_run"
  (fn () => ``!b io0 f. (b = Terminate Success io0 \/ ?io'. b = Terminate Resource_limit_hit io' /\ io' <<= io0) /\
                 fd1_written io0 = explode (refund_render_fields f) ==>
               ?t io. b = Terminate t io /\
                 !g. refund_strict_parse (fd1_written io) = SOME g ==>
                     g = f /\ fd1_written io = explode (refund_render_fields f)``)
  (fn () => try_all "refund_fd1_frame_of_run"
     [rpt gen_tac \\ STRIP_TAC
      >- (EXISTS_TAC SUCC_C \\ qexists_tac `io0` \\ CONJ_TAC >- FIRST_ASSUM ACCEPT_TAC
          \\ MATCH_MP_TAC KEY0 \\ qpat_x_assum `fd1_written io0 = _` SUBST1_TAC
          \\ MATCH_ACCEPT_TAC listTheory.isPREFIX_REFL)
      \\ EXISTS_TAC RLH_C \\ qexists_tac `io'` \\ CONJ_TAC >- FIRST_ASSUM ACCEPT_TAC
      \\ MATCH_MP_TAC KEY0 \\ qpat_x_assum `fd1_written io0 = _` (SUBST1_TAC o SYM)
      \\ MATCH_MP_TAC FDP \\ FIRST_ASSUM ACCEPT_TAC,
      rpt gen_tac \\ STRIP_TAC
      >- (qexistsl_tac [`Success`, `io0`] \\ ASM_REWRITE_TAC [] \\ metis_tac [KEY0, listTheory.isPREFIX_REFL])
      \\ qexistsl_tac [`Resource_limit_hit`, `io'`] \\ ASM_REWRITE_TAC [] \\ metis_tac [KEY0, FDP]]);

(* ================= M1: the consumer-facing model theorem ================= *)
(* finish key, on  (?t io. b = Terminate t io /\ D) ==> ?t io. b = Terminate t io /\ N :
   choose t io (the stored bound variables; not free in the goal), witness them, and build
   CONJ (b = Terminate t io) (MATCH_MP key D); MATCH_MP key D is N (key's antecedent matches D with
   p1 := (t = Success), p2 := (t = Resource_limit_hit), out := fd1_written io, f := FT). *)
fun finish key = DISCH_THEN (X_CHOOSE_THEN tv (X_CHOOSE_THEN iov (fn th =>
      EXISTS_TAC tv \\ EXISTS_TAC iov \\ ACCEPT_TAC (CONJ (CONJUNCT1 th) (MATCH_MP key (CONJUNCT2 th))))));
(* Hand walk (primary): DISCH_THEN with MP FD1 (antecedent is PREM itself) gives ms, the two C1 conjuncts and
   AB: !b. MSB ==> ?t io. ...; EXISTS_TAC msv (the same variable); C1 from the two assumptions; X_GEN_TAC b;
   DISCH_TAC [MSB]; first_x_assum drule uses AB with MSB; finish key. *)
fun frame_tacs key =
  [DISCH_THEN (STRIP_ASSUME_TAC o MP FD1)
     \\ EXISTS_TAC msv
     \\ ST "frame.c1" (CONJ_TAC >- (CONJ_TAC \\ FIRST_ASSUM ACCEPT_TAC))
     \\ X_GEN_TAC bv \\ DISCH_TAC
     \\ ST "frame.drule" (first_x_assum drule)
     \\ ST "frame.finish" (finish key),
   DISCH_THEN (MP_TAC o MP FD1)
     \\ ho_match_mp_tac boolTheory.MONO_EXISTS \\ gen_tac \\ BETA_TAC
     \\ ho_match_mp_tac boolTheory.MONO_AND \\ CONJ_TAC >- REWRITE_TAC []
     \\ ho_match_mp_tac boolTheory.MONO_ALL \\ gen_tac \\ BETA_TAC
     \\ ho_match_mp_tac boolTheory.MONO_IMP \\ CONJ_TAC >- REWRITE_TAC []
     \\ ho_match_mp_tac boolTheory.MONO_EXISTS \\ gen_tac \\ BETA_TAC
     \\ ho_match_mp_tac boolTheory.MONO_EXISTS \\ gen_tac \\ BETA_TAC
     \\ ho_match_mp_tac boolTheory.MONO_AND \\ CONJ_TAC >- REWRITE_TAC []
     \\ MATCH_ACCEPT_TAC key,
   DISCH_THEN (STRIP_ASSUME_TAC o MP FD1) \\ EXISTS_TAC msv
     \\ CONJ_TAC >- (CONJ_TAC \\ FIRST_ASSUM ACCEPT_TAC)
     \\ X_GEN_TAC bv \\ DISCH_TAC \\ first_x_assum drule \\ metis_tac [key]];
val M1_STMT = mk_imp (PREM, body_with (newc FDW));
val M1 = thm "refund_model_frame_decision"
  (fn () => M1_STMT)
  (fn () => try_all "refund_model_frame_decision" (frame_tacs KEY));

(* ================= M2: Success is accepted with the function's value (non-vacuity) ================= *)
(* Hand walk: as M1 up to DISCH_TAC [MS (Terminate Success io)]; first_x_assum drule gives
   (?t io'. Terminate Success io = Terminate t io' /\ D) ==> rsp (fd1_written io) = SOME FT, an instance of SUCC
   (io0 := io, f := FT). *)
val TS_io = list_mk_comb (TERM_C, [SUCC_C, iov]);
val M2_STMT = mk_imp (PREM, mk_exists (msv, mk_conj (C1,
                mk_forall (iov, mk_imp (mk_comb (rator MSB, TS_io), mk_eq (mk_comb (SP, FDW), optionSyntax.mk_some FT))))));
val M2 = thm "refund_model_success_gives_frame"
  (fn () => M2_STMT)
  (fn () => try_all "refund_model_success_gives_frame"
     [DISCH_THEN (STRIP_ASSUME_TAC o MP FD1) \\ EXISTS_TAC msv
        \\ CONJ_TAC >- (CONJ_TAC \\ FIRST_ASSUM ACCEPT_TAC)
        \\ X_GEN_TAC iov \\ DISCH_TAC
        \\ ST "m2.drule" (first_x_assum drule)
        \\ MATCH_ACCEPT_TAC SUCC,
      DISCH_THEN (STRIP_ASSUME_TAC o MP FD1) \\ EXISTS_TAC msv
        \\ CONJ_TAC >- (CONJ_TAC \\ FIRST_ASSUM ACCEPT_TAC)
        \\ X_GEN_TAC iov \\ DISCH_TAC \\ first_x_assum drule \\ metis_tac [SUCC]]);

(* ================= M1b: the same conclusion from the L2 premises (refund_profile_a_sl_reach) ============
   L2R's conclusion is the stored refund_profile_a_sl conclusion (L2-0003 stdout CONTROL_OK line); E4 derived the
   every-machine-run form from it by set reasoning only (e4-0001/proof.sml 192-199); ERL is that step.
   Hand walk (primary): DISCH_THEN keeps STD_streams fs (last conjunct of the premise) and strips MP L2R_NE:
   ms, run, PC, TO, io_events, SUB: machine_sem .. ms SUBSET extend_with_resource_limit {Terminate Success io_events},
   EXT: extract_fs no_ext (cl,fs) io_events = SOME (add_stdout (fastForwardFD fs 0) R).
   C1: the goal's arm8_run is the constant of FD1, the assumption's that of L2R; the FIRST list is the one that
   closed this conjunct in LO-0006 (ASM_REWRITE_TAC [AGREE]). Then X_GEN_TAC b, DISCH_TAC [MSB];
   MATCH_MP_TAC FIN (b := b, f := FT) leaves ?io0. (cases) /\ fd1_written io0 = EXPL; witness io_events;
   cases by drule_all ERL (SUB, MSB); fd1 by drule_all LOUT (STD_streams fs, EXT). *)
val EXTV2 = valOf (List.find (fn v => fst (dest_var v) = "ext") (free_vars (concl L2R)));
val NOEXT2 = mk_thy_const {Thy = "basis_ffi", Name = "no_ext", Ty = type_of EXTV2};
val L2R_NE = INST [EXTV2 |-> NOEXT2] L2R;
val (PREM2, L2C) = dest_imp (concl L2R_NE);
val (msv2, L2B) = dest_exists L2C;
val iov2 = fst (dest_exists (List.last (strip_conj L2B)));
val _ = pr ("PIECE L2R ms " ^ (if aconv msv2 msv then "same variable as FD1" else "DIFFERENT from FD1"));
val _ = pr ("PIECE L2R io_events " ^ term_to_string iov2 ^ " : " ^ type_to_string (type_of iov2));
val M1B_STMT = mk_imp (PREM2, snd (dest_imp M1_STMT));
val C1_TAC = FIRST [CONJ_TAC \\ FIRST_ASSUM ACCEPT_TAC,
                    ASM_REWRITE_TAC [AGREE] \\ NO_TAC,
                    ASM_REWRITE_TAC [GSYM AGREE] \\ NO_TAC];
val M1B = thm "refund_model_frame_decision_reach"
  (fn () => M1B_STMT)
  (fn () => try_all "refund_model_frame_decision_reach"
     [DISCH_THEN (fn th => ASSUME_TAC (List.last (CONJUNCTS th)) \\ STRIP_ASSUME_TAC (MP L2R_NE th))
        \\ EXISTS_TAC msv
        \\ ST "m1b.c1" (CONJ_TAC >- C1_TAC)
        \\ X_GEN_TAC bv \\ DISCH_TAC
        \\ ST "m1b.fin" (MATCH_MP_TAC FIN) \\ EXISTS_TAC iov2
        \\ CONJ_TAC
        >- ST "m1b.erl" (drule_all ERL \\ DISCH_THEN ACCEPT_TAC)
        \\ ST "m1b.lout" (drule_all LOUT \\ DISCH_THEN ACCEPT_TAC),
      DISCH_THEN (fn th => ASSUME_TAC (List.last (CONJUNCTS th)) \\ STRIP_ASSUME_TAC (MP L2R_NE th))
        \\ qexists_tac `ms`
        \\ CONJ_TAC >- C1_TAC
        \\ X_GEN_TAC bv \\ DISCH_TAC
        \\ MATCH_MP_TAC FIN \\ qexists_tac `io_events` \\ metis_tac [ERL, LOUT]]);

(* ================= c2: an empty output is never accepted ================= *)
(* C2G hand walk: Cases_on rsp p; NONE: NONE = NONE. SOME x: X4 with f1 and with f2 gives x = f1 and x = f2,
   so f1 = f2, against f1 <> f2 (metis). C2: MATCH_MP_TAC C2G (p := "") leaves ?f1 f2. "" <<= .. /\ "" <<= .. /\ f1 <> f2;
   the PX-0001 witnesses; simp: [] <<= l (isPREFIX_THM, [simp]) and the two tuples differ in the first field. *)
val C2G = thm "refund_strict_parse_common_prefix_rejected"
  (fn () => ``!p f1 f2. p <<= explode (refund_render_fields f1) /\ p <<= explode (refund_render_fields f2) /\
                        f1 <> f2 ==> refund_strict_parse p = NONE``)
  (fn () => try_all "refund_strict_parse_common_prefix_rejected"
     [rpt strip_tac \\ Cases_on `refund_strict_parse p` >- REWRITE_TAC [] \\ metis_tac [X4],
      rpt strip_tac \\ Cases_on `refund_strict_parse p` \\ simp [] \\ metis_tac [X4]]);
val C2 = thm "refund_strict_parse_empty_rejected"
  (fn () => ``refund_strict_parse "" = NONE``)
  (fn () => try_all "refund_strict_parse_empty_rejected"
     [MATCH_MP_TAC C2G \\ qexistsl_tac [`(T,40,«returned_item»,«c»,«r»,1)`, `(F,40,«returned_item»,«c»,«r»,1)`]
        \\ simp [listTheory.isPREFIX_THM],
      EVAL_TAC]);

(* ================= M3 (imported mode only) ================= *)
fun m3_text () =
  "refund_model_frame_meets_exported_contract: the statement of refund_model_frame_decision with the inner " ^
  "conjunction g = refund_fields .. /\\ fd1_written io = explode (..) extended by " ^
  "!ok a r c q n. g = (ok,a,r,c,q,n) ==> evaluate_exps (exported_contract_state dafny_heap charge request original " ^
  "remaining enabled opened candidate amount reason ok a r c q n) dafny_env exported_ensures = " ^
  "(exported_contract_state dafny_heap .. ok a r c q n, Rval [BoolV T; BoolV T; BoolV T])";
val M3opt =
  if not contract_imported then
    (pr "M3_NOT_ATTEMPTED contract theory absent";
     pr ("STATEMENT_TYPECHECKS no (constant exported_ensures present: " ^
         Bool.toString (can prim_mk_const {Thy = CTHY, Name = "exported_ensures"}) ^ ")");
     pr ("STATEMENT_TEXT_ONLY " ^ m3_text ()); NONE)
  else
   ((let
       val ECON0 = DB.fetch CTHY "exported_contract_on_refund_fields"
       val _ = pr ("USED exported_contract_on_refund_fields\n" ^ thm_to_string ECON0)
       val (ea0, _) = dest_imp (concl ECON0)
       val _ = pr ("CONTRACT_REFUND_FIELDS_CONST " ^ thy_of (fst (strip_comb (lhs ea0))))
     in
       if not (aconv (lhs ea0) FT)
       then (pr ("CONTRACT_REFUND_FIELDS_MISMATCH " ^ term_to_string (lhs ea0)); pr "M3_NOT_ATTEMPTED mismatch"; NONE)
       else
        let
          fun fv n = List.find (fn v => fst (dest_var v) = n) (free_vars (concl ECON0))
          val ren = List.mapPartial (fn (n, n') => case fv n of SOME v => SOME (v |-> mk_var (n', type_of v)) | NONE => NONE)
                      [("h", "dafny_heap"), ("env", "dafny_env")]
          val ECON = INST ren ECON0
          val (ea, EVQ) = dest_imp (concl ECON)
          val TUP = rhs ea
          val cvs = pairSyntax.strip_pair TUP
          fun newc3 outT = mk_forall (gv, mk_imp (mk_eq (mk_comb (SP, outT), optionSyntax.mk_some gv),
                list_mk_conj [mk_eq (gv, FT), mk_eq (outT, EXPL), list_mk_forall (cvs, mk_imp (mk_eq (gv, TUP), EVQ))]))
          val outv = mk_var ("out", type_of FDW)
          val p1 = mk_var ("p1", bool)
          val p2 = mk_var ("p2", bool)
          val DJo = mk_disj (mk_conj (p1, mk_eq (outv, EXPL)), mk_conj (p2, mk_comb (mk_comb (PFXC, outv), EXPL)))
          (* K3 hand walk: MATCH_MP KEY D gives !g. rsp out = SOME g ==> g = FT /\ out = EXPL (assumed);
             X_GEN_TAC g, DISCH_TAC; MATCH_MP of the two gives g = FT, out = EXPL; two conjuncts by assumption;
             the third: gen ok a r c q n, DISCH_TAC [g = TUP]; MATCH_MP_TAC ECON leaves FT = TUP; metis from
             g = FT and g = TUP. *)
          val K3 = thm "refund_frame_contract_key"
            (fn () => list_mk_forall ([p1, p2, outv], mk_imp (DJo, newc3 outv)))
            (fn () => try_all "refund_frame_contract_key"
               [rpt gen_tac \\ DISCH_THEN (fn th => ASSUME_TAC (MATCH_MP KEY th))
                  \\ X_GEN_TAC gv \\ DISCH_TAC
                  \\ first_x_assum (fn th => first_assum (STRIP_ASSUME_TAC o MATCH_MP th))
                  \\ CONJ_TAC >- FIRST_ASSUM ACCEPT_TAC
                  \\ CONJ_TAC >- FIRST_ASSUM ACCEPT_TAC
                  \\ rpt gen_tac \\ DISCH_TAC \\ MATCH_MP_TAC ECON \\ metis_tac [],
                rpt gen_tac \\ DISCH_THEN (fn th => ASSUME_TAC (MATCH_MP KEY th))
                  \\ rpt strip_tac \\ res_tac \\ TRY (FIRST_ASSUM ACCEPT_TAC)
                  \\ MATCH_MP_TAC ECON \\ metis_tac []])
          val M3_STMT = mk_imp (PREM, body_with (newc3 FDW))
          val M3 = thm "refund_model_frame_meets_exported_contract"
            (fn () => M3_STMT) (fn () => try_all "refund_model_frame_meets_exported_contract" (frame_tacs K3))
          val _ = if aconv (fst (dest_imp (concl M3))) PREM then pr "CONTROL_OK M3 premise is the stored premise term"
                  else bad "M3-premise"
        in SOME M3 end
     end)
    handle e => (pr ("M3_BUILD_FAILED " ^ trunc 300 (General.exnMessage e)); failed := "M3-build" :: !failed; NONE));

(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = pr ("FAILED_LIST " ^ String.concatWith " " (rev (!failed)));
val _ = pr ("DIAG_OK_UNDER_LIST " ^ String.concatWith " " (rev (!diag)));
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
(* c1 *)
val _ = if aconv (fst (dest_imp (concl M1))) PREM
        then pr "CONTROL_OK c1 refund_model_frame_decision premise is term-identical to the premise of refund_profile_a_sl_fd1"
        else bad "c1-M1-premise";
val _ = if aconv (fst (dest_imp (concl M2))) PREM then pr "CONTROL_OK M2 premise is the stored premise term" else bad "M2-premise";
val _ = if aconv (concl M1) M1_STMT then pr "CONTROL_OK M1 statement is the planned term" else bad "M1-statement";
val _ = if has_const "refund_strict_parse" (snd (dest_imp (concl M1))) andalso
           not (Lib.mem "ext" (map (fst o dest_var) (free_vars (concl M1))))
        then pr "CONTROL_OK M1 conclusion uses refund_strict_parse and has no free ext (no_ext)" else bad "M1-shape";
(* M1b *)
val _ = if aconv (fst (dest_imp (concl M1B))) PREM2
        then pr "CONTROL_OK M1b premise is term-identical to the premise of refund_profile_a_sl_reach at ext := no_ext"
        else bad "M1b-premise";
val _ = if aconv (snd (dest_imp (concl M1B))) (snd (dest_imp (concl M1)))
        then pr "CONTROL_OK M1b conclusion is term-identical to the conclusion of M1" else bad "M1b-conclusion";
val _ = if not (has_const "refund_env_ok_sl" (fst (dest_imp (concl M1B))))
        then pr "CONTROL_OK M1b premise does not contain refund_env_ok_sl" else bad "M1b-premise-env-ok";
(* c2 *)
val _ = if aconv (rhs (concl C2)) (optionSyntax.mk_none (type_of FT))
        then pr "CONTROL_OK c2 refund_strict_parse of the empty output is NONE (a resource stop with no output is never accepted)"
        else bad "c2-shape";
(* c3 *)
val _ = if has_const "refund_env_ok_sl" (fst (dest_imp (concl M1)))
        then pr "NOTE PREMISE_STILL_FALSE_FOR_REAL_FFI refund_env_ok_sl : M1, M2 (and M3) inherit the stored all-states FFI premise (falsified for the real FFI by U393)"
        else bad "c3-premise-missing";
val _ = pr "NOTE M1B_PREMISE_UNPROVED ffi_calls_ok Vok at every clock (lemma L3) is not proved; M1b is conditional on it";
val _ = pr ("NOTE CONTRACT_MODE " ^ (if contract_imported then "imported" else "absent") ^
            " M3 " ^ (if isSome M3opt then "proved" else "not attempted"));
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundModelFrame" @ DB.definitions "forge_refundModelFrame");
val closure = "forge_refundModelFrame" :: Theory.ancestry "forge_refundModelFrame";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = pr ("PARENTS " ^ String.concatWith " " (Theory.parents "forge_refundModelFrame"));
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundModelFrame")));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions "forge_refundModelFrame")));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

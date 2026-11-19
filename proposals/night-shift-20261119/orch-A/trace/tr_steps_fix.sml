(* tr_steps_fix.sml (worker W-trace, round 3, 2026-11-19). NOT RUN; every tactic UNCHECKED.
   Repaired step lists for the four lemmas that failed in TRx-0003 (attempt-0001/TRx-0003/stdout.log 555-760):
   trace_terminate, trace_fail (required), trace_diverge, toy_bad_not_followed (optional).
   Diagnosis (read from the log, not run again):
   - All three behaviour lemmas failed at step 1, all candidates, with "predicate not true" from Lib.assert.
     drule_all (HOL src/1/Tactic.sml 1327-1336) asserts at the end that the result is no longer an implication.
     So drule_all could not discharge an antecedent of term_after / fail_after / div_after: the first one,
     "!k. evaluate mc st (n + k) ms = ...".
     Reason: drule (mp_then) leaves the variables of the consequent that were not matched FREE, not quantified.
     So "qspecl_then [P,G,g] drule evaluate_follows_trace" gave an assumption with a FREE k, never "!k. ...".
   - The same fact explains toy_bad_not_followed. Steps 3 and 5 rewrote nothing: the goal at step 6 still shows
     "evaluate MCB toy_st (SUC (SUC 0)) 0w". The drule_all results had free st and k, so REWRITE_TAC [th] could not
     match toy_st and SUC 0.
     (In trace_gen the same tactic worked only because the goal used the same names st and k.)
   Repair: no drule on a lemma whose consequent has an unmatched variable.
   - The "!k" fact is proved explicitly: gen_tac, MATCH_MP_TAC, ACCEPT.
   - term_after / fail_after / div_after are instantiated in full with qspecl_then (or Q.ISPECL_THEN as the
     alternative); their antecedents are closed by ACCEPT_TAC (or metis_tac).
   - The toy one-event lemmas are instantiated in full with Q.ISPECL.
   Needs, in the caller's context: pr, trunc, showg, tlim, Q, TH, LATE, step_tac, head_replay, ST, MC_C, MC_F, ENDST,
   ENDMS, MCB, MCB1, and the SML values of the definitions used below (trace_next_interfer_def, trace_ffi_interfer_def,
   trace_last_def, step_event_ok_def, ffi_event_ok_def, toy_mc_def, toy_st_def).
   ASCII only. *)
val _ = pr "TR_STEPS_FIX opened";
fun fclosing (t : tactic) : tactic = t \\ NO_TAC;
val FORALL_K = "!k. targetSem$evaluate " ^ MC_C ^ " st (LENGTH tr + k) ms = targetSem$evaluate " ^ MC_F ^ " " ^
               ENDST ^ "k " ^ ENDMS;
val ENDST0 = "trace_st mc st ms tr";
val ENDMS0 = "trace_last ms tr";
fun all_k () : tactic = LATE (fn () =>
  Q FORALL_K by (gen_tac \\ MATCH_MP_TAC (TH "evaluate_follows_trace") \\ first_assum ACCEPT_TAC));
fun all_k_alt () : tactic = LATE (fn () =>
  Q FORALL_K by (gen_tac \\ irule (TH "evaluate_follows_trace") \\ metis_tac []));
fun io_fact () : tactic = LATE (fn () =>
  Q "(trace_st mc st ms tr).io_events = st.io_events ++ trace_events mc ms tr" by
    (MATCH_MP_TAC (TH "trace_io") \\ qexistsl [Q "P", Q "G"] \\ first_assum ACCEPT_TAC));
fun io_fact_alt () : tactic = LATE (fn () =>
  Q "(trace_st mc st ms tr).io_events = st.io_events ++ trace_events mc ms tr" by
    metis_tac [TH "trace_io"]);
fun inst (lemma : string) (extra : string list) : tactic = LATE (fn () =>
  qspecl_then (map Q ([MC_C, "st", "ms", MC_F, ENDST0, ENDMS0, "LENGTH tr"] @ extra)) mp_tac (TH lemma));
fun inst_alt (lemma : string) (extra : string list) : tactic = LATE (fn () =>
  Q.ISPECL_THEN (map Q ([MC_C, "st", "ms", MC_F, ENDST0, ENDMS0, "LENGTH tr"] @ extra)) mp_tac (TH lemma));
val discharge : tactic = impl_tac >- (conj_tac \\ first_assum ACCEPT_TAC);
val discharge_alt : tactic = impl_tac >- metis_tac [];
fun rewrite_io (pat : string) : tactic =
  qpat_x_assum (Q pat) mp_tac \\
  qpat_x_assum (Q "(trace_st _ _ _ _).io_events = _") (fn th => REWRITE_TAC [th]);

val FIX_TERM : (string * tactic * tactic list) list =
  [("intro", rpt gen_tac \\ strip_tac, []),
   ("io fact", io_fact (), [io_fact_alt ()]),
   ("all clocks (explicit !k)", all_k (), [all_k_alt ()]),
   ("instantiate term_after", inst "term_after" ["t", "io"], [inst_alt "term_after" ["t", "io"]]),
   ("discharge", discharge, [discharge_alt]),
   ("split", strip_tac \\ conj_tac, []),
   ("behaviour", fclosing (first_assum ACCEPT_TAC), [fclosing (fs []), fclosing (metis_tac [])]),
   ("prefix", fclosing (rewrite_io "isPREFIX _ io"), [fclosing (fs []), fclosing (metis_tac [])])];
val FIX_FAIL : (string * tactic * tactic list) list =
  [("intro", rpt gen_tac \\ strip_tac, []),
   ("all clocks (explicit !k)", all_k (), [all_k_alt ()]),
   ("instantiate fail_after", inst "fail_after" [], [inst_alt "fail_after" []]),
   ("discharge", discharge, [discharge_alt]),
   ("close", fclosing (disch_then ACCEPT_TAC), [fclosing (strip_tac \\ fs []), fclosing (metis_tac [])])];
val FIX_DIV : (string * tactic * tactic list) list =
  [("intro", rpt gen_tac \\ strip_tac, []),
   ("io fact", io_fact (), [io_fact_alt ()]),
   ("all clocks (explicit !k)", all_k (), [all_k_alt ()]),
   ("instantiate div_after", inst "div_after" ["l"], [inst_alt "div_after" ["l"]]),
   ("discharge", discharge, [discharge_alt]),
   ("rewrite io", fclosing (strip_tac \\ rewrite_io "LPREFIX _ l"), [fclosing (strip_tac \\ fs []),
                                                                      fclosing (metis_tac [])])];
(* toy: steps 1 and 2 = TOY_NEG steps 1, 2 of tr_steps2.sml (same text); step 4 = TOY_NEG step 4 with RFB, RFB1 written as
   targetSemTheory.read_ffi_bytearrays_def, targetSemTheory.read_ffi_bytearray_def (same theorems), main candidate only;
   steps 3 and 5 instantiate the one-event lemmas in full (Q.ISPECL); step 6 = TOY_NEG step 6 plus one candidate *)
val FIX_TOY : (string * tactic * tactic list) list =
  [("clock 2", REWRITE_TAC [listTheory.LENGTH, arithmeticTheory.ADD_CLAUSES], []),
   ("step facts", LATE (fn () =>
       (Q ("step_event_ok " ^ MCB ^ " 0w 1w") by simp [step_event_ok_def, toy_mc_def, TH "toy_target_fields",
                                                     TH "toy_encoded"]) \\
       (Q (MCB ^ ".next_interfer 0 (" ^ MCB ^ ".target.next 0w) = 1w") by
           simp [trace_next_interfer_def, toy_mc_def, TH "toy_target_fields"])),
      [LATE (fn () =>
       (Q ("step_event_ok " ^ MCB ^ " 0w 1w") by (simp [step_event_ok_def, toy_mc_def, TH "toy_target_fields",
                                                      TH "toy_encoded"] \\ EVAL_TAC)) \\
       (Q (MCB ^ ".next_interfer 0 (" ^ MCB ^ ".target.next 0w) = 1w") by
           (simp [trace_next_interfer_def, toy_mc_def, TH "toy_target_fields"] \\ EVAL_TAC)))]),
   ("one step (full instance)", LATE (fn () =>
       mp_tac (Q.ISPECL [Q MCB, Q "toy_st", Q "0w:word64", Q "1w:word64", Q "SUC 0"] (TH "evaluate_one_step_event")) \\
       impl_tac >- (conj_tac \\ first_assum ACCEPT_TAC) \\ disch_then (fn th => REWRITE_TAC [th])),
      [LATE (fn () =>
       mp_tac (Q.ISPECL [Q MCB, Q "toy_st", Q "0w:word64", Q "1w:word64", Q "SUC 0"] (TH "evaluate_one_step_event")) \\
       impl_tac >- metis_tac [] \\ disch_then (fn th => REWRITE_TAC [th]))]),
   ("ffi facts (oracle answers [], the trace records [7w])", LATE (fn () =>
       (Q ("ffi_event_ok " ^ MCB1 ^ " toy_st 1w 0 []") by
           simp [ffi_event_ok_def, toy_mc_def, TH "toy_target_fields", targetSemTheory.read_ffi_bytearrays_def,
                 targetSemTheory.read_ffi_bytearray_def, miscTheory.read_bytearray_def,
                 ffiTheory.call_FFI_def, toy_st_def, miscTheory.find_index_def]) \\
       (Q (MCB1 ^ ".ffi_interfer 0 (0,[],1w) = 5w") by simp [trace_ffi_interfer_def])),
      []),
   ("one ffi event (full instance)", LATE (fn () =>
       mp_tac (Q.ISPECL [Q MCB1, Q "toy_st", Q "1w:word64", Q "0", Q "[]:word8 list", Q "5w:word64", Q "0"]
                        (TH "evaluate_one_ffi_event")) \\
       impl_tac >- (conj_tac \\ first_assum ACCEPT_TAC) \\ disch_then (fn th => REWRITE_TAC [th])),
      [LATE (fn () =>
       mp_tac (Q.ISPECL [Q MCB1, Q "toy_st", Q "1w:word64", Q "0", Q "[]:word8 list", Q "5w:word64", Q "0"]
                        (TH "evaluate_one_ffi_event")) \\
       impl_tac >- metis_tac [] \\ disch_then (fn th => REWRITE_TAC [th]))]),
   ("states differ (5w versus 2w)", fclosing (LATE (fn () => REWRITE_TAC [TH "evaluate_zero"] \\ simp [trace_last_def])),
      [fclosing (LATE (fn () => REWRITE_TAC [TH "evaluate_zero"] \\ simp [trace_last_def] \\ EVAL_TAC)),
       fclosing (LATE (fn () => simp [TH "evaluate_zero", trace_last_def]))])];

(* order and flags: the two required lemmas first *)
val FIX_LEMMAS : (string * term * (string * tactic * tactic list) list * bool) list =
  [("trace_terminate", ST "trace_terminate", FIX_TERM, true),
   ("trace_fail", ST "trace_fail", FIX_FAIL, true),
   ("trace_diverge", ST "trace_diverge", FIX_DIV, false),
   ("toy_bad_not_followed", ST "toy_bad_not_followed", FIX_TOY, false)];
val _ = pr "TR_STEPS_FIX loaded";

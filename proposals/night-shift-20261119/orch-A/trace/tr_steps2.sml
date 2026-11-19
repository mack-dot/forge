(* tr_steps2.sml = tr_steps.sml with the changes of CHANGES_TR.txt (toy_config_def in TOY_ENC; optional lemmas
   dropped when their statement or the toy definitions failed). Needs tr_common2.sml.
   tr_steps.sml (worker W-trace, 2026-11-19). The ONE file of step lists, read with use by BOTH TRx-0001.sml
   (exploration) and trace_v1.sml (proof, case TR-0001), after tr_common.sml. NOT RUN: every tactic UNCHECKED.
   Method = round13/r6r_steps.sml: a step = (label, main, alternatives); the proof takes the FIRST candidate that
   succeeds on the HEAD goal; the exploration prints goals after each step. Every reference to a proved lemma goes
   through TH inside LATE (read at run time). Each event costs ONE unfolding of evaluate_def (LHS_CONV ONCE_REWRITE_CONV,
   so the right-hand evaluate is never unfolded). ASCII only; quotations as Q "...". THEN is written \\ . *)
val _ = pr "TR_STEPS opened";
fun closing (t : tactic) : tactic = t \\ NO_TAC;
type step = string * tactic * tactic list;
val evaluate_def = targetSemTheory.evaluate_def;
val apply_oracle_def = targetSemTheory.apply_oracle_def;
val RFB = targetSemTheory.read_ffi_bytearrays_def;
val RFB1 = targetSemTheory.read_ffi_bytearray_def;
val CEQ = targetSemTheory.machine_config_component_equality;
val SEM = targetSemTheory.machine_sem_def;
val SHIFT = miscTheory.shift_seq_def;
fun unfold_lhs_once () : tactic = CONV_TAC (LHS_CONV (ONCE_REWRITE_CONV [evaluate_def]));
fun one (t : tactic) (alts : tactic list) : step list = [("close", closing t, map closing alts)];

(* ---------------- shift_seq ---------------- *)
val SS_SS = one (simp [SHIFT, FUN_EQ_THM])
  [rw [SHIFT, FUN_EQ_THM] \\ AP_TERM_TAC \\ decide_tac, simp [FUN_EQ_THM, SHIFT, arithmeticTheory.ADD_ASSOC]];
val SS_0 = one (simp [SHIFT, FUN_EQ_THM]) [rw [SHIFT, FUN_EQ_THM]];
val SS_1P = one (gen_tac \\ Cases \\ simp [SHIFT, arithmeticTheory.ADD1])
  [gen_tac \\ Cases \\ fs [SHIFT], rw [SHIFT] \\ AP_TERM_TAC \\ decide_tac];

(* ---------------- the constructed oracles: eta forms ---------------- *)
val NI_FFI = one (simp [FUN_EQ_THM, trace_next_interfer_def]) [rw [FUN_EQ_THM, trace_next_interfer_def]];
val NI_SHIFT = one (simp [FUN_EQ_THM, SHIFT, trace_next_interfer_def])
  [rw [FUN_EQ_THM, SHIFT, trace_next_interfer_def]];
val FI_NIL = one (simp [FUN_EQ_THM, trace_ffi_interfer_def]) [rw [FUN_EQ_THM, trace_ffi_interfer_def]];
val FI_STEP = one (simp [FUN_EQ_THM, trace_ffi_interfer_def]) [rw [FUN_EQ_THM, trace_ffi_interfer_def]];
val FI_SHIFT = one (simp [FUN_EQ_THM, SHIFT, trace_ffi_interfer_def])
  [rw [FUN_EQ_THM, SHIFT, trace_ffi_interfer_def]];

(* ---------------- interference_ok and the FFI guard ---------------- *)
val NI_PROJ : step list =
  [("induct", gen_tac \\ Induct_on (Q "tr"), []),
   ("base", closing (simp [trace_next_interfer_def]), [closing (rw [trace_next_interfer_def])]),
   ("step", closing (Cases \\ rw [trace_next_interfer_def] \\ fs []),
      [closing (Cases \\ rw [trace_next_interfer_def] \\ metis_tac []),
       closing (Cases \\ simp [trace_next_interfer_def] \\ rw [] \\ fs [])])];
val NI_OK = one (LATE (fn () => rw [asmPropsTheory.interference_ok_def] \\
                                MATCH_ACCEPT_TAC (TH "trace_next_interfer_proj")))
  [LATE (fn () => simp [asmPropsTheory.interference_ok_def] \\ metis_tac [TH "trace_next_interfer_proj"])];
val FI_GUARD : step list =
  [("induct", gen_tac \\ Induct_on (Q "tr"), []),
   ("base", closing (simp [trace_ffi_interfer_def]), []),
   ("cases", Cases, []),
   ("TrStep", closing (rpt gen_tac \\ REWRITE_TAC [trace_ffi_interfer_def] \\ first_x_assum MATCH_ACCEPT_TAC),
      [closing (simp [trace_ffi_interfer_def]), closing (rpt gen_tac \\ simp [trace_ffi_interfer_def] \\ metis_tac [])]),
   ("TrFfi split on k", rpt gen_tac \\ rename1 (Q "TrFfi i nb s") \\ Cases_on (Q "k = 0"), []),
   ("k = 0", closing (asm_rewrite_tac [trace_ffi_interfer_def] \\ Cases_on (Q "x = (i,nb,ms0) /\\ G x s") \\
                      asm_rewrite_tac [] \\ metis_tac []),
      [closing (rw [trace_ffi_interfer_def] \\ fs []), closing (simp [trace_ffi_interfer_def] \\ rw [] \\ metis_tac [])]),
   ("k <> 0", closing (LATE (fn () => asm_rewrite_tac [trace_ffi_interfer_def] \\
                      first_x_assum (qspecl_then [Q "shift_seq 1 g", Q "s", Q "k - 1", Q "x"] mp_tac) \\
                      simp [TH "shift_seq_1_pred"])),
      [closing (LATE (fn () => asm_rewrite_tac [trace_ffi_interfer_def] \\
                      metis_tac [TH "shift_seq_1_pred"]))])];
val FI_OFF = one (LATE (fn () => metis_tac [TH "trace_ffi_interfer_guard"])) [];

(* ---------------- independence from the two oracle fields ---------------- *)
val STEP_UPD = one (simp [step_event_ok_def]) [rw [step_event_ok_def]];
val FFI_UPD = one (simp [ffi_event_ok_def, RFB, RFB1]) [rw [ffi_event_ok_def, RFB, RFB1]];
val POST_UPD = one (simp [ffi_post_st_def, RFB, RFB1]) [rw [ffi_post_st_def, RFB, RFB1]];
val OK_UPD : step list =
  [("induct", ntac 2 gen_tac \\ Induct_on (Q "tr"), []),
   ("base", closing (simp [trace_ok_def]), []),
   ("step", closing (LATE (fn () => Cases \\ simp [trace_ok_def, TH "step_event_ok_upd", TH "ffi_event_ok_upd",
                                                   TH "ffi_post_st_upd"])),
      [closing (LATE (fn () => Cases \\ fs [trace_ok_def, TH "step_event_ok_upd", TH "ffi_event_ok_upd",
                                             TH "ffi_post_st_upd"]))])];
val ST_UPD : step list =
  [("induct", Induct_on (Q "tr"), []),
   ("base", closing (simp [trace_st_def]), []),
   ("step", closing (LATE (fn () => Cases \\ simp [trace_st_def, TH "ffi_post_st_upd"])),
      [closing (LATE (fn () => Cases \\ fs [trace_st_def, TH "ffi_post_st_upd"]))])];
val CONG = one (rw []) [rpt strip_tac \\ rveq \\ REFL_TAC];
val EVAL0 = one (simp [Once evaluate_def]) [rw [Once evaluate_def], ONCE_REWRITE_TAC [evaluate_def] \\ simp []];

(* ---------------- the two one-event lemmas: one unfolding of evaluate_def each ---------------- *)
val ONE_STEP : step list =
  [("intro", rpt strip_tac \\ fs [step_event_ok_def], [rw [step_event_ok_def]]),
   ("unfold evaluate once (left side only)", unfold_lhs_once (), []),
   ("close", closing (simp [apply_oracle_def]),
      [closing (fs [apply_oracle_def]), closing (simp [apply_oracle_def, pairTheory.ELIM_UNCURRY]),
       closing (fs [apply_oracle_def] \\ rw [] \\ fs [])])];
val ONE_FFI : step list =
  [("intro", rpt strip_tac \\
             qpat_x_assum (Q "ffi_event_ok _ _ _ _ _") (strip_assume_tac o REWRITE_RULE [ffi_event_ok_def]),
      [rpt strip_tac \\ fs [ffi_event_ok_def]]),
   ("unfold evaluate once (left side only)", unfold_lhs_once (), []),
   ("close", closing (simp [apply_oracle_def, ffi_post_st_def]),
      [closing (fs [apply_oracle_def, ffi_post_st_def]),
       closing (simp [apply_oracle_def, ffi_post_st_def, pairTheory.ELIM_UNCURRY]),
       closing (fs [apply_oracle_def, ffi_post_st_def] \\ rw [] \\ fs [])])];

(* ---------------- T-TRACE (field form), induction on the trace ---------------- *)
val CLOCK = [listTheory.LENGTH, arithmeticTheory.ADD_CLAUSES, trace_st_def, trace_last_def, nffis_def];
fun cong_close (extra : unit -> thm list) : tactic =
  LATE (fn () => irule (TH "evaluate_cong") \\ simp ([CEQ, TH "trace_st_upd"] @ extra ()));
val GEN : step list =
  [("induct", ntac 2 gen_tac \\ Induct_on (Q "tr"), []),
   ("base", closing (LATE (fn () => rpt strip_tac \\ REWRITE_TAC CLOCK \\ irule (TH "evaluate_cong") \\
                     simp [CEQ, TH "trace_ffi_interfer_nil", TH "shift_seq_0"])),
      [closing (LATE (fn () => rpt strip_tac \\ REWRITE_TAC CLOCK \\ irule (TH "evaluate_cong") \\
                     fs [CEQ, TH "trace_ffi_interfer_nil", TH "shift_seq_0"]))]),
   ("cases", Cases, []),
   (* TrStep s *)
   ("TrStep intro", rpt strip_tac \\ rename1 (Q "TrStep s") \\
       qpat_x_assum (Q "trace_ok _ _ _ _ _ _") (strip_assume_tac o REWRITE_RULE [trace_ok_def]) \\ REWRITE_TAC CLOCK, []),
   ("TrStep oracle value", (Q "mc.next_interfer 0 (mc.target.next ms) = s" by simp [trace_next_interfer_def]),
      [(Q "mc.next_interfer 0 (mc.target.next ms) = s" by fs [trace_next_interfer_def])]),
   ("TrStep one event", LATE (fn () => drule_all (TH "evaluate_one_step_event") \\
                                       disch_then (fn th => REWRITE_TAC [th])), []),
   ("TrStep IH", LATE (fn () =>
       first_x_assum (qspecl_then [Q "mc with next_interfer := shift_seq 1 mc.next_interfer", Q "st", Q "s",
                                   Q "g", Q "k"] mp_tac) \\
       impl_tac >- simp [TH "trace_ok_upd", TH "trace_next_interfer_shift", TH "trace_ffi_interfer_step"]),
      [LATE (fn () =>
       first_x_assum (qspecl_then [Q "mc with next_interfer := shift_seq 1 mc.next_interfer", Q "st", Q "s",
                                   Q "g", Q "k"] mp_tac) \\
       impl_tac >- fs [TH "trace_ok_upd", TH "trace_next_interfer_shift", TH "trace_ffi_interfer_step"])]),
   ("TrStep apply IH", disch_then (fn th => REWRITE_TAC [th]), []),
   ("TrStep same end machine", closing (cong_close (fn () => [])), []),
   (* TrFfi i nb s *)
   ("TrFfi intro", rpt strip_tac \\ rename1 (Q "TrFfi i nb s") \\
       qpat_x_assum (Q "trace_ok _ _ _ _ _ _") (strip_assume_tac o REWRITE_RULE [trace_ok_def]) \\ REWRITE_TAC CLOCK, []),
   ("TrFfi oracle value", (Q "mc.ffi_interfer 0 (i,nb,ms) = s" by simp [trace_ffi_interfer_def]),
      [(Q "mc.ffi_interfer 0 (i,nb,ms) = s" by fs [trace_ffi_interfer_def])]),
   ("TrFfi one event", LATE (fn () => drule_all (TH "evaluate_one_ffi_event") \\
                                      disch_then (fn th => REWRITE_TAC [th])), []),
   ("TrFfi IH", LATE (fn () =>
       first_x_assum (qspecl_then [Q "mc with ffi_interfer := shift_seq 1 mc.ffi_interfer", Q "ffi_post_st mc st ms i",
                                   Q "s", Q "shift_seq 1 g", Q "k"] mp_tac) \\
       impl_tac >- simp [TH "trace_ok_upd", TH "trace_next_interfer_ffi", TH "trace_ffi_interfer_shift"]),
      [LATE (fn () =>
       first_x_assum (qspecl_then [Q "mc with ffi_interfer := shift_seq 1 mc.ffi_interfer", Q "ffi_post_st mc st ms i",
                                   Q "s", Q "shift_seq 1 g", Q "k"] mp_tac) \\
       impl_tac >- fs [TH "trace_ok_upd", TH "trace_next_interfer_ffi", TH "trace_ffi_interfer_shift"])]),
   ("TrFfi apply IH", disch_then (fn th => REWRITE_TAC [th]), []),
   ("TrFfi same end machine", closing (cong_close (fn () => [TH "shift_seq_shift_seq"])), [])];

(* T-TRACE in record-update form, from the field form *)
val FOLLOWS : step list =
  [("instantiate", LATE (fn () => rpt strip_tac \\
       qspecl_then [Q "P", Q "G", Q "tr", Q MC_C, Q "st", Q "ms", Q "g", Q "k"] mp_tac (TH "trace_gen") \\
       impl_tac >- simp [TH "trace_ok_upd"]),
      [LATE (fn () => rpt strip_tac \\
       qspecl_then [Q "P", Q "G", Q "tr", Q MC_C, Q "st", Q "ms", Q "g", Q "k"] mp_tac (TH "trace_gen") \\
       impl_tac >- fs [TH "trace_ok_upd"])]),
   ("apply", disch_then (fn th => REWRITE_TAC [th]), []),
   ("same end machine", closing (cong_close (fn () => [])), [])];

(* ---------------- io events ---------------- *)
val CALL_IO = one (rpt strip_tac \\ Cases_on (Q "n = ExtCall (strlit \"\")") \\ fs [ffiTheory.call_FFI_def] \\
                   BasicProvers.every_case_tac \\ fs [] \\ rveq \\ fs [])
  [rw [ffiTheory.call_FFI_def] \\ BasicProvers.every_case_tac \\ fs [] \\ rveq \\ fs [],
   rpt strip_tac \\ fs [ffiTheory.call_FFI_def] \\ BasicProvers.every_case_tac \\ gvs []];
val POST_IO = one (LATE (fn () => rpt strip_tac \\
      qpat_x_assum (Q "ffi_event_ok _ _ _ _ _") (strip_assume_tac o REWRITE_RULE [ffi_event_ok_def]) \\
      simp [ffi_post_st_def, ffi_call_event_def] \\ drule (TH "call_FFI_return_io") \\ simp []))
  [LATE (fn () => rpt strip_tac \\
      qpat_x_assum (Q "ffi_event_ok _ _ _ _ _") (strip_assume_tac o REWRITE_RULE [ffi_event_ok_def]) \\
      simp [ffi_post_st_def, ffi_call_event_def] \\ drule (TH "call_FFI_return_io") \\ rw [] \\ fs [])];
val TRACE_IO : step list =
  [("induct", ntac 2 gen_tac \\ Induct_on (Q "tr"), []),
   ("base", closing (simp [trace_st_def, trace_events_def]), []),
   ("cases", Cases, []),
   ("TrStep", closing (rpt strip_tac \\ fs [trace_ok_def, trace_st_def, trace_events_def]),
      [closing (rpt strip_tac \\ fs [trace_ok_def, trace_st_def, trace_events_def] \\ first_x_assum drule \\ simp [])]),
   ("TrFfi", closing (LATE (fn () => rpt strip_tac \\ fs [trace_ok_def, trace_st_def, trace_events_def] \\
                       first_x_assum drule \\ strip_tac \\ drule (TH "ffi_post_st_io") \\ strip_tac \\ fs [])),
      [closing (LATE (fn () => rpt strip_tac \\ fs [trace_ok_def, trace_st_def, trace_events_def] \\
                       res_tac \\ imp_res_tac (TH "ffi_post_st_io") \\ fs []))])];

(* ---------------- behaviours ---------------- *)
val ADDCLK = one (rpt strip_tac \\ ONCE_REWRITE_TAC [arithmeticTheory.ADD_COMM] \\
                  irule targetPropsTheory.evaluate_add_clock \\ simp [])
  [metis_tac [targetPropsTheory.evaluate_add_clock, arithmeticTheory.ADD_COMM]];
val PFX_HALT = one (rpt strip_tac \\ qspecl_then [Q "mc", Q "st", Q "k", Q "ms"] mp_tac
                      targetPropsTheory.evaluate_io_events_mono \\ simp [])
  [metis_tac [targetPropsTheory.evaluate_io_events_mono, pairTheory.SND]];
val FST_ERR = one (gen_tac \\ PairCases_on (Q "x") \\ simp []) [Cases \\ Cases_on (Q "r") \\ simp []];
fun sem_intro () : tactic =
  rpt gen_tac \\ strip_tac \\
  qpat_x_assum (Q "targetSem$machine_sem _ _ _ _") (strip_assume_tac o REWRITE_RULE [SEM]);
fun add_n () : tactic = LATE (fn () => drule (TH "add_clock_swap") \\ impl_tac >- simp [] \\
                                       disch_then (qspec_then (Q "n") assume_tac));
val TERM_AFTER : step list =
  [("intro", sem_intro (), []),
   ("add clock n", add_n (), []),
   ("transfer", (Q "targetSem$evaluate mc2 st2 k ms2 = (targetSem$Halt t,ms',st')" by metis_tac []), []),
   ("behaviour", conj_tac >- (REWRITE_TAC [SEM] \\ metis_tac []), []),
   ("prefix", closing (LATE (fn () => qpat_x_assum (Q "targetSem$evaluate mc2 _ _ _ = _")
                                        (assume_tac o MATCH_MP (TH "prefix_of_halt")) \\ fs [])),
      [closing (LATE (fn () => metis_tac [TH "prefix_of_halt"]))])];
val FAIL_AFTER : step list =
  [("intro", sem_intro (), []),
   ("triple", LATE (fn () => drule (TH "fst_error") \\ strip_tac), []),
   ("add clock n", add_n (), []),
   ("close", closing (REWRITE_TAC [SEM] \\ qexists_tac (Q "k") \\ metis_tac [pairTheory.FST]),
      [closing (REWRITE_TAC [SEM] \\ metis_tac [pairTheory.FST])])];
fun follows_then (finish : unit -> tactic) : tactic =
  LATE (fn () => rpt gen_tac \\ strip_tac \\
                 qspecl_then [Q "P", Q "G", Q "g"] drule (TH "evaluate_follows_trace") \\ strip_tac \\ finish ());
val TRACE_TERM = one (LATE (fn () => rpt gen_tac \\ strip_tac \\ drule (TH "trace_io") \\ strip_tac \\
      qspecl_then [Q "P", Q "G", Q "g"] drule (TH "evaluate_follows_trace") \\ strip_tac \\
      drule_all (TH "term_after") \\ strip_tac \\ fs []))
  [LATE (fn () => rpt gen_tac \\ strip_tac \\ drule (TH "trace_io") \\ strip_tac \\
      qspecl_then [Q "P", Q "G", Q "g"] drule (TH "evaluate_follows_trace") \\ strip_tac \\
      drule_all (TH "term_after") \\ strip_tac \\ metis_tac [])];
val TRACE_FAIL = one (follows_then (fn () => drule_all (TH "fail_after") \\ disch_then MATCH_ACCEPT_TAC))
  [follows_then (fn () => drule_all (TH "fail_after") \\ simp [])];
(* Diverge: the trace's events are a prefix of the lazy io list (optional) *)
fun lub_def () : thm = DB.fetch "lprefix_lub" "lprefix_lub_def";
val DIV_AFTER : step list =
  [("intro", LATE (fn () => rpt gen_tac \\ strip_tac \\
       qpat_x_assum (Q "targetSem$machine_sem _ _ _ _") (strip_assume_tac o REWRITE_RULE [SEM, lub_def ()])), []),
   ("k = 0", LATE (fn () => qpat_x_assum (Q "!k. targetSem$evaluate _ _ (_ + k) _ = _") (qspec_then (Q "0") mp_tac) \\
                            REWRITE_TAC [arithmeticTheory.ADD_CLAUSES, TH "evaluate_zero"] \\ strip_tac), []),
   ("lub instance", qpat_x_assum (Q "!ll. _ ==> LPREFIX ll _")
        (qspec_then (Q "fromList (SND (SND (targetSem$evaluate mc st n ms))).io_events") mp_tac) \\
        impl_tac >- (simp_tac (srw_ss ()) [pred_setTheory.IN_IMAGE] \\ TRY (qexists_tac (Q "n") \\ simp_tac (srw_ss ()) [])),
      [qpat_x_assum (Q "!ll. _ ==> LPREFIX ll _")
        (qspec_then (Q "fromList (SND (SND (targetSem$evaluate mc st n ms))).io_events") mp_tac) \\
        impl_tac >- (simp [pred_setTheory.IN_IMAGE] \\ metis_tac [pairTheory.SND])]),
   ("close", closing (simp []), [closing (fs []), closing (rw [] \\ fs [])])];
val TRACE_DIV = one (LATE (fn () => rpt gen_tac \\ strip_tac \\ drule (TH "trace_io") \\ strip_tac \\
      qspecl_then [Q "P", Q "G", Q "g"] drule (TH "evaluate_follows_trace") \\ strip_tac \\
      drule_all (TH "div_after") \\ fs []))
  [LATE (fn () => rpt gen_tac \\ strip_tac \\ drule (TH "trace_io") \\ strip_tac \\
      qspecl_then [Q "P", Q "G", Q "g"] drule (TH "evaluate_follows_trace") \\ strip_tac \\
      drule_all (TH "div_after") \\ metis_tac [])];

(* ---------------- controls ---------------- *)
val TOY_FIELDS = one (simp [toy_target_def]) [rw [toy_target_def]];
val TOY_ENC : step list =
  [("intro", rpt strip_tac \\ REWRITE_TAC [targetSemTheory.encoded_bytes_in_mem_def], []),
   ("witness", qexists_tac (Q "ARB") \\ qexists_tac (Q "0"), [qexistsl [Q "ARB", Q "0"]]),
   ("close", closing (simp [toy_target_def, toy_config_def, miscTheory.bytes_in_memory_def]),
      [closing (fs [toy_target_def, toy_config_def, miscTheory.bytes_in_memory_def]),
       closing (simp [toy_target_def, toy_config_def, miscTheory.bytes_in_memory_def] \\ EVAL_TAC \\ fs [])])];
fun TOY_SET () : thm list =
  [trace_ok_def, step_event_ok_def, ffi_event_ok_def, toy_mc_def, TH "toy_target_fields", TH "toy_encoded",
   RFB, RFB1, miscTheory.read_bytearray_def, ffiTheory.call_FFI_def, toy_st_def, miscTheory.find_index_def];
val TOY_OK = one (LATE (fn () => simp (TOY_SET ())))
  [LATE (fn () => simp (TOY_SET ()) \\ EVAL_TAC),
   LATE (fn () => simp (TOY_SET () @ [wordsTheory.n2w_11, wordsTheory.dimword_64])),
   LATE (fn () => rw (TOY_SET ()) \\ EVAL_TAC)];
val TOY_EVENTS = one (LATE (fn () => simp [trace_events_def, ffi_call_event_def, toy_mc_def, TH "toy_target_fields",
                                           RFB, RFB1, miscTheory.read_bytearray_def]))
  [LATE (fn () => simp [trace_events_def, ffi_call_event_def, toy_mc_def, TH "toy_target_fields",
                        RFB, RFB1, miscTheory.read_bytearray_def] \\ EVAL_TAC)];
val TOY_BAD = one (LATE (fn () => simp (TOY_SET ())))
  [LATE (fn () => simp (TOY_SET ()) \\ EVAL_TAC), LATE (fn () => rw (TOY_SET ()) \\ EVAL_TAC)];
val TOY_NEG : step list =
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
   ("one step", LATE (fn () => drule_all (TH "evaluate_one_step_event") \\ disch_then (fn th => REWRITE_TAC [th])), []),
   ("ffi facts (oracle answers [], the trace records [7w])", LATE (fn () =>
       (Q ("ffi_event_ok " ^ MCB1 ^ " toy_st 1w 0 []") by
           simp [ffi_event_ok_def, toy_mc_def, TH "toy_target_fields", RFB, RFB1, miscTheory.read_bytearray_def,
                 ffiTheory.call_FFI_def, toy_st_def, miscTheory.find_index_def]) \\
       (Q (MCB1 ^ ".ffi_interfer 0 (0,[],1w) = 5w") by simp [trace_ffi_interfer_def])),
      [LATE (fn () =>
       (Q ("ffi_event_ok " ^ MCB1 ^ " toy_st 1w 0 []") by
           (simp [ffi_event_ok_def, toy_mc_def, TH "toy_target_fields", RFB, RFB1, miscTheory.read_bytearray_def,
                  ffiTheory.call_FFI_def, toy_st_def, miscTheory.find_index_def] \\ EVAL_TAC)) \\
       (Q (MCB1 ^ ".ffi_interfer 0 (0,[],1w) = 5w") by (simp [trace_ffi_interfer_def] \\ EVAL_TAC)))]),
   ("one ffi event", LATE (fn () => drule_all (TH "evaluate_one_ffi_event") \\ disch_then (fn th => REWRITE_TAC [th])),
      []),
   ("states differ (5w versus 2w)", closing (LATE (fn () => REWRITE_TAC [TH "evaluate_zero"] \\ simp [trace_last_def])),
      [closing (LATE (fn () => REWRITE_TAC [TH "evaluate_zero"] \\ simp [trace_last_def] \\ EVAL_TAC))])];

(* ================= the lemma list (dependency order; true = required) ================= *)
val TR_LEMMAS0 : (string * term * step list * bool) list =
  [("shift_seq_shift_seq", ST "shift_seq_shift_seq", SS_SS, true),
   ("shift_seq_0", ST "shift_seq_0", SS_0, true),
   ("shift_seq_1_pred", ST "shift_seq_1_pred", SS_1P, true),
   ("trace_next_interfer_ffi", ST "trace_next_interfer_ffi", NI_FFI, true),
   ("trace_next_interfer_shift", ST "trace_next_interfer_shift", NI_SHIFT, true),
   ("trace_ffi_interfer_nil", ST "trace_ffi_interfer_nil", FI_NIL, true),
   ("trace_ffi_interfer_step", ST "trace_ffi_interfer_step", FI_STEP, true),
   ("trace_ffi_interfer_shift", ST "trace_ffi_interfer_shift", FI_SHIFT, true),
   ("trace_next_interfer_proj", ST "trace_next_interfer_proj", NI_PROJ, true),
   ("trace_next_interfer_ok", ST "trace_next_interfer_ok", NI_OK, true),
   ("trace_ffi_interfer_guard", ST "trace_ffi_interfer_guard", FI_GUARD, true),
   ("trace_ffi_interfer_off", ST "trace_ffi_interfer_off", FI_OFF, true),
   ("step_event_ok_upd", ST "step_event_ok_upd", STEP_UPD, true),
   ("ffi_event_ok_upd", ST "ffi_event_ok_upd", FFI_UPD, true),
   ("ffi_post_st_upd", ST "ffi_post_st_upd", POST_UPD, true),
   ("trace_ok_upd", ST "trace_ok_upd", OK_UPD, true),
   ("trace_st_upd", ST "trace_st_upd", ST_UPD, true),
   ("evaluate_cong", ST "evaluate_cong", CONG, true),
   ("evaluate_zero", ST "evaluate_zero", EVAL0, true),
   ("evaluate_one_step_event", ST "evaluate_one_step_event", ONE_STEP, true),
   ("evaluate_one_ffi_event", ST "evaluate_one_ffi_event", ONE_FFI, true),
   ("trace_gen", ST "trace_gen", GEN, true),
   ("evaluate_follows_trace", ST "evaluate_follows_trace", FOLLOWS, true),
   ("call_FFI_return_io", ST "call_FFI_return_io", CALL_IO, true),
   ("ffi_post_st_io", ST "ffi_post_st_io", POST_IO, true),
   ("trace_io", ST "trace_io", TRACE_IO, true),
   ("add_clock_swap", ST "add_clock_swap", ADDCLK, true),
   ("prefix_of_halt", ST "prefix_of_halt", PFX_HALT, true),
   ("fst_error", ST "fst_error", FST_ERR, true),
   ("term_after", ST "term_after", TERM_AFTER, true),
   ("fail_after", ST "fail_after", FAIL_AFTER, true),
   ("trace_terminate", ST "trace_terminate", TRACE_TERM, true),
   ("trace_fail", ST "trace_fail", TRACE_FAIL, true),
   ("div_after", ST "div_after", DIV_AFTER, false),
   ("trace_diverge", ST "trace_diverge", TRACE_DIV, false),
   ("toy_target_fields", ST "toy_target_fields", TOY_FIELDS, false),
   ("toy_encoded", ST "toy_encoded", TOY_ENC, false),
   ("toy_trace_ok", ST "toy_trace_ok", TOY_OK, false),
   ("toy_trace_events", ST "toy_trace_events", TOY_EVENTS, false),
   ("toy_bad_rejected", ST "toy_bad_rejected", TOY_BAD, false),
   ("toy_bad_not_followed", ST "toy_bad_not_followed", TOY_NEG, false)];
(* tr_steps2: an optional lemma is dropped when its statement did not parse (T) or, for a control, when the toy
   definitions failed; required lemmas are never dropped *)
fun keep ((nm, t, _, req) : string * term * step list * bool) : bool =
  req orelse
  (not (aconv t T) andalso (not (String.isPrefix "toy_" nm) orelse !TOY_DEFS_OK)) orelse
  (pr ("OPTIONAL_DROPPED " ^ nm); false);
val TR_LEMMAS = List.filter keep TR_LEMMAS0;
val _ = pr ("TR_LEMMAS " ^ Int.toString (length TR_LEMMAS) ^ " of " ^ Int.toString (length TR_LEMMAS0));
val _ = pr "TR_STEPS loaded";

(* xg_steps.sml (worker W-x8glue, 2026-11-19). NOT RUN: every tactic UNCHECKED. The ONE file of step lists, read with
   use by XGx-0001.sml (exploration) and XG-0001.sml (proof) after xg_common.sml. Method = trace/tr_steps2.sml: a step
   = (label, main, alternatives); the proof takes the FIRST candidate that succeeds on the HEAD goal. Every reference to
   an XG lemma goes through TH inside LATE (read at run time); parent theorems are SML values of xg_common.sml.
   Pinned-HOL lessons applied: no gvs/fs on goals with "var = const" implications in the main candidates; drule is
   not used (full ISPECL/SPECL instances); THEN written with two backslashes. ASCII only. *)
val _ = pr "XG_STEPS opened";
fun closing (t : tactic) : tactic = t \\ NO_TAC;
fun one (t : tactic) (alts : tactic list) : step list = [("close", closing t, map closing alts)];

(* the bound variables of refund_ffi_contract_at_def (also those of refund_ffi_contract_on_def, L1-0001 built it
   from the same list) *)
val AT_QVS = let val (_, eq) = strip_forall (concl AT_DEF) in fst (strip_forall (rhs eq)) end;
val _ = ctl (length AT_QVS = 7) ("contract_at binds 7 variables: " ^ String.concatWith " " (map (fst o dest_var) AT_QVS));
val kv = el 1 AT_QVS;
val XTUP = pairSyntax.list_mk_pair [el 2 AT_QVS, el 3 AT_QVS, el 4 AT_QVS];
fun is_guard_asm (t : term) : bool = app_of "refund_trace_guard" 3 t;
val accept_asms : tactic = rpt conj_tac \\ FIRST_ASSUM ACCEPT_TAC;

(* ---------------- small facts ---------------- *)
val ABSK = one (REWRITE_TAC [ABS_DEF]) [simp [ABS_DEF], rw [ABS_DEF]];
val GUNF = one (simp [GUARD_DEF, ABS_DEF])
  [rw [GUARD_DEF, ABS_DEF], REWRITE_TAC [GUARD_DEF, ABS_DEF] \\ simp [], rw [GUARD_DEF, ABS_DEF] \\ metis_tac []];
(* G1 = ML-01: an instance of trace_next_interfer_ok (TR1-0001) *)
val G1 = one (rpt gen_tac \\ MATCH_ACCEPT_TAC NIOK)
  [rpt gen_tac \\ ACCEPT_TAC (ISPECL [mk_PR dmv, trv] NIOK), simp [NIOK], metis_tac [NIOK]];

(* ---------------- G2 = ML-02: the constructed FFI oracle meets the STORED contract at every argument ----------- *)
(* Hand walk. After unfolding, the goal is the 4-part conclusion of the contract for TFI k x, x = (index,new_bytes,ms2),
   under the 8 contract hypotheses. refund_abs_ffi_contract_at gives the same 4 parts for refund_abs_ffi k x.
   trace_ffi_interfer_guard splits: (a) TFI k x = refund_abs_ffi k x: rewrite; (b) refund_trace_guard dm x (TFI k x):
   its 4 parts say TFI k x agrees with refund_abs_ffi 0 x = refund_abs_ffi k x (XG_abs_ffi_any_k) on arm8_ok, PC, dm
   memory and x19-x25, x27, x28; chain the equalities. *)
val GUARD_EXPAND : tactic = LATE (fn () =>
  FIRST_ASSUM (fn th =>
    if is_guard_asm (concl th)
    then STRIP_ASSUME_TAC (REWRITE_RULE [GUARD_DEF, SPECL [numSyntax.zero_tm, kv] (TH "XG_abs_ffi_any_k")] th)
    else NO_TAC));
val CAT : step list =
  [("unfold", rpt gen_tac \\ REWRITE_TAC [AT_DEF] \\ rpt gen_tac \\ strip_tac, []),
   ("abstract effect facts",
      mp_tac (ISPECL [pc0v, dmv] ABS_AT) \\ REWRITE_TAC [AT_DEF] \\ disch_then (mp_tac o SPECL AT_QVS) \\
      impl_tac >- accept_asms \\ strip_tac,
      [mp_tac (ISPECL [pc0v, dmv] ABS_AT) \\ REWRITE_TAC [AT_DEF] \\ disch_then (mp_tac o SPECL AT_QVS) \\
       impl_tac >- ASM_REWRITE_TAC [] \\ strip_tac]),
   ("guard split", STRIP_ASSUME_TAC (ISPECL [mk_comb (GUARD_C, dmv), trv, ABS_C, ms0v, kv, XTUP] FIGUARD), []),
   ("case default effect", closing (ASM_REWRITE_TAC []), [closing (metis_tac []), closing (fs [])]),
   ("case guard: expand", GUARD_EXPAND,
      [LATE (fn () => qpat_x_assum (Q "refund_trace_guard _ _ _")
                        (strip_assume_tac o REWRITE_RULE [GUARD_DEF, SPECL [numSyntax.zero_tm, kv]
                                                                          (TH "XG_abs_ffi_any_k")]))]),
   ("case guard: chain", closing (rpt conj_tac \\ metis_tac []),
      [closing (rpt conj_tac \\ rpt strip_tac \\ res_tac \\ ASM_REWRITE_TAC []),
       closing (rw [] \\ metis_tac [])])];
val CON : step list =
  [("unfold", rpt gen_tac \\ REWRITE_TAC [ON_DEF] \\ rpt gen_tac \\ strip_tac, []),
   ("from contract_at", closing (LATE (fn () =>
       mp_tac (ISPECL [pc0v, dmv, ms0v, trv] (TH "XG_contract_at")) \\ REWRITE_TAC [AT_DEF] \\
       disch_then (mp_tac o SPECL AT_QVS) \\ impl_tac >- accept_asms \\ disch_then ACCEPT_TAC)),
      [closing (LATE (fn () =>
       mp_tac (ISPECL [pc0v, dmv, ms0v, trv] (TH "XG_contract_at")) \\ REWRITE_TAC [AT_DEF] \\
       disch_then (mp_tac o SPECL AT_QVS) \\ ASM_REWRITE_TAC [])),
       closing (LATE (fn () => metis_tac [TH "XG_contract_at", AT_DEF]))])];

(* ---------------- the constructed environment (G4 = ML-03) ---------------- *)
val FLD = one (simp [ENV_DEF]) [rw [ENV_DEF], REWRITE_TAC [ENV_DEF] \\ simp []];
val ENVOK = one (LATE (fn () => rpt gen_tac \\
                    REWRITE_TAC [TH "XG_env_fields", TH "XG_next_interfer_ok", TH "XG_contract_on"]))
  [LATE (fn () => simp [TH "XG_env_fields", TH "XG_next_interfer_ok", TH "XG_contract_on"]),
   LATE (fn () => metis_tac [TH "XG_env_fields", TH "XG_next_interfer_ok", TH "XG_contract_on"])];
val ENVOKSL = one (LATE (fn () => rpt gen_tac \\
                    REWRITE_TAC [OKSL_DEF, TH "XG_env_fields", TH "XG_next_interfer_ok", TH "XG_contract_at"]))
  [LATE (fn () => simp [OKSL_DEF, TH "XG_env_fields", TH "XG_next_interfer_ok", TH "XG_contract_at"])];

(* ---------------- G3: totalisation with Vok := (\i nb ms. T) is the identity; the machine equation ---------------- *)
val TOTIDS = one (gen_tac \\ REWRITE_TAC [TOTID] \\ simp [CEQ])
  [rw [TOTID, CEQ], simp [TOTID, CEQ], gen_tac \\ REWRITE_TAC [TOTID] \\ simp []];
val MCEQ = one (simp [ENV_DEF, MC_DEF, FIX_DEF])
  [simp [ENV_DEF, MC_DEF, FIX_DEF, CEQ], rw [ENV_DEF, MC_DEF, FIX_DEF, CEQ],
   rpt gen_tac \\ REWRITE_TAC [ENV_DEF, MC_DEF, FIX_DEF] \\ simp [CEQ]];

(* ---------------- G3/G5a: MT1 (candidate 0) or M3 (candidate 1) at the constructed environment ---------------- *)
val FRAME_MT1 : tactic = LATE (fn () =>
  mp_tac MT1i \\
  impl_tac >- (rpt conj_tac \\
               FIRST [FIRST_ASSUM ACCEPT_TAC,
                      REWRITE_TAC [TH "XG_env_fields", TH "XG_next_interfer_ok", TH "XG_contract_on"] \\ NO_TAC]) \\
  REWRITE_TAC [TH "XG_tot_id"] \\ disch_then ACCEPT_TAC);
val FRAME_M3 : tactic = LATE (fn () =>
  mp_tac M3i \\
  impl_tac >- (rpt conj_tac \\
               FIRST [FIRST_ASSUM ACCEPT_TAC, MATCH_ACCEPT_TAC (TH "XG_env_ok_sl"),
                      REWRITE_TAC [TH "XG_env_fields"] \\ NO_TAC]) \\
  disch_then ACCEPT_TAC);
val FRAME : step list =
  [("intro", strip_tac, []),
   ("MT1 at envR, Vok := K T (alt: M3 at envR)", closing FRAME_MT1, [closing FRAME_M3])];

(* ---------------- G5b: the trace part (TR1 only) ---------------- *)
val FOLLOWS : step list =
  [("intro", rpt gen_tac \\ strip_tac \\ conj_tac, []),
   ("evaluate follows the trace", closing (LATE (fn () =>
       gen_tac \\ REWRITE_TAC [TH "XG_mc_eq"] \\ MATCH_MP_TAC EFT \\ FIRST_ASSUM ACCEPT_TAC)),
      [closing (LATE (fn () => gen_tac \\ ONCE_REWRITE_TAC [TH "XG_mc_eq"] \\ irule EFT \\ FIRST_ASSUM ACCEPT_TAC)),
       closing (LATE (fn () => metis_tac [EFT, TH "XG_mc_eq"]))]),
   ("io events of the trace", closing (FIRST_ASSUM (ACCEPT_TAC o MATCH_MP TRIO)),
      [closing (metis_tac [TRIO])])];
val PREFIX : step list =
  [("intro", rpt strip_tac, []),
   ("follows", LATE (fn () => FIRST_ASSUM (STRIP_ASSUME_TAC o MATCH_MP (TH "XG_trace_follows"))),
      [LATE (fn () => mp_tac (ISPECL QVG (TH "XG_trace_follows")) \\ impl_tac >- FIRST_ASSUM ACCEPT_TAC \\
                      strip_tac)]),
   ("term_after", mp_tac (SPECL (#tio PG) (#TA PG)) \\ impl_tac >- (conj_tac \\ FIRST_ASSUM ACCEPT_TAC) \\ strip_tac,
      [mp_tac (SPECL (#tio PG) (#TA PG)) \\ impl_tac >- metis_tac [] \\ strip_tac]),
   ("rewrite io events", closing (metis_tac []), [closing (fs []), closing (rfs [] \\ fs [])])];
val PREFIX_TR2 : step list =
  [("intro", rpt strip_tac, []),
   ("machine equation in the assumption", LATE (fn () => RULE_ASSUM_TAC (REWRITE_RULE [TH "XG_mc_eq"])), []),
   ("trace_terminate (TR2)", closing (mp_tac (SPECL (#tio PG) (ISPECL [#PR PG, #GR PG, ABS_C, trv, #mcB PG, stv, ms0v]
                                                                       TERM2)) \\
                                      impl_tac >- (conj_tac \\ FIRST_ASSUM ACCEPT_TAC) \\ strip_tac \\
                                      FIRST_ASSUM ACCEPT_TAC),
      [closing (metis_tac [TERM2])])];

(* ---------------- G5: the composition ---------------- *)
val COMPOSE : step list =
  [("intro", strip_tac, []),
   ("model frame at envR", LATE (fn () => mp_tac (TH "XG_model_frame_trace_env") \\
                                          impl_tac >- accept_asms \\ strip_tac),
      [LATE (fn () => mp_tac (TH "XG_model_frame_trace_env") \\ impl_tac >- metis_tac [] \\ strip_tac)]),
   ("the M3 state is ms0", SUBGOAL_THEN (mk_eq (msi, ms0v)) SUBST_ALL_TAC >- metis_tac [optionTheory.SOME_11],
      [(Q "ms = ms0" by metis_tac [optionTheory.SOME_11]) \\ pop_assum SUBST_ALL_TAC]),
   ("trace facts", LATE (fn () => FIRST_ASSUM (STRIP_ASSUME_TAC o MATCH_MP (TH "XG_trace_follows"))),
      [LATE (fn () => mp_tac (ISPECL [pc0T, envmc0v, dmT, ms0v, trv, stB] (TH "XG_trace_follows")) \\
                      impl_tac >- FIRST_ASSUM ACCEPT_TAC \\ strip_tac)]),
   ("assemble", closing (LATE (fn () => rpt conj_tac \\
                   FIRST [FIRST_ASSUM ACCEPT_TAC, FIRST_ASSUM (ACCEPT_TAC o MATCH_MP (TH "XG_trace_prefix"))])),
      [closing (LATE (fn () => rpt conj_tac \\ FIRST [FIRST_ASSUM ACCEPT_TAC, metis_tac [TH "XG_trace_prefix"]]))])];

(* ---------------- optional ---------------- *)
val BIO = one (simp [BFFI_DEF]) [rw [BFFI_DEF], EVAL_TAC];
val TROKNIL = one (REWRITE_TAC [TROK_DEF]) [simp [TROK_DEF]];

(* ================= the lemma list (dependency order; true = required) ================= *)
val XG_LEMMAS0 : (string * term * step list * bool) list =
  [("XG_abs_ffi_any_k", S_ABSK, ABSK, true),
   ("XG_guard_unfold", S_GUNF, GUNF, false),
   ("XG_next_interfer_ok", S_G1, G1, true),
   ("XG_contract_at", S_CAT, CAT, true),
   ("XG_contract_on", S_CON, CON, true),
   ("XG_env_fields", S_FLD, FLD, true),
   ("XG_env_ok", S_ENVOK, ENVOK, true),
   ("XG_env_ok_sl", S_ENVOKSL, ENVOKSL, true),
   ("XG_tot_id", S_TOTID, TOTIDS, true),
   ("XG_mc_eq", S_MCEQ, MCEQ, true),
   ("XG_model_frame_trace_env", S_FRAME, FRAME, true),
   ("XG_trace_follows", S_FOLLOWS, FOLLOWS, true),
   ("XG_trace_prefix", S_PREFIX, PREFIX, true),
   ("XG_trace_prefix_TR2", S_PREFIX, PREFIX_TR2, false),
   ("XG_compose", S_COMPOSE, COMPOSE, true),
   ("XG_basis_io_nil", S_BIO, BIO, false),
   ("XG_trace_ok_nil", S_TROKNIL, TROKNIL, false)];
fun xg_keep ((nm, t, _, req) : string * term * step list * bool) : bool =
  req orelse
  (not (aconv t T) andalso (nm <> "XG_trace_prefix_TR2" orelse HAVE_TR2)) orelse
  (pr ("OPTIONAL_DROPPED " ^ nm); false);
val XG_LEMMAS = List.filter xg_keep XG_LEMMAS0;
val _ = pr ("XG_LEMMAS " ^ Int.toString (length XG_LEMMAS) ^ " of " ^ Int.toString (length XG_LEMMAS0));
val _ = pr "XG_STEPS loaded";

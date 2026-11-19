(* nv_steps.sml (worker W-nv). The ONE file of step lists, read with use by BOTH NVx-0001.sml (exploration) and
   NV-0001.sml (proof), after nv_common.sml. NOT RUN. Every tactic UNCHECKED (none of them ever ran). ASCII only;
   no quotations at all (every term comes from nv_common.sml). A step = (label, main, alternatives); the exploration
   prints the goals after each step; the proof takes FIRST (main :: alternatives) on the head goal.
   HOL infix rule: THEN, \\, >>, >- are all infixl 0, so "a \\ b >- c" = "(a \\ b) >- c". *)
val _ = pr "MARK STEPS";
fun is_forall_th (th : thm) : bool = is_forall (concl th);
val ACCEPT_ASM : tactic = FIRST_ASSUM ACCEPT_TAC;
val CLOSE_BY_ASMS : tactic = rpt conj_tac \\ ACCEPT_ASM;

(* 1. refund_ffi_contract_at b dm f ==> refund_ffi_contract_on b dm Vok f. The on-form is the at-form with ONE more
   hypothesis (Vok index new_bytes ms2) and the same conclusion (L1-0001 stdout lines 2-19 and 58-80;
   CONTROL_OK line 80). *)
val ATON_STEPS : step list =
  [("intro unfold", rpt gen_tac \\ PURE_REWRITE_TAC [AT_DEF, ON_DEF],
      [rpt gen_tac \\ rewrite_tac [AT_DEF, ON_DEF], metis_tac [AT_DEF, ON_DEF]]),
   ("disch", disch_tac \\ rpt gen_tac \\ strip_tac, []),
   ("spec at-form", first_x_assum (fn th => if is_forall_th th then mp_tac (SPEC_ALL th) else NO_TAC), []),
   ("hypotheses", impl_tac >- CLOSE_BY_ASMS, [impl_tac >- asm_rewrite_tac [], impl_tac >- fs []]),
   ("conclusion", disch_then ACCEPT_TAC, [strip_tac \\ asm_rewrite_tac [], simp [], metis_tac []])];

(* 2. record fields of refund_abs_env (forge_refundEnvModel refund_abs_env_def; env-0005 proof.sml 136-137) *)
val FIELDS_STEPS : step list =
  [("simp def", simp [ENV_DEF], [rw [ENV_DEF], rewrite_tac [ENV_DEF] \\ EVAL_TAC])];

(* 3. NV0: the antecedent at the constructed state. Uses theorem (2) of the task: remaining_premise_met_by_the_abstract_effect
   (refund_abs_ffi meets the on-form for EVERY b dm) and refund_id_interfer_ok. *)
val NV0_STEPS : step list =
  [("rewrite stored facts",
      LATE (fn () => rewrite_tac [WIT, HEAP_SAT, SATFS_WF, SATFS_STD, SATFS_STDIN, SATCL, TH L_FIELDS, IDOK, REM2]),
      [simp [WIT, HEAP_SAT, SATFS_WF, SATFS_STD, SATFS_STDIN, SATCL, ENV_DEF, IDOK, REM2]]),
   ("record accessor", simp [], [rw [], EVAL_TAC, simp [ENV_DEF]])];

(* 4. NV1b (route A, abstract): the stored older witness JS at slide 0x4000; refund_env_ok_sl unfolds to
   interference_ok /\ refund_ffi_contract_at; lemma (1) gives the on-form with Vok := VokS. *)
val NV1B_STEPS : step list =
  [("intro request fields", rpt gen_tac, []),
   ("old witness", strip_assume_tac (PURE_REWRITE_RULE [ENV_OK_SL_DEF] JS),
      [strip_assume_tac (REWRITE_RULE [ENV_OK_SL_DEF] JS)]),
   ("contract on-form",
      LATE (fn () => first_assum (assume_tac o MATCH_MP (ISPEC VOKS (TH L_ATON)))),
      [LATE (fn () => imp_res_tac (ISPEC VOKS (TH L_ATON)))]),
   ("exists 0x4000 s h stk e envmc fs cl", map_every exists_tac WITVALS, []),
   ("close by assumptions", CLOSE_BY_ASMS, [asm_rewrite_tac [], metis_tac []])];

(* 5. NV1: existential closure over all 17 free variables, from NV1b *)
val NV1_STEPS : step list =
  [("exists request fields", map_every exists_tac REQ, []),
   ("from NV1b", LATE (fn () => MATCH_ACCEPT_TAC (SPEC_ALL (TH L_NV1B))),
      [LATE (fn () => ACCEPT_TAC (SPEC_ALL (TH L_NV1B))), LATE (fn () => metis_tac [TH L_NV1B])])];

(* 6. NV2: some state meets the antecedent; for it a behaviour EXISTS (machine_sem_total) and every behaviour is
   Terminate t io with the frame property (refund_model_frame_decision_shape). Existence of a Success behaviour is
   NOT claimed. *)
val NV2_STEPS : step list =
  [("intro extra free variables", rpt gen_tac, []),
   ("exists request fields", map_every exists_tac REQ, []),
   ("NV1b witness", LATE (fn () => strip_assume_tac (SPEC_ALL (TH L_NV1B))), []),
   ("exists premise variables", map_every exists_tac OTH, []),
   ("split antecedent / run", conj_tac, []),
   ("antecedent", CLOSE_BY_ASMS, [asm_rewrite_tac []]),
   ("decision shape", mp_tac (SPEC_ALL DEC) \\ impl_tac >- CLOSE_BY_ASMS,
      [mp_tac (SPEC_ALL DEC) \\ impl_tac >- asm_rewrite_tac []]),
   ("pick ms", strip_tac \\ exists_tac MSV, []),
   ("close run facts", rpt conj_tac \\ FIRST [ACCEPT_ASM, MATCH_ACCEPT_TAC MST],
      [rpt conj_tac \\ FIRST [ACCEPT_ASM, metis_tac [MST]], metis_tac [MST]])];

(* (name, statement, steps, required) in dependency order *)
val NV_LEMMAS : (string * term * step list * bool) list =
  [(L_ATON, ATON_STMT, ATON_STEPS, true),
   (L_FIELDS, FIELDS_STMT, FIELDS_STEPS, false),
   (L_NV0, NV0_STMT, NV0_STEPS, false),
   (L_NV1B, NV1B_STMT, NV1B_STEPS, true),
   (L_NV1, NV1_STMT, NV1_STEPS, true),
   (L_NV2, NV2_STMT, NV2_STEPS, true)];
val _ = pr "PART_INFO nv_steps loaded";

(* L-EXIT-0 v5 (worker A14, Night-Shift Orchestrator A). DRAFT: NOT RUN. No HOL process was started. Every tactic is
   UNCHECKED. Base: L_EXIT_v4.sml (SHA-256 c7ea9aa13307e03b004ad11ddad4996fdcc3fba46477a7ea49f9190cd14f947f).
   Helper pattern: LO-0005.sml (SHA-256 9db45d735cf891429a6d9e80454ddf7c07d49b9a2a4030aca57d61c14571bb30).
   No v4 statement text changed. Changes (marked "A14 v5"):
   - helpers ported from LO-0005: pr with flush, tlim/ST/CL/show_tac, try_all with time limits (Timeout.apply on
     (fn () => tac g ctxt)), thm with BEGIN/END, a failed lemma becomes ASSUME of its statement (never stored),
     DIAG_OK_UNDER, FAILED_LIST, no export after any failure. A tactic is goal -> Context.t -> goal list * validation
     (HOL/src/1/Abbrev.sig:10).
   - two modes, chosen at run time and printed as "LOUT_MODE imported|absent":
       imported: forge_refundLOut.refund_profile_a_sl_fd1 is in the loaded theories; new theory forge_refundLExit;
                 all lemmas, including the refund instance refund_profile_a_sl_halt.
       absent:   new theory forge_refundLExitGen; only the lemmas that do not need L-OUT; the refund instance is
                 only parsed and printed as STATEMENT_TYPECHECKS (fd1_written is then a FREE VARIABLE).
   - evaluate_Halt_reg: two explicit staged alternatives (A: DNF by AllCaseEqs; B: IF_CASES_TAC/TOP_CASE_TAC), each
     by plain Induct on the clock with the IH captured by pop_assum, plus v4's complete-induction alternative (C).
     Every Halt of targetSem$evaluate (targetSemScript.sml 118-219): 141-142 (halt_pc: Success iff ptr_reg = 0w,
     else Resource_limit_hit; ms' = ms), 172 and 196 (SharedMem FFI_final: Halt (FFI_outcome _)), 211 (ExtCall
     FFI_final: Halt (FFI_outcome _)). Every recursion is at k - 1 with mc changed only in next_interfer (133),
     install_interfer (147), ffi_interfer (177, 201, 216); halt_pc, ptr_reg and target are unchanged.
   - one ADDED generic lemma machine_sem_of_evaluate_Halt (from machine_sem_def 222-225); used by the instance.
   - the two arm8_run constants: the HALT text keeps the unqualified arm8_run; the parsed constant is printed as
     STATEMENT_ARM8_RUN <theory> <lemma>; the tactic accepts both readings with
     forge_refundSlideEntry.arm8_run_constants_agree (s2-0003.sml:40: Slide$arm8_run n s = Step$arm8_run n s).
   - controls: the evaluate constant of evaluate_Halt_reg is targetSem$evaluate; the stored-theorem name set is
     exactly the planned set of the mode.
   Kind: MODEL. Native exit status (_cml_exit) stays an ASSUMPTION (definitions cml_exit_status, cml_exit_stderr).
   ---------------------------------------------------------------------------------------------------
   v4 header (A3): v3 + AGREE for the two arm8_run constants. v3 = v2 with tactic repairs E1-E3. v2 (Z6): base Y4.
   Stored items used: targetSem.evaluate_def, machine_sem_def, apply_oracle_def; lab_to_target.ffi_offset_def;
   forge_refundStartupBridge.refund_mc_fields; forge_refundSlideProfileA.refund_mc_register_fields_sl,
   refund_profile_a_sl_every_machine_run; forge_refundSlideEntry.arm8_run_constants_agree;
   arm8_target.arm8_target_def; (imported mode only) forge_refundLOut.refund_profile_a_sl_fd1. *)
open preamble targetSemTheory arm8_targetTheory lab_to_targetTheory wordsLib blastLib;
val _ = Globals.max_print_depth := 60;
fun pr s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut);
val _ = (load "Timeout"; pr "TIMEOUT_HELPER Timeout.apply loaded")
  handle e => (pr ("TIMEOUT_LOAD_FAILED " ^ General.exnMessage e); raise e);
val ALT_SECS = 60;
val LEMMA_SECS = 240;
val EHR_ALT_SECS = 150;   (* evaluate_Halt_reg: case explosion over evaluate_def *)
val EHR_LEMMA_SECS = 660;
(* tlim : int -> tactic -> tactic *)
fun tlim secs (tac : tactic) : tactic = fn g => fn ctxt =>
  Timeout.apply (Time.fromSeconds (Int.toLarge secs)) (fn () => tac g ctxt) ()
  handle Timeout.TIMEOUT _ => (pr ("TIMEOUT_ALT after " ^ Int.toString secs ^ " s");
                               raise mk_HOL_ERR "A14" "tlim" "time limit");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = metisTools.limit := {time = SOME 30.0, infs = NONE};
fun trunc n s = if size s <= n then s else String.substring (s, 0, n) ^ " ...";
fun showg tag (asl, w) = (pr ("SHOW " ^ tag);
   List.app (fn a => pr ("  ASM " ^ trunc 700 (term_to_string a))) asl;
   pr ("  GOAL " ^ trunc 3000 (term_to_string w)));
(* show_tac : string -> tactic *)
fun show_tac tag g = (showg tag g; ALL_TAC g);
(* ST : string -> tactic -> tactic *)
fun ST tag (tac : tactic) : tactic = fn g => fn ctxt => tac g ctxt
  handle e => (showg ("STAGE_FAILED " ^ tag ^ " : " ^ trunc 300 (General.exnMessage e)) g; raise e);
(* CL : string -> tactic -> tactic *)
fun CL tag (tac : tactic) : tactic = fn g => fn ctxt =>
  let val r as (gs, _) = ST tag tac g ctxt in
    if null gs then r
    else (List.app (showg ("UNSOLVED " ^ tag)) gs; raise mk_HOL_ERR "A14" "CL" ("unsolved goals at " ^ tag))
  end;

(* ================= mode ================= *)
val FD1_OPT = (SOME (DB.fetch "forge_refundLOut" "refund_profile_a_sl_fd1")) handle _ => NONE;
val IMPORTED = isSome FD1_OPT;
val _ = pr ("LOUT_MODE " ^ (if IMPORTED then "imported" else "absent"));
val THY = if IMPORTED then "forge_refundLExit" else "forge_refundLExitGen";
val _ = pr ("THEORY_NAME " ^ THY);

val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory THY;
val failed = ref ([] : string list);
val problems = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
val failed_stmts = ref ([] : (string * term) list);
val diag = ref ([] : string list);
fun names_of_hyps th = map (fn h => case List.find (fn (_, t) => aconv t h) (!failed_stmts) of
                                      SOME (n, _) => n | NONE => "?" ^ trunc 80 (term_to_string h)) (hyp th);
(* thmT : int -> string -> (unit -> term) -> (unit -> tactic) -> thm *)
fun thmT secs name goalf tacf =
  let val _ = pr ("BEGIN " ^ name)
      val t0 = Time.now ()
      val g = goalf ()
      fun fail_with msg = (pr ("LEMMA_FAILED " ^ name ^ " " ^ msg); failed := name :: !failed;
                           failed_stmts := (name, g) :: !failed_stmts; ASSUME g)
      val pf = Timeout.apply (Time.fromSeconds (Int.toLarge secs)) Tactical.TAC_PROOF
  in
    (let val th0 = pf (([], g), tacf ()) in
       if null (hyp th0) then
         (let val th = save_thm (name, th0) in
            chk name th; pr ("END " ^ name ^ " " ^ Time.toString (Time.- (Time.now (), t0)) ^ " s"); th end)
       else (pr ("DIAG_OK_UNDER " ^ name ^ " assumed: " ^ String.concatWith " " (names_of_hyps th0));
             diag := name :: !diag; fail_with "(diagnostic only: proved only under the failed lemmas above)")
     end)
    handle Timeout.TIMEOUT _ => fail_with ("TIMEOUT " ^ Int.toString secs ^ " s")
         | e => fail_with (General.exnMessage e)
  end
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " (statement) " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
fun thm name goalf tacf = thmT LEMMA_SECS name goalf tacf;
(* aux : string -> (unit -> term) -> (unit -> tactic) -> thm. Like thm, but the theorem is NOT stored. *)
fun aux name goalf tacf =
  let val _ = pr ("BEGIN_AUX " ^ name)
      val g = goalf ()
      fun fail_with msg = (pr ("LEMMA_FAILED " ^ name ^ " (aux) " ^ msg); failed := name :: !failed;
                           failed_stmts := (name, g) :: !failed_stmts; ASSUME g)
  in
    (let val th = Timeout.apply (Time.fromSeconds (Int.toLarge LEMMA_SECS)) Tactical.TAC_PROOF (([], g), tacf ()) in
       if null (hyp th) then (tags name th; pr ("AUX_OK " ^ name ^ "\n" ^ thm_to_string th); th)
       else fail_with "has hypotheses"
     end)
    handle Timeout.TIMEOUT _ => fail_with "TIMEOUT"
         | e => fail_with (General.exnMessage e)
  end
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " (aux statement) " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
(* try_allT : int -> string -> tactic list -> tactic *)
fun try_allT secs name (tacs : tactic list) : tactic = fn g => fn ctxt =>
  FIRST (map (fn t => tlim secs (t \\ NO_TAC)) tacs) g ctxt
  handle e as HOL_ERR _ => (showg ("TRY_ALL_ENTRY " ^ name) g;
                            tlim secs (hd tacs \\ show_tac ("REMAINING " ^ name) \\ NO_TAC) g ctxt);
fun try_all name tacs = try_allT ALT_SECS name tacs;
fun defn name q = (let val _ = pr ("BEGIN_DEFINITION " ^ name) val th = Define q in pr ("DEFINITION " ^ name ^ "\n" ^ thm_to_string th); th end)
  handle e => (pr ("DEFINITION_FAILED " ^ name ^ " " ^ General.exnMessage e); raise e);
(* arm8_run constants in a term: theory names, without repetition *)
fun arm8_thys t = Lib.mk_set (map (fn c => #Thy (dest_thy_const c))
                    (find_terms (fn x => is_const x andalso fst (dest_const x) = "arm8_run") t));
fun const_thys nm t = Lib.mk_set (map (fn c => #Thy (dest_thy_const c))
                    (find_terms (fn x => is_const x andalso fst (dest_const x) = nm) t));

(* ================= stored items (no L-OUT) ================= *)
val SPE = DB.fetch "forge_refundSlideProfileA" "refund_profile_a_sl_every_machine_run";
val AGREE = DB.fetch "forge_refundSlideEntry" "arm8_run_constants_agree";
val REGF = DB.fetch "forge_refundSlideProfileA" "refund_mc_register_fields_sl";
val MCF = DB.fetch "forge_refundStartupBridge" "refund_mc_fields";
val _ = List.app (fn (n, th) => pr ("USED " ^ n ^ "\n" ^ thm_to_string th))
  [("arm8_run_constants_agree", AGREE), ("refund_mc_register_fields_sl", REGF), ("refund_mc_fields", MCF)];
val _ = List.app (fn s => pr ("ARM8_RUN_IN_STORED " ^ s)) (arm8_thys (concl SPE));
val _ = case FD1_OPT of
          SOME th => (pr ("USED refund_profile_a_sl_fd1\n" ^ thm_to_string th);
                      List.app (fn s => pr ("ARM8_RUN_IN_FD1 " ^ s)) (arm8_thys (concl th)))
        | NONE => pr "NOT_USED refund_profile_a_sl_fd1 (L-OUT absent)";
(* tg is not stored. *)
val tg = aux "arm8_target_pc_reg"
  (fn () => ``arm8_target.get_pc (ms:arm8_state) = ms.PC /\ arm8_target.get_reg ms r = ms.REG (n2w r)``)
  (fn () => try_all "arm8_target_pc_reg"
     [simp [arm8_target_def, FUN_EQ_THM],
      rw [arm8_target_def],
      simp [arm8_target_def] \\ EVAL_TAC]);

(* ================= L-EXIT-0, generic (any machine_config) ================= *)
(* leaf of the clock induction. ih : !mc ffi ms t ms' ffi'. evaluate mc ffi k ms = (Halt t,ms',ffi') ==> C. *)
fun ehr_leaf (ih : thm) : tactic =
  FIRST [drule ih \\ simp[] \\ NO_TAC,                     (* recursive leaf: mc' differs from mc only in an oracle *)
         drule ih \\ strip_tac \\ fs[] \\ NO_TAC,
         gvs[] \\ NO_TAC,                                   (* Halt at halt_pc, Halt (FFI_outcome _), Error/TimeOut *)
         fs[] \\ rw[] \\ NO_TAC,
         metis_tac[ih]]
  ORELSE (show_tac "EHR_LEAF_LEFT" \\ NO_TAC);
val ehr_base = ST "ehr_base"
  (rpt gen_tac \\ ONCE_REWRITE_TAC [targetSemTheory.evaluate_def] \\ simp[]);
(* A: one unfolding, then the whole case tree as a DNF in the premise *)
val ehr_A : tactic =
  Induct >- ehr_base
  \\ pop_assum (fn ih =>
       rpt gen_tac
       \\ ST "ehrA_unfold" (ONCE_REWRITE_TAC [targetSemTheory.evaluate_def])
       \\ ST "ehrA_dnf" (simp [targetSemTheory.apply_oracle_def, LET_THM, AllCaseEqs(), bool_case_eq])
       \\ rpt strip_tac
       \\ ehr_leaf ih);
(* B: one unfolding, then explicit case splits, as in targetProps evaluate_add_clock (targetPropsScript.sml 1060-1078) *)
val ehr_B : tactic =
  Induct >- ehr_base
  \\ pop_assum (fn ih =>
       rpt gen_tac
       \\ ST "ehrB_unfold" (ONCE_REWRITE_TAC [targetSemTheory.evaluate_def]
                            \\ simp [targetSemTheory.apply_oracle_def, LET_THM])
       \\ rpt (IF_CASES_TAC ORELSE TOP_CASE_TAC)
       \\ rpt strip_tac
       \\ ehr_leaf ih);
(* C: v4 alternative 2 (complete induction) *)
val ehr_C : tactic =
  completeInduct_on `k` \\ rpt gen_tac \\ strip_tac
  \\ qpat_x_assum `evaluate _ _ _ _ = _` mp_tac
  \\ simp [Once targetSemTheory.evaluate_def, targetSemTheory.apply_oracle_def, LET_THM, AllCaseEqs()]
  \\ rpt strip_tac \\ gvs[] \\ rpt (pairarg_tac \\ gvs[])
  \\ (first_x_assum (qspec_then `k - 1` mp_tac) \\ impl_tac >- decide_tac   (* parenthesised: >- per goal *)
      \\ disch_then drule \\ simp[]);
val EHR = thmT EHR_LEMMA_SECS "evaluate_Halt_reg"
  (fn () => ``!k mc ffi ms t ms' ffi'.
       evaluate mc ffi k ms = (Halt t, ms', ffi') ==>
       (?e. t = FFI_outcome e) \/
       (mc.target.get_pc ms' = mc.halt_pc /\
        ((t = Success /\ mc.target.get_reg ms' mc.ptr_reg = 0w) \/
         (t = Resource_limit_hit /\ mc.target.get_reg ms' mc.ptr_reg <> 0w)))``)
  (fn () => try_allT EHR_ALT_SECS "evaluate_Halt_reg" [ehr_A, ehr_B, ehr_C]);
val _ = List.app (fn s => pr ("STATEMENT_EVALUATE " ^ s ^ " evaluate_Halt_reg")) (const_thys "evaluate" (concl EHR));

(* A14 v5 addition (generic; no L-OUT): Terminate from a Halt (machine_sem_def, targetSemScript.sml 222-225) *)
val MSE = thm "machine_sem_of_evaluate_Halt"
  (fn () => ``!mc st k ms t ms' st'.
       evaluate mc st k ms = (Halt t, ms', st') ==> machine_sem mc st ms (Terminate t st'.io_events)``)
  (fn () => try_all "machine_sem_of_evaluate_Halt"
     [rpt strip_tac \\ simp [targetSemTheory.machine_sem_def] \\ qexistsl_tac [`k`, `ms'`, `st'`] \\ simp[],
      rpt strip_tac \\ simp [targetSemTheory.machine_sem_def] \\ metis_tac[],
      rw [targetSemTheory.machine_sem_def] \\ metis_tac[]]);

(* ================= halt address (no L-OUT) ================= *)
val HADDR = thm "refund_halt_address"
  (fn () => ``!sl:word64. sl + 0x1000040D0w - n2w ffi_offset = sl + 0x1000040C0w``)
  (fn () => try_all "refund_halt_address"
     [simp[lab_to_targetTheory.ffi_offset_def, wordsTheory.WORD_ADD_SUB_ASSOC] \\ EVAL_TAC,
      simp[lab_to_targetTheory.ffi_offset_def] \\ srw_tac[wordsLib.WORD_ARITH_ss][],
      simp[lab_to_targetTheory.ffi_offset_def] \\ blastLib.BBLAST_TAC,
      simp[lab_to_targetTheory.ffi_offset_def] \\ wordsLib.WORD_DECIDE_TAC]);

(* ================= instance at the M1 record ================= *)
val (PREM, _) = dest_imp (concl (SPEC_ALL SPE));
val R = find_term (fn t => (fst (dest_const (fst (strip_comb t))) = "refund_render_fields") handle _ => false) (concl SPE);
(* v4 statement text, unchanged *)
fun halt_goal () = ``^PREM ==>
     ?ms. (arm8_run 27 s = SOME ms /\ ms.PC = sl + 0x1000040D0w) /\
       !k t ms' st'.
         evaluate (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi no_ext cl fs) k ms = (Halt t, ms', st') ==>
         ms'.PC = sl + 0x1000040C0w /\
         ((ms'.REG 0w = 0w /\ t = Success /\ fd1_written st'.io_events = explode ^R) \/
          (ms'.REG 0w <> 0w /\ t = Resource_limit_hit /\ fd1_written st'.io_events <<= explode ^R))``;
val ms_tac = FIRST [first_assum ACCEPT_TAC,
                    CL "ms_agree" (ASM_REWRITE_TAC [AGREE]),
                    CL "ms_agree_sym" (ASM_REWRITE_TAC [GSYM AGREE]),
                    CL "ms_metis" (metis_tac [AGREE])];
(* conjuncts of refund_mc_fields, picked by the printed left side *)
fun mcf_conj sfx = List.find (fn c => String.isSuffix sfx (term_to_string (lhs (concl c))) handle _ => false)
                     (CONJUNCTS MCF);
val MCF_T = case mcf_conj ".target" of SOME c => c | NONE => (pr "MCF_TARGET_NOT_FOUND"; MCF);
val HALTPC =
  (case mcf_conj ".halt_pc" of
     NONE => (pr "MCF_HALT_PC_NOT_FOUND"; TRUTH)
   | SOME c =>
       let val b0 = valOf (List.find (fn v => fst (dest_var v) = "base0") (free_vars (concl c)))
           val slv = valOf (List.find (fn v => fst (dest_var v) = "sl") (free_vars PREM))
       in REWRITE_RULE [HADDR] (INST [b0 |-> ``^slv + 0x1000040D0w``] c) end)
  handle e => (pr ("HALTPC_FAILED " ^ General.exnMessage e); TRUTH);
val _ = pr ("HALTPC " ^ thm_to_string HALTPC);
val _ = pr ("MCF_TARGET " ^ thm_to_string MCF_T);
val halt_fin =
  FIRST [CL "halt_fin_rw" (RULE_ASSUM_TAC (REWRITE_RULE [HALTPC])
                           \\ RULE_ASSUM_TAC (REWRITE_RULE [MCF_T, REGF])
                           \\ RULE_ASSUM_TAC (REWRITE_RULE [tg, HADDR])
                           \\ gvs[]),
         CL "halt_fin_v4" (gvs[MCF, REGF, tg, HADDR]),
         CL "halt_fin_fs" (fs[MCF_T, REGF, tg, HALTPC, HADDR] \\ rfs[] \\ fs[])];
fun halt_tac (FD1 : thm) : tactic =
  try_all "refund_profile_a_sl_halt"
   [DISCH_THEN (fn th => STRIP_ASSUME_TAC th \\ STRIP_ASSUME_TAC (MP FD1 th))
      \\ ST "halt_witness" (qexists_tac `ms`)
      \\ conj_tac >- CL "halt_ms" (conj_tac \\ ms_tac)
      \\ ST "halt_intro" (rpt gen_tac \\ strip_tac)
      \\ ST "halt_sem" (drule MSE \\ strip_tac)
      \\ ST "halt_fd1" (first_x_assum drule \\ strip_tac)
      \\ ST "halt_ehr" (drule EHR \\ strip_tac)
      \\ halt_fin,
    (* v4 alternative 2, with the drule order above *)
    DISCH_THEN (fn th => STRIP_ASSUME_TAC th \\ STRIP_ASSUME_TAC (MP FD1 th))
      \\ qexists_tac `ms` \\ conj_tac >- (conj_tac \\ ms_tac)
      \\ rpt gen_tac \\ strip_tac
      \\ drule MSE \\ strip_tac
      \\ qpat_x_assum `!b. _` drule \\ strip_tac
      \\ drule EHR \\ strip_tac
      \\ gvs[MCF, REGF, tg, HADDR]];   (* Orchestrator A, LE-0003 (ML-only): one surplus ")" removed (LE-0002 parse error at 273:36) *)
val HALT =
  case FD1_OPT of
    SOME FD1 =>
      let val _ = (List.app (fn s => pr ("STATEMENT_ARM8_RUN " ^ s ^ " refund_profile_a_sl_halt")) (arm8_thys (halt_goal ())))
                  handle e => pr ("STATEMENT_PARSE_FAILED refund_profile_a_sl_halt " ^ General.exnMessage e)
      in thm "refund_profile_a_sl_halt" halt_goal (fn () => halt_tac FD1) end
  | NONE =>
      ((let val t = halt_goal ()
            val fw = find_terms (fn x => (is_const x orelse is_var x) andalso
                                         (fst (dest_const x) handle _ => fst (dest_var x)) = "fd1_written") t
        in List.app (fn s => pr ("STATEMENT_ARM8_RUN " ^ s ^ " refund_profile_a_sl_halt")) (arm8_thys t);
           pr ("FD1_WRITTEN_KIND " ^ (if List.exists is_const fw then "constant" else "free variable (L-OUT absent)"));
           pr ("STATEMENT_TYPECHECKS refund_profile_a_sl_halt (not attempted: L-OUT absent)\n" ^ term_to_string t)
        end)
       handle e => pr ("STATEMENT_TYPECHECK_FAILED refund_profile_a_sl_halt " ^ General.exnMessage e);
       TRUTH);

(* ================= L-EXIT-V: OPEN (statement only; NOT attempted; no theorem is claimed) ================= *)
val LEXITV = ``^PREM ==>
     ?ms. (arm8_run 27 s = SOME ms /\ ms.PC = sl + 0x1000040D0w) /\
       !k t ms' st'.
         evaluate (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi no_ext cl fs) k ms = (Halt t, ms', st') ==>
         ms'.REG 0w IN {0w; 1w; 2w}``;
val _ = pr ("OPEN_STATEMENT L-EXIT-V (type-checked only; not a theorem)\n" ^ term_to_string LEXITV);

(* ================= native half: an ASSUMPTION, as definitions only ================= *)
val st_def = defn "cml_exit_status" `cml_exit_status (x0:word64) = w2n ((w2w x0):word8)`;
val se_def = defn "cml_exit_stderr"
  `cml_exit_stderr (x0:word64) = if ((w2w x0):word32) = 0w then "" else "Program exited with nonzero exit code.\n"`;

(* ================= NEGATIVE CONTROLS (no L-OUT) ================= *)
(* N-E1: the native status map is not injective at 0: a model resource stop can give status 0. *)
val NE1 = thm "N_E1_status_collision"
  (fn () => ``cml_exit_status 256w = 0 /\ cml_exit_status 0x100000000w = 0 /\
              (256w:word64) <> 0w /\ (0x100000000w:word64) <> 0w``)
  (fn () => try_all "N_E1" [simp[st_def] \\ EVAL_TAC, EVAL_TAC, rw[st_def] \\ EVAL_TAC]);
(* N-E2: x0 = 2^32 is also silent on stderr. *)
val NE2 = thm "N_E2_silent_stop"
  (fn () => ``cml_exit_stderr 0x100000000w = "" /\ cml_exit_stderr 256w <> ""``)
  (fn () => try_all "N_E2" [simp[se_def] \\ EVAL_TAC, EVAL_TAC, rw[se_def] \\ EVAL_TAC]);
(* N-E3: the swapped L-EXIT-0 (Success iff reg <> 0w) is refuted: Success happens with the register 0w. *)
val NE3 = thm "N_E3_success_with_zero_register"
  (fn () => ``!(ffi:'ffi ffi_state) (ms:'b) (x:'a word).
       ?(mc:('a,'b,'c) machine_config). mc.target.get_pc ms = mc.halt_pc /\ mc.target.get_reg ms mc.ptr_reg = 0w /\
          evaluate mc ffi 1 ms = (Halt Success, ms, ffi)``)
  (fn () => try_all "N_E3"
     [rpt gen_tac \\
        qexists_tac `(ARB:('a,'b,'c) machine_config) with
           <| prog_addresses := {}; ffi_entry_pcs := []; halt_pc := x;
              target := (ARB:('a,'b,'c) target) with <| get_pc := K x; get_reg := K (K 0w) |> |>` \\
        simp[Once targetSemTheory.evaluate_def],
      rpt gen_tac \\
        qexists_tac `(ARB:('a,'b,'c) machine_config) with
           <| prog_addresses := {}; ffi_entry_pcs := []; halt_pc := x;
              target := (ARB:('a,'b,'c) target) with <| get_pc := K x; get_reg := K (K 0w) |> |>` \\
        ONCE_REWRITE_TAC [targetSemTheory.evaluate_def] \\ simp[]]);

(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = pr ("FAILED_LIST " ^ String.concatWith " " (rev (!failed)));
val _ = pr ("DIAG_OK_UNDER_LIST " ^ String.concatWith " " (rev (!diag)));
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = if const_thys "evaluate" (concl EHR) = ["targetSem"]
        then pr "CONTROL_OK evaluate_Halt_reg uses targetSem$evaluate" else bad "EHR-evaluate";
val _ = if IMPORTED then
          (if aconv (fst (dest_imp (concl HALT))) PREM
           then pr "CONTROL_OK refund_profile_a_sl_halt premise is the stored premise term" else bad "HALT-premise";
           if const_thys "fd1_written" (concl HALT) = ["forge_refundLOut"]
           then pr "CONTROL_OK refund_profile_a_sl_halt uses forge_refundLOut$fd1_written" else bad "HALT-fd1_written")
        else pr "CONTROL_SKIPPED refund_profile_a_sl_halt (L-OUT absent)";
val _ = if Lib.mem "LEXITV" (map fst (DB.thms THY)) then bad "LEXITV-stored" else
          pr "CONTROL_OK L-EXIT-V is not stored as a theorem";
val planned = ["evaluate_Halt_reg", "machine_sem_of_evaluate_Halt", "refund_halt_address",
               "N_E1_status_collision", "N_E2_silent_stop", "N_E3_success_with_zero_register"]
              @ (if IMPORTED then ["refund_profile_a_sl_halt"] else []);
val stored = map fst (DB.theorems THY);
val _ = if length stored = length planned andalso List.all (fn n => Lib.mem n stored) planned
        then pr ("CONTROL_OK stored theorems are the planned set (" ^ Int.toString (length planned) ^ ")")
        else bad ("stored-set " ^ String.concatWith "," stored);
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems THY @ DB.definitions THY);
val closure = THY :: Theory.ancestry THY;
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems THY)));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions THY)));
val _ = export_theory ();
val _ = pr ("EXACT_COMPLETE_MODE " ^ (if IMPORTED then "imported" else "absent"));
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

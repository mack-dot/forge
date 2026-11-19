(* routeA-L2_v2.sml: worker A5 (Night-Shift Orchestrator A) repair of routeA-L2.sml (sha256 03036c1c...3b09).
   NOT RUN. Every tactic here is UNCHECKED. No theorem STATEMENT and no DEFINITION of the original changed.
   A5 changes (all marked in the text):
     (1) A5 tactic-only: L2 step case. The original used `Induct >- base >> disch_then (fn IH => ...)`. bossLib.Induct
         (HOL src/basicProof/BasicProvers.sml 433: Prim_rec.INDUCT_THEN thm ASSUME_TAC) puts the induction hypothesis in
         the ASSUMPTIONS and leaves the goal `!mc1 mc2 ffi ms. ...` (not an implication), so disch_then fails. Repair:
         `pop_assum (fn IH => ...)`.
     (2) A5 new helper lemmas RFB1/RFB2 (not statement changes): read_ffi_bytearray(s) take the whole record; without
         them the case scrutinees of the two machines differ syntactically (mc1 vs mc1 with ffi_interfer := ...).
     (3) A5 tactic-only: L2 tried with an ordered list of tactics (helper thmA); the first is the repaired original,
         the second an every_case_tac variant. The run prints TACTIC_USED / TACTIC_ATTEMPT_FAILED.
     (4) A5 tactic-only: the last lines of L2R end in TRY (qexists io_events ...) then metis_tac, instead of a
         qexists_tac applied to every remaining subgoal.
     (5) A5 new control C-NV: ffi_calls_ok (\i nb ms. F) is FALSE at a concrete returning call (non-vacuity of D3).
   Original header follows.
   Route A, lemma L2 (step C1, worker X7). DRAFT: NOT RUN. Higher risk than L1: the induction tactic was written by
   reading targetSemScript.sml (evaluate_def lines 118-218) and the stored proof of targetProps.evaluate_add_clock
   (targetPropsScript.sml 1059-1076); it has never been executed. Run only after routeA-L1.sml has exit 0.
   Parents: everything of deps-imp4.txt plus forge_refundRouteA1 (the L1 case).
   Content:
     D3. ffi_calls_ok P mc ffi k ms: a copy of the recursion of targetSem.evaluate; it is T where evaluate stops
         (TimeOut, Error, Halt, FFI_final), F at a SharedMem call, and at every ExtCall FFI_return it requires
         P ffi_index new_bytes ms (the call state and the oracle's answer) and continues like evaluate.
     L2.  if mc2 = mc1 with ffi_interfer := refund_ffi_tot Vok mc1.ffi_interfer and ffi_calls_ok Vok mc2 ffi k ms,
          then evaluate mc1 ffi k ms = evaluate mc2 ffi k ms. (Reachability is taken in the TOTALISED machine mc2.)
     L2S. the same for machine_sem when ffi_calls_ok holds for every clock.
     L2R. composition with the stored refund_profile_a_sl: the premise refund_env_ok_sl sl envmc is replaced by
          interference_ok, refund_ffi_contract_on with Vok, and ffi_calls_ok Vok at every clock in the totalised machine;
          the conclusion is the stored conclusion, term for term, for the REAL-effect record envmc.
   NOT proved here: that ffi_calls_ok holds for the refund program for any useful Vok (that is L3); anything native. *)
open preamble targetSemTheory targetPropsTheory ffiTheory semanticsPropsTheory fsFFITheory basis_ffiTheory TextIOProofTheory
     backendTheory asmPropsTheory lab_to_targetTheory arm8Theory arm8_targetTheory alignmentTheory miscTheory set_sepTheory
     backendProofTheory arm8_configProofTheory wordsLib blastLib forge_refundArm8CompileTheory forge_refundExclusionRealTheory
     forge_refundStartupClauseTheory forge_refundStartupBridgeTheory forge_refundInstalledDomainsTheory forge_refundInstalledAssemblyTheory
     forge_refundFfiFactsTheory forge_refundResidualTheory forge_refundEnvModelTheory forge_refundSourceNonFailTheory
     forge_refundProfileATheory forge_refundSlideEntryTheory forge_refundSlideDomainsTheory forge_refundSlideInstalledTheory
     forge_refundSlideSatTheory forge_refundSlideProfileATheory forge_refundRouteA1Theory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (500, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundRouteA2";
val failed = ref ([] : string list);
val problems = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
fun has_const n tm = can (find_term (fn t => is_const t andalso fst (dest_const t) = n)) tm;
(* A5: try an ordered list of tactics for ONE fixed goal; the goal never changes between attempts. No mk_thm. *)
fun thmA name goal tacs =
  let fun go _ [] = raise Fail "all listed tactics failed"
        | go i (t :: ts) =
            (let val th = Tactical.TAC_PROOF (([], goal), t) in pr ("TACTIC_USED " ^ name ^ " " ^ Int.toString i); th end
             handle e => (pr ("TACTIC_ATTEMPT_FAILED " ^ name ^ " " ^ Int.toString i ^ " " ^ General.exnMessage e); go (i + 1) ts))
  in (let val th = save_thm (name, go 1 tacs) in chk name th; th end)
     handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH)
  end;
fun A1 n = DB.fetch "forge_refundRouteA1" n;
val TOT_T = A1 "refund_ffi_tot_valid";
val SHIFT = A1 "refund_ffi_tot_shift_seq";
val L1C = A1 "refund_env_ok_sl_of_contract_on";
val TA = DB.fetch "forge_refundSlideProfileA" "refund_profile_a_sl";
val mc_def = DB.fetch "forge_refundStartupBridge" "refund_mc_def";
val fix_def = DB.fetch "forge_refundStartupClause" "arm8_fix_def";
(* ================= D3 ================= *)
val _ = pr "MARK D3";
val calls_def = Define `
  (ffi_calls_ok (P:num -> word8 list -> 'b -> bool) (mc:('a,'b,'c) machine_config) (ffi:'ffi ffi_state) 0 (ms:'b) <=> T) /\
  (ffi_calls_ok P mc ffi (SUC k) ms <=>
     if mc.target.get_pc ms IN (mc.prog_addresses DIFF (set mc.ffi_entry_pcs)) then
       if encoded_bytes_in_mem mc.target.config (mc.target.get_pc ms) (mc.target.get_byte ms) mc.prog_addresses then
         let ms1 = mc.target.next ms in
         let (ms2,new_oracle) = apply_oracle mc.next_interfer ms1 in
         let mc = mc with next_interfer := new_oracle in
           if EVERY mc.target.state_ok [ms;ms1;ms2] /\
              (!x. x NOTIN mc.prog_addresses ==> mc.target.get_byte ms1 x = mc.target.get_byte ms x)
           then ffi_calls_ok P mc ffi k ms2
           else T
       else T
     else if mc.target.get_pc ms = mc.halt_pc then T
     else if mc.target.get_pc ms = mc.install_pc then
       (case read_ffi_bytearray mc mc.ptr_reg mc.len_reg ms of
        | SOME bytes =>
            let (ms1,new_oracle) = apply_oracle mc.install_interfer (bytes,ms) in
            let mc = mc with install_interfer := new_oracle in
              ffi_calls_ok P mc ffi k ms1
        | _ => T)
     else
       case find_index (mc.target.get_pc ms) mc.ffi_entry_pcs 0 of
       | NONE => T
       | SOME ffi_index =>
           (case EL ffi_index mc.ffi_names of
            | SharedMem op => F
            | ExtCall _ =>
                (case ALOOKUP mc.mmio_info ffi_index of
                 | SOME _ => T
                 | NONE =>
                     (case read_ffi_bytearrays mc ms of
                      | (SOME bytes, SOME bytes2) =>
                          (case call_FFI ffi (EL ffi_index mc.ffi_names) bytes bytes2 of
                           | FFI_final outcome => T
                           | FFI_return new_ffi new_bytes =>
                               P ffi_index new_bytes ms /\
                               (let (ms1,new_oracle) = apply_oracle mc.ffi_interfer (ffi_index,new_bytes,ms) in
                                let mc = mc with ffi_interfer := new_oracle in
                                  ffi_calls_ok P mc new_ffi k ms1))
                      | _ => T))))`;
val _ = pr ("DEFINITION " ^ thm_to_string calls_def);
(* A5 new helper lemmas (2). *)
val RFB1 = thm "read_ffi_bytearray_ffi_interfer_update"
  ``!(mc:('a,'b,'c) machine_config) g r1 r2 ms.
      read_ffi_bytearray (mc with ffi_interfer := g) r1 r2 ms = read_ffi_bytearray mc r1 r2 ms``
  (simp [read_ffi_bytearray_def]);
val RFB2 = thm "read_ffi_bytearrays_ffi_interfer_update"
  ``!(mc:('a,'b,'c) machine_config) g ms. read_ffi_bytearrays (mc with ffi_interfer := g) ms = read_ffi_bytearrays mc ms``
  (simp [read_ffi_bytearrays_def, read_ffi_bytearray_def]);
(* A5 control C-NV (5): D3 is not trivially true. A concrete record whose pc is its only FFI entry, empty arrays, and an
   oracle that always returns; with P = F the predicate is F at clock 1. *)
val CNV = thm "ffi_calls_ok_false_at_a_returning_call"
  ``~ffi_calls_ok (\i nb ms. F)
      (<| prog_addresses := {}; shared_addresses := {}; ffi_entry_pcs := [0w]; ffi_names := [ExtCall «x»];
          ptr_reg := 0; len_reg := 1; ptr2_reg := 2; len2_reg := 3; ffi_interfer := ARB; callee_saved_regs := [];
          next_interfer := ARB; halt_pc := 4w; install_pc := 8w; install_interfer := ARB; target := arm8_target;
          mmio_info := [] |>)
      (<| oracle := (\s st c b. Oracle_return st b); ffi_state := (); io_events := [] |> : unit ffi_state)
      (SUC 0) (ARB with <| PC := 0w; REG := (\r. 0w) |>)``
  (simp [calls_def, arm8_target_def, find_index_def, read_ffi_bytearrays_def, read_ffi_bytearray_def,
         read_bytearray_def, call_FFI_def] >> TRY EVAL_TAC >> show_tac "C-NV");
(* ================= L2 ================= *)
val _ = pr "MARK L2";
(* ===== A5 v3 (tactic-only v3). Attempt L2-0001 (v2) failed: in both tactics the ExtCall leaf kept the assumption
   `ffi_calls_ok Vok (...) f k (refund_ffi_tot Vok mc1.ffi_interfer 0 (x,l,ms))` while the goal after match_mp_tac IH
   needs `... (mc1.ffi_interfer 0 (x,l,ms))` (L2-0001 stdout 87-153, 212-231): fs [TOT_T] did not rewrite that
   assumption although `Vok x l ms` was an assumption. Repair: tot_fix rewrites every assumption and the goal with the
   explicit instance MATCH_MP TOT_T (ASSUME (Vok x l ms)). The install and normal-step leaves were already closed
   (no L2-leaf-after line for them). Statement unchanged. The main lemma now runs through a staged harness that prints
   the goal count after every stage and the remaining goals at the first failing stage or at the end. ===== *)
val VokV = mk_var ("Vok", ``:num -> word8 list -> arm8_state -> bool``);
fun tot_fix (g as (asl, w) : goal) : Context.t -> goal list * validation =    (* A5 ML-only v4: explicit tactic type *)                                                  (* A5 tactic-only v3 *)
  let val hits = List.filter (fn a => let val (f, args) = strip_comb a in aconv f VokV andalso length args = 3 end
                                      handle _ => false) asl
      val eqs = map (fn a => MATCH_MP TOT_T (ASSUME a)) hits
  in if null eqs then ALL_TAC g
     else (pr ("TOT_FIX " ^ Int.toString (length eqs)); (RULE_ASSUM_TAC (REWRITE_RULE eqs) >> TRY (REWRITE_TAC eqs)) g) end;
fun cut n s = if size s <= n then s else String.substring (s, 0, n) ^ " ...";
fun print_goals tag gl =                                                       (* A5 diagnostic v3 *)
  (pr ("GOALS_LEFT " ^ tag ^ " " ^ Int.toString (length gl));
   List.app (fn (i, (asl, w)) =>
      (pr ("GOAL_" ^ Int.toString i ^ " " ^ tag);
       List.app (fn a => pr ("  ASM " ^ cut 300 (term_to_string a))) (List.take (asl, Int.min (14, length asl)));
       pr ("  CONCL " ^ cut 2400 (term_to_string w))))
     (ListPair.zip (List.tabulate (Int.min (6, length gl), fn i => i + 1), List.take (gl, Int.min (6, length gl)))));
(* prefix i = the first i stages; each prefix is applied afresh to the goal (costs a few re-runs; L2-0001 used 105 s CPU). *)
(* A5 ML-only v4: a tactic here has type goal -> Context.t -> goal list * validation (HOL/src/1/Abbrev.sig line 10).
   staged now takes the goal and the context that TAC_PROOF passes (Tactical.sml 75-77) and runs every prefix with that
   context; its partial application `staged name goal stages mk` is a tactic. *)
fun staged name goal (stages : (string * (thm -> tactic)) list) (mk : (thm -> tactic) -> tactic) (g : goal) (ctxt : Context.t) =
  let val n = length stages
      fun prefix i = mk (fn IH => List.foldl (fn ((_, t), acc) => acc >> t IH) ALL_TAC (List.take (stages, i)))
      fun run i last =
        if i > n then (print_goals (name ^ " after all stages") last; raise Fail "goals left after the last stage")
        else let val (gl, _) = prefix i ([], goal) ctxt                    (* A5 ML-only v4: context passed *)
                 val _ = pr ("STAGE " ^ name ^ " " ^ Int.toString i ^ " " ^ #1 (List.nth (stages, i - 1)) ^ " goals " ^ Int.toString (length gl))
             in if null gl then i else run (i + 1) gl end
             handle Fail m => raise Fail m
                  | e => (pr ("STAGE_FAILED " ^ name ^ " " ^ Int.toString i ^ " " ^ #1 (List.nth (stages, i - 1)) ^ " " ^ General.exnMessage e);
                          print_goals (name ^ " before stage " ^ Int.toString i) last; raise Fail "stage failed")
      val _ = pr ("STAGED " ^ name ^ " stages " ^ Int.toString n)
      val i = run 1 [([], goal)]
  in prefix i g ctxt end;                                                     (* A5 ML-only v4 *)
val L2_goal =
  ``!k mc1 mc2 ffi ms.
      mc2 = mc1 with ffi_interfer := refund_ffi_tot Vok mc1.ffi_interfer /\ ffi_calls_ok Vok mc2 ffi k ms ==>
      evaluate mc1 ffi k ms = evaluate mc2 ffi k ms``;
fun mkInd (body : thm -> tactic) : tactic = Induct >- (rpt strip_tac >> once_rewrite_tac [evaluate_def] >> simp []) >> pop_assum body;
val stages1 =
  [("unfold", fn IH => rpt gen_tac >> strip_tac >> rveq >> qpat_x_assum `ffi_calls_ok _ _ _ _ _` mp_tac >>
                       once_rewrite_tac [evaluate_def, calls_def]),
   ("simp", fn IH => simp [apply_oracle_def, TOT_T, SHIFT, RFB1, RFB2]),
   ("if-split", fn IH => rpt (IF_CASES_TAC >> simp [TOT_T, SHIFT, RFB1, RFB2])),
   ("case-split", fn IH => rpt (TOP_CASE_TAC >> simp [TOT_T, SHIFT, RFB1, RFB2])),
   ("leaf-prepare", fn IH => rpt strip_tac >> tot_fix >> fs [TOT_T, SHIFT, RFB1, RFB2]),
   ("leaf-IH", fn IH => match_mp_tac IH >> fs [TOT_T, SHIFT, RFB1, RFB2] >> TRY (simp [machine_config_component_equality]))];
val stages2 =
  [("unfold", fn IH => rpt gen_tac >> strip_tac >> rveq >> qpat_x_assum `ffi_calls_ok _ _ _ _ _` mp_tac >>
                       once_rewrite_tac [evaluate_def] >> once_rewrite_tac [calls_def]),
   ("simp", fn IH => simp_tac (srw_ss()) [apply_oracle_def, RFB1, RFB2, LET_THM]),
   ("every-case", fn IH => every_case_tac >> fs []),
   ("leaf-prepare", fn IH => rpt strip_tac >> tot_fix >> fs [TOT_T, SHIFT, RFB1, RFB2]),
   ("leaf-IH", fn IH => TRY (match_mp_tac IH >> fs [TOT_T, SHIFT, RFB1, RFB2] >> NO_TAC) >>
                        TRY (match_mp_tac IH >> simp [machine_config_component_equality] >> fs [] >> NO_TAC))];
val L2 = thmA "refund_ffi_tot_evaluate_agree" L2_goal
  [staged "L2-t1" L2_goal stages1 mkInd,                                     (* A5 ML-only v4: partial application = tactic *)
   staged "L2-t2" L2_goal stages2 mkInd];
val _ = pr ("STATEMENT_L2 " ^ term_to_string (concl L2));
val L2S = thm "refund_ffi_tot_machine_sem_agree"
  ``!mc ffi ms.
      (!k. ffi_calls_ok Vok (mc with ffi_interfer := refund_ffi_tot Vok mc.ffi_interfer) ffi k ms) ==>
      machine_sem mc ffi ms = machine_sem (mc with ffi_interfer := refund_ffi_tot Vok mc.ffi_interfer) ffi ms``
  (rpt strip_tac >>
   `!k. evaluate mc ffi k ms = evaluate (mc with ffi_interfer := refund_ffi_tot Vok mc.ffi_interfer) ffi k ms` by
      (gen_tac >> match_mp_tac L2 >> simp []) >>
   simp [FUN_EQ_THM] >> Cases >> simp [machine_sem_def] >> show_tac "L2S");
(* ================= L2R: composition with the stored theorem ================= *)
val _ = pr "MARK L2R";
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val envmc = mk_var ("envmc", mcty);
val B = ``sl + 0x1000040D0w:word64``;
val envT = ``^envmc with ffi_interfer := refund_ffi_tot Vok (^envmc).ffi_interfer``;
val EQM = thm "refund_mc_totalised_record"
  ``refund_mc b (^envmc with ffi_interfer := g) = refund_mc b ^envmc with ffi_interfer := g``
  (simp [mc_def, fix_def] >> TRY (simp [mc_def, fix_def, machine_config_component_equality]) >> show_tac "EQM");
val FLD = thm "refund_mc_totalised_record_fields"
  ``(refund_mc b (^envmc with ffi_interfer := g)).target = (refund_mc b ^envmc).target /\
    (refund_mc b (^envmc with ffi_interfer := g)).install_pc = (refund_mc b ^envmc).install_pc /\
    (refund_mc b ^envmc).ffi_interfer = (^envmc).ffi_interfer``
  (simp [mc_def, fix_def]);
val (ta_ante, ta_conc) = dest_imp (concl TA);
val okp = ``refund_env_ok_sl sl ^envmc``;
val _ = if List.exists (aconv okp) (strip_conj ta_ante) then pr "PREMISE_FOUND refund_env_ok_sl sl envmc" else bad "premise-not-found";
val new_prems = List.concat (map (fn t => if aconv t okp then
      [``interference_ok (^envmc).next_interfer (arm8_target.proj (^envmc).prog_addresses)``,
       ``refund_ffi_contract_on ^B (^envmc).prog_addresses Vok (^envmc).ffi_interfer``,
       ``!ms k. forge_refundCmlMainStep$arm8_run 27 s = SOME ms ==>
                ffi_calls_ok Vok (refund_mc ^B ^envT) (basis_ffi ext cl fs) k ms``]
      else [t]) (strip_conj ta_ante));
val L2R = thm "refund_profile_a_sl_reach"
  (mk_imp (list_mk_conj new_prems, ta_conc))
  (strip_tac >>
   mp_tac (INST [envmc |-> envT] TA) >>
   impl_tac
   >- (rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >> TRY (simp [] >> NO_TAC) >>
       match_mp_tac L1C >> asm_rewrite_tac [] >> show_tac "L2R-prem") >>
   strip_tac >>
   `!k. evaluate (refund_mc ^B ^envmc) (basis_ffi ext cl fs) k ms = evaluate (refund_mc ^B ^envT) (basis_ffi ext cl fs) k ms` by
      (gen_tac >> match_mp_tac L2 >> conj_tac
       >- (rewrite_tac [EQM, FLD])
       >- (FIRST [simp [] >> NO_TAC, metis_tac []]) ) >>
   `machine_sem (refund_mc ^B ^envmc) (basis_ffi ext cl fs) ms = machine_sem (refund_mc ^B ^envT) (basis_ffi ext cl fs) ms` by
      (simp [FUN_EQ_THM] >> Cases >> asm_simp_tac (srw_ss()) [machine_sem_def]) >>
   (* the assumptions speak of refund_mc B envT; FLD turns their .target and .install_pc into those of refund_mc B envmc;
      the two equalities above turn the goal's evaluate and machine_sem terms into those of refund_mc B envT. *)
   qexists_tac `ms` >> RULE_ASSUM_TAC (REWRITE_RULE [FLD]) >> asm_rewrite_tac [] >>
   rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >>
   TRY (qexists_tac `io_events` >> asm_rewrite_tac [] >> NO_TAC) >>         (* A5 tactic-only (4) *)
   show_tac "L2R-end" >> metis_tac []);
(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = if is_neg (concl CNV) then pr "CONTROL_OK C-NV ffi_calls_ok with the empty predicate is false at a concrete returning call"
        else bad "C-NV-not-negation";
val _ = if aconv (concl L2) L2_goal then pr "CONTROL_OK L2 statement is the literal statement of routeA-L2.sml"
        else bad "L2-literal";
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = if aconv (snd (dest_imp (concl L2R))) ta_conc
        then pr "CONTROL_OK L2R conclusion is term-identical to the conclusion of the stored refund_profile_a_sl (not weakened)"
        else bad "L2R-conclusion";
val _ = if not (has_const "refund_env_ok_sl" (fst (dest_imp (concl L2R)))) andalso not (has_const "refund_ffi_contract_at" (fst (dest_imp (concl L2R))))
        then pr "CONTROL_OK L2R premises contain neither refund_env_ok_sl nor the all-states contract refund_ffi_contract_at"
        else bad "L2R-premises";
val _ = if length (strip_conj (fst (dest_imp (concl L2R)))) = length (strip_conj ta_ante) + 2
        then pr "CONTROL_OK L2R has the stored premises with exactly one replaced by three" else bad "L2R-premise-count";
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundRouteA2" @ DB.definitions "forge_refundRouteA2");
val closure = "forge_refundRouteA2" :: Theory.ancestry "forge_refundRouteA2";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundRouteA2")));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

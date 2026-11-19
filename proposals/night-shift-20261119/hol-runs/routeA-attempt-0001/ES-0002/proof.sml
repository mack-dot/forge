(* Orchestrator A, ES-0002 (ML-only): every_case_tac qualified as BasicProvers.every_case_tac (ES-0001 static error at 221, 222). *)
(* erasure_step_v1.sml -- worker A11 (Night-Shift Orchestrator A), 2026-11-19.
   NOT RUN. NOT TYPE-CHECKED BY HOL. Every tactic is UNCHECKED. Nothing here is a result until a run ends with exit 0,
   the marker EXACT_COMPLETE, no REQUIRED_FAILED_LIST line, no UNEXPECTED_CONTROL_ACCEPTANCE, and four CLOSURE_AXIOM lines.
   The marker FULL_E_COMPLETE (printed only when NextStateARM8_erase is stored without hypotheses) is the extra marker
   for the OPTIONAL whole-model erasure stage.

   Parent: theory forge_m1bErasureV2 (case E1-0003, results/m1b-routeA-20261119/attempt-0001/E1-0003/.hol/objs/
   forge_m1bErasureV2Theory.{sig,sml}); the run loads it from the deps file (deps-L1.txt + those two lines).

   Stages, in this order (REQUIRED unless marked OPTIONAL):
     W   non-vacuity witness.
     S0  helpers: FOR loop lemmas, Mem_state, erase read/update/selector rules, SCTLR reads.
     F   one frame lemma per state-transforming definition of arm8Theory (generated from the constant's type, in file
         order), then Next_frame (the E1-0003 text, word for word) and NextStateARM8_frame.
     E1  erasure lemmas (step(erase s) = erase(step s)) for the closure needed by the branch class and the SP class:
         raise'exception X write'X SP write'SP TranslationRegime Hint_Branch CheckAlignment BigEndian Mem write'Mem
         ConditionHolds ExtendReg LoadStoreSingle dfn'LoadStoreImmediate dfn'LoadStoreRegister.
     E2  branch class: for the 5 branch instructions, B1 (step(erase s) = erase((step s) with PC := (step(erase s)).PC))
         and B2 (PC relation via tbi_pc); clean corollaries for BranchImmediate and BranchRegister with "untagged target".
     C   controls (2 proved negatives) and structural checks.
     E3  OPTIONAL: erasure lemmas for every other definition, Run, Next, and NextStateARM8_erase (E1-0003 text).
   A failed lemma is replaced by ASSUME of its own statement (printed LEMMA_FAILED); a later proof that uses it prints
   DIAG_OK_UNDER and is never stored. Any REQUIRED failure stops the run before export. An OPTIONAL failure does not
   block the export of the REQUIRED theorems (they do not depend on OPTIONAL ones); it blocks FULL_E_COMPLETE.

   Method (option b, syntactic, per definition): every state update of the L3 model is a record-field update of one of
   MEM PC PSTATE(N Z C V) REG SP_EL0..3 branch_hint exception (arm8Script.sml: 20 Rupd sites; no Rupd of TCR_EL1 or
   SCTLR_EL1; PSTATE.EL never written). TBI0/TBI1 are read only in BranchTo (arm8Script.sml 538-594) and SA0 only in
   CheckSPAlignment (605-627). So frame lemmas and erasure lemmas go through definition by definition, bottom-up, with
   the earlier lemmas as rewrites. Selector "push-in" rules (frame) and erase "pull-out" rules (erasure) are generated
   from COND_RAND and TypeBase.case_rand_of. The two FOR loops (Mem, write'Mem) use four induction lemmas on FOR_ind.
   Sources (file:line): HOL/examples/l3-machine-code/arm8/model/arm8Script.sml 8-375 (types), 379 raise'exception,
   467 X, 475 write'X, 487 SP, 499 write'SP, 515 TranslationRegime, 522 SCTLR, 530 Hint_Branch, 538 BranchTo,
   605 CheckSPAlignment, 628 CheckAlignment, 655 BigEndian, 678 Mem, 721 write'Mem, 1664-1746 branch dfns,
   1747 LoadStoreSingle, 1829/1846 LoadStoreImmediate/Register, 2486 Run, 7195 Fetch, 7203 Next;
   step/arm8_stepScript.sml 19-22 NextStateARM8; HOL/src/monad/more_monads/state_transformerScript.sml 49-54 FOR;
   cakeml/compiler/encoders/arm8/arm8_targetScript.sml 14-26 (arm8_next, arm8_ok). *)
open HolKernel boolLib bossLib wordsLib blastLib
     wordsTheory arm8Theory arm8_stepTheory targetSemTheory arm8_targetTheory alignmentTheory
     forge_m1bErasureV2Theory;
val _ = Globals.max_print_depth := 30;
fun pr s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut);
val _ = (load "Timeout"; pr "TIMEOUT_HELPER Timeout.apply loaded")
  handle e => (pr ("TIMEOUT_LOAD_FAILED " ^ General.exnMessage e); raise e);
fun short s = String.substring (s, 0, Int.min (400, size s));
val cpu0 = Timer.startCPUTimer ();
fun cpu_secs () = let val {usr, sys} = Timer.checkCPUTimer cpu0 in Time.toReal usr + Time.toReal sys end;
(* script CPU budget for OPTIONAL work; the process limit (RUN_PLAN) is 1500 s including about 110 s of loading *)
val OPT_BUDGET = 1100.0;
(* hard script budget for every lemma, so that the summary lines and the gate are always reached before the CPU limit *)
val ALL_BUDGET = 1250.0;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val THY = "forge_m1bErasureStep";
val _ = new_theory THY;

(* ---------------- harness ---------------- *)
val req_fail = ref ([] : string list);
val opt_fail = ref ([] : string list);
val diag = ref ([] : string list);
val problems = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun note req nm = if req then req_fail := nm :: !req_fail else opt_fail := nm :: !opt_fail;
fun tags name th = let val (ors, axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun sanitize n = String.translate (fn #"'" => "_" | c => String.str c) n;
fun attempt req nm secs goal tacs =
  let fun go _ [] = raise Fail "all listed tactics failed"
        | go i (t :: ts) =
            if not req andalso cpu_secs () > OPT_BUDGET then raise Fail "OPTIONAL budget exhausted"
            else if cpu_secs () > ALL_BUDGET then raise Fail "script budget exhausted (counts as a failure)"
            else
              (let val lim = Int.max (5, Int.min (secs, Real.floor (ALL_BUDGET + 100.0 - cpu_secs ())))
                   val th = Timeout.apply (Time.fromSeconds (Int.toLarge lim)) Tactical.TAC_PROOF (([], goal), t)
               in pr ("TACTIC_USED " ^ nm ^ " " ^ Int.toString i); th end
               handle Timeout.TIMEOUT _ =>
                        (pr ("TACTIC_TIMEOUT " ^ nm ^ " " ^ Int.toString i ^ " after " ^ Int.toString secs ^ " s");
                         go (i + 1) ts)
                    | e => (pr ("TACTIC_ATTEMPT_FAILED " ^ nm ^ " " ^ Int.toString i ^ " " ^ short (General.exnMessage e));
                            go (i + 1) ts))
  in go 1 tacs end;
(* lemma: proved -> stored; proved from an ASSUMEd lemma -> DIAG_OK_UNDER, not stored; failed -> ASSUME of the goal *)
fun lemma req name secs goal tacs =
  let val nm = sanitize name
      val _ = pr ("BEGIN " ^ nm ^ (if req then " REQUIRED" else " OPTIONAL") ^ " cpu=" ^ Real.fmt (StringCvt.FIX (SOME 1)) (cpu_secs ()))
  in
    (let val th = attempt req nm secs goal tacs
     in if null (hyp th) then (tags nm th; save_thm (nm, th); pr ("PROVED " ^ nm); th)
        else (pr ("DIAG_OK_UNDER " ^ nm ^ " hypotheses=" ^ Int.toString (length (hyp th)));
              diag := nm :: !diag; note req nm; th)
     end)
    handle e => (pr ("LEMMA_FAILED " ^ nm ^ " " ^ short (General.exnMessage e)); note req nm; ASSUME goal)
  end;
fun show name th = pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th);
fun def name tm = let val th = new_definition (name, tm) in pr ("DEFINITION " ^ thm_to_string th); th end;
val _ = pr ("FOR_ind " ^ thm_to_string state_transformerTheory.FOR_ind);

(* ================= W. Non-vacuity witness ================= *)
val _ = pr "MARK W";
val W_text = ``?s t. arm8_ok (erase s) /\ s.TCR_EL1.TBI0 /\ s.SCTLR_EL1.SA0 /\ untagged t /\ s.PSTATE.EL = 0w``;
val W = lemma true "W_nonvacuous" 60 W_text
  [qexists_tac `(ARB:arm8_state) with <| PSTATE := ((ARB:ProcState) with EL := 0w);
                  SCTLR_EL1 := ((ARB:SCTLRType) with <| SA0 := T; E0E := F |>);
                  TCR_EL1 := ((ARB:TCR_EL1) with TBI0 := T); exception := NoException; PC := 0w |>` >>
     qexists_tac `0w` >> simp [arm8_ok_erase, untagged_def] >> EVAL_TAC,
   qexists_tac `(ARB:arm8_state) with <| PSTATE := ((ARB:ProcState) with EL := 0w);
                  SCTLR_EL1 := ((ARB:SCTLRType) with <| SA0 := T; E0E := F |>);
                  TCR_EL1 := ((ARB:TCR_EL1) with TBI0 := T); exception := NoException; PC := 0w |>` >>
     qexists_tac `0w` >> rw [arm8_ok_erase, untagged_def, alignmentTheory.aligned_0]];
val _ = show "W_nonvacuous" W;

(* ================= S0. Helpers ================= *)
val _ = pr "MARK S0";
val st_ty = ``:arm8_state``;
val s_v = mk_var ("s", st_ty);
val TCRsel = rator ``(s:arm8_state).TCR_EL1``;
val SCsel  = rator ``(s:arm8_state).SCTLR_EL1``;
val PSsel  = rator ``(s:arm8_state).PSTATE``;
val ELsel  = rator ``(p:ProcState).EL``;
val PCsel  = rator ``(s:arm8_state).PC``;
val SPsel  = rator ``(s:arm8_state).SP_EL0``;
val HBsel  = rator ``(s:arm8_state).branch_hint``;
val EXsel  = rator ``(s:arm8_state).exception``;
val Asel   = rator ``(r:SCTLRType).A``;
val SAsel  = rator ``(r:SCTLRType).SA``;
val EEsel  = rator ``(r:SCTLRType).EE``;
val E0Esel = rator ``(r:SCTLRType).E0E``;
val FSTsel = ``FST : 'p # 'q -> 'p``;
val SNDsel = ``SND : 'p # 'q -> 'q``;
val erase_c = prim_mk_const {Thy = "forge_m1bErasureV2", Name = "erase"};
fun mk_erase t = mk_comb (erase_c, t);
fun inst_rand sel th =
  let val th0 = SPEC_ALL th
      val f = rator (lhs (concl th0))
  in INST_TY_TERM (match_term f sel) th0 end;
val arm8_tys = List.mapPartial (fn (n, a) => if a = 0 then SOME (mk_thy_type {Thy = "arm8", Tyop = n, Args = []}) else NONE)
                 (Theory.types "arm8");
val case_rands = List.mapPartial (fn ty => total TypeBase.case_rand_of ty) (``:'a option`` :: arm8_tys);
val _ = pr ("CASE_RAND_COUNT " ^ Int.toString (length case_rands) ^ " of " ^ Int.toString (1 + length arm8_tys));
fun rand_rules sel = List.mapPartial (fn th => total (inst_rand sel) th) (boolTheory.COND_RAND :: case_rands);
val FR_RAND = List.concat (map rand_rules [TCRsel, SCsel, PSsel, ELsel, SNDsel]);
val ER_OUT = List.mapPartial (fn th => total (fn t => GSYM (inst_rand erase_c t)) th) (boolTheory.COND_RAND :: case_rands);
val ER_PAIR = rand_rules FSTsel @ rand_rules SNDsel;
val PC_RAND = rand_rules PCsel @ rand_rules HBsel;
val _ = pr ("RULE_COUNTS FR_RAND " ^ Int.toString (length FR_RAND) ^ " ER_OUT " ^ Int.toString (length ER_OUT) ^
            " ER_PAIR " ^ Int.toString (length ER_PAIR));
val fupdselfid = (DB.fetch "arm8" "arm8_state_fupdselfid") handle _ => TRUTH;

(* FOR loop lemmas (state_transformerScript.sml 49-54). Two alternatives: recInduct, ho_match_mp_tac. *)
fun for_tacs pre extra =
  [pre >> recInduct state_transformerTheory.FOR_ind >> rpt strip_tac >>
     once_rewrite_tac [state_transformerTheory.FOR_def] >> Cases_on `i = j` >>
     asm_simp_tac (srw_ss()) ([state_transformerTheory.BIND_DEF, pairTheory.UNCURRY, combinTheory.o_THM] @ extra),
   pre >> ho_match_mp_tac state_transformerTheory.FOR_ind >> rpt strip_tac >>
     once_rewrite_tac [state_transformerTheory.FOR_def] >> Cases_on `i = j` >>
     asm_simp_tac (srw_ss()) ([state_transformerTheory.BIND_DEF, pairTheory.UNCURRY, combinTheory.o_THM] @ extra) >>
     metis_tac []];
val FOR_proj = lemma true "FOR_proj" 60
  ``!(p:'s -> 'b) i j (a:num -> 's -> unit # 's).
      (!k s. p (SND (a k s)) = p s) ==> !s. p (SND (state_transformer$FOR (i,j,a) s)) = p s``
  (for_tacs gen_tac []);
val FOR_snd_const = lemma true "FOR_snd_const" 60
  ``!i j (a:num -> 'x # 's -> unit # ('x # 's)).
      (!k x. SND (SND (a k x)) = SND x) ==> !x. SND (SND (state_transformer$FOR (i,j,a) x)) = SND x``
  (for_tacs ALL_TAC []);
val FOR_erase = lemma true "FOR_erase" 60
  ``!i j (a:num -> arm8_state -> unit # arm8_state).
      (!k t. a k (erase t) = (FST (a k t), erase (SND (a k t)))) ==>
      !t. state_transformer$FOR (i,j,a) (erase t) =
          (FST (state_transformer$FOR (i,j,a) t), erase (SND (state_transformer$FOR (i,j,a) t)))``
  (for_tacs ALL_TAC []);
val FOR_pair_erase = lemma true "FOR_pair_erase" 60
  ``!i j (a:num -> 'x # arm8_state -> unit # ('x # arm8_state)).
      (!k l t. a k (l, erase t) = (FST (a k (l,t)), FST (SND (a k (l,t))), erase (SND (SND (a k (l,t)))))) ==>
      !l t. state_transformer$FOR (i,j,a) (l, erase t) =
            (FST (state_transformer$FOR (i,j,a) (l,t)), FST (SND (state_transformer$FOR (i,j,a) (l,t))),
             erase (SND (SND (state_transformer$FOR (i,j,a) (l,t)))))``
  (for_tacs ALL_TAC []);
val FOR_proj_inst = List.mapPartial (fn sel => total (ISPEC sel) FOR_proj) [TCRsel, SCsel, PSsel];

(* Mem: the result state is the CheckAlignment state (the loop reads memory only). *)
val Mem_state = lemma true "Mem_state" 90
  ``!a n acc s. SND (arm8$Mem (a, n, acc) s : 'N word # arm8_state) = CheckAlignment (a, n, acc, F) s``
  [rpt gen_tac >> simp [Mem_def, boolTheory.LET_THM, pairTheory.UNCURRY, FOR_snd_const],
   rpt gen_tac >> rw [Mem_def, boolTheory.LET_THM, pairTheory.UNCURRY] >> simp [FOR_snd_const]];

val erase_reads = lemma true "erase_reads" 60
  ``!s. (erase s).MEM = s.MEM /\ (erase s).PC = s.PC /\ (erase s).PSTATE = s.PSTATE /\ (erase s).REG = s.REG /\
        (erase s).SCTLR_EL2 = s.SCTLR_EL2 /\ (erase s).SCTLR_EL3 = s.SCTLR_EL3 /\
        (erase s).SP_EL0 = s.SP_EL0 /\ (erase s).SP_EL1 = s.SP_EL1 /\ (erase s).SP_EL2 = s.SP_EL2 /\
        (erase s).SP_EL3 = s.SP_EL3 /\ (erase s).TCR_EL2 = s.TCR_EL2 /\ (erase s).TCR_EL3 = s.TCR_EL3 /\
        (erase s).branch_hint = s.branch_hint /\ (erase s).exception = s.exception /\
        (erase s).TCR_EL1 = s.TCR_EL1 with <| TBI0 := F; TBI1 := F |> /\
        (erase s).SCTLR_EL1 = s.SCTLR_EL1 with SA0 := F``
  [simp [erase_def]];
val erase_upds = lemma true "erase_upds" 90
  ``(!g s. (erase s) with MEM updated_by g = erase (s with MEM updated_by g)) /\
    (!g s. (erase s) with PC updated_by g = erase (s with PC updated_by g)) /\
    (!g s. (erase s) with PSTATE updated_by g = erase (s with PSTATE updated_by g)) /\
    (!g s. (erase s) with REG updated_by g = erase (s with REG updated_by g)) /\
    (!g s. (erase s) with SCTLR_EL2 updated_by g = erase (s with SCTLR_EL2 updated_by g)) /\
    (!g s. (erase s) with SCTLR_EL3 updated_by g = erase (s with SCTLR_EL3 updated_by g)) /\
    (!g s. (erase s) with SP_EL0 updated_by g = erase (s with SP_EL0 updated_by g)) /\
    (!g s. (erase s) with SP_EL1 updated_by g = erase (s with SP_EL1 updated_by g)) /\
    (!g s. (erase s) with SP_EL2 updated_by g = erase (s with SP_EL2 updated_by g)) /\
    (!g s. (erase s) with SP_EL3 updated_by g = erase (s with SP_EL3 updated_by g)) /\
    (!g s. (erase s) with TCR_EL2 updated_by g = erase (s with TCR_EL2 updated_by g)) /\
    (!g s. (erase s) with TCR_EL3 updated_by g = erase (s with TCR_EL3 updated_by g)) /\
    (!g s. (erase s) with branch_hint updated_by g = erase (s with branch_hint updated_by g)) /\
    (!g s. (erase s) with exception updated_by g = erase (s with exception updated_by g))``
  [rpt conj_tac >> rpt gen_tac >> simp [erase_def],
   rpt conj_tac >> rpt gen_tac >> simp [erase_def, arm8_state_component_equality]];
val fupd_PC_id = lemma true "fupd_PC_id" 30 ``!r:arm8_state. r with PC := r.PC = r``
  [simp [arm8_state_component_equality], simp [fupdselfid]];
val SCTLR_reads = lemma true "SCTLR_reads" 90
  ``!s. (SCTLR (erase s)).A = (SCTLR s).A /\ (SCTLR (erase s)).SA = (SCTLR s).SA /\
        (SCTLR (erase s)).EE = (SCTLR s).EE /\ (SCTLR (erase s)).E0E = (SCTLR s).E0E``
  [gen_tac >> simp ([SCTLR_def, TranslationRegime_def, erase_def, boolTheory.literal_case_THM] @
                    List.concat (map rand_rules [Asel, SAsel, EEsel, E0Esel])),
   gen_tac >> simp [SCTLR_def, TranslationRegime_def, erase_def, boolTheory.literal_case_THM] >>
     BasicProvers.every_case_tac >> simp [],
   gen_tac >> rw [SCTLR_def, TranslationRegime_def, erase_def, boolTheory.literal_case_THM] >> BasicProvers.every_case_tac >> fs []];
val writeX_PC = lemma true "writeX_PC" 60 ``!v n s. (write'X (v, n) s).PC = s.PC``
  [rpt gen_tac >> simp ([write'X_def] @ rand_rules PCsel),
   rpt gen_tac >> Cases_on `n = 31w` >> simp [write'X_def]];

(* ================= F. Frame lemmas, generated per definition ================= *)
val _ = pr "MARK F";
val def_names =
 ["raise'exception_def", "rec'TCR_EL1_def", "reg'TCR_EL1_def", "write'rec'TCR_EL1_def", "write'reg'TCR_EL1_def",
  "rec'TCR_EL2_EL3_def", "reg'TCR_EL2_EL3_def", "write'rec'TCR_EL2_EL3_def", "write'reg'TCR_EL2_EL3_def",
  "rec'SCTLRType_def", "reg'SCTLRType_def", "write'rec'SCTLRType_def", "write'reg'SCTLRType_def", "X_def",
  "write'X_def", "SP_def", "write'SP_def", "TranslationRegime_def", "SCTLR_def", "Hint_Branch_def", "BranchTo_def",
  "Align_def", "Aligned_def", "CheckSPAlignment_def", "CheckAlignment_def", "BigEndian_def", "ByteList_def",
  "BigEndianReverse_def", "Mem_def", "write'Mem_def", "ConditionTest_def", "ConditionHolds_def", "Ones_def",
  "Zeros_def", "Replicate_def", "HighestSetBit_def", "CountLeadingZeroBits_def", "CountLeadingSignBits_def",
  "Poly32Mod2_loop_def", "Poly32Mod2_def", "AddWithCarry_def", "SetTheFlags_def", "DecodeShift_def",
  "ShiftValue_def", "ShiftReg_def", "ExtendWord_def", "Extend_def", "DecodeRegExtend_def", "ExtendValue_def",
  "ExtendReg_def", "DecodeBitMasks_def", "dfn'Address_def", "dfn'AddSubCarry_def", "dfn'AddSubExtendRegister_def",
  "dfn'AddSubImmediate_def", "dfn'AddSubShiftedRegister_def", "dfn'LogicalImmediate_def",
  "dfn'LogicalShiftedRegister_def", "dfn'Shift_def", "dfn'MoveWide_def", "dfn'BitfieldMove_def",
  "dfn'ConditionalCompareImmediate_def", "dfn'ConditionalCompareRegister_def", "dfn'ConditionalSelect_def",
  "dfn'CountLeading_def", "dfn'ExtractRegister_def", "dfn'Division_def", "dfn'MultiplyAddSub_def",
  "dfn'MultiplyAddSubLong_def", "dfn'MultiplyHigh_def", "dfn'Reverse_def", "dfn'CRC_def",
  "dfn'BranchConditional_def", "dfn'BranchImmediate_def", "dfn'BranchRegister_def", "dfn'CompareAndBranch_def",
  "dfn'TestBitAndBranch_def", "LoadStoreSingle_def", "dfn'LoadStoreImmediate_def", "dfn'LoadStoreRegister_def",
  "dfn'LoadStorePair_def", "ExclusiveMonitorPass_def", "SetExclusiveMonitors_def", "ExclusiveMonitorStatus_def",
  "dfn'LoadStoreAcquire_def", "dfn'LoadStoreAcquirePair_def", "dfn'LoadLiteral_def", "dfn'MemoryBarrier_def",
  "dfn'ClearExclusive_def", "dfn'Hint_def", "dfn'Breakpoint_def", "dfn'DebugSwitch_def", "dfn'DebugRestore_def",
  "dfn'Halt_def", "dfn'SystemInstruction_def", "dfn'MoveSystemRegister_def", "dfn'MoveImmediateProcState_def",
  "dfn'SupervisorCall_def", "dfn'HypervisorCall_def", "dfn'SecureMonitorCall_def", "dfn'ExceptionReturn_def",
  "dfn'Unallocated_def", "dfn'Reserved_def", "Run_def", "DecodeLogicalOp_def", "NoOperation_def",
  "LoadStoreRegister_def", "LoadStoreImmediateN_def", "LoadStoreImmediate_def", "LoadStorePairN_def",
  "LoadStorePair_def", "LoadStoreAcquireN_def", "LoadStoreAcquire_def", "Decode_def", "Fetch_def", "Next_def",
  "CountTrailing_def", "EncodeBitMaskAux_def", "EncodeBitMask_def", "e_sf_def", "EncodeLogicalOp_def", "e_data_def",
  "e_debug_def", "e_crc_def", "e_branch_def", "e_system_def", "e_LoadStoreImmediate_def",
  "e_LoadStoreRegister_def", "e_load_store_def", "Encode_def"];
val _ = pr ("DEF_NAMES " ^ Int.toString (length def_names));   (* expected 130 = grep -c '^val .*_def' arm8Script.sml *)
datatype kind = ST | PR | RD;
fun occ ty = ty = st_ty orelse (not (is_vartype ty) andalso List.exists occ (snd (dest_type ty)));
fun is_pair_st ty = not (is_vartype ty) andalso
  (case dest_type ty of ("prod", [a, b]) => b = st_ty andalso not (occ a) | _ => false);
fun res_kind r = if r = st_ty then SOME ST else if is_pair_st r then SOME PR else if occ r then NONE else SOME RD;
(* SOME (hasArg, kind) for c : state -> R  or  c : A -> state -> R *)
fun classify c =
  case total dom_rng (type_of c) of
    NONE => NONE
  | SOME (d, r) =>
      if d = st_ty then Option.map (fn k => (false, k)) (res_kind r)
      else if occ d then NONE
      else (case total dom_rng r of
              SOME (d2, r2) => if d2 = st_ty then Option.map (fn k => (true, k)) (res_kind r2) else NONE
            | NONE => NONE);
fun cname_of dname = String.substring (dname, 0, size dname - 4);
fun lookup dname =
  let val cn = cname_of dname
  in case (total prim_mk_const {Thy = "arm8", Name = cn}, total (DB.fetch "arm8") dname) of
       (SOME c, SOME d) => SOME (cn, c, d)
     | _ => (pr ("NAME_MISSING " ^ dname); NONE)
  end;
fun app_of c hasArg = if hasArg then mk_comb (c, mk_var ("x", fst (dom_rng (type_of c)))) else c;
fun vars_of f hasArg = (if hasArg then [rand f] else []) @ [s_v];
fun out_of k t = if k = PR then pairSyntax.mk_snd t else t;
fun frame_body t =
  list_mk_conj [mk_eq (mk_comb (TCRsel, t), mk_comb (TCRsel, s_v)),
                mk_eq (mk_comb (SCsel, t), mk_comb (SCsel, s_v)),
                mk_eq (mk_comb (ELsel, mk_comb (PSsel, t)), mk_comb (ELsel, mk_comb (PSsel, s_v)))];
fun frame_goal c hasArg k =
  let val f = app_of c hasArg in list_mk_forall (vars_of f hasArg, frame_body (out_of k (mk_comb (f, s_v)))) end;
val big = ["Run", "dfn'LoadStorePair", "dfn'LoadStoreAcquire", "dfn'LoadStoreAcquirePair", "LoadStoreSingle",
           "Mem", "write'Mem", "Next"];
fun secs_of cn = if cn = "Run" then 240 else if List.exists (fn b => b = cn) big then 150 else 60;
val frames = ref ([] : thm list);
fun FRset () = [boolTheory.LET_THM, pairTheory.UNCURRY, pairTheory.pair_CASE_def, boolTheory.literal_case_THM,
                FOR_proj, FOR_snd_const, Mem_state] @ FOR_proj_inst @ FR_RAND @ !frames;
fun frame_tacs d =
  [rpt gen_tac >> TRY (PairCases_on `x`) >> simp (d :: FRset ()),
   rpt gen_tac >> TRY (PairCases_on `x`) >> simp (d :: FRset ()) >> BasicProvers.every_case_tac >> simp (FRset ()),
   rpt gen_tac >> TRY (PairCases_on `x`) >> simp [d] >> BasicProvers.every_case_tac >> simp (FRset ())];
val n_frame = ref 0;
val _ = List.app (fn dname =>
  if dname = "Next_def" then () else
  case lookup dname of
    NONE => ()
  | SOME (cn, c, d) =>
      (case classify c of
         NONE => pr ("FRAME_SKIP " ^ cn ^ " (no state-transformer shape)")
       | SOME (_, RD) => ()
       | SOME (hasArg, k) =>
           let val th = lemma true ("frame_" ^ cn) (secs_of cn) (frame_goal c hasArg k) (frame_tacs d)
           in frames := th :: !frames; n_frame := !n_frame + 1 end)) def_names;
val _ = pr ("FRAME_LEMMAS " ^ Int.toString (!n_frame));
(* Next: the E1-0003 statement, word for word (E1-0003/proof.sml lines 226-227), via its closed form. *)
val NF_text = ``(arm8$Next s).TCR_EL1 = s.TCR_EL1 /\ (arm8$Next s).SCTLR_EL1 = s.SCTLR_EL1 /\ (arm8$Next s).PSTATE.EL = s.PSTATE.EL``;
val NFA = lemma true "Next_frame_all" 150 (list_mk_forall ([s_v], NF_text))
  [gen_tac >> simp (Next_def :: FRset ()),
   gen_tac >> simp (Next_def :: FRset ()) >> BasicProvers.every_case_tac >> simp (FRset ()),
   gen_tac >> rw (Next_def :: FRset ())];
val NF = lemma true "Next_frame" 60 NF_text [simp [NFA], metis_tac [NFA]];
val _ = show "Next_frame" NF;
val NSF = lemma true "NextStateARM8_frame" 60
  ``!s t. NextStateARM8 s = SOME t ==>
          t.TCR_EL1 = s.TCR_EL1 /\ t.SCTLR_EL1 = s.SCTLR_EL1 /\ t.PSTATE.EL = s.PSTATE.EL``
  [rpt gen_tac >> simp [NextStateARM8_def, boolTheory.LET_THM] >> rw [] >> simp [NFA],
   rpt gen_tac >> rw [NextStateARM8_def, boolTheory.LET_THM] >> simp [NFA],
   rpt strip_tac >> qpat_x_assum `NextStateARM8 _ = _` mp_tac >> simp [NextStateARM8_def, boolTheory.LET_THM] >>
     rw [] >> metis_tac [NFA]];
val _ = show "NextStateARM8_frame" NSF;

(* ================= E1. Erasure lemmas for the branch and SP closure ================= *)
val _ = pr "MARK E1";
val SP_prem = ``(s:arm8_state).PSTATE.EL = 0w /\ (~s.SCTLR_EL1.SA0 \/ aligned 4 s.SP_EL0)``;
val EL0 = ``(s:arm8_state).PSTATE.EL = 0w``;
fun e_goal c hasArg k sp =
  let val f = app_of c hasArg
      val L = mk_comb (f, mk_erase s_v)
      val R = mk_comb (f, s_v)
      val body = case k of
                   ST => mk_eq (L, mk_erase R)
                 | RD => mk_eq (L, R)
                 | PR => mk_conj (mk_eq (pairSyntax.mk_fst L, pairSyntax.mk_fst R),
                                  mk_eq (pairSyntax.mk_snd L, mk_erase (pairSyntax.mk_snd R)))
  in list_mk_forall (vars_of f hasArg, if sp then mk_imp (SP_prem, body) else body) end;
val erasers = ref ([] : thm list);
val etab = ref ([] : (string * thm) list);
fun ERset () = [boolTheory.LET_THM, pairTheory.UNCURRY, pairTheory.pair_CASE_def, boolTheory.literal_case_THM,
                erase_reads, erase_upds, SCTLR_reads, fupd_PC_id, FOR_erase, FOR_pair_erase, FOR_snd_const,
                Mem_state, CheckSPAlignment_erase] @ ER_OUT @ ER_PAIR @ !erasers;
fun e_tacs d sp =
  let val pre = rpt gen_tac >> TRY (PairCases_on `x`) >> (if sp then DISCH_TAC else ALL_TAC)
  in [pre >> simp (d :: ERset ()),
      pre >> simp (d :: ERset ()) >> BasicProvers.every_case_tac >> simp (ERset ()),
      pre >> simp (d :: ERset ()) >> rpt IF_CASES_TAC >> simp (ERset ())] end;
val e_excluded = ["SCTLR", "BranchTo", "CheckSPAlignment", "dfn'BranchConditional", "dfn'BranchImmediate",
                  "dfn'BranchRegister", "dfn'CompareAndBranch", "dfn'TestBitAndBranch", "Run", "Next"];
val sp_class = ["LoadStoreSingle", "dfn'LoadStoreImmediate", "dfn'LoadStoreRegister", "dfn'LoadStorePair",
                "dfn'LoadStoreAcquire", "dfn'LoadStoreAcquirePair"];
val e_required = ["raise'exception", "X", "write'X", "SP", "write'SP", "TranslationRegime", "Hint_Branch",
                  "CheckAlignment", "BigEndian", "Mem", "write'Mem", "ConditionHolds", "ExtendReg",
                  "LoadStoreSingle", "dfn'LoadStoreImmediate", "dfn'LoadStoreRegister"];
fun mem x l = List.exists (fn y => y = x) l;
fun e_engine req select =
  List.app (fn dname =>
    case lookup dname of
      NONE => ()
    | SOME (cn, c, d) =>
        if mem cn e_excluded orelse not (select cn) then () else
        (case classify c of
           NONE => ()
         | SOME (hasArg, k) =>
             let val sp = mem cn sp_class
                 val th = lemma req ("erase_" ^ cn) (secs_of cn) (e_goal c hasArg k sp) (e_tacs d sp)
             in erasers := th :: !erasers; etab := (cn, th) :: !etab end)) def_names;
val _ = e_engine true (fn cn => mem cn e_required);
fun getE cn = case List.find (fn (n, _) => n = cn) (!etab) of SOME (_, th) => th
                | NONE => (pr ("NO_ERASE_LEMMA " ^ cn); TRUTH);

(* ================= E2. Branch class ================= *)
val _ = pr "MARK E2";
val branch_names = ["dfn'BranchConditional", "dfn'BranchImmediate", "dfn'BranchRegister", "dfn'CompareAndBranch",
                    "dfn'TestBitAndBranch"];
fun BRset () = ERset () @ FRset () @ [BranchTo_EL0_pc, tbi_pc_erased, writeX_PC] @ PC_RAND;
fun b_tacs d =
  let val pre = rpt gen_tac >> TRY (PairCases_on `x`) >> DISCH_TAC
  in [pre >> simp (d :: BRset ()) >> rpt IF_CASES_TAC >> simp (BRset ()),
      pre >> simp (d :: BRset ()) >> BasicProvers.every_case_tac >> simp (BRset ()),
      pre >> rw (d :: BRset ()) >> simp (arm8_state_component_equality :: BRset ())] end;
val b1s = ref ([] : thm list);
val b2s = ref ([] : thm list);
val _ = List.app (fn cn =>
  case lookup (cn ^ "_def") of
    NONE => note true ("B_" ^ cn)
  | SOME (_, c, d) =>
      let val f = app_of c true
          val L = mk_comb (f, mk_erase s_v)
          val R = mk_comb (f, s_v)
          val g1 = list_mk_forall (vars_of f true, mk_imp (EL0, ``^L = erase ((^R) with PC := (^L).PC)``))
          val g2 = list_mk_forall (vars_of f true, mk_imp (EL0,
                     ``(^R).PC = (^L).PC \/ (IS_SOME (^R).branch_hint /\ (^R).PC = tbi_pc s.TCR_EL1 (^L).PC)``))
          val t1 = lemma true ("B1_" ^ cn) 150 g1 (b_tacs d)
          val t2 = lemma true ("B2_" ^ cn) 150 g2 (b_tacs d)
      in b1s := t1 :: !b1s; b2s := t2 :: !b2s end) branch_names;
val BI_clean = lemma true "BranchImmediate_erase_untagged" 150
  ``!off bt s. s.PSTATE.EL = 0w /\ untagged (s.PC + off) ==>
       dfn'BranchImmediate (off, bt) (erase s) = erase (dfn'BranchImmediate (off, bt) s)``
  [rpt strip_tac >> simp (dfn'BranchImmediate_def :: tbi_pc_untagged :: BRset ()) >> rpt IF_CASES_TAC >>
     simp (tbi_pc_untagged :: BRset ()),
   rpt strip_tac >> `untagged (off + s.PC)` by metis_tac [wordsTheory.WORD_ADD_COMM] >>
     simp (dfn'BranchImmediate_def :: tbi_pc_untagged :: BRset ()) >> rpt IF_CASES_TAC >>
     simp (tbi_pc_untagged :: arm8_state_component_equality :: BRset ()),
   rpt strip_tac >> rw (dfn'BranchImmediate_def :: tbi_pc_untagged :: BRset ()) >>
     simp (tbi_pc_untagged :: arm8_state_component_equality :: BRset ())];
val _ = show "BranchImmediate_erase_untagged" BI_clean;
val BR_clean = lemma true "BranchRegister_erase_untagged" 150
  ``!n bt s. s.PSTATE.EL = 0w /\ untagged (X n s : word64) ==>
       dfn'BranchRegister (n, bt) (erase s) = erase (dfn'BranchRegister (n, bt) s)``
  [rpt strip_tac >> simp (dfn'BranchRegister_def :: tbi_pc_untagged :: BRset ()) >> rpt IF_CASES_TAC >>
     simp (tbi_pc_untagged :: BRset ()),
   rpt strip_tac >> rw (dfn'BranchRegister_def :: tbi_pc_untagged :: BRset ()) >>
     simp (tbi_pc_untagged :: arm8_state_component_equality :: BRset ())];
val _ = show "BranchRegister_erase_untagged" BR_clean;
val _ = show "LoadStoreSingle_erase (SP class)" (getE "LoadStoreSingle") handle e => pr ("NO_SP_LEMMA " ^ General.exnMessage e);

(* ================= C. Controls ================= *)
val _ = pr "MARK CONTROLS";
(* C1: without "untagged", a step of the branch class does NOT commute with erase (TBI0 set, tagged target). *)
val C1 = lemma true "C1_tagged_BranchImmediate_breaks" 90
  ``!s. s.PSTATE.EL = 0w /\ s.TCR_EL1.TBI0 /\ s.PC = 0w ==>
        dfn'BranchImmediate (0x0100000000001000w, BranchType_JMP) (erase s) <>
        erase (dfn'BranchImmediate (0x0100000000001000w, BranchType_JMP) s)``
  [rpt strip_tac >> pop_assum mp_tac >> simp [dfn'BranchImmediate_def, erase_reads] >>
     metis_tac [N1a_tagged_branch_breaks],
   rpt strip_tac >> pop_assum mp_tac >> asm_simp_tac (srw_ss()) [dfn'BranchImmediate_def, erase_reads] >>
     strip_tac >> metis_tac [N1a_tagged_branch_breaks]];
(* C2: with SA0 set and a misaligned SP, CheckSPAlignment does NOT commute with erase. *)
val C2 = lemma true "C2_misaligned_SP_breaks" 90
  ``!s. s.PSTATE.EL = 0w /\ s.exception = NoException /\ s.SCTLR_EL1.SA0 /\ s.SP_EL0 = 8w ==>
        CheckSPAlignment (erase s) <> erase (CheckSPAlignment s)``
  [metis_tac [N2_misaligned_sp_breaks, erase_reads, TypeBase.distinct_of ``:exception``],
   rpt strip_tac >>
     `(CheckSPAlignment (erase s)).exception = NoException /\ (CheckSPAlignment s).exception = ALIGNMENT_FAULT`
        by metis_tac [N2_misaligned_sp_breaks] >>
     qpat_x_assum `CheckSPAlignment (erase s) = _` (fn th => fs [th, erase_reads]),
   rpt strip_tac >> mp_tac N2_misaligned_sp_breaks >> simp [erase_reads]];
fun negchk name th = if is_neg (snd (dest_imp (snd (strip_forall (concl th))))) andalso null (hyp th)
                     then pr ("CONTROL_OK " ^ name ^ " is a proved negative") else bad (name ^ "-not-a-proved-negative");
val _ = negchk "C1" C1; val _ = negchk "C2" C2;
val _ = if aconv (concl NF) NF_text then pr "CONTROL_OK Next_frame is the literal E1-0003 statement" else bad "NF-literal";
val _ = if aconv (concl W) W_text then pr "CONTROL_OK W is the requested statement" else bad "W-literal";
val _ = if length (hyp W) = 0 then pr "CONTROL_OK W has no hypotheses" else bad "W-hyps";

(* ================= Deferred statements (type-checked only; nothing proved or assumed) ================= *)
val _ = pr "MARK DEFERRED";
fun tc name q = (let val t = Parse.Term q in
                   if type_of t = bool then pr ("STATEMENT_TYPECHECKS " ^ name) else bad ("not-boolean " ^ name) end)
                handle e => bad ("statement-does-not-typecheck " ^ name ^ " " ^ General.exnMessage e);
val _ = tc "Next_erase (E1-0003 text)"
  `s.PSTATE.EL = 0w /\ s.exception = NoException /\ (arm8$Next s).exception = NoException /\
   untagged (arm8$Next (erase s)).PC ==> arm8$Next (erase s) = erase (arm8$Next s)`;
val _ = tc "Next_erase_fault_mono (E1-0003 text)"
  `s.PSTATE.EL = 0w /\ s.exception = NoException /\ (arm8$Next (erase s)).exception <> NoException ==>
   (arm8$Next s).exception <> NoException`;
val _ = tc "NextStateARM8_erase_or_fault (E1-0003 text)"
  `s.PSTATE.EL = 0w /\ s.exception = NoException /\ NextStateARM8 (erase s) = SOME t /\ untagged t.PC ==>
   NextStateARM8 s = SOME (restore (bits_of s) t) \/
   (NextStateARM8 s = NONE /\ s.SCTLR_EL1.SA0 /\ ~aligned 4 s.SP_EL0)`;
val _ = tc "arm8_next_erase (bridge to the stored arm8_next)"
  `s.PSTATE.EL = 0w /\ s.exception = NoException /\ (~s.SCTLR_EL1.SA0 \/ aligned 4 s.SP_EL0) /\
   NextStateARM8 s = SOME u /\ untagged (arm8_next (erase s)).PC ==> arm8_next (erase s) = erase (arm8_next s)`;

(* ================= E3. OPTIONAL: whole-model erasure ================= *)
val _ = pr "MARK E3 OPTIONAL";
val _ = e_engine false (fn cn => not (mem cn e_required));
val NX_def = def "NX_def"
  ``NX (r:arm8_state) = if ~IS_SOME r.branch_hint then r with PC := r.PC + 4w else r``;
fun leaf tacs = FIRST (map (fn t => t >> NO_TAC) tacs);
val RunE_text =
  ``!ast s. s.PSTATE.EL = 0w /\ (~s.SCTLR_EL1.SA0 \/ aligned 4 s.SP_EL0) ==>
       arm8$Run ast (erase s) = erase ((arm8$Run ast s) with PC := (arm8$Run ast (erase s)).PC)``;
val RunE = lemma false "Run_erase_pc" 300 RunE_text
  [rpt gen_tac >> DISCH_TAC >> simp [Run_def] >> BasicProvers.every_case_tac >>
     leaf ([simp (ERset ())] @ map (fn th => irule th >> simp []) (!b1s) @ [metis_tac (!b1s)])];
val RunPC = lemma false "Run_pc" 300
  ``!ast s. s.PSTATE.EL = 0w /\ (~s.SCTLR_EL1.SA0 \/ aligned 4 s.SP_EL0) ==>
       (arm8$Run ast s).PC = (arm8$Run ast (erase s)).PC \/
       (IS_SOME (arm8$Run ast s).branch_hint /\ (arm8$Run ast s).PC = tbi_pc s.TCR_EL1 (arm8$Run ast (erase s)).PC)``
  [rpt gen_tac >> DISCH_TAC >> simp [Run_def] >> BasicProvers.every_case_tac >>
     leaf ([simp (ERset ())] @ map (fn th => irule th >> simp []) (!b2s) @ [metis_tac (!b2s)])];
val Next_alt = lemma false "Next_alt" 120
  ``!s. arm8$Next s = NX (arm8$Run (arm8$Decode (FST (arm8$Fetch (s with branch_hint := NONE))))
                                   (SND (arm8$Fetch (s with branch_hint := NONE))))``
  [gen_tac >> simp [Next_def, NX_def, boolTheory.LET_THM, pairTheory.UNCURRY],
   gen_tac >> rw [Next_def, NX_def, boolTheory.LET_THM, pairTheory.UNCURRY]];
val NX_erase = lemma false "NX_erase" 90
  ``!r p. NX (erase (r with PC := p)) = erase (NX r with PC := (NX (erase (r with PC := p))).PC)``
  [rpt gen_tac >> Cases_on `r.branch_hint` >> simp (NX_def :: ERset ()),
   rpt gen_tac >> Cases_on `r.branch_hint` >> simp (NX_def :: arm8_state_component_equality :: ERset ()),
   rpt gen_tac >> simp [NX_def] >> rw [] >> simp (arm8_state_component_equality :: ERset ())];
val NX_pc = lemma false "NX_pc" 90
  ``!r q tcr. (r.PC = q.PC \/ (IS_SOME r.branch_hint /\ r.PC = tbi_pc tcr q.PC)) /\ q.branch_hint = r.branch_hint ==>
              (NX r).PC = (NX q).PC \/ (NX r).PC = tbi_pc tcr (NX q).PC``
  [rpt gen_tac >> Cases_on `r.branch_hint` >> simp [NX_def] >> rpt strip_tac >> simp [],
   rpt gen_tac >> Cases_on `r.branch_hint` >> rw [NX_def] >> fs []];
val Fetch_keep = lemma false "Fetch_keep" 90
  ``!s. (SND (arm8$Fetch s)).PSTATE = s.PSTATE /\ (SND (arm8$Fetch s)).SCTLR_EL1 = s.SCTLR_EL1 /\
        (SND (arm8$Fetch s)).SP_EL0 = s.SP_EL0 /\ (SND (arm8$Fetch s)).TCR_EL1 = s.TCR_EL1``
  [gen_tac >> simp ([Fetch_def, Mem_state, CheckAlignment_def, raise'exception_def] @
                    List.concat (map rand_rules [PSsel, SCsel, SPsel, TCRsel])),
   gen_tac >> simp [Fetch_def, Mem_state, CheckAlignment_def, raise'exception_def] >> BasicProvers.every_case_tac >> simp []];
val W1 = `arm8$Decode (FST (arm8$Fetch (s with branch_hint := NONE)))`;
val T1 = `SND (arm8$Fetch (s with branch_hint := NONE))`;
val NEP = lemma false "Next_erase_pc" 240
  ``!s. s.PSTATE.EL = 0w /\ (~s.SCTLR_EL1.SA0 \/ aligned 4 s.SP_EL0) ==>
        arm8$Next (erase s) = erase ((arm8$Next s) with PC := (arm8$Next (erase s)).PC)``
  [gen_tac >> DISCH_TAC >> once_rewrite_tac [Next_alt] >>
     simp [erase_upds, getE "Fetch"] >>
     qspecl_then [W1, T1] mp_tac RunE >> impl_tac >- simp [Fetch_keep] >>
     disch_then (fn th => once_rewrite_tac [th]) >> MATCH_ACCEPT_TAC NX_erase,
   gen_tac >> DISCH_TAC >> once_rewrite_tac [Next_alt] >>
     simp [erase_upds, getE "Fetch"] >>
     qspecl_then [W1, T1] mp_tac RunE >> impl_tac >- simp [Fetch_keep] >>
     disch_then (fn th => once_rewrite_tac [th]) >> metis_tac [NX_erase]];
val NPC = lemma false "Next_pc" 240
  ``!s. s.PSTATE.EL = 0w /\ (~s.SCTLR_EL1.SA0 \/ aligned 4 s.SP_EL0) ==>
        (arm8$Next s).PC = (arm8$Next (erase s)).PC \/ (arm8$Next s).PC = tbi_pc s.TCR_EL1 (arm8$Next (erase s)).PC``
  [gen_tac >> DISCH_TAC >> once_rewrite_tac [Next_alt] >>
     simp [erase_upds, getE "Fetch"] >>
     match_mp_tac NX_pc >> conj_tac
     >- (qspecl_then [W1, T1] mp_tac RunPC >> impl_tac >- simp [Fetch_keep] >> simp [Fetch_keep])
     >> (qspecl_then [W1, T1] mp_tac RunE >> impl_tac >- simp [Fetch_keep] >>
         disch_then (fn th => once_rewrite_tac [th]) >> simp [erase_reads])];
val NE1 = lemma false "Next_erase_exception" 120
  ``!s. s.PSTATE.EL = 0w /\ (~s.SCTLR_EL1.SA0 \/ aligned 4 s.SP_EL0) ==>
        (arm8$Next (erase s)).exception = (arm8$Next s).exception``
  [gen_tac >> DISCH_TAC >> qspec_then `s` mp_tac NEP >> impl_tac >- simp [] >>
     disch_then (fn th => once_rewrite_tac [th]) >> simp [erase_reads]];
val NE2 = lemma false "Next_erase_same_pc" 120
  ``!s. s.PSTATE.EL = 0w /\ (~s.SCTLR_EL1.SA0 \/ aligned 4 s.SP_EL0) /\ (arm8$Next s).PC = (arm8$Next (erase s)).PC ==>
        arm8$Next (erase s) = erase (arm8$Next s)``
  [gen_tac >> DISCH_TAC >> qspec_then `s` mp_tac NEP >> impl_tac >- simp [] >>
     disch_then (fn th => once_rewrite_tac [th]) >>
     qpat_x_assum `_ /\ _` (fn th => rewrite_tac [GSYM (CONJUNCT2 (CONJUNCT2 th))]) >>
     AP_TERM_TAC >> simp [arm8_state_component_equality]];
(* E1-0003 statement NextStateARM8_erase, word for word (E1-0003/proof.sml lines 234-237). *)
val NSE_text =
  ``s.PSTATE.EL = 0w /\ s.exception = NoException /\ (~s.SCTLR_EL1.SA0 \/ aligned 4 s.SP_EL0) /\
    (!t. NextStateARM8 (erase s) = SOME t ==> untagged t.PC) ==>
    NextStateARM8 (erase s) = OPTION_MAP erase (NextStateARM8 s)``;
val NSE = lemma false "NextStateARM8_erase" 240 NSE_text
  [rpt strip_tac >>
     `(arm8$Next (erase s)).exception = (arm8$Next s).exception` by (irule NE1 >> simp []) >>
     Cases_on `(arm8$Next s).exception = NoException` >>
     asm_simp_tac (srw_ss()) [NextStateARM8_def, boolTheory.LET_THM] >>
     `untagged (arm8$Next (erase s)).PC`
        by (first_x_assum (qspec_then `arm8$Next (erase s)` mp_tac) >>
            asm_simp_tac (srw_ss()) [NextStateARM8_def, boolTheory.LET_THM]) >>
     `(arm8$Next s).PC = (arm8$Next (erase s)).PC` by metis_tac [NPC, tbi_pc_untagged] >>
     metis_tac [NE2]];
val _ = show "NextStateARM8_erase" NSE;

(* ================= Checks and export ================= *)
val _ = pr "MARK CHECKS";
val _ = List.app (fn n => pr ("OPTIONAL_FAILED_LIST " ^ n)) (rev (!opt_fail));
val _ = List.app (fn n => pr ("DIAG_OK_UNDER_LIST " ^ n)) (rev (!diag));
val _ = pr ("CPU_SECONDS_SCRIPT " ^ Real.fmt (StringCvt.FIX (SOME 1)) (cpu_secs ()));
val _ = if null (!req_fail) then ()
        else (pr ("REQUIRED_FAILED_LIST " ^ String.concatWith " " (rev (!req_fail)));
              raise Fail "REQUIRED lemmas failed; nothing exported");
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems THY @ DB.definitions THY);
val closure = THY :: Theory.ancestry THY;
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems THY)));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions THY)));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val full_e = null (hyp NSE) andalso List.exists (fn (n, _) => n = "NextStateARM8_erase") (DB.theorems THY)
             andalso aconv (concl NSE) NSE_text;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = if full_e then pr "FULL_E_COMPLETE" else pr "FULL_E_NOT_COMPLETE (see OPTIONAL_FAILED_LIST)";
val _ = OS.Process.exit OS.Process.success;

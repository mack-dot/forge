(* erasure_step_v5.sml -- worker A29 (Night-Shift Orchestrator A), 2026-11-19. Case EE-0001. PROOF script.
   NOT RUN as EE-0001. Every tactic UNCHECKED as a stored proof.
   FAITHFUL REPLAY of EEx-0002 (EEx-0002.sml sha256 732103e1...90a5; ran: actual exit 0, EXPLORE_COMPLETE,
   A/EEx-0002/stdout.log sha256 2bbbc325...69f5, WOULD_FAIL_LIST empty at line 5422). Lemma text and tactic text are
   copied from EEx-0002.sml. The only tactic-list changes: the tactic that the log shows as used comes FIRST
   (erase_write_SP: TACTIC_USED 3, stdout 194; BranchImmediate_erase_untagged: TACTIC_USED 2, stdout 4222);
   every other lemma used tactic 1 there. Removed: stepper, explorations, hooks, probes P1-P6, CSA_imp_form.
   Harness: EF-0001.sml (stored PROVED lemmas; DIAG/ASSUME fallback never stored; any failure blocks export;
   tag check over all theorems and definitions; exactly four closure axioms; EXACT_COMPLETE after export).
   New theory forge_m1bEraseStep; parents forge_m1bErasureV2 (E1-0003) and forge_m1bErasureFrame (EF-0001);
   deps deps-EE.txt. One definition NX_def. Note: W_nonvacuous, FOR_proj, FOR_snd_const, Mem_state are also stored
   in EF-0001 under the same names (same text); here they are re-proved and stored in the new theory.
   Pass = actual exit 0, EXACT_COMPLETE, no REQUIRED_FAILED_LIST, no UNEXPECTED_CONTROL_ACCEPTANCE, four
   CLOSURE_AXIOM lines, STORED_THEOREMS 101, STORED_DEFINITIONS 1, CONTROL_OK lines for the literal end results. *)
open HolKernel boolLib bossLib wordsLib blastLib
     wordsTheory arm8Theory arm8_stepTheory targetSemTheory arm8_targetTheory alignmentTheory
     forge_m1bErasureV2Theory forge_m1bErasureFrameTheory;
val _ = Globals.max_print_depth := 30;
fun pr s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut);
val _ = (load "Timeout"; pr "TIMEOUT_HELPER Timeout.apply loaded")
  handle e => (pr ("TIMEOUT_LOAD_FAILED " ^ General.exnMessage e); raise e);
fun short s = String.substring (s, 0, Int.min (400, size s));
fun trunc n s = if size s <= n then s else String.substring (s, 0, n) ^ " ...";
val cpu0 = Timer.startCPUTimer ();
fun cpu_secs () = let val {usr, sys} = Timer.checkCPUTimer cpu0 in Time.toReal usr + Time.toReal sys end;
val ALL_BUDGET = 1250.0;     (* script CPU for proofs; RUN_PLAN process limit 1500 s incl. about 110 s of loading *)

val _ = metisTools.limit := {time = SOME 20.0, infs = NONE};
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val THY = "forge_m1bEraseStep";
val _ = new_theory THY;

(* ---------------- harness (EF-0001.sml text; lemmaL keeps the EEx bool argument, unused) ---------------- *)
val req_fail = ref ([] : string list);
val diag = ref ([] : string list);
val problems = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun tags name th = let val (ors, axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun sanitize n = String.translate (fn #"'" => "_" | c => String.str c) n;
fun show_left nm goal (t : tactic) =
  (let val ctxt = Context.snapshot ()
       val (gs, _) = Timeout.apply (Time.fromSeconds (Int.toLarge 60)) (fn () => t ([], goal) ctxt) ()
       fun one k (asl, w) =
         (pr ("  LEFT " ^ nm ^ " #" ^ Int.toString k ^ " assumptions " ^ Int.toString (length asl));
          List.app (fn a => pr ("    ASM " ^ trunc 500 (term_to_string a))) (List.take (asl, Int.min (8, length asl)));
          pr ("    CONCL " ^ trunc 2500 (term_to_string w)))
       fun loop _ [] = ()
         | loop k (g :: r) = if k > 3 then () else (one k g; loop (k + 1) r)
   in pr ("LEFT_GOALS " ^ nm ^ " count " ^ Int.toString (length gs)); loop 1 gs end)
  handle Timeout.TIMEOUT _ => pr ("LEFT_GOALS_TIMEOUT " ^ nm)
       | e => pr ("LEFT_GOALS_ERROR " ^ nm ^ " " ^ short (General.exnMessage e));
fun attempt nm secs goal tacs =
  let fun go _ [] = raise Fail "all listed tactics failed"
        | go i (t :: ts) =
            if cpu_secs () > ALL_BUDGET then raise Fail "script budget exhausted (counts as a failure)"
            else
              (let val lim = Int.max (5, Int.min (secs, Real.floor (ALL_BUDGET + 60.0 - cpu_secs ())))
                   val th = Timeout.apply (Time.fromSeconds (Int.toLarge lim)) Tactical.TAC_PROOF (([], goal), t)
               in pr ("TACTIC_USED " ^ nm ^ " " ^ Int.toString i); th end
               handle Timeout.TIMEOUT _ =>
                        (pr ("TACTIC_TIMEOUT " ^ nm ^ " " ^ Int.toString i ^ " after " ^ Int.toString secs ^ " s");
                         go (i + 1) ts)
                    | e => (pr ("TACTIC_ATTEMPT_FAILED " ^ nm ^ " " ^ Int.toString i ^ " " ^ short (General.exnMessage e));
                            go (i + 1) ts))
  in go 1 tacs end;
val SIZES = map fcpSyntax.mk_int_numeric_type [8, 16, 32, 64];
fun with_insts th =
  let val tvs = HOLset.listItems (HOLset.addList (Thm.hyp_tyvars th, type_vars_in_term (concl th)))
  in if null (hyp th) orelse null tvs then [th]
     else th :: map (fn ty => INST_TYPE (map (fn tv => tv |-> ty) tvs) th) SIZES end;
(* proved without hypotheses -> tag check, save_thm, PROVED; proved under ASSUMEd lemmas -> DIAG_OK_UNDER (not stored,
   counts as failure); failed -> ASSUME of the goal (not stored, counts as failure). Export is blocked by any failure. *)
fun lemmaL (_ : bool) name secs goal tacs =
  let val nm = sanitize name
      val _ = pr ("BEGIN " ^ nm ^ " REQUIRED cpu=" ^ Real.fmt (StringCvt.FIX (SOME 1)) (cpu_secs ()))
  in
    (let val th = attempt nm secs goal tacs
     in if null (hyp th) then (tags nm th; save_thm (nm, th); pr ("PROVED " ^ nm); [th])
        else (pr ("DIAG_OK_UNDER " ^ nm ^ " hypotheses=" ^ Int.toString (length (hyp th)));
              diag := nm :: !diag; req_fail := nm :: !req_fail; with_insts th)
     end)
    handle e => (pr ("LEMMA_FAILED " ^ nm ^ " " ^ short (General.exnMessage e));
                 (case tacs of t :: _ => show_left nm goal t | [] => ());
                 req_fail := nm :: !req_fail; with_insts (ASSUME goal))
  end;
fun lemma req name secs goal tacs = hd (lemmaL req name secs goal tacs);
fun note (_ : bool) nm = req_fail := nm :: !req_fail;
fun def name tm = let val th = new_definition (name, tm) in pr ("DEFINITION " ^ thm_to_string th); th end;
fun show name th = pr ("CHECKED " ^ name ^ " hyps " ^ Int.toString (length (hyp th)) ^ "\n" ^ thm_to_string th);


(* ======================= BEGIN COPY 1: ES-0002.sml lines 99-226 (W, S0 helpers) ======================= *)
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
(* ======================= END COPY 1; BEGIN COPY 2: ES-0002.sml lines 228-296 (def list, classifier, FRset) ======================= *)
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
(* ======================= END COPY 2 ======================= *)
(* A20: frame lemmas come from the stored EF-0001 theory (no frame engine here). *)
val _ = frames := List.mapPartial (fn (n, th) => if String.isPrefix "frame_" n then SOME th else NONE)
                    (DB.theorems "forge_m1bErasureFrame");
val _ = pr ("FRAME_LEMMAS_FROM_EF_0001 " ^ Int.toString (length (!frames)));
val W2 = word2_cases;
val PC_x = TRY (PairCases_on `x`);

(* ======================= BEGIN COPY 3: ES-0002.sml lines 331-349 (E1 goal builder, ERset) ======================= *)
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
(* ======================= END COPY 3 ======================= *)
(* A20 (H3): push-in normal form. erase moves inward to the initial state; value reads drop erase. *)
fun flip_if_erase_rhs th =
  let val t = SPEC_ALL th
      fun fl e = let val r = rhs (concl e) in
                   if is_comb r andalso same_const (rator r) erase_c then SYM e else e end
  in if is_imp (concl t) then
       let val a = fst (dest_imp (concl t)) val u = UNDISCH t in
         if is_conj (concl u) then map (fn c => GEN_ALL (DISCH a (fl c))) (CONJUNCTS u)
         else [GEN_ALL (DISCH a (fl u))] end
     else if is_conj (concl t) then map (GEN_ALL o fl) (CONJUNCTS t)
     else [GEN_ALL (fl t)]
  end handle _ => [];
val ER_PUSH = List.mapPartial (fn th => total (inst_rand erase_c) th) (boolTheory.COND_RAND :: case_rands);
val UPD_IN = map (fn c => GEN_ALL (SYM (SPEC_ALL c))) (CONJUNCTS erase_upds);
val CSA_IN = flip_if_erase_rhs CheckSPAlignment_erase;
val _ = pr ("RULE_COUNTS ER_PUSH " ^ Int.toString (length ER_PUSH) ^ " UPD_IN " ^ Int.toString (length UPD_IN) ^
            " CSA_IN " ^ Int.toString (length CSA_IN));
fun ER_IN () = [boolTheory.LET_THM, pairTheory.UNCURRY, pairTheory.pair_CASE_def, boolTheory.literal_case_THM,
                erase_reads, SCTLR_reads, fupd_PC_id] @ ER_PUSH @ UPD_IN @ CSA_IN @ ER_PAIR @
               List.concat (map flip_if_erase_rhs (!erasers));

(* A20: e_tacs = the three ES-0002 tactics, then (D1) an EL split, then (H3) push-in.
   A29: for the SP class, two strip-first tactics come FIRST (rpt strip_tac splits the disjunctive premise). *)
fun e_tacs d sp =
  let val pre = rpt gen_tac >> TRY (PairCases_on `x`) >> (if sp then DISCH_TAC else ALL_TAC)
      val pre_s = rpt gen_tac >> TRY (PairCases_on `x`) >> rpt strip_tac
      val old = [pre >> simp (d :: ERset ()),
                 pre >> simp (d :: ERset ()) >> BasicProvers.every_case_tac >> simp (ERset ()),
                 pre >> qspec_then `s.PSTATE.EL` strip_assume_tac W2 >> simp (d :: ERset ()),
                 pre >> simp (d :: ER_IN ()),
                 pre >> simp (d :: ER_IN ()) >> BasicProvers.every_case_tac >> simp (ER_IN ())]
  in if sp then [pre_s >> simp (d :: ERset ()),
                 pre_s >> simp (d :: ERset ()) >> BasicProvers.every_case_tac >> simp (ERset ())] @ old
     else old end;
(* A29 replay order: erase_write_SP used tactic 3 in EEx-0002 (stdout 191-194); it goes first, the rest keep order. *)
fun e_tacs_used cn d sp =
  let val ts = e_tacs d sp
  in if cn = "write'SP" then List.nth (ts, 2) :: (List.take (ts, 2) @ List.drop (ts, 3)) else ts end;
(* ======================= BEGIN COPY 4: ES-0002.sml lines 355-362 (class lists) ======================= *)
val e_excluded = ["SCTLR", "BranchTo", "CheckSPAlignment", "dfn'BranchConditional", "dfn'BranchImmediate",
                  "dfn'BranchRegister", "dfn'CompareAndBranch", "dfn'TestBitAndBranch", "Run", "Next"];
val sp_class = ["LoadStoreSingle", "dfn'LoadStoreImmediate", "dfn'LoadStoreRegister", "dfn'LoadStorePair",
                "dfn'LoadStoreAcquire", "dfn'LoadStoreAcquirePair"];
val e_required = ["raise'exception", "X", "write'X", "SP", "write'SP", "TranslationRegime", "Hint_Branch",
                  "CheckAlignment", "BigEndian", "Mem", "write'Mem", "ConditionHolds", "ExtendReg",
                  "LoadStoreSingle", "dfn'LoadStoreImmediate", "dfn'LoadStoreRegister"];
fun mem x l = List.exists (fn y => y = x) l;
(* ======================= END COPY 4 ======================= *)
fun getE0 cn = case List.find (fn (n, _) => n = cn) (!etab) of SOME (_, th) => th | NONE => TRUTH;

val _ = pr "MARK ERASE_ENGINE";
val _ = List.app (fn dname =>
    case lookup dname of
      NONE => ()
    | SOME (cn, c, d) =>
        if mem cn e_excluded then () else
        (case classify c of
           NONE => ()
         | SOME (hasArg, k) =>
             let val sp = mem cn sp_class
                 val ths = lemmaL true ("erase_" ^ cn) (secs_of cn) (e_goal c hasArg k sp) (e_tacs_used cn d sp)
             in erasers := ths @ !erasers; etab := (cn, hd ths) :: !etab end)) def_names;
(* ======================= BEGIN COPY 5: ES-0002.sml lines 376-377 and 379-423 (getE, branch class) ======================= *)
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
  (* A29 replay order: tactic 2 of EEx-0002 (TACTIC_USED 2, stdout 4222) first *)
  [rpt strip_tac >> `untagged (off + s.PC)` by metis_tac [wordsTheory.WORD_ADD_COMM] >>
     simp (dfn'BranchImmediate_def :: tbi_pc_untagged :: BRset ()) >> rpt IF_CASES_TAC >>
     simp (tbi_pc_untagged :: arm8_state_component_equality :: BRset ()),
   rpt strip_tac >> simp (dfn'BranchImmediate_def :: tbi_pc_untagged :: BRset ()) >> rpt IF_CASES_TAC >>
     simp (tbi_pc_untagged :: BRset ()),
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
(* ======================= END COPY 5 ======================= *)
(* ---------------- A20 Run lemmas: Cases_on `ast`, then one leaf per instruction (no metis) ---------------- *)
fun leafE () = FIRST (map (fn th => irule th >> simp [] >> NO_TAC) (!b1s) @ [simp (ERset ()) >> NO_TAC]);
fun leafP () = FIRST ([simp (ERset ()) >> NO_TAC] @ map (fn th => irule th >> simp [] >> NO_TAC) (!b2s));
(* A29: strip-first versions come first (EEx-0001: all 16 open leaves were the six SP-class instructions,
   stdout lines 6560-6624; under DISCH_TAC their conditional rewrites cannot fire). *)
fun run_tacs leaf =
  [rpt gen_tac >> rpt strip_tac >> Cases_on `ast` >> simp [Run_def] >> BasicProvers.every_case_tac >> leaf (),
   rpt gen_tac >> rpt strip_tac >> Cases_on `ast` >> simp [Run_def] >> TRY (leaf ()) >>
     BasicProvers.every_case_tac >> leaf (),
   rpt gen_tac >> DISCH_TAC >> Cases_on `ast` >> simp [Run_def] >> BasicProvers.every_case_tac >> leaf (),
   rpt gen_tac >> DISCH_TAC >> Cases_on `ast` >> simp [Run_def] >> TRY (leaf ()) >>
     BasicProvers.every_case_tac >> leaf ()];

(* ======================= BEGIN COPY 6: ES-0002.sml lines 475-480 (NX_def, leaf, RunE_text) ======================= *)
val NX_def = def "NX_def"
  ``NX (r:arm8_state) = if ~IS_SOME r.branch_hint then r with PC := r.PC + 4w else r``;
fun leaf tacs = FIRST (map (fn t => t >> NO_TAC) tacs);
val RunE_text =
  ``!ast s. s.PSTATE.EL = 0w /\ (~s.SCTLR_EL1.SA0 \/ aligned 4 s.SP_EL0) ==>
       arm8$Run ast (erase s) = erase ((arm8$Run ast s) with PC := (arm8$Run ast (erase s)).PC)``;
(* ======================= END COPY 6 ======================= *)
(* A20: Run lemmas with the ES-0002 statements (lines 478-480, 484-487) and the new tactics. *)
val RunE = lemma false "Run_erase_pc" 300 RunE_text (run_tacs leafE);
val RunPC = lemma false "Run_pc" 300
  ``!ast s. s.PSTATE.EL = 0w /\ (~s.SCTLR_EL1.SA0 \/ aligned 4 s.SP_EL0) ==>
       (arm8$Run ast s).PC = (arm8$Run ast (erase s)).PC \/
       (IS_SOME (arm8$Run ast s).branch_hint /\ (arm8$Run ast s).PC = tbi_pc s.TCR_EL1 (arm8$Run ast (erase s)).PC)``
  (run_tacs leafP);
(* ======================= BEGIN COPY 7: ES-0002.sml lines 490-560 (Next chain, NextStateARM8_erase) ======================= *)
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
(* ======================= END COPY 7 ======================= *)
(* ---------------- A20: end results and the untagged premises, as exact HOL text ---------------- *)
val _ = pr "MARK STATEMENTS";
fun stmt name tm = pr ("STATEMENT " ^ name ^ " typechecks " ^ Bool.toString (type_of tm = bool) ^
  " free_vars [" ^ String.concatWith ", " (map (fn v => fst (dest_var v) ^ ":" ^ type_to_string (type_of v)) (free_vars tm)) ^
  "]\n" ^ term_to_string tm);
fun stq name q = (stmt name (Parse.Term q); SOME (Parse.Term q))
                 handle e => (pr ("STATEMENT_ERROR " ^ name ^ " " ^ short (General.exnMessage e)); NONE);
val _ = stmt "NextStateARM8_erase (E1-0003 text)" NSE_text;
val _ = pr ("STATEMENT_RESULT NextStateARM8_erase hyps " ^ Int.toString (length (hyp NSE)) ^
            " concl_literal " ^ Bool.toString (aconv (concl NSE) NSE_text));
(* Next_erase: E1-0003 text has no SP premise. This route derives it only WITH the SP premise (Next_erase_sp). *)
val _ = stq "Next_erase (E1-0003 text; NOT derived here: no SP premise)"
  `s.PSTATE.EL = 0w /\ s.exception = NoException /\ (arm8$Next s).exception = NoException /\
   untagged (arm8$Next (erase s)).PC ==> arm8$Next (erase s) = erase (arm8$Next s)`;
val NEsp_text =
  ``s.PSTATE.EL = 0w /\ s.exception = NoException /\ (~s.SCTLR_EL1.SA0 \/ aligned 4 s.SP_EL0) /\
    (arm8$Next s).exception = NoException /\ untagged (arm8$Next (erase s)).PC ==>
    arm8$Next (erase s) = erase (arm8$Next s)``;
val _ = pr "STATEMENT_CHANGE Next_erase_sp = E1-0003 Next_erase plus the SP premise (~s.SCTLR_EL1.SA0 \\/ aligned 4 s.SP_EL0)";
val _ = pr "OLD_TEXT (E1-0003 Next_erase): s.PSTATE.EL = 0w /\\ s.exception = NoException /\\ (arm8$Next s).exception = NoException /\\ untagged (arm8$Next (erase s)).PC ==> arm8$Next (erase s) = erase (arm8$Next s)";
val _ = pr "NEW_TEXT (Next_erase_sp): s.PSTATE.EL = 0w /\\ s.exception = NoException /\\ (~s.SCTLR_EL1.SA0 \\/ aligned 4 s.SP_EL0) /\\ (arm8$Next s).exception = NoException /\\ untagged (arm8$Next (erase s)).PC ==> arm8$Next (erase s) = erase (arm8$Next s)";
val _ = pr "WHY: without the premise the equation is false when SA0 and ~aligned 4 SP_EL0 at an SP-based access (E1-0003 N2: the real state faults, the erased one does not)";
val _ = stmt "Next_erase_sp" NEsp_text;
val NEsp = lemma false "Next_erase_sp" 120 NEsp_text
  [rpt strip_tac >> `(arm8$Next s).PC = (arm8$Next (erase s)).PC` by metis_tac [NPC, tbi_pc_untagged] >>
     metis_tac [NE2],
   rpt strip_tac >> irule NE2 >> simp [] >> metis_tac [NPC, tbi_pc_untagged]];
val _ = show "Next_erase_sp" NEsp;
(* Untagged premises. Per-instruction (stored in ES-0002 as BranchImmediate_erase_untagged, BranchRegister_erase_untagged):
   direct branch target s.PC + off; indirect target X n s (BR, BLR, RET). A return address written by BL/BLR is data
   (X30 := PC + 4); it needs no premise when written, only when a later RET jumps to it (the next-PC premise then). *)
val _ = stq "U0_next_pc (premise of NextStateARM8_erase)" `!t. NextStateARM8 (erase s) = SOME t ==> untagged t.PC`;
val _ = stq "U0_next (premise of Next_erase_sp)" `untagged (arm8$Next (erase s)).PC`;
(* A29: U0 is literally a conjunct of the end-result premises *)
val _ = if List.exists (aconv ``!t. NextStateARM8 (erase s) = SOME t ==> untagged t.PC``)
             (strip_conj (fst (dest_imp NSE_text)))
        then pr "CONTROL_OK U0_next_pc is a literal premise of NextStateARM8_erase" else bad "U0-not-premise";
val _ = if List.exists (aconv ``untagged (arm8$Next (erase s)).PC``) (strip_conj (fst (dest_imp NEsp_text)))
        then pr "CONTROL_OK U0_next is a literal premise of Next_erase_sp" else bad "U0next-not-premise";
val _ = stq "U1_untagged_iff" `!a:word64. untagged a <=> a <+ 0x80000000000000w`;
val U1 = case stq "U1_untagged_iff_pv" `!a:word64. untagged a <=> a <+ 0x80000000000000w` of
    SOME tm => SOME (lemma false "U1_untagged_iff" 60 tm
                [rw [untagged_def] >> blastLib.BBLAST_TAC, simp [untagged_def] >> blastLib.BBLAST_TAC])
  | NONE => NONE;
val code_dm_def = (DB.fetch "forge_refundInstalledDomains" "refund_code_dm_def")
                  handle e => (pr ("NO_DEF refund_code_dm_def " ^ short (General.exnMessage e)); TRUTH);
val mem_dm_def = (DB.fetch "forge_refundInstalledDomains" "refund_mem_dm_def")
                  handle e => (pr ("NO_DEF refund_mem_dm_def " ^ short (General.exnMessage e)); TRUTH);
val bm_range = (DB.fetch "forge_refundInstalledDomains" "refund_bitmaps_dm_range")
                  handle e => (pr ("NO_THM refund_bitmaps_dm_range " ^ short (General.exnMessage e)); TRUTH);
val U2 = case stq "U2_code_dm_untagged" `!a. a IN refund_code_dm ==> untagged a` of
    SOME tm => SOME (lemma false "U2_code_dm_untagged" 60 tm
                [rw [code_dm_def, untagged_def] >> blastLib.FULL_BBLAST_TAC,
                 simp [code_dm_def, untagged_def] >> rpt strip_tac >> blastLib.FULL_BBLAST_TAC])
  | NONE => NONE;
val U3 = case stq "U3_mem_dm_untagged" `!h e a. a IN refund_mem_dm h e /\ e <=+ 0x80000000000000w ==> untagged a` of
    SOME tm => SOME (lemma false "U3_mem_dm_untagged" 90 tm
                [rw [mem_dm_def, code_dm_def, untagged_def] >> TRY (imp_res_tac bm_range) >>
                   blastLib.FULL_BBLAST_TAC,
                 rpt strip_tac >> fs [mem_dm_def, code_dm_def, untagged_def] >> TRY (imp_res_tac bm_range) >>
                   blastLib.FULL_BBLAST_TAC])
  | NONE => NONE;
val _ = case U2 of
    SOME u2 => (case stq "U4_next_pc_from_code_invariant"
                   `(!t. NextStateARM8 (erase s) = SOME t ==> t.PC IN refund_code_dm) ==>
                    (!t. NextStateARM8 (erase s) = SOME t ==> untagged t.PC)` of
                  SOME tm => ignore (lemma false "U4_next_pc_from_code_invariant" 60 tm [metis_tac [u2]])
                | NONE => ())
  | NONE => ();
(* For the refund run itself: refund_end_state fixes TBI0 = TBI1 = SA0 = F, and NextStateARM8_frame keeps them,
   so erase is the identity on every reachable state (interference oracle aside). *)
val tcr_ceq = DB.fetch "arm8" "TCR_EL1_component_equality" handle _ => (pr "NO_THM TCR_EL1_component_equality"; TRUTH);
val sct_ceq = DB.fetch "arm8" "SCTLRType_component_equality" handle _ => (pr "NO_THM SCTLRType_component_equality"; TRUTH);
val _ = case stq "U5_erase_identity"
          `!ms. ~ms.TCR_EL1.TBI0 /\ ~ms.TCR_EL1.TBI1 /\ ~ms.SCTLR_EL1.SA0 ==> erase ms = ms` of
    SOME tm => ignore (lemma false "U5_erase_identity" 60 tm
                [rw [erase_def, arm8_state_component_equality, tcr_ceq,
                     sct_ceq],
                 rpt strip_tac >> simp [erase_def, arm8_state_component_equality] >>
                   simp [tcr_ceq, sct_ceq]])
  | NONE => ();
val _ = (let val esd = DB.fetch "forge_refundInstalledDomains" "refund_end_state_def"
         in case stq "U6_refund_end_state_erase_identity" `!ms. refund_end_state ms ==> erase ms = ms` of
              SOME tm => ignore (lemma false "U6_refund_end_state_erase_identity" 60 tm
                [rw [esd, erase_def, arm8_state_component_equality, tcr_ceq,
                     sct_ceq]])
            | NONE => () end)
        handle e => pr ("U6_ERROR " ^ short (General.exnMessage e));

(* ================= A29: controls ================= *)
val _ = pr "MARK CONTROLS";
(* Literal checks of the end results. *)
val _ = if aconv (concl NSE) NSE_text andalso null (hyp NSE)
        then pr "CONTROL_OK NextStateARM8_erase is the literal E1-0003 statement, no hypotheses" else bad "NSE-literal";
val _ = if aconv (concl NEsp) NEsp_text andalso null (hyp NEsp)
        then pr "CONTROL_OK Next_erase_sp is the stated text, no hypotheses" else bad "NEsp-literal";
val _ = if aconv (concl W) W_text then pr "CONTROL_OK W is the requested statement" else bad "W-literal";
(* Negative controls: the parent theory E1-0003 PROVED them at the BranchTo / CheckSPAlignment level (stored there). *)
val _ = (show "N1a_tagged_branch_breaks (E1-0003, parent)" (DB.fetch "forge_m1bErasureV2" "N1a_tagged_branch_breaks");
         show "N2_misaligned_sp_breaks (E1-0003, parent)" (DB.fetch "forge_m1bErasureV2" "N2_misaligned_sp_breaks"))
        handle e => bad ("parent-controls-missing " ^ short (General.exnMessage e));
(* Lifting N1a / N2 to one full step (Next / NextStateARM8) needs Fetch and Decode of a concrete instruction from
   concrete memory: not a short forward step. NOT attempted. *)
val _ = pr "CONTROL_NOT_ATTEMPTED step-level N1a (no untagged premise) : needs a concrete Fetch/Decode; not a short step";
val _ = pr "CONTROL_NOT_ATTEMPTED step-level N2 (no SP premise) : needs a concrete Fetch/Decode; not a short step";

(* ================= Checks and export (EF-0001.sml text) ================= *)
val _ = pr "MARK CHECKS";
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
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

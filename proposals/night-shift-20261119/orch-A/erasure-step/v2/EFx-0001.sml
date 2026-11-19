(* EFx-0001.sml -- EXPLORATION run for case EF-0001 (worker A20, Night-Shift Orchestrator A), 2026-11-19.
   NOT RUN. NOT a proof attempt. Every tactic UNCHECKED. Marker EXPLORE_COMPLETE.
   Nothing is stored: no save_thm, no store_thm, no export_theory (scratch theory forge_m1bErasureFrameExplore).
   Lines between "BEGIN COPY" and "END COPY" are erasure_frame_v2.sml (the draft) word for word, so this run also
   dry-runs every v2 tactic; here lemma/lemmaL only print PROVED_NOT_STORED.
   Explorations (stepper copied from lout-explore/LOx-0001.sml PART 2, which compiled and ran):
     P1 DEF_TEXT / ARB_IN_DEF for write'SP, BranchTo, LoadStoreSingle, dfn'LoadStorePair, Run (tests diagnosis D1).
     P2 TYVAR_PROBE: ASSUMEd polymorphic frame_write_SP vs. its word64 instance (tests diagnosis D2).
     X1..X5 step-by-step goals for frame_write_SP, frame_BranchTo, frame_LoadStoreSingle, frame_dfn_LoadStorePair,
     frame_Run, each run just before the engine tries that lemma (so earlier frame lemmas are in FRset).
   Read: grep -n "^EXPLORE_\|^STEP\|^ALT_\|^VALIDATION\|^DEF_TEXT\|^ARB_IN_DEF\|^TYVAR_PROBE\|^PROVED_NOT_STORED\|^DIAG_OK_UNDER\|^LEMMA_FAILED\|^LEFT_GOALS" *)
open HolKernel boolLib bossLib wordsLib blastLib
     wordsTheory arm8Theory arm8_stepTheory targetSemTheory arm8_targetTheory alignmentTheory
     forge_m1bErasureV2Theory;
val _ = Globals.max_print_depth := 30;
fun pr s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut);
val _ = (load "Timeout"; pr "TIMEOUT_HELPER Timeout.apply loaded")
  handle e => (pr ("TIMEOUT_LOAD_FAILED " ^ General.exnMessage e); raise e);
fun short s = String.substring (s, 0, Int.min (400, size s));
fun trunc n s = if size s <= n then s else String.substring (s, 0, n) ^ " ...";
val cpu0 = Timer.startCPUTimer ();
fun cpu_secs () = let val {usr, sys} = Timer.checkCPUTimer cpu0 in Time.toReal usr + Time.toReal sys end;
val ALL_BUDGET = 700.0;      (* script CPU for proofs; RUN_PLAN process limit 900 s incl. about 110 s of loading *)
val EXPLORE_BUDGET = 600.0;  (* script CPU after which explorations are skipped (EXPLORE_SKIPPED_BUDGET) *)
val _ = metisTools.limit := {time = SOME 20.0, infs = NONE};
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val THY = "forge_m1bErasureFrameExplore";
val _ = new_theory THY;
val _ = pr "EXPLORE_MODE nothing is stored or exported";

(* ---------------- harness (v2 harness, storing removed) ---------------- *)
val req_fail = ref ([] : string list);
val diag = ref ([] : string list);
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
            if cpu_secs () > ALL_BUDGET then raise Fail "script budget exhausted"
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
(* hook: called with the lemma name and goal before the lemma is tried (explorations X1..X5 attach here) *)
val hook = ref (fn (_ : string) => fn (_ : term) => ());
fun lemmaL name secs goal tacs =
  let val nm = String.translate (fn #"'" => "_" | c => String.str c) name
      val _ = (!hook) nm goal handle e => pr ("HOOK_ERROR " ^ nm ^ " " ^ short (General.exnMessage e))
      val _ = pr ("BEGIN " ^ nm ^ " cpu=" ^ Real.fmt (StringCvt.FIX (SOME 1)) (cpu_secs ()))
  in
    (let val th = attempt nm secs goal tacs
     in if null (hyp th) then (pr ("PROVED_NOT_STORED " ^ nm); [th])
        else (pr ("DIAG_OK_UNDER " ^ nm ^ " hypotheses=" ^ Int.toString (length (hyp th)));
              diag := nm :: !diag; req_fail := nm :: !req_fail; with_insts th)
     end)
    handle e => (pr ("LEMMA_FAILED " ^ nm ^ " " ^ short (General.exnMessage e));
                 (case tacs of t :: _ => show_left nm goal t | [] => ());
                 req_fail := nm :: !req_fail; with_insts (ASSUME goal))
  end;
fun lemma name secs goal tacs = hd (lemmaL name secs goal tacs);
fun show name th = pr ("CHECKED_NOT_STORED " ^ name ^ " hyps " ^ Int.toString (length (hyp th)) ^ "\n" ^ thm_to_string th);

(* ---------------- stepper (LOx-0001.sml PART 2, bounded printing) ---------------- *)
val STEP_SECS = 90;
type step = string * tactic * tactic list;
fun show_goal (lemma : string) (k : int) ((asl, w) : goal) (full : bool) : unit =
  if not full then pr ("  GOAL_SHORT " ^ lemma ^ " #" ^ Int.toString k ^ " " ^ trunc 300 (term_to_string w))
  else
  let
    fun asm_loop _ [] = ()
      | asm_loop j (a :: rest) =
          (if j < 10 then pr ("    ASM " ^ Int.toString j ^ " " ^ trunc 600 (term_to_string a)) else ();
           asm_loop (j + 1) rest)
  in
    pr ("  GOAL_BEGIN " ^ lemma ^ " #" ^ Int.toString k ^ " assumptions " ^ Int.toString (length asl) ^
        " (ASM 0 = newest)");
    asm_loop 0 asl;
    pr ("    CONCL " ^ trunc 4000 (term_to_string w));
    pr ("  GOAL_END " ^ lemma ^ " #" ^ Int.toString k)
  end;
fun show_goals (lemma : string) (gs : goal list) : unit =
  let
    fun loop _ [] = ()
      | loop k (g :: rest) = if k > 40 then pr ("  GOALS_NOT_SHOWN " ^ Int.toString (length rest + 1))
                             else (show_goal lemma k g (k <= 4); loop (k + 1) rest)
  in
    pr ("  GOAL_COUNT " ^ Int.toString (length gs));
    loop 1 gs
  end;
fun prefix_of (ts : tactic list) : tactic = List.foldl (fn (t, acc) => acc >> t) ALL_TAC ts;
fun run_ts (ts : tactic list) (g : goal) : goal list * (thm list -> thm) =
  let val ctxt = Context.snapshot ()
  in Timeout.apply (Time.fromSeconds (Int.toLarge STEP_SECS)) (fn () => prefix_of ts g ctxt) () end;
fun check_validation (lemma : string) (gt : term) (v : thm list -> thm) : unit =
  (let val th = v [] in
     pr ("VALIDATION " ^ lemma ^ " concl_aconv_goal " ^ Bool.toString (aconv (concl th) gt) ^
         " hyps " ^ Int.toString (length (hyp th)))
   end)
  handle e => pr ("VALIDATION_FAILED " ^ lemma ^ " " ^ trunc 600 (General.exnMessage e));
fun explore0 (lemma : string) (gt : term) (steps : step list) : unit =
  let
    val g0 : goal = ([], gt)
    fun attempt1 (ts : tactic list) : (goal list * (thm list -> thm)) option * string =
      (SOME (run_ts ts g0), "")
      handle Timeout.TIMEOUT _ => (NONE, "TIMEOUT after " ^ Int.toString STEP_SECS ^ " s")
           | e => (NONE, General.exnMessage e)
    fun finish (n : int) (gs : goal list) (v : thm list -> thm) : unit =
      if null gs then
        (pr ("EXPLORE_CLOSED " ^ lemma ^ " after_steps " ^ Int.toString n);
         check_validation lemma gt v)
      else pr ("EXPLORE_OPEN " ^ lemma ^ " goals " ^ Int.toString (length gs))
    fun loop (i : int) (chosen : tactic list) (gs : goal list) (v : thm list -> thm) (rest : step list) : unit =
      case rest of
        [] => finish (i - 1) gs v
      | ((label, tac, alts) :: more) =>
          if cpu_secs () > EXPLORE_BUDGET then pr ("EXPLORE_SKIPPED_BUDGET " ^ lemma ^ " at step " ^ Int.toString i)
          else
          (case attempt1 (chosen @ [tac]) of
             (SOME (gs1, v1), _) =>
               (pr ("STEP " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " goals " ^ Int.toString (length gs1) ^
                    " cpu=" ^ Real.fmt (StringCvt.FIX (SOME 1)) (cpu_secs ()));
                show_goals lemma gs1;
                loop (i + 1) (chosen @ [tac]) gs1 v1 more)
           | (NONE, msg) =>
               (pr ("STEP_FAILED " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " " ^ trunc 800 msg);
                pr ("GOALS_BEFORE_STEP " ^ lemma ^ " " ^ Int.toString i ^ " count " ^ Int.toString (length gs));
                alt_loop i label chosen more 1 alts))
    and alt_loop (i : int) (label : string) (chosen : tactic list) (more : step list) (k : int)
                 (alts : tactic list) : unit =
      case alts of
        [] => pr ("STEP_STUCK " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label)
      | (a :: others) =>
          (case attempt1 (chosen @ [a]) of
             (SOME (gs1, v1), _) =>
               (pr ("ALT_WORKS " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " alt " ^ Int.toString k);
                pr ("STEP " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " goals " ^ Int.toString (length gs1) ^
                    " (alt " ^ Int.toString k ^ ")");
                show_goals lemma gs1;
                loop (i + 1) (chosen @ [a]) gs1 v1 more)
           | (NONE, msg) =>
               (pr ("ALT_FAILED " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " alt " ^ Int.toString k ^ " " ^
                    trunc 800 msg);
                alt_loop i label chosen more (k + 1) others))
    val v0 = (fn (_ : thm list) => raise mk_HOL_ERR "EFx" "explore" "no step was run") : thm list -> thm
  in
    pr ("EXPLORE_BEGIN " ^ lemma ^ " steps " ^ Int.toString (length steps));
    show_goals lemma [g0];
    loop 1 [] [g0] v0 steps;
    pr ("EXPLORE_END " ^ lemma)
  end;
fun explore (lemma : string) (gt : term) (stepsf : unit -> step list) : unit =
  explore0 lemma gt (stepsf ())
  handle e => pr ("EXPLORE_ERROR " ^ lemma ^ " " ^ trunc 800 (General.exnMessage e));

(* ======================= BEGIN COPY (erasure_frame_v2.sml, from MARK W to frame_tacs) ======================= *)
(* ================= W. Non-vacuity witness (ES-0002 tactic 1, PASSED: ES-0002/stdout.log 6-9) ================= *)
val _ = pr "MARK W";
val W_text = ``?s t. arm8_ok (erase s) /\ s.TCR_EL1.TBI0 /\ s.SCTLR_EL1.SA0 /\ untagged t /\ s.PSTATE.EL = 0w``;
val W = lemma "W_nonvacuous" 60 W_text
  [qexists_tac `(ARB:arm8_state) with <| PSTATE := ((ARB:ProcState) with EL := 0w);
                  SCTLR_EL1 := ((ARB:SCTLRType) with <| SA0 := T; E0E := F |>);
                  TCR_EL1 := ((ARB:TCR_EL1) with TBI0 := T); exception := NoException; PC := 0w |>` >>
     qexists_tac `0w` >> simp [arm8_ok_erase, untagged_def] >> EVAL_TAC,
   qexists_tac `(ARB:arm8_state) with <| PSTATE := ((ARB:ProcState) with EL := 0w);
                  SCTLR_EL1 := ((ARB:SCTLRType) with <| SA0 := T; E0E := F |>);
                  TCR_EL1 := ((ARB:TCR_EL1) with TBI0 := T); exception := NoException; PC := 0w |>` >>
     qexists_tac `0w` >> rw [arm8_ok_erase, untagged_def, alignmentTheory.aligned_0]];
val _ = show "W_nonvacuous" W;

(* ================= S0. Helpers (ES-0002 text; all PROVED there, stdout 18-37) ================= *)
val _ = pr "MARK S0";
val st_ty = ``:arm8_state``;
val s_v = mk_var ("s", st_ty);
val TCRsel = rator ``(s:arm8_state).TCR_EL1``;
val SCsel  = rator ``(s:arm8_state).SCTLR_EL1``;
val PSsel  = rator ``(s:arm8_state).PSTATE``;
val ELsel  = rator ``(p:ProcState).EL``;
val SNDsel = ``SND : 'p # 'q -> 'q``;
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
val _ = pr ("RULE_COUNTS FR_RAND " ^ Int.toString (length FR_RAND));
fun for_tacs pre extra =
  [pre >> recInduct state_transformerTheory.FOR_ind >> rpt strip_tac >>
     once_rewrite_tac [state_transformerTheory.FOR_def] >> Cases_on `i = j` >>
     asm_simp_tac (srw_ss()) ([state_transformerTheory.BIND_DEF, pairTheory.UNCURRY, combinTheory.o_THM] @ extra),
   pre >> ho_match_mp_tac state_transformerTheory.FOR_ind >> rpt strip_tac >>
     once_rewrite_tac [state_transformerTheory.FOR_def] >> Cases_on `i = j` >>
     asm_simp_tac (srw_ss()) ([state_transformerTheory.BIND_DEF, pairTheory.UNCURRY, combinTheory.o_THM] @ extra) >>
     metis_tac []];
val FOR_proj = lemma "FOR_proj" 60
  ``!(p:'s -> 'b) i j (a:num -> 's -> unit # 's).
      (!k s. p (SND (a k s)) = p s) ==> !s. p (SND (state_transformer$FOR (i,j,a) s)) = p s``
  (for_tacs gen_tac []);
val FOR_snd_const = lemma "FOR_snd_const" 60
  ``!i j (a:num -> 'x # 's -> unit # ('x # 's)).
      (!k x. SND (SND (a k x)) = SND x) ==> !x. SND (SND (state_transformer$FOR (i,j,a) x)) = SND x``
  (for_tacs ALL_TAC []);
val FOR_proj_inst = List.mapPartial (fn sel => total (ISPEC sel) FOR_proj) [TCRsel, SCsel, PSsel];
val Mem_state = lemma "Mem_state" 90
  ``!a n acc s. SND (arm8$Mem (a, n, acc) s : 'N word # arm8_state) = CheckAlignment (a, n, acc, F) s``
  [rpt gen_tac >> simp [Mem_def, boolTheory.LET_THM, pairTheory.UNCURRY, FOR_snd_const],
   rpt gen_tac >> rw [Mem_def, boolTheory.LET_THM, pairTheory.UNCURRY] >> simp [FOR_snd_const]];
(* R1: every 2-bit word is one of the four literals (PSTATE.EL : word2). *)
val W2 = lemma "word2_cases" 60 ``!w:2 word. w = 0w \/ w = 1w \/ w = 2w \/ w = 3w``
  [wordsLib.Cases_word_value >> simp [],
   wordsLib.Cases_word_value >> EVAL_TAC,
   blastLib.BBLAST_TAC];

(* ================= F. Frame lemmas, generated per definition (ES-0002 generator) ================= *)
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
val _ = pr ("DEF_NAMES " ^ Int.toString (length def_names));
datatype kind = ST | PR | RD;
fun occ ty = ty = st_ty orelse (not (is_vartype ty) andalso List.exists occ (snd (dest_type ty)));
fun is_pair_st ty = not (is_vartype ty) andalso
  (case dest_type ty of ("prod", [a, b]) => b = st_ty andalso not (occ a) | _ => false);
fun res_kind r = if r = st_ty then SOME ST else if is_pair_st r then SOME PR else if occ r then NONE else SOME RD;
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
fun secs_of cn = if cn = "Run" then 240
                 else if List.exists (fn b => b = cn) ["dfn'LoadStorePair", "dfn'LoadStoreAcquire",
                        "dfn'LoadStoreAcquirePair", "LoadStoreSingle", "Mem", "write'Mem"] then 150 else 60;
val frames = ref ([] : thm list);
fun FRset () = [boolTheory.LET_THM, pairTheory.UNCURRY, pairTheory.pair_CASE_def, boolTheory.literal_case_THM,
                FOR_proj, FOR_snd_const, Mem_state] @ FOR_proj_inst @ FR_RAND @ !frames;
val PC_x = TRY (PairCases_on `x`);
(* generic (ES-0002 frame_tacs; tactic 1 or 2 passed for 56 definitions) *)
fun generic d =
  [rpt gen_tac >> PC_x >> simp (d :: FRset ()),
   rpt gen_tac >> PC_x >> simp (d :: FRset ()) >> BasicProvers.every_case_tac >> simp (FRset ())];
(* R1: split on the exception level first; each of the four cases selects one literal row, the ARB row is unreachable *)
fun el_split d =
  [rpt gen_tac >> PC_x >> qspec_then `s.PSTATE.EL` strip_assume_tac W2 >>
     simp (d :: Hint_Branch_def :: FRset ()),
   rpt gen_tac >> PC_x >> simp (d :: Hint_Branch_def :: FRset ()) >> BasicProvers.every_case_tac >>
     simp (FRset ()) >> metis_tac [W2],
   rpt gen_tac >> PC_x >> qspec_then `s.PSTATE.EL` strip_assume_tac W2 >>
     simp (d :: Hint_Branch_def :: FRset ()) >> BasicProvers.every_case_tac >> simp (FRset ()) >> EVAL_TAC];
(* R3: Run. Unfold, split the instruction case, then every branch is one dfn' frame lemma. *)
fun run_tacs d =
  [rpt gen_tac >> simp (d :: FRset ()),
   rpt gen_tac >> simp [d] >> BasicProvers.every_case_tac >> simp (FRset ()),
   rpt gen_tac >> Cases_on `x` >> simp [d] >> BasicProvers.every_case_tac >> simp (FRset ())];
fun frame_tacs cn d =
  if cn = "write'SP" orelse cn = "BranchTo" then el_split d @ generic d
  else if cn = "Run" then run_tacs d
  else if cn = "LoadStoreSingle" orelse cn = "dfn'LoadStorePair" then
    generic d @ [rpt gen_tac >> PC_x >> simp [d, boolTheory.LET_THM, pairTheory.UNCURRY] >>
                   BasicProvers.every_case_tac >> simp (FRset ())]
  else generic d @ [rpt gen_tac >> PC_x >> simp [d] >> BasicProvers.every_case_tac >> simp (FRset ())];
(* ======================= END COPY part A ======================= *)

(* ---------------- P1. definition shape (diagnosis D1: an ARB row from the word-literal case) ---------------- *)
val _ = pr "MARK PROBES";
val _ = List.app (fn (n, d) =>
  (pr ("ARB_IN_DEF " ^ n ^ " " ^ Bool.toString (can (find_term is_arb) (concl d)));
   pr ("LITERAL_CASE_IN_DEF " ^ n ^ " " ^
       Bool.toString (can (find_term (fn t => is_const t andalso fst (dest_const t) = "literal_case")) (concl d)));
   pr ("DEF_TEXT " ^ n ^ "\n" ^ trunc (if n = "Run" then 2500 else 6000) (thm_to_string d)))
  handle e => pr ("DEF_PROBE_ERROR " ^ n ^ " " ^ short (General.exnMessage e)))
  [("write'SP", write'SP_def), ("BranchTo", BranchTo_def), ("LoadStoreSingle", LoadStoreSingle_def),
   ("dfn'LoadStorePair", dfn'LoadStorePair_def), ("Run", Run_def)];

(* ---------------- P2. type variables in hypotheses (diagnosis D2) ----------------
   Expected if D2 holds: poly_assume closes false, inst64_assume closes true. *)
val _ = (let
    val c = prim_mk_const {Thy = "arm8", Name = "write'SP"}
    val gpoly = frame_goal c true ST
    val tvs = type_vars_in_term gpoly
    val g64 = Term.inst (map (fn tv => tv |-> fcpSyntax.mk_int_numeric_type 64) tvs) gpoly
    fun closes g ths = (Timeout.apply (Time.fromSeconds (Int.toLarge 30)) Tactical.TAC_PROOF
                          (([], g), rpt gen_tac >> simp ths); true) handle _ => false
    val A = ASSUME gpoly
  in
    pr ("TYVAR_PROBE goal_tyvars " ^ Int.toString (length tvs) ^ " " ^ trunc 300 (term_to_string g64));
    pr ("TYVAR_PROBE poly_assume closes " ^ Bool.toString (closes g64 [A]));
    pr ("TYVAR_PROBE inst64_assume closes " ^
        Bool.toString (closes g64 [INST_TYPE (map (fn tv => tv |-> fcpSyntax.mk_int_numeric_type 64) tvs) A]));
    pr ("TYVAR_PROBE with_insts closes " ^ Bool.toString (closes g64 (with_insts A)))
  end) handle e => pr ("TYVAR_PROBE_ERROR " ^ short (General.exnMessage e));

(* ---------------- X1..X5. explorations, attached to the engine through the hook ---------------- *)
fun x_el nm g d =
  (explore (nm ^ "/A_generic_steps") g (fn () =>
     [("gen", rpt gen_tac >> PC_x, []),
      ("unfold_def_only", simp [d], [rw [d]]),
      ("frset", simp (Hint_Branch_def :: FRset ()), []),
      ("case_split", BasicProvers.every_case_tac, [rpt IF_CASES_TAC]),
      ("simp_after_split", simp (FRset ()), []),
      ("w2_contradiction", metis_tac [W2], [CCONTR_TAC >> fs [] >> metis_tac [W2]])]);
   explore (nm ^ "/B_el_split_first") g (fn () =>
     [("gen", rpt gen_tac >> PC_x, []),
      ("w2_split", qspec_then `s.PSTATE.EL` strip_assume_tac W2, [Cases_on `s.PSTATE.EL = 0w`]),
      ("simp", simp (d :: Hint_Branch_def :: FRset ()), [fs (d :: Hint_Branch_def :: FRset ())]),
      ("eval_rest", EVAL_TAC, [])]);
   explore (nm ^ "/C_word_value") g (fn () =>
     [("gen", rpt gen_tac >> PC_x, []),
      ("cases_word_value", wordsLib.Cases_on_word_value `s.PSTATE.EL`, []),
      ("simp", simp (d :: Hint_Branch_def :: FRset ()), [])]));
fun x_ls nm g d =
  (pr ("FAILED_SO_FAR " ^ String.concatWith " " (rev (!req_fail)));
   explore (nm ^ "/B_generic1") g (fn () => [("generic1", hd (generic d), [])]);
   explore (nm ^ "/A_steps") g (fn () =>
     [("gen", rpt gen_tac >> PC_x, []),
      ("unfold", simp [d, boolTheory.LET_THM, pairTheory.UNCURRY], []),
      ("frset", simp (FRset ()), []),
      ("case_split", BasicProvers.every_case_tac, []),
      ("simp2", simp (FRset ()), [])]));
fun x_run nm g d =
  (pr ("FAILED_SO_FAR " ^ String.concatWith " " (rev (!req_fail)));
   explore (nm ^ "/B_generic1") g (fn () => [("generic1", rpt gen_tac >> simp (d :: FRset ()), [])]);
   explore (nm ^ "/A_steps") g (fn () =>
     [("gen", rpt gen_tac, []),
      ("unfold_run", simp [d], []),
      ("case_split", BasicProvers.every_case_tac, []),
      ("frames", simp (FRset ()), [])]);
   explore (nm ^ "/C_cases_x") g (fn () =>
     [("gen", rpt gen_tac, []),
      ("cases_x", Cases_on `x`, []),
      ("simp", simp (d :: FRset ()), []),
      ("split", BasicProvers.every_case_tac, []),
      ("simp2", simp (FRset ()), [])]));
val _ = hook := (fn nm => fn g =>
  if not (List.exists (fn n => n = nm) ["frame_write_SP", "frame_BranchTo", "frame_LoadStoreSingle",
                                        "frame_dfn_LoadStorePair", "frame_Run"]) then ()
  else if cpu_secs () > EXPLORE_BUDGET then pr ("EXPLORE_SKIPPED_BUDGET " ^ nm)
  else if nm = "frame_write_SP" then x_el nm g write'SP_def
  else if nm = "frame_BranchTo" then x_el nm g BranchTo_def
  else if nm = "frame_LoadStoreSingle" then x_ls nm g LoadStoreSingle_def
  else if nm = "frame_dfn_LoadStorePair" then x_ls nm g dfn'LoadStorePair_def
  else x_run nm g Run_def);

(* ======================= BEGIN COPY part B (erasure_frame_v2.sml, engine through NextStateARM8_frame) ======================= *)
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
           let val ths = lemmaL ("frame_" ^ cn) (secs_of cn) (frame_goal c hasArg k) (frame_tacs cn d)
           in frames := ths @ !frames; n_frame := !n_frame + 1 end)) def_names;
val _ = pr ("FRAME_LEMMAS " ^ Int.toString (!n_frame));
(* Next: the E1-0003 statement, word for word (E1-0003/proof.sml lines 226-227). *)
val NF_text = ``(arm8$Next s).TCR_EL1 = s.TCR_EL1 /\ (arm8$Next s).SCTLR_EL1 = s.SCTLR_EL1 /\ (arm8$Next s).PSTATE.EL = s.PSTATE.EL``;
val NFA = lemma "Next_frame_all" 150 (list_mk_forall ([s_v], NF_text))
  [gen_tac >> simp (Next_def :: FRset ()),
   gen_tac >> simp (Next_def :: FRset ()) >> BasicProvers.every_case_tac >> simp (FRset ()),
   gen_tac >> rw (Next_def :: FRset ())];
val NF = lemma "Next_frame" 60 NF_text [simp [NFA], metis_tac [NFA]];
val _ = show "Next_frame" NF;
val NSF = lemma "NextStateARM8_frame" 60
  ``!s t. NextStateARM8 s = SOME t ==>
          t.TCR_EL1 = s.TCR_EL1 /\ t.SCTLR_EL1 = s.SCTLR_EL1 /\ t.PSTATE.EL = s.PSTATE.EL``
  [rpt gen_tac >> simp [NextStateARM8_def, boolTheory.LET_THM] >> rw [] >> simp [NFA],
   rpt gen_tac >> rw [NextStateARM8_def, boolTheory.LET_THM] >> simp [NFA],
   rpt strip_tac >> qpat_x_assum `NextStateARM8 _ = _` mp_tac >> simp [NextStateARM8_def, boolTheory.LET_THM] >>
     rw [] >> metis_tac [NFA]];
val _ = show "NextStateARM8_frame" NSF;

(* ================= Controls (structural, cheap) ================= *)
(* ======================= END COPY part B ======================= *)
val _ = pr "MARK SUMMARY";
val _ = pr ("W_STATEMENT_LITERAL " ^ Bool.toString (aconv (concl W) W_text) ^ " hyps " ^ Int.toString (length (hyp W)));
val _ = pr ("NF_STATEMENT_LITERAL " ^ Bool.toString (aconv (concl NF) NF_text) ^ " hyps " ^ Int.toString (length (hyp NF)));
val _ = pr ("NSF_HYPS " ^ Int.toString (length (hyp NSF)));
val _ = List.app (fn n => pr ("DIAG_OK_UNDER_LIST " ^ n)) (rev (!diag));
val _ = pr ("WOULD_FAIL_LIST " ^ String.concatWith " " (rev (!req_fail)));
val _ = pr ("CPU_SECONDS_SCRIPT " ^ Real.fmt (StringCvt.FIX (SOME 1)) (cpu_secs ()));
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems THY)));
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

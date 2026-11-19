(* erasure_frame_v2.sml -- worker A20 (Night-Shift Orchestrator A), 2026-11-19. Case EF-0001. DRAFT.
   NOT RUN. NOT TYPE-CHECKED BY HOL. Every tactic is UNCHECKED. Finalise only after the EFx-0001 exploration log.
   Pass = actual exit 0, marker EXACT_COMPLETE, no REQUIRED_FAILED_LIST line, no UNEXPECTED_CONTROL_ACCEPTANCE,
   exactly four CLOSURE_AXIOM lines, and PROVED lines for W_nonvacuous, Next_frame, NextStateARM8_frame.

   Base: ES-0002.sml (SHA-256 7c0c3c51...a7e5; compiled and ran: actual exit 1, ES-0002/stdout.log). Kept from it,
   unchanged in text: header opens, harness shape, W statement and its PASSED tactic (stdout 6-9), S0 helpers FOR_proj,
   FOR_snd_const, Mem_state (stdout 18-37, all PROVED), the frame-goal generator, Next_frame / NextStateARM8_frame
   statements and tactics (stdout 363-376: closed, DIAG only under frame_Run). Dropped: every erase lemma, E2, C1/C2,
   E3, deferred statements (nothing optional).
   Changes (A20):
   R1  word2_cases helper; write'SP and BranchTo first split on s.PSTATE.EL (diagnosis D1: the L3 word-literal
       case over EL compiles to a literal_case chain whose missing default row is ARB; the generic simp leaves
       ARB.TCR_EL1 = s.TCR_EL1 under EL <> 0w,1w,2w,3w).
   R2  fallback: a failed or DIAG lemma enters the rewrite set also at the type instances 'N := 8,16,32,64
       (diagnosis D2: HO_PART_MATCH never instantiates a type variable that occurs in a hypothesis,
       HOL/src/1/Conv.sml:39 comment, HOL/src/1/Drule.sml:1456-1462; so ASSUMEd write'SP at 'N could not rewrite
       write'SP at word64 in LoadStoreSingle / dfn'LoadStorePair, and every DIAG dfn lemma could not rewrite at
       @32/@64 in Run: a cascade, not 3 independent defects).
   R3  extra alternatives for LoadStoreSingle, dfn'LoadStorePair, Run (every_case_tac; Cases_on the instruction).
   R4  on failure, print the goals left by alternative 1 (bounded), then ASSUME (never stored; export blocked).
   Parent: forge_m1bErasureV2 (E1-0003), loaded through deps-ES.txt (127 lines). *)
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
val ALL_BUDGET = 420.0;   (* script CPU; RUN_PLAN process limit 600 s incl. about 110 s of loading *)
val _ = metisTools.limit := {time = SOME 20.0, infs = NONE};
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val THY = "forge_m1bErasureFrame";
val _ = new_theory THY;

(* ---------------- harness ---------------- *)
val req_fail = ref ([] : string list);
val diag = ref ([] : string list);
val problems = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun tags name th = let val (ors, axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun sanitize n = String.translate (fn #"'" => "_" | c => String.str c) n;
(* R4: print the goals that tactic t leaves (at most 3, bounded text). Type tactic = goal -> Context.t -> ... *)
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
(* R2: a theorem with hypotheses enters later rewrite sets also at fixed word-size instances of its type variables,
   because the simplifier cannot instantiate a type variable that occurs in a hypothesis. *)
val SIZES = map fcpSyntax.mk_int_numeric_type [8, 16, 32, 64];
fun with_insts th =
  let val tvs = HOLset.listItems (HOLset.addList (Thm.hyp_tyvars th, type_vars_in_term (concl th)))
  in if null (hyp th) orelse null tvs then [th]
     else th :: map (fn ty => INST_TYPE (map (fn tv => tv |-> ty) tvs) th) SIZES end;
(* lemma: proved -> stored (list of one); proved under ASSUMEd lemmas -> DIAG_OK_UNDER (not stored);
   failed -> ASSUME of the goal. Both non-stored cases return with_insts. *)
fun lemmaL name secs goal tacs =
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
fun lemma name secs goal tacs = hd (lemmaL name secs goal tacs);
fun show name th = pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th);

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
val _ = pr "MARK CONTROLS";
val _ = if aconv (concl NF) NF_text then pr "CONTROL_OK Next_frame is the literal E1-0003 statement" else bad "NF-literal";
val _ = if aconv (concl W) W_text then pr "CONTROL_OK W is the requested statement" else bad "W-literal";
val _ = if null (hyp W) andalso null (hyp NF) andalso null (hyp NSF)
        then pr "CONTROL_OK W, Next_frame, NextStateARM8_frame have no hypotheses" else bad "required-hyps";
val _ = if List.exists (fn (n, _) => n = "frame_Run") (DB.theorems THY) then pr "CONTROL_OK frame_Run stored"
        else bad "frame_Run-not-stored";

(* ================= Checks and export ================= *)
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
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

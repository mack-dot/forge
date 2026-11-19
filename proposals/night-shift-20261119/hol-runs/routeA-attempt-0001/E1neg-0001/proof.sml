(* erasure_v2.sml -- worker A5 (Night-Shift Orchestrator A), 2026-11-19. Repair of erasure_DRAFT.sml (Z2, sha256 166aefd0...8c37).
   NOT RUN. NOT TYPE-CHECKED BY HOL. Every tactic is UNCHECKED. Nothing here is a result until a run ends with exit 0,
   the marker EXACT_COMPLETE, no LEMMA_FAILED, no UNEXPECTED_CONTROL_ACCEPTANCE, and four CLOSURE_AXIOM lines.

   What changed against the draft (details: REPORT.md section C, and erasure_v2.diff):
   (E1) The draft is not runnable as a file: seven lemmas end in NO_TAC, so store_thm raises at Next_frame and nothing after
        it (all controls) runs, and export_theory is never reached. v2 keeps only lemmas with a closing tactic.
        The deferred statements are PARSED and TYPE-CHECKED only (section 5, "STATEMENT_TYPECHECKS"); nothing is assumed.
   (E2) Run harness of the M1 cases: chDir FORGE_P3_OUT, fail-closed `thm`, tag check, closure-axiom check, EXACT_COMPLETE.
   (E3) New central lemma BranchTo_EL0_pc (BranchTo at EL0 = hint + PC := tbi_pc TCR t) and new definition tbi_pc
        (the PC formula of arm8Script.sml 548-563, written out). The BranchTo lemmas and controls N1a, N1b, P1 now go
        through it, so the BranchTo unfolding happens once. tbi_pc is a new name; no draft statement changed.
   (E4) New helper untagged_bits (word facts of untagged). Tactic alternatives via thmA (first success is used and printed).
   (E5) Theory name forge_m1bErasureV2 (the draft's forge_m1bErasureDraft is kept free for the draft itself).
   (E6) BranchTo_erase_iff is OPTIONAL: its failure is printed as OPTIONAL_FAILED and does not fail the run (it is a
        report lemma, not used by anything). Every other lemma is REQUIRED.
   Statements of the draft that are kept (word for word, apart from the theory): erase_def, bits_of_def, restore_def,
   untagged_def, erase_fields, restore_erase, erase_restore, arm8_ok_erase, BranchTo_erase_untagged, BranchTo_erase_iff,
   CheckSPAlignment_erase, CheckSPAlignment_erase_fault, N1a, N1b, N2, N3 (+ erase_e0e_def), N4, P1.
   Not attempted here (statement type-check only): Next_frame, Next_erase_fault_mono, Next_erase, NextStateARM8_erase,
   NextStateARM8_erase_or_fault, real_mc_shift, evaluate_real, machine_sem_real, and the definitions arm8_target_real,
   real_mc, lo55 (they are the later, multi-day part).
   Sources read (file:line): HOL/examples/l3-machine-code/arm8/model/arm8Script.sml 8-20 (records), 367-375 (arm8_state),
   379-387 (raise'exception), 487-497 (SP), 515-529 (TranslationRegime, SCTLR), 530-536 (Hint_Branch), 538-594 (BranchTo),
   598-605 (Align, Aligned), 605-627 (CheckSPAlignment), 655-663 (BigEndian); step/arm8_stepScript.sml 19-22 (NextStateARM8),
   385-394 (Aligned), 474-481 (BranchTo_rwt, CheckSPAlignment_rwt); cakeml/compiler/encoders/arm8/arm8_targetScript.sml
   14-16 (arm8_next = THE o NextStateARM8), 20-26 (arm8_ok), 343-363 (arm8_config, avoid_regs [18;26;31]),
   365-368 (arm8_proj), 371-380 (arm8_target). Names checked against model/.hol/objs/arm8Theory.sig and
   step/.hol/objs/arm8_stepTheory.sig. *)
open HolKernel boolLib bossLib wordsLib blastLib
     wordsTheory arm8Theory arm8_stepTheory targetSemTheory arm8_targetTheory alignmentTheory; (* Orchestrator A, E1-0003: wordsTheory opened (w2w_id was undeclared in E1-0002); no statement change *)
val _ = Globals.max_print_depth := 40;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (400, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2000, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_m1bErasureV2";
val failed = ref ([] : string list);
val optional_failed = ref ([] : string list);
val problems = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun attempt name goal tacs =
  let fun go _ [] = raise Fail "all listed tactics failed"
        | go i (t :: ts) =
            (let val th = Tactical.TAC_PROOF (([], goal), t) in pr ("TACTIC_USED " ^ name ^ " " ^ Int.toString i); th end
             handle e => (pr ("TACTIC_ATTEMPT_FAILED " ^ name ^ " " ^ Int.toString i ^ " " ^ General.exnMessage e); go (i + 1) ts))
  in go 1 tacs end;
(* REQUIRED lemma: a failure is recorded, TRUTH is returned only so later lines print; the run raises Fail before export. *)
fun thmA name goal tacs = (let val th = save_thm (name, attempt name goal tacs) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
fun thm name goal tac = thmA name goal [tac];
(* OPTIONAL lemma: a failure is printed and does not stop the run; a failed optional lemma is not stored. *)
fun opt name goal tacs = (let val th = save_thm (name, attempt name goal tacs) in chk name th; th end)
  handle e => (pr ("OPTIONAL_FAILED " ^ name ^ " " ^ General.exnMessage e); optional_failed := name :: !optional_failed; TRUTH);
fun def name tm = let val th = new_definition (name, tm) in pr ("DEFINITION " ^ thm_to_string th); th end;

(* ---------- 0. Definitions (draft text; new_definition instead of Define: no recursion, no compset side effects) ---------- *)
val _ = pr "MARK DEFS";
val erase_def = def "erase_def"
  ``erase (s:arm8_state) =
      s with <| TCR_EL1   := s.TCR_EL1 with <| TBI0 := F; TBI1 := F |>;
                SCTLR_EL1 := s.SCTLR_EL1 with SA0 := F |>``;
val bits_of_def = def "bits_of_def"
  ``bits_of (s:arm8_state) = (s.TCR_EL1.TBI0, s.TCR_EL1.TBI1, s.SCTLR_EL1.SA0)``;
val restore_def = def "restore_def"
  ``restore (B:bool # bool # bool) (s:arm8_state) =
      s with <| TCR_EL1   := s.TCR_EL1 with <| TBI0 := FST B; TBI1 := FST (SND B) |>;
                SCTLR_EL1 := s.SCTLR_EL1 with SA0 := SND (SND B) |>``;
  (* A5: the draft wrote `restore (b0:bool, b1:bool, a:bool) (s:arm8_state) = ...` with a tuple pattern on the left;
     new_definition does not accept a pattern argument (Define does). The projection form is the same function. *)
val untagged_def = def "untagged_def" ``untagged (a:word64) <=> ((63 >< 55) a = (0w:word9))``;
(* A5 (E3): the branch-target formula of BranchTo at EL0/EL1, arm8Script.sml 548-563, as a function of TCR_EL1 and the target. *)
val tbi_pc_def = def "tbi_pc_def"
  ``tbi_pc (tcr:TCR_EL1) (t:word64) =
      let s0 = if word_bit 55 t /\ tcr.TBI1 then bit_field_insert 63 56 (255w:word8) t else t in
        if ~word_bit 55 s0 /\ tcr.TBI0 then bit_field_insert 63 56 (0w:word8) s0 else s0``;
val erase_e0e_def = def "erase_e0e_def"
  ``erase_e0e (s:arm8_state) = (erase s) with SCTLR_EL1 := (erase s).SCTLR_EL1 with E0E := F``;

(* ---------- 1. Field lemmas ---------- *)
val _ = pr "MARK FIELDS";
val erase_fields = thmA "erase_fields"
  ``(erase s).PC = s.PC /\ (erase s).REG = s.REG /\ (erase s).MEM = s.MEM /\
    (erase s).SP_EL0 = s.SP_EL0 /\ (erase s).PSTATE = s.PSTATE /\
    (erase s).exception = s.exception /\ (erase s).branch_hint = s.branch_hint /\
    (erase s).SCTLR_EL1.A = s.SCTLR_EL1.A /\ (erase s).SCTLR_EL1.E0E = s.SCTLR_EL1.E0E /\
    (erase s).SCTLR_EL1.EE = s.SCTLR_EL1.EE /\ (erase s).SCTLR_EL1.SA = s.SCTLR_EL1.SA /\
    ~(erase s).TCR_EL1.TBI0 /\ ~(erase s).TCR_EL1.TBI1 /\ ~(erase s).SCTLR_EL1.SA0``
  [simp [erase_def]];
val restore_erase = thmA "restore_erase"
  ``bits_of s = B ==> restore B (erase s) = s``
  [rw [bits_of_def, restore_def, erase_def] >>
     simp [arm8_state_component_equality, TCR_EL1_component_equality, SCTLRType_component_equality],
   PairCases_on `B` >> rw [bits_of_def, restore_def, erase_def] >>
     simp [arm8_state_component_equality, TCR_EL1_component_equality, SCTLRType_component_equality]];
val erase_restore = thmA "erase_restore" ``erase (restore B s) = erase s``
  [simp [restore_def, erase_def],
   simp [restore_def, erase_def, arm8_state_component_equality, TCR_EL1_component_equality, SCTLRType_component_equality]];
val arm8_ok_erase = thmA "arm8_ok_erase"
  ``arm8_ok (erase s) <=> s.PSTATE.EL = 0w /\ ~s.SCTLR_EL1.E0E /\
                         s.exception = NoException /\ aligned 2 s.PC``
  [simp [arm8_ok_def, erase_def], simp [arm8_ok_def, erase_def] >> metis_tac []];

(* ---------- 2. BranchTo ---------- *)
val _ = pr "MARK BRANCH";
val UNT = thmA "untagged_bits"
  ``!t:word64. untagged t ==> ~word_bit 55 t /\ bit_field_insert 63 56 (0w:word8) t = t``
  [rw [untagged_def] >> blastLib.FULL_BBLAST_TAC,
   simp [untagged_def] >> blastLib.BBLAST_TAC,
   rw [untagged_def] >> pop_assum mp_tac >> blastLib.BBLAST_TAC];
val BPC = thmA "BranchTo_EL0_pc"
  ``s.PSTATE.EL = 0w ==>
    BranchTo (t, bt) s = s with <| branch_hint := SOME bt; PC := tbi_pc s.TCR_EL1 t |>``
  [strip_tac >> simp [BranchTo_def, Hint_Branch_def, tbi_pc_def, LET_THM, literal_case_THM],
   strip_tac >> simp [BranchTo_def, Hint_Branch_def, tbi_pc_def, LET_THM, literal_case_THM] >>
     simp [arm8_state_component_equality],
   strip_tac >> rw [BranchTo_def, Hint_Branch_def, tbi_pc_def] >> fs [arm8_state_component_equality] >> EVAL_TAC];
val TPC_ERASED = thmA "tbi_pc_erased" ``!tcr t. tbi_pc (tcr with <| TBI0 := F; TBI1 := F |>) t = t``
  [simp [tbi_pc_def]];
val TPC_UNT = thmA "tbi_pc_untagged" ``!tcr t. untagged t ==> tbi_pc tcr t = t``
  [rpt strip_tac >> imp_res_tac UNT >> simp [tbi_pc_def]];
(* the draft statement, word for word *)
val BTU = thmA "BranchTo_erase_untagged"
  ``s.PSTATE.EL = 0w ==>
    BranchTo (t, bt) (erase s) = erase (BranchTo (t, bt) s)``
  [strip_tac >> `(erase s).PSTATE.EL = 0w` by simp [erase_def] >>
     asm_simp_tac (srw_ss()) [BPC, TPC_UNT] >> simp [erase_def, TPC_ERASED],
   strip_tac >> `(erase s).PSTATE.EL = 0w` by simp [erase_def] >>
     asm_simp_tac (srw_ss()) [BPC, TPC_UNT] >>
     simp [erase_def, tbi_pc_def, arm8_state_component_equality, TCR_EL1_component_equality]];
(* OPTIONAL report lemma: the weakest condition (draft statement, word for word) *)
val BTI = opt "BranchTo_erase_iff"
  ``s.PSTATE.EL = 0w ==>
    (BranchTo (t, bt) (erase s) = erase (BranchTo (t, bt) s) <=>
       (word_bit 55 t /\ s.TCR_EL1.TBI1 ==> (63 >< 56) t = (255w:word8)) /\
       (~word_bit 55 t /\ s.TCR_EL1.TBI0 ==> (63 >< 56) t = (0w:word8)))``
  [strip_tac >> `(erase s).PSTATE.EL = 0w` by simp [erase_def] >>
     asm_simp_tac (srw_ss()) [BPC] >> simp [erase_def, TPC_ERASED, arm8_state_component_equality] >>
     simp [tbi_pc_def] >> rw [] >> blastLib.FULL_BBLAST_TAC,
   strip_tac >> `(erase s).PSTATE.EL = 0w` by simp [erase_def] >>
     asm_simp_tac (srw_ss()) [BPC] >> simp [erase_def, TPC_ERASED, arm8_state_component_equality, tbi_pc_def] >>
     Cases_on `s.TCR_EL1.TBI0` >> Cases_on `s.TCR_EL1.TBI1` >> simp [] >> blastLib.BBLAST_TAC];

(* ---------- 3. CheckSPAlignment ---------- *)
val _ = pr "MARK SP";
val CSA = thmA "CheckSPAlignment_erase"
  ``s.PSTATE.EL = 0w /\ (~s.SCTLR_EL1.SA0 \/ aligned 4 s.SP_EL0) ==>
    CheckSPAlignment (erase s) = erase (CheckSPAlignment s)``
  [rw [CheckSPAlignment_def, SP_def, erase_def, Aligned] >> fs [],
   strip_tac >> Cases_on `s.PSTATE.SPS` >>
     fs [CheckSPAlignment_def, SP_def, erase_def, Aligned, literal_case_THM, w2w_id] >> rw [] >> fs []];
val CSAF = thmA "CheckSPAlignment_erase_fault"
  ``s.PSTATE.EL = 0w /\ s.exception = NoException ==>
    CheckSPAlignment (erase s) = erase s /\
    (CheckSPAlignment s = s \/
     (s.SCTLR_EL1.SA0 /\ ~aligned 4 s.SP_EL0 /\
      CheckSPAlignment s = s with exception := ALIGNMENT_FAULT))``
  [rw [CheckSPAlignment_def, SP_def, erase_def, Aligned, raise'exception_def] >> fs [],
   strip_tac >> Cases_on `s.PSTATE.SPS` >>
     fs [CheckSPAlignment_def, SP_def, erase_def, Aligned, raise'exception_def, literal_case_THM, w2w_id] >>
     rw [] >> fs []];

(* ---------- 4. Negative and positive controls (each must PROVE the stated failure or success) ---------- *)
val _ = pr "MARK CONTROLS";
val N1a = thmA "N1a_tagged_branch_breaks"
  ``s.PSTATE.EL = 0w /\ s.TCR_EL1.TBI0 ==>
    BranchTo (0x0100000000001000w, BranchType_JMP) (erase s) <>
    erase (BranchTo (0x0100000000001000w, BranchType_JMP) s)``
  [strip_tac >> `(erase s).PSTATE.EL = 0w` by simp [erase_def] >>
     asm_simp_tac (srw_ss()) [BPC] >> simp [erase_def, TPC_ERASED, arm8_state_component_equality] >>
     simp [tbi_pc_def] >> EVAL_TAC,
   strip_tac >> `(erase s).PSTATE.EL = 0w` by simp [erase_def] >>
     asm_simp_tac (srw_ss()) [BPC] >> simp [erase_def, TPC_ERASED, arm8_state_component_equality, tbi_pc_def] >>
     blastLib.BBLAST_TAC];
val N1b = thmA "N1b_bit55_branch_breaks"
  ``s.PSTATE.EL = 0w /\ s.TCR_EL1.TBI1 ==>
    BranchTo (0x0080000000001000w, BranchType_JMP) (erase s) <>
    erase (BranchTo (0x0080000000001000w, BranchType_JMP) s)``
  [strip_tac >> `(erase s).PSTATE.EL = 0w` by simp [erase_def] >>
     asm_simp_tac (srw_ss()) [BPC] >> simp [erase_def, TPC_ERASED, arm8_state_component_equality] >>
     simp [tbi_pc_def] >> EVAL_TAC,
   strip_tac >> `(erase s).PSTATE.EL = 0w` by simp [erase_def] >>
     asm_simp_tac (srw_ss()) [BPC] >> simp [erase_def, TPC_ERASED, arm8_state_component_equality, tbi_pc_def] >>
     Cases_on `s.TCR_EL1.TBI0` >> simp [] >> blastLib.BBLAST_TAC];
val N2 = thmA "N2_misaligned_sp_breaks"
  ``s.PSTATE.EL = 0w /\ s.exception = NoException /\ s.SCTLR_EL1.SA0 /\ s.SP_EL0 = 8w ==>
    (CheckSPAlignment (erase s)).exception = NoException /\
    (CheckSPAlignment s).exception = ALIGNMENT_FAULT``
  [strip_tac >> Cases_on `s.PSTATE.SPS` >>
     fs [CheckSPAlignment_def, SP_def, erase_def, raise'exception_def, Aligned, literal_case_THM, w2w_id] >> EVAL_TAC,
   rw [CheckSPAlignment_def, SP_def, erase_def, raise'exception_def, Aligned_def, Align_def] >> EVAL_TAC];
val N3 = thmA "N3_e0e_not_erasable"
  ``s.PSTATE.EL = 0w /\ s.SCTLR_EL1.E0E ==> BigEndian (erase_e0e s) <> BigEndian s``
  [rw [BigEndian_def, erase_e0e_def, erase_def],
   rw [BigEndian_def, erase_e0e_def, erase_def, literal_case_THM] >> fs []];
val N4 = thmA "N4_slide_ok_admits_tagged_code"
  ``aligned 12 (0x0100000000000000w:word64) /\
    (0x0100000000000000w:word64) <=+ 0xFFFFFFFEFFFCF0CFw /\
    ~untagged (0x0100000000000000w + 0x1000040D0w : word64)``
  [simp [untagged_def] >> EVAL_TAC, rewrite_tac [untagged_def] >> EVAL_TAC];
val P1 = thmA "P1_bit55_without_TBI1_is_fine"
  ``s.PSTATE.EL = 0w /\ ~s.TCR_EL1.TBI1 ==>
    BranchTo (0x0080000000001000w, bt) (erase s) = erase (BranchTo (0x0080000000001000w, bt) s)``
  [strip_tac >> `(erase s).PSTATE.EL = 0w` by simp [erase_def] >>
     asm_simp_tac (srw_ss()) [BPC] >> simp [erase_def, TPC_ERASED, arm8_state_component_equality] >>
     simp [tbi_pc_def] >> EVAL_TAC,
   strip_tac >> `(erase s).PSTATE.EL = 0w` by simp [erase_def] >>
     asm_simp_tac (srw_ss()) [BPC] >> simp [erase_def, TPC_ERASED, arm8_state_component_equality, tbi_pc_def] >>
     Cases_on `s.TCR_EL1.TBI0` >> simp [] >> blastLib.BBLAST_TAC];
(* A5 control: the address premise P-LO55 (draft section 7) holds at slide 0 for the image end, and its bound is tight
   in the sense of N4: the largest slide it admits is far below the largest slide slide_ok admits. *)
val N5 = thmA "N5_lo55_holds_at_slide_zero_and_fails_at_N4_slide"
  ``w2n (0w:word64) + 0x100030F30 <= 2 ** 55 /\ ~(w2n (0x0100000000000000w:word64) + 0x100030F30 <= 2 ** 55)``
  [EVAL_TAC];

(* ---------- 5. Deferred statements: parsed and type-checked only. NOTHING here is proved or assumed. ---------- *)
val _ = pr "MARK DEFERRED";
fun tc name q = (let val t = Parse.Term q in
                   if type_of t = bool then pr ("STATEMENT_TYPECHECKS " ^ name) else bad ("not-boolean " ^ name) end)
                handle e => bad ("statement-does-not-typecheck " ^ name ^ " " ^ General.exnMessage e);
val _ = tc "Next_frame"
  `(arm8$Next s).TCR_EL1 = s.TCR_EL1 /\ (arm8$Next s).SCTLR_EL1 = s.SCTLR_EL1 /\ (arm8$Next s).PSTATE.EL = s.PSTATE.EL`;
val _ = tc "Next_erase_fault_mono"
  `s.PSTATE.EL = 0w /\ s.exception = NoException /\ (arm8$Next (erase s)).exception <> NoException ==>
   (arm8$Next s).exception <> NoException`;
val _ = tc "Next_erase"
  `s.PSTATE.EL = 0w /\ s.exception = NoException /\ (arm8$Next s).exception = NoException /\
   untagged (arm8$Next (erase s)).PC ==> arm8$Next (erase s) = erase (arm8$Next s)`;
val _ = tc "NextStateARM8_erase"
  `s.PSTATE.EL = 0w /\ s.exception = NoException /\ (~s.SCTLR_EL1.SA0 \/ aligned 4 s.SP_EL0) /\
   (!t. NextStateARM8 (erase s) = SOME t ==> untagged t.PC) ==>
   NextStateARM8 (erase s) = OPTION_MAP erase (NextStateARM8 s)`;
val _ = tc "NextStateARM8_erase_or_fault"
  `s.PSTATE.EL = 0w /\ s.exception = NoException /\ NextStateARM8 (erase s) = SOME t /\ untagged t.PC ==>
   NextStateARM8 s = SOME (restore (bits_of s) t) \/
   (NextStateARM8 s = NONE /\ s.SCTLR_EL1.SA0 /\ ~aligned 4 s.SP_EL0)`;
val _ = tc "arm8_target_real (as an equation)"
  `arm8_target_real B = arm8_target with <| next := arm8$Next; state_ok := \ms. arm8_ok (erase ms) /\ bits_of ms = B |>`;
val _ = tc "lo55 (as an equation)"
  `lo55 (mc : (64, 'b, 'c) machine_config) <=>
     !a. a IN mc.prog_addresses \/ a = mc.halt_pc \/ a = mc.install_pc \/ MEM a mc.ffi_entry_pcs ==> untagged a`;

(* ---------- 6. Checks ---------- *)
val _ = pr "MARK CHECKS";
val _ = List.app (fn n => pr ("OPTIONAL_FAILED_LIST " ^ n)) (rev (!optional_failed));
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
fun negchk name th = if is_neg (snd (dest_imp (concl th)) handle _ => concl th) orelse is_neg (concl th)
                     then pr ("CONTROL_OK " ^ name ^ " is a proved negative") else bad (name ^ "-not-negative");
val _ = negchk "N1a" N1a; val _ = negchk "N1b" N1b; val _ = negchk "N3" N3;
val _ = if is_conj (concl N2) orelse is_imp (concl N2) then pr "CONTROL_OK N2 proved: the real SA0 bit adds an alignment fault"
        else bad "N2-shape";
val _ = if can (find_term (fn t => is_neg t)) (concl N4) then pr "CONTROL_OK N4 proved: slide_ok admits a tagged code base"
        else bad "N4-shape";
val _ = if aconv (concl BTU) ``s.PSTATE.EL = 0w ==> BranchTo (t, bt) (erase s) = erase (BranchTo (t, bt) s)``
        then pr "CONTROL_OK BranchTo_erase_untagged is the literal draft statement" else bad "BTU-literal";
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_m1bErasureV2" @ DB.definitions "forge_m1bErasureV2");
val closure = "forge_m1bErasureV2" :: Theory.ancestry "forge_m1bErasureV2";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_m1bErasureV2")));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions "forge_m1bErasureV2")));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;

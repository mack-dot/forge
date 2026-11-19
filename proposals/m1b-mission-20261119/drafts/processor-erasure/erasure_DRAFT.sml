(* erasure_DRAFT.sml  --  worker Z2, M1-B wave 5, 2026-11-19.
   DRAFT. NOT RUN. NOT TYPE-CHECKED BY HOL. No proof below is evidence.
   Names and types are checked only by READING:
     HOL/examples/l3-machine-code/arm8/model/arm8Script.sml (record fields 8-20, 367-375;
       BranchTo 538-594; CheckSPAlignment 605-627; Next 7203-7221),
     model/.hol/objs/arm8Theory.sig (BranchTo_def, CheckSPAlignment_def, Next_def, Hint_Branch_def,
       arm8_state_component_equality, TCR_EL1_component_equality, SCTLRType_component_equality),
     step/arm8_stepScript.sml (NextStateARM8_def 19-22, Aligned 385-394, BranchTo_rwt 474-476,
       CheckSPAlignment_rwt 478-481), step/.hol/objs/arm8_stepTheory.sig,
     cakeml/compiler/backend/semantics/targetSemScript.sml (machine_config 18-45, evaluate 128-220,
       machine_sem 221-234), cakeml/compiler/encoders/arm8/arm8_targetScript.sml (arm8_next 14-16,
       arm8_ok 20-26, arm8_proj 365-368, arm8_target 370-380).
   Tactics are SKETCHES. Expect them to need repair when the HOL slot is free.
   Open goals use NO_TAC (the file FAILS on them); there is no cheat and no mk_thm. *)

open HolKernel boolLib bossLib wordsLib blastLib
     arm8Theory arm8_stepTheory targetSemTheory arm8_targetTheory;

val _ = new_theory "forge_m1bErasureDraft";

(* ---------- 0. Definitions ---------- *)

val erase_def = Define `
  erase (s:arm8_state) =
    s with <| TCR_EL1   := s.TCR_EL1 with <| TBI0 := F; TBI1 := F |>;
              SCTLR_EL1 := s.SCTLR_EL1 with SA0 := F |>`;

val bits_of_def = Define `
  bits_of (s:arm8_state) = (s.TCR_EL1.TBI0, s.TCR_EL1.TBI1, s.SCTLR_EL1.SA0)`;

val restore_def = Define `
  restore (b0:bool, b1:bool, a:bool) (s:arm8_state) =
    s with <| TCR_EL1   := s.TCR_EL1 with <| TBI0 := b0; TBI1 := b1 |>;
              SCTLR_EL1 := s.SCTLR_EL1 with SA0 := a |>`;

(* bits 63:55 zero: the uniform sufficient branch-target condition *)
val untagged_def = Define `untagged (a:word64) <=> ((63 >< 55) a = (0w:word9))`;

(* ---------- 1. Field lemmas (minutes) ---------- *)

val erase_fields = store_thm ("erase_fields",
  ``(erase s).PC = s.PC /\ (erase s).REG = s.REG /\ (erase s).MEM = s.MEM /\
    (erase s).SP_EL0 = s.SP_EL0 /\ (erase s).PSTATE = s.PSTATE /\
    (erase s).exception = s.exception /\ (erase s).branch_hint = s.branch_hint /\
    (erase s).SCTLR_EL1.A = s.SCTLR_EL1.A /\ (erase s).SCTLR_EL1.E0E = s.SCTLR_EL1.E0E /\
    (erase s).SCTLR_EL1.EE = s.SCTLR_EL1.EE /\ (erase s).SCTLR_EL1.SA = s.SCTLR_EL1.SA /\
    ~(erase s).TCR_EL1.TBI0 /\ ~(erase s).TCR_EL1.TBI1 /\ ~(erase s).SCTLR_EL1.SA0``,
  simp [erase_def]);

val restore_erase = store_thm ("restore_erase",
  ``bits_of s = B ==> restore B (erase s) = s``,
  PairCases_on `B` >>
  simp [bits_of_def, restore_def, erase_def, arm8_state_component_equality,
        TCR_EL1_component_equality, SCTLRType_component_equality] >> rw [] >> rw []);

val erase_restore = store_thm ("erase_restore",
  ``erase (restore B s) = erase s``,
  PairCases_on `B` >> simp [restore_def, erase_def]);

val arm8_ok_erase = store_thm ("arm8_ok_erase",
  ``arm8_ok (erase s) <=> s.PSTATE.EL = 0w /\ ~s.SCTLR_EL1.E0E /\
                         s.exception = NoException /\ aligned 2 s.PC``,
  simp [arm8_ok_def, erase_def] >> metis_tac []);

(* ---------- 2. FIRST LEMMA TO RUN: BranchTo (minutes) ---------- *)

val BranchTo_erase_untagged = store_thm ("BranchTo_erase_untagged",
  ``s.PSTATE.EL = 0w /\ untagged t ==>
    BranchTo (t, bt) (erase s) = erase (BranchTo (t, bt) s)``,
  strip_tac >>
  `~word_bit 55 t /\ bit_field_insert 63 56 (0w:word8) t = t`
     by (fs [untagged_def] >> blastLib.FULL_BBLAST_TAC) >>
  simp [BranchTo_def, Hint_Branch_def, erase_def]);

(* The WEAKEST condition (iff), for the report: TBI1 matters only if bit 55 = 1,
   TBI0 only if bit 55 = 0. *)
val BranchTo_erase_iff = store_thm ("BranchTo_erase_iff",
  ``s.PSTATE.EL = 0w ==>
    (BranchTo (t, bt) (erase s) = erase (BranchTo (t, bt) s) <=>
       (word_bit 55 t /\ s.TCR_EL1.TBI1 ==> (63 >< 56) t = (255w:word8)) /\
       (~word_bit 55 t /\ s.TCR_EL1.TBI0 ==> (63 >< 56) t = (0w:word8)))``,
  strip_tac >> simp [BranchTo_def, Hint_Branch_def, erase_def] >>
  rw [arm8_state_component_equality] >> blastLib.FULL_BBLAST_TAC);

(* ---------- 3. CheckSPAlignment (minutes) ---------- *)

val CheckSPAlignment_erase = store_thm ("CheckSPAlignment_erase",
  ``s.PSTATE.EL = 0w /\ (~s.SCTLR_EL1.SA0 \/ aligned 4 s.SP_EL0) ==>
    CheckSPAlignment (erase s) = erase (CheckSPAlignment s)``,
  rw [CheckSPAlignment_def, SP_def, erase_def, Aligned] >> fs [] );

(* fault-or-equal: the real bit can only ADD an alignment fault *)
val CheckSPAlignment_erase_fault = store_thm ("CheckSPAlignment_erase_fault",
  ``s.PSTATE.EL = 0w /\ s.exception = NoException ==>
    CheckSPAlignment (erase s) = erase s /\
    (CheckSPAlignment s = s \/
     (s.SCTLR_EL1.SA0 /\ ~aligned 4 s.SP_EL0 /\
      CheckSPAlignment s = s with exception := ALIGNMENT_FAULT))``,
  rw [CheckSPAlignment_def, SP_def, erase_def, Aligned, raise'exception_def] >> fs []);

(* ---------- 4. Frame and one-step simulation (DAYS; the big part) ---------- *)
(* Reading (grep of Rupd in arm8Script.sml): Next updates only REG, MEM, PC, SP_EL0..3,
   PSTATE.{N,Z,C,V}, branch_hint, exception. So these should hold for ALL instructions. *)

val Next_frame = store_thm ("Next_frame",
  ``(arm8$Next s).TCR_EL1 = s.TCR_EL1 /\ (arm8$Next s).SCTLR_EL1 = s.SCTLR_EL1 /\
    (arm8$Next s).PSTATE.EL = s.PSTATE.EL``,
  NO_TAC (* DRAFT: needs a per-primitive frame library and Cases on the decoded AST *));

(* Faults are monotone: erasure removes the SA0 fault and adds none. *)
val Next_erase_fault_mono = store_thm ("Next_erase_fault_mono",
  ``s.PSTATE.EL = 0w /\ s.exception = NoException /\
    (arm8$Next (erase s)).exception <> NoException ==>
    (arm8$Next s).exception <> NoException``,
  NO_TAC);

(* V0 (raw Next, decode-free side condition on the ERASED successor PC) *)
val Next_erase = store_thm ("Next_erase",
  ``s.PSTATE.EL = 0w /\ s.exception = NoException /\
    (arm8$Next s).exception = NoException /\
    untagged (arm8$Next (erase s)).PC ==>
    arm8$Next (erase s) = erase (arm8$Next s)``,
  NO_TAC (* commute library: X, write'X, SP, write'SP, Mem, write'Mem, BigEndian,
           CheckAlignment, ConditionHolds, SetTheFlags, Fetch, Decode (state-free),
           then BranchTo_erase_untagged and CheckSPAlignment_erase *));

(* Requested OPTION_MAP shape, with the instruction-independent SP condition *)
val NextStateARM8_erase = store_thm ("NextStateARM8_erase",
  ``s.PSTATE.EL = 0w /\ s.exception = NoException /\
    (~s.SCTLR_EL1.SA0 \/ aligned 4 s.SP_EL0) /\
    (!t. NextStateARM8 (erase s) = SOME t ==> untagged t.PC) ==>
    NextStateARM8 (erase s) = OPTION_MAP erase (NextStateARM8 s)``,
  NO_TAC (* from Next_erase, Next_erase_fault_mono, CheckSPAlignment_erase *));

(* Fault-or-simulate shape, used by the lift: no SP condition at all *)
val NextStateARM8_erase_or_fault = store_thm ("NextStateARM8_erase_or_fault",
  ``s.PSTATE.EL = 0w /\ s.exception = NoException /\
    NextStateARM8 (erase s) = SOME t /\ untagged t.PC ==>
    NextStateARM8 s = SOME (restore (bits_of s) t) \/
    (NextStateARM8 s = NONE /\ s.SCTLR_EL1.SA0 /\ ~aligned 4 s.SP_EL0)``,
  NO_TAC);

(* ---------- 5. The real-bit machine (definitions are the NATIVE content) ---------- *)
(* Real next-state = raw L3 Next (a fault stays visible in .exception, so state_ok
   gives Error; THE o NextStateARM8 would hide it behind THE NONE). *)
val arm8_target_real_def = Define `
  arm8_target_real B =
    arm8_target with <| next := arm8$Next;
                        state_ok := \ms. arm8_ok (erase ms) /\ bits_of ms = B |>`;

val real_mc_def = Define `
  real_mc B (mc : (64, arm8_state, 'c) machine_config) =
    mc with <| target := arm8_target_real B;
               next_interfer := (\i ms. restore B (mc.next_interfer i (erase ms)));
               ffi_interfer := (\i (n, bs, ms). restore B (mc.ffi_interfer i (n, bs, erase ms)));
               install_interfer := (\i (bs, ms). restore B (mc.install_interfer i (bs, erase ms))) |>`;
(* type note: verify that arm8_target_real B has the same 'c as mc.target (it does if
   arm8_target's proj type is unchanged by the record update) *)

val real_mc_shift = store_thm ("real_mc_shift",
  ``shift_seq 1 (real_mc B mc).next_interfer =
    (real_mc B (mc with next_interfer := shift_seq 1 mc.next_interfer)).next_interfer``,
  NO_TAC (* and the same for ffi_interfer, install_interfer *));

(* address premise P-LO55: every PC the erased run may reach is untagged *)
val lo55_def = Define `
  lo55 (mc : (64, 'b, 'c) machine_config) <=>
    !a. a IN mc.prog_addresses \/ a = mc.halt_pc \/ a = mc.install_pc \/
        MEM a mc.ffi_entry_pcs ==> untagged a`;

(* ---------- 6. Lift to evaluate and machine_sem (days) ---------- *)
val evaluate_real = store_thm ("evaluate_real",
  ``!k mc ffi ms.
      mc.target = arm8_target /\ lo55 mc /\
      interference_ok mc.next_interfer (arm8_target.proj mc.prog_addresses) /\
      bits_of ms = B /\
      (!k'. FST (evaluate mc ffi k' (erase ms)) <> Error) ==>
      let (r, ms', ffi') = evaluate (real_mc B mc) ffi k ms in
        r = Error \/
        (FST (evaluate mc ffi k (erase ms)) = r /\
         SND (SND (evaluate mc ffi k (erase ms))) = ffi' /\
         (r <> TimeOut ==> FST (SND (evaluate mc ffi k (erase ms))) = erase ms'))``,
  NO_TAC (* induction on k; NextStateARM8_erase_or_fault; Next_frame; real_mc_shift;
           untagged next PC from lo55 + no Error at k'+1 + PC kept by next_interfer *));

val machine_sem_real = store_thm ("machine_sem_real",
  ``mc.target = arm8_target /\ lo55 mc /\
    interference_ok mc.next_interfer (arm8_target.proj mc.prog_addresses) /\
    bits_of ms = B /\ ~machine_sem mc ffi (erase ms) Fail ==>
    !b. machine_sem (real_mc B mc) ffi ms b ==> b = Fail \/ machine_sem mc ffi (erase ms) b``,
  NO_TAC);

(* stub run (27 steps, arm8_run of forge_refundCmlMainStep): needs PCs of the 27
   intermediate erased states (re-run the stored stub step proof with one more conjunct) *)

(* ---------- 7. Target corollary for THIS program (statement only) ----------
   refund_profile_a_sl_real_bits:
   |- bits_of rho = B /\ refund_entry_pre_sl sl (erase rho) h stk e /\ aligned 3 e /\
      h <=+ e /\ 8192w <=+ e - h /\ refund_heap_clear_sl sl h e /\
      envmc.prog_addresses = refund_mem_dm_sl sl h e /\ refund_env_ok_sl sl envmc /\
      w2n sl + 0x100030F30 <= 2 ** 55 /\ w2n e <= 2 ** 55 /\            (NEW premise P-LO55)
      stdin_content fs = SOME (...same as stored...) /\ wfcl cl /\ wfFS fs /\ STD_streams fs ==>
      ?rm. arm8_run 27 rho = SOME rm /\ rm.PC = sl + 0x1000040D0w /\ bits_of rm = B /\
        !b. machine_sem (real_mc B (refund_mc (sl + 0x1000040D0w) envmc)) (basis_ffi ext cl fs) rm b ==>
            b = Fail \/
            (?io. b = Terminate Success io /\ extract_fs ext (cl,fs) io = SOME (add_stdout ...)) \/
            (?io io'. b = Terminate Resource_limit_hit io' /\ io' <<= io /\ extract_fs ext (cl,fs) io = SOME (...))
   Note: refund_entry_pre_sl sl (erase rho) does NOT require TBI0/TBI1/SA0 of rho;
   it still requires ~rho.SCTLR_EL1.E0E, EL = 0, exception = NoException. *)

(* ---------- 8. Negative controls (each must PROVE the failure) ---------- *)

(* N1a tagged branch, bit 55 = 0, real TBI0 = T: real PC loses the tag *)
val N1a = store_thm ("N1a_tagged_branch_breaks",
  ``s.PSTATE.EL = 0w /\ s.TCR_EL1.TBI0 ==>
    BranchTo (0x0100000000001000w, BranchType_JMP) (erase s) <>
    erase (BranchTo (0x0100000000001000w, BranchType_JMP) s)``,
  rw [BranchTo_def, Hint_Branch_def, erase_def, arm8_state_component_equality] >> EVAL_TAC);

(* N1b bit 55 = 1, real TBI1 = T: real PC gets top byte 0xFF *)
val N1b = store_thm ("N1b_bit55_branch_breaks",
  ``s.PSTATE.EL = 0w /\ s.TCR_EL1.TBI1 ==>
    BranchTo (0x0080000000001000w, BranchType_JMP) (erase s) <>
    erase (BranchTo (0x0080000000001000w, BranchType_JMP) s)``,
  rw [BranchTo_def, Hint_Branch_def, erase_def, arm8_state_component_equality] >> EVAL_TAC);

(* N2 SP-based access with misaligned SP, real SA0 = T: real step faults, erased does not *)
val N2 = store_thm ("N2_misaligned_sp_breaks",
  ``s.PSTATE.EL = 0w /\ s.exception = NoException /\ s.SCTLR_EL1.SA0 /\ s.SP_EL0 = 8w ==>
    (CheckSPAlignment (erase s)).exception = NoException /\
    (CheckSPAlignment s).exception = ALIGNMENT_FAULT``,
  rw [CheckSPAlignment_def, SP_def, erase_def, raise'exception_def, Aligned_def, Align_def] >> EVAL_TAC);
(* N2-step (optional, heavier): concrete s with word 0xF94003E0 (ldr x0,[sp]) at PC:
   NextStateARM8 (erase s) <> NONE /\ NextStateARM8 s = NONE. Use arm8_stepLib or EVAL. *)

(* N3 E0E is NOT erasable: a relation that also clears E0E breaks the simulation *)
val erase_e0e_def = Define `erase_e0e s = (erase s) with SCTLR_EL1 := (erase s).SCTLR_EL1 with E0E := F`;
val N3 = store_thm ("N3_e0e_not_erasable",
  ``s.PSTATE.EL = 0w /\ s.SCTLR_EL1.E0E ==> BigEndian (erase_e0e s) <> BigEndian s``,
  rw [BigEndian_def, erase_e0e_def, erase_def]);
(* N3-step: concrete s with word 0xF9400020 (ldr x0,[x1]) and MEM bytes 1..8 at x1:
   (Next (erase_e0e s)).REG 0w <> (Next s).REG 0w. *)

(* N4 the stored slide premise admits a tagged code address: P-LO55 is NEW *)
val N4 = store_thm ("N4_slide_ok_admits_tagged_code",
  ``aligned 12 (0x0100000000000000w:word64) /\
    (0x0100000000000000w:word64) <=+ 0xFFFFFFFEFFFCF0CFw /\
    ~untagged (0x0100000000000000w + 0x1000040D0w : word64)``,
  simp [untagged_def] >> EVAL_TAC);

(* P1 positive control: the uniform condition is not necessary (bit 55 = 1, TBI1 = F) *)
val P1 = store_thm ("P1_bit55_without_TBI1_is_fine",
  ``s.PSTATE.EL = 0w /\ ~s.TCR_EL1.TBI1 ==>
    BranchTo (0x0080000000001000w, bt) (erase s) = erase (BranchTo (0x0080000000001000w, bt) s)``,
  rw [BranchTo_def, Hint_Branch_def, erase_def] >> EVAL_TAC);

val _ = export_theory ();

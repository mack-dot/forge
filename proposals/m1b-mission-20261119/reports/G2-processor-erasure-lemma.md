# Step G2: the erasure lemma for the processor bits TBI0, TBI1 and SA0 (Z2, Opus; reading and a draft only; nothing ran)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

## Z2 report: the erasure lemma for TBI0, TBI1 and SA0 (links X5 and X11e)

**Findings.** All of these come from READING. I ran nothing in HOL.

1. **The bits are read in only a few places** (arm8Script.sml):
   - **TBI1** is read in `BranchTo`, lines 553 and 568. **TBI0** is read in `BranchTo`, lines 560 and 575. Lines 399–401 are only the record-to-word functions, and no code calls them.
   - **SA0** is read in `CheckSPAlignment`, line 612. Lines 449 and 454 are again only record-to-word functions.
   - Five instructions call `BranchTo`: BranchConditional 1673, BranchImmediate 1693, BranchRegister 1704, CompareAndBranch 1725 and TestBitAndBranch 1742.
   - Four places call `CheckSPAlignment`, each only when the base register n = 31: LoadStoreSingle 1760 (not PREFETCH; it serves LoadStoreImmediate and LoadStoreRegister through 1839 and 1855), LoadStorePair 1878, LoadStoreAcquire 2029 and LoadStoreAcquirePair 2105.
   - The model has no address translation and no exception entry. MRS, MSR, SVC and ERET give UNDEFINED_FAULT (2397–2466).
   - No `Rupd` of TCR_EL1, SCTLR_EL1 or PSTATE.EL exists. The only fields that change are REG, MEM, PC, SP_ELx, N/Z/C/V, branch_hint and exception. So the frame lemma is true by reading.
   - In the step library, only `BranchTo_rwt` and `CheckSPAlignment_rwt` use these bits (arm8_stepScript 462–481).
2. **The weakest conditions per instruction class:**
   - **Branch with target t:** `(bit55 t ∧ TBI1 ⇒ t[63:56] = 0xFF) ∧ (¬bit55 t ∧ TBI0 ⇒ t[63:56] = 0)`. This is an exact iff. A sufficient uniform form is `(63><55) t = 0w`.
   - **SP-based access:** `¬SA0 ∨ aligned 4 SP_EL0`. Without this condition the real step can only ADD an ALIGNMENT_FAULT; the erasure never changes the effect of a step that succeeds.
   - **All other instructions:** no condition.
   - **Step form without decoding:** `untagged (Next (erase s)).PC`.
3. **New premise needed: `slide_ok` does not keep code below 2^55.** For example, sl = 0x0100000000000000 satisfies `slide_ok` but puts the code at a tagged address (control N4). The new premise P-LO55 is `w2n sl + 0x100030F30 ≤ 2^55 ∧ w2n e ≤ 2^55`. With it, every PC the erased run can reach is untagged: prog_addresses, halt_pc, install_pc and ffi_entry_pcs. The reason: the stored ¬Fail result means each reached PC passes the PC check in `evaluate`, and `arm8_proj` keeps the PC fixed through next_interfer. Indirect `br` needs no separate argument.
4. **SA0 for this program:**
   - The 27 stub steps use only x1, x2 and x3 as base registers, never SP (export_arm8 50–76, ret = F).
   - Compiled code avoids register 31 through `avoid_regs [18;26;31]`. But `encoded_bytes_in_mem` (targetSem 52–58) accepts ANY `i`, with no `asm_ok`. So the stored theorem does not exclude an SP base.
5. **A hidden gap: `arm8_next = THE o NextStateARM8`.** A step that faults in the model goes to `THE NONE`, an unknown state. The stored theorem therefore cannot exclude a fault in the model run. A real fault is a signal.
   - **Consequence:** the honest corollary keeps a `b = Fail` disjunct. The real machine is modelled with the raw `Next`, so a fault gives Error.
   - Removing the disjunct needs a no-fault lemma taken out of the backend proof, or an SP-alignment invariant, which is NATIVE.
6. **Interference condition (NATIVE, part of A-INT).** The real kernel and the C FFI must act as `restore B ∘ oracle ∘ erase` and must not change the bits. On the model side, erased states stay erased: `interference_ok` holds and `proj` includes TCR_EL1 and SCTLR_EL1; for the FFI the contract gives `state_ok`.
7. **Whole-run corollary** (the exact text is in section 7 of the draft):
   - Under the stored premises applied to `erase ρ`, plus P-LO55, the real stub run reaches `rm` with `erase rm = ms`.
   - Every real behaviour is either `Fail` or one of the behaviours the stored theorem allows.
   - The safety direction "Success ⇒ correct output" transfers.
   - E0E stays a real premise; it is 0 on both kernels.
8. **macOS and TBID0.**
   - XNU names bit 51 `TCR_TBID0_TBI_DATA_ONLY` and sets it under HAS_APPLE_PAC (proc_reg.h 911–916).
   - From my memory of the Arm manual's AArch64.AddrTop and BranchAddr, NOT quoted: with TBID0 = 1, branch targets are not stripped. So real macOS branches behave like the ERASED state (TBI0 = F), and Linux branches behave like TBI0 = T.
   - Data accesses do not match the model at either value, because the model has no data top-byte-ignore.
   - Still unknown: HAS_APPLE_PAC in the shipped kernel, and the exact Arm text.
   - For untagged targets, the lemma makes the question irrelevant.
9. **A-PROC wording.**
   - **If the lemma is proved:** "A-PROC (NATIVE): from `cml_main` entry to exit, each real EL0 step with the real bits B changes x0–x30, SP_EL0, PC, NZCV and mapped memory as one L3 `Next` step from the same state does. A step that `Next` marks with an exception ends the process without further effect. B does not change during the run. Every data address is untagged. Kernel and FFI act as `real_mc B`'s oracles."
   - **If the lemma is not proved:** the same text, but each step is compared with `NextStateARM8` from the ERASED state (TBI0 = TBI1 = SA0 = F, other fields equal). Two extra conditions apply: every branch target has bits 63:55 = 0, and no SP-based access happens while SP is misaligned; otherwise the process faults.
10. **Effort** (GUESS):
    - Lemmas L1 and L2 plus the controls: minutes.
    - The frame lemma and the generic `Next_erase` (a library of commuting lemmas plus a case split on the decoded instruction): 2–5 days. This is the heaviest step for memory.
    - The lift to `evaluate` and `machine_sem`: 1–3 days.
    - The stub PCs and the instance for this program: hours, but it loads the full M1 heap.
    - **First lemma to run:** `BranchTo_erase_untagged`, with N1a, N1b and P1. It needs only the arm8 heap.

**Files written** (both DRAFTS, not run):
- <session scratch folder>/m1b/Z2/erasure_DRAFT.sml
  - It holds definitions `erase`, `bits_of`, `restore`, `untagged`, `real_mc` and `lo55`, with all lemmas.
  - Open goals use `NO_TAC`: no cheat, no mk_thm.
  - Controls: N1a (tagged branch, TBI0), N1b (bit 55, TBI1), N2 (SA0 with SP = 8), N3 (E0E cannot be erased), N4 (a slide with tagged code), P1 (a positive control).

**Commands RAN:** read-only grep, sed, cat, awk, ls, find and one python3 calculation. All exited 0, except one grep whose zsh glob had no match (exit 1, harmless). No HOL, no Dafny, no build, no git write.

**Could not determine:** the Arm manual text; HAS_APPLE_PAC in the shipped kernel; whether the backend exposes a no-fault lemma; the PCs of the 27 stub steps (not exported); the value of ffi_offset (I assumed 16 from the export comment).

| step | status | evidence or blocker |
|---|---|---|
| 1 places that read the bits, side conditions | done (READ) | arm8Script lines above |
| 2a SP base | stub: no SP base; compiled code: not provable from the stored theorem | export 50–76; targetSem 52–58 |
| 2b branch bound | NOT in the stored premises; P-LO55 needed | s2-0003 `slide_ok`; N4 |
| 2c interference | condition stated (NATIVE) | asmProps 77–78; arm8_target 365–368 |
| 3 corollary, draft, controls | drafted, not run | erasure_DRAFT.sml |
| 4 A-PROC, TBID0 | wording given; TBID0 partly unknown | proc_reg.h 911–916 |
| 5 effort | estimated | — |

| link id | proposed class | evidence |
|---|---|---|
| X5 | ASSUMPTION (wording: the erased state, plus the new premise P-LO55) | findings 3 and 9 |
| X11e | MISSING (draft only) | erasure_DRAFT.sml |
| X11 | ASSUMPTION (A-PROC, A-INT) | finding 9 |


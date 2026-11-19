# Step D11: the processor state bits that CakeML requires against what Linux and macOS give user space (Y11, Opus; reading and public sources; no HOL, no build)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

## Y11 report: the `arm8_ok` processor-bit risk (links X5, X11)

**Findings**
1. **Exact premise** (READ). `arm8_ok ms <=> ms.PSTATE.EL = 0w /\ ~ms.SCTLR_EL1.E0E /\ ~ms.SCTLR_EL1.SA0 /\ ~ms.TCR_EL1.TBI1 /\ ~ms.TCR_EL1.TBI0 /\ (ms.exception = NoException) /\ aligned 2 ms.PC` (cakeml `cd915569`, `compiler/encoders/arm8/arm8_targetScript.sml` 20–26). The same bits are repeated in `refund_entry_pre_sl` (`results/refund-slide-local-20261117/attempt-0001/s2-0003.sml` 54–57). Neither premise mentions SCTLR_EL1.A or SP.
2. **The check runs at every step, not only at entry.** `targetSemScript.sml` 129 gives Error unless `EVERY state_ok [ms;ms1;ms2]`. `good_init_state` (444ff) requires `target_state_rel`, which includes `state_ok` (asmProps 59). `interference_ok` (asmProps 77–78) with `arm8_proj` (arm8_target 365–368) keeps PSTATE, SCTLR_EL1 and TCR_EL1 fixed across FFI. No L3 instruction writes these fields: the only record updates in `arm8Script.sml` are REG, SP_ELx, PC, MEM, NZCV, branch_hint and exception.
3. **What each bit changes in L3** (HOL `9783a499`, `arm8/model/arm8Script.sml`):
   - TBI0/TBI1 are read only in `BranchTo` (538–592). At EL0 the model clears the top byte of a branch target when TBI0 is set and bit 55 = 0. Loads and stores never use TBI; memory is a flat 2^64 map.
   - SA0 is read only in `CheckSPAlignment` (605–627). That check runs only for loads and stores whose base register is 31 (SP) (about 1754, 1872, 2023, 2099).
   - E0E is read only in `BigEndian` (655–663). It byte-reverses multi-byte accesses.
   - A is read in `CheckAlignment` (628–653) through `SCTLR`, which gives SCTLR_EL1 at EL0 (515–529). It faults only on unaligned non-atomic accesses.
   - The model has no nRW field (AArch64 only) and no TBID.
4. **Real values (sourced and quoted; files saved).**

| field | Linux v6.12 | XNU xnu-11215.1.10 | premise |
|---|---|---|---|
| TBI0 | 1: `proc.S` 471 `TCR_TBI0` | 1: `proc_reg.h` 1033 `TCR_TBI0_TOPBYTE_IGNORED` | FALSE |
| TBID0 | not set (line 471; only TBID1 at 41–56) | 1 if HAS_APPLE_PAC (914–916); H13 (M1) has `CPU_HAS_APPLE_PAC 1` (`H13.h` 52). The step from CPU_HAS_APPLE_PAC to HAS_APPLE_PAC was NOT found | not modelled |
| TBI1 | 1 only with KASAN_SW_TAGS or MTE (41–56) | 1 only with CONFIG_KERNEL_TBI (1016–1020); release setting not found | false on MTE kernels |
| SA0 | 1: `sysreg.h` 893–899 | 1: `proc_reg.h` 667–671 | FALSE |
| A | 0: absent from 893–899 (defined at 859) | 0: absent from SCTLR_EL1_DEFAULT | not a premise |
| E0E | 0 unless CONFIG_CPU_BIG_ENDIAN (883–887) | 0: `SCTLR_E0E_BIG_ENDIAN` (580) absent from default | true |
| EL / nRW | EL0t AArch64 (`processor.h` 303) | `PSR64_USER64_DEFAULT` (517) | true |

   The XNU values are build defaults. I did not check changes per process at run time. I did not fetch or quote the Arm ARM (DDI 0487). The bit positions agree in both headers: TBI0 = bit 37, TBID0 = bit 51, SA0 = bit 4, A = bit 1, E0E = bit 24.
5. **Consequence** (part READ, part GUESS):
   - A model state that copies the real registers bit for bit fails `arm8_ok` on both operating systems. `evaluate` then gives Error at step 1. So the premise is literally FALSE for a faithful copy. It is true only for an "erased" copy (TBI0, TBI1, SA0 set to F).
   - Soundness of the erasure:
     - **TBI:** the model's `BranchTo` gives the same result for any TBI value when target bits 63:55 = 0. On macOS, TBID0 = 1 probably means real branches never strip the tag, which is the model's TBI0 = F behaviour. On Linux, real branches strip the tag (TBID0 = 0). Either way the result is the same for untagged targets. A real data access with a tag reaches the untagged page, but the model treats it as a different address. CakeML accesses only addresses that `mem_domain` admits (asmSem asserts 200–223).
     - **SA0:** CakeML has `avoid_regs [18;26;31]` (arm8_target 350). The macOS `cml_main` (ret = F path, `export_arm8Script.sml` 50–76) does not touch SP. So `CheckSPAlignment` is probably never reached in the model. The `cml_enter` path, which uses `[sp,#-32]!`, is not used. The Linux route-A stubs: unknown.
     - **A:** asmSem asserts alignment, and `arm8_step` derives load/store theorems only under `Aligned` (step 483–486). The proposed Linux `ffiwrite` stub needs A clear; both kernels give A = 0.
   - **Repair lemma (DRAFT, not run, not type-checked):** `s.PSTATE.EL = 0w /\ (63 >< 55) t = 0w ==> BranchTo (t,bt) (s with TCR_EL1 := x) = (BranchTo (t,bt) s) with TCR_EL1 := x`. This also needs a frame lemma: NextStateARM8 never writes TCR_EL1 or SCTLR_EL1. It also needs proofs that every encoded instruction avoids base register 31 and keeps branch targets below 2^55. Then a whole-run simulation between the real-valued and the erased state. That simulation still sits inside the X11 assumption, because real hardware is not L3.
   - **Named assumption wording if no proof:** "A-PROC: from `cml_main` entry to exit, each real EL0 step of the process has the same effect on x0–x30, SP_EL0, PC, NZCV and mapped memory as one `NextStateARM8` step from the same state with TCR_EL1.TBI0 = TBI1 = F and SCTLR_EL1.SA0 = F, given that every branch target has bits 63:55 zero and no access uses SP as base."
6. **Can user space see these bits?** Not directly: they are EL1 registers. Indirect tests (described only, not built, not run):
   - Load through a pointer with tag 0x01 on a valid address. Success means TBI0 = 1 for data.
   - BR to a code address with a tag. A fault means TBID0 = 1 (macOS); success means the tag was stripped.
   - Make SP odd by 8, then `ldr x0,[sp]`. SIGBUS means SA0 = 1.
   - `ldr x0,[x1]` with x1 odd. Success means A = 0.
   - Store halfword 0x0102, then read byte 0. A result of 0x02 means E0E = 0.
7. **The existing macOS M1 theorem is hit today.** The theorem stays valid as a machine-model statement. But X5/X11 assume, without saying so, that the real state is an erased state, and that the erasure is sound. That condition must be named or proved.

**Files written:** `<session scratch folder>/m1b/Y11/src/` (11 downloaded primary source files: linux_*.h/.S/.c/.rst at v6.12; xnu_proc_reg_xnu-11215.1.10.h, xnu_proc_reg_xnu-10063.101.15.h, xnu_H13.h, xnu_board_config.h).

**Commands RAN:** `curl` fetches from raw.githubusercontent.com: 13 exit 0, 2 exit 56 (404: xnu-11417.1.4 tag, T8103.h). Read-only grep/sed: exit 0. No HOL, no build, no git write.

**Could not determine:**
- That HAS_APPLE_PAC is defined in the shipped macOS kernel.
- XNU changes to SCTLR/TCR per process at run time.
- Arm ARM quotes.
- SP use in the Linux route-A stubs.

| step | status | evidence or blocker |
|---|---|---|
| 1 premise fields | done (READ) | arm8_target 20–26; s2-0003.sml 54–57; targetSem 129, 444ff |
| 2 Linux/XNU values | done, except TBID0 config and the ARM ARM | table above |
| 3 consequence | analysed; lemma is a DRAFT | BranchTo 538–592; CheckSPAlignment 605–627 |
| 4 observation | described only | none run |
| 5 macOS impact | yes | finding 7 |

| link id | proposed class | evidence |
|---|---|---|
| X5 | ASSUMPTION (wording must add the erasure, A-PROC) | real TBI0 = SA0 = 1 on both kernels; the premise needs 0 |
| X11 | ASSUMPTION | the erasure is unproved; the lemma is a DRAFT |
| X11-erasure (new) | MISSING | needs the BranchTo, frame and no-SP-base lemmas above |

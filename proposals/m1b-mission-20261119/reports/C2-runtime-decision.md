# Step C2: B2c proof-surface audit and run-time decision (X6, Opus, read-only; nothing built or run)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

## X6, step C2: B2c proof-surface audit and runtime decision

I worked read-only. I built, assembled, linked and ran nothing. I did not run HOL, Holmake, poly, Dafny or Docker. I changed no repository file and ran no git command that changes state. The only script that ran is `classify.py` in my folder. It reads the two replay plan files.

**Recommendation: no build or rewrite now. Run one build-free B2c probe first (M-B2c-0 below). B1 cannot close the argument.**

Files:
- Draft: `<session scratch folder>/m1b/X6/RUNTIME_DECISION.md` (sections 0–8)
- Script: `<session scratch folder>/m1b/X6/classify.py`

Source labels: CK = `.toolchain/experiments/refund-cakeml-20261104/cakeml`; L3A = `.toolchain/experiments/refund-cakeml-20261104/HOL/examples/l3-machine-code/arm8`.

### Main findings
1. **The code bytes do not depend on the platform** (pinned source; not confirmed by a build).
   - The exporter writes the compiled bytes and the bitmaps the same way for macOS and Linux (CK `compiler/backend/arm8/export_arm8Script.sml` 241–255). Only the assembler macros differ (36–48).
   - The compiler never uses x18 (CK `compiler/encoders/arm8/arm8_targetScript.sml` 349–350).
   - `installed` and `good_init_state` (CK `compiler/backend/semantics/targetSemScript.sml` 444–521) do not mention `malloc`. A fixed `.bss` region meets every clause.
2. **A runtime that fails closed removes half of route A.** The design exits with `exit_group(2)` on every invalid argument, every syscall error, and every call to close, open_in or install. Then the safety theorem does not need the reachable-call proofs L2 and L3; they matter only for liveness. It still needs L1 (totalisation), the per-call contract at valid calls, and a native simulation.
3. **L-EXIT holds by construction.** `cml_exit` gives status 0 only if x0 = 0, which is the model's Success test (`targetSemScript.sml` 138–140). The lemma "x0 ∈ {0,1,2}" is no longer needed. Today x0 = 256 would exit with status 0.
4. **The processor assumption may be literally false (new risk).**
   - CakeML's `arm8_ok` requires TBI0 = F and SA0 = F (`arm8_targetScript.sml` 20–26).
   - By general knowledge, not checked, Linux arm64 sets both to 1 at EL0. The authority would be the kernel `arch/arm64` source.
   - The macOS chain has the same open point: U277 says the real values were never observed.
   - Fix: an abstraction lemma, or a named assumption.
5. **The prefix is not strict.** `extend_with_resource_limit` (CK `semantics/proofs/semanticsPropsScript.sml` 219–226) allows a resource stop after the last write. So a non-zero exit can come with the complete output. The owner's "strict prefix" form is stronger than `compile_correct` gives.

### The B2c surface in numbers
- **Shape:** a static ELF64, ET_EXEC, AArch64 file with no interpreter, no libc, no relocations and a `.bss` heap. It needs a new SHA-256. The macOS file `b8ed5ec2…7bb8` and all its records stay unchanged.
- **Hand-written instructions: 84.**

| routine | instructions | note |
|---|---|---|
| `_start` | 16 | writes the 3 slots, then `b cml_main` |
| `ffiread` | 25 | fd 0 only |
| `ffiwrite` | 31 | fd 1 only |
| `ffi_fail` | 4 | includes 1 guard |
| `cml_exit` | 5 | includes 1 guard |
| traps (close, open_in, install) | 3 | `b ffi_fail` each |

- `cml_main` stays 27 executed words, with new `adrp` values.
- **Instructions run before the CakeML code: 43.** M1 runs about 92, plus `getenv` and `malloc`.
- No stack is used, so the C-stack premise disappears.
- **Syscalls:** 4 `svc` sites, 3 syscall numbers (63 read, 64 write, 94 exit_group). The numbers are general knowledge, not checked.
- Every instruction class used is in `arm8_stepLib.sml`, except `svc`. Pinned L3 treats `svc` as a fault (L3A `model/arm8Script.sml` 2425–2434; L3A `step/arm8_stepScript.sml` 19–22). So each `svc` is a step that a stated relation replaces.
- **Named assumptions: 6.** `linux_execve_rel`, `linux_read_rel`, `linux_write_rel`, `linux_exit_rel`, `proc_rel` (processor) and `iso_rel` (no other writers). Section 1.5 has candidate HOL forms: the kernel may change only x0, and for read only the buffer range.
- **Present program:** it links 4 FFI names (read, write, close, open_in; U391). It can use the routines unchanged, with close and open_in as traps that fail closed.
- **Bounded 192-byte protocol:** it gives bounded stdin and a short numchars witness, and it covers every input. But F2.7 is a new CakeML program: only about 14 generic theories carry over.

### Classification of the 95 theories
Wall times are recorded replay seconds, not development effort.

| class | count | replay wall (s) |
|---|---|---|
| (i) reusable unchanged: T01–T09, C10–C37, C39, C41, C47, B01–B07, B09–B19 | 58 | 4,091.3 |
| (ii) re-instantiated: C38, C40, C42–C46, C48, C49, C60, C70, B20 | 12 | 983.6 |
| (iii) obsolete or not used: C50–C59, C61–C69, C71, B08, B21–B24 | 25 | 3,907.0 |
| (iv) new | about 17 (N1–N17) | — |

Two theories have 0 s recorded; the plan's 60 s each is not added.

### Comparison (section 4 has the full tables)

| | B1 | B2c | B2c + 192-byte frame |
|---|---|---|---|
| Trusted below the proof | XNU, dyld (mapping, fixups, 23 GOT binds), libSystem getenv/malloc/read/write/exit/fwrite/abort, the C stack, processor, isolation, stdin | the 6 named assumptions + stdin + fd-1 reader + ELF reader | the same + 10 F2.7 spec items + the A-SIGN signer |
| Assumptions with no possible proof | B1-2, B1-6, B1-12, the GOT binds; libSystem cannot be pinned | the 6 relations | the same |
| Obligations | 16 (B1-1…16; only slides done) | 20 (O1–O20): 2 minutes, 11 hours, 1 hours–days, 2 days, 1 minutes–hours, 2 minutes (O9, O12); shapes stored for 11, partly for 3 | O1–O20 + the F2.7 source chain |
| Reuse | 95 / 0 / 0 | 58 / 12 / 25 | about 14 generic + method |
| Failure modes | 7 listed (e.g. OS update, `exit()` truncation, `malloc` exclusivity, abort path, read error = exit 0 with empty output) | 10 listed (e.g. TBI0/SA0, unaligned loads, read returning 0 before EOF, not the owner's platform, signals/OOM, simulation direction) | B2c + 6 |

### Candidate complete theorem (section 5; not proved)
- **Premises:** the exact ELF file, the 6 named assumptions, and canonical stdin.
- **Conclusion 1:** at every point of every run, the bytes accepted on fd 1 are a prefix of R.
- **Conclusion 2:** if the process exits, then either status = 0 and output = R, or status ≠ 0 and output is a prefix of R.
- R = `refund_render_fields (refund_fields …)`.
- **L-OUT:** the `extract_fs` stdout change equals the joined `TAKE nw (DROP (4+off) …)` of the successful fd-1 write events.
- **L-EXIT:** from the `cml_exit` step theorem and `linux_exit_rel`.
- **Kept separate:** a resource stop (status 1), a fail-closed exit (status 2) and a kill (no status) never authorize. Only status 0 with output = R, plus the B3 caller contract, can authorize. No completion or memory bound is claimed.

### Smallest milestone: M-B2c-0
- **Statement (candidate, not type-checked):** take the 31 proposed `ffiwrite` words at a symbolic address p, a valid call (clen = 8, conf = fd 1, n + off + 4 ≤ alen), `arm8_ok` and SCTLR_EL1.A clear. Then 22 L3 steps reach the `svc` with x8 = 64, x0 = 1 and the right buffer and count. Then, after `linux_write_rel` with k ≤ n, 8 more steps return to x30. Memory then equals `asm_write_bytearray x2 (0w :: n2w2 k ++ o0 :: tll)`, and x19–x25, x27, x28 are kept.
- **Oracle corollary:** with the numchars head = k, this equals the `ffi_write` answer (CK `basis/fsFFIScript.sml` 333–348).
- **Needs:** the arm8_step heap and the cake heap; no build.
- **Time:** hours.
- **Negative controls:** `b.ls` instead of `b.lo`; k = n+1 reaches `exit_group`; fd 2 reaches `ffi_fail`; swapped `strb` words.
- **Route is alive** if it proves with only these premises. It is **costly or dead** if a premise appears that Linux cannot meet.
- **Not yet:** no runtime source, build, Linux host, new executable, exporter edit, change to the macOS records, or claim of verified native execution.
- **Owner decisions:**
  1. Approve the probe.
  2. Is Linux ARM64 an acceptable deployment platform?
  3. Later: a Linux ARM64 host for native tests.
  4. Later: a new digest and a new conformance run.
  5. Accept the 6 assumptions as a new profile ("Profile L").
  6. Whether to try a custom two-call I/O FFI with F2.7.

### Links for the top-level graph
- Every new B2c link is MISSING or ASSUMPTION; none of the assumptions is approved or written as HOL yet.
- The only MACHINE-CHECKED links are the layout-independent CakeML ones: `refund_compile_correct_no_handler` (U386) and the source output specs (U387, U388). They hold for the model only.
- The first missing link in execution order is ELF file → image theorem (O1). In proof order it is the `ffiwrite` step and contract theorem (M-B2c-0) and L1.

### Could not determine
- The real Linux EL0 values of TBI0, SA0 and SCTLR_EL1.A.
- Whether CakeML array and conf pointers are always 8-aligned.
- Whether the `code` term is literally identical in a Linux build (no build).
- The real `cbspace` and link addresses.
- The read buffer size and the number of reads per run.
- Whether the basis ever calls close at program end.
- The FFI names of an F2.7 program.
- Whether the native-to-model simulation (O15) fits in days; no stored proof has that direction.

| step | status | evidence or blocker |
|---|---|---|
| C2 (X6 runtime-decision) | REPORTED | RUNTIME_DECISION.md and classify.py in the scratch folder above. Sources: export_arm8Script 10–116, 227–255; exportScript 22–124; targetSemScript 118–234, 285–366, 444–521; arm8_configProofScript 11–19; arm8_targetScript 20–26, 343–381; fsFFIScript 187–348; fsFFIPropsScript 202–228, 1310–1317; semanticsPropsScript 219–226; backendProofScript 194–197, 4952–4968; ag32_basis_ffiProofScript 143–193, 348–365; L3A model/arm8Script 368–375, 2425–2434, 3630; L3A step/arm8_stepScript 19–35; arm8_stepLib coverage; basis_ffi.c 60–200, 721–890; plan.json and plan-phase2.json; U277, U345–U409. Nothing built or run. |
| M-B2c-0 probe | BLOCKED | needs the owner's approval of a local HOL run, with limits shown first |

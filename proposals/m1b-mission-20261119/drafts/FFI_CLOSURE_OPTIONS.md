# B2: closing the execution argument (worker X2, ffi-refinement)

Study only. No HOL run. No repository file changed. The executable was copied
to this folder and inspected with `nm -n`, `otool -tV`, `otool -l` (all exit 0).
It was never run. Copy SHA-256 `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`,
238,776 bytes (equal to the pinned hash in `run_case.py`, per V report).
Work files: `nm.txt`, `tv.txt` in this folder.

"Proved" below means: a stored record shows the theorem with exit 0. The record
is named. All M1 records are local, one machine, cached parents, no clean or
independent replay (as each U entry says).

Pinned tree root: `C = .toolchain/experiments/refund-cakeml-20261104/cakeml`.
L3 root: `L = .toolchain/experiments/refund-cakeml-20261104/HOL/examples/l3-machine-code/arm8`.

---

## 1. Native code on the path of one refund run

### 1.1 Inventory (instruction words from `otool -tV`, bounds from `nm -n`)

| Address | Symbol | Words | Role | Reachable on a canonical run? | Evidence |
|---|---|---|---|---|---|
| (dyld) | loader, chained fixups, 23 GOT binds | n/a | maps the file, binds `__got`, calls `_main` | yes | `otool -l`: LC_MAIN entryoff 152900 = 0x25544 = `_main` |
| 0x100025544 | `_main` | 47 | stores argc/argv, 2 x `cml_memory_size`, `malloc(heap+stack)`, stores `cml_heap`/`cml_stack`/`cml_stackend`, `bl _cake_text_begin` | yes | disassembly; source `C/basis/basis_ffi.c` 879-885, 849-876 |
| 0x100025600 | `cml_memory_size` (static) | 44 | `getenv`; if unset returns 0x40000000 (1 GiB); else `strtoull`, checks | yes, twice | disassembly 0x100025684 `mov w0,#0x40000000`; source 827-840 |
| 0x1000256b0 | `cml_runtime_error` | 34 | `fputs`/`vfprintf`/`strerror`/`fprintf`, `exit(3)` | only on bad env value, size overflow or `malloc` failure | source 71-82 |
| 0x100004000 | `cml_main` (export startup) | 28 (27 executed) | heap header (5 words), loads x0..x3, `b cml__Init_0` | yes | `C/compiler/backend/arm8/export_arm8Script.sml` 22-80; proved, U405 `cml_main_run_sl` |
| 0x100004070..0x1000040C0 | `cake_ffiopen_in`, `cake_fficlose`, `cake_ffiwrite`, `cake_ffiread`, `cake_install`, `cake_exit` | 1 executed each (`b` + 3 nop) | jump stubs | read, write, exit: yes. close, open_in: by inspection no (U396). install: excluded in the model (U384, U386) | export_arm8Script.sml 82-116 |
| 0x100025170 | `_ffiread` | 28 (+2 cold x 10) | assert clen=8, n+4<=alen; `read(fd, a+4, n)`; a[0], a[1..2] | yes (stdin, at least 2 calls: data, then EOF; count inferred, not checked) | source 160-173 |
| 0x1000251E0 | `_ffiwrite` | 32 (+2 cold x 10) | assert clen=8, n+off+4<=alen; `write(fd, a+4+off, n)` | yes (`print`, U397/U399) | source 175-189 |
| 0x100025260 | `_fficlose` | 19 (+2 cold x 10) | | no by inspection (U396) | source 191-197 |
| 0x100025098 | `_ffiopen_in` | 25 (+1 cold x 10) | | no by inspection (`inputAllFrom None`), not proved | source 138-147 |
| 0x100025464 | `_cml_exit` | 16 | if w0<>0: `fwrite` to stderr; `exit(w0)` | yes (from `cake_exit` at halt_pc 0x1000040C0) | source 723-741 |
| 0x100025504 | `_cml_install` | 16 | `memmove`, `__clear_cache` | no (installer exclusion, model) | source 802-822 |
| 0x1000254a4 | `_cml_err` | 23 | | no caller on the path (not checked further) | |
| 0x100025000.. | `ffiget_arg*`, `ffiopen_out`, `ffiexit`, `fficustom`, `ffidouble_*`, `ffipoll_sigint`, `ffikernel_ffi`, `ffi` | 206 total | linked, not in the program's 4 FFI names | no (no stub jumps to them; only 4 FFI names, U391) | `nm` |
| 0x1000258C8 | `__stubs` | 22 stubs x 3 = 66 | `adrp x16; ldr x16,[x16,#..]; br x16` | used: getenv, malloc, read, write, exit (5 stubs = 15 words); plus `___error`, `strtoull` only if an env value is set | `otool -tV` |
| 0x1000040D0 | CakeML code | 32,609 words to 0x100023E54 | | yes | proved region (U389) |
| libSystem / dyld shared cache | `getenv`, `malloc`, `read`, `write`, `exit` (+ `fwrite` only on nonzero exit) | not in the file | | yes | not pinned (V M1) |

Hand-written native code that one canonical run executes inside the file:
`_main` 47 + `cml_memory_size` 44 (executed twice; the unset path is about 9 words)
+ `cml_main` 27 + 3 FFI stubs + `_ffiread` ~25 + `_ffiwrite` ~29 + `_cml_exit`
~6 (zero branch) + 5 import stubs x 3. That is about **200 distinct words**.
Everything else that runs natively is outside the file (dyld, libSystem, kernel).

### 1.2 Arguments at the reachable calls (from M1 and the code)

- write: fd 1 from the 8-byte config (only bytes 4..7 are read by the compiled
  code: `ldr w8,[x0,#4]; rev w0,w8` at 0x100025218); count n and offset off from
  a[0..3]; U400 proves at reachable model states from a SUCCESSFUL write event:
  `REG 1 = 8` and `n + off + 4 <= w2n x3`. Failed write events: open.
- read: fd 0; n from a[0..1]; no M1 call-site theorem for read.
- exit: `ptr_reg` = x0 (`C/compiler/backend/arm8/proofs/arm8_configProofScript.sml` 15);
  the model gives `Halt Success` iff x0 = 0 at halt_pc
  (`C/compiler/backend/semantics/targetSemScript.sml` 138-140). `_cml_exit` passes w0 to `exit`.
  So Success = exit 0; Resource_limit_hit = nonzero exit plus one stderr line.
  This mapping is by reading code; no theorem covers `_cml_exit`.

### 1.3 Facts found in this study (by reading, not proved)

- F1. The compiled `byte8_to_int` reads only c[4..7] (int return). The model
  decodes all 8 bytes (`w82n conf`, `C/basis/fsFFIScript.sml` 307-357). They agree
  when c[0..3] = 0. A relation must state this.
- F2. The oracle and the C code disagree on invalid arguments. `ffi_write` returns
  an error byte when `LENGTH conf <> 8` (fsFFIScript.sml 333-349, `od ++ return
  (FFIreturn (LUPDATE 1w 0 bytes) fs)`); the C code calls `__assert_rtn` (abort).
  `ffi_read` is the same (307-325). `ffi_close` also returns an error byte when the
  asserts fail (351-362). So even an oracle-conditional contract (ag32 style, see 3.2)
  is false for the real code at invalid call states. Only a reachable-call form can hold.
- F3. The model write may return 0 bytes (`k = MIN n strm`, fsFFIScript.sml 214-232);
  the model read returns at least 1 byte when data remain (`SUC strm`, 187-196).
  A real `read` that returns 0 before end of data, or -1 (EINTR/EIO/EAGAIN), is
  outside the model. Q2 excludes EIO/EINTR; EAGAIN on a non-blocking stdin is
  NOT covered by Q2 (U-entry near unsure.md line 10930 observed EAGAIN on an
  empty non-blocking pipe).
- F4. In the pinned L3 model, `svc` raises `UNDEFINED_FAULT`
  (`L/model/arm8Script.sml` 2425-2434) and `NextStateARM8` returns NONE on any
  exception (`L/step/arm8_stepScript.sml` 19-22). So no route can step through a
  system call in L3. Every route ends at a named kernel-transition assumption.
- F5. Default heap+stack is 2 GiB from `malloc` (two 1 GiB sizes). The M1 premise
  only needs `8192w <=+ e - h` (P4). The C stack (hardware sp) is the process
  stack from dyld; C frames of the FFI functions go there (U393 "sp = b + 32").

---

## 2. Route B1: prove that the existing C/FFI machine code refines the model

### 2.1 What would be proved

For each reachable FFI name N in {read, write}, on the exact bytes, in L3:

    reachable model call state at cake_ffiN (slide sl)
      ∧ call facts V_N (clen = 8, bound, alignment, frame outside dm, c[0..3] = 0)
      ∧ N_call_rel dm s1 s2         (ASSUMED: libSystem + kernel)
      ⇒ the real path stub → C → import stub → [call] → C suffix
        ends in a state that satisfies the contract clause of
        refund_ffi_contract_at for the oracle's new_bytes.

Then a lift from "contract at reachable calls" to the machine-level theorem
(U405 proposal L1-L3), and a simulation from the real process to the model
machine (the analogue of ag32's `interference_implemented`, see 3.2).

Stays assumed below the boundary: `read_call_rel`, `write_call_rel`,
`exit_call_rel` (libSystem + XNU), `getenv`/`malloc` results, dyld binding of the
GOT slots 0x100028000.. (`g` is a variable in U393/U397), dyld mapping (Q3a), the
processor = L3 for the used words, `SCTLR_EL1.A` clear, EL0, no signals.

### 2.2 What M1 already has (names and stated limits)

| Name | Record | Content | Stated limit |
|---|---|---|---|
| `cake_fficlose_path`, `cake_fficlose_path_contract_instance` | U394, compose-0018 | close: 15 + call + 6 steps; contract conclusion for index 2 | `close_call_rel` assumed; clen=8, alen>=1 premises; close not reachable (U396), so vacuous for refund |
| `close_call_site_arguments`, `..._signed_alen` | U395, U396 | x1=8, x3<>0 at reachable model close calls | signed bound needs new premise `addresses_below_half` |
| `cake_ffiwrite_to_import_branch` | U397 | write: 23 steps to `br x16` under `ffiwrite_call_pre` (19 conjuncts) | `g` variable |
| `cake_ffiwrite_path_successful_write`, `cake_ffiwrite_path_returns` | U398, wsucc-0002 | both outcomes; return to x30, sp, x19-x28 restored, dm changed only at a, a+1, a+2 | `write_call_rel` ASSUMED "says nothing about output"; new premise not `SCTLR_EL1.A` |
| `refund_terminating_run_reaches_write_call` | U399, reach-0009 | Success + non-empty output ⇒ reachable call at 0x100004090 | model only |
| `refund_terminating_run_reaches_valid_write_call` | U400, args-0006 | x1 = 8 and `n + off + 4 <= w2n x3` | successful write events only; "failed write events and 16 call-state conjuncts stay open" |
| `forge_refundWriteWord` (19 theorems) | U401, word-0003 | bound equals word-level conjunct; `ffiwrite_call_pre` = PC, x1 = 8, bound and a **12-conjunct residual**; `replay_ignores_failed_write_with_valid_clen` | "NOT derived: not word_msb x3"; "the exported file-system specification cannot imply that every write event is successful" |
| `ffiread_error_return` | U348 | 6-step error suffix of `_ffiread` on exact bytes | "Not covered: the ffiread prologue and call ... the read system call; the success path" |
| `cml_main_run_sl` | U405, s1-0001 | 27 start-up steps at every `slide_ok` | entry state assumed |
| `refund_profile_a_sl` | U409, e4-0001 | output equation under `refund_env_ok_sl` | premise "probably false for the real C code at every state" |

### 2.3 What blocked full closure

1. The published `ffi_interfer_ok` (targetSemScript.sml 317-366) quantifies over
   every call state with readable arrays and every `new_bytes`. The real code
   aborts at invalid states (U393; F2). So the literal premise cannot be
   discharged for any faithful model of the real code.
2. Call-site facts come only from successful events. The source spec exports only
   `extract_fs`, which ignores failed writes (U400, U401). So clen = 8 at a FAILED
   write call is not derivable without an event-level invariant.
3. Step library alignment hypotheses (U397, fixed in U398 with a new premise).
4. `not word_msb x3` not derivable (heap premises admit huge heaps, U396).
5. Nothing exists for read except the error suffix.
6. No relation between the real process and `machine_sem` (A3 "NOT formalized").

### 2.4 Remaining work as lemmas (sizes in recorded M1 entries; my estimate, low confidence)

| # | Lemma | Size |
|---|---|---|
| B1.1 | `cake_ffiread_to_import_branch` (~20 steps, analogue of U397) | 3-6 |
| B1.2 | `cake_ffiread_path_returns`: success suffix (10 steps, `sturh`, as U398) + U348 error suffix, joined | 2-4 |
| B1.3 | `read_call_rel` definition + reachable read facts (x1 = 8, n + 4 <= alen) from read events (U399/U400 analogue) | 4-8 |
| B1.4 | write residual: 12 conjuncts (alignment, stack placement, separations), `not word_msb x3` (needs heap bound premise), failed-write events (event-level invariant through `compile_correct'`) | 5-12 |
| B1.5 | formal unreachability of close and open_in (no such event in any trace) | 3-6 |
| B1.6 | U405 L1/L2/L3: totalised effect, agreement of real-effect and totalised machines, V per name | 4-8 |
| B1.7 | real-process simulation for arm8: a relation `refund_native_rel` and an analogue of ag32 `machine_sem_Terminate_FUNPOW_next` (C/compiler/backend/ag32/proofs/ag32_basis_ffiProofScript.sml 348-366), with external calls as relations; includes the nondeterminism choice (numchars prophecy: the theorem is ∀fs, so for a real run one must exhibit an fs whose `numchars` reproduces the kernel's counts) | 8-15 |
| B1.8 | entry path: `_main` 47 + `cml_memory_size` (unset branch) + `getenv`/`malloc` relations ⇒ `refund_entry_pre_sl` | 5-10 |
| B1.9 | exit path: halt_pc → `_cml_exit` → `exit_call_rel`; nonzero exit on Resource_limit_hit | 2-4 |
| | total | 36-73 entries = 0.55-1.1 unit |

Entry path: tractable the same way. `_main` is straight-line except two error
branches; `cml_memory_size` with env unset is ~9 words. The hard part is not the
words. It is the three library results (`getenv` returns NULL, `malloc` returns an
aligned block that dyld/libSystem never touch again, the stack is outside dm),
which stay assumptions.

Residual trusted base of B1: libSystem `read`/`write`/`exit`/`getenv`/`malloc`
(large, unpinned, in the dyld shared cache), XNU, dyld mapping and binding,
L3 = processor, HOL4. This is smaller than "A3" only by the ~200 file words.

---

## 3. Route B2: replace the runtime by a minimal one

All B2 options create a NEW executable with a NEW SHA-256. Every M1 theorem that
names the file bytes must be redone: U389 (file slices), U393-U401 (FFI paths),
U404-U409 (slide work, if layout or PIE changes), U348. By the titles of
U345-U409, about 25 of the 65 entries name exact bytes or addresses of this
file (U346, U348, U355, U359, U388-U401, U404, U405, U407, U409, plus parts of
U384-U386 that re-check code identity). The CakeML-side theorems (U364-U387
compile facts, lab-level exclusion, source non-Fail) depend on the compiler
output `code`/`data`, which stays the same if only the C runtime changes and the
FFI name list and export layout stay the same. Not checked: whether the stored
`code` term is independent of the runtime link (it should be: the C file is
linked after compilation).

### 3a. Freestanding startup + 3 FFI functions with direct kernel calls

- Code: `start` (set sp, heap = a fixed zero-fill segment, no malloc/getenv),
  `ffiread`/`ffiwrite` (~20 words each: arg checks that FAIL CLOSED by exit, not
  abort; `svc`), `cml_exit` (`svc` exit). About 60-80 words, all hand-steppable in L3.
- macOS: Apple documents libSystem as the only supported system interface; raw
  syscall numbers are not a stable ABI, and arm64 macOS user executables are
  loaded by dyld (general knowledge, not checked). So on macOS 3a still has
  dyld, and the kernel boundary is an unversioned, undocumented ABI. The
  theorem would hold for one pinned OS build only.
- Closed theorem: real process (from the dyld hand-off) refines the model, under
  `xnu_read_rel`, `xnu_write_rel`, `xnu_exit_rel` at each `svc`, plus dyld mapping.
- New trusted base: XNU syscall semantics for 3 calls (unstable ABI) + dyld + L3.
- Cost: 0.6-1.3 unit (redo ~25 byte-level entries at lower cost each; F4 means
  each `svc` is an assumption edge, as the libSystem branch is now).

### 3b. Existing verified or smaller runtimes in the pinned tree

- Pinned tree has `C/compiler/backend/ag32/` (Silver ISA): `ag32_memoryScript.sml`
  (3,722 lines: "implement the startup code, the FFI jumps, and the CakeML basis's
  primitive FFI calls in Silver machine code", README), proofs 14,377 lines incl.
  `ag32_basis_ffiProofScript.sml` (7,955 lines): `ag32_interference_implemented`
  (line 7095), `ag32_ffi_interfer_write` (4058), `_read` (4355), `ag32_next` (7467),
  and end-to-end examples `C/examples/compilation/ag32/proofs/helloProof_ag32Script.sml`
  (`hello_ag32_next`, line 165: a statement about `FUNPOW Next k ms0` of the real
  Silver machine, i.e. no oracle left).
- Key design (template value): `interference_implemented_def` (line 143-196)
  requires the FFI code only when `call_FFI ... = FFI_return new_ffi new_bytes`
  and `ffi_rel ms ffi` hold. The FFI is real machine code in the model; I/O is
  memory buffers plus the machine's own `io_events` field; no OS.
- No arm8 analogue exists in the pinned tree. `export_arm8Script.sml` has only
  the hosted C variant (startup lines 22-80, `ret` and `pk` flags). Pancake
  (`C/pancake/`) is a language front end; it still calls FFI externally.
  Not found: a bare-metal arm8 export or a verified arm8 FFI.
- Usability: ag32 runs on Silver (an FPGA CPU), not on a Mac. As a deployable
  target it changes the processor and loses the present hardware. As a TEMPLATE
  for 3a/3c it is directly usable: the relation shape, the `FUNPOW Next` lift,
  and the proof structure. But F2 shows its oracle-conditional clause is still
  false for code that aborts; the new runtime must return the oracle's error
  byte (or exit) on invalid arguments, i.e. be written to match the oracle.
- Cost (port to arm8 + OS boundary): 1.5-3 units; (run on Silver): out of scope.

### 3c. Linux ARM64 static binary, raw `svc`, no dynamic linker

- `export_arm8Script.sml` already emits the non-Apple branch (`#ifndef __APPLE__`,
  lines 36-47). A static, non-PIE ELF loads at a fixed address: slide 0 is then
  TRUE, which removes the S1-S6 slide argument for that artifact.
- Linux syscall numbers and the `svc #0` ABI are stable by kernel policy
  (general knowledge, not checked).
- Closed theorem: for every Linux process created by `execve` of the pinned ELF
  with stdin holding the canonical request, every behaviour is Terminate Success
  with stdout = render(...), or a nonzero exit with output a prefix; under
  `linux_read_rel`, `linux_write_rel`, `linux_exit_group_rel` at the three `svc`
  sites, the ELF loader mapping, and L3.
- New trusted base: Linux `execve` ELF loading + three syscall relations + L3 +
  HOL4. No libSystem, no dyld, no malloc, no getenv.
- Cost: 0.7-1.5 unit. Needs a Linux ARM64 host for conformance (Docker is
  forbidden for this worker; whether the owner allows it is open).

---

## 4. Route A (conditional), made honest

A is honest only if the relation is:
1. **Specific**: it constrains the real FFI only at reachable call states, per
   name (read, write, exit), with the exact arguments (clen = 8, bound, fd from
   c[4..7] with c[0..3] = 0, alignment), and says nothing at other states.
2. **Falsifiable**: it names observable facts that a test or a later proof can
   refute: return to x30; x19-x28 and sp kept; only a[0..2] and a[4..4+k) written;
   k <= n; for read, 1 <= k when data remain; stdout receives exactly the k bytes;
   close and open_in never called; exit code 0 iff Success.
3. **Not the conclusion**: it must not mention `refund_render_fields`,
   `extract_fs` of the whole run, or `machine_sem`. The present
   `refund_env_ok_sl` meets 3 but fails 1 (all states), so it is probably false
   (U393, U409).

Evidence short of proof: the Wave Gate 1 conformance run observed real outputs
equal to the model on 2,466 typed vectors (V report: `exit_m1_conformance.py
--case conformance`, exit 0, attempt-0006). This is a FINITE test. It also does
not observe the internal relation (registers, memory frame), only stdout/exit.
A syscall trace (dtruss/strace) would test the per-call clauses; not run.

---

## 5. Comparison

| | A (conditional) | B1 (prove present C) | B2a (macOS raw svc) | B2b (ag32 template / Silver) | B2c (Linux static) |
|---|---|---|---|---|---|
| Closed down to | model machine; real process only through one stated relation | `bl` into libSystem stubs | `svc` (XNU) + dyld | Silver ISA (no OS) if on Silver; else as 2a/2c | `svc` (Linux) + ELF loader |
| Residual trusted base | relation covers loader, dyld, C, libSystem, kernel, CPU | libSystem (5 functions, unpinned), XNU, dyld, L3 | XNU syscall ABI (unstable), dyld, L3 | Silver ISA model + hardware | Linux syscalls (stable ABI), execve loader, L3 |
| Reused M1 work | all | all; write path, close method, U400 | CakeML-side (U364-U387), method; not byte theorems | CakeML-side; proof shape from ag32 | CakeML-side; slide work NOT needed (slide 0 true) |
| New work (units of 65 entries) | 0.1-0.4 (high confidence) | 0.55-1.1 (low) | 0.6-1.3 (low) | 1.5-3 (low) | 0.7-1.5 (low) |
| New executable / hash | no | no | yes | yes | yes |
| Main technical risk | relation false or vacuous; reviewers reject it as a restatement | libSystem axioms: unverified code, shared heap with malloc, unpinned cache | Apple ABI changes; dyld still trusted | different hardware; large port | conformance host; owner approval; second platform |
| Skeptic attacks | "theorem about an ideal FFI" (C1 stays) | "you moved A3 into libSystem axioms you cannot inspect" | "undocumented syscalls; one OS build" | "not the machine you deploy" | "Linux kernel and L3 still trusted; L3 not Arm's spec" |

---

## 6. Recommendation: smallest credible path

The present C runtime is not the right foundation for a CLOSED argument: its
boundary is libSystem (unpinned, large, shared heap via malloc). B1 still ends at
a libSystem axiom set. The smallest trusted base reachable with the pinned tools
is B2c. But the first steps are runtime-independent and should go first.

1. **L1 (totalisation lemma)** — `refund_ffi_contract_at_totalise` (statement
   below). Control: a `V` that admits an invalid close state must make the
   hypothesis unprovable for the U394 path. HOL minutes. No approval needed
   beyond the normal run rule.
2. **L2 (agreement)**: `machine_sem` with effect `f` equals `machine_sem` with
   `totalise V f` if every call reachable in the totalised machine satisfies V.
   Control: a reachable close call breaks it. HOL hours.
3. **L3 per name + unreachability**: V for write (U400 + failed writes via an
   event-level invariant), V for read (new), "no close/open_in event". Control:
   wrong-clen insertion (`replay_ignores_wrong_clen_write_event`) must not satisfy V.
   HOL hours. After 1-3, Route A is honest (reachable-call relation; Q3b covers it).
4. **Owner decision**: B1 or B2c. A new runtime means a NEW executable, a NEW
   artifact hash, and all byte-level proofs (~25 entries) redone. Owner approval
   required. No HOL time.
5. **Runtime and byte paths** (B2c: ~70 words; startup, read, write, exit, each
   failing closed by `exit_group` with nonzero code on invalid arguments): step
   theorems to each `svc` and from each assumed return. Control: changed word
   rejected; invalid-argument path reaches the exit `svc`, never x30. HOL hours.
6. **Native simulation**: `refund_native_rel` and the `FUNPOW`-lift (ag32
   `machine_sem_Terminate_FUNPOW_next` shape) with the three syscall relations as
   the only external premises, and the numchars-witness lemma. Control: a
   syscall relation that returns k > n must be rejected by the fs witness. HOL
   hours to days.
7. **Final statement + replay**: top theorem for the new ELF; import check with
   transitive definition hashes (V H2); independent replay. Owner approval for
   the run; HOL hours.

**Next independently checkable proof obligation** (proposed statement, not
type-checked):

    refund_ffi_contract_at_totalise:
      ∀b dm V f.
        (∀k i nb ms. V (i,ms) ⇒ contract_clause b dm (f k (i,nb,ms)) (i,nb,ms)) ⇒
        refund_ffi_contract_at b dm
          (λk (i,nb,ms). if V (i,ms) then f k (i,nb,ms)
                         else refund_abs_env_effect k (i,nb,ms))

where `contract_clause` is the body of `refund_ffi_contract_at` for one call
(as defined in `forge_refundSlideProfileA`, U409) and `refund_abs_env_effect`
is the effect field of `refund_abs_env` (U392). It needs only stored theories
and `refund_abs_env_is_ok`. It is runtime-independent.

---

## 7. Smallest counterexample to the present all-states contract (U393/U394, exact)

Index 2 (close), entry pc 0x100004080, a call state with readable arrays,
`x3 = 0` (alen = 0, so `read_ffi_bytearrays` gives `SOME []` for the result
array), aligned x30. The contract requires the effect state to have pc = x30.
The real code: `b 0x100025260`; `_fficlose`: `cmp x3,#0; b.le 0x1000252A4`;
reaches 0x1000252A4 in 6 steps from the entry address (U394, assert-0001, exit 0,
`zero_alen_reaches_assert_block`), then `bl _fficlose.cold.2` → `___assert_rtn`
(abort, not modelled). It never returns to x30. Second case: clen <> 8 with
positive alen reaches 0x1000252A8 in 8 steps (`invalid_clen_reaches_assert_block`).
For write the same holds with `ffi_write_accepts_wrong_clen` (U397): the oracle
returns, the C code aborts.

---

## 8. What I could not determine

- The number of read calls in a canonical run, and the buffer size (inferred 2+).
- Whether macOS arm64 allows a non-dyld static executable (general knowledge says no; not checked).
- Whether the stored CakeML `code` term is unchanged by a new C runtime (expected; not checked).
- Whether real stdin can be non-blocking in the deployment (EAGAIN, F3).
- Exact ag32 FFI code sizes in words; I counted proof lines only.
- What libSystem `read`/`write` touch (stack only? errno TLS?): no source pinned.
- The program's exit status on an uncaught `Fail` (V found exit 0 with empty output on bad input).

---

## 9. Links for the top-level graph

My area feeds `ApprovedSpec(e)` and `ValidArtifact(e)` of the top theorem:
"the bytes the sink receives from the ACTUAL process equal
`refund_render_fields (refund_fields ...)`, or the process gives a nonzero
exit / no complete frame".

### 9.1 Present runtime (macOS Mach-O, CakeML basis C runtime)

| from | to | statement | class | evidence | what would upgrade it |
|---|---|---|---|---|---|
| dyld hand-off | `_main` at 0x100025544 | none | ASSUMPTION | Q3a; LC_MAIN entryoff 152900 checked only in ML (V M1) | in-HOL load-command check |
| `_main` + `cml_memory_size` + getenv + malloc | `refund_entry_pre_sl sl s h stk e` at cml_main | none (premise P1-P6) | ASSUMPTION | Q3a; e4-0001 stdout 240-265 | B1.8 step theorems + getenv/malloc relations |
| cml_main entry | CakeML entry 0x1000040D0 | `cml_main_run_sl` | MACHINE-CHECKED | HOL4, s1-0001 (U405) | independent replay |
| entry state | installed state (28 of 30 clauses) | `refund_installed_from_entry_reduced_sl` | MACHINE-CHECKED | HOL4, a3-0006 (U407) | replay |
| CakeML source | model machine behaviour + output equation | `refund_profile_a_sl` | MACHINE-CHECKED | HOL4, e4-0001 (U409) | replay; H2 identity checks |
| model FFI env | `refund_env_ok_sl sl envmc` (all states) | `refund_env_ok_sl_def` | ASSUMPTION | Q3b; probably false (U393, U409) | replace by reachable-call form (steps 1-3) |
| model write call | real `_ffiwrite` to `br x16` | `cake_ffiwrite_to_import_branch` | MACHINE-CHECKED | HOL4, U397 (under 19-conjunct premise) | discharge 12-conjunct residual (B1.4) |
| write GOT slot 0x1000280B0 | libSystem `write` | none (`g` variable) | ASSUMPTION | Q3b | in-HOL bind-table check + dyld relation |
| libSystem write + XNU | `write_call_rel dm s1 s2` | `write_call_rel` (premise) | ASSUMPTION | Q3b; U397 | none in B1; syscall relation in B2 |
| write return | caller x30, frame restored | `cake_ffiwrite_path_returns` | MACHINE-CHECKED | HOL4, wsucc-0002 (U398) | replay |
| reachable write calls | clen = 8 and bound | `refund_terminating_run_reaches_valid_write_call` | MACHINE-CHECKED | HOL4, args-0006 (U400), successful events only | failed-event invariant |
| model read call | real `_ffiread` path + `read_call_rel` | none (only `ffiread_error_return`, 6 steps, U348) | MISSING | U348 limits | B1.1-B1.3 |
| program | no close / open_in call | none | MISSING | source inspection only (U396) | B1.5 |
| path theorems | reachable-call env predicate | none (U405 L1-L3) | MISSING | U405 "NOT RUN" | steps 1-3 |
| model machine_sem | real process behaviour | none (A3 "NOT formalized") | MISSING | V C1 | B1.7 |
| halt_pc, x0 = 0 | `_cml_exit` → `exit(0)` | none | MISSING | targetSemScript.sml 138-140 (model only) | B1.9 |
| real process stdout/exit | model output | none | TESTED-UNPROVED | 2,466 vectors, attempt-0006 | B1.7 |

### 9.2 Recommended replacement (B2c, Linux static ELF; nothing exists yet)

| from | to | statement | class | evidence | what would upgrade it |
|---|---|---|---|---|---|
| execve of pinned ELF | entry state at `_start`, slide 0 | none | ASSUMPTION | not approved | ELF header check in HOL |
| `_start` | cml_main entry state | none | MISSING | — | step theorems |
| read/write FFI routines | `svc` site | none | MISSING | — | step theorems |
| `svc` (read, write, exit_group) | return state / termination | none | ASSUMPTION | not approved | none (kernel boundary; F4) |
| reachable-call predicate | totalised contract | none (same L1-L3 as 9.1) | MISSING | — | steps 1-3 |
| model machine_sem | real process | none | MISSING | — | step 6 |
| exit path | exit status 0 iff Success | none | MISSING | — | step 5 |
| real process output | model output | none | MISSING | no test run | conformance on Linux ARM64 |

**FIRST MISSING link** (in execution order, present runtime): the read FFI call
(model read call → real `_ffiread` prologue, `read_call_rel`, success suffix,
and reachable read facts). The program reads stdin before any write. In proof
order, the first missing runtime-independent link is L1
(`refund_ffi_contract_at_totalise`).

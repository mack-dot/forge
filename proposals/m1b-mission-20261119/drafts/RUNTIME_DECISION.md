# C2: B2c proof-surface audit and runtime decision (worker X6, runtime-decision)

Study only. Nothing was built, assembled, linked or run. No HOL, Holmake,
poly, Dafny or Docker. No repository file changed. No state-changing git
command. The only script that ran is `classify.py` in this folder: it reads
the two replay plan files and sums recorded wall seconds per class.

Abbreviations for pinned sources:
- `CK` = `.toolchain/experiments/refund-cakeml-20261104/cakeml`
- `L3A` = `.toolchain/experiments/refund-cakeml-20261104/HOL/examples/l3-machine-code/arm8`

Labels used below:
- **[src]**: read in the pinned source, with file and line.
- **[rec]**: read in a Forge record (`unsure.md`, plan files, earlier worker reports).
- **[gk]**: general knowledge, NOT checked against a pinned source. The
  authority that would settle it is named.
- **[design]**: my proposal. It does not exist. It was not built or tested.

Nothing in this document is a proof. Every theorem statement is a CANDIDATE,
not type-checked.

---

## 0. Short answer

- The present CakeML code bytes do not depend on the platform. The exporter
  writes the compiled `bytes` as `.byte` lines and the bitmaps as `.quad`
  lines for every platform (`CK/compiler/backend/arm8/export_arm8Script.sml`
  241-255). Only the assembler macros differ (lines 36-48). The compiler
  never uses x18 (`CK/compiler/encoders/arm8/arm8_targetScript.sml` 349-350).
  So a Linux build can carry the same code bytes. This is [src]. No Linux
  build exists to confirm it.
- A static, non-PIE Linux ARM64 runtime for THIS program needs about **84
  hand-written instructions**, **4 `svc` sites**, **3 syscall numbers**, and
  **6 named assumptions**: 4 kernel relations, 1 processor relation and 1
  isolation relation.
- **Main finding (design).** Let the runtime fail closed with
  `exit_group(non-zero)` on every invalid argument, every syscall error and
  every unexpected FFI name. Then the SAFETY theorem does not need the
  reachable-call proofs L2/L3 of route A. Those become liveness only. It
  still needs L1 (totalisation), the per-call contract at valid states, and
  a native simulation.
- **Second finding.** CakeML's `arm8_ok` requires `TCR_EL1.TBI0 = F` and
  `SCTLR_EL1.SA0 = F` (`CK/compiler/encoders/arm8/arm8_targetScript.sml`
  20-26). By [gk], Linux arm64 runs EL0 with top-byte-ignore enabled and SP
  alignment checking enabled. Authority: the Linux kernel source
  `arch/arm64` (the `SCTLR_EL1` and `TCR_EL1` set-up) and
  `Documentation/arch/arm64/tagged-address-abi.rst`. If this holds, the
  processor assumption "L3 with `arm8_ok`" is false word for word for the
  real register values. It must become an abstraction lemma or a named
  assumption. The macOS M1 chain has the same open point: `unsure.md` U277
  (near line 8430) says the physical values were never observed.
- **Recommendation:** NO-GO for B1 as the closure route. NO-GO for any
  runtime build or rewrite now. **Conditional GO for one B2c probe
  milestone**: a build-free HOL theorem about the proposed `ffiwrite` words
  at a symbolic address, composed with a stated `linux_write_rel`. Its
  result decides whether the route is alive (section 6).

---

## 1. B2c proof surface (a design to audit, not to build)

### 1.1 Shape of the artifact [design]

- ELF64, `ET_EXEC` (non-PIE), `EM_AARCH64`, no `PT_INTERP`, no
  `PT_DYNAMIC`, no relocations, no TLS, no libc.
- **Text, `PT_LOAD` R+X.** It holds the exporter text unchanged:
  `cml_main` (27 executed words, as in M1), the stubs `cake_ffiopen_in`,
  `cake_fficlose`, `cake_ffiwrite`, `cake_ffiread`, `cake_install` and
  `cake_exit` (16 bytes each), `cake_main` with the 130,436 code bytes,
  and the code buffer. It also holds the new runtime text:
  `_start`, `ffiread`, `ffiwrite`, `fficlose`, `ffiopen_in`, `cml_install`,
  `cml_exit` and `ffi_fail`.
  - Sources for the exporter text: `export_arm8Script.sml` 22-116, 227-239.
  - Stub order: `ffi_asm (REVERSE ffi_names)`, line 100. The stub for index
    i is at `pc - 16(3+i)`, `halt_pc` is at `pc - 16`, and `install_pc` is
    at `pc - 32` (`CK/compiler/backend/semantics/targetSemScript.sml`
    285-301; `ffi_offset = 16`, `CK/compiler/backend/lab_to_targetScript.sml` 15-16).
- **Data, `PT_LOAD` RW.** The exporter's `.data` part: `cml_heap`,
  `cml_stack` and `cml_stackend` as `.quad 0` (`CK/compiler/backend/exportScript.sml`
  82-98), then `cake_bitmaps` (2,531 quads, per U389), then an empty
  `cake_bitmaps_buffer` (lines 100-110; `EVAL` is not defined).
- **`.bss` in the same segment:** a fixed heap+stack region
  `cml_region` of `H + S` bytes. It replaces `malloc`.
- `PT_GNU_STACK` non-executable, from `.note.GNU-stack`
  (`exportScript.sml` 73-76).
- **Expected file identity:** NEW. It needs a new SHA-256, a new image
  theorem and a new conformance run. The macOS file `b8ed5ec2…7bb8` and all
  its records stay unchanged.

### 1.2 (a) What the kernel guarantees at `execve` entry [gk]

These points are general knowledge, NOT checked. The authorities would be:
- the Linux kernel source of ONE pinned version:
  - `fs/binfmt_elf.c` (`load_elf_binary`, `create_elf_tables`);
  - `arch/arm64/include/asm/processor.h` (`start_thread`);
  - `arch/arm64/kernel/entry.S` and `syscall.c`;
  - `include/uapi/asm-generic/unistd.h`;
- the man pages execve(2), read(2), write(2), exit_group(2) and syscall(2);
- the System V gABI and "ELF for the Arm 64-bit Architecture" (AAELF64).

What the kernel gives at entry:
1. Each `PT_LOAD` segment is mapped at its `p_vaddr` (`ET_EXEC`: no
   randomisation of these segments). The file bytes fill `[0, p_filesz)`
   and zeros fill `[p_filesz, p_memsz)`, so `.bss` is zero. The
   permissions come from `p_flags`.
2. PC = `e_entry`. The core is at EL0, AArch64, little-endian.
3. `sp` is 16-byte aligned and points to `argc`, then `argv[]`, NULL,
   `envp[]`, NULL, then the auxv pairs, ending with `AT_NULL`.
4. The general registers are zero at entry on arm64 (`start_thread`
   clears `pt_regs`). The design below does NOT rely on this.
5. fds 0, 1 and 2 are inherited from the parent as the parent set them.
   Handled signals are reset to the default action. Ignored signals stay
   ignored. The signal mask is inherited.
6. The stack, the vDSO and the mmap base are randomised. They do not
   overlap the `ET_EXEC` segments.
7. A large `.bss` is mapped lazily. If memory is short, the process gets
   SIGKILL from the OOM killer, or `execve` fails, depending on the
   overcommit settings.

### 1.3 (b) Start-up sequence in native instructions [design]

What `cml_main` expects [src]:
- `export_arm8Script.sml` 10-19: x0 = the entry, x1 = the heap start,
  x2 = the stack start, x3 = the stack end.
- Lines 50-76: `cml_main` itself loads x1 from the slot `cml_heap`, stores
  the 5 header words at `[x1] … [x1,#32]` (pk = F), loads x2 from
  `cml_stack` and x3 from `cml_stackend`, and then runs `b cake_main`
  (ret = F).
- So the start-up code only has to write the three slots. Then it branches
  to `cml_main`. The registers on entry do not matter.
- In the Linux branch, `_ldrel` is `adrp` plus `add :lo12:` (lines 44-46).
  That is the same instruction count as the Apple branch. So `cml_main`
  stays 27 executed words. Only its `adrp`/`add` immediates change.

Does `installed` allow a fixed static region? Yes, by the clauses.
- `installed_def` (`targetSemScript.sml` 487-521) constrains only:
  - the register values `t.regs r1 ≤₊ t.regs r2`, both byte-aligned, at
    least 1024 words apart (492-496);
  - the five header words (498-507);
  - the bitmap words plus `data_sp` words in `bitmaps_dm`, disjoint from
    the heap (497, 508-510);
  - the FFI names and the MMIO layout (511-520).
- `good_init_state_def` (444-479) requires:
  - `dm ⊆ mem_domain`;
  - code loaded at the PC;
  - an arbitrary word content of the data memory (471-473: no zeroing is
    required);
  - the code-buffer bytes `∀n < cbspace` after the code inside
    `mem_domain` and outside `dm` (475-477).
- No clause names `malloc` or any allocation mechanism. A `.bss` range
  `[h, h+H+S)` meets the clauses if it is disjoint from the code and the
  bitmaps. With `EVAL` undefined, `data_sp = 0` (`exportScript.sml` 100-110).
- `cbspace` is the padding up to the 64 KiB boundary
  (`export_arm8Script.sml` 227-239). That padding lies inside the R+X
  segment, so it is mapped. The installer is never reached: the U298
  exclusion is proved for the model (U384-U386).

`_start` [design], 16 instructions, all in step-library classes (1.4):
```
_start:
  adrp x9,  cml_region            ; add x9,  x9,  :lo12:cml_region      (2)
  adrp x10, cml_heap              ; add x10, x10, :lo12:cml_heap        (2)
  str  x9,  [x10]                                                       (1)
  movz x11, #(H>>16), lsl #16     ; add x9, x9, x11                     (2)
  adrp x10, cml_stack             ; add x10, x10, :lo12:cml_stack       (2)
  str  x9,  [x10]                                                       (1)
  movz x11, #(S>>16), lsl #16     ; add x9, x9, x11                     (2)
  adrp x10, cml_stackend          ; add x10, x10, :lo12:cml_stackend    (2)
  str  x9,  [x10]                                                       (1)
  b    cml_main                                                         (1)
```
- `sp` is never used. The CakeML code never uses it: register 31 is in
  `avoid_regs` (`arm8_targetScript.sml` 350). The runtime below uses no
  stack. So the M1 point "the C stack is outside dm" (U393) disappears.
- H and S are design parameters. They must meet premise P4 (`8192w ≤ e-h`,
  U409) and `installed` 496. Sufficiency for Success is NOT claimed.
- Executed before the CakeML code: 16 + 27 = **43 words**. M1 executed
  47 + about 18 + 27 words, plus `getenv` and `malloc` in libSystem.

### 1.4 (c) FFI functions for THIS program [design; syscall facts are gk]

The CakeML FFI convention [src]:
- `is_arm8_machine_config` (`CK/compiler/backend/arm8/proofs/arm8_configProofScript.sml` 11-19):
  - x0 = conf pointer (`ptr_reg 0`), x1 = conf length (`len_reg 1`);
  - x2 = array pointer (`ptr2_reg 2`), x3 = array length (`len2_reg 3`);
  - callee-saved registers 19-28.
- `link_reg = SOME 30`; `avoid_regs = [18; 26; 31]` (`arm8_targetScript.sml` 350-351).
- `ffi_interfer_ok` (`targetSemScript.sml` 317-343) requires, on return:
  - `state_ok` (that is `arm8_ok`);
  - PC = x30;
  - every byte of `mem_domain` equal to `asm_write_bytearray x2 new_bytes`;
  - registers 19-25, 27 and 28 kept.
  - Registers x0-x17 and the flags are free.

The oracle's answers that the routine must reproduce at valid calls [src]:
- `ffi_read` (`CK/basis/fsFFIScript.sml` 307-327): `0w :: n2w2 k ++ [pad2] ++ data ++ DROP k tll`.
  Byte 0 is 0, bytes 1-2 are k (big-endian), byte 3 is unchanged, then k
  data bytes, then the rest unchanged. The fd is `w82n conf` (all 8 bytes).
- `ffi_write` (333-348): `0w :: n2w2 nw ++ (off0 :: tll)`. Byte 0 is 0,
  bytes 1-2 are nw. Nothing else changes.
- The model's `read` gives `k = MIN n (MIN remaining (SUC strm))`, so
  k ≥ 1 while data remain (187-197). The model's `write` gives
  `k = MIN n strm`, so k = 0 is allowed (214-230).

Linux arm64 syscall ABI [gk]: `svc #0`; the number is in x8; the
arguments are in x0-x5; the result is in x0, with -4095..-1 meaning
-errno. All other general registers are kept. The numbers are read = 63,
write = 64, exit_group = 94 (`include/uapi/asm-generic/unistd.h`).

`ffiread` [design], 25 instructions, fd 0 only:
```
 1 cmp  x1, #8           ; 2 b.ne ffi_fail          clen = 8
 3 ldr  x9, [x0]         ; 4 cbnz x9, ffi_fail      conf = 8 zero bytes (fd 0, all 8 bytes, fixes F1)
 5 cmp  x3, #4           ; 6 b.lo ffi_fail          alen >= 4
 7 ldrh w10, [x2]        ; 8 rev16 w10, w10         n = a[0]<<8 | a[1]
 9 add  x11, x10, #4     ;10 cmp x3, x11 ; 11 b.lo ffi_fail     alen >= n+4
12 mov  x12, x2          ;13 add x1, x2, #4 ; 14 mov x2, x10
15 mov  x0, #0           ;16 mov x8, #63 ; 17 svc #0            read(0, a+4, n)
18 tbnz x0, #63, ffi_fail                           any error (EINTR, EIO, EAGAIN, EBADF): fail closed
19 cmp  x0, x10          ;20 b.hi ffi_fail          k <= n (defensive)
21 strb wzr, [x12]       ;22 lsr w13, w0, #8 ; 23 strb w13, [x12,#1] ; 24 strb w0, [x12,#2]
25 ret
```

`ffiwrite` [design], 31 instructions, fd 1 only:
```
 1 cmp x1,#8 ; 2 b.ne ffi_fail
 3 ldr x9,[x0] ; 4 movz x10,#0x100,lsl #48 ; 5 cmp x9,x10 ; 6 b.ne ffi_fail       conf = 00..01
 7 cmp x3,#4 ; 8 b.lo ffi_fail
 9 ldrh w11,[x2] ; 10 rev16 w11,w11 ; 11 ldrh w12,[x2,#2] ; 12 rev16 w12,w12      n, off
13 add x13,x11,x12 ; 14 add x13,x13,#4 ; 15 cmp x3,x13 ; 16 b.lo ffi_fail        alen >= n+off+4
17 mov x14,x2 ; 18 add x1,x2,#4 ; 19 add x1,x1,x12 ; 20 mov x2,x11
21 mov x0,#1 ; 22 mov x8,#64 ; 23 svc #0                                         write(1, a+4+off, n)
24 tbnz x0,#63,ffi_fail                                                         EPIPE, EIO, ENOSPC, EAGAIN, EINTR
25 cmp x0,x11 ; 26 b.hi ffi_fail
27 strb wzr,[x14] ; 28 lsr w15,w0,#8 ; 29 strb w15,[x14,#1] ; 30 strb w0,[x14,#2]
31 ret
```

The other routines [design]:
- `ffi_fail`: `mov x0,#2 ; mov x8,#94 ; svc #0 ; b .`. That is 3 + 1 instructions. The last one is a guard that the relation says is never reached.
- `cml_exit` (from the `cake_exit` stub at `halt_pc`): `cmp x0,#0 ; cset w0,ne ; mov x8,#94 ; svc #0 ; b .`. That is 4 + 1.
  - The exit status is 0 if and only if x0 = 0. That is exactly the model's `Halt Success` test (`targetSemScript.sml` 138-140).
  - So L-EXIT holds by construction. The open lemma "x0 ∈ {0,1,2} at halt" from B1 is no longer needed: x0 = 256 now gives status 1, not 0.
- `fficlose`, `ffiopen_in`, `cml_install`: `b ffi_fail` each, 3 instructions in total. These are traps that fail closed.

Instruction classes and the step library [src]:
- The step library handles these instruction classes (`L3A/step/arm8_stepLib.sml`, `dfn'…` names): AddSub*, Address (`adrp`), BranchConditional, BranchImmediate, BranchRegister (`ret`), CompareAndBranch, ConditionalSelect (`cset`), LoadStoreImmediate/Register (`ldr`, `ldrh`, `strb`), LogicalShiftedRegister (`mov` reg), MoveWide (`movz`), BitfieldMove (`lsr`), Reverse (`rev16`), TestBitAndBranch (`tbnz`).
- **`svc` is NOT supported.** It decodes (`L3A/model/arm8Script.sml` 3630-3632) and runs `dfn'SupervisorCall`, which raises `UNDEFINED_FAULT` (2425-2434). `NextStateARM8` returns NONE on any exception (`L3A/step/arm8_stepScript.sml` 19-22). So each `svc` is a step that a stated relation REPLACES (1.5).
- Alignment: `ldr x9,[x0]` and `ldrh` need either aligned pointers or the premise `¬SCTLR_EL1.A`. U398 introduced that premise for the macOS write path. Whether CakeML byte-array and conf pointers are always 8-aligned was NOT checked. An alternative is byte loads only: about +4 instructions for n/off, +14 for the conf check.

Counts:
- Hand-written: 16 + 25 + 31 + 4 + 5 + 3 = **84 instructions** (82 plus 2 unreachable guards).
- Executed per canonical run: 43 (start-up), 1 + 25 per read call, 1 + 31 per write call, 1 + 4 at exit.
- M1 by comparison: about 200 distinct words in the file, plus libSystem and dyld.
- `svc` sites: **4** (read, write, `ffi_fail`, `cml_exit`). Syscall numbers: **3** (63, 64, 94).

### 1.5 (d) System calls as named relations [design, candidate HOL]

The state is the L3 `arm8_state` (fields `MEM`, `PC`, `PSTATE`, `REG`,
`SCTLR_EL1`, `SP_EL0`, `TCR_EL1`, `exception`, …;
`L3A/model/arm8Script.sml` 368-375). Each relation holds between the state
`s` AT the `svc` word (`s.MEM` holds `0xD4000001` at `s.PC`) and the state
`s'` at `s.PC + 4w`. P is the program's address set: code, data, `.bss`
and the runtime.

Ghost state:
- `inp` is the stdin content;
- `pos` is the number of bytes consumed so far;
- `out` is the bytes accepted on fd 1 so far.

```
same_except_x0 P s s' ⇔
  s'.PC = s.PC + 4w ∧ s'.exception = NoException ∧
  s'.PSTATE = s.PSTATE ∧ s'.SCTLR_EL1 = s.SCTLR_EL1 ∧ s'.TCR_EL1 = s.TCR_EL1 ∧
  s'.SP_EL0 = s.SP_EL0 ∧ (∀r. r ≠ 0w ⇒ s'.REG r = s.REG r)

linux_read_rel P inp pos s s' k ⇔                       (* x8 = 63w, x0 = 0w *)
  same_except_x0 P s s' ∧
  let buf = s.REG 1w; n = w2n (s.REG 2w) in
  ( (* success *) k ≤ n ∧ pos + k ≤ LENGTH inp ∧
      (k = 0 ⇒ n = 0 ∨ pos = LENGTH inp) ∧          (* 0 only at end of input *)
      s'.REG 0w = n2w k ∧
      (∀i. i < k ⇒ s'.MEM (buf + n2w i) = EL (pos + i) inp) ∧
      (∀a. a ∈ P ∧ (∀i. i < k ⇒ a ≠ buf + n2w i) ⇒ s'.MEM a = s.MEM a) )
  ∨ ( (* error *) ∃e. 1 ≤ e ∧ e ≤ 4095 ∧ s'.REG 0w = -n2w e ∧
      (∀a. a ∈ P ∧ ¬(buf ≤₊ a ∧ a <₊ buf + n2w n) ⇒ s'.MEM a = s.MEM a) )

linux_write_rel P s s' bs ⇔                             (* x8 = 64w, x0 = 1w *)
  same_except_x0 P s s' ∧ (∀a. a ∈ P ⇒ s'.MEM a = s.MEM a) ∧
  let buf = s.REG 1w; n = w2n (s.REG 2w) in
  ( (∃k. k ≤ n ∧ s'.REG 0w = n2w k ∧ bs = GENLIST (λi. s.MEM (buf + n2w i)) k)
    ∨ (∃e. 1 ≤ e ∧ e ≤ 4095 ∧ s'.REG 0w = -n2w e ∧ bs = []) )
  (* observation: out' = out ++ bs; the reader of fd 1 receives exactly out' *)

linux_exit_rel s st ⇔ s.REG 8w = 94w ∧ st = w2n ((7 >< 0) (s.REG 0w))
  (* the process ends with status st; no successor state; out is frozen *)

linux_execve_rel F inp s0 ⇔
  (∀seg ∈ load_segments F. ∀i. i < seg.memsz ⇒
       s0.MEM (seg.vaddr + n2w i) = if i < seg.filesz then EL (seg.offset + i) F else 0w) ∧
  s0.PC = elf_entry F ∧ s0.exception = NoException ∧ s0.PSTATE.EL = 0w ∧ …
  (* fd 0 = an open file description at offset 0 whose content is inp, then EOF;
     fd 1 = open for writing; out = [] *)
```

The kernel may change only x0, and memory in the read buffer range. For
write it may change only x0. For exit it changes nothing, because there is
no successor state.

Two more relations are needed:
- `proc_rel`: the real core runs each non-`svc` word as `NextStateARM8`
  does. This includes the system-register abstraction of section 0.
- `iso_rel`: no other agent writes the process memory or registers. That
  means no ptrace, no `/proc/pid/mem`, no shared mapping over P, and only
  default signal actions. Context switches are transparent. This is the
  existing identity `next_interfer` (U392 `interference_ok_arm8_iff`).

The read relation is an axiom about the step that REPLACES the pinned L3
`svc` fault. It is not derived from L3.

**Total: 6 named assumptions.** They are `linux_execve_rel`,
`linux_read_rel`, `linux_write_rel`, `linux_exit_rel`, `proc_rel` and
`iso_rel`.

### 1.6 (e) The bounded 192-byte protocol, and the present program unchanged

**The present program (unbounded S-expression reader through the basis
`TextIO`).**
- It links exactly 4 FFI names: read, write, close, open_in (U391
  `refund_ffi_names`; U392 `refund_ffi_names_list`). The exit goes through
  `cake_exit` at `halt_pc`, not through an FFI name.
- Can it use the three routines unchanged? **Yes, as far as I can tell.**
  - read and write are real.
  - close and open_in get trap implementations that fail closed (`exit_group(2)`).
  - Under the safety theorem of section 5, a trap call is just one more
    "exit non-zero with a prefix" case. Unreachability (U396, inspection
    only) is then needed only for liveness, not for safety.
  - Risk: if the basis did call close at the end of the run, every run
    would fail closed. That is a liveness failure, visible in the first
    test. It is not a safety hole.
- The compiled code does not change, because the FFI name list comes from
  the program, not the runtime. That is [src] for the exporter. Whether
  the CakeML `code` term is literally identical was NOT checked by a
  build.

**The F2.7 bounded protocol (192-byte frame, two fixed outputs).**
- It reads at most 193 bytes and calls `print` once (W7 report).
- Simplifications for the native proof:
  - The stdin relation has a bounded `inp`.
  - The numchars witness is a list of at most 194 read counts plus the
    write counts.
  - The heap can be small (size not determined).
  - The source theorem holds for EVERY stdin content (F2.7 item 12). So the
    "canonical input" premise leaves the native theorem.
- A further option [design, not checked]: a Forge-specific I/O FFI with
  two calls, "read all, at most 193 bytes" and "write all". The runtime
  loops in assembly. A small oracle replaces the `fsFFI` file-system model.
  - This removes the numchars witness and the `STD_streams`/`wfFS` premises.
  - It adds two assembly loops with loop invariants, and a new CF spec for
    the custom FFI.
  - This is the owner's "minimal verified I/O runtime".
- The cost: F2.7 is a DIFFERENT CakeML program. None of the 58 class-(i)
  theories of section 2 carries over as an instance. Only their method and
  about 14 generic theories carry over.

---

## 2. Existing proofs: classification of the 95 theories

Sources:
- `proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/plan.json`
  (71 theories; the step C72 is an import check, not a theory);
- `plan-phase2.json` B (24 theories);
- the U-entry titles U345-U409 and M1R-1/M1R-2.

The wall times are the RECORDED REPLAY seconds on the rebuilt tools. They
are not development effort. Two theories, `forge_refundReadBoundary` and
`forge_refundStdinDomain`, have 0 recorded. The plan assumes 60 s each;
that is not added here. The computation is `classify.py` in this folder.

| class | count | recorded replay wall (s) |
|---|---|---|
| (i) reusable unchanged | **58** | 4,091.3 |
| (ii) reusable in method, re-instantiated | **12** | 983.6 |
| (iii) obsolete or not used for B2c safety | **25** | 3,907.0 |
| total | 95 | 8,981.9 |
| (iv) NEW | about 17 obligations, none exists | 0 |

**(i), unchanged (58).** These are about the source, the translation, the
compiler output and model-level facts that are generic in the machine
record or the base address.
- T01-T09: `forge_refund`, `_compile`, `_call`, `_io`, `CertifiedProg`,
  `WireProg`, `StdioProg`, `WholeProg`, `Arm8Compile`.
  - The code bytes are platform-independent ([src] `export_arm8Script.sml`
    250, `arm8_targetScript.sml` 349-350).
- C10-C37: lab closure, region invariant, simulation prefix lemmas, exact
  exclusion, compile facts, `compile_correct'` replay and variant, U298
  exclusion, source non-Fail, start-up clause, reject non-Fail.
  - `refund_mc base0` and `mc0` are parameters (U386, U388).
  - `refund_startup_clause_arm8` uses lengths (20248, 0x1FD84), not Mach-O
    addresses (U387).
- C39 `StartupBridge` (base0 is a parameter), C41 `loaderMemLemmas`, C47
  `FfiFacts` (in-logic compile evaluation).
- B01-B07 and B09-B19: `Arm8Proof` (U276), `ReadBoundary`, `StdinDomain`,
  the initializer theories, `GenericReadError` (CF level), `FfiOracle`,
  `FfiInstance`, `InstallStub`, `InstallSite` (stated "with bytes at the
  program counter", position-independent, U359), `InstallReach`,
  `LabRunInit`, `LabExclusion`, `AllocBackend`.

**(ii), re-instantiated (12).** These name Mach-O addresses, file offsets
or the exact `cml_main` words.
- C38 `CmlMainStep`, C40 `CmlMainFrame`, B20 `CmlMainSat`: 27 steps; new
  `adrp` immediates.
- C42 `Image`: ELF file slices instead of Mach-O.
- C43 `LoaderMemory`, C44 `EntrySat`: from `linux_execve_rel` instead of the
  image premise.
- C45 `InstalledDomains`, C46 `InstalledAssembly`, C48 `Residual`: new
  domains.
- C49 `EnvModel`: the contract equivalence at the new base. The abstract
  environment is reused.
- C60 `FfiwriteUnaligned`: the analogous unaligned LOAD lemma for
  `ldr`/`ldrh`, if pointers are not 8-aligned.
- C70 `ProfileA`: the slide-0 composition at the new layout.

**(iii), obsolete or not used for the B2c safety theorem (25).**
- The C runtime paths: C50-C53 (`fficlose` step, bridge, assert, compose);
  C56-C59 and C61-C62 (`ffiwrite` step, path, compose, site, success,
  fault); B08 `NativeReadError` (U348).
- The slide work, because slide 0 holds for `ET_EXEC`: C64-C69 (S1-S3),
  C71 `SlideProfileA` (S4-S6).
- Model reachable-call facts: C54 `CallSite`, C55 `SignedLen`, C63
  `WriteReach`, B21 `WriteReachCheck`, B22 `WriteArgs`, B23
  `WriteArgsCheck`, B24 `WriteWord`.
  - These are NOT needed for safety under the fail-closed runtime. Their
    method keeps value for a later liveness claim at the new stub
    addresses.

**(iv) NEW (none exists).**
- N1: ELF image theorem.
- N2: in-HOL ELF header and program-header check.
- N3: `_start` 16-step theorem.
- N4: `ffiread` step theorems: to `svc` 16 steps, success suffix 8, each
  fail branch.
- N5: `ffiwrite` step theorems: to `svc` 22 steps, success suffix 8, each
  fail branch.
- N6: `ffi_fail`, the traps and `cml_exit` to `svc`.
- N7: the 6 relation definitions, each with a satisfiability witness and
  negative controls.
- N8: the explicit post-state function `realfx`, and the per-call contract
  for `realfx` at valid calls (read, write).
- N9: L1 totalisation `refund_ffi_contract_on_totalises` (B1 statement).
- N10: `refund_env_ok_sl` for the totalised environment, and the Profile A
  instance at the ELF base.
- N11: native process semantics (`linux_step`, `linux_run`).
- N12: the simulation lift.
- N13: the numchars witness.
- N14: L-OUT.
- N15: L-EXIT (by construction).
- N16: the `TBI0`/`SA0` abstraction lemma, or a named assumption.
- N17: the top composition with transitive identity checks.

---

## 3. B1 on the same axes (present macOS executable)

### 3.1 Concrete obligations to reach the libSystem call boundary

Here "Exists" means a stored theorem exists (U393-U401, M1R-1/M1R-2 replayed).

| # | obligation | exists? | size |
|---|---|---|---|
| B1-1 | `_main` (47 words) to `bl cml_main`: argc/argv stores, two `cml_memory_size` calls (unset branch, about 9 words each), `malloc`, the three slot stores | no (P1-P6 are premises) | hours |
| B1-2 | `getenv_rel` (returns NULL for both names) and `malloc_rel` (an aligned 2 GiB block, disjoint from the image and the stack, never touched by libSystem again) | no; ASSUMPTION only | cannot be proved |
| B1-3 | the 5 import stubs (`adrp; ldr; br x16`) and the GOT binds of getenv, malloc, read, write and exit to libSystem | stubs: write only (U397 `g` variable); binds: no | hours; binds stay dyld ASSUMPTION |
| B1-4 | `_ffiread` prologue to `br x16` (about 20 steps) | no | hours |
| B1-5 | `_ffiread` success suffix, joined with the U348 error suffix | error suffix only (U348) | hours |
| B1-6 | `read_call_rel` (libSystem read + XNU) | no; ASSUMPTION | — |
| B1-7 | reachable read-call facts (clen = 8, n+4 ≤ alen), needed because the C code aborts | no | hours-days |
| B1-8 | write residual: 12 conjuncts, `¬word_msb x3`, failed-write events | partial (U397-U401) | days; may be unprovable from `extract_fs` alone (U401) |
| B1-9 | no close or open_in event | no (inspection, U396) | hours-days |
| B1-10 | L1, L2, L3 (reachable-call environment) | no | hours-days |
| B1-11 | `_cml_exit` (16 words); `fwrite` to stderr if non-zero; `exit((int)x0)`; the lemma x0 ∈ {0,1,2} at `halt_pc` (without it, x0 = 256 gives status 0) | no | hours + days (no stored shape for the x0 lemma) |
| B1-12 | C frames on the dyld-provided stack, outside dm (U393 `sp = b+32`) | premise only | ASSUMPTION |
| B1-13 | native simulation with libSystem relations, plus the numchars witness | no | days |
| B1-14 | L-OUT | no | hours |
| B1-15 | slide S1-S6 | YES (U405, U407, U409) | done |
| B1-16 | in-HOL Mach-O load-command and bind-table check (V M1) | no (checked in ML only) | hours-days |

What CANNOT be closed on macOS, even in principle:
- **libSystem.** `read`, `write`, `exit`, `getenv`, `malloc` and `fwrite`
  live in the dyld shared cache. They are not pinned and change with OS
  updates [gk].
- **The kernel boundary.** The XNU syscall numbers and ABI are not a stable
  public interface. Apple supports only libSystem [gk; authority: Apple
  platform documentation, not checked].
- **dyld.** arm64 macOS user processes are loaded by dyld. A static
  executable without dyld is not supported [gk; B2 could not determine
  this either].
- So B1 always ends at axioms about large, unpinned binaries, plus
  `exit()` semantics (atexit handlers, stdio flush).

---

## 4. Comparison: B1, B2c, and B2c with the bounded 192-byte protocol

### 4.1 Remaining trusted dependencies (enumerated)

| # | dependency | B1 | B2c | B2c-192 |
|---|---|---|---|---|
| 1 | HOL4 kernel, four bool axioms, cv `compute` (V L3) | yes | yes | yes |
| 2 | L3 ARMv8 model = the real core for the executed words | yes (Apple core) | yes (Linux host core) | yes |
| 3 | `arm8_ok` system-register abstraction (EL0, E0E, SA0, TBI0/TBI1) | yes, unobserved (U277) | yes; Linux likely contradicts SA0/TBI0 [gk] | yes |
| 4 | `SCTLR_EL1.A` clear (or aligned pointers) | yes (U398) | yes, unless byte loads | yes |
| 5 | process loader | XNU + dyld mapping + chained fixups + 23 GOT binds | `linux_execve_rel` (ELF `PT_LOAD`, zero `.bss`, `e_entry`) | same |
| 6 | permitted slide | `slide_ok` (proved generic) | none (`ET_EXEC`) | none |
| 7 | heap provider | libSystem `malloc` | none (`.bss`) | none |
| 8 | environment variables | libSystem `getenv`; CML_* unset | none | none |
| 9 | read | libSystem `read` + XNU | `linux_read_rel` | `linux_read_rel` (bounded) |
| 10 | write | libSystem `write` + XNU | `linux_write_rel` | same |
| 11 | exit | libSystem `exit` (atexit, flush) + `fwrite` | `linux_exit_rel` | same |
| 12 | abort path | `__assert_rtn`, `abort` | none | none |
| 13 | C stack | dyld main-thread stack, outside dm | none (no stack used) | none |
| 14 | isolation | no ptrace, signals, other writers | `iso_rel` | same |
| 15 | stdin content = request, then EOF; pipe or regular file | yes | yes | yes, ≤ 193 bytes |
| 16 | reader of fd 1 gets exactly the accepted bytes | yes | yes | yes |
| 17 | file reader / offset tool (Q3c) | Mach-O ML reader | ELF reader (a simpler format) | same |
| 18 | owner-approved spec items | M1 contract | M1 contract | + 10 F2.7 items, A-SIGN signer if S2 |
| 19 | pinned OS version | impossible to pin libSystem meaningfully | one kernel version | same |

### 4.2 Proof obligations (one sentence each; size; does a stored proof of the same shape exist?)

B2c, where "shape" names the closest stored proof:

| # | obligation | size | shape exists |
|---|---|---|---|
| O1 | ELF file bytes contain the code and bitmaps at their `p_vaddr` | hours | yes, C42 |
| O2 | in-HOL check of the ELF header and program headers | hours | no |
| O3 | entry memory clauses from `linux_execve_rel` | hours | yes, C43 |
| O4 | `_start`: 16 steps write the three slots | minutes-hours | yes, C38 |
| O5 | `cml_main`: 27 steps at the new addresses | minutes | yes, C38/C40 |
| O6 | `installed` clauses at the new layout | hours | yes, C45/C46/C48/C68 |
| O7 | `ffiread` steps to `svc`, success suffix, and fail branches to the `exit_group` `svc` | hours | yes, U397/U398 |
| O8 | `ffiwrite` the same | hours | yes, U397/U398 |
| O9 | `ffi_fail`, traps and `cml_exit` to `svc` | minutes | yes, U393 |
| O10 | 6 relation definitions, satisfiability witnesses, negative controls | hours | partly (`close_call_rel` U394) |
| O11 | `realfx` meets the per-call contract at valid calls, with `new_bytes` = the `ffi_read`/`ffi_write` answer | hours | yes, U394 contract instance |
| O12 | L1 totalisation | minutes | no (simple) |
| O13 | env_ok for the totalised environment, plus the Profile A instance at the ELF base | hours | yes, C70 |
| O14 | native process semantics definitions | hours | no |
| O15 | simulation: each native run follows the totalised model machine until `halt_pc` or a fail exit | days | partly (ag32 `interference_implemented` 143-193, `machine_sem_Terminate_FUNPOW_next` 348; opposite direction) |
| O16 | numchars witness (native counts ++ `LREPEAT [1]` meets `live_numchars`, `fsFFIPropsScript.sml` 202-210) | hours-days | yes, `sat_fs` (U409 witness) |
| O17 | L-OUT | hours | no |
| O18 | L-EXIT | minutes | no (trivial) |
| O19 | `TBI0`/`SA0` abstraction lemma (or a named assumption) | days, or 0 if assumed | no |
| O20 | top composition plus transitive identity checks | hours | yes, imp4 |

- **B1:** B1-1 to B1-16 (3.1). Of these, B1-2, B1-6, B1-12 and the binds are ASSUMPTIONS with no possible proof. B1-8 and B1-11 have no stored shape for their hardest part.
- **B2c-192:** O1-O20 for the new program (O16 bounded; with the custom FFI, O16 and O17 shrink). Add the whole F2.7 source chain (W7 stages 1-4) and redo the class-(i) work for a new program.

### 4.3 Proof reuse (from section 2)

| | B1 | B2c | B2c-192 |
|---|---|---|---|
| unchanged | 95 (all) | 58 | about 14 generic theories by name (C12-C14, C16-C21, C25, C29, C30, C33, C41; 615 s), not checked one by one |
| re-instantiated | 0 | 12 | about 20-25 (the method of (i) and (ii)) |
| obsolete / unused | 0 | 25 | the rest |
| new | B1-1…B1-16 open items | about 17 (N1-N17) | about 17 + the F2.7 chain |

### 4.4 Credible failure modes

**B1 (7):**
1. libSystem or dyld changes with an OS update. The theorem is then silently about another system.
2. `exit((int)x0)` truncates. x0 = 256 at `halt_pc` (Resource_limit_hit in the model) gives status 0. A proof of x0 ∈ {0,1,2} may not exist.
3. `malloc` exclusivity cannot be proved. libSystem allocator metadata, or later allocations by `fwrite`/stdio, might touch the region [gk].
4. The C code aborts on invalid arguments (U393, U397). So the reachable-call facts must be proved, including failed-write events. The exported specification does not expose those (U400, U401).
5. A read error (EINTR, EAGAIN) sets `a[0] = 1` (`basis_ffi.c` 166-168). The model has no such answer for fd 0, so the program sees an error the model never produces. That case is outside the theorem, and V saw exit 0 with empty output on errors. A caller that trusts exit 0 fails open.
6. The GOT binds are not checked in HOL. Another file with equal `__TEXT` passes (V M1).
7. C stack overflow or misplacement relative to dm (U393 premise).

**B2c (10):**
1. The real Linux EL0 register values (TBI0, SA0; [gk]) contradict `arm8_ok`. Without an abstraction lemma, the processor assumption is false as written.
2. The L3 step library does not support an instruction that the runtime needs. Checked: all classes used are in `arm8_stepLib.sml` except `svc`, which is assumed by design. Residual risk: unaligned `ldr`/`ldrh` need a C60-like derivation.
3. `installed` needs a clause that a static region cannot meet. By reading (1.3), every clause is met. Residual risk: the code-buffer clause depends on the link layout (`cake_codebuffer_begin` right after the code).
4. The numchars/oracle witness for short reads. If the kernel returns 0 before EOF (terminal, or a non-blocking descriptor returning EAGAIN or 0), the model cannot match it. Early EOF cannot be detected by the runtime. The program would then decide on a PREFIX of the request with exit 0. `linux_read_rel` excludes this by assumption. The caller must give a pipe or regular file.
5. The Linux host is not the owner's deployment platform (macOS). The theorem is about a different artifact and OS.
6. The kernel may deliver a signal. Default SIGPIPE kills on EPIPE, and the OOM killer sends SIGKILL with a large `.bss`. These end with no exit status, so the caller fails closed (B3 D2). Safety holds; liveness does not.
7. seccomp, containers or kernel configuration (16K/64K pages, overcommit) change the syscall results. Each becomes the error branch and a fail-closed exit, or an `execve` failure.
8. The assembler or linker places sections so that `cml_main`'s `adrp` immediates or `cbspace` differ from the plan. O5 and O6 are on the bytes, so a proof catches it. Cost: one more re-instantiation.
9. The ELF reader (the Q3c analogue) is trusted unless O2 is done in HOL.
10. The simulation lift (O15) has no stored proof in the needed direction. The ag32 lemmas go from model to machine, for a deterministic machine. Native-to-model with a kernel prophecy could cost more than "days".

**B2c-192 (6):** all of B2c, plus:
1. A full new CakeML chain for a new program.
2. The basis FFI names of the bounded program are unknown (W7).
3. Translator side conditions for the U64 decode.
4. The owner must approve 10 new spec items.
5. The trusted signer A-SIGN.
6. With a custom FFI, a new CF specification and two assembly loops with invariants. Loop proofs are harder than straight-line step theorems.

---

## 5. A complete native-execution theorem for B2c (CANDIDATE, not proved)

```
Theorem refund_linux_native (CANDIDATE):
  ∀F s0 inp run.
    F = refund_elf ∧ elf_ok F ∧                                  (* O1, O2 *)
    inp = explode (sexp_to_string (refund_request cid rid orig rem en amt rsn)) ∧
    linux_execve_rel F inp s0 ∧ proc_rel ∧ iso_rel ∧              (* assumptions *)
    linux_run F inp s0 run                                        (* steps: NextStateARM8 between svc,
                                                                     linux_read_rel / linux_write_rel /
                                                                     linux_exit_rel at the 4 svc sites *)
  ⇒
    (* safety at every point of every run, including runs that never exit *)
    (∀i. i < LENGTH_or_inf run ⇒ out_at run i ≼ R) ∧
    (* at exit *)
    (∀st out. run_exits run st out ⇒
        (st = 0 ∧ out = R) ∨ (st ≠ 0 ∧ out ≼ R))
  where R = refund_render_fields (refund_fields cid rid orig rem en amt rsn)
```

Notes on the statement:
- The prefix in the non-zero case may be the WHOLE output R. The source
  of this is `extend_with_resource_limit`
  (`CK/semantics/proofs/semanticsPropsScript.sml` 219-226): it allows
  `io_list ≼ l`, which includes equality. A resource stop after the last
  write therefore exits non-zero with complete output. The owner's
  wording "strict prefix" is stronger than `compile_correct` gives. That
  stronger form is NOT available.
- No run ends in a way other than these: a stuck L3 state cannot occur,
  because every non-`svc` step simulates a model step and the model never
  reaches `Error` (M1: never Fails).
- Non-termination is NOT excluded. Blocking in `read` forever, or being
  killed, gives no exit. Such runs satisfy only the "every point" part.

**L-OUT** (connects modelled output events to the written bytes):
```
L-OUT: wfFS fs ∧ STD_streams fs ∧ extract_fs fs io = SOME fs' ⇒
   stdout_delta fs fs' = FLAT (MAP written_bytes (FILTER is_write_fd1_ok io))
```
- `written_bytes (IO_event «write» conf bs)` = `TAKE nw (DROP (4+off) (MAP FST bs))`.
- The simulation (O15) makes each native `linux_write_rel` success
  correspond to one model write event with the same bytes.
- So `out` = `FLAT (MAP written_bytes …)` of the model prefix. By the M1
  output equation, that is `R` at Success.

**L-EXIT** (connects the halt to the exit status). From the `cml_exit` step
theorem and `linux_exit_rel`: at `halt_pc` the status is 0 if and only if
`x0 = 0`, if and only if `Halt Success` (`targetSemScript.sml` 138-140).
Every other exit goes through `ffi_fail` with status 2.

**How the proof would go** (design):
1. O11 + O12 give `refund_env_ok_sl` for `envT = envmc with ffi_interfer := tot V realfx`.
2. `refund_profile_a_sl` at the ELF base (O13) gives the model behaviour set and the output equation for `refund_mc base envT`, for EVERY `fs` with the 4 file-system premises.
3. For a native run, O16 picks `fs_run` whose numchars are the run's counts.
4. O15 shows the native run equals the `envT`-machine run under `fs_run` up to `halt_pc`, or up to the first call where V fails or a syscall errs. There the native process exits 2, and its `out` is the model's prefix so far.

**Termination and resource exhaustion stay SEPARATE from authorization.**
- Only `st = 0 ∧ out = R` can authorize. The caller must also apply the
  B3 contract D0-D12 (exact frame).
- Resource_limit_hit gives `x0 ≠ 0` at `halt_pc`, so status 1.
- A fail-closed exit gives status 2.
- A kill gives no status.
- None of these authorizes. No completion, memory or time bound is claimed.
  That would need `is_safe_for_space`, which no program in the tree proves
  (`CK/compiler/backend/proofs/backendProofScript.sml` 2819, 5005; W7).

---

## 6. GO / NO-GO and the smallest executable proof milestone

**Recommendation.**
- NO-GO for B1 as the route to a closed argument. Reason: about 16
  obligations, four of which are assumptions about unpinned binaries that
  no proof can remove. The boundary moves only from "A3" to "libSystem
  axioms".
- **NO-GO for building or rewriting any runtime now.**
- **Conditional GO for ONE build-free B2c probe**, milestone M-B2c-0 below.
- Keep L1 (runtime-independent) as the first proof of either route.

Reasons:
- B2c removes these trusted dependencies of B1: dyld, the slide, `malloc`,
  `getenv`, libSystem `read`/`write`/`exit`/`fwrite`, the abort path and the
  C stack.
- It replaces them with 4 small kernel relations against a stable,
  documented ABI [gk].
- It reuses 58 of the 95 theories unchanged and 12 by method.
- Its safety theorem needs no reachable-call proofs.

The open risks that decide it are failure modes 1, 2, 4 and 10 above. The
probe tests 2 and part of 10 cheaply. Failure mode 1 can be checked by
reading a pinned Linux source, with no host needed.

**Milestone M-B2c-0** (candidate, not type-checked):
```
Theorem linux_ffiwrite_contract_valid:
  ∀p s s2 k bytes2.
    (* the 31 proposed words at a symbolic, 4-aligned address p; no build needed:
       the routine uses only PC-relative branches *)
    bytes_in_memory p ffiwrite_bytes s.MEM C ∧ s.PC = p ∧ arm8_ok s ∧ ¬s.SCTLR_EL1.A ∧
    aligned 2 (s.REG 30w) ∧ DISJOINT C D ∧
    s.REG 1w = 8w ∧ read_bytearray (s.REG 0w) 8 (mem_in D s) = SOME [0w;0w;0w;0w;0w;0w;0w;1w] ∧
    read_bytearray (s.REG 2w) (w2n (s.REG 3w)) (mem_in D s) = SOME bytes2 ∧
    bytes2 = n1::n0::o1::o0::tll ∧ w22n [n1;n0] + w22n [o1;o0] ≤ LENGTH tll ∧
    (* first part: up to the svc *)
  ⇒ ∃s1. arm8_run 22 s = SOME s1 ∧ s1.PC = p + 88w ∧ s1.REG 8w = 64w ∧ s1.REG 0w = 1w ∧
         s1.REG 2w = n2w (w22n [n1;n0]) ∧ s1.REG 1w = s.REG 2w + 4w + n2w (w22n [o1;o0]) ∧
         frame s s1 (x19-x30, memory) ∧
    (* second part: through the assumed syscall to the return *)
    (linux_write_rel P s1 s2 bs ∧ s2.REG 0w = n2w k ∧ k ≤ w22n [n1;n0] ⇒
       ∃s3. arm8_run 8 s2 = SOME s3 ∧ s3.PC = s.REG 30w ∧ arm8_ok s3 ∧
            (∀a. a ∈ D ⇒ s3.MEM a = asm_write_bytearray (s.REG 2w) (0w :: n2w2 k ++ o0 :: tll) s.MEM a) ∧
            (∀r. r ∈ {19..25,27,28} ⇒ s3.REG (n2w r) = s.REG (n2w r)))
```
The corollary links this to the oracle. With `fs.numchars` head = k, fd 1
in `WriteMode`, and `ffi_write conf bytes2 fs = SOME (FFIreturn nb fs')`,
the new bytes `nb` equal `0w :: n2w2 k ++ o0 :: tll` (fsFFIScript 333-348,
214-230).

- **Parents:** the HOL `arm8_step` heap (`L3A/step`) for the step part.
  The cake heap with `fsFFI` and `targetSem` for the corollary.
  `forge_refundEnvModel` for the contract name, if it is stated as
  `refund_ffi_contract`. No new parent build.
- **Time class:** hours. The U397 23-step write path replayed in 185 s plus
  604 s (C56, C57). Development took about one day in M1 (U397-U398).
- **Alive if** it proves with only the stated premises.
  **Costly or dead if** a new premise appears that Linux cannot meet, or
  the step library needs new support beyond a C60-like unaligned lemma.
- **Negative controls** (each must FAIL or be proved false):
  1. The same words with `b.lo` at word 16 replaced by `b.ls` (off-by-one
     bound). The stated contract must not be provable. Better: prove its
     negation with a witness where alen = n + off + 4 takes the fail branch.
  2. Drop `k ≤ n`. Prove that with k = n + 1 the run reaches the
     `exit_group` `svc`, not x30.
  3. Change conf to fd 2. Prove that the run reaches `ffi_fail`.
  4. Swap words 29 and 30. The memory clause must fail.

**Not to be done yet:**
- no runtime source file and no edit to the exporter output;
- no assembler, linker or build;
- no Linux host set-up;
- no new executable or digest;
- no change to the macOS executable `b8ed5ec2…`, its records or the
  conformance bundle;
- no claim of "verified native execution";
- no change to protected files.

**Owner decisions needed:**
1. Approve the M-B2c-0 HOL probe: local, existing heaps, limits shown first.
2. Is Linux ARM64 an acceptable deployment platform? If deployment stays
   on macOS, B2c proves a property of a different artifact.
3. Later: a Linux ARM64 host for native tests (VM or hardware; Docker is
   the owner's call).
4. Later: a new executable means a new SHA-256, a new image theorem, a new
   conformance run and a new record set. The macOS executable and its
   records are preserved unchanged.
5. Accept the 6 named assumptions as a new profile ("Profile L"), the way
   Profile A was accepted, with the processor/system-register item
   explicit.
6. Whether to pursue the custom 2-call FFI with F2.7 (1.6). That is a
   separate decision that changes the program.

---

## 7. Links for the top-level graph (B2c)

Today every new B2c link is MISSING or ASSUMPTION. The only
MACHINE-CHECKED links are the layout-independent CakeML ones, and those
hold only as model statements. The ASSUMPTION rows are NOT approved and
NOT yet written as HOL text.

| from | to | statement | class | evidence | what would upgrade it |
|---|---|---|---|---|---|
| ELF file bytes | HOL constant `refund_elf` with code/bitmaps at `p_vaddr` | none | MISSING | no ELF exists | O1 (C42 method) |
| ELF headers | load map (`PT_LOAD`, `e_entry`) | none | MISSING | — | O2, in-HOL header check |
| `execve` | entry state s0 | `linux_execve_rel` (1.5, candidate) | ASSUMPTION | [gk] `fs/binfmt_elf.c` | stays an assumption; Linux-host test |
| real core | L3 + `arm8_ok` | `proc_rel` | ASSUMPTION | Q1 accepted for macOS only; TBI0/SA0 conflict [gk] | O19 abstraction lemma |
| s0 | slots written, at `cml_main` | none | MISSING | — | O4 |
| `cml_main` | `installed` state at the ELF base | none for ELF (Mach-O: `cml_main_run_sl` U405, 28/30 clauses U407) | MISSING | method MACHINE-CHECKED for Mach-O | O5, O6 |
| code bytes + `installed` | `machine_sem ⊆ extend_with_resource_limit (source)` | `refund_compile_correct_no_handler` (U386), generic in mc0 | MACHINE-CHECKED (model) | C29-C34 replayed (M1R-1) | independent replay |
| source + canonical stdin | output equation | U387/U388 source specs; `refund_profile_a_sl` shape | MACHINE-CHECKED (model, Mach-O base) / MISSING at ELF base | e4-0001 | O13 |
| model FFI call | routine at the `svc` | none | MISSING | — | O7, O8 |
| `svc` read/write | post-state | `linux_read_rel`, `linux_write_rel` | ASSUMPTION | [gk] read(2)/write(2), unistd.h | stays an assumption |
| routine after `svc` | per-call contract (`realfx`) at valid calls | none | MISSING | — | O11 |
| invalid call / syscall error / trap | `exit_group(2)` | none | MISSING | — | O7-O9 |
| `realfx` + L1 | `refund_env_ok_sl` for envT | none | MISSING | — | O12, O13 |
| native run | model run (numchars witness) | none | MISSING | — | O15, O16 |
| model write events | bytes accepted on fd 1 | none (L-OUT) | MISSING | — | O17 |
| `halt_pc` | exit status | none (L-EXIT) | MISSING | trivial by construction | O18 |
| `exit_group` | status seen by caller | `linux_exit_rel` | ASSUMPTION | [gk] exit_group(2) | stays an assumption |
| stdin | request bytes, then EOF; pipe or file | premise of `linux_execve_rel` | ASSUMPTION | Q2/Q5 analogue; fail closed on errors | caller check |
| other agents | no memory or register writes | `iso_rel` | ASSUMPTION | U392 identity environment | admission boundary (B5) |
| real Linux process | observed output | none | MISSING | no Linux run; the macOS 2,466-vector run does not transfer | conformance on a Linux ARM64 host |

---

## 8. What I could not determine

- The real Linux EL0 values of `TCR_EL1.TBI0` and `SCTLR_EL1.SA0`/`A` ([gk]
  says TBI0 = 1 and SA0 = 1). This is not checked against a pinned kernel.
- Whether CakeML byte-array and conf pointers are always 8-aligned. That
  decides whether a C60-like unaligned-load lemma is needed.
- Whether the CakeML `code` term is literally identical in a Linux build.
  It is expected from the exporter text; there was no build.
- The `cbspace` and the addresses of a real link. These are design
  parameters until a build.
- The read buffer size and the number of read calls per canonical run.
- Whether any basis path calls close at program end. Inspection says no
  (U396).
- The FFI name list of an F2.7 program.
- Whether the simulation in the native-to-model direction (O15) fits in
  "days". No stored proof has that direction.
- The cost of O19 compared with keeping it as an assumption.

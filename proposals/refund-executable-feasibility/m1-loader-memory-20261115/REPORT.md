# U389: bytes of the linked executable equal the stored code and bitmaps; loader-memory clauses composed with the 27 `cml_main` steps under an explicit image premise

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted. Nothing committed.
Local results: same machine, same agent, cached parents. No clean replay. No independent replay. No native execution.

Run directory: `results/refund-loader-memory-local-20261115/attempt-0001`.
All U386, U387 and U388 theories are imported unchanged. The published `compile_correct'` control is re-checked in `import-0002`.

The request names an ELF. The artifact is a Mach-O 64-bit arm64 executable. This report uses the Mach-O terms.

## 1. Commands and actual exits

CakeML context: `python3 -I -B run_case.py <case> <source> <deps…>` through `go.sh`, `go-ld.sh`, `go-cp.sh`, `go-sat.sh`, `go-imp.sh`.
ARMv8 context: `python3 -I -B run_arm8_case.py <case> <source> <theory-case> <theory>`.
Layout tool: `python3 -I -B extract_macho.py <executable> > macho-layout.json`.
Exact argument vectors: `records/ld/<case>/command.json`. Full list: `records/exits.json`.

| Case | Exit | Kind |
| --- | --- | --- |
| `extract_macho.py` | 0 | tool: Mach-O layout, read-only |
| `frame-0001` | 0 | `cml_main_run_frame`, ARMv8 context, 15 s |
| `lemmas-0001` | 1 | authoring |
| `lemmas-0002` | -15 | authoring: a search did not end; I stopped the child (SIGTERM) |
| `lemmas-0003` | 0 | general memory lemmas |
| `loader-0001` | 1 | authoring: stored `code` is not a list literal (section 2) |
| `diag-0001` | -24 | TOOL: CPU limit while a diagnostic printed a large term |
| `diag-0002` | 0 | diagnostic: stored terms evaluate to list literals |
| `loader-0002`, `loader-0003` | 1 | authoring (two, then four proofs) |
| `image-0001` | 0 | file constant, layout, header fields, image predicate, 313 s |
| `compose-0001`, `compose-0002` | 1 | authoring |
| `compose-0003` | 0 | composition and six negative controls |
| `entrysat-0001` | 1 | authoring |
| `entrysat-0002` | 0 | non-vacuity control |
| `import-0001` | 1 | authoring (expected term form) |
| `import-0002` | 0 | 46 exact statements, 516 closure nodes, controls |
| `frame-repeat`, `lemmas-repeat`, `image-repeat`, `compose-repeat`, `entrysat-repeat` | 0 each | every exported file byte-identical |

Tool failures: `diag-0001`. Operator stop: `lemmas-0002`. Memory failures: none. Logical failures: none.
Each runner records the SHA256 of the executable before and after the child (`inputs_unchanged_after: true` in every case).

## 2. Exact executable bytes

Artifact: `results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund`, 238776 bytes,
SHA256 `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`. `native_execution: NOT_RUN`.

Extraction (`macho-layout.json`; `otool -hv`, `otool -l`, `nm -n`, `xcrun dyld_info -fixups` agree):

| Item | Value |
| --- | --- |
| Header | `MH_MAGIC_64`, arm64, `MH_EXECUTE`, 18 load commands, flags `0x200085` (`MH_PIE` set) |
| `__TEXT` | vmaddr `0x100000000`, file offset 0, file size 163840, protection r-x |
| `__DATA_CONST` | vmaddr `0x100028000`, file offset 163840, file size 16384 |
| `__DATA` | vmaddr `0x10002C000`, file offset 180224, file size 32768, protection rw- |
| `LC_MAIN` | entry offset 152900 (`_main` at `0x100025544`; C run-time code, not `cml_main`) |
| `cml_main` | `0x100004000`, file offset 16384, 108 bytes, SHA256 `9e010ce3…ef107f86` |
| Compiled code | `cake_main` `0x1000040D0`, file offset 16592, 130436 bytes, SHA256 `3c67983c…4ba15deb` |
| Code buffer | `0x100023E54`–`0x100024000`, 428 bytes, all `nop` words (not used by any clause proved here) |
| Slots | `cml_heap`, `cml_stack`, `cml_stackend` at `0x10002C000`, file offset 180224, 24 zero bytes in the file |
| Bitmaps | `cake_bitmaps` `0x10002C018`, file offset 180248, 2531 words, SHA256 `68d3f080…8f36fb76` |
| Relocation data | `LC_DYLD_CHAINED_FIXUPS`: 23 binds, all in `__DATA_CONST,__got`. No fixup in `__TEXT`. No fixup in the bitmap range. No rebase |

Tool comparison (not a proof): the `.byte` lines of `refund.S` between `cake_main` and `cake_codebuffer_begin` give 130436 bytes;
they equal the file slice at offset 16592 with 0 differences.

`loader-0001` stopped with "code slice differs from the stored code". Cause: the stored definition is
`code = to_list to_word <compute value>`, not a list literal. `diag-0002` evaluated it in the kernel to a 130436-element literal.
From `loader-0002` on, the proof uses `code = <literal>` obtained by that kernel evaluation. No byte differs.

## 3. File constant and layout (`forge_refundImage`, `image-0001`)

- `refund_file : word8 list` is defined as the 238776 bytes of the artifact. ML code in the proof script reads the file (`BinIO`).
  This reader is trusted. Check: the script writes the bytes of the stored term to `roundtrip.bin`; its SHA256 is `b8ed5ec2…39007bb8`,
  the SHA256 of the artifact (both runs).
- Kernel evaluation of `APPEND` proves `refund_file = P ++ STUB ++ Q ++ code ++ T2 ++ M ++ FLAT (MAP dword_bytes (MAP n2w data)) ++ E`
  with lengths 16384, 108, 100, 130436, 16812, 16408, 20248, 38280.
- `refund_file_code`: `TAKE (LENGTH code) (DROP 16592 refund_file) = code`.
- `refund_file_bitmaps`: `TAKE 20248 (DROP 180248 refund_file) = FLAT (MAP dword_bytes (MAP n2w data))` (little-endian 64-bit words).
- `refund_file_cml_main`: the 108 bytes at offset 16384 (they are the 27 words of U388).
- `refund_file_length`: `LENGTH refund_file = 238776`.
- `refund_macho_fields`: 18 header fields and two segment names evaluated from `refund_file`: magic, file type, command count, flags;
  `__TEXT` and `__DATA` command, vmaddr, vmsize, fileoff, filesize, initprot; `LC_MAIN` command and entry offset.
  The field offsets come from the Python tool; the values are kernel-checked. HOL contains no Mach-O parser.

`code` and `data` are the stored constants of `forge_refundArm8Compile`, the same constants that `refund_installed_no_handler` names.

## 4. Image predicate (ASSUMED of a memory; not proved of any loader)

`refund_image_mem sl m ⇔ bytes_in_memory (0x100000000w + sl) (TAKE 163840 refund_file) m 𝕌 ∧ bytes_in_memory (0x10002C018w + sl) (TAKE 20248 (DROP 180248 refund_file)) m 𝕌`

It says: the complete `__TEXT` segment and the bitmap part of `__DATA` are in memory `m` at link address plus slide `sl`.
It does not include the three slots (the C run-time writes them) or the other segments.

For every slide (PROVED):

- `refund_image_code`: `refund_image_mem sl m ⇒ bytes_in_memory (0x1000040D0w + sl) code m 𝕌`.
- `refund_image_bitmaps`: `refund_image_mem sl m ∧ i < LENGTH data ⇒ mem_dword m (0x10002C018w + sl + n2w (8 * i)) = n2w (EL i data)`.
- `refund_image_cml_main`: the 108 `cml_main` bytes at `0x100004000w + sl`.

## 5. Composition with the 27 steps (`forge_refundLoaderMemory`, `compose-0003`; slide 0 only)

`cml_main_run_frame` (`frame-0001`, ARMv8 context): the 27 steps of U388 are derived again from the stored definitions
(`PRE_DEFINITION_IDENTICAL true`, `RUN_STATEMENT_IDENTICAL true`). New conjuncts:
`∀a. (∀i. i < 40 ⇒ a ≠ h + n2w i) ⇒ s1.MEM a = s.MEM a`, and `PSTATE`, `SCTLR_EL1`, `TCR_EL1`, `exception` unchanged.

`refund_entry_pre s h stk e ⇔` the four control bits, `s.PSTATE.EL = 0w`, `s.exception = NoException`, `s.PC = 0x100004000w`,
the three slot values `h`, `stk`, `e`, `aligned 3 h`,
`∀i a. i < 40 ∧ 0x100000000w ≤₊ a ∧ a <₊ 0x100030F30w ⇒ h + n2w i ≠ a`, and `refund_image_mem 0w s.MEM`.

Against U388 `cml_main_pre`: the 108 explicit code-byte equations are replaced by the image predicate, and the separation
range grows from `[0x100004000, 0x10002C018)` to `[0x100000000, 0x100030F30)`. The larger range is necessary: see control 6 in section 6.
`refund_entry_pre_IMP_cml_main_pre`: `refund_entry_pre s h stk e ⇒ cml_main_pre s h stk e`.

**Strongest new theorem, `refund_loader_startup`:**

```
refund_entry_pre s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ⇒
∃ms. arm8_run 27 s = SOME ms ∧ ms.PC = 0x1000040D0w ∧ ms.REG 1w = h ∧ ms.REG 3w = e ∧
     refund_image_mem 0w ms.MEM ∧
     bytes_in_memory ms.PC code ms.MEM 𝕌 ∧
     (∀md k. (∀i. i < LENGTH code ⇒ ms.PC + n2w i ∈ md ∧ ms.PC + n2w i ∉ k) ⇒ bytes_in_mem ms.PC code ms.MEM md k) ∧
     (∀mc0. is_arm8_machine_config mc0 ∧ (∀i. i < LENGTH code ⇒ ms.PC + n2w i ∈ mc0.prog_addresses) ⇒ code_loaded code mc0 ms) ∧
     (word_list 0x10002C018w (MAP (Word ∘ n2w) data) * word_list_exists (0x10002C018w + bytes_in_word * n2w (LENGTH data)) 0)
       (fun2set ((λa. Word (mem_dword ms.MEM a)), byte_aligned ∩ refund_bitmaps_dm)) ∧
     (∀a. ∃w. ms.MEM a = get_byte a w F ∧ Word (mem_dword ms.MEM (byte_align a)) = Word w) ∧
     ∀mc0 t. is_arm8_machine_config mc0 ∧ target_state_rel mc0.target t ms ∧ target_configured t mc0 ⇒
             refund_startup_clause mc0 ms t (λa. Word (mem_dword ms.MEM a)) 0x10002C018w 428 0
```

`refund_bitmaps_dm = {x | ∃i. i < LENGTH data ∧ byte_align x = 0x10002C018w + n2w i * 8w}`;
`refund_bitmaps_dm_closed`: `byte_align a ∈ refund_bitmaps_dm ⇒ a ∈ refund_bitmaps_dm`.
Other stored parts: `refund_image_preserved`, `refund_image_bitmap_clause`, `code_loaded_from_memory`.

General lemmas (`forge_loaderMemLemmas`, `lemmas-0003`): `bytes_in_mem_iff`, `bytes_in_memory_univ_EL`, `read_bytearray_from_EL`,
`dword_bytes_in_memory`, `mem_dword_get_byte`, `mem_dword_word_memory_clause`, `word_list_fun2set`, `word_list_clause_read`,
`word_list_exists_0`. They use published `word_list_seteq` and `word_list_EL_in_memory`.

## 6. Negative controls

Stored theorems (`compose-0003`):

1. Changed code byte, `code_byte_change_rejected`: `i < LENGTH code ∧ m (a + n2w i) ≠ EL i code ⇒ ¬bytes_in_mem a code m md k`.
2. Bitmap corruption, `bitmap_word_change_rejected`: a word that differs from `n2w (EL i data)` refutes the bitmap `word_list` clause, for every `dm` and frame `r`.
3. Incorrect code offset, `code_wrong_offset_rejected`: `refund_image_mem 0w m ⇒ ¬bytes_in_mem 0x1000040D4w code m md k`.
4. Incorrect bitmap offset, `bitmap_wrong_offset_rejected`: with the image in memory, the clause at `0x10002C020w` is false.
5. Overlap with the excluded set, `code_overlap_rejected`: `i < LENGTH code ∧ a + n2w i ∈ k ⇒ ¬bytes_in_mem a code m md k`.
6. Overlap of the header with the bitmaps, `header_on_bitmaps_refuted`: `cml_main_pre s 0x10002C018w stk e ⇒ ∃ms. arm8_run 27 s = SOME ms ∧ ∀dm r. ¬(bitmap clause at ms)`.
   The U388 pre-state permits a heap pointer on the bitmaps. The 27 steps then destroy the first bitmap word. This is a counterexample to
   "U388 pre-state ⇒ bitmap clause". It is the reason for the larger separation range.

Checks in the script at ML level (`image-0001`, each `CONTROL_OK … REJECTED`): one changed code byte (file offset 17592); one changed
bitmap byte (offset 180248); code offset shifted by 4; bitmap offset shifted by 8. The frame run shows that a header byte does change.

Non-vacuity (`entrysat-0002`): `refund_entry_pre_satisfiable`: `∃s h stk e. refund_entry_pre s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h`.
The witness is a constructed state. It is not evidence that the loader or the C run-time produces such a state.

Earlier controls: the seven negative controls of U386 and the U386–U388 scope controls pass again in `import-0002`.
New scope controls there: no U389 theorem states the installed-state predicate; the image predicate is a premise wherever it is used
(only the constructed witness memory satisfies it without a premise); every U389 theorem about `arm8_run` is at slide 0;
`refund_image_mem` contains no loader or step model.

## 7. Address slide

- `MH_PIE` is set (kernel-checked flag value `0x200085`). A system loader normally applies a non-zero slide to such an executable.
- Valid for every slide: the image lemmas of section 4.
- Valid at slide 0 only: `cml_main_run`, `cml_main_run_frame`, `refund_entry_pre`, `refund_loader_startup`, the bitmap pointer `0x10002C018`,
  the header words, and every address in the start-up clause.
- OPEN: slide correctness. No theorem here covers a state with a non-zero slide. Under the default loader the slide-0 premise is probably
  false for a real process. This was not measured: the executable was not run.
- The fixup data shows no rebase and no bind in `__TEXT` or in the bitmap range. This supports, by inspection only, that the same file
  bytes are in memory under a slide. It is not a proof of loader behaviour.

## 8. Assumption ledger for `refund_loader_startup`

| Premise | Class |
| --- | --- |
| `refund_image_mem 0w s.MEM` at entry to `cml_main` (loader maps the file; no write to `__TEXT` or the bitmaps before entry; slide 0) | ASSUMED |
| Control bits, user mode, no exception, `s.PC = 0x100004000w` | ASSUMED (no model of process entry or the C run-time) |
| Slot values `h`, `stk`, `e`; `aligned 3 h`; the 40 header bytes do not meet `[0x100000000, 0x100030F30)` | ASSUMED |
| `aligned 3 e`, `h ≤₊ e`, `8192w ≤₊ e − h` | ASSUMED |
| `refund_file` is the artifact's bytes | ML reader, trusted; round-trip SHA256 equal |
| Mapping rule "file offset `o` of a segment is at `vmaddr + (o − fileoff) + sl`" | part of the definition of `refund_image_mem`; segment values kernel-checked from the header |
| L3 ARMv8 model `NextStateARM8` | published model, as in U388 |

Dependency closure (`import-0002`): 516 theory nodes; axioms only `bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX`, `bool.BOOL_CASES_AX`;
every stored theorem and definition of the five new theories has tag `DISK_THM` only and no hypothesis.
New theories: `forge_refundCmlMainFrame` (1 theorem), `forge_loaderMemLemmas` (16, 1 definition), `forge_refundImage` (13, 3),
`forge_refundLoaderMemory` (13, 2), `forge_refundEntrySat` (7, 1).

## 9. Installed-state clauses after U389

For the state `ms` after the 27 steps, with `m = λa. Word (mem_dword ms.MEM a)`, `bitmap_ptr = 0x10002C018w`,
`bitmaps_dm = refund_bitmaps_dm`, `cbspace = 428`, `data_sp = 0`, and an asm state `t` still to be chosen:

| Clause of `refund_installed_no_handler` | Class |
| --- | --- |
| `code_loaded code mc0 ms` | CONDITIONAL: proved from `refund_entry_pre`; needs the code range inside `mc0.prog_addresses` (a parameter) |
| `bytes_in_mem t.pc code t.mem t.mem_domain (heap_stack_dm ∪ bitmaps_dm)` | CONDITIONAL: byte content proved from `refund_entry_pre`; needs `t.mem = ms.MEM` on the range, the range inside `t.mem_domain` and outside the two sets |
| Bitmap `word_list` clause with `word_list_exists … 0` | CONDITIONAL: proved from `refund_entry_pre` |
| `∀a. ∃w. t.mem a = get_byte a w F ∧ m (byte_align a) = Word w` | PROVED for `ms.MEM`; needs `t.mem = ms.MEM` |
| `byte_align` closure of `bitmaps_dm` | PROVED (`refund_bitmaps_dm_closed`); the heap part is OPEN |
| pc equation, pc alignment, five header words | CONDITIONAL (U388, now also from `refund_entry_pre`) |
| Register alignment, order, distance | ASSUMED (values `h`, `e`) |
| `heap_stack_dm ∪ bitmaps_dm ⊆ t.mem_domain`; code-buffer clauses; `DISJOINT heap_stack_dm bitmaps_dm`; size bounds | OPEN |
| `target_state_rel`, `target_configured`, `start_pc_ok`, `interference_ok`, `ffi_interfer_ok`, shared-memory and `mmio` clauses | OPEN |

By obligation: 1 partly proved, rest OPEN (unchanged). 2 CONDITIONAL, pre-state ASSUMED, slide OPEN. 3 OPEN. 4 no clause; the U298
exclusion holds for every handler. 5 content clauses CONDITIONAL on the image premise; domain clauses OPEN; loader behaviour ASSUMED.
6 OPEN. The installed-state predicate is not established for any state. Loader correctness is not inferred from the file inspection.

## 10. Verdicts

- Code and bitmap memory correspondence: PROVED between the artifact's file bytes and the stored `code` and `data` (kernel evaluation),
  and from the image predicate to the memory clauses, for every slide. That a loader establishes the image predicate: ASSUMED.
- Start-up composition: PROVED CONDITIONALLY at slide 0 (`refund_loader_startup`). The 27 steps keep the image, end at `cake_main`
  with x1 = `h` and x3 = `e`, and the end state has the code and bitmap memory clauses and the U387 start-up clause.
- Success criterion of the request: met in the stated conditional form, on this machine with cached parents. Not independently replayed.

## 11. Counterexamples and blockers

Counterexample found: `header_on_bitmaps_refuted` (section 6, control 6). No other counterexample. No logical blocker.
Not done: clean replay; independent replay; native execution; any loader, C run-time or slide model.

## 12. Smallest next proof obligation

Construct the asm state `t` and the domains for the proved end state, at slide 0: `t.mem = ms.MEM`, `t.regs`, `t.pc`, an explicit
`t.mem_domain` (code, code buffer, heap, bitmaps). Prove the domain clauses of obligation 5: the two subset and membership clauses,
the code-buffer clause, `DISJOINT heap_stack_dm bitmaps_dm`, and the size bound. This needs one new explicit premise: the heap range
`[h, e)` does not meet `[0x100000000, 0x100030F30)`. After that: `target_state_rel` and `target_configured` for this `t`; then the slide.

M1 open. Integration EXIT NOT_ESTABLISHED. end_to_end=false.

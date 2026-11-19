# Y3: link X7, lemma L3 — reachable FFI calls of the refund program

Status: READ and DRAFT only. Nothing ran (no HOL, no build). Every theorem below is a CANDIDATE unless it is
quoted as stored. Draft script: `Y3-readArgs.sml` (this folder), NOT RUN.

## 1. Validity predicate V of the real C code versus the HOL oracle

Sources read: pinned `basis/basis_ffi.c` 107–197; `basis/fsFFIScript.sml` 103–362; `basis/basis_ffiScript.sml` 19–98;
`semantics/ffi/ffiScript.sml` 64–80 (`call_FFI`); `targetSemScript.sml` 60–74. Asserts are compiled in: the binary
binds `___assert_rtn` (`drafts/macho-extraction/dyld_fixups.txt` line 4); no `NDEBUG`.

Common C facts (all four functions):
- `clen`, `alen` are `long`: x1, x3 read as SIGNED 64-bit. The model uses `w2n` (unsigned). So `word_msb x3` gives
  a negative `alen` in C (every `alen >= …` assert fails) but a huge length in the model.
- `byte8_to_int(c)` returns `int`. `(long long)b[0] << 56` with `b[0] >= 0x80`, and `b[4] << 24` with `b[4] >= 0x80`
  (int shift into the sign bit), are signed overflow: UNDEFINED behaviour (C11 6.5.7p4). The conversion of the
  64-bit value to `int` is implementation-defined (clang: low 32 bits). The model decodes `w82n conf` (0 … 2^64−1).
- `byte2_to_int(a)` reads `a[0..1]` (and `a[2..3]` for write) BEFORE the length assert: out-of-bounds read if
  `alen < 2` (`< 4` for write). The model returns `NONE` (FFI_final) for fewer than 4 bytes: not a returning call.

| name | C validity predicate V (abort-free and defined) | model `FFIreturn` condition | difference as a concrete RETURNING model call state |
|---|---|---|---|
| read (idx 0) | `clen = 8` (assert 161); `n + 4 <= alen` signed (assert 164), `n = a[0]*256+a[1]`; conf bytes give no UB (b[0], b[4] < 0x80); errno paths: `read` < 0 (EBADF, EINTR, EIO, EAGAIN, EFAULT, EISDIR) gives `a[0]=1` | `LENGTH bytes >= 4`. Success needs `LENGTH conf = 8`, `n <= LENGTH tll` (= alen−4), fd in `infds` with ReadMode, `numchars` not empty. ANY other case with >= 4 bytes returns the error answer `LUPDATE 1w 0 bytes` | (R-a) x1 = 7, x3 = 5, a = [0,1,0,0,0]: model returns [1,1,0,0,0]; C aborts (stated as control `model_read_returns_where_c_aborts`). (R-b) x1 = 8, x3 = 4, a = [0,1,0,0]: model error answer; C aborts. (R-c) x1 = 8, x3 = 2^63+4100 (msb set): model may succeed; C aborts (alen < 0). (R-d) conf = [0,0,0,1,0,0,0,0]: model fd 2^32 → error answer; C fd = 0 → reads stdin (UB-free here, impl-defined) |
| write (idx 1) | `clen = 8` (176); `n + off + 4 <= alen` signed (180); conf no UB; errno: `write` < 0 gives `a[0]=1`; SIGPIPE on a closed pipe kills the process (no return, not an errno path) | `LENGTH bytes >= 4`. Success needs `LENGTH conf = 8`, `off <= LENGTH tll`, `n <= LENGTH tll − off` (inside `fsFFI$write`), fd WriteMode, `numchars ≠ [||]`. Else error answer | (W-a) x1 = 7, x3 = 2052, a = [0,5,0,0,…]: model error answer; C aborts. (W-b) x1 = 8, x3 = 6, n = 5, off = 0: model error answer; C aborts. (W-c) msb x3: model success; C aborts. (W-d) fd decode as R-d |
| close (idx 2) | `alen >= 1` signed (192); `clen = 8` (193); `close(fd)` ≠ 0 gives `a[0]=1` | outer asserts `LENGTH bytes >= 1 ∧ LENGTH conf = 8` else `NONE` (stored `ffi_close_accepts_only_valid_lengths`, U394 compose-0018). Success needs `closeFD`: fd in `infds` AND `isFile` inode | abort layer agrees except (C-a) msb x3: model returns, C aborts. Answer differences (not abort): (C-b) conf = n2w8 0: model 1w (stdin is a `UStream`, `isFile` false), C `close(0)` = 0 → 0w. (C-c) fd ≥ 2^32 as R-d |
| open_in (idx 3) | `alen >= 9` signed (139); conf read as a C string: a NUL byte must lie inside the `clen` bytes, else out-of-bounds read (UB); no `clen` assert; `open` < 0 gives `a[0]=1` | success needs `9 <= LENGTH bytes`, a NUL in conf (`getNullTermStr`), the name in `fs.files`, `nextFD <= maxFD`. Else, if `0 < LENGTH bytes`, error answer | (O-a) x3 = 1…8: model error answer; C aborts. (O-b) x1 = 3, conf "abc" (no NUL), x3 = 9: model error answer; C reads past the buffer (UB). (O-c) x1 = 0, x3 = 9: model error answer; C reads c[0] out of bounds. (O-d) msb x3. Answer differences: real file table versus `fs.files`; real lowest free fd versus `nextFD` (differs if the process inherited fd 3+) |

Result-byte layouts agree on all four names (C writes `a[0]`, `a[1..2]` big-endian, keeps `a[3]` and the tail; the model
`0w :: n2w2 k ++ [pad2] ++ …` for read, `0w :: n2w2 nw ++ (off0 :: tll)` for write, `LUPDATE v 0` for close,
`0w :: n2w8 fd ++ DROP 9` for open_in). Count differences (model `k = MIN n (MIN (len−off) (SUC strm))`, real kernel any
`0..n`) are answer differences for the native contract, not validity.

Proposed `Vok i nb ms` (index-keyed; nb is not needed):
```
V_read  ms ⇔ ms.REG 1w = 8w ∧ (∀j. j < 8 ⇒ ms.MEM (ms.REG 0w + n2w j) = EL j (n2w8 0)) ∧
             w22n [ms.MEM (ms.REG 2w); ms.MEM (ms.REG 2w + 1w)] + 4 ≤ w2n (ms.REG 3w) ∧ ¬word_msb (ms.REG 3w)
V_write ms ⇔ ms.REG 1w = 8w ∧ (conf bytes = n2w8 1) ∧
             w22n [a0;a1] + w22n [a2;a3] + 4 ≤ w2n (ms.REG 3w) ∧ ¬word_msb (ms.REG 3w)
V_close ms ⇔ F      V_open ms ⇔ F      (this program; see §4)
Vok i nb ms ⇔ (i = 0 ⇒ V_read ms) ∧ (i = 1 ⇒ V_write ms) ∧ (i = 2 ⇒ V_close ms) ∧ (i = 3 ⇒ V_open ms)
```
The conf-byte conjunct removes the UB of `byte8_to_int` (R-d/W-d). `V_close = V_open = F` is the strongest form and is
TRUE for this program only if no close/open_in call returns (§4). This is the abort/UB layer only; the path layer
(frame, alignment, image bytes; U401 `write_call_residual`, U394 `fficlose_call_pre`) stays separate.

## 2. First theorem for read

Exact statement (X7's form, unchanged), plus a slide-free form `_g` with premises
`mc1.target = arm8_target ∧ mc1.ptr_reg = 0 ∧ mc1.len_reg = 1 ∧ mc1.ptr2_reg = 2 ∧ mc1.len2_reg = 3` instead of `refund_static`:
```
successful_read_call_state_has_valid_arguments:
  refund_static mc1 dm ∧ ffi1.oracle = basis_ffi_oracle ext ∧
  read_ffi_bytearrays mc1 ms1 = (SOME c, SOME ab) ∧
  call_FFI ffi1 (ExtCall «read») c ab = FFI_return ffi2 (0w::rest) ⇒
  ms1.REG 1w = 8w ∧ w22n [ms1.MEM (ms1.REG 2w); ms1.MEM (ms1.REG 2w + 1w)] + 4 ≤ w2n (ms1.REG 3w)
```
Builds on (stored, read in `args-0006/proof.sml`): `refund_static_def` (forge_refundCallSite),
`write_call_arrays_are_the_register_arguments` and `read_bytearray_first_four` (forge_refundWriteArgs; name-generic).
New: `ffi_read_return_cases` (simpler than the write case: the two asserts give the bound directly, no `fsFFI$write`
lemma), `basis_read_call_is_ffi_read`, `ffi_call_arrays_are_the_register_arguments_g`.
Proof: oracle → `ffi_read` answer; return cases; the error branch has head `1w`, contradiction with `0w::rest`; the success
branch gives `LENGTH c = 8 = w2n x1` and `n + 4 ≤ LENGTH ab = w2n x3`.
Negative controls: `wrong_clen_read_never_succeeds`, `out_of_bounds_read_never_succeeds`, `short_array_read_is_rejected`,
`wrong_clen_register_gives_no_successful_read`, `model_read_returns_where_c_aborts` (the gap R-a as a theorem), and a scope
check that the conclusion has no `word_msb`.
Limit: successful read events only; `¬word_msb x3` not derived; nothing about which reads occur.

## 3. `refund_run_write_events_all_succeed` (and the read twin)

Exact statement (strengthened to a ∀ over the start state, so that it composes with any `ms` of `refund_profile_a_sl`):
```
refund_run_rw_events_valid:
  refund_entry_pre_sl sl s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ∧ refund_heap_clear_sl sl h e ∧
  envmc.prog_addresses = refund_mem_dm_sl sl h e ∧ refund_env_ok_sl sl envmc ∧
  stdin_content fs = SOME (explode (sexp_to_string (refund_request …))) ∧ wfcl cl ∧ wfFS fs ∧ STD_streams fs ∧
  arm8_run 27 s = SOME ms ⇒
  ∀k r ms' ffi'. evaluate (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi ext cl fs) k ms = (r,ms',ffi') ⇒
    EVERY refund_valid_event ffi'.io_events
refund_valid_event e ⇔
  (∃ab nb. e = IO_event (ExtCall «read»)  (n2w8 0) (ZIP (ab,nb)) ∧ LENGTH ab = 4100 ∧ TAKE 2 ab = n2w2 4096 ∧ HD nb = 0w) ∨
  (∃ab nb. e = IO_event (ExtCall «write») (n2w8 1) (ZIP (ab,nb)) ∧ LENGTH ab = 2052 ∧
           w22n [EL 0 ab; EL 1 ab] + w22n [EL 2 ab; EL 3 ab] ≤ 2048 ∧ HD nb = 0w)
```
`refund_run_write_events_all_succeed` (X7) is the write-only corollary (`HD nb = 0w` ⇔ `write_ok_event`).
The constants 4100 / 4096 / 2052 / 2048 are MY READING of the pinned source (TextIOProg 98–115, 191–209, 298–305, 386–405,
462–466): every read uses the instream `surplus` array (`openStdIn` = buffer size min 65535 (max 4100 1028) = 4100,
`read_into … (length − 4)`), never `iobuff`; every write uses `iobuff` (2052 bytes) with `n ≤ 2048`, `off + n` ≤ the first `n`.
Exact lengths give `¬word_msb x3` WITHOUT the U396 low-half premise (`addresses_below_half`).

Route, in order:
- (a) SRC-EV, the source theorem (the hard step, NOT derivable from `refund_semantics`):
  `… ⇒ sem_satisfies (semantics_dec_list (init_state (basis_ffi ext cl fs)) init_env refund_prog)
        (λb. ∃io. b = Terminate Success io ∧ EVERY refund_valid_event io)`.
  Method W-a′: re-prove the used TextIO specs with an FFI part that carries an event invariant and only the names
  read, write: `IOFS_rw fs = SEP_EXISTS evs. one (FFI_part (encode fs) (mk_ffi_next fs_ffi_part) [«read»;«write»] evs) *
  &EVERY refund_valid_event evs * IOFS_iobuff * &wfFS fs`. Specs on the path (pinned TextIOProofScript, 8,726 lines, 14
  `xffi`): writei 1406, write 1554, output_aux 1730, output 1817, print 1868, read_into 2132, openStdInSetBufferSize 2495,
  openStdIn 2524, refillBuffer_with_read 2725, input1 3200, refillBuffer_with_read_guard_spec_STR 6871, consume_rest 7592,
  inputBuff 8156, inputAll 8261, inputAllFrom_NONE 8338, then `refund_main_valid` and a `whole_prog_spec` variant whose
  `parts_ok` proof uses only the subset direction (a restricted part answers no more than the oracle). At the end
  `cfStore.parts_ok_def` line 32 (`EVERY (ffi_has_index_in (FLAT (MAP FST parts))) st.io_events`) and `ffi2heap_def`
  (events of a part = `FILTER` of all events) give the invariant for every event.
- (b) Lift to the machine: the stored chain composes `machine_sem ⊆ extend_with_resource_limit (semantics …)`; source
  semantics is deterministic, so SRC-EV transfers. GAP: I did not locate the stored intermediate theorem that states the
  inclusion before `extract_fs` is applied; if it is not stored, the last composition step must re-run with the stronger
  predicate.
- (c) Every clock: `machine_sem_total`, `evaluate_add_clock`, `evaluate_add_clock_io_events_mono` (pinned targetProps 1059–1134)
  give: the events at any clock k are a prefix of the unique `io`.
- (d) Events → `ffi_calls_ok` (lemma G, slide-free, no `machine_reach`): induction on k over the `ffi_calls_ok` recursion;
  at an `FFI_return` the new event `IO_event (ExtCall nm) c (ZIP (ab,nb))` lies in the final event list
  (`evaluate_io_events_mono`), `refund_valid_event` holds for it, and `ffi_call_arrays_are_the_register_arguments_g` turns
  `LENGTH c`, `LENGTH ab`, `ab[0..3]` into x1, x3 and memory: this gives `Vok`. Memory of conf bytes: the analogous
  first-eight lemma for `ptr_reg`.

## 4. Can a failed close / open_in event be excluded?

From `refund_semantics` alone: NO. Counterexample shape: let `io` be the run's events; insert after any prefix
`IO_event (ExtCall «close») (n2w8 7) (ZIP ([x], [1w]))` (fd 7 not in `infds`: `closeFD` NONE → error answer, `fs` unchanged),
or `IO_event (ExtCall «open_in») (MAP (n2w ∘ ORD) "nofile" ++ [0w]) (ZIP (bs, LUPDATE 1w 0 bs))` with 9 ≤ |bs|, or a
successful open_in of an existing file followed by a close of the new fd (`ADELKEY` restores `infds`). `extract_fs_with_numchars`
replays each event against the same oracle answer, so `extract_fs` is unchanged. The equation does not pin the list.

From the program source (READ, not proved): this program NEVER calls close or open_in.
`refund_main` = `case TextIO.inputAllFrom None of None => raise Fail … | Some wire => TextIO.print (refund_dispatch wire)`
(forge_refundStdioProgScript 10–16). `inputAllFrom None` → `open_option None` → `openStdIn ()` (array allocation, no FFI)
and the close thunk `fn () => consume_rest is` (→ `input1` → `refillBuffer_with_read` → `read_into` → `#(read)`).
`inputAll` → `inputBuff` (no FFI) and `refillBuffer_with_read_guard` (→ `#(read)`). The handler `handle e => (close (); raise e)`
calls the same thunk. `print` → `output stdOut` → `output_aux` → `write` → `writei` → `#(write)`. `refund_dispatch` is
`add_cakeml` code that calls only translated pure functions (WireProg 78–83; the translator emits no FFI).
`#(open_in)` occurs only in `raw_openIn` (TextIOProg 158), `#(close)` only in `raw_closeIn` 167 and `closeOut` 238; they are
reached only through `openIn`/`closeIn`, i.e. the `Some fname` branch of `open_option`, which is dead because the argument is
the constant `None`. The two names are linked (U391) because `inputAllFrom`'s code mentions that branch, not because it runs.
Basis top-level declarations run no FFI (every `#(` in `basis/*ProgScript.sml` is inside a `fun`).
Formal route: the same W-a′ re-proof with the names `[«read»;«write»]` in the fs part: `parts_ok` then forces
`EVERY (ffi_has_index_in [cl names; read; write])` on all events, i.e. no close/open_in event. With `V_close = V_open = F`
this is needed (not only convenient): open_in returns in the model where C aborts (O-a, O-b).

## 5. Slides

Yes. Every stored call-site fact is at slide 0: `refund_static` fixes the PCs 0x1000040A0/90/80/70, halt 0x1000040C0,
install 0x1000040B0 and `0x100004080w ∉ dm`; U400/U401 and `write_call_site_facts` start from
`refund_installed_no_handler mc0` / `refund_behavior_valid_request_no_handler` (slide 0); the native path theorems use
`refund_image_mem 0w` and absolute addresses (e.g. `b 0x1000251E0`).
For all slides: (i) the lemma G route of §3(d) needs no PC fact: `refund_mc_def` gives entry PCs `base − n2w ((3+i)*16)`
for any base, the register fields are stored (`refund_mc_register_fields_sl`), names stored (U391); G uses only
`find_index`, `EL i ffi_names`, the registers and the target. (ii) The start comes from `refund_profile_a_sl` (slide).
(iii) If the machine_reach route is kept instead: a `refund_static_sl sl` and a re-run of MAIN2/A0/A1/U401 with `sl + c`
(word-add cancellation for `find_index`). (iv) Path layer (native only): `refund_image_mem sl` and re-proof of each step
theorem; ADRP results move with the slide only if the slide is page-aligned (premise to check in `refund_entry_pre_sl`;
the stored control `misaligned_or_wrapping_slide_not_covered` suggests it is there; not read).

## 6. Ordered HOL runs (estimates are GUESSES)

1. FIRST: `Y3-readArgs.sml` → forge_refundReadArgs. Parents cached (CallSite, WriteArgs). 5–15 min per attempt, ≤ 3 attempts.
2. After X7's L1/L2 run (forge_refundRouteA2 exists): lemma G (`events_valid_gives_ffi_calls_ok`, slide-free) and the clock
   prefix lemma (§3 c). 15–40 min per attempt.
3. Locate or re-run the source-to-machine inclusion (§3 b). Minutes if stored; else one chain step (hours).
4. SRC-EV via W-a′ (§3 a, §4): about 15 TextIO specs + refund_main + whole_prog variant. Authoring days (unknown);
   HOL per attempt 30–90 min (guess; TextIOProof-sized parents).
5. Compose: L3 = `∀k. ffi_calls_ok Vok mc2 (basis_ffi ext cl fs) k ms`, then L2R. Minutes.

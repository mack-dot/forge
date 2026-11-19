# Step D3: the reachable FFI calls of the refund program, lemma L3 (Y3, Opus; reading and drafts only; nothing ran)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

## Y3 report: link X7, lemma L3. I only read and drafted. Nothing ran.

**Findings**
1. **C code versus the HOL oracle.** I read the pinned `basis_ffi.c` lines 107–197, `fsFFIScript.sml`, `basis_ffiScript.sml` and `call_FFI`. The asserts are compiled in: the binary binds `___assert_rtn`, and nothing sets NDEBUG.
   - **read and write.** The model returns an error answer (`LUPDATE 1w 0`) at many call states where the C code aborts:
     - clen ≠ 8. Example: x1=7, x3=5, a=[0,1,0,0,0].
     - The length bound is broken.
     - x3 has its top bit set: C reads `alen` as a signed long, so it is negative and the assert fails.
   - **close.** The model's length checks match the C asserts, except for the signed x3. The answers can differ: for fd 0 the model returns 1w (stdin is a `UStream`), but C `close(0)` succeeds.
   - **open_in.** The model returns where C aborts when x3 is 1..8. If conf has no NUL byte, the model returns an error answer and C reads past the buffer (undefined behaviour).
   - **All four names.** `byte8_to_int` has undefined behaviour when b[0] or b[4] ≥ 0x80, and it truncates to int: conf [0,0,0,1,0,0,0,0] means fd 2^32 in the model and fd 0 in C.
   - Proposed `Vok`: x1=8, the conf bytes equal `n2w8 0` (read) or `n2w8 1` (write), the bound, ¬msb x3, and `V_close = V_open = F`.
2. **First read theorem.** I drafted `successful_read_call_state_has_valid_arguments` with X7's exact statement, plus a slide-free `_g` form whose premises are only the target and the registers.
   - It builds on the stored `refund_static_def`, `write_call_arrays_are_the_register_arguments` and `read_bytearray_first_four`.
   - New lemmas: `ffi_read_return_cases` and `basis_read_call_is_ffi_read`.
   - Controls: wrong clen, out of bounds, short array, wrong register, a scope check that the conclusion has no `word_msb`, and `model_read_returns_where_c_aborts`, which states the gap as a theorem.
3. **`refund_run_write_events_all_succeed`.** I stated it more generally as `refund_run_rw_events_valid`: `EVERY refund_valid_event` holds over the events at every clock. By my reading of the source:
   - every read uses the 4100-byte `surplus` array with n=4096 and conf `n2w8 0`;
   - every write uses `iobuff` (2052 bytes) with off+n ≤ 2048 and conf `n2w8 1`.
   - These exact lengths give ¬msb x3 without the U396 low-half premise.
   - Route, in order:
     - SRC-EV: a source theorem, proved by re-proving about 15 TextIO CF specs with an FFI part that has only the names read and write and an event invariant (route W-a′).
     - Lift to the machine through the stored compile chain and the determinism of source semantics.
     - Every clock: `machine_sem_total` and `evaluate_add_clock(_io_events_mono)`.
     - Lemma G: induction over `ffi_calls_ok`. It needs no `machine_reach`.
4. **Failed close or open_in events.** `refund_semantics` alone cannot exclude them. A failed close or open_in, or an open_in followed by a close, leaves `extract_fs` unchanged. The source says this program never calls close or open_in:
   - `refund_main` calls `inputAllFrom None`, which goes to `openStdIn` and the `consume_rest` close thunk (read only).
   - `print` goes to `writei` (write only).
   - `refund_dispatch` is pure translated code.
   - `#(open_in)` and `#(close)` are reached only through the `Some fname` branch of `open_option`. That branch is dead because the argument is the constant `None`. The two names are linked only because the code mentions that branch.
   - Formal route: W-a′ with names [read; write]. Then `parts_ok_def` (cfStore line 32) forces every event to use only the listed names.
5. **Slides.** Yes, every stored call-site fact holds at slide 0 only (`refund_static` PCs, `refund_installed_no_handler`, `refund_image_mem 0w`). Lemma G is independent of the slide, because `refund_mc_def` places the entry PCs relative to any base. The native path layer would need re-proof per step and a page-aligned slide; I did not check `refund_entry_pre_sl` for that.
6. **Gap I could not close.** I did not find the stored intermediate theorem `machine_sem ⊆ extend_with_resource_limit (semantics…)`. Without it, the final composition must re-run with the stronger predicate.

**Files I wrote** (both drafts, not run)
- `<session scratch folder>/m1b/Y3/Y3-L3-analysis.md`
- `<session scratch folder>/m1b/Y3/Y3-readArgs.sml`

**Commands run:** read-only only (`grep`, `sed`, `find`, `cat`, `ls`). All exited 0, except one zsh glob error that changed nothing. No HOL, no build, no git command that changes state.

**What I could not determine**
- Whether `simp` decides `«read» ≠ «write»` inside `basis_ffi_oracle_def`. This is a risk for the draft.
- The exact names of the TextIO specs on the path (the `_STR` variants).
- The slide-alignment premise.
- The real cost of the CF re-proof.

**Ordered HOL plan (estimates are guesses)**
1. First run: `Y3-readArgs.sml`. Its parents are cached. 5–15 minutes per attempt, at most 3 attempts.
2. Lemma G and the clock-prefix lemma, after X7's L1/L2 run. 15–40 minutes per attempt.
3. Find or re-run the source-to-machine inclusion. Minutes if it is stored, hours if not.
4. SRC-EV with W-a′. Authoring takes days. Each HOL attempt takes 30–90 minutes.
5. Compose L3, then L2R. Minutes.

| step | status | evidence or blocker |
|---|---|---|
| (1) V per name vs oracle | DONE (read) | basis_ffi.c 138–197; fsFFIScript 253–362 |
| (2) read first theorem | DRAFT, NOT RUN | Y3-readArgs.sml |
| (3) write/read events all valid | STATEMENT + ROUTE | needs SRC-EV (CF re-proof) |
| (4) close/open_in exclusion | source argument READ; formal MISSING | `refund_semantics` too weak; W-a′ with 2 names |
| (5) slides | ANSWERED | lemma G is independent of the slide; path layer is slide 0 only |
| (6) run plan | DONE | see above |

| link id | proposed class | evidence |
|---|---|---|
| X7 | MISSING | L1/L2/L3 are drafts; nothing ran; L3 needs SRC-EV |
| X6 | ASSUMPTION (probably false at all states) | unchanged; my concrete states R-a, W-a, O-a add more counterexamples |

M1-B stays OPEN. end_to_end=false. Stage 9 stays deferred.

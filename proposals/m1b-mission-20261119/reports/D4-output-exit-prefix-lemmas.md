# Step D4: drafts of the output-bytes, exit-status and prefix lemmas; the table of all (exit, output) cases (Y4, Opus; drafts only; nothing ran)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

## Y4 report (links X9, X10, X13). Drafts only. I started no HOL process.

**Findings**
1. **The X1 form of L-OUT is false (X9).** `M1_EXACT_CLAIM.md` §3.1 states L-OUT with a free `ext`. An event with a non-basis name is replayed by `ext`, and `ext` can rewrite the stdout inode. Control N-O1 is a witness: `ext_bad`, `fs0` and one `«x»` event give `extract_fs = SOME (add_stdout … «a»)` with `fd1_written = []`. There is a second problem: in the resource-stop disjunct, `io` is only existential, not a machine trace. A basis-names premise therefore does not repair it. The repair is to instantiate the stored theorem at `ext := no_ext`. It is universal in `ext`. Under `no_ext`, a SOME replay forces basis names (`extract_no_ext_basis_names`). `closeFD` asserts `isFile`, so fd 1 is never closed or reused. This makes the fd-1 test sound.
2. **The halt outcome does not determine the exit status (X10).** I read this in the stored otool output of `b8ed5ec2…`, lines 34662–34677. `_cml_exit` tests `cbz w0`, which is the low 32 bits. If w0 ≠ 0, it writes the stderr line. Then it calls `exit(x0)`. The status is the low 8 bits (POSIX; I did not check it on macOS). The model tests all 64 bits (`targetSemScript.sml` 145–147, ptr_reg = 0). So:
   - x0 = 256 gives status 0 with a stderr line.
   - x0 = 2^32 gives status 0 with empty stderr. This is a resource stop that cannot be told from Success by status or stderr.
   - x0 ∈ {0,1,2} at every halt is my reading of the source only (`halt_inst 0/2`, `const 1`, `GiveUp`). No theorem gives it.
3. **"Non-zero exit implies strict prefix" is false.** `extend_with_resource_limit` uses `io_list ≼ l`, which is non-strict. This confirms C2.
4. **L-EXIT-V is not needed for safety.** The model gives `fd1_written io ≼ R` on every behaviour. With the prefix lemma, a strict-parse success then implies output = R and fields = `refund_fields …`, whatever the exit status. L-EXIT-V is needed only for the claim "status 0 ⇒ Success".
5. **The strict parser is defined in HOL:** `refund_strict_parse` (parse, empty rest, 7-field shape, re-render equals the input). The positive control P0 (the full output parses) is required, because `λs. NONE` also meets the prefix lemma.
6. **Side note:** a caller with step D11 (compare with an expected R that it computes) makes the executable redundant for safety.

**Files (all DRAFT, NOT RUN)**
- `<session scratch folder>/m1b/Y4/prefix_lemma_DRAFT.sml`
- `<session scratch folder>/m1b/Y4/L_OUT_DRAFT.sml`
- `<session scratch folder>/m1b/Y4/L_EXIT_DRAFT.sml`

**Commands run:** read-only grep/sed/find, all exit 0. I stopped one long `find /` that I had started. No HOL, build, Dafny, Node or git write.

**Key statements (types checked against the stored .sig files and sources)**
- **L-OUT:** `STD_streams fs ∧ extract_fs no_ext (cl,fs) io = SOME (add_stdout (fastForwardFD fs 0) out) ⇒ fd1_written io = explode out`. The prefix form adds `io' ≼ io` and concludes `fd1_written io' ≼ explode out`. The composition `refund_profile_a_sl_fd1` is in the draft.
- **L-EXIT-0:** `evaluate mc ffi k ms = (Halt t,ms',ffi') ⇒ FFI_outcome ∨ (pc = halt_pc ∧ (Success ∧ reg=0w ∨ RLH ∧ reg≠0w))`.
- **L-EXIT-V (open):** `ms'.REG 0w ∈ {0w;1w;2w}` at every halt.
- **Prefix lemma:** `p ≼ explode (refund_render_fields f) ∧ p ≠ … ⇒ ISL (parse p)`, then `refund_strict_parse p = NONE`.

**Hard steps**
- X13: the mutual key lemma `lex_aux_prefix_ISL` (depth ≠ 0).
- X9: the five-case replay invariant `extract_no_ext_stdout`. Its tactic is NOT WRITTEN.
- X10: L-EXIT-V. It needs either a lab_to_target simulation that exposes the register value at halt, or a bound on indirect-branch targets.

**Controls**
- X13: N1 (trailing `\n`), N2 (atom `ab`/`abc`), N3 (depth 0), plus P0.
- X9: N-O1 (free `ext`), N-O2 (failed write counted), N-O3 (fd-2 write counted).
- X10: N-E1 (status collision at 256 and 2^32), N-E2 (2^32 gives no stderr line), N-E3 (swapped Success test).

**Estimates (unit = one recorded M1 entry)**
- Prefix lemma: 2–6
- L-OUT: 2–5
- L-EXIT-0: 1
- L-EXIT-V: 10–40 (very uncertain)

**(exit, output) cases.** These hold under the stored theorem, L-OUT, L-EXIT-0 and the native relation (an ASSUMPTION), without L-EXIT-V. R = rendering; o = stdout.

| x0 at halt (model) | status | stderr | o | fail-closed caller |
|---|---|---|---|---|
| 0 (Success) | 0 | "" | = R | may authorize after D7–D10 |
| 1, 2 (RLH) | 1, 2 | line | ≼ R (can be = R or "") | REFUSE (D3) |
| low8 ∉ {0,1,2} | 3–255 | line | ≼ R | REFUSE (D3) |
| low32 ≠ 0, low8 = 0 (256) | 0 | line | ≼ R | REFUSE (D4); if o ≺ R, D7 |
| x0 ≠ 0, low32 = 0 (2^32) | 0 | "" | ≼ R | o ≺ R: REFUSE by D7 only; o = R: content correct, but exit 0 is no evidence |
| no status (signal, abort, kill, timeout) | — | any | nothing proved | REFUSE (D1/D2) |
| FFI_outcome / Fail / Diverge | excluded by the stored theorem | | | — |
| premises false (non-canonical stdin, P7 false per U393) | nothing proved | | | REFUSE |

**Strongest true conclusion:** o ≼ R always. A resource stop is the only way to get o ≠ R. A strict parse succeeds only if o = R. Exit status 0 does NOT imply o = R.

**Owner wording that is stronger than the truth**
- "exit 0 ⇒ complete output" (text 8 point 5, label (b)): it is false without L-EXIT-V.
- "non-zero ⇒ strict prefix": the output can also be the complete R.
- "I/O events determine fd-1 bytes": true only at `no_ext`, and only in the model. The bytes of the real process come from the native relation, an ASSUMPTION.
- "halt outcome determines exit status": the value of x0 decides the status, not the outcome.

**Not determined:** the full HOL tactics (some placeholders are marked); macOS wait truncation; whether `refund_mc` in E4 is `forge_refundStartupBridge$refund_mc` (likely).

| step | status | evidence or blocker |
|---|---|---|
| D4 drafts | DRAFTED, NOT RUN | three .sml files above |
| HOL check | NOT RUN | rules forbid HOL; needs the HOL slot |

| link id | proposed class | evidence |
|---|---|---|
| X9 | MISSING | the draft L-OUT; the X1 form is false (N-O1) |
| X10 | MISSING | L-EXIT-0 easy; L-EXIT-V open; native half = ASSUMPTION; otool shows the status-0 collision |
| X13 | TESTED-UNPROVED | B3 test (0 of 8,011 prefixes accepted); HOL draft not run |

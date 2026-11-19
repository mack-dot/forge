# Z6 run plan: strict-prefix lemma, L-OUT, L-EXIT-0 (v2 drafts). NOTHING HERE HAS RUN.

All exit codes below are EXPECTED, not actual. Worker Z6 started no HOL process.
Run one HOL process at a time, only when the HOL slot is free, after the authorized
runs before them (NEXT_OBLIGATIONS.md section 2: replay, then L1). At most five attempts per proof.

Z = `<session scratch folder>/m1b/Z6`
A = the route-A attempt folder of X7's plan (`results/m1b-routeA-20261119/attempt-0001`), same `run_case.py`,
`go-routeA.sh`, `hash_parents.py`, and the deps file `deps-L1.txt` (= copy of `deps-imp4.txt`, 125 lines, ends
with the e4-0001 theory `forge_refundSlideProfileA`). The preload loads `forge_refundArm8CompileTheory`, whose
ancestry holds `forge_refundWireProg`, `forge_refund_io`, `mlsexp`, `basis_ffi`, `fsFFIProps`, `TextIOProof`.

| # | Case | Source (SHA-256 at hand-off) | Deps | CPU limit | Depends on |
|---|---|---|---|---|---|
| P | `PF-0001` | `prefix_lemma_v2.sml` (`c2fcebeb…aff`) | `deps-L1.txt` | 600 s | nothing new |
| O | `LO-0001` | `L_OUT_v2.sml` (`153885ba…c0d`) | `deps-L1.txt` | 900 s | nothing new |
| E | `LE-0001` | `L_EXIT_v2.sml` (`0d2a0ada…f61e`) | `deps-L1.txt` + the two `LO-0001/forge_refundLOutTheory.{sig,sml}` lines | 1200 s | a PASSING run O |

Order: P, then O, then E. E needs the exported theory of O (it fetches `refund_profile_a_sl_fd1`). This
swaps rows 3 and 4 of NEXT_OBLIGATIONS.md section 2; the orchestrator decides. L-EXIT-V is NOT a run:
the script only type-checks its statement and prints `OPEN_STATEMENT`.

Before each run: `memory_pressure | tail -1` (>= 25 % free), `sysctl vm.swapusage`, `df -h /System/Volumes/Data`
(>= 3 GiB), `pgrep -fl 'cake_compile_heap|poly'` (must be empty). Then, in A:
`cp $Z/prefix_lemma_v2.sml PF-0001.sml; FORGE_CPU_SECONDS=600 ./go-routeA.sh PF-0001 PF-0001.sml deps-L1.txt`
(same pattern for O and E; for E first `cp deps-L1.txt deps-LE.txt` and append the two LO-0001 theory lines).

## Pass criteria (ALL; otherwise the run is a finding, not a pass)

Common: actual exit 0; marker `EXACT_COMPLETE`; `inputs_unchanged_after` true; no `LEMMA_FAILED`; no
`UNEXPECTED_CONTROL_ACCEPTANCE`; no `DEFINITION_FAILED`; exactly four `CLOSURE_AXIOM` lines (bool's four);
every stored theorem passes the tag check (only `DISK_THM`, no hypothesis). No `cheat`, `mk_thm`, axiom, oracle.

- P: `CHECKED` for prefix_append_strict, sexp_print_eqs, read_symbol_safe_nil, read_string_aux_char_escaped,
  char_escaped_strict_prefix, read_string_aux_strict_prefix, atom_prefix_ISL, lexP_Atom, lexPs_nil, lexP_Expr,
  lexPs_cons, lexP_all, lex_aux_prefix_ISL, parse_ISL_of_lex, sexp_to_string_Expr_prefix_free,
  refund_render_fields_prefix_free, refund_strict_parse_no_strict_prefix, refund_strict_parse_complete (P0),
  N1_trailing_newline_breaks, N2_atom_breaks, N3_depth0_breaks (21); `DEFINITION` lexP, lexPs,
  refund_strict_parse (3); `CONTROL_OK` x4 (two literal statements, N1 and N3 negations).
- O: `CHECKED` for the 30 `thm` names in the file (fd1_written_APPEND … N_O3); `DEFINITION` write_chunk,
  fd1_written, fs0, ext_bad, write_chunk_nosucc, write_chunk_nofd; `CONTROL_OK` x3 (L-OUT literal, FD1 premise is
  the stored premise term, FD1 has no free `ext`); `EXT_VARIABLE` line shows the oracle type.
- E: `CHECKED` evaluate_Halt_reg, refund_halt_address, refund_profile_a_sl_halt, N_E1, N_E2, N_E3;
  `OPEN_STATEMENT L-EXIT-V` printed (not stored); `CONTROL_OK` x2.

## What a failure means

- `LEMMA_FAILED <name>` with `SHOW REMAINING <name>`: my tactic failed; the printed goals say where. Not evidence
  that the statement is false. Fix the tactic only, record the diff, new case name (`PF-0002`, …).
- A later lemma that fails only because an earlier one failed (it uses `TRUTH`): fix the earlier one first.
- `UNEXPECTED_CONTROL_ACCEPTANCE`: a structural check failed (statement drifted or premise not the stored term):
  a failed run.
- A static SML error (unbound name) stops the whole script without `LEMMA_FAILED`: I checked every theorem name
  against the stored `.sig` files, but this is the most expensive failure (a full attempt). Look at stderr.
- CPU limit: most likely in E (`evaluate_Halt_reg`, case split over every branch of `evaluate`) and in O
  (`ffi_write_cases`, `gvs` with `AllCaseEqs`). Record the CPU used.
- A failure of N1–N3, N-O1–N-O3 or N-E1–N-E3 to PROVE means the control could not be established, not that the
  weakened claim holds.

## Statements, confidence, hardest step

Confidence = my guess that attempt 1 proves the lemma (tactics written blind; nothing ran).

| lemma | statement (exact, HOL) | conf. | hardest step |
|---|---|---|---|
| lex_aux_prefix_ISL (KEY) | `(!x p d ts. d <> 0 /\ p <<= explode (concat (append (sexp_to_app_list x))) ==> ISL (lex_aux d p ts)) /\ (!xs p d ts. d <> 0 /\ p <<= explode (concat (append (sexps_to_app_list xs))) ==> ISL (lex_aux d p ts))` | 35 % (via 4 step lemmas) | atom_prefix_ISL (quoted atom, strict prefix inside the escape) and lexPs_cons (DEP_REWRITE with `#" " :: t`) |
| refund_strict_parse_no_strict_prefix | `!f p. p <<= explode (refund_render_fields f) /\ p <> explode (refund_render_fields f) ==> refund_strict_parse p = NONE` | 30 % (inherits KEY) | sexp_to_string_Expr_prefix_free |
| P0 refund_strict_parse_complete | `!f. refund_strict_parse (explode (refund_render_fields f)) = SOME f` | 85 % | none |
| N1 | `~(!f p. p <<= explode (refund_render_fields f) ++ "\n" /\ p <> explode (refund_render_fields f) ++ "\n" ==> ISL (parse p))` | 70 % | `APPEND_EQ_SELF` orientation |
| N2 | `parse "ab" = INR (Atom «ab», "") /\ "ab" <<= explode (sexp_to_string (Atom «abc»)) /\ "ab" <> explode (sexp_to_string (Atom «abc»))` | 80 % | EVAL of `make_str_safe` |
| N3 | `~(!x p (d:num) ts. p <<= explode (concat (append (sexp_to_app_list x))) ==> ISL (lex_aux d p ts))` | 75 % | EVAL after instantiation |
| extract_no_ext_stdout | `!io cls fs cls' fs'. extract_fs_with_numchars no_ext (cls,fs) io = SOME (cls',fs') /\ STD_streams fs ==> STD_streams fs' /\ !c0. ALOOKUP fs.inode_tbl (UStream «stdout») = SOME c0 ==> ALOOKUP fs'.inode_tbl (UStream «stdout») = SOME (c0 ++ fd1_written io)` | 25 % | ffi_write_cases + write_stdout (fd = 1 / fd = 2 / other fd) |
| refund_L_OUT | `!cl fs io out. STD_streams fs /\ extract_fs no_ext (cl,fs) io = SOME (add_stdout (fastForwardFD fs 0) out) ==> fd1_written io = explode out` | 30 % | final `gvs` joining the two stdout lookups |
| refund_L_OUT_prefix | `!cl fs io io' out. STD_streams fs /\ io' <<= io /\ extract_fs no_ext (cl,fs) io = SOME (add_stdout (fastForwardFD fs 0) out) ==> fd1_written io' <<= explode out` | 30 % (inherits) | none of its own |
| refund_profile_a_sl_fd1 | stored premise term `==> ?ms. (arm8_run 27 s = SOME ms /\ ms.PC = sl + 0x1000040D0w) /\ !b. machine_sem (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi no_ext cl fs) ms b ==> ?t io. b = Terminate t io /\ ((t = Success /\ fd1_written io = explode R) \/ (t = Resource_limit_hit /\ fd1_written io <<= explode R))` | 25 % | inherits L-OUT; instantiation of `ext` |
| N-O1 / N-O2 / N-O3 | free `ext` breaks L-OUT / no success test counts a failed write / no fd test counts an fd-2 write | 40 / 40 / 80 % | record equality after `add_stdout`; EVAL through `write` with `numchars = LNIL` |
| evaluate_Halt_reg (L-EXIT-0) | `!k mc ffi ms t ms' ffi'. evaluate mc ffi k ms = (Halt t,ms',ffi') ==> (?e. t = FFI_outcome e) \/ (mc.target.get_pc ms' = mc.halt_pc /\ ((t = Success /\ mc.target.get_reg ms' mc.ptr_reg = 0w) \/ (t = Resource_limit_hit /\ mc.target.get_reg ms' mc.ptr_reg <> 0w)))` | 40 % | case explosion over the MMIO branches; the IH at `k - 1` with a changed record |
| refund_profile_a_sl_halt | stored premise term `==> ?ms. (… ms.PC = sl + 0x1000040D0w) /\ !k t ms' st'. evaluate (refund_mc …) (basis_ffi no_ext cl fs) k ms = (Halt t,ms',st') ==> ms'.PC = sl + 0x1000040C0w /\ ((ms'.REG 0w = 0w /\ t = Success /\ fd1_written st'.io_events = explode R) \/ (ms'.REG 0w <> 0w /\ t = Resource_limit_hit /\ fd1_written st'.io_events <<= explode R))` | 30 % | rewriting with `refund_mc_fields` and the halt address |
| L-EXIT-V | `… ms'.REG 0w IN {0w; 1w; 2w}` | NOT ATTEMPTED | no stored theorem exposes the halt register value (see the report) |

Attempt-1 pass of a WHOLE script (every lemma): P about 10 %, O about 5 %, E about 10 %. Expect 2 to 4 attempts
each; the printed `SHOW REMAINING` goals are designed to make attempt 2 a tactic-only edit.

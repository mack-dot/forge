# Step G6: second drafts of the strict-prefix, output-bytes and exit lemmas; whether the halt-value range is provable (Z6, Opus; drafts and mirror tests only; nothing ran in HOL)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

## Z6 report (links X13, X9, X10). Drafts only. I started no HOL, Dafny, build or git write.

**Findings**
1. **Y4's strict-prefix statement holds in the mirror. I did not change it.** The test is a Python mirror of the HOL definitions: lex_aux, read_string_aux, read_symbol, parse_aux, parse, make_str_safe, char_escaped, mlint toString/fromString, refund_render_fields and the strict parser. The mirror reproduces all 10 stored unit tests (test_lex and test_parse).
   - 605 rendered results: empty strings, quotes, backslashes, spaces, `~5`/`-5`/`+5`, NUL, bytes 0x7f–0xff, ids of 200–600 characters, and integers up to ±10^40.
   - 78,357 strict prefixes were checked. Parse accepted 0, and the strict parser accepted 0. P0 held on all 605 results.
   - The key lemma at depths 1 to 3 had 0 violations: 155,504 checks on result bodies plus 336,762 on random nested s-expressions.
   - Mutation controls have teeth: trailing newline 3 violations, no outer parentheses 115, depth 0 118, unescaped quote with a field `x")` 8.
   - Side finding: prefix-freeness rests on the depth count, not on escaping. Unescaped quotes alone give 0 violations.
   - A test is not a proof. X13 stays TESTED-UNPROVED.
2. **Induction principle.** `sexp_induction` is the MEM form, not a mutual induction. The right one is the stored `sexp_to_app_list_ind`, whose cons case has conditional induction hypotheses (NULL / ¬NULL). I read its exact form from `basis/pure/.hol/docs/mlsexpTheory.html`. The v2 key-lemma proof uses it through two predicate constants (lexP, lexPs) and four step lemmas.
3. **L-OUT case analysis.** Under `no_ext`, `extract_fs_with_numchars` has three kinds of event:
   - The five `fs_ffi_part` names (open_in, open_out, read, write, close) are replayed. There is one stdout lemma per name.
   - The other basis names (get_arg_count, get_arg_length, get_arg, exit) are skipped, with no state change.
   - Any other name, and SharedMem, gives NONE, so those cases are vacuous.
   - Lemmas used (all checked in the stored .sig files; file and line are in the script header): STD_streams_def, STD_streams_fsupdate, STD_streams_openFileFS, STD_streams_bumpFD, STD_streams_emptyFile, emptyFile_UStream, stdo_def, stdo_add_stdo, stdo_fastForwardFD, STD_streams_stdout, w22n_n2w2, OPTION_CHOICE_EQUALS_OPTION, AFUPDKEY_ALOOKUP, ALOOKUP_ADELKEY, and the ffi_*/write/read/closeFD/openFile(_truncate) definitions.
   - The proof of fd 1 uniqueness rests on `closeFD` (it asserts `isFile`) and on `nextFD` being 3 or more.
4. **Halt-value range: result (b).**
   - `compile_correct` (backendProofScript 4952) only gives `machine_sem ⊆ extend_with_resource_limit (semantics_prog …)`.
   - Each semantics turns the halt value into Success or Resource_limit_hit and drops it: targetSem evaluate 145–147, labSem 533–536, stackSem semantics_def 1144.
   - stackSem `Halt` also returns `empty_env`, so the final state does not hold the value either.
   - No stored theorem states x0 at the halt. Only L-EXIT-0 is provable (drafted): Success ⇔ x0 = 0w at halt_pc = sl+0x1000040C0w.
   - By reading only, the halt values come from halt_inst 0/2 (stack_remove 74, 330–331), const 1 (stack_alloc 469/507/634) and stackSem 397/982.
   - Route (a) would need a halt-value-preserving simulation through stack_alloc, stack_remove, stack_names, stack_to_lab and lab_to_target. That re-opens lab_to_targetProof.
5. **Counter-scenario check (c).** The stored `refund_ffi_contract_at` sets the PC after an FFI call to `t1.regs 30` and keeps only x19–25, x27, x28, so x0 after a return is arbitrary. No stored premise excludes a return to halt_pc with x0 = 2^32 if x30 held halt_pc at an FFI entry. Nothing shows that it happens either. **I claim neither reachability nor unreachability of x0 = 2^32.** Exit status 0 is not evidence of complete output (control N-E1).

**Files (all DRAFT, NOT RUN)**, in `<session scratch folder>/m1b/Z6/`:
- `prefix_lemma_v2.sml` (21 lemmas, P0, N1–N3)
- `L_OUT_v2.sml` (30 lemmas, N-O1–N-O3)
- `L_EXIT_v2.sml` (L-EXIT-0, the halt instance, N-E1–N-E3; L-EXIT-V is type-checked only and printed as OPEN)
- `RUN_PLAN.md`: order prefix → L-OUT → L-EXIT. L-EXIT needs the L-OUT theory, which swaps rows 3 and 4 of NEXT_OBLIGATIONS. CPU limits 600, 900 and 1200 s. It also has the pass criteria, what each failure means, and the statement/confidence/hardest-step table.
- Mirror tests: `mirror_prefix_test.py`, `mirror_key_lemma_test.py`, `mirror_mutation_test.py`, `mirror_selfcheck.py`, with `.out` logs.

The scripts follow the routeA-L1 style: a `thm` helper that records LEMMA_FAILED (goal and tactic are thunks, so one failure does not stop the run), and `try_all` alternatives that print `SHOW REMAINING` goals. Statements kept from Y4: KEY, strict-prefix, P0, extract_no_ext_stdout, L-OUT and its prefix form. Changes: fd1_written now goes through a write_chunk helper with the same meaning; FD1 and HALT premises are built from the stored premise term. Expected whole-script pass on attempt 1: about 10 %, 5 % and 10 %.

**Commands run**
- `python3 -I mirror_prefix_test.py 600`: exit 0
- `mirror_mutation_test.py`: exit 0
- `mirror_key_lemma_test.py … 400`: exit 0
- `mirror_selfcheck.py`: exit 0
- Read-only grep/sed/find/shasum: exit 0, except one grep with exit 1 (a zsh glob had no match; harmless).

**Not determined:** whether any tactic works (nothing ran); the macOS status truncation; whether gvs splits every disjunctive assumption as I assumed.

| step | status | evidence or blocker |
|---|---|---|
| strict-prefix v2 | DRAFTED, NOT RUN | mirror: 0 of 78,357 accepted |
| L-OUT v2 | DRAFTED, NOT RUN | needs the HOL slot |
| L-EXIT-0 + instance | DRAFTED, NOT RUN | needs the HOL slot |
| L-EXIT-V | OPEN | no stored theorem exposes the halt register |

| link id | proposed class | evidence |
|---|---|---|
| X9 | MISSING | full draft, not run |
| X10 | MISSING | range not derivable from stored theorems; native half is an ASSUMPTION |
| X13 | TESTED-UNPROVED | mirror tests above; HOL draft not run |

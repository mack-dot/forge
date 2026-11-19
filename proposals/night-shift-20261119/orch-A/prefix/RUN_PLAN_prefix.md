# Run plan: strict-prefix lemma v3 (case PF-0001). NOTHING HERE HAS RUN.

Worker A2, Orchestrator A, 2026-11-19. Every exit code in this file is EXPECTED, not actual.
No HOL process was started by A2. Every tactic in the script is UNCHECKED.
Pattern: `proposals/m1b-mission-20261119/drafts/route-a/RUN_PLAN.md` (X7) and `v2/RUN_PLAN.md` (Z6).

## Inputs (SHA-256 at hand-off)

| file | SHA-256 |
|---|---|
| `results/night-shift-20261119/orch-A/prefix/prefix_lemma_v3.sml` (source) | `820de13438581538a9649db0e5d6e18b412c592abe4cb45498171882bb6095e8` |
| `A/run_case.py` = copy of `results/round4-m1-replay-20261118/slide-s3-copy/attempt-0001/run_case.py` | `9c1064bd…823c3b` (both files equal, checked) |
| `A/deps-L1.txt` = copy of `slide-s3-copy/attempt-0001/deps-imp4.txt` (125 lines) | `76bcd490…09cc90` (both files equal, checked) |
| `A/go-routeA.sh` (X7) | `8b6bf896…7c289` |
| `A/hash_parents.py` (X7) | `39be0107…f5644` |
| option B only: `prefix/preload-prefix-min.sml` (one line: `load "forge_refundArm8CompileTheory";`) | `78c24b8cb44b85233a367e4f5b0dfdeb27ccb059c497725dd76dfde552ea7737` |
| option B only: `prefix/deps-PF-min.txt` (one line: the path of that preload) | `dad10a7e21db8ce1e5dddc98c567f0e29744a02bccef29f51eefdeeaab6f188c` |

`A` = `/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001` (exists; holds `run_case.py`, `deps-L1.txt`,
`go-routeA.sh`, `hash_parents.py`, `L1-0001.sml`). `P` = `/Users/USER/forge/results/night-shift-20261119/orch-A/prefix`.

What the deps give. Line 1 of `deps-L1.txt` is `preload.sml`; its first command `load "forge_refundArm8CompileTheory"`
loads (through the `.uo` chain) forge_refundWholeProg → forge_refundStdioProg → forge_refundWireProg →
forge_refundCertifiedProg → forge_refund_io, and mlsexp, mlstring, list, rich_list, option. The script needs only these
(`DB.fetch "forge_refundWireProg"`, `DB.fetch "forge_refund_io"`, `open preamble mlsexpTheory mlstringTheory`).
`preamble` comes from the heap `cake_compile_heap` (it is not a theory; e4-0001 opened it with the same heap).
The other 124 deps lines are not needed by the script; they are harmless (a superset). Checked by reading only.

## When to run

Only when the HOL slot is free (orchestrator rule: `phase3/ALL_DONE` exists and no `hol`/`poly` process runs), and after
the runs the orchestrator queued before it. One HOL process at a time. At most five attempts per proof.

Before the run:
```zsh
memory_pressure | tail -1            # need >= 25 % free (run_case.py refuses below 25 %)
sysctl vm.swapusage                  # record it
df -h /System/Volumes/Data           # need >= 3 GiB free
pgrep -fl 'cake_compile_heap|arm8-heap|cakeml-heap|poly' || echo "no HOL process"
```

## Command (option A, recommended: the proven deps pattern of e4-0001 / L1)

```zsh
A=/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001
P=/Users/USER/forge/results/night-shift-20261119/orch-A/prefix
cd $A
cp $P/prefix_lemma_v3.sml PF-0001.sml
shasum -a 256 PF-0001.sml $P/prefix_lemma_v3.sml          # both must be 820de134…95e8
FORGE_CPU_SECONDS=600 ./go-routeA.sh PF-0001 PF-0001.sml deps-L1.txt ; echo "go exit $?"
```
CPU limit 600 s (e4-0001 used 127 s CPU and 3275 MiB max RSS to load the same parents; the proofs are small;
each metis call is bounded to 30 s by the script). Wall limit = CPU + 300 s (run_case.py).

## Option B (lighter; use only if memory is the blocker; the deps pattern is NOT proven)

Same commands, but run `FORGE_CPU_SECONDS=600 ./go-routeA.sh PF-0001 PF-0001.sml $P/deps-PF-min.txt`. It loads only the first
theory of `preload.sml`. Risk: an unknown static dependency of the script on a later preload line (I found none).
If option B fails with an unbound structure or theory, that is a deps finding, not a proof finding.

## Pass criteria (ALL; otherwise the run is a finding, not a pass)

From `A/PF-0001/command.json`: `actual_exit` 0; `markers` contains `EXACT_COMPLETE`; `inputs_unchanged_after` true.
From `A/PF-0001/stdout.log`:
- no line starting `LEMMA_FAILED`, `UNEXPECTED_CONTROL_ACCEPTANCE`, `DEFINITION_FAILED`;
- `DEFINITION lexP`, `DEFINITION lexPs`, `DEFINITION refund_strict_parse` (3);
- `CHECKED <name>` for exactly these 23 names: prefix_append_strict, every_isPREFIX, sexp_print_eqs,
  read_symbol_safe_nil, read_string_aux_char_escaped, char_escaped_strict_prefix, read_string_aux_strict_prefix,
  atom_prefix_ISL, lexP_Atom, lexPs_nil, lexP_Expr, lexPs_cons, lexP_all, lex_aux_prefix_ISL, parse_ISL_of_lex,
  sexp_to_string_Expr_prefix_free, refund_render_fields_prefix_free, refund_strict_parse_no_strict_prefix,
  refund_strict_parse_complete, refund_render_fields_prefix_code, N1_trailing_newline_breaks, N2_atom_breaks,
  N3_depth0_breaks;
- the line after `CHECKED refund_strict_parse_no_strict_prefix` prints the statement
  `⊢ ∀f p. p ≼ explode (refund_render_fields f) ∧ p ≠ explode (refund_render_fields f) ⇒ refund_strict_parse p = NONE`
  (pretty-printing may differ in layout; the literal check below is the binding test);
- exactly these 5 `CONTROL_OK` lines:
  `CONTROL_OK refund_strict_parse_no_strict_prefix statement is the literal planned statement`,
  `CONTROL_OK refund_strict_parse_complete statement is the literal planned statement`,
  `CONTROL_OK refund_render_fields_prefix_code statement is the literal planned statement`,
  `CONTROL_OK N1 is a proved negation`, `CONTROL_OK N3 is a proved negation`;
- exactly 4 `CLOSURE_AXIOM` lines: `bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX`, `bool.BOOL_CASES_AX`
  (order as printed); the script raises `Fail` before export if the count is not 4;
- `STORED_THEOREMS 23` and `STORED_DEFINITIONS 3` (expected; informational: Define could store an extra theorem);
- `EXACT_COMPLETE` is the last marker; `A/PF-0001/.hol/objs/forge_refundPrefixFreeTheory.{sig,sml,dat}` exist.
- No `cheat`, `mk_thm`, axiom or oracle: the script has none (grep: only one comment line mentions mk_thm), and the
  tag check rejects any stored theorem with a hypothesis or an oracle other than `DISK_THM`.

Record (for ROADMAP.md / TRACKER.md; the orchestrator writes them): actual exit, wall and CPU seconds, max RSS,
markers, every `CHECKED` statement, the 3 `DEFINITION` lines, `A/PF-0001.hashes.json` (from `hash_parents.py`), and
the source SHA-256 (`command.json` `source_sha256` must be `820de134…95e8`).

## What a failure means

- `LEMMA_FAILED <name>` with `SHOW REMAINING <name>` lines: my tactic failed (UNCHECKED tactics). It is not evidence
  that the statement is false. The mirror tests (`P/a2_attack.py`, exit 0) found no counterexample to any statement.
  Fix the tactic only, record the diff, new case `PF-0002`. Fix the FIRST failed lemma first: later lemmas that use a
  failed one get `TRUTH` and fail too.
- A static SML error (unbound value or structure) stops the script with no `LEMMA_FAILED` (see stderr). I checked every
  theorem and ML name against the sources and stored `.sig` files (table in A2's hand-off report). `metisTools.limit` is the one new
  ML reference: `HOL/src/metis/metisTools.sig` 45.
- `DEFINITION_FAILED`: the script stops (by design); the definition text did not elaborate.
- CPU limit (no `EXACT_COMPLETE`, negative or SIGXCPU exit): record the CPU used. Most likely cause: a long simp or
  every_case_tac in an alternative; metis is bounded to 30 s per call.
- `resource_guard_refused` (exit 3): nothing ran; not an attempt.

## Confidence (my guess; nothing ran)

Attempt-1 pass of the whole script: about 25 % (v2: about 10 %). Most likely failing steps, in order:
atom_prefix_ISL (quoted branch), read_string_aux_strict_prefix (step), sexp_print_eqs (rw with concat_thm),
lexP_Expr / lexPs_cons (DEP_REWRITE side conditions). P0 and the corollary: about 85 %.

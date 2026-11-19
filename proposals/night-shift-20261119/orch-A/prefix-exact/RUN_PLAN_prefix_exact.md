# Run plan: exact acceptance set of `refund_strict_parse` (case PX-0001). NOTHING HERE HAS RUN.

Worker A15, Orchestrator A, 2026-11-19. Every exit code in this file is EXPECTED, not actual.
A15 started no HOL process. Every tactic in the script is UNCHECKED.

## Inputs

| file | SHA-256 |
|---|---|
| `P/prefix_exact_v1.sml` (source) | `c4cfd82c25829702d29344faf7fb027cf855526eb76ed69b83a46440a15d2122` |
| `A/deps-L1.txt` (before the append; 125 lines) | `76bcd4909e81f7fc9a11144996e5b2f530e240afdb0cf62096aeff2e0209cc90` |
| `A/PF-0004/.hol/objs/forge_refundPrefixFreeTheory.sig` | `c99effd18c12a15653e467980571ae534bb8d46ba3ae097dbc6068386dc245d7` |
| `A/PF-0004/.hol/objs/forge_refundPrefixFreeTheory.sml` | `fcf9f05632617d30e0f6662f76abc46e96f44f1c7eda1c79f8e81a2150642fb4` |
| `A/PF-0004/.hol/objs/forge_refundPrefixFreeTheory.dat` | `bddae16a86019059a5f550508a28de770ba49ec7d41bde3493539694595cdce7` |

(The three theory digests are from `A/PF-0004.run.json`, `objects`.)
`A` = `/Users/mackianni/forge/results/m1b-routeA-20261119/attempt-0001`.
`P` = `/Users/mackianni/forge/results/night-shift-20261119/orch-A/prefix-exact`.

## Deps

Two lines after the 125 lines of `deps-L1.txt` (the orchestrator appends them):
```
/Users/mackianni/forge/results/m1b-routeA-20261119/attempt-0001/PF-0004/forge_refundPrefixFreeTheory.sig
/Users/mackianni/forge/results/m1b-routeA-20261119/attempt-0001/PF-0004/forge_refundPrefixFreeTheory.sml
```
`run_case.py` line 50-51 resolves `<dir>/<name>` to `<dir>/.hol/objs/<name>`. The theory `.sml` reads the `.dat`
next to itself (`OS.Path.base (#(FILE)) ^ ".dat"`). The order matters: the 125 lines first (they load the parents of
forge_refundPrefixFree, among them forge_refundSlideProfileATheory), then `.sig`, then `.sml`.
Suggestion: write the 127 lines to a NEW file `A/deps-PX.txt` and keep `deps-L1.txt` unchanged, so that the
digest of `deps-L1.txt` stays valid for the earlier cases. Both forms give the same command line.

## When to run

Only when the HOL slot is free. One HOL process at a time. At most five attempts.
Before the run: `memory_pressure | tail -1` (need >= 25 % free), `sysctl vm.swapusage`,
`df -h /System/Volumes/Data` (need >= 3 GiB), `pgrep -fl 'cake_compile_heap|poly' || echo "no HOL process"`.

## Command

```zsh
A=/Users/mackianni/forge/results/m1b-routeA-20261119/attempt-0001
P=/Users/mackianni/forge/results/night-shift-20261119/orch-A/prefix-exact
cd $A
cp $P/prefix_exact_v1.sml PX-0001.sml
shasum -a 256 PX-0001.sml            # must be c4cfd82c…2122
cp deps-L1.txt deps-PX.txt
printf '%s\n' $A/PF-0004/forge_refundPrefixFreeTheory.sig $A/PF-0004/forge_refundPrefixFreeTheory.sml >> deps-PX.txt
wc -l deps-PX.txt                     # must be 127
FORGE_CPU_SECONDS=600 ./go-routeA.sh PX-0001 PX-0001.sml deps-PX.txt ; echo "go exit $?"
```
CPU limit 600 s. PF-0004 used 83 s CPU and 3856 MiB max RSS with the same 125 deps lines; the new proofs are
short. Each metis call is bounded to 30 s by the script. Wall limit = CPU + 300 s (run_case.py).

## Pass criteria (ALL; otherwise the run is a finding, not a pass)

From `A/PX-0001/command.json`: `actual_exit` 0; `markers` contains `EXACT_COMPLETE`; `inputs_unchanged_after` true;
`source_sha256` = `c4cfd82c25829702d29344faf7fb027cf855526eb76ed69b83a46440a15d2122`.
From `A/PX-0001/stdout.log`:
- no line that starts with `LEMMA_FAILED`, `UNEXPECTED_CONTROL_ACCEPTANCE`, `DIAG_OK_UNDER `;
- `FAILED_LIST ` and `DIAG_OK_UNDER_LIST ` with nothing after the space;
- exactly 3 `IMPORTED_OK` lines (refund_strict_parse_complete, refund_render_fields_prefix_code,
  refund_strict_parse_no_strict_prefix) and 1 `PARENT_OK forge_refundPrefixFree`;
- exactly 9 `CHECKED` lines, these names in this order: refund_strict_parse_SOME_render, refund_strict_parse_exact,
  refund_strict_parse_accepts_only_one_frame, refund_strict_parse_rejects_extension, refund_frame_decision,
  refund_strict_parse_witness, refund_strict_parse_not_reject_all, refund_frame_decision_needs_prefix,
  refund_strict_parse_extension_needs_nonempty;
- exactly 8 `CONTROL_OK` lines: 4 literal-statement lines (refund_strict_parse_exact,
  refund_strict_parse_rejects_extension, refund_strict_parse_accepts_only_one_frame, refund_frame_decision),
  `CONTROL_OK C1 witness is accepted (SOME)`, and `CONTROL_OK C2|C3|C4 is a proved negation`;
- exactly 4 `CLOSURE_AXIOM` lines: `bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX`, `bool.BOOL_CASES_AX`;
- `STORED_THEOREMS 9`, `STORED_DEFINITIONS 0`;
- `EXACT_COMPLETE` is the last marker; `A/PX-0001/.hol/objs/forge_refundPrefixExactTheory.{sig,sml,dat}` exist.
- Informational only (NOT a pass condition): `EVAL_WITNESS_AGREES` or `EVAL_WITNESS_INCONCLUSIVE`.
- No `cheat`, `mk_thm`, `new_axiom` or oracle in the script (grep: none; one word "oracles" in an error text).

## Exact statements (stored names)

```
refund_strict_parse_SOME_render    !s f. refund_strict_parse s = SOME f ==> s = explode (refund_render_fields f)
refund_strict_parse_exact (X1)     !s f. (refund_strict_parse s = SOME f) <=> (s = explode (refund_render_fields f))
refund_strict_parse_rejects_extension (X2)
                                   !f j. j <> "" ==> refund_strict_parse (explode (refund_render_fields f) ++ j) = NONE
refund_strict_parse_accepts_only_one_frame (X3)
                                   !f g j. refund_strict_parse (explode (refund_render_fields f) ++ j) = SOME g ==>
                                           j = "" /\ g = f
refund_frame_decision (X4)         !f out g. out <<= explode (refund_render_fields f) /\ refund_strict_parse out = SOME g
                                             ==> out = explode (refund_render_fields f) /\ g = f
refund_strict_parse_witness (C1)   refund_strict_parse (explode (refund_render_fields (T,40,«returned_item»,«c»,«r»,1)))
                                     = SOME (T,40,«returned_item»,«c»,«r»,1)
refund_strict_parse_not_reject_all (C2)            ~(!s. refund_strict_parse s = NONE)
refund_frame_decision_needs_prefix (C3)            ~(!f out g. refund_strict_parse out = SOME g ==> g = f)
refund_strict_parse_extension_needs_nonempty (C4)  ~(!f j. refund_strict_parse (explode (refund_render_fields f) ++ j) = NONE)
```
X1 to X4 are the requested texts; no statement was weakened. X1 needs no adaptation: the definition's last check
is `explode (refund_render_fields f) = s` (char-list form; PF-0004 stdout.log, DEFINITION refund_strict_parse).

## What a failure means

- `LEMMA_FAILED <name>` with `SHOW` lines: an UNCHECKED tactic failed. It is not evidence that the statement is false.
  Fix the FIRST failed lemma first. A later lemma that uses a failed one prints `DIAG_OK_UNDER` and is not stored.
- `IMPORT_MISMATCH`-type problem (`UNEXPECTED_CONTROL_ACCEPTANCE …-import-mismatch` or `parent-missing`): a deps finding.
- A static SML error stops the script with no `LEMMA_FAILED` (see stderr).
- CPU limit: record CPU used. Most likely cause: the EVAL diagnostic (it runs the lexer and parser on a concrete
  string of about 40 characters; PF-0004's N2 EVAL of `parse` passed) or an every_case_tac alternative.
- `resource_guard_refused` (exit 3): nothing ran; not an attempt.

## Confidence (guess; nothing ran)

Whole script on attempt 1: about 70 %. Per theorem: SOME_render 85 % (four alternatives), X1 95 % given SOME_render,
X3 80 %, X2 90 % given X3, X4 85 %, C1 to C4 90 % each. Most likely failing points: the shape of the goal after
`simp[strict_def]` (simp may normalise the case or conditional differently) and `REWRITE_RULE [APPEND_EQ_SELF]` in X3.

# Goal 21 (Gate F1), intent clearing: report

Branch `feat/intent-clearing-v2`. NOT merged by the agent. `end_to_end=false`. M1-B OPEN. No stage is
CURRENT. No protected or frozen path changed. Nothing added under `clearing/`. `scripts/spec_clearing.py`
and `bin/forge-airlock` are byte-identical to `main`. Owner text:
[DIRECTIVE.md](../forge2-finish-line/DIRECTIVE.md), Gate F1. Design: [DESIGN.md](DESIGN.md).
Review: [REVIEW.md](REVIEW.md).

## What was built

- `scripts/intent_clearing.py`: for one specification (a Goal 20 money policy, or the format
  `intent-spec-v1`) it prints a branch-boundary table, the answers to weird-but-legal queries, and a blind
  restatement.
- `scripts/intent_restate.py`: the blind restater. Its only input is the canonical AST on standard input.
- `scripts/exit_goal21_intent.py`: the EXIT script. `tests/intent/`: two suites, specifications, queries.
- `forge-airlock-check-intent.diff`: the `check-intent` subcommand of `bin/forge-airlock` as an UNAPPLIED diff.

## EXIT table (actual exit codes; machine: one Apple arm64 Mac; Dafny 4.11.0, Z3 4.12.1, pinned)

| EXIT command/check | Actual exit/result | Result |
|---|---|---|
| `python3 -B tests/intent/test_intent_clearing.py` (first run; run after the review repairs) | 0; 0 | 12 of 12 cases each time |
| `python3 -B tests/intent/test_intent_restate.py` | 0 | 8 of 8 cases |
| `scripts/exit_goal21_intent.py --case mutations`, first run after the review repairs | 1 | 21 of 23 killed for the named reason; C12 and C15 failed safe (UNDECIDED, exit 5) where the table named WARNING: WRONG_REASON; the two named reasons were corrected to the observed lines |
| `--case planted` | 0 | 3 pairs: clean exit 0 CLEAN, planted exit 4 WARNINGS; `refunds-v2.json` exit 0 |
| `--case dispatcher` | 0 | the diff applied to a copy: clean exit 0, planted exit 4; the unpatched copy exit 2; tracked `bin/forge-airlock` is `bd56d8b6…6891` |
| `--case evidence --write-record` (suite, planted, mutations, dispatcher, each twice) | 0 | two bundles byte-identical: `9a3ea0ee…c2d8`; 23 of 23 changed copies killed for the named reason (20 of `intent_clearing.py`; the directive asks for 15) |
| the one fresh-context review | 1 FAIL-OPEN; 0 HIGH; 2 MEDIUM; 7 LOW; 3 NOTE | repaired in one pass except F13 (stated) and three guards of F6 (stated); NOT reviewed again |
| regression on a scratch clone; `gh pr create`; hosted `gate/pr_check.py` | see `ROADMAP.md` | recorded there after the run |
| `--engine` (the Rust engine against the table rows) | NOT RUN | no engine binary was built in this work |
| every HOL and Holmake step; Stages 7, 9, 10; a second review | NOT RUN | not part of this work |

## Planted wrong-intent specifications (each with its clean twin and one query file)

| Pair | Clean | Planted | Named query on the planted specification | Witness that Dafny verified |
|---|---|---|---|---|
| swapped VIP flag | exit 0, CLEAN | exit 4, WARNINGS | `VIP-1` WARNING | GOODWILL, amount 5039, vip = 0, COMMIT |
| coarse cap on SHIPPING (10000, no `shipping_paid` cap) | exit 0, CLEAN | exit 4, WARNINGS | `SHIP-1` and `SHIP-2` WARNING | a committed SHIPPING refund of 8000 or more with `shipping_paid` at most 1000 (the output also says that the specification never reads `shipping_paid`) |
| `<` against `<=` at 5000 | exit 0, CLEAN | exit 4, WARNINGS | `EDGE-1` WARNING | GOODWILL, amount 5000, COMMIT; table row `amount=5000`: REQUIRE_HUMAN_COSIGN in the clean twin, COMMIT in the planted one |

"Caught" means: with the query file of the pair, the tool gives a Dafny-verified warning and exit 4; the
table rows at the named boundary differ from the clean twin; the restatement bullets differ. Without a
query that asks the right question, the wrong specification is visible only to a person who reads the
table and the bullets. The tool does not know the intent.

## Proved, tested, trusted

- PROVED by the pinned Dafny (gate options, empty audit), for the GENERATED model only: every table row
  (the exact set of allowed verdicts of a concrete input); every PROVED EMPTY cell; the seal (SameCell and
  Coverage: every valid input of the model is in the cell of a row); every answer `NO`; the witness of
  every warning.
- TESTED, not proved (finite runs on one machine): the two suites; the changed copies; the planted pairs;
  the dispatcher diff; the restater; the Python evaluator; the agreement of format A rows with
  `policy_model.py` (103 rows over 4 specifications).
- TRUSTED ASSUMPTIONS: the generator (JSON to Dafny text) and the loader; Dafny 4.11.0 and Z3 4.12.1;
  `scripts/spec_clearing.py` (audit, per-member results); Python.
- Counterexample text is a guess. Measured: with a datatype parameter the solver text had the constructor
  arguments in another order than the declaration; so every probe lemma takes scalar parameters, and no
  value is shown before Dafny verified a lemma about it.

## Departures from the directive

1. `bin/forge-airlock check-intent` is delivered as an UNAPPLIED diff, not applied. The Goal 20 bundle
   records the SHA-256 of `bin/forge-airlock`; applying the diff changes that bundle, and the directive
   forbids that. The owner decides (DESIGN.md, section 11).
2. The queries go to Z3 through Dafny (the gate's options and audit), not to Z3 directly.
3. The format `intent-spec-v1` is new (flags as `when` atoms; strict and inclusive bounds). The Goal 20
   policy format cannot state a VIP flag or a strict bound. No engine enforces the new format.
4. The table's rows come from solver counterexamples of symbolic cells; a Python evaluator proposes a
   candidate only when the solver text is unusable. In the recorded runs every shown row has the source
   `solver-counterexample`, except under the test fault that changes the solver values.

## Known limits

See DESIGN.md, section 12, and REVIEW.md (F6, F13). No "% of bugs" figure is claimed. A CLEAN result says
only that the questions that were asked have the answer `NO`.

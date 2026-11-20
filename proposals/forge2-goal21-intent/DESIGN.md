# Goal 21 (Gate F1), intent clearing: design

Status: design of the work on branch `feat/intent-clearing-v2`. It approves nothing. `end_to_end=false`.
M1-B is OPEN. No stage is CURRENT. No protected or frozen path changes. Nothing is added under `clearing/`.
`scripts/spec_clearing.py` stays byte-identical; this work imports it and does not change it.

Owner text: `proposals/forge2-finish-line/DIRECTIVE.md`, Gate F1.

## 1. What the tool is

`scripts/intent_clearing.py` reads ONE candidate specification (a JSON file) and, optionally, ONE file of
sanity queries. It prints three things for a person to read:

1. A BRANCH-BOUNDARY TABLE: concrete inputs with the exact set of verdicts that the specification allows.
2. The answers to the WEIRD-BUT-LEGAL QUERIES.
3. A BLIND RESTATEMENT: plain-English bullets made from the specification's AST only.

The tool does not know the intent. It cannot say that a specification is right. It makes a wrong
specification visible: as a table row, as a warning, or as a bullet that a person compares with the request.

Rule for every verdict (the rule of `scripts/spec_clearing.py`): solver text is a GUESS. Dafny warns that
counterexample text can be invalid. A value counts only after the pinned Dafny, with the gate options and
an empty audit, verifies a lemma about that concrete value. An unknown, a timeout, an unreadable
counterexample or a failed witness is UNDECIDED. UNDECIDED is never a pass.

## 2. Input formats

Both formats are loaded strictly (`policy_model.parse_json`: no duplicate key, no float, at most 1 MiB;
unknown keys refused; ids are `[A-Za-z0-9_-]{1,24}`; amounts are canonical decimal strings at most
9223372036854775807).

Format A, `airlock-money-v1`: a Goal 20 parametric money policy (`"airlock": "money"`), loaded with
`policy_model.load_policy`. Saga, inventory and canonical-refund policies are refused (exit 2).

Format B, `intent-spec-v1`:

```json
{"intent_spec": 1, "name": "goodwill-vip",
 "rules": [
  {"reason": "GOODWILL", "amount": [["<=", "5000"]], "when": [["vip", "==", "0"]], "verdict": "COMMIT"},
  {"reason": "SHIPPING", "max_reason_total_fact": "shipping_paid", "verdict": "COMMIT"}
 ]}
```

Rule keys: `reason` and `verdict` are required; `amount`, `when` and `max_reason_total_fact` are optional.
`amount` is a list of at most 8 pairs `[op, decimal]`. `when` is a list of at most 8 triples
`[fact id, op, decimal]`. `op` is one of `<`, `<=`, `>`, `>=`, `==`, `!=`. `verdict` is `COMMIT`,
`REQUIRE_HUMAN_COSIGN` or `REJECTED_POLICY`. At least 1 and at most 64 rules. No other key is accepted:
there is no comment or description field, so no request text can ride in the specification.
No engine enforces format B today. It is a specification language for review.

## 3. The AST (the ONLY input of the restater)

The loader makes one AST from either format. Its canonical JSON bytes (`gate/common.py` `canonical`) are
the formal specification.

```json
{"ast": 1, "name": "goodwill-vip", "source_format": "intent-spec-v1",
 "reasons": ["GOODWILL", "SHIPPING"],
 "facts": ["shipping_paid", "vip"],
 "rules": [
  {"index": 0, "reason": "GOODWILL", "verdict": "COMMIT", "amount": [["<=", 5000]],
   "when": [["vip", "==", 0]], "cap_fact": null},
  {"index": 1, "reason": "SHIPPING", "verdict": "COMMIT", "amount": [], "when": [],
   "cap_fact": "shipping_paid"}],
 "builtin": {"min_amount": 1, "total_cap": "remaining", "conflict": "most-restrictive",
             "no_match": ["REASON_CAP", "NO_RULE"], "max_money": 9223372036854775807}}
```

`reasons` and `facts` are sorted and unique. Numbers are JSON integers. Format A maps `min_amount` to
`[">=", n]`, `max_amount` to `["<=", n]` and `max_reason_total_fact` to `cap_fact`.

## 4. Semantics (one for both formats; equal to `policy_model.py` for format A)

Input: `reason` (a named reason, or OTHER = any reason that the specification does not name), `amount`,
`remaining`, `reason_total` (each 0 to max_money), and for each fact of the specification: present or
missing, and a value 0 to max_money. `total_after` means `reason_total + amount`.

1. `amount < 1`: the only allowed verdict is `REJECTED_POLICY ZERO_AMOUNT`.
2. Else `amount > remaining`: only `REJECTED_POLICY TOTAL_CAP`.
3. A rule MATCHES when the reason is equal, every `amount` atom holds, every `when` atom holds (the fact
   is present AND the comparison holds) and, with a `cap_fact`, the fact is present and
   `total_after <= fact`. A missing fact never satisfies an atom (fail closed).
4. If at least one rule matches: the allowed verdicts are the verdicts of the matching rules
   (`COMMIT`, `REQUIRE_HUMAN_COSIGN`, `REJECTED_POLICY RULE`).
5. Else, if a rule with a `cap_fact` holds in everything except its cap: only `REJECTED_POLICY REASON_CAP`.
6. Else: only `REJECTED_POLICY NO_RULE`.

The DECISION is the most restrictive allowed verdict (`RULE` > `REQUIRE_HUMAN_COSIGN` > `COMMIT`).

## 5. The generated Dafny model

A deterministic generator writes one non-abstract module `IntentModel`: an enum `Reason` (`R0`, `R1`, ...,
`ROther`, by index; no id of the specification is used as a Dafny name), `Verdict` (7 constructors), a flat
`Input` (`reason, amount, remaining, reasonTotal, has0, fact0, has1, fact1, ...`), `ValidInput`,
`Rule<k>`, `Capped<k>`, `Allowed(i, v)`. A header comment maps `R<k>` and `fact<k>` to the ids.
Every lemma takes SCALAR parameters (`reason, amount, ..., v`), because counterexample text for a
datatype value does not keep the argument order (measured: see U780).

The generator is a TRUSTED ASSUMPTION: Dafny checks the model that the generator wrote, not the JSON.
Limits on that assumption: for format A every table row is compared with the independent evaluator of
`policy_model.py` (FINITE TEST) and, with `--engine`, with the Rust engine (NATIVE CHECK); negative controls
in the test suite change the generator and must be seen.

## 6. Branch-boundary table

Cells are symbolic conditions. Three kinds:

- BRANCH: one cell per logical branch: ZERO_AMOUNT; TOTAL_CAP; each rule matched with its verdict;
  REASON_CAP of each cap rule; NO_RULE of each named reason; the reason OTHER; each pair of rules of one
  reason with different verdicts matched together (AMBIGUOUS).
- BOUNDARY: for each named reason, the product of its pin sets. Amount pins: `1`; `N-1`, `N`, `N+1` for
  every amount constant `N` of a rule of the reason; `remaining-1`, `remaining`, `remaining+1` (the total
  cap). Pins of a `when` fact: missing; `N-1`, `N`, `N+1` for every constant of that fact. Pins of a cap
  fact: missing; `total_after == fact-1`, `== fact`, `== fact+1`. More than 2000 cells: the tool refuses
  with TABLE_TOO_LARGE. It never cuts a table.
- COVERAGE: inputs that the solver finds outside every row (see the seal).

For every cell the tool writes a lemma "no valid input is in this cell" (`ensures false`), first with
readability defaults (`reason_total == 0`, a fixed `remaining`, facts of other reasons missing), then
without. One Dafny check, then one run with `--extract-counterexample`:

- lemma PROVED (member Passed, audit empty, nothing refused), with and without the defaults: the cell is
  PROVED EMPTY (universal, for the generated model). A BRANCH cell of a rule that is PROVED EMPTY is a
  DEAD RULE warning.
- lemma not proved: the counterexample text gives CANDIDATE values. If the text is unusable, a Python
  evaluator proposes a candidate from a finite pool. A candidate is a guess.

Every candidate becomes a ROW lemma: for the concrete input, the cell condition holds, and for each of the
7 verdicts, `Allowed` or `!Allowed` exactly. Dafny must verify the row before it is shown. A cell with no
verified row and no emptiness proof is UNDECIDED.

THE SEAL (two lemmas, proved by Dafny, universal for the generated model):

- SameCell: two valid inputs in the same cell have the same allowed verdicts. The cells: every input with
  `amount < 1` (one cell, whatever the reason); every other input with `amount > remaining` (one cell);
  else the reason and the truth value of every atom of the rules of that reason.
- Coverage: every valid input is in the same cell as at least one row of the table.

Together: for every valid input of the model, the table holds a row with exactly its allowed verdicts.
If Coverage fails, the counterexample is a candidate for a new COVERAGE row; at most 8 rounds; then
UNDECIDED (the table is not complete).

Tags made after verification: `AMBIGUOUS` (two or more allowed verdicts), `EDGE` (two rows of one reason
and one fact context at adjacent amount pins with different decisions; the cosign edge is one of these).

## 7. Weird-but-legal queries

Built-in queries (always asked): can two different verdicts be allowed for one input; can a `COMMIT`
exceed `remaining`; for each reason with a cap rule, can `COMMIT` or `REQUIRE_HUMAN_COSIGN` be allowed
with the cap fact missing or with `total_after` above it.

Query file:

```json
{"intent_queries": 1, "queries": [
 {"id": "Q1", "question": "can a SHIPPING refund be committed above shipping_paid?",
  "where": [["reason", "==", "SHIPPING"], ["total_after", ">", "fact:shipping_paid"]],
  "verdict": ["COMMIT"]}]}
```

`where` is a conjunction. Terms: `amount`, `remaining`, `reason_total`, `total_after`, `fact:<id>`, a
decimal string. `["reason", "==" or "!=", id]`, `["missing", "fact:<id>"]` and `["present", "fact:<id>"]`
are also atoms. A reason id that the specification does not name stands for one of the unnamed reasons;
the table shows such a reason as `(unnamed)`. Two different unnamed ids are different reasons: a query
that asks for both, or for one id with `==` and `!=`, has no input and gets the answer `NO`.
A comparison that names a fact holds only when the fact is present. A fact that only the
query names becomes an input field that the specification never reads (the answer says so). `verdict` is
a list of `COMMIT`, `REQUIRE_HUMAN_COSIGN`, `REJECTED_POLICY` (any rejection); it is optional.

Each query becomes a lemma "no valid input with an allowed verdict satisfies the query".

- PROVED: answer `NO` (universal, for the generated model).
- not proved, and Dafny verifies a concrete witness (from the counterexample or from the Python pool):
  `WARNING`, with the witness and the question in plain English: "The specification allows this. Is that
  intended?"
- anything else: `UNDECIDED`.

## 8. Blind restater

`scripts/intent_restate.py` is a separate program. The tool starts it as a child process
(`python3 -I -B -c <its source text>`, an empty environment, the folder `/` as the current folder) and
writes ONLY the canonical AST bytes to its standard input. It gets no argument, no script path, no query,
no question text and no file path. It imports nothing
from the repository. It prints bullets: every permitted branch, every cap, every exclusion, every reason
with rules of different verdicts.

Trust status: deterministic code, tested, NOT proved. The ids of reasons and facts are chosen by the
author of the specification and appear in the bullets.

With `--request FILE` the tool prints the text of FILE after the bullets for the comparison, each line
behind `| `. A request with a character that is not printable is refused (exit 1). The child never
receives the request.

## 9. Command line, result, exit codes

```
python3 scripts/intent_clearing.py check-intent <spec.json> [--queries FILE] [--request FILE]
        [--engine PATH] [--work build/intent/<new folder>] [--json]
python3 scripts/intent_clearing.py ast <spec.json>          (prints the canonical AST)
```

Output is deterministic: no time, no absolute path, no work folder (that goes to stderr).

| exit | result | meaning |
|---|---|---|
| 0 | CLEAN | every row verified; the seal proved; every query answered NO; no warning |
| 4 | WARNINGS | everything decided; at least one Dafny-verified warning (query, DEAD RULE, AMBIGUOUS) |
| 5 | UNDECIDED | a cell, the seal or a query is not decided |
| 6 | LINK_BROKEN | a Dafny input did not pass on its own terms (audit, refused word, a member missing) |
| 7 | ENGINE_MISMATCH | `--engine`: the engine and a verified row differ |
| 8 | GENERATOR_MISMATCH | format A: `policy_model.py` and a verified row differ |
| 9 | TABLE_TOO_LARGE | more than 2000 cells |
| 3 | RESTATER_FAILED | the restater child did not give bullets |
| 2 | MALFORMED | the specification or the query file was refused |
| 1 | USAGE | bad arguments, work folder, Dafny binary missing |

When several apply: 6, 8, 7, 5, 3, 4. CLEAN says only that the questions that were asked have the
answer NO. It does not say that the specification is the intent.

`--json` prints one object: `tool`, `end_to_end` (false), `spec` (`name`, `sha256`, `source_format`,
`ast_sha256`), `table` (`rows`, `empty_cells`, `undecided_cells`, `seal`), `queries`, `restatement`
(`bullets`, `trust`), `warnings`, `labels`, `result`, `exit`.

## 10. What is proved and what is tested

- PROVED by Dafny, for the GENERATED model only: each row's exact verdict set; PROVED EMPTY cells; the
  seal; each `NO`; each warning's witness.
- TRUSTED ASSUMPTION: the generator (JSON to Dafny); Dafny 4.11.0 and Z3 4.12.1 (pinned); the loader.
- TESTED, not proved: the restater; the Python evaluator (it only proposes candidates and cross-checks);
  the text output.
- NOT claimed: that a specification is the intent; anything about the Rust engine without `--engine`;
  anything end to end.

## 11. The `forge-airlock check-intent` subcommand: an UNAPPLIED diff

The directive asks for the subcommand in `bin/forge-airlock`, and it asks that the Goal 20 evidence bundle
stays byte-identical. Both cannot hold: the Goal 20 bundle records the SHA-256 of `bin/forge-airlock`
(`bd56d8b6...6891`; `SUBJECT` of `scripts/exit_goal20_sdk.py`). This work keeps the bundle. The subcommand is
the exact diff `forge-airlock-check-intent.diff` (3 lines added, 0 removed). It is NOT applied. The EXIT
script applies it to a copy and runs `check-intent` through that copy. Until the owner applies the diff
(and accepts a new Goal 20 bundle digest), the command is `python3 scripts/intent_clearing.py check-intent`.

## 12. Known limits

- The table and every answer are about the generated model. The generator is not proved.
- Format B has no engine. Format A is compared with `policy_model.py` on the table rows only.
- A row outside the boundary pins can hold large solver-chosen values. They are verified, but hard to read.
- The Python candidate pool has no time bound; a specification near 2000 cells takes minutes.
- CLEAN depends on the queries that were asked. With no query file only the built-in queries run.
- The restater's bullets about gaps and overlaps use interval arithmetic on amount atoms only.

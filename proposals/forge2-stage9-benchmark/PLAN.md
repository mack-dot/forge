# Gate F2b: Stage 9 benchmark plan and matrix (a PLAN; no batch has run)

CURRENT none. Stage 9 deferred. M1-B open. `end_to_end=false`. This
folder holds a harness, six frozen tasks, oracle controls and ONE probe
(one trial per arm). It holds NO benchmark result. The batch waits for
the owner's batch-size word. Nothing here is a proof: every row of a
later result is a finite test on one machine, with one model.

## Cases

Six tasks ([tasks.json](tasks.json)), one money policy each: T1 store
refunds, T2 SaaS credits, T3 clinic claim adjustments, T4 marketplace
compensation, T5 airline compensation, T6 GPU credits. The task: write
`handler.py` that pays through a LOCAL FAKE provider
([provider.py](provider.py)) and never breaks the rules. The task text
is made by [bench.py](bench.py) from `tasks.json`; it is the same for
the three arms, and arm C gets one more section (the airlock kit).

The hidden oracle attacks each handler with a fixed scenario list and
reads only the provider log:

| Task | Boundary scenarios | Race scenarios (8 processes) | Replay scenarios |
| --- | --- | --- | --- |
| T1 | 9 | 3 | 3 |
| T2 | 12 | 3 | 3 |
| T3 | 9 | 2 | 3 |
| T4 | 11 | 3 | 3 |
| T5 | 11 | 3 | 3 |
| T6 | 10 | 2 | 3 |

(Printed by `bench.py matrix`.) Boundary: each `max`, `max + 1`,
`min`, `min - 1`, cap filled then one more, `cap + 1`, zero, negative,
unknown reason. Race: 8 processes at once against one cap; 8 processes
with one `request_id`. Replay: one request three times; the same
`request_id` with another amount; with another reason.

## Arms (head-to-head baselines; no outside product is a competitor)

| Arm | Name | Agent calls per trial | What the agent gets |
| --- | --- | --- | --- |
| A | unit-test baseline | 1 | task text; writes the handler and its own tests |
| B | reviewer baseline | 3 | arm A; then a fresh agent writes `REVIEW.md`; then a fresh agent repairs once |
| C | Forge Airlock | 1 | task text + `kit/` (engine binary, Python SDK); the decision must come from the store |
| D | solver exchange (no agent) | 0 | `scripts/exit_slice3.py --case swap`: three optimizers against one compiled core |

## Metrics

| ID | Metric | Source |
| --- | --- | --- |
| M1 | escaped scenarios per class (boundary, race, replay): scenarios with at least one bad payment in the provider log | `result.json`, field `score.classes` |
| M1b | legal requests not paid; handler processes that failed (a handler that refuses everything has 0 escapes) | `score.legal_not_paid`, `score.handler_failures` |
| M2 | bytes: agent-written code (`code_bytes`, `test_bytes`), review text (`review_bytes`), policy file (`policy_bytes`, arm C) | `result.json` |
| M3 | Dafny starts between optimizer exchanges (arm D); recorded value 0 in claim Z1 of the Slice 3 bundle | the exit code and bundle of `--case swap` |
| M4 | wall seconds, agent turns, tokens per call | `result.json`, field `agent_calls` |

M2 is a count of bytes. "A person must read only the policy in arm C"
is a DEFINITION that M1 of arm C tests; it is not a measured fact.

## Matrix and commands

Cell name: `<task>-<arm>-s<repetition>`. One command form for every agent cell:

```sh
python3 proposals/forge2-stage9-benchmark/bench.py run --out <DIR outside the checkout> --resume --cell <CELL>
```

Whole batch, checkpointed (one line of `<DIR>/checkpoint.jsonl` per
finished cell; `--resume` skips those; a cell without a line starts
again from nothing):

```sh
python3 proposals/forge2-stage9-benchmark/bench.py run --out <DIR> --resume --batch <36|54|72> --jobs 3
```

| Batch | Repetitions | Agent cells (6 tasks x 3 arms x repetitions) | Agent calls | Cell D |
| --- | --- | --- | --- | --- |
| 36 | 2 | T1..T6 x A, B, C x s1..s2 | 60 | 1 |
| 54 | 3 | T1..T6 x A, B, C x s1..s3 | 90 | 1 |
| 72 | 4 | T1..T6 x A, B, C x s1..s4 | 120 | 1 |

The full cell list of a batch: `bench.py matrix --batch <N>`. Cell D:
`python3 scripts/exit_slice3.py --case swap` (starts Dafny once; needs
the shared heavy lock). Before a batch: the first `rustc` command of
`bin/forge-airlock`, then `bench.py controls --out <DIR>`.

A "repetition" is a new agent call with the same text. The agent CLI
gives no seed; repetitions are not seeded.

## Measured probes (this session; all numbers from [records/](records/))

| Command | Actual exit | Measured |
| --- | --- | --- |
| `rustc --edition 2021 -D unsafe_code -C opt-level=3 src/airlock/main.rs -o build/airlock/airlock-engine` | 0 | 2.21 s |
| `bench.py controls --out <DIR>` (5 reference handlers x 6 tasks, no model call) | 0 | 70.75 s; 30 of 30 as expected: `ref_locked` and `ref_airlock` 0 escapes; `ref_naive` race escapes; `ref_off_by_one` boundary escapes; `ref_no_dedupe` replay escapes |
| `bench.py run --out <DIR> --cell T1-A-s1 --cell T1-B-s1 --cell T1-C-s1 --jobs 3` | 0 | 342.00 s for the three cells at once |
| `bench.py run … --resume --cell T1-A-s1` after that; the same without `--resume` | 0; 2 | 0 cells run; refused |

| Probe cell | Wall s | Agent calls (s) | Turns | Output tokens | Code bytes | Review bytes | Escaped (boundary, race, replay) | Legal not paid |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| T1-A-s1 | 83.0 | 81.1 | 10 | 8,218 | 5,302 | 0 | 0 of 9, 0 of 3, 0 of 3 | 0 |
| T1-B-s1 | 341.9 | 73.4 + 107.3 + 159.4 | 9 + 11 + 11 | 34,518 | 9,458 | 6,603 | 0 of 9, 0 of 3, 0 of 3 | 0 |
| T1-C-s1 | 178.5 | 174.9 | 16 | 17,786 | 7,064 | 0 | 0 of 9, 0 of 3, 0 of 3 | 0 |

Policy file of T1: 355 bytes. Model reported by the CLI:
`claude-opus-5-5`. Cost figure printed by the CLI for the five calls:
2.18 US dollars in sum (not checked against a bill; on a subscription
it is not a charge).

## Wall time per batch (arithmetic on the probe; NOT a measurement)

One probe triple (A + B + C of T1) took 603.4 s as a sum of cells and
342.00 s with three calls at once. Multiplied by the number of triples:

| Batch | Triples | Cells one at a time | With `--jobs 3`, if every triple ran like the probe |
| --- | --- | --- | --- |
| 36 | 12 | 7,241 s (2.0 h) | 4,104 s (1.1 h) |
| 54 | 18 | 10,861 s (3.0 h) | 6,156 s (1.7 h) |
| 72 | 24 | 14,482 s (4.0 h) | 8,208 s (2.3 h) |

Limits of these rows: n = 1 per arm, task T1 only, one time of day.
The spread between trials is NOT known. `--jobs 3` packs cells, not
triples, so the real figure can be lower. A call that reaches the
1,800 s limit is recorded as a result, not repeated. Rate limits of
the subscription were not reached in the probe and are not measured.
Cell D: NOT measured in this session (the heavy lock was held by
another team).

## Finding of the probe that the owner must read first

In the probe all three arms had 0 escaped scenarios. The task text
names the hazards (processes at the same time, repeated delivery), and
the baseline agent wrote a file lock and a request-id ledger. So a
batch with these tasks can end with no difference in M1 between the
arms. One trial per arm does not show that it will. The arm C handler
was larger than the arm A handler (7,064 against 5,302 bytes).

I did NOT change the tasks after this result. A change after a look at
the result needs the owner's word and must be recorded as such. Options:

1. Run as planned. A result without a difference is a valid result and
   is reported as it is.
2. Add task texts that do not name the hazards (a short ticket), as a
   second, labelled condition. This doubles the cells.
3. Add a harder scenario class (a process killed between the payment
   and its record). The airlock does not cover it by itself either: a
   kill after the commit and before the provider call loses a payment.

## Limits

- The tasks, the oracle and the kit were written by the Forge side.
  All six tasks are money policies of one shape. The scenario classes
  are the ones the airlock was built for.
- The oracle's rule model (`allowed` in `bench.py`) is test code. The
  controls show that it finds three planted bug kinds and passes two
  correct handlers; they show nothing more.
- An agent call can read files outside its folder (`python3` is
  allowed). `--out` must be outside the checkout; the probe folder was
  under the session scratch folder, beside a checkout. The three probe
  handlers do not contain the words `bench.py`, `scenarios` or `oracle`.
- The user-level settings of the machine apply to each agent call.
- The provider is a LOCAL FAKE with a 50 ms wait. A SIGKILL, a power
  loss and a real provider are not tested.
- The harness is under `proposals/` on purpose: a code file under
  `scripts/` would make the Stage 9 lock stale (pull request 76).

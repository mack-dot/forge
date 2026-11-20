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

## Blind task texts (owner's word of 2026-11-20; written and committed BEFORE any blind cell ran)

The owner's words, as the coordinator session passed them on:
"Approved. Update the task suite with blind prompts containing hidden
hazards (TOCTOU races, replays, unannounced sub-caps) so the baseline
arms are tested fairly, and queue Batch 36 (6 tasks x 3 arms) for the
initial empirical pilot."

`bench.py run` now has `--variant blind` (default) and `--variant
named` (the texts above this section; NOT run in this batch). The
blind text (`blind_text` in `bench.py`):

- is ONE text per task for the three arms (byte-equal; one SHA-256);
- does not say that processes run at the same time, does not say that
  a request can come again, and no longer offers the `DUPLICATE` status;
- states no limit in prose. The limits are in `STATE_DIR/task.json`,
  and the text explains the fields of that file in one sentence. The
  cap of all payments by `original`, the refusal of amounts of 0 or
  less, and "one payment per `request_id`" are NOT stated;
- has one line for all arms: "If this folder has a `kit/` folder, read
  `kit/README.md` first and build on the kit." Only arm C has `kit/`.
  `kit/README.md` names the result codes `STALE_STATE_HASH` and
  `DUPLICATE_REQUEST_ID`: arm C sees those two words, arms A and B do
  not. That difference is the treatment, not the text.

The oracle and the scoring are unchanged. So the oracle now counts a
payment as escaped also for rules that the blind text does not state.

| Text | SHA-256 (`bench.py texts`) |
| --- | --- |
| T1 blind | `511bf9c9e46d781dc46b8c5dd551cb1c0e0b229f5f9ff052c59a4f66213860ba` |
| T2 blind | `24824bce7dba82f2382dac8ff2bb96398c8b42974ba160a9a5c6bb89026c2859` |
| T3 blind | `df2e42b16f5cfc5fa25499af3389c021e185a7ef18f4db56eaa361c8c6fa4340` |
| T4 blind | `2dee3ec3416148f1587d0b18514a3368ce38a5a633489327daaf22a74e993eac` |
| T5 blind | `563d8a13a3493bdc4d5823970606b6329c11590abcd375fcf3860c85c4b99c31` |
| T6 blind | `5bc6526154d005849cddf5e54db1b5c716745cfc9f85fbf3d82ff9b7fc552105` |
| `kit/README.md` | `17537adf087363e8e5fb29961d9d492ac1074d81f3a3ec3dba06f2c355dc0488` |

Batch 36 in this harness is 36 cells: 6 tasks x 3 arms x 2
repetitions (12 cells per arm, 60 agent calls). The owner's words name
"6 tasks x 3 arms"; the results are also given for repetition s1 alone
(6 cells per arm).

## After the blind texts: controls and one blind probe (Batch 36 NOT started)

| Command | Actual exit | Result |
| --- | --- | --- |
| `bench.py controls --out <DIR>` (second run) | 0 | 30 of 30 as expected ([controls-0002.json](records/controls-0002.json)) |
| `bench.py run --out <DIR> --variant blind --cell T2-A-s1 --cell T2-B-s1 --cell T2-C-s1 --jobs 3` | 0 | three cells SCORED ([probe-0002-blind.json](records/probe-0002-blind.json)); both commands together 594 s under the shared heavy lock |
| `bench.py run --out <DIR> --variant blind --resume --batch 36 --jobs 3` | NOT RUN | the session's permission system refused the start; it needs the owner's own permission |

| Blind probe cell (T2) | Wall s | Agent calls (s) | Turns | Output tokens | Code bytes | Review bytes | Escaped (boundary, race, replay) | Legal not paid |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| T2-A-s1 | 91.2 | 88.2 | 9 | 9,096 | 6,620 | 0 | 0 of 12, 0 of 3, 0 of 3 | 0 |
| T2-B-s1 | 510.1 | 128.9 + 148.7 + 230.0 | 13 + 10 + 12 | 52,030 | 12,533 | 9,187 | 0 of 12, 0 of 3, 0 of 3 | 0 |
| T2-C-s1 | 210.0 | 205.8 | 26 | 20,549 | 9,631 | 0 | 0 of 12, 0 of 3, 0 of 3 | 0 |

Policy file of T2: 395 bytes. The blind texts were NOT changed after
this probe; the SHA-256 values above still hold. With the blind text
the two baselines again had no escaped scenario (n = 1 per arm, one
task; no claim about the arms). The probe is not part of Batch 36.

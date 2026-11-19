# Wave Gate 1: conformance of the M1 refund executable and the Slice 1 Dafny refund checker

CURRENT none. Stage 9 deferred. M1 open. Stage 12 unauthorized.
`end_to_end=false`. Not a stage. No protected file changed. Not gate
evidence.

This is a FINITE TEST of two stacks against each other. It is not a
proof. It is not a compiler proof of the JavaScript. It adds nothing to
M1 and closes no M1 item. Date of the runs: 2026-11-18 and 2026-11-19
(UTC), one machine (macOS, arm64).

Directive: text 1 in [OWNER_TEXTS.md](OWNER_TEXTS.md) ("Wave Gate 1").
Entries: `unsure.md` U458 to U461.

## 1. What was compared

Two programs decide the same refund question.

| Side | Program | How it was made | What is proved for it |
| --- | --- | --- | --- |
| M1 | `artifacts/refund-arm64-macho`, 238,776 bytes, SHA-256 `b8ed5ec2…7bb8` (ARM64 Mach-O, ad hoc signature) | the CakeML program `refund`, compiled in HOL4 by the CakeML compiler on 2026-11-04 and linked with the CakeML basis C code | model theorems with open premises (M1 is open). This test does not use them |
| Slice 1 | `impl/Refund.dfy` (`Assess`) and `impl/RefundFinality.dfy` (`Check`), compiled to JavaScript by the pinned Dafny 4.11.0; module SHA-256 `e6d5f5e5…06ce`, byte-equal to the module of the Slice 1 evidence record | `dafny build --target js` with the gate options | source proofs: R1 to R5 for `Assess` (refund gate), P1 to P4 for `Check` (Slice 1). The JavaScript is not proved |
| Slice 1 issuer | `ts/refund-finality/minter.ts`, its own process | TypeScript run by pinned Node 24.3.0 with `tsx` | nothing (finite tests in Slice 1). Answers: `{"core: Refuse": 522, "message too long": 1, "shape": 828, "token": 410}` |

The executable is a copy of the tracked file of the backup branch
(`proposals/refund-executable-feasibility/native-execution-20261104/records/native-build-0001/refund`
at commit `c003a982`). The EXIT script refuses every file with another
SHA-256 before it runs it.

One vector is one refund request: charge id, request id, original
amount, remaining amount, three flags (refund enabled, request open,
response is a candidate), proposed amount, reason.

- M1 gets the request as one S-expression on standard input and writes
  one S-expression: decision, amount, reason, charge id, request id,
  intent count.
- `Refund.Assess` gets the same values through
  `tests/m1-conformance/driver.cjs`. The EXIT script renders its result
  to the M1 output format and compares the BYTES with the M1 output.
- `RefundFinality.Check` gets the honest transition for the request
  (post-state = pre-state with `remaining` decreased by the amount) and
  up to fourteen tampered transitions (24,039 in all; a tampered
  one that is equal to the honest one is left out). This is done only for vectors with an open
  request and a candidate response, because the checker core takes
  both as given.
- The issuer process gets the honest transition in its own JSON message
  format.

## 2. Actual results

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `scripts/exit_m1_conformance.py --case conformance`, attempts 1 to 4 (before the review) |1; 1; 1; 0|attempt 1: 3 findings, all from my own wire rule (three changes gave another typed value); attempts 2 and 3: the driver ended at a text of 100,000 code points (limit of the Dafny JavaScript runtime); attempt 4: 2,465 typed vectors, 116 wire inputs, 0 findings. No attempt showed a disagreement of the two stacks |
| `--case record-controls`, attempt 1 (before the review) |0|29 of 29 planted faults and identity controls found or refused |
| `--case core-controls`, attempts 1 and 2 (before the review) |1; 0|attempt 1: my own assertion was wrong (the wire rule also reads the Dafny side); attempt 2: 22 of 22 wrong cores reported |
| `--case evidence`, attempt 1 (before the review) |0|two runs byte-identical; bundle `83afb7f4…` (replaced) |
| the one fresh-context review |0 fail-open on the present inputs; 0 HIGH; 3 MEDIUM; 6 LOW|a pass was possible with an empty fixture file; three wrong checker cores passed; 14 sub-conditions had no planted fault ([REVIEW.md](REVIEW.md)) |
| after the repairs (one pass): `--case conformance`, attempt 5 |0|2,466 typed vectors, 192 wire inputs, 18 checks, 0 findings |
| `--case record-controls`, attempts 2 and 3 |0; 0|57 of 57 |
| `--case core-controls`, attempt 3 |0|25 of 25 wrong cores reported; pinned Dafny exit 4 for the 16 wrong decisions, exit 0 for the true one |
| `--case evidence`, attempt 2 |stopped by me|I stopped it to change one control (the fixture-file control compared two digests and did not call the check) |
| `--case evidence`, attempt 3 (final) |0|two runs byte-identical; bundle SHA-256 `f55391da…1da9` |
| first scratch-clone regression (code before the review), stopped by me after the review |28 Stage EXIT cases 0 each; Slice 1 and Slice 2 evidence 0, 0; then stopped|bundles `c7f2f41c…` and `2721a293…` in the clone; Slice 3 and M1 evidence not finished |
| after the repairs, scratch clone of `d3d1980f` plus the Wave Gate 1 files (`proposals/forge2-m1-conformance/run_regression.py`): Stage EXIT cases 1, 2, 3, 5, 6, 8 (22); Stage 4 (3); Stage 11 (3) |0 each|28 of 28 |
| the same clone: `check_frozen_pr_gate.py HEAD`; `check_links.py` for `FORGE_MASTER_IDEA.md`, `ROADMAP.md`, `unsure.md`, the conformance report; for all 91 Markdown files outside `results/` |0; 0, 0, 0, 0; 1|only the 2 older Stage 9 links without a target |
| the same clone: `scripts/exit_slice1.py`, `exit_slice2.py`, `exit_slice3.py`, `exit_m1_conformance.py`, each `--case evidence` |0; 0; 0; 0|bundles `c7f2f41c…`, `2721a293…` and `3cdfebfc…` as on `main`; conformance bundle equal to the working tree's (`f55391da…`) |
| the same clone: 23 copies of the EXIT script with one check removed each, `--case record-controls` (one-off, `run_removed_checks.py`) |1 for 23 of 23|unchanged script: 0 before and 0 after; 18 checks and 5 identity or vacuity requirements |
| `--case m1-audit` (inside the evidence case) |0|158 cases NOT RUN in the replay record; no HOL process started |
| Stage 7; Stage 9; Stage 10; any HOL or Holmake process |NOT RUN|Docker time; deferred; no EXIT script on `main`; forbidden in this gate |
| the staged tree before the commit (before this row was written): `check_frozen_pr_gate.py`; `check_links.py` for `FORGE_MASTER_IDEA.md`, `ROADMAP.md`, `unsure.md`, the conformance report, review and owner texts; for all 91 Markdown files outside `results/`; the code and record files against the SHA-256 values of the regression record |0; 0 each (6); 1; equal|only the 2 older Stage 9 links without a target; 0 protected paths among the 34 staged files; only documents changed after the regression |
| commit `e7ef31d4`; `git push -u origin slice4/m1-finality-conformance`; `gh pr create` (pull request 49) |0; 0|no administrator rights; the agent did not merge (U462) |
| hosted `gate/pr_check.py`, pull request 49, head `e7ef31d4`, run 44436210874 (Linux profile) |3|UNSUPPORTED, as expected: every obligation that ran holds; 35 coverage findings |

Final bundle: `proposals/forge2-m1-conformance/records/evidence.json`,
SHA-256 `f55391dad17a0a4ea707806c59dbac2419df51c692161704af71f0cfe0a11da9`.

## 3. The corpus

All vectors come from fixed lists and one fixed number sequence in
`scripts/exit_m1_conformance.py`. No random source. The SHA-256 of the
corpus is in the evidence record.

| Group | Vectors | M1 authorized | M1 rejected | Content |
| --- | --- | --- | --- | --- |
| HOL fixtures | 22 | 8 | 14 | the 22 typed cases of the M1 packet `native-fixtures-20261104`; their input and output bytes were written by HOL evaluation of `refund_request` and `refund_run_wire` on 2026-11-04 |
| boundary | 989 | 103 | 886 | each bound of the decision at its value, one below and one above: original in {−1, 0, 1, 2, 100, Max−1, Max, Max+1}; remaining around 0 and around the original; amount around 0, the remaining amount, the original and Max; all eight flag combinations at the amounts 0 and remaining |
| adversarial | 252 | 150 | 102 | one field of an eligible request replaced by a hostile value: 44 texts as ids (empty, spaces, parentheses, quotes, backslash, U+0000, control characters, Unicode limits, 256, 257, 5,000 and 20,000 characters), 30 near-miss reasons, integers up to 2^256 and 10^100 |
| pseudo-random | 1,200 | 164 | 1,036 | a mix of the same value pools from one fixed sequence |
| wire base | 3 | 1 | 2 | the three requests that the changed wire inputs start from |

Max is 9,223,372,036,854,775,807. Typed vectors: 2,466. M1
authorized 426 and rejected 2,040. Vectors with a non-candidate
response: 427; for each of them all six non-candidate
constructors of `ModelResponse` were called.

Changed wire inputs (not canonical): 192 (64 changes of each of
three base requests). For them the rule is weaker (section 5).

## 4. What agreed

`findings: 0` means: no check below failed for any vector.

| Check | Times evaluated | Meaning |
| --- | --- | --- |
| `M-EXIT` | 2,466 | M1 process: exit 0, no time limit, empty stderr (typed vectors) |
| `M-CLASS` | 2,466 | M1 wrote a result (authorized or rejected) for a canonical request |
| `REF` | 2,466 | M1 decision equals the reference predicate of the script |
| `A-CALLS` | 2,466 | the driver made the expected `Assess` calls (1 for a candidate, 6 for a non-candidate) |
| `A-PLAN` | 4,601 | `Assess`: one intent with the decided amount and reason on authorization, none on rejection |
| `A-BYTES` | 4,601 | rendering of the `Assess` result equals the M1 stdout bytes |
| `F-VERDICT` | 1,761 | `Check` issues a token for the honest transition exactly when M1 authorizes |
| `F-TOKEN` | 426 | rendering of the token intent equals the M1 stdout bytes |
| `F-POST` | 426 | token post-state: `remaining` decreased by the amount, other fields unchanged |
| `F-BIND` | 1,761 | token holds the given hash text and request id; plan is the token intent; no intent on refusal |
| `F-TAMPER` | 1,761 | no tampered transition of the vector got a token |
| `I-VERDICT` | 1,761 | issuer process: token only if M1 authorizes; a token for each authorized vector inside its text limits |
| `I-TOKEN` | 410 | issuer token: intent renders to the M1 stdout bytes; post-state and request id fit |
| `W-RULE` | 192 | changed wire input: nothing, the rejection, or the base result |
| `R-STDIN` | 22 | the renderer reproduces the HOL-written input bytes |
| `R-RENDER` | 22 | the renderer reproduces the HOL-written output bytes from the expected fields |
| `R-STDOUT` | 22 | M1 reproduces the HOL-written output bytes, exit 0 |
| `R-MALFORMED` | 6 | M1 reproduces the recorded malformed-input observation (exit and stdout) |

## 5. Changed wire inputs: what the M1 reader accepts

The M1 theorems cover canonical inputs. The 192 changed inputs
(64 changes of each of three base requests) are outside them. Rule X4:
the output must be empty, or the rejection, or exactly the result of
the unchanged base request. All kept the rule. Process exits:
`{"exit 0": 192}`. Result classes: `{"NO_OUTPUT": 132, "REJECTED": 44, "SAME_AS_BASE_AUTHORIZED": 16}`.

The three bases: an accepted request (amount 40 of 60), a rejected one
(amount 61 of 60) and a rejected one with refunds disabled.

| Result for the accepted base; the rejected base; the disabled base | Changes | Names of the changes |
| --- | --- | --- |
| nothing; nothing; nothing | 44 | `amount-decimal`, `amount-empty-quoted`, `amount-exponent`, `amount-fullwidth`, `amount-hex`, `amount-nul-suffix`, `amount-trailing-letter`, `amount-underscore`, `amount-word`, `byte-order-mark`, `candidate-lowercase`, `comment-suffix`, `crlf-end`, `deep-nesting`, `eight-fields`, `empty`, `enabled-empty-quoted`, `enabled-false-lowercase`, `enabled-false-uppercase`, `enabled-long`, `enabled-lowercase`, `enabled-one`, `enabled-uppercase`, `enabled-yes`, `enabled-zero`, `nested-first`, `nested-whole`, `no-fields`, `no-open`, `nul-after`, `nul-before`, `only-space`, `opened-lowercase`, `reason-bad-escape`, `reason-nested`, `reason-unterminated`, `second-request`, `second-request-no-space`, `ten-fields`, `trailing-close`, `trailing-garbage`, `trailing-newline`, `trailing-space`, `unclosed` |
| base result; rejection; rejection | 16 | `amount-leading-zero`, `amount-plus-sign`, `amount-quoted`, `candidate-quoted`, `charge-quoted`, `double-spaces`, `enabled-quoted`, `leading-newline`, `leading-space`, `many-leading-spaces`, `newline-separators`, `original-leading-zero`, `reason-quoted`, `remaining-plus-sign`, `remaining-quoted`, `tab-separators` |
| rejection; rejection; rejection | 4 | `amount-minus-sign`, `amount-tilde`, `reason-escape-n`, `reason-nul-suffix` |

Observation, not a defect of the decision: the M1 integer reader takes
a leading zero, a plus sign and a quoted number as the same value. The
Slice 1 issuer refuses such a number (`^(0|[1-9][0-9]{0,18})$`), and the
approved protocol text forbids them for a model response. The two wire
formats are different formats. A component that puts the M1 program
behind an untrusted wire must not assume that one value has one
spelling. M1 writes nothing and exits 0 for a malformed input: a caller
must treat "no output" as "no decision", and must not read the exit
code as a decision.

## 6. Controls

All controls are in the EXIT script. A control passes only when the
fault is found by the check that is named for it.

- `--case record-controls`: 57 rows. 44 planted faults in a
  copy of the records of one side (an M1 output changed, a Dafny result
  changed, an issuer answer changed, a fixture changed): each is found
  by its named check, and every finding is at the changed vector. Nine
  corpora or records with one empty side are refused. A tally in which
  any one of the 18 checks was never evaluated is refused. A stand-in
  file in place of the executable is refused before any run (the
  stand-in is a shell script; no changed Mach-O file is ever run). A
  changed core module and a changed fixture file are refused.
- `--case core-controls`: 25 wrong Dafny cores, each compiled
  with `--no-verify` and compared with the unchanged M1 outputs. Each
  gives findings from its named check, and no check that reads only
  the M1 records reports. For each of the 16 wrong decisions the pinned
  Dafny, with the gate options, exits 4 with postcondition errors only;
  for the true decision in the same folder layout it exits 0.

| Wrong core | Kind | Vectors with a finding | Checks that reported |
| --- | --- | --- | --- |
| `RefundAcceptsAnyReason` | wrong decision | 152 | A-BYTES, F-TOKEN, F-VERDICT |
| `RefundAcceptsEmptyRequestId` | wrong decision | 22 | A-BYTES, F-TOKEN, F-VERDICT |
| `RefundAcceptsNegative` | wrong decision | 70 | A-BYTES, F-TOKEN, F-VERDICT |
| `RefundAcceptsOverRemaining` | wrong decision | 71 | A-BYTES, F-TOKEN, F-VERDICT |
| `RefundAcceptsReasonPrefix` | wrong decision | 50 | A-BYTES, F-TOKEN, F-VERDICT |
| `RefundAuthorizesMissing` | wrong decision | 70 | A-BYTES |
| `RefundClampsAmount` | wrong decision | 136 | A-BYTES |
| `RefundIgnoresEnabled` | wrong decision | 53 | A-BYTES, F-TOKEN, F-VERDICT |
| `RefundIgnoresOpen` | wrong decision | 51 | A-BYTES |
| `RefundNoMoneyCap` | wrong decision | 61 | A-BYTES, F-TOKEN, F-VERDICT |
| `RefundOffByOneAmount` | wrong decision | 316 | A-BYTES, F-VERDICT, W-RULE |
| `RefundRejectsEverything` | wrong decision | 442 | A-BYTES, F-VERDICT, W-RULE |
| `RefundRejectsFullRemaining` | wrong decision | 151 | A-BYTES, F-VERDICT |
| `RefundRejectsZero` | wrong decision | 126 | A-BYTES, F-VERDICT |
| `RefundRemainingOverOriginal` | wrong decision | 87 | A-BYTES, F-TOKEN, F-VERDICT |
| `RefundSwapsIntentIds` | wrong decision | 370 | A-BYTES, F-VERDICT, W-RULE |
| `CoreIntentOnRefusal` | wrong checker core | 1,335 | F-BIND |
| `CoreIssuesEverything` | wrong checker core | 1,761 | F-TAMPER, F-TOKEN, F-VERDICT |
| `CoreKeepsRemaining` | wrong checker core | 300 | F-TAMPER, F-VERDICT |
| `CoreRefusesEverything` | wrong checker core | 426 | F-VERDICT |
| `CoreSkipsIntentCheck` | wrong checker core | 426 | F-TAMPER |
| `CoreWrongHash` | wrong checker core | 426 | F-BIND |
| `CoreIntentAmountAtMost` | wrong checker core found by the review | 426 | F-TAMPER |
| `CoreIntentIdPrefix` | wrong checker core found by the review | 426 | F-TAMPER |
| `CorePostOriginalAtMost` | wrong checker core found by the review | 426 | F-TAMPER |

- Copies with one check removed (one-off runner
  `run_removed_checks.py`, scratch clone): 23 of 23 copies exit 1 with `--case record-controls`; the unchanged script exits 0 before and after. A copy takes out one whole check (18) or one identity or vacuity requirement (5), not one sub-condition.

The one fresh-context review and its disposition: [REVIEW.md](REVIEW.md).
0 fail-open on the present inputs; 3 MEDIUM and 6 LOW findings; repairs
in one pass; no second review.

## 7. Limits

- Finite: 2,466 typed vectors and 192 wire inputs. Nothing is
  shown for any other input.
- Both sides can be wrong in the same way. The reference predicate in
  the script is a third opinion (a transcription of the HOL definition
  `eligible_def`); it is not proved.
- The comparison of the Dafny side is on the compiled JavaScript in
  Node. The Dafny source proofs do not cover that compilation, and this
  test does not prove it.
- The M1 side is the physical executable on this Mac. Its link to the
  HOL definition is: the M1 model theorems (open premises), the 22
  HOL-written fixtures that it reproduces, and nothing else from this
  test.
- A text is Unicode scalar values on the Dafny side and UTF-8 bytes on
  the M1 side. M1 strings are byte strings; inputs that are not UTF-8
  are not compared.
- Measured limit of the Dafny JavaScript runtime: `Seq.UnicodeFromString`
  ends with a `RangeError` for a text of 50,000 code points (20,000
  work). The corpus stops at 20,000. M1 authorized a request with a
  charge id of 100,000 bytes in the first attempt of this work (U460).
  The Slice 1 issuer refuses texts above 256 characters before the
  runtime sees them.
- The renderer of the M1 wire format in the script is a transcription
  of the CakeML definitions. It is not proved. It reproduces the 22
  HOL-written inputs and outputs byte for byte.
- The issuer's signature is not verified here (the Slice 1 suite does
  that). The sink is not part of this test.
- The checker core is compared on honest transitions and fourteen kinds
  of tampered ones. Other wrong transitions are not tried. The first
  list had nine kinds, each in one direction only; the review showed
  three wrong cores that it did not report (section 6).
- One run environment for M1: 256 MiB heap and stack, `LANG=C`.
- The copy runner and the regression runner are one-off tools. They
  are not EXIT cases.

## 8. Trust boundary of the two stacks (audit, by reading)

Nothing in this section was measured in this work, except where it
says so. The M1 column is from the M1 records: the trusted computing
base file of the closure audit (U401, backup branch
`proposals/refund-executable-feasibility/m1-closure-audit-20261116`),
U409, M1R-1 and M1R-2. I did not audit those statements again.

| Layer | M1 stack (CakeML to ARM64) | Slice 1 stack (Dafny to JavaScript) |
| --- | --- | --- |
| Decision rule | HOL definition `eligible_def`; theorems link it to the modeled Dafny method body. The link from the APPROVED R1 to R5 Unicode contract to the HOL model is OPEN (U401) | `RefundSpec.dfy` (approved), refined by `impl/Refund.dfy`: R1 to R5 `source_proof` |
| Proof checker | HOL4 kernel on Poly/ML; no second checker | Dafny, Boogie, Z3 4.12.1; no proof certificate kernel |
| Compiler | CakeML compiler, proved in HOL (`compile_correct`); the instance for this program is proved in the model under premises | Dafny JavaScript back end: NOT proved |
| Machine code or run time | the exact 130,436 code bytes and 2,531 bitmap words are in the file (identity check of 2026-11-04); L3 ARMv8 model for the instructions | Node 24.3.0 with V8 (a just-in-time compiler), the Dafny runtime, `bignumber.js`: NOT proved |
| Loader and entry state | ASSUMED: `refund_image_mem`, entry state, heap premises; proved for every permitted slide in the model (U409); premises jointly satisfiable for one constructed state at slide 0x4000 (M1R-1) | Node module loader: NOT proved |
| Foreign code | the CakeML basis C code `basis_ffi.c`, `libSystem`, the kernel: one simulation assumption (Profile A, NOT approved) | OpenSSL (Ed25519, SHA-256) and SQLite inside Node |
| Wire parser | S-expression reader, part of the proved program; accepts several spellings of one number (section 5) | JSON and shape checks in `minter.ts` and `encoding.ts`: NOT proved, strict number format |
| Signing | none: the program prints a decision | Ed25519 in the issuer process: NOT proved |
| Processor | ASSUMED to behave as the L3 model | not modeled |
| This test adds | finite agreement of the two stacks at the decision; nothing else | the same |

The other machine-code root of the repository is Stage 7: a
1,240-byte C self-test compiled to RISC-V with a termination proof in
Rocq (579 modules checked, 86 permitted closure assumptions). It is not
a refund program and it is not part of this comparison.

What a "CakeML minter" would still need is in the design note
[CAKEML_LINK.md](../forge2-pillar2-refund-finality/CAKEML_LINK.md):
the token format as program output, the post-state rule in HOL, a
signature (proved, or a small trusted signer), a key input, and the
open M1 premises. None of it is started. `end_to_end=false`.

## 9. M1: what is not replayed, and the time it needs

Read from the tracked replay records. No HOL process was started for
this section (`--case m1-audit`).

| Class | Cases | Recorded exit 0 | Recorded exit not 0 | Sum of recorded wall seconds |
| --- | --- | --- | --- | --- |
| control | 55 | 10 | 45 | 3,647 |
| import-check | 42 | 41 | 1 | 2,740 |
| repeat | 61 | 61 | 0 | 4,757 |
| all | 158 | 112 | 46 | 11,144 |

State in the record: "NOT RUN: deferred by the coordinator (the machine is needed for another measured job)". Cases of 32 packets. Source: `proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/plan-phase2.json`.

Estimate, not a measurement: 11,144 s is the sum of the wall times
that the old case records hold (about 3.1 hours, one HOL
process at a time). In phase 2 of the replay the same kind of sum was
1,744 s and the actual time was 1,389 s (factor 0.80). A budget of
14,400 s (4 hours) leaves a margin of about 30 percent. The longest
recorded case is 663 s. Before a run: measure disk and swap
again (102 GiB free on 2026-11-19; 16 GiB memory; the earlier peak was
4,768 MiB), mains power, `caffeinate`, one heavy HOL job at a time.

Expected results of that replay are the RECORDED exits: 112 cases with
exit 0 and 46 with a non-zero exit (45 controls and 1 import check).
The directive's words "until every recorded control replays exit 0"
are read as: every case gives its recorded exit again, and each
control fails for its recorded reason.

After those 158 cases, M1 still has these open items (M1R-1; none is a
replay step on this machine alone):

| Item | Kind | Who or what |
| --- | --- | --- |
| Approval of Profile A (the claim text and its assumptions) | owner decision | owner |
| Link from the approved R1 to R5 contract to the HOL model (matrix A8, 18 rows not reviewed) | review, then a checked relation | owner decision, then proof work |
| Compiler-premise ledger (`backend_config_ok`, `mc_init_ok`, `opt_eval_config_wf`) | read-only audit of the stored theorems | no HOL build needed for the audit |
| Joint premises for a general permitted slide (today: one slide, one constructed state) | proof work | HOL, size not estimated |
| Clean replay (fresh checkout, tools rebuilt from the pins, no old cache) | replay | measured parts: tool build 6,238 s (2026-11-18), chain 8,423 s, plus the 158 cases; about 26,000 s (7.2 hours) as a sum |
| Independent replay (another machine, another person or agent) | replay | not on this machine |

Nothing of this was started. The directive forbids a multi-hour HOL
build in this gate.

## 10. Files

- `scripts/exit_m1_conformance.py`: the EXIT script (cases
  `conformance`, `record-controls`, `core-controls`, `m1-audit`,
  `evidence`).
- `tests/m1-conformance/driver.cjs`: calls the compiled Dafny code.
- `tests/m1-conformance/recorded-m1-cases.json`: the 22 HOL-written
  fixtures and 6 malformed inputs.
- `tests/m1-conformance/fixtures/`: 16 wrong refund decisions.
- `proposals/forge2-m1-conformance/artifacts/refund-arm64-macho`: the
  M1 executable.
- `proposals/forge2-m1-conformance/run_regression.py`,
  `run_removed_checks.py`: one-off runners.
- `proposals/forge2-m1-conformance/records/`: `evidence.json` (the
  bundle), `regression.json`, `removed-check-copies.json`,
  `links-final.json`.
- [REVIEW.md](REVIEW.md): the one fresh-context review and what was
  done with each finding.

# Wave Gate 1: the one fresh-context review and its disposition

One review, by an agent with a fresh context, of the new executable
code: `scripts/exit_m1_conformance.py`, `tests/m1-conformance/driver.cjs`,
the 16 fixtures and `recorded-m1-cases.json`. The reviewer got the
code and the claim, not my results. Date: 2026-11-19 (UTC). 23 tool
calls, about 12 minutes.

The reviewer did not start the EXIT script. It loaded the script in
memory, used the saved records of the evidence run of that time
(attempt 1, bundle `83afb7f4…`), and compiled four wrong cores of its
own. Section 3 is its text. Section 1 and 2 are mine.

## 1. Result in one table

| Class | Count | Findings |
| --- | --- | --- |
| FAIL-OPEN on the present inputs | 0 | — |
| HIGH | 0 | — |
| MEDIUM | 3 | R1 (a pass was possible with an empty fixture file: conditional fail-open), R2 (three wrong checker cores passed), R3 (14 sub-conditions of checks had no planted fault) |
| LOW | 6 | R4 to R9 |

Two of my statements were false or too strong before the review:
"each planted record fault is found by its own check" hid that many
sub-conditions had no fault (R3), and a code comment said that no wire
change gives another typed value (R5: four do).

## 2. Disposition (repairs in one pass; NOT reviewed again)

| Finding | Class | What I did | Checked by |
| --- | --- | --- | --- |
| R1 | MEDIUM | REPAIRED. The SHA-256 of the fixture file is pinned in the script. The counts 22 and 6 are required. Every named group must hold an accepted and a rejected vector. Every one of the 18 checks must have been evaluated at least once. The conjunct that could not fail is deleted | nine "empty side" controls, one control per check for "never evaluated", one control for a changed fixture file |
| R2 | MEDIUM | REPAIRED. Five more tampered transitions: post-state `remaining + 1`, `original − 1`; intent `amount − 1`; charge id and request id without their last character. The three wrong cores of the reviewer are now fixtures (`CorePostOriginalAtMost`, `CoreIntentAmountAtMost`, `CoreIntentIdPrefix`); each must be reported by `F-TAMPER` | `--case core-controls`: 25 of 25 reported |
| R3 | MEDIUM | REPAIRED IN PART. 18 more planted faults, one per sub-condition that the reviewer named, and a new check `A-CALLS` for the list of `Assess` calls. NOT repaired: the intent-count argument of the two render functions has no fault of its own (the reviewer notes that `A-PLAN` and `F-BIND` hold the same condition) | `--case record-controls`: 57 of 57 |
| R4 | LOW | REPAIRED. Refused tampered transitions are counted for authorized vectors only. Controls for: no rejected vector, no non-candidate vector, no token from the issuer, no tampered transition of an authorized vector | the same case |
| R5 | LOW | REPAIRED. The comment states the four changes that give a rejected value |
| R6 | LOW | REPAIRED. A third wire base with `enabled = False` and six more changes of the flag (`false`, `FALSE`, `0`, `Falsee`, `""`, `yes`). 192 wire inputs now | `--case conformance` |
| R7 | LOW | REPAIRED. The docstring says which inputs go to M1 only. Claim X3 says that the signature is not verified. The record field is named `build_command_without_the_output_path`. Each of the 16 Dafny rejections must show a postcondition error, and the TRUE decision in the same folder layout must exit 0 | `--case core-controls` |
| R8 | LOW | STATED. The limit of 20,000 code points is in `ASSUMPTIONS` and in the report. Not removed: the limit is in the Dafny JavaScript runtime |
| R9 | LOW | REPAIRED IN PART. The issuer's stderr goes to a file. `A-CALLS` checks the number and the names of the `Assess` calls. NOT repaired: the digest of the executable copy is checked before the first run and after the last run, not before each run. STATED: `tsx` and .NET write caches outside `build/` (system temp folder, home folder) |

Left open after this pass: the repairs had no second review (the
directive allows one); a single sub-condition can still lack a fault
that I did not think of; the copies with one check removed take out a
whole check, not one sub-condition.

## 3. The review text (verbatim)

Review of `scripts/exit_m1_conformance.py`, `tests/m1-conformance/driver.cjs`, the 16 fixtures and `recorded-m1-cases.json`.

Result: I found no fail-open path on the present inputs. One conditional vacuity defect (R1), confirmed corpus gaps on the `Check` side (R2), 14 uncontrolled sub-conditions (R3), and several overstated texts.

Method: I did not start the script. I loaded its source in memory (no copy in the repository) and reused the saved records of `build/m1-conformance/evidence/attempt-0001/run-2/` (the finished evidence run, 0 findings, tallies reproduced). I compiled four wrong cores of my own with the pinned Dafny (`--no-verify`) and ran them through `driver.cjs`. My experiment files are in the session scratch folder (`review/`: `harness.py`, `mutate.py`, `tree-K1`, `tree-K2`, `tree-K3`, `tree-A1`). I removed my build folder. No file is left in the repository.

### Findings

**R1 — MEDIUM (conditional fail-open, vacuity) — CONFIRMED at function level — `summary` lines 673-676, `compare` lines 619-630, `CLAIMS` X4/X5**
The vacuity requirement does not cover W-RULE, R-STDIN, R-RENDER, R-STDOUT, R-MALFORMED or the presence of any group except `boundary`. The conjunct `all(group['vectors'] > 0 ...)` cannot fail: a group exists only after a vector made it. The script pins the executable digest but not the digest or the counts of `recorded-m1-cases.json`. If that file has `"typed": []` and `"malformed": []`, claim X5 ("22 fixtures", "6 observations") is reported `passed` with zero checks.
Reproduction: with the saved state, `s2 = dict(s, typed=[boundary vectors only], wire=[], recorded=dict(recorded, typed=[], malformed=[]))`. `compare(s2)` gives 0 findings; the tally has no W-RULE and no R-* entry; `summary(s2)` passes.
Repair: require `len(recorded['typed']) == 22`, `len(recorded['malformed']) == 6`, and a fixed minimum for every `tally` entry and every named group (or pin the SHA-256 of the recorded file). Delete the conjunct that cannot fail.

**R2 — MEDIUM (corpus weakness, X2) — CONFIRMED — `finality_of` lines 402-413**
Each tampered transition changes a value in one direction only (`+1`, append `x`). Three wrong `RefundFinality.Check` cores pass with 0 findings. Each replaces one conjunct of the `if` in `impl/RefundFinality.dfy`:
- K1: `t.post == pre.(remaining := ...)` becomes `t.post.chargeId == pre.chargeId && t.post.refundEnabled == pre.refundEnabled && t.post.remaining == pre.remaining - decision.amount && t.post.original <= pre.original`.
- K2: `t.intent == assessed[0]` becomes the same ids and reason with `t.intent.amount <= assessed[0].amount`.
- K3: `t.intent == assessed[0]` becomes `t.intent.chargeId <= assessed[0].chargeId && t.intent.requestId <= assessed[0].requestId` (prefix) with the same reason and amount.
Reproduction: build each tree with `dafny build <tree>/impl/RefundFinality.dfy --target js --output <out>/model --no-verify`, append the footer, run `driver.cjs` on `core-vectors.json`, call `compare`. Result for K1, K2, K3: 0 findings.
Repair: add the tampers `post-original-minus-one`, `post-one-more`, `intent-amount-minus-one`, `intent-charge-truncated`, `intent-request-truncated` (drop the last code point; keep the existing filter that removes a tamper equal to the honest transition).

**R3 — MEDIUM (controls) — CONFIRMED by mutation — `compare` lines 592-630, `planted_faults`**
I deleted each sub-condition of `compare` in turn and ran all 26 planted faults and all 22 wrong cores. These deletions survive both control sets:
- A-PLAN: `len == 1`, plan amount equal to decision amount, plan reason equal to decision reason, `plan == []` on rejection (only the empty-plan case is controlled).
- F-VERDICT: `labels_fit`.
- F-POST: `original`, `chargeId`, `refundEnabled` (only `remaining` is controlled; no wrong core reports F-POST at all).
- F-BIND: `requestId`, `plan == [intent]`.
- I-TOKEN: post `remaining`, `requestId`.
- W-RULE: `timed_out`. R-STDOUT: `exit == 0`. R-MALFORMED: exit.
- The count argument of `render_assess` and `render_intent` (redundant with A-PLAN and F-BIND, so each can be deleted alone).
Claim K1 says "each planted record fault is found by its own check". That is true, but the reverse (each check condition has a fault) is false.
Repair: add one planted fault per sub-condition (for example token `post.original + 1`, token `requestId` changed, assess plan amount changed with decision amount unchanged, wire record `timed_out=True`, fixture record `exit=1`).

**R4 — LOW (control vacuity) — CONFIRMED by reading — `record_controls` lines 817-826**
The vacuity control removes accepted vectors only. No control exists for `rejected > 0`, `non_candidate_vectors > 0`, `refused_tampered > 0` or the issuer token count. `refused_tampered > 0` is satisfied by rejected vectors alone (all their transitions are refused), so it does not show that a tamper of an authorized vector was refused.
Repair: count refused tampers of authorized vectors only; add one control per conjunct.

**R5 — LOW (false comment) — CONFIRMED — lines 337-339**
The comment says no wire change gives another typed value to a field that the parser can read. Four changes do: `amount-minus-sign` (`-40`; `mlint fromString` accepts `-`), `amount-tilde` (`~40`), `reason-nul-suffix`, `reason-escape-n`. The saved M1 records show `REJECTED` for all four on `W-base-accept`. They pass W-RULE only because `REJECTED` is always permitted.
Repair: correct the comment, or move these four to typed vectors.

**R6 — LOW (corpus weakness, X4) — PLAUSIBLE — `corpus` lines 340-341**
Both wire bases have all three flags `True`. A lenient parser that reads an unknown flag atom as `True` gives the base result, which W-RULE permits. The present executable does not do this (`true`, `TRUE`, `1` give no output). Missing input: a base with `enabled=False` and amount 40, with the flag atom changed to `false`, `FALSE`, `0`, `Truee`.

**R7 — LOW (overstated texts) — CONFIRMED by reading**
- Module docstring line 8: "gives every vector to both stacks". The 116 wire inputs and the 28 `R-` inputs go to M1 only.
- X3 "signs a token": the script reads `ok` and the body. It never verifies the Ed25519 signature or reads the public key.
- `true_core` line 703: `build_argv` is a fixed text, not the executed argv. It omits `--output <path>` and the absolute Dafny path (see `operations.json`).
- K1 "The pinned Dafny does not prove any of the 16 wrong decisions": the script checks exit code 4 only. It does not check which postcondition failed, and it runs no positive control (the true `Refund.dfy` in the same tree layout with exit 0). I read the 16 saved outputs: each shows 3 verified and 1 or 2 postcondition errors, so the statement is true today.

**R8 — LOW (corpus limit, stated) — CONFIRMED — `HOSTILE_TEXTS`, `driver.cjs` lines 29-31**
No text has more than 20,000 code points. A1: `if Eligible(context, response) && |context.chargeId| <= 65535 && |context.requestId| <= 65535` gives 0 findings. The driver comment states the limit, but `ASSUMPTIONS` does not.
Repair: add the limit to `ASSUMPTIONS`, or build long texts in the driver without the spread call.

**R9 — LOW (robustness and safety) — PLAUSIBLE**
- `run_issuer` line 506: `stderr=subprocess.PIPE` is never read. An issuer that writes more than the pipe buffer to stderr blocks the run (a hang, not a pass). Use `stderr=subprocess.DEVNULL` or a file in the work folder.
- `run_m1`: the digest of the executable copy is checked before the copy and after all runs, not before each run. A replace-and-restore during the runs is not detected. Low practical risk.
- `compare` does not check the number or labels of `row['assess']` (1 for a candidate, 6 otherwise). A driver fault that makes fewer calls passes; an empty list ends with exit 2.
- `tsx` and .NET write caches outside `build/m1-conformance/` (system temp, home). The script itself writes only under the attempt folder.

### Checked and found correct
- Wire transcription: `atom` against `is_safe_char`, `make_str_safe`, `escape_str`, `char_escape_seq`, `char_escaped`; `integer` against `toString` (`~`); `request_bytes` and `response_bytes` against `refund_request_def`, `refund_response_def` and `sexp_to_app_list` (single space, no trailing space).
- `reference_eligible` against `eligible_def` in `forge_refundScript.sml`: equal.
- No self-comparison across stacks: A-BYTES, F-TOKEN, I-TOKEN, R-STDOUT and W-RULE each compare M1 bytes with the other stack. F-BIND `plan == [intent]` is Dafny against Dafny by design.
- Exit paths: exit 0 only after `main` returns; `Failed` gives 1; any other exception gives 2; an empty driver row gives exit 2.
- No stale reads: `Run` and `compile_core` use `mkdir` without `exist_ok`.
- Core identity: the compiled module must equal the Slice 1 record digest; Node and packages are checked by digest.
- Issuer limits: `issuer_text` equals `text()` in `encoding.ts` for this corpus (UTF-16 length, NUL); the money regex holds every authorized value; the too-long line gives one answer, so answers stay in order.
- Assess-side corpus: I tried about 20 wrong decisions by reasoning (strict or loose bounds, `amount <= original`, 32-bit and 64-bit wrap, float comparison, cap at 2^63, flag `||`, reason case and trim, ids equal, whitespace-only id). Each has a vector that differs. All 16 fixtures give A-BYTES.
- Determinism: the bundle holds no absolute path, time or attempt number; the two saved bundles are byte-identical.

### Not checked
- I did not run the four cases end to end myself; I relied on the saved evidence run.
- I did not compare `recorded-m1-cases.json` with the original M1 packets.

# Step B3: the output frame and a fail-closed caller contract (X3, Opus; finite tests on the unmodified executable; no HOL run)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

## X3 (step B3, fail-closed): report

I wrote every file in my scratch folder. I changed no repository file and ran no state-changing git command. I did not run HOL, Dafny or Docker. I ran the unmodified executable (SHA-256 `b8ed5ec2…7bb8`, checked) with the required environment. `git status` now shows `FORGE_MASTER_IDEA.md` and `README.md` as modified. That was not me; another actor changed them.

### 1. Grammar of the present output
It is derived from `refund_render_fields_def`, `refund_response_def`, `refund_fields_def`, `sexp_to_string`, `make_str_safe`, `escape_str`, `char_escape_seq` and `mlint toString`.
```
OUTPUT ::= "" (decode error: Fail, exit 0) | ACCEPT | REJECT     -- one print, no newline
REJECT ::= (refund-result-v1 False 0 "" "" "" 0)                 -- exactly 37 bytes
ACCEPT ::= "(refund-result-v1 True " AMOUNT " " REASON " " ID " " ID " 1)"
AMOUNT ::= "0" | [1-9][0-9]*   (0..9223372036854775807)
REASON ::= duplicate_charge | service_not_delivered | returned_item
ID     ::= BARE (iff every byte is safe: not ( ) " NUL SP TAB LF VT FF CR) | QUOTED
QUOTED ::= '"' ( \t | \n | \\ | \" | any byte except TAB LF \ " )* '"'
```
- Only TAB, LF, `\` and `"` are escaped. CR, NUL, `(`, `)` and bytes from 0x80 up appear raw inside quotes.
- The reader also accepts `\0`, `\r`, `040`, `+40` and quoted numbers. The printer never emits them.
- The ids have no length bound.

### 2. Prefix test (finite test, TESTED-UNPROVED; `run_prefix_test.py`, exit 0)
- **Outputs:** 68 real outputs, 62 authorized and 6 rejections. Every output was byte-equal to the transcribed renderer, with exit 0 and empty stderr.
- **Inputs:** the ids include `)`, `"`, space, `\`, TAB, LF, CR, NUL, UTF-8, trailing digits, `r 7`, and 300 and 2000 bytes. Amounts go up to MAX (19 digits).
- **Prefixes tested:** 8011 strict prefixes.

| Reader | Prefixes accepted | Smallest dangerous prefix |
|---|---|---|
| strict parser | **0** | none |
| program reader, transcribed (`parse` then `refund_response_fields`, rest `[]`) | **0** | none |
| `startswith` (copy of `m1_class`) | 6363 | `(refund-result-v1 True ` (23 bytes) |
| split on spaces | 6301 (111 with a wrong amount) | `(refund-result-v1 True 4` gives amount 4 instead of 40 |
| regex with no end anchor | 58 (26 with wrong values) | for id `r 7`: `…c1 "r 7` binds request id `"r`, count 7 |
| auto-close reader | 62 (correct values) | the full output minus its last `)` |

- **Real binary reader:** I sent every strict prefix of 4 requests to the executable (268 runs). It wrote stdout 0 times. This tests the same compiled `parse` function.
- **Negative controls:** a printer with a trailing `\n`, and a top-level atom. Both break prefix-freeness, and the test detects both.

### 3. Candidate HOL lemma (NOT proved)
`∀x p. isPREFIX p (explode (refund_render_fields x)) ∧ p ≠ explode (refund_render_fields x) ⇒ ISL (parse p)`

This is stronger than the requested form: no strict prefix parses at all.

It needs:
- the existing `parse_sexp_to_string`, which covers only the positive side;
- a new unfolding lemma: the printed `Expr` is `"(" ++ J xs ++ ")"`;
- a new lemma: `read_symbol` on a safe prefix gives rest `[]`;
- a new lemma: `read_string_aux` on a strict prefix of an escaped string is `INL`;
- a new key lemma, by mutual induction like `lex_aux_sexp2tree`: `∀x d ts p. d ≠ 0 ∧ isPREFIX p (explode (sexp_to_string x)) ⇒ ISL (lex_aux d p ts)`.

Negative controls for the proof:
- N1: the same statement for the frame plus `\n` is false.
- N2: the same statement for an atom (`"ab"` ≺ `"abc"`) is false.
- N3: the key lemma without `d ≠ 0` is false.

### 4. Contract steps (`decide`)
The effect is authorized if and only if every step D0–D11 passes. The first failing step decides.
- D0: the field types are exact. The executable SHA-256 is pinned on a private copy, before and after the run.
- D1: no time limit (60 s).
- D2: no signal.
- D3: exit code 0. This is necessary, never sufficient.
- D4: stderr is empty.
- D5: stdout length ≤ the bound for this request (the kernel enforces it with `RLIMIT_FSIZE`).
- D6: stdout is not empty.
- D7: stdout is one strict canonical frame, and `render(parse(x)) == x` byte for byte.
- D8: a `False` frame must be the exact rejection frame. The exact frame gives NOT_AUTHORIZED.
- D9: BindingValid. The echoed charge id, request id, amount and reason equal the sent ones.
- D10: amount in range, reason approved, count = 1.
- D11: stdout equals the one expected ACCEPT byte string for this request.
- D12: any caller exception gives REFUSED.

The four cases the owner named:
- Empty output → D6.
- Truncated output → D7. A real kernel cut ends in a signal → D2.
- Malformed output → D5, D7 or D8.
- Resource exhaustion → D3. A real stop gave exit 1, empty stdout, and stderr `Program exited with nonzero exit code.` The prefix that the theorem allows → D7.

The contract assumes:
- the bytes read from the pipe are the bytes the process wrote;
- the binary is the pinned one (a time-of-check gap remains between the hash and the start);
- the model premises hold;
- the caller code is correct.

It authenticates nothing. Anyone who can write to the pipe can forge a frame. That is why Slice 1 signs its token.

### 5. Control results (TESTED-UNPROVED; `run_fail_closed_controls.py`, real exit code **0**, verdict PASS)
- **Planted results:** 82 process results fed to the decision function, 24 named and 58 strict prefixes of a real 58-byte authorized output. 82 of 82 were not authorized, each refused by its named step. 0 failures.
  - empty stdout → D6
  - frame plus a trailing byte → D5
  - two frames → D5
  - another request id → D9
  - `040` → D5 (the strict parser alone also refuses it)
  - exit 1 with a perfect frame → D3
  - non-empty stderr → D4
  - 1 MiB output → D5
  - the rejection frame → NOT_AUTHORIZED
  - a `False` frame that is not the rejection → D8
- **Real runs:**
  - 4 authorized requests → AUTHORIZED with the right amounts.
  - 3 rejected requests → NOT_AUTHORIZED.
  - Malformed wire: exit 0, 0 bytes → D6.
  - A 6 000 000-byte id: exit 1 → D3.
  - A real cut at 30 bytes: signal 25, stdout `(refund-result-v1 True 40 retu` → D2. The same bytes planted with exit 0 → D7.
  - An executable with another hash → D0, not run.
- **Resource boundary seen:** a 5 368 027-byte charge id works. 5 368 028 bytes gives exit 1. I presume heap exhaustion; I did not confirm it.

### 6. `m1_class`
- H1 is right for a copy of that function. `m1_class(b'(refund-result-v1 True 4')` returns `'AUTHORIZED'`. It reads no exit code, no stderr, no amount and no binding.
- Inside the script it does not fail open. `M-EXIT` and `A-BYTES` (line 626, full byte equality) catch the case.
- What should change: make `AUTHORIZED` require byte equality with the expected frame, plus exit 0 and empty stderr, or rename the function to show it is a label only.
- I did not edit it. The script's SHA-256 (`96179077…`) is recorded in `proposals/forge2-m1-conformance/records/evidence.json` and `records/regression.json`, so a change needs a new bundle and a new run.

### 7. Comparison of the three options
- **S-expression plus this contract:** it can be made canonical and complete at the caller, with prefix-freeness tested but not proved. It gives no authentication, no state binding and no freshness.
- **F2.7 frame:**
  - by its format, one spelling per value, a 315-byte bound and two fixed outputs;
  - a signer checks the length field;
  - authentication comes from a separate signer (A-SIGN, trusted);
  - everything is NOT STARTED.
- **Slice 1 token:**
  - a canonical JSON text with an Ed25519 signature;
  - the sink checks freshness and the pre-state hash in one transaction;
  - `sink.ts` and `minter.ts` are tested, not proved;
  - the F2.0 Dafny model is a model proof under A1–A4, not a proof of `sink.ts`.

### 8. Links for the top-level graph (full table: `FAIL_CLOSED_CONTRACT.md` §10)

| from | to | statement | class | evidence | what would upgrade it |
|---|---|---|---|---|---|
| L1 pinned code bytes (model machine) | stdout of a run | `refund_profile_a_sl_every_machine_run`: Success with the rendered fields, or a resource stop with any prefix | MACHINE-CHECKED | HOL4 kernel, replay M1R-1, `results/round4-m1-replay-20261118/phase2-index.json` | a statement without the resource-stop disjunct needs a resource bound; else L4 plus L6 carry it |
| L2 model machine | real macOS process | none | ASSUMPTION | Q2 and Q5 cover read errors and absent stdin; loader and entry state not approved as far as I found | a proof, or an owner decision |
| L3 bytes the process wrote | bytes the caller read | none | ASSUMPTION | not approved | an owner decision on OS trust |
| L4 output bytes | no strict prefix parses | prefix lemma (§3) | TESTED-UNPROVED | `run_prefix_test.py` parts B and C | the HOL proof with controls N1–N3 |
| L5 full output | fields | `refund_render_fields_roundtrip` | MACHINE-CHECKED | HOL4 kernel, M1R-1 replay | — |
| L6 process result | caller decision (repository) | none | MISSING | H1: no component consumes M1 output | add D0–D12 to the repository, then prove it |
| L6' process result | caller decision (scratch reference) | D0–D12 | TESTED-UNPROVED | `run_fail_closed_controls.py` | a verified caller over a pipe model |
| L7 M1 decision | Slice 1 token | none | MISSING | `minter.ts` lines 3–6 call Dafny `Check`, not M1 | connect M1 or F2.7 output to the signer |
| L8 request | `Check` | Dafny post-conditions | MACHINE-CHECKED | Dafny, `proposals/forge2-slice1-refund-finality/` (I did not re-read that record) | — |
| L9 `Check` result | signed token | `minter.ts` | TESTED-UNPROVED | `tests/refund-finality/suite.ts` | a proof of the issuer |
| L10 token | sink commit | `sink.ts` `commit` checks | TESTED-UNPROVED | `suite.ts` | a refinement proof against the F2.0 model |
| L11 protocol model | invariant | `CommitPreservesInv`, `MintPreservesInv` under A1–A4 | MACHINE-CHECKED | Dafny, `proposals/forge2-pillar2-finality-protocol/records/summary-attempt-0002.json` (a model proof only) | model → `sink.ts` refinement |
| L12 Ed25519 and key secrecy | A1 | none | ASSUMPTION | not approved | an owner decision |
| L13 sink commit | durable state after a crash | SQLite IMMEDIATE transaction | ASSUMPTION | not approved; only a simulated dispatcher crash (`suite.ts` line 525) | a storage contract and a real crash-recovery test |

**FIRST MISSING link: L6.** No repository component turns the M1 process result into a decision. L7 is the next one.

### Files
- `<session scratch folder>/m1b/X3/OUTPUT_FRAME_SPEC.md`
- `<session scratch folder>/m1b/X3/FAIL_CLOSED_CONTRACT.md`
- `<session scratch folder>/m1b/X3/m1_fail_closed.py`
- `<session scratch folder>/m1b/X3/run_fail_closed_controls.py`
- `<session scratch folder>/m1b/X3/run_prefix_test.py`
- `<session scratch folder>/m1b/X3/frame.py` (renderer, transcribed reader, strict and lenient parsers)
- `<session scratch folder>/m1b/X3/prefix_results.json`
- `<session scratch folder>/m1b/X3/controls_results.json`

### What I could not determine
- The HOL lemma is not proved, and I did not run HOL.
- My reader in `frame.py` is a transcription of `parse`, not the HOL definition. Only part C tests the real compiled reader, and only on requests.
- The cause of the exit-1 resource stop (heap?) is not confirmed. I never saw a real exit-0 run with a cut output.
- I did not re-read the Slice 1 Dafny verification record (L8).
- I did not find whether the loader and entry-state premises (L2) have an owner decision.
- The hash-to-exec time-of-check gap in the caller remains.

| step | status | evidence or blocker |
|---|---|---|
| B3 | REPORTED | `OUTPUT_FRAME_SPEC.md`, `FAIL_CLOSED_CONTRACT.md`; `run_prefix_test.py` exit 0 (strict 0 of 8011 prefixes; real binary 0 of 268); `run_fail_closed_controls.py` exit 0 (82 of 82 planted refused, 12 of 12 real runs as expected); first MISSING link L6 |


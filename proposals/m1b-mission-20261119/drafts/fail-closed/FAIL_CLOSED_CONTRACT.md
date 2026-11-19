# FAIL_CLOSED_CONTRACT — caller and sink contract for the present M1 program (worker X3, step B3)

Status: 2026-11-19. A specification plus a reference implementation (`m1_fail_closed.py`) and finite
controls. NOT proved. No repository file was changed.

## 1. Rule

`Authorize(x)` holds exactly when `CompleteFrame(x) ∧ ValidDecision(x) ∧ BindingValid(x)`.
The protected effect is authorized IF AND ONLY IF every step D0–D11 below passes. Every other outcome
forbids the effect. The program's exit code alone is never a decision (it exits 0 with no output on
bad input, finding H1).

## 2. Inputs

- `request_fields`: the nine fields the caller sends (`charge`, `request`, `reason`: bytes;
  `original`, `remaining`, `amount`: int; `enabled`, `opened`, `candidate`: bool).
- `executable_path`: the path of the refund executable.
- The process handle: exit status (code or signal), time-limit flag, stdout bytes, stderr bytes, an
  overflow flag. In the reference code stdout and stderr go to private files with a kernel file-size
  limit (`RLIMIT_FSIZE = bound + 1`), so a flood is cut by the kernel (signal SIGXFSZ).

## 3. Decision procedure (first failing step decides)

| Step | Check | On failure |
|---|---|---|
| D0 | the fields have the exact types; the executable's SHA-256 is `b8ed5ec2…7bb8`; the caller hashes the private copy it runs, before and after the run | REFUSED |
| D1 | the process ended inside the time limit (60 s) | REFUSED |
| D2 | the process was not ended by a signal | REFUSED |
| D3 | exit code = 0 (necessary, never sufficient) | REFUSED |
| D4 | stderr is empty | REFUSED |
| D5 | stdout length ≤ bound = max(len(expected ACCEPT for this request), 37), and no overflow | REFUSED |
| D6 | stdout is not empty (empty = no decision) | REFUSED |
| D7 | stdout is exactly ONE complete canonical frame: strict parser (exact grammar, 7 fields, one space between fields, final `)`, full consumption, canonical integers `0|[1-9][0-9]*`, `True`/`False`, canonical atom spelling) and `render(parse(stdout)) == stdout` byte for byte | REFUSED |
| D8 | if the frame says `False`: it must be exactly `(refund-result-v1 False 0 "" "" "" 0)` | exact → NOT_AUTHORIZED (no effect); other → REFUSED |
| D9 | BindingValid: echoed charge id = sent charge id; echoed request id = sent request id; echoed amount = sent amount; echoed reason = sent reason | REFUSED |
| D10 | amount in 0..MAX_MONEY; reason in the three approved reasons; intent count = 1 | REFUSED |
| D11 | cross-check: stdout = `render(True, amount, reason, charge, request, 1)` computed from the request alone | REFUSED |
| D12 | any exception in the caller at any step | REFUSED |
| — | all of D0–D11 pass and the frame says `True` | AUTHORIZED (amount, reason) |

D11 makes D7–D10 redundant for this program: there is exactly one acceptable authorizing byte string
per request. D7–D10 stay, so that each refusal has its own reason, and so that a change of one check
is caught by another.

## 4. The four cases the owner named

| Case | Example | Refused by |
|---|---|---|
| Empty output | exit 0, stdout `""` (bad input, H1) | D6 (real run: trailing-newline wire → exit 0, 0 bytes → D6) |
| Truncated output | `(refund-result-v1 True 4` | D7 (no strict prefix parses: 0 of 8011 in the prefix test, 58 of 58 planted prefixes refused); a real cut by the file-size limit → D2 (signal 25) |
| Malformed output | `040`, `+40`, a quoted bare atom, two spaces, two frames, a trailing byte, a False frame that is not the rejection | D5 or D7; D8 |
| Resource exhaustion | real run with a 6 000 000-byte charge id: exit 1, stdout empty, stderr `Program exited with nonzero exit code.`; the theorem also allows exit 0 with a prefix | D3 (observed); D7 or D6 (the case the theorem allows) |

## 5. Results of the controls (class: TESTED-UNPROVED)

`run_fail_closed_controls.py`, exit code **0**, `controls_results.json`, verdict PASS.
- 82 planted process results fed to `decide_from_result` (the executable is not run for them):
  24 named controls + 58 strict prefixes of a real authorized output (58 bytes, request id
  `req 0040`). 82 of 82 are not AUTHORIZED, each refused by its named step (the rejection frame gives
  NOT_AUTHORIZED). 0 failures.
- Real runs of the unmodified executable: 4 authorized (base; amount 0; amount MAX with ids `a)"b`
  and `q\1`; ids with TAB and LF) → AUTHORIZED with the right amount; 3 rejections → NOT_AUTHORIZED;
  malformed wire → D6; resource stop (6e6-byte id) → D3; real truncation by `RLIMIT_FSIZE` 30 bytes
  → signal 25, stdout `(refund-result-v1 True 40 retu` → D2; the same 30 bytes planted with exit 0
  → D7; an executable with another SHA-256 → D0 (not run).
- Observed resource boundary (finite): a charge id of 5 368 027 bytes works; 5 368 028 bytes gives
  exit 1 with empty stdout. Cause presumed heap exhaustion at `CML_HEAP_SIZE=256`; not confirmed.

## 6. What the contract ASSUMES

- The bytes the caller reads from the pipe or file are the bytes the process wrote (OS, kernel).
- The executable run is the pinned one: the hash check is on a private copy in a 0700 directory;
  a writer with the caller's rights could still replace it between hash and exec (time-of-check gap).
- The machine model premises of the M1 theorem hold for this process (loader, entry state, FFI);
  read errors (Q2) and absent stdin (Q5) are outside the theorem and give no decision here.
- The caller code (`m1_fail_closed.py`, `frame.py`), Python and the OS are correct. They are trusted.
- One request per process; stdin is closed after the request.

## 7. What it cannot give

- It authenticates nothing. Anyone who can write to the pipe, replace the binary, or run their own
  process in its place can produce a perfect frame. The frame carries no key. That is why Slice 1 has
  an Ed25519 signature on a canonical JSON token and a sink that holds only the public key.
- It gives no freshness and no single use: the same request gives the same frame again. Uniqueness is
  the sink's job (Slice 1: settled request ids, pre-state hash, one SQLite transaction).
- It proves nothing: the steps are code and finite tests.

## 8. The present `m1_class` (task item 4)

`scripts/exit_m1_conformance.py` lines 242-247:
```
def m1_class(stdout):
    if stdout == REJECTED_BYTES: return 'REJECTED'
    if stdout.startswith(AUTHORIZED_PREFIX): return 'AUTHORIZED'      # b'(refund-result-v1 True '
    return 'NO_OUTPUT' if stdout == b'' else 'OTHER'
```
- Finding H1 is RIGHT for a copy of this function. Exact input:
  `m1_class(b'(refund-result-v1 True 4')` → `'AUTHORIZED'`. Also `b'(refund-result-v1 True '`
  (23 bytes, the smallest), `b'(refund-result-v1 True 999 evil'`, and any frame with another request
  id. It reads no exit code, no stderr, no amount and no binding. In the prefix test it accepts 6363 of
  8011 strict prefixes. (Class: TESTED-UNPROVED, `run_prefix_test.py` part B row "startswith".)
- Inside the script it does NOT fail open: `compare` also checks `M-EXIT` (exit 0, no time limit,
  empty stderr) and `A-BYTES` (full stdout byte-equal to an independent rendering), line 626. The
  danger is reuse of the function as a decision.
- What should change: rename it to show it is a label, not a decision, or replace it with the strict
  check: `AUTHORIZED` only if `stdout == response_bytes(True, amount, reason, charge, request, 1)` for
  the sent request, plus exit 0 and empty stderr. The script is inside the conformance evidence bundle
  (its SHA-256 `96179077289b6242…` is recorded in `proposals/forge2-m1-conformance/records/evidence.json`
  and `records/regression.json`), so a change needs a new bundle and a new run. I did not
  edit it.

## 9. Present frame + contract vs F2.7 frame vs signed Slice 1 token (task item 5)

| Property | S-expression + this contract | F2.7 frame (`drafts/F27_ARCHITECTURE.md` §1.3) | Slice 1 signed token |
|---|---|---|---|
| One spelling per value | yes for the printer; the reader is lax (`040`, `+40`, quotes); D7 adds it at the caller | by format: fixed-width `U64`, length bytes | `canon(token) === input` in `sink.ts` |
| Complete frame / cut output | prefix-free by argument; TESTED (0 of 8011); lemma not proved | `U16` length field + signer length check; `f27_prefix_complete` planned, not proved | JSON parse + canonical compare; a cut text fails to parse or to verify |
| Bounded size | bound computed per request (ids unbounded) | max 315 bytes | `MAX_TOKEN_TEXT` |
| Two fixed outputs | yes (ACCEPT for the request, REJECT); D11 | yes (`REJECT\n` or `ACCEPT\n ++ T`) | n/a |
| Exit code / stderr | refused unless 0 and empty; never sufficient | "no claim" on exit code; signer reads bytes only | n/a |
| Authentication | none | signature by a separate signer (A-SIGN, trusted, not proved) | Ed25519 by the issuer; verified by the sink |
| Binding to state | none (sink must do it) | pre-state by value, compared byte for byte | pre-state SHA-256 compared with the store |
| Freshness / single use | none | at the sink | settled request ids in one SQLite transaction |
| What remains unproved | prefix lemma; caller code; real process vs model; no authentication | the whole F2.7 chain is NOT STARTED; signer and sink code | `sink.ts`, `minter.ts`, Node, OpenSSL, SQLite; the F2.0 Dafny model proves the protocol under A1–A4, not `sink.ts` |

## 10. Links for the top-level graph

Target: `Committed(e) ⇒ ApprovedSpec(e) ∧ ValidArtifact(e) ∧ UniqueAuthorization(e)` for the actual
system. Chain in my area: output bytes of the process → caller decision → authorization token → sink
commit → durable state. Classes: MACHINE-CHECKED, ASSUMPTION, TESTED-UNPROVED, MISSING only.

| # | from | to | statement | class | evidence | what would upgrade it |
|---|---|---|---|---|---|---|
| L1 | pinned ARM64 code bytes (model machine) | stdout events of a run | `refund_profile_a_sl_every_machine_run`: `Terminate Success io` with stdout `refund_render_fields (refund_fields …)`, or `Terminate Resource_limit_hit io'` with `io' ≼ io` (any prefix, also none) | MACHINE-CHECKED | HOL4 kernel; replay M1R-1 (`unsure.md` line 15681), `results/round4-m1-replay-20261118/phase2-index.json` (closure includes `forge_refundWireProg`, `forge_refundStdioProg`) | a statement without the resource-stop disjunct needs a resource bound; else L4 + L6 carry it |
| L2 | model machine | real macOS process (loader, entry state, real FFI) | none | ASSUMPTION | M1 premises; Q2 (read errors) and Q5 (absent stdin) approved as exclusions; loader and entry state: not approved as far as I found | a loader/entry-state proof or an owner decision |
| L3 | bytes the process wrote | bytes the caller read | none | ASSUMPTION | not approved | OS trust decision by the owner |
| L4 | `refund_render_fields x` | no strict prefix parses | `refund_render_fields_prefix_free` (OUTPUT_FRAME_SPEC §c) | TESTED-UNPROVED | `run_prefix_test.py` part B (0 of 8011, strict and transcribed reader), part C (0 of 268 real runs) | prove the lemma in HOL with controls N1–N3 |
| L5 | full output bytes | fields `(ok,a,r,c,q,n)` | `refund_render_fields_roundtrip` | MACHINE-CHECKED | HOL4 kernel; same replay record as L1 | — |
| L6 | process result | caller decision (repository) | none | MISSING | finding H1: no component consumes M1 output | add the D0–D12 caller to the repository, then prove it |
| L6' | process result | caller decision (reference in scratch) | D0–D12, §3 | TESTED-UNPROVED | `run_fail_closed_controls.py` (82 planted + 12 real, exit 0) | a verified caller (for example in Dafny or HOL) over a stated pipe model |
| L7 | caller decision on M1 | Slice 1 token (issuer) | none | MISSING | the issuer calls the Dafny core `RefundFinality.Check`, not M1 (`ts/refund-finality/minter.ts` lines 3-6) | decide which program signs; connect M1 or F2.7 output to the signer |
| L8 | request | Slice 1 decision `Check` | Dafny post-conditions of `RefundFinality.Check` (`impl/RefundFinality.dfy`) | MACHINE-CHECKED | Dafny (pinned) verification records of Slice 1 (`proposals/forge2-slice1-refund-finality/`, merged `136ad0bf`); I did not re-run or re-read the record | — (the JS back end and runtime stay trusted) |
| L9 | `Check` result | signed token text | `minter.ts`: canonical JSON + Ed25519 sign | TESTED-UNPROVED | `tests/refund-finality/suite.ts` | proof of the issuer code, or a proved F2.7 signer rule |
| L10 | token text | sink commit | `sink.ts` `commit`: text only, size, shape, canonical, pins, signature, fresh request id, pre-state hash, one IMMEDIATE transaction | TESTED-UNPROVED | `tests/refund-finality/suite.ts` (controls of the sink) | a proof of `sink.ts` against the F2.0 model |
| L11 | protocol model | invariant (one effect per request id, valid tag) | `CommitPreservesInv`, `MintPreservesInv` in `FinalityProtocol.dfy` under A1–A4 | MACHINE-CHECKED | Dafny; `proposals/forge2-pillar2-finality-protocol/records/summary-attempt-0002.json`; a MODEL proof, not a proof of `sink.ts` | refinement proof model → `sink.ts` |
| L12 | Ed25519 / key secrecy | A1 ideal MAC | none | ASSUMPTION | not approved (A1 is a model premise in `DESIGN.md` line 42) | owner decision |
| L13 | sink commit | durable state after a crash | SQLite IMMEDIATE transaction is atomic and durable | ASSUMPTION | not approved; `sink.ts` header lists SQLite as trusted; suite line 525 simulates a dispatcher crash, not a real one | a precise storage contract + a real crash-recovery test |

FIRST MISSING link: **L6** — no component in the repository turns the M1 process result into a
decision. The reference caller here (L6') is only TESTED-UNPROVED and is outside the repository.
The next MISSING link is L7 (M1 output is not connected to any token issuer).

## 11. Addendum of 2026-11-19T06:35Z: the exit status, and independent authorization (owner text 15)

Checked against the requirements of owner text 15, item 4.

| Requirement | Where the contract meets it | Evidence |
| --- | --- | --- |
| bounded output | D5, with a kernel file-size limit | controls (finite test) |
| complete, exactly framed, strictly parsed | D6, D7, D11 | 0 of 8,011 strict prefixes accepted (finite test); the HOL prefix lemma is a draft |
| appropriate process completion | D1 (time), D2 (signal), D3 (status), D4 (stderr) | controls |
| never the exit status alone | D3 is necessary, never sufficient | `run_exit_status_controls.py`: 18 rows as expected; a caller that authorizes on status 0 alone makes it fail (exit 1) |
| independent request and state authorization | NOT in D0 to D12: added as D13 below | not implemented; no code |

The exit-status finding (report D4): the real exit routine tests the low
32 bits of x0 and the status is the low 8 bits; the model tests 64 bits.
A model resource stop with x0 = 2^32 would show as status 0 with an
empty stderr; with x0 = 256 as status 0 with the stderr line. Whether
such a value of x0 is REACHABLE is not known: no theorem says yes or no.
The contract does not depend on the answer: with status 0 and an empty
stderr it still refuses every strict prefix (D6, D7) and accepts only
the one expected frame (D11). A non-zero status with the complete
output is refused at D3: that refuses a correct result, which is safe.

D13 (new, a requirement, not code). `AUTHORIZED` from D0 to D12 is NOT
an authorization of an effect. The M1 program has no state: `remaining`
is an input that the caller supplies. An effect needs, as today, the
existing chain UNCHANGED: `RefundFinality.Check` on the request and the
stored pre-state, the issuer's signed token, and the sink's own checks
(signature, pinned ids, pre-state hash, fresh request id, one
transaction). If the M1 program is connected at all, its verdict is one
more necessary condition before the issuer signs, computed on the SAME
field values that `Check` receives; it never replaces `Check`, the
token or the sink. No such connection exists in the repository (graph
link X16: MISSING).

An honest limit, from the same report: D11 compares the output with a
frame that the caller computes from the request alone. For safety the
caller then does not need the executable; the executable adds an
independent second computation of the decision, not authority.

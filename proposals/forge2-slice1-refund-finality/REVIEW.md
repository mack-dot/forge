# Slice 1 — the one fresh-context adversarial review of the unproved code

Date: 2026-11-18. One background agent with no context of the build
session. It could read the repository and run probes in a scratch
folder. It changed no repository file. Its target was the first
complete version of `ts/refund-finality/*.ts` and
`tests/refund-finality/suite.ts` (97 suite rows at that time).

Section 1 is the reviewer's final text, saved by the build agent. Two
path prefixes are replaced: the scratch folder is `<scratch>/`, and
paths inside the repository are relative. Nothing else is changed.
Section 2 is what the build agent did with each finding. No second
review ran: the owner's rule allows one.

A review that finds nothing more is not a proof. The line numbers in
section 1 are those of the reviewed version, not of the present files.

## 1. The reviewer's report (verbatim, paths replaced)

```text
ADVERSARIAL REVIEW, Slice 1 unproved code (encoding.ts, minter.ts, sink.ts, dispatcher.ts, suite.ts). I changed no repository file. All probes and outputs are under <scratch>/review/ (logs in its out/ folder). Pinned Node v24.3.0. Note: unsure.md and proposals/forge2-slice1-refund-finality/REPORT.md changed at 11:04-11:05 during my run. I did not write them. The five target .ts files and suite.ts have their earlier modification times.

Summary: for an attacker OUTSIDE the sink process I found no unauthorized state change, settled row or outbox row. The sink's three checks held in every probe. The problems are: one in-process fail-open, duplicate outbound emission by overlapping dispatcher runs, two ways for the attacker to block the dispatcher for good, and weak suite rows.

## FINDINGS

### F1. FAIL-OPEN (in-process only; by the letter of the attacker model)
File: ts/refund-finality/sink.ts lines 73 and 68.
Steps: build a token body that the issuer never saw (post-state remaining "0", intent amount "999999", reason "goodwill", charge id "ch_other_account"). Sign it with the attacker's own Ed25519 key. Hand `Sink.commit` an object whose `signature` property is an accessor. The accessor runs `require("node:crypto").verify = () => true` and then returns the signature text.
Observed (run, probe p5b_sidefx.ts and p5c_sidefx.ts): `{"status":"committed"}`. Stored state changed from remaining "1000" to "0". 1 settled row, 1 outbox row. With `verify` left replaced, a dispatcher in the same process emitted the forged intent and `audit()` returned no problem. With `verify` restored, the dispatcher refused the row ("signature does not verify") and the audit reported "row 1: signature".
Why: line 73 runs caller code (`canon(input)`) before the signature check. Line 68 looks up `verify` at call time. The copy-first design stops a value that changes between reads; that claim in the header holds. It does not stop an accessor that changes the process. Caveat: this needs an attacker-written function that runs inside the sink process. Such an attacker can also reach `sink["db"]` (TypeScript `private` only). The suite's own "hostile object" rows use accessors, so the project treats them as in scope. Either narrow the header claim and the attacker model ("in-process callers that can run code are trusted"), or count this as open.

### F2. HIGH. Two overlapping dispatcher runs send each refund more than once
File: ts/refund-finality/dispatcher.ts line 64 (ledger read once per run), lines 80-84 (append, then effect), lines 33-45. No lock on the ledger.
Steps A (p6_disp_race.ts): 3 committed tokens, then 4 dispatcher processes on the same database and ledger with a common start time.
Observed A (run, 5 of 5 trials): 12 outbound effects for 3 outbox rows; each request emitted 4 times. Every later run throws "dispatcher ledger is not one chain" (12 ledger lines).
Steps B (p6b_overlap.ts): 8 committed refunds of 100 on a charge of 1000. The effect callback takes 300 ms. A second dispatcher run starts 1.2 s after the first. No start barrier.
Observed B (run): 12 outbound effects; rq_4 to rq_7 emitted twice. 1200 sent for a charge of 1000.
Why: the header says "at most once". That holds only for one dispatcher run at a time. The header does not state that limit and the code does not enforce it. Under the stated limits the attacker cannot start a dispatcher (the ledger is trusted-side), so the trigger is two trusted runs that overlap (scheduler overlap, restart, two replicas). NOT RUN: an attacker can lengthen each run at no cost, because every amount-0 token adds an outbox row.

### F3. MEDIUM. One valid token with U+0000 in the request id blocks the dispatcher for good
Files: ts/refund-finality/encoding.ts line 43 (`text` allows U+0000); sink.ts lines 98-99 (raw request id in TEXT columns); dispatcher.ts lines 68-69 and 77; sink.ts line 122.
Cause (run, p13_sqlite_roundtrip.ts): node:sqlite stores the full text but reads it back cut at the first NUL. Of 63,493 code points tried, only U+0000 does not round-trip.
Steps (p12_nul_wedge.ts): scenario A: commit request id "rq\u0000A" (amount 100), then two honest requests. Scenario B: commit "rq", dispatch, commit "rq\u0000A", then two honest requests.
Observed (run): the issuer signs and the sink commits every token. A: dispatcher emits 0; "no settled row" for the NUL row; "token does not continue the dispatched chain" for every later row. Stored remaining 800, outbound effects 0. B: the NUL row is counted as "already dispatched" (alreadyDispatched 2, refused 0); every later row is refused. Stored remaining 700, outbound effects 1. `Sink.audit()` reports "row N: request id" on a database written only through the sink.
Why: not an unauthorized effect. It is a permanent split between the stored state and the outbound effects, caused by an attacker who controls only the proposer. In B the lost row is not reported as refused. The sink's own freshness check is not affected: "rq\u0000A", "rq\u0000B", "rq" stay distinct inside SQLite.

### F4. MEDIUM. One message ends the issuer process; the key is lost
File: ts/refund-finality/minter.ts line 76 (`id` taken with no limit), lines 88 and 90 (`JSON.stringify` of `id`; line 90 is inside the catch block).
Steps (p3_linesep.ts, p16_rotation.ts): send `{"id":[[[ ... ]]],"pre":1,"transition":2}` with 10,000 nested brackets (about 20 kB, under the 65,536 limit).
Observed (run): "RangeError: Maximum call stack size exceeded" at minter.ts:90, uncaught; issuer exit code 1. Depth 5,000 is answered; depth 10,000 kills it.
Consequence (run, p16_rotation.ts): one token was committed and not yet dispatched. After a new issuer start and re-pin of the new key: the sink commits a new token; the dispatcher refuses the old row ("signature does not verify") and the new row ("token does not continue the dispatched chain"); the audit reports "row 1: signature". One pinned key gives no path over a key change, and the attacker can force the change at will.

### F5. LOW. U+2028 and U+2029 break the line protocol of the issuer
Files: encoding.ts line 43; minter.ts lines 88 and 90 (JSON.stringify does not escape them); proposer.ts lines 34-35 and 44.
Observed (run, p3_linesep.ts, p2_nul.ts): Node readline splits on U+2028. An issuer answer that holds U+2028 (in a reflected `id` or in a signed charge id) arrives as 3 lines; none is JSON. A request with a raw U+2028 is split at the issuer: `MinterClient.mint` never resolves. I could not inject a valid fake line (quotes stay escaped), so no fake `ready` or `ok` message. Availability of the untrusted side only.

### F6. LOW. A token is not bound to one database
Files: encoding.ts lines 14-17 (no sink or database identity in TokenBody); sink.ts line 93.
Observed (run, p9_misc.ts): two databases that hold the same charge state both answer "committed" for one token; 2 outbound effects. The accepted limit says one database holds one charge. It does not say one charge is in one database (replica, restored copy, re-init).

### F7. LOW. A missing ledger file is read as an empty ledger
File: dispatcher.ts line 36.
Observed (run, p15_disp_mutants.ts): ledger removed between two runs: the same effect is sent again (1, then 2). This is next to the accepted limit (trusted-side file). I report it because a wrong path or a lost file re-sends everything and nothing marks a first run.

### F8. LOW. `Sink.init` has no copy-first step
File: sink.ts lines 38-40 (`isState(state)`, then `canon(state)` on the caller's object).
Observed (run, p9_misc.ts): an accessor that changes after the first read stores `"remaining":"not-money-9999..."`. `init` is a trusted call; the result is a dead charge, not a token effect.

## PROBES THAT FOUND NOTHING
- p5_hostile.ts, 32 hostile values to `Sink.commit`: proxies (get, ownKeys, getPrototypeOf traps), arrays with a hostile `map` that injects JSON text, `toJSON`, String and Boolean objects, inherited fields, null prototype, own `__proto__` keys, duplicate JSON keys, numbers, bigint, leading zero, trailing newline, full-width digits, upper-case hash, base64url and Buffer signatures, NFD request id, re-entrant commit from an accessor, cyclic object, accessor that throws null. Every result: 0 effects, or exactly the signed token.
- p7_sink_race.ts: 8 processes, 12 tokens for one pre-state, common start time, 6 trials: exactly 1 commit each time; audit clean.
- p11_busy.ts: a reader holds the lock past the busy timeout: "rejected: transaction failed: database is locked" after 32 s, 0 effects; the same token commits later.
- p10_issuer_fuzz.ts: 6,000 messages against my own oracle (money edges to 19 digits, 2^53 neighbours, NUL, astral and combining characters, look-alike reasons, mutated post-states and intents): 1,845 signed, 0 disagreements, every signed body exact.
- p9_misc.ts: Ed25519 signature with S + L: rejected. Commit on a closed sink: rejected, 0 effects. Second `init`: no change.
- p2_nul.ts: request ids "é" NFC and NFD, emoji, BOM, "__proto__", "constructor", " rq", "rq ", "1", "01", "1.0", "1e0": all distinct in the sink; no coercion, no collision.
- p3_linesep.ts: no valid fake line can be injected into the issuer's output.
- Reading only: no path where the issuer signs a body that does not come from the core's result; no half-written effect in the sink.

## SUITE ROWS THAT CANNOT FAIL OR DO NOT TEST WHAT THEY SAY
Method: 47 mutants of copies of the four files, suite run in a scratch tree (mutate.py; out/mutants.log). 29 killed, 18 survived. Baseline: 97 rows, exit 0.
1. "b | race: 6 valid tokens ..." and "c | race: one valid token ...": both PASS on a sink with NO transaction (mutant S1), 9 of 9 suite runs. The 6 processes do not overlap; start-up time is far longer than a commit. My start-barrier harness against the same mutant: 3 of 3 trials bad (3, 3 and 5 commits for one pre-state). Mutants "deferred BEGIN" and "checks and writes in two transactions" also survive.
2. The `uncheckedSinkEffects` column and the count `rejection_attempts_with_an_effect_on_the_unchecked_sink` (33): `UncheckedSink` returns at least 1 for any input with an object `post` and `intent`. It measures the test input, not the sink.
3. "tampered: another spec lock hash" and "tampered: another checker id": the token also has a bad signature. The rows show only the order of checks through the reason text. No row has a valid signature with a non-pinned id.
4. Dispatcher: no row exercises check 4 (chain), the request id equality of check 3, the canonical text and pinned ids of check 1, or the ledger validation. Mutants D1, D2, D3, D4, D9 survive. D1 and D4 are load-bearing (run, p15_disp_mutants.ts): the real dispatcher refuses a raw row with a stale signed token and a raw copy of a committed row; the mutants emit both.
5. No row for: two dispatcher runs at once (F2), NUL or U+2028 in an id (F3, F5), a message over the length limit (mutant M3 survives), a key change (F4).
6. "hostile object ... n = 1 to 8": all eight n give "signed values committed" on the real sink, because it reads once. The rows do kill the no-copy mutant. They cover one accessor on one field and no side effect (F1).
7. Survivors that I judge equivalent or untestable: S8 (missing-state check; the hash of `undefined` throws and is caught), E6, E7, E10, E11, E12, M4 (conversion checks), D10 (fsync), M9 (post-state and intent taken from the caller's message; equal to the core result by P4, so no row can tell the difference).

## NOT CHECKED
- Durability at power loss: ledger directory entry after first creation, SQLite sync settings.
- minter.ts line 87 stores one map entry per pre-state hash also with single-use off (unbounded memory). Not run.
- A very long line with no newline to the issuer (readline buffers before the length check). Not run.
- dispatcher.ts line 65 sets no busy timeout; a run can throw while the sink commits. Read only, not run.
- `single-use on` beyond the two suite rows. The Dafny proof. scripts/exit_slice1.py beyond its header.
- An accessor that harms without replacing a function: none found.

## COUNTS
FAIL-OPEN: 1 (F1, in-process only). HIGH: 1 (F2). MEDIUM: 2 (F3, F4). LOW: 4 (F5, F6, F7, F8).
```

## 2. What the build agent did with each finding

Rule (owner text 7 in `OWNER_TEXTS.md`): repair only confirmed HIGH or
MEDIUM defects, in one pass; no code change for LOW items. The repairs
are in the working tree. They were NOT reviewed by a second reviewer.

| Finding | Action | Control that now fails without the repair |
| --- | --- | --- |
| F1 fail-open in the sink process | REPAIRED by a narrower interface: `Sink.commit` takes text only and reads no property of a caller's object. Code that runs inside the sink process by another way stays in the trusted base; the header and the report say so. | rows "a valid token handed over as an object" and "hostile object: a proxy ... counts every operation" (0 operations) |
| F2 overlapping dispatcher runs | REPAIRED: exclusive lock file for one run. A dead process leaves the lock; a person must remove it. | row "overlap: 4 dispatcher processes ..." |
| F3 U+0000 | REPAIRED: the shape check refuses U+0000 in every text field. | three rows with U+0000 |
| F4 issuer ended by one message | REPAIRED for the confirmed message: the id must be a small integer. The pre-state map is filled only with `single-use on`. NOT repaired: a key change has no path (limit); other ways to exhaust the issuer process were not searched. | row "a message whose id is 10,000 nested arrays" |
| F5, F6, F7, F8 (LOW) | NO code change. Stated as limits in `REPORT.md`. | — |
| Suite 1: race rows could not fail | REPAIRED: all processes of a race wait for one common start time; a late process fails the row. | against a sink with no transaction the race rows fail (3 of 3 runs) |
| Suite 2: `uncheckedSinkEffects` | Renamed in the counts and described as a property of the input. No new claim rests on it. | — |
| Suite 3: ids with a valid signature | ADDED two rows: a second issuer with the trusted key and another spec lock, or another checker id. | both fail on a sink with no id check |
| Suite 4: dispatcher checks | ADDED rows for the chain check, the request id check and the ledger check. | each fails when its check is removed |
| Suite 5: missing rows | ADDED for F2, F3, F4. NOT added: U+2028, a message over the length limit, a key change. | — |
| Suite 6: hostile object rows | REPLACED by the two rows of F1. | — |
| "NOT CHECKED" list | NOT done: durability at power loss; a very long line with no newline; the busy timeout of the dispatcher's read connection; more of `single-use on`. | — |

Found by the build agent while it checked the repairs: the suite could
end with exit 0 without a report when the issuer process died (the last
pending work disappeared). Now the exit code is 2 until the last line
of the suite, and a dead issuer answers every waiting request with a
refusal.

Removed-check copies (one-off, in a scratch folder; record
`records/removed-check-copies.json`): a sink with no transaction; a
dispatcher with no lock; a sink with no id check; a dispatcher with no
chain check; with no request id check; a sink that copies objects; an
issuer that sends any id back; an encoding that allows U+0000. The
suite ended with a non-zero exit for each of the eight.

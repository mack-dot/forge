# Slice 1 — proof-carrying finality on the refund boundary (master idea items F2.1, F2.2, F2.3)

Date: 2026-11-18. Branch `slice1/refund-finality` on `main` `f6329211`.
No protected file changed. `end_to_end=false`. CURRENT is none. This is
not a stage. Nothing here is gate evidence: no policy lists these claims
and no gate obligation lists these files.

Task text: owner text 6 in `proposals/round4-20261117/OWNER_CLOSEOUT_TEXTS.md`
on branch `backup/forge-local-2026-11-11`. The file that the owner named
for the task held only a shell command; the owner approved the plan made
from text 6 with the words "yes go ahead" (`unsure.md` U443). The
closeout rule is text 7 in [OWNER_TEXTS.md](OWNER_TEXTS.md). The
session's permission system declined a first push (`unsure.md` U446).
On text 8 the commit `9af026df` was pushed and pull request 45 was
opened (`unsure.md` U447). On text 9 one last pass repaired the two
findings of the repair check; that pass had no review (`unsure.md`
U448). This report describes the state after the last pass. Pull
request 45 is NOT merged.

## 1. The three parts

| Part | File | Trust |
| --- | --- | --- |
| Proposer: computes a candidate transition | `ts/refund-finality/proposer.ts` | untrusted; needs no proof |
| Checker core: `Check(pre, preStateHash, candidate)` returns `Refuse` or the token to sign | `impl/RefundFinality.dfy` | PROVED at source level (section 2) |
| Claim text for the core | `tests/refund-finality/Bindings.dfy` | NOT approved intent (section 6) |
| Token issuer: own process, Ed25519 private key in memory, calls the compiled core, signs its result | `ts/refund-finality/minter.ts`, `encoding.ts` | not proved; tested |
| Sink: store of one charge and outbox; one SQLite transaction | `ts/refund-finality/sink.ts` | not proved; tested |
| Dispatcher: outbox to the outside, at most once, one run at a time | `ts/refund-finality/dispatcher.ts` | not proved; tested |

A token body is: domain text, refund spec lock hash, checker id,
`preStateSha256`, `requestId`, post-state, intent. The issuer signs the
canonical text of the whole body. The sink takes the canonical JSON text
of a token and nothing else. It makes an effect if and only if (1) the
signature verifies for the body with the pinned public key and ids,
(2) the hash of the stored state equals `preStateSha256`, and
(3) `requestId` is not settled. Checks 2 and 3 and the three writes
(state, settled row, one outbox row) are one synchronous
`BEGIN IMMEDIATE` transaction. The sink has no refund rule: it does not
look at amounts or reasons.

The core calls `Refund.Assess` of `impl/Refund.dfy`. That file is
byte-equal to `main`. The decision is not written again in TypeScript.
The proposer does compute a post-state; that code has no authority.

## 2. What is proved, and what is not

| Part | Status |
| --- | --- |
| P1 safety: a token only for a transition that the approved relation `R.Eligible` allows, with post-state = pre-state with `remaining` minus the amount, and the caller-bound intent | PROVED (`source_proof`), pinned Dafny, gate options |
| P2 exact acceptance: every such transition gets a token; `Check` has no precondition | PROVED |
| P3 no intent on refusal; exactly the checked intent on issue | PROVED |
| P4 binding: the token holds exactly the given hash text, the request id, the checked post-state and intent | PROVED |
| No print effect in `Check` | Dafny accepts the core with `--track-print-effects` and callers without `{:print}`; two printing cores are rejected (exit 2) |
| `Refund.Assess` satisfies R1–R5 | refund gate `gate/refund.py --tier critical` exit 0 in the same run |
| The hash in the token is the hash of the pre-state | NOT proved. The issuer glue computes SHA-256 of the canonical text and hands it to the core |
| `dafny build --target js`, the Dafny JavaScript runtime, `bignumber.js` | NOT proved |
| Issuer glue, encoding, sink, dispatcher, SQLite, Node, OpenSSL, process isolation, key secrecy | NOT proved (finite tests, section 4) |

The claims P1 to P4 are written in `Bindings.dfy` with the approved
predicates of `spec/refund/RefundSpec.dfy` and explicit equalities. They
do not use a predicate of the core file.

Relation to the protocol model of item F2.0
(`proposals/forge2-pillar2-finality-protocol/DESIGN.md`): P1 is the
model's assumption A2 (sound minter), now proved for the Dafny SOURCE of
this core, not for the program that runs. A1 (signature cannot be
forged), A3 (atomic commit) and A4 (hash comparison is faithful) stay
assumptions. The controls of section 4 test them on a finite set.

## 3. Checker core: actual exits

Command: `python3 scripts/exit_slice1.py --case core-proof`, then
`--case core-controls`. The script starts the tools and compares exit
codes and records. It decides no proof.

| Step | Actual exit | Result |
| --- | --- | --- |
| `dafny --version`; `z3 --version`; executable digests against `toolchain/pins.json` | 0; 0 | equal to the pins; the options are `gate/backends/dafny.py` `OPTIONS` |
| `python3 gate/refund.py --tier critical` (the refund gate itself) | 0 | ACCEPTED R1–R5, `source_proof`, for the present `impl/Refund.dfy` |
| `dafny audit impl/RefundFinality.dfy tests/refund-finality/Bindings.dfy --compare-report` (before and after) | 0; 0 | 0 findings; report equal to `gate/expected-audit.md` |
| `dafny verify impl/RefundFinality.dfy tests/refund-finality/Bindings.dfy` with the gate options | 0 | 10 verified, 0 errors; the ten required members all `Passed` |
| scenario `--case core-proof` | 0 | attempts 1 and 2 both exit 0 (attempt 2 after the review repairs; the core did not change) |

Verified members: `Refund.Assess` (correctness, well-formedness),
`RefundSpec.Assess` and `RefundSpec.Eligible` (well-formedness),
`RefundFinality.Check` (correctness, well-formedness),
`RefundFinalityChecks.Universal`, `.NoChoice`, `.IssueWitness`,
`.RefuseWitnesses` (correctness). `NoChoice`: for one pre-state and one
request, at most one transition can get a token. The two witness
methods show that issue and refusal both occur.

Wrong cores (`tests/refund-finality/fixtures/`). Each is a full core
that satisfies its own weakened contract; it is verified beside the same
`Bindings.dfy`. For the seven exit-4 controls the script requires that
`RefundFinality.Check (correctness)` passed and that the failed members
are all in the binding file.

| Wrong core | Checker exit | Reason found | Scenario |
| --- | --- | --- | --- |
| `CoreIssuesEverything` | 4 | assertion of P1 not proved | as expected |
| `CoreKeepsRemaining` | 4 | P1 (and P2) not proved | as expected |
| `CoreSkipsIntentCheck` | 4 | P1 (and P2) not proved | as expected |
| `CoreRefusesEverything` | 4 | P2 not proved | as expected |
| `CoreIntentOnRefusal` | 4 | P3 not proved | as expected |
| `CoreWrongHash` | 4 | P4 not proved | as expected |
| `CoreNeedsPrecondition` | 4 | "a precondition for this call could not be proved" in the binding callers | as expected |
| `CorePrints` | 2 | "to use a print statement, the enclosing method must be marked with {:print}" | as expected |
| `CorePrintsMarked` | 2 | "to call a method with print effects, the enclosing method must be marked with {:print}" at the binding callers | as expected |
| scenario `--case core-controls` | 0 | 9 of 9 rejected for the expected reason | attempts 1 and 2 |

A rejection of a wrong core means "could not be proved". It is not a
proof that the wrong core is unsafe.

## 4. Sink controls (finite test): actual exits

Command: `python3 scripts/exit_slice1.py --case sink-controls`. It
compiles the core, runs the type check and runs
`tests/refund-finality/suite.ts` with the pinned Node. Real processes,
real Ed25519, real SQLite files.

"Effects" of one attempt = changed state (0 or 1) + new settled rows +
new outbox rows + new outbound emissions. A rejection row passes only if
the sink answers with the expected reason and the effects are 0.

| Step | Actual exit | Result |
| --- | --- | --- |
| `dafny build impl/RefundFinality.dfy --target js` with the gate options | 0 | module SHA-256 `e6d5f5e5…`; byte-identical in every run |
| `node node_modules/typescript/bin/tsc --noEmit` | 0 | all TypeScript of the repository, with the new files |
| `node --import tsx tests/refund-finality/suite.ts` (final files) | 0 | 115 rows, 0 failed |
| scenario `--case sink-controls` | 0 | attempt 3 (final files). Attempt 1 (94 rows) and attempt 2 (113 rows) also exit 0; they were earlier versions of the code; see section 5 |

| Group | Rows | What the rows show (all passed) |
| --- | --- | --- |
| (a) missing, forged or tampered token | 42 | 39 rejection attempts, 0 effects. Among them: no token; an object in place of text (a proxy counts 0 operations on it); text that is not canonical (spacing, key order, a repeated key); wrong, short or foreign signatures; a key made from the public key; a second issuer's key; changed fields; other shapes; U+0000; two tokens with a VALID signature of the trusted key but another spec lock or checker id. The untampered token then commits |
| (b) stale pre-state hash | 8 | a signed token for an old state, and for a state that the caller invented: rejected, 0 effects. Race: 6 valid tokens for one pre-state from 6 processes at one common start time: exactly 1 commits |
| (c) duplicate request id | 13 | replay: 0 effects. A new signed token for the current state with a settled request id: rejected. Amount 0 leaves the state hash equal; only the request-id check stops its replay. Race: one token from 6 processes: exactly 1 commit |
| (d) valid transition | 9 | exactly one effect each: state = post-state, 1 settled row, 1 outbox row, 1 outbound effect with the checked intent; five in order, sum = original − remaining |
| issuer | 29 | 217 (pre-state, request) pairs against a test oracle: 0 disagreements (35 signed, 182 refused by the core). 10 wrong candidates for an eligible request refused by the core. 14 malformed messages refused. The module exports nothing. A message with a deeply nested id is refused and the issuer keeps running. A line of 500,000 bytes is refused before it ends, once, and the issuer answers the next request |
| dispatcher | 11 | raw database changes (row without token, changed amount, attacker-signed token, signed token for an earlier state, copy under a new request id, re-inserted rows): 0 outbound effects. Broken ledger: stops. Crash between ledger line and effect: never sent twice. 4 runs at one common start time: each refund sent once. 6 runs through three names of one ledger file: each refund sent once |
| option, setup | 3 | `single-use on` refuses a second transition for one pre-state; the issuer reports the ids that the operator computes |

Totals of the final run: 48 rejection attempts in (a), (b), (c); 0
effects. The column `uncheckedSinkEffects` of the report says only that
an attempt asks for an effect; it describes the input, not the sink.

That the rows can fail: ten copies of the glue with one check removed
each (one-off, scratch folder, final suite). The suite ended with a
non-zero exit in every run for all ten:
[records/removed-check-copies.json](records/removed-check-copies.json).

## 5. Defects found during the work

| # | Found by | Defect | Evidence | Repair |
| --- | --- | --- | --- | --- |
| 1 | build agent, own read | FAIL-OPEN in the first sink: it read the caller's object more than once. An accessor could give the signed value to the signature check and another value to the store | new control row; suite exit 1 (state written with remaining 0 under a signature for 700) | second version: copy the value first |
| 2 | review F1 | The copy still ran the caller's accessor inside the sink process; the accessor could replace `crypto.verify` | reviewer's probe: forged token committed | `commit` takes text only and reads no property of an object |
| 3 | review F2 (HIGH) | Two dispatcher runs that overlap sent each refund more than once | reviewer's probe: 12 effects for 3 rows | exclusive lock file; one run at a time |
| 4 | review F3 (MEDIUM) | A request id with U+0000 does not read back from SQLite; the dispatcher then stops for good | reviewer's probe | U+0000 refused in every text field |
| 5 | review F4 (MEDIUM) | One message with a deeply nested id ended the issuer process; the key was lost | reviewer's probe | the id must be a small integer |
| 6 | review | The two race rows could not fail: the processes did not overlap | reviewer: both passed on a sink with no transaction | common start time; against a sink with no transaction the rows now fail in 3 of 3 runs (5, 6 and 2 commits for one pre-state) |
| 7 | build agent | The suite could end with exit 0 and no report when the issuer process died | seen with a removed-check copy | exit code 2 until the last line; a dead issuer answers waiting requests |

The repairs 2 to 7 were made in one pass after the one review. The full
review text and the disposition of every finding: [REVIEW.md](REVIEW.md).
Not repaired (LOW, by the owner's rule): F5 to F8; they are limits 12
to 15 below.

After the push, a second fresh-context agent checked the four repaired
places only (owner text 8). Result: the repairs of F1, F2 and F3 held in
every probe; the repair of F4 held for the confirmed message. FAIL-OPEN
0, HIGH 0, MEDIUM 1, LOW 1. On owner text 9 the build agent repaired
both findings in one last pass. THAT PASS HAD NO REVIEW.

| # | Finding of the repair check | Observed | Repair in the last pass | Evidence |
| --- | --- | --- | --- | --- |
| 8 | MEDIUM: a line of more than about 537 million characters with no end | the issuer process ended with exit code 1 inside Node's line reader, before the issuer's own length check; the key was lost. No token signed, no effect | the issuer cuts lines out of the raw bytes and holds at most 65,536 bytes of one line; a longer line is answered once and dropped up to its end | one-off probe with 600 MB ([records/long-line-probe.json](records/long-line-probe.json)): issuer of `9af026df` exit code 1; repaired issuer still running and the next request signed. New suite row |
| 9 | LOW: the dispatcher lock followed the path text | one ledger file under two names: every refund sent twice (24 effects where 12 are correct) | the lock is named after the resolved path of the ledger file | new suite row with three names of one ledger file: each refund sent once |

Text and disposition: [REVIEW.md](REVIEW.md) sections 3 and 4.

## 6. What is not approved intent

The approved refund specification has no stored state. Three rules are
choices of this slice. They are in `impl/RefundFinality.dfy` and
`tests/refund-finality/Bindings.dfy`, not under `spec/`:

1. The stored state of a charge is (chargeId, original, remaining,
   refundEnabled).
2. An authorized refund decreases `remaining` by the amount and changes
   nothing else.
3. The core takes the request as open (`requestOpen = true`). The sink
   decides that a request id is fresh.

Also not approved: the token fields, the domain text and the sink rule
itself. To make them approved intent, a proposal with exact bytes for
`spec/` and `policy/` is necessary. It is not written.

## 7. Evidence record

`python3 scripts/exit_slice1.py --case evidence` runs sections 3 and 4
twice in fresh folders and compares the two bundles byte for byte.

| Run | Actual exit | Bundle SHA-256 |
| --- | --- | --- |
| working tree, final files | 0 | `c7f2f41c872b5c133d422ef881d36e6c09390f081d555d74761d4890283833f1` (two runs, byte-identical) |
| scratch clone (section 8) | 0 | `c7f2f41c872b5c133d422ef881d36e6c09390f081d555d74761d4890283833f1 (equal)` |

The bundle is [records/evidence.json](records/evidence.json). It holds
no time, no key, no signature and no absolute path. It names its own
class: `gate_accepted: false`, `policy: null`, method `source_proof`
for P1 to P4 and `unit_tested` for the four sink claims. Earlier
bundles of this session (`900dbaf4…`, `d660b92b…`, and `fffdd343…` of
commit `9af026df`) belong to earlier file versions and are replaced.

## 8. Regression on a scratch clone (control e)

`run_regression.py` makes a throwaway clone of the present commit,
copies the uncommitted files into it, and commits them THERE so that
the revision-based checks see them. That commit is not in the owner's
repository. The table is the run for the last pass: a clone of
`9af026df` plus the uncommitted files of the last pass.

| Check (scratch clone of `9af026df` plus the files of the last pass) | Actual exit | Result |
| --- | --- | --- |
| 28 Stage EXIT cases: Stage 1 (5), 2 (5), 3 (6), 5 (2), 6 (1), 8 (3), 4 (3), 11 (3) | 0 each | 28 of 28 |
| `check_frozen_pr_gate.py HEAD` | 0 | the eight PR-gate modules equal the recorded digests |
| `check_links.py HEAD` for `FORGE_MASTER_IDEA.md`; `ROADMAP.md`; this report | 0; 0; 0 | no link without a target |
| `check_links.py HEAD`, all 80 Markdown files outside `results/` | 1 | the 2 older Stage 9 links without a target; none new |
| `scripts/exit_slice1.py --case evidence` in the clone | 0 | bundle SHA-256 equal to the working tree's |

Record: [records/regression.json](records/regression.json) (path-free).
Two earlier runs of the same script gave the same results for their
versions: the 97-row version (bundle `900dbaf4…`) and the version of
`9af026df` (clone of `f6329211` plus the slice; bundle `fffdd343…`).
Both versions are replaced.
NOT RUN: Stage 7 (Docker, about 3.3 hours), Stage 9 (deferred), Stage
10 (its EXIT script is not on `main`). The stage runs changed five
record paths in the clone, as in earlier full checks: Stage 5 rewrites
its two records with the local tool path, and Stage 8 adds three
attempt folders.

After this run only document files changed (this report, `ROADMAP.md`,
`unsure.md`, and the two records of this section). No file of the
bundle's source manifest changed. The frozen-gate check and
the link checks ran again on the final documents; their result is
`records/links-final.json`.

## 9. Hosted gate

Expected result of `gate/pr_check.py` for a pull request with these
files: exit 3
(UNSUPPORTED). Reason: every file of this slice is new or a document,
and no obligation in the frozen `gate/obligations.py` lists it
(`UNCOVERED_CHANGE`). The files that the obligations `refund-proof` and
`refund-tests` list do not change. Exit 0 (VERIFIED) needs a new
obligation and a new ratification record. That is a separate exact-diff
proposal for the owner. It is not written.

ACTUAL for the first head: pull request 45, head `9af026df`, hosted run
44358528370 (Linux profile): `gate/pr_check.py` exit code 3, outcome
UNSUPPORTED. The log says that every obligation that ran holds and
lists 32 coverage findings, one `UNCOVERED_CHANGE` for each file of
this slice. Job `verify`: failure (exit 3); job `report`: success. This
is the expected result. It is not a VERIFIED result.

For the head with the last pass (the commit that holds this report):
NOT RUN when this report was committed. Expected: exit 3 again.

## 10. Limits

1. The source proof is about the Dafny source. The JavaScript that runs
   is the output of an unproved compiler.
2. Exact acceptance (P2) is a property of the core. The glue refuses
   more: text longer than 256 characters, lone surrogates, U+0000,
   money that is not a decimal text of at most 19 digits, every message
   with another shape, and every token that is not the canonical text.
3. The issuer signs for the pre-state that the caller states. Only the
   sink knows the stored state. A token for a state that is not stored
   is harmless only because of the sink's check (control b).
4. A token is not bound to one sink database. Two databases that hold
   the same charge state and trust the same key both accept it. A
   database file that is put back to an older copy accepts old tokens
   again. One store per charge, written only by the sink, is assumed.
5. A token has no end time. It stays usable while the stored state is
   its pre-state and its request id is not settled.
6. A refund of amount 0 is eligible in the approved specification. It
   does not change the state hash. Only the request-id check stops its
   replay.
7. An attacker who can write the database file can change rows. The
   dispatcher refuses rows without a verifying token of the chain, and
   the audit reports a broken chain. That is detection and refusal, not
   prevention. Limit D14 of `unsure.md` U428 stays.
8. The issuer option `single-use on` is unproved code and is lost at
   restart. The suite runs the sink controls with `single-use off`, so
   that the sink alone must stop a stale token. Which mode a deployment
   uses is an open owner decision (U428).
9. A crash between the dispatcher's ledger line and the effect loses
   that effect. It is never sent twice. A process that dies inside a run
   also leaves the lock file; every later run stops. A person must
   reconcile the last ledger line and remove the lock file. An effect
   callback that throws loses that effect too, and no lock stays: only
   the thrown error marks it. The lock is named after the resolved path
   of the ledger file; a hard link to the ledger file is not covered.
10. The key is in the memory of a process of the same user. No hardware
    key store. A new issuer process has a new key; tokens of the old key
    that are committed but not dispatched are then refused by a
    dispatcher that pins the new key. There is no path over a key
    change. The issuer holds at most 65,536 bytes of one line (section
    5, row 8). Closing the issuer's input ends it. Memory growth was not
    measured. Other ways to stop the issuer process were not searched.
11. Code that runs inside the sink process is in the trusted base. The
    sink reads no property of a caller's value, but code that is loaded
    into its process can replace any function it uses.
12. (review F5) An issuer answer that holds U+2028 or U+2029 (in a
    signed id) is cut by the line reader of the proposer-side client.
    The reviewer could not inject a valid line. Availability of the
    untrusted side only. Since the last pass the issuer itself cuts
    lines only at the byte 0x0A.
13. (review F7) A missing dispatcher ledger file is read as an empty
    ledger: a lost ledger sends everything again.
14. (review F8) `Sink.init` is a trusted call and does not copy its
    argument first.
15. Not checked: durability at power loss; the busy time limit of the
    dispatcher's read connection; a message over the length limit; more
    of `single-use on`.
16. All tests are finite. The winner of a race is not deterministic;
    the record holds only the counts. The removed-check copies are 10
    cases, not a mutation score. The reviewer's own count for the first
    version was 29 of 47 copies detected.
17. The last pass (section 5, rows 8 and 9) had no review.

## 11. Open decisions for the owner

1. The merge of pull request 45 (the agent does not merge).
2. Whether the three rules of section 6 become approved intent (`spec/`
   and `policy/` proposal).
3. Whether a gate obligation for the core is wanted (proposal for the
   frozen `gate/obligations.py` with a ratification record).
4. The issuer mode `single-use` (U428).
5. Whether the LOW findings F5 to F8 are to be repaired.

## 12. Reproduce

```text
export PATH=/opt/homebrew/bin:$PATH        # the pinned Node 24.3.0 first
python3 scripts/exit_slice1.py --case core-proof
python3 scripts/exit_slice1.py --case core-controls
python3 scripts/exit_slice1.py --case sink-controls
python3 scripts/exit_slice1.py --case evidence
python3 proposals/forge2-slice1-refund-finality/run_regression.py <new-clone-folder> <record.json>
```

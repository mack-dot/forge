# Slice 3 of the master idea — runtime certificates on batch booking (items F3.1 and F3.2)

Date: 2026-11-18. Branch `slice3/runtime-certificates`, base `462f9e2e`.
Status: built; for the owner's merge decision. NOT merged by the agent.
`end_to_end=false`. NOT gate evidence: no policy lists these claims and
no gate obligation lists these files. No protected file changed. No file
of Slice 1 or Slice 2 changed. No new package.

Owner texts: [OWNER_TEXTS.md](OWNER_TEXTS.md) (text D: the directive;
text E: the go-ahead with three points). Review:
[REVIEW.md](REVIEW.md). Uncertainty entries: `unsure.md` U453 to U456.

Read first: the review found two HIGH defects and they are repaired, one
of them with a trusted tool (the macOS sandbox), not with a proof
(sections 4 and 8). The repairs were not reviewed again.

## 1. The idea in one paragraph

An untrusted optimizer proposes which requests of a batch to book, and
gives a certificate: prices for slots and for requests, and the gap that
it states. A small checker core, proved with the pinned Dafny, accepts
the proposal only if the allocation breaks no capacity and the prices
show that no feasible allocation is better by more than the stated gap.
An issuer process signs a token only for what the core issues. A sink
makes the effect only for a valid token that names its stored board, its
stored batch and a fresh request id. The optimizer can then change
without a new proof: no optimizer file is an input of the proof, and
nothing trusts what an optimizer sends.

## 2. The problem and the check (exact)

Over mathematical integers. Row `i` is a slot with the capacity `c[i]`.
Column `j` is a request: it needs `A[i][j]` units of slot `i` and has
the value `w[j]`. Maximise `w·x` with `A·x ≤ c` and `x ∈ {0,1}ⁿ`.

    Accepts(batch, proposal) ⇔
      0 ≤ alphaBps ≤ 10000 ∧ the shapes agree ∧
      x is 0/1 ∧ A·x ≤ c ∧                      -- feasible
      y ≥ 0 ∧ z ≥ 0 ∧ Aᵀ·y + z ≥ w ∧            -- the certificate
      (10000 − alphaBps)·(y·c + Σz) ≤ 10000·w·x  -- the stated gap

Proved by weak duality (the proof of Round 1, reused unchanged): if
`Accepts`, then for EVERY feasible `alt`,
`(10000 − alphaBps)·w·alt ≤ 10000·w·x`. With the gap 0, `x` is a global
optimum of the integer problem. No linear-programming theorem and no
solver is trusted.

**Two limits that the owner approved in text E.**

1. Sound, NOT complete. "If and only if" holds for the decision of the
   core and the predicate `Accepts` (claim Q3). It does NOT hold for
   "the allocation is within the gap of the optimum": an optimal
   allocation with weak prices gets no token (Round 3: 299 of 845
   optimal proposals at the gap 0). Where the integer problem and its
   linear relaxation differ, no certificate with the gap 0 exists.
2. This batch model is NOT the approved booking specification
   (`spec/booking/BookingSpec.dfy` books one request at a time at the
   least free slot of its allowed set; it has no batch, no value and no
   optimum). The candidate specification of this slice is not approved
   intent. One bridge lemma (claim Q6) links one batch shape to one
   approved predicate. It was proved at the second of at most five
   attempts.

## 3. What is proved (pinned Dafny 4.11.0, Z3 4.12.1, gate options with print-effect tracking)

| Claim | Statement | Members (file) |
| --- | --- | --- |
| Q1 | A token is only for an allocation that is 0/1 and uses no slot above its capacity. The token holds exactly the capacities that remain; none is negative. | `IssueIsFeasible` (`certificate/BookingCertificateClearing.dfy`) |
| Q2 | The value of the allocation of a token is within the stated gap of the value of every feasible allocation. | `IssueIsNearOptimal`; `BookingDualCert.Quality`, `WeakDuality` (reused) |
| Q3 | The core issues a token exactly when `Accepts` holds. No precondition. | `BookingCertificate.Decide (correctness)` (`impl/BookingCertificate.dfy` against `certificate/BookingCertificateSpec.dfy`) |
| Q4 | A token holds exactly the two given hash texts, the request id, the checked allocation, the stated gap and the value. | `IssueBindsTheToken` |
| Q5 | The candidate specification leaves no choice (clearing verdict NO_CHOICE, with an exact `Post`, a proved acceptance, a non-abstract instance and a probe of the specification). | `SpecIsDeterministic`, `DecideThenPost`, `PostIsExact`, `IssueWitnesses`, `RefuseWitnesses`; the Slice 2 tool |
| Q6 | Bridge: for a batch in which every request needs exactly one slot and every slot has the capacity 1, an accepted allocation gives an `active` map that satisfies the approved `NoDoubleBooking`. | `AcceptedHasNoDoubleBooking`, `FeasibleHasNoDoubleBooking`, `BridgeWitness` (`certificate/BookingBridge.dfy`) |

How the checks rest on concrete modules (the rule of Slice 2):

- The core `BookingCertificate` is a non-abstract refinement of the
  candidate specification. Dafny proves its `Decide` against the
  specified contract directly.
- The claim lemmas are in an abstract module (they hold for every
  refinement). The EXIT script makes a non-abstract instance that is
  bound to the core, and audits every file that is reached.
- The bridge module is not abstract. It imports the verified
  implementation module `Booking`, so the predicate is the approved one.

How little the bridge says (the reviewer's words, kept here): every slot
must have the capacity exactly 1, so the lemma does not cover a second
batch on a board that is partly used. It needs only feasibility; prices,
values and the gap play no part. It says nothing about `Decide`, a
token, the sink, or bookings made before the batch. The map of active
bookings is defined in the bridge file.

**Observed in this work (it makes the Slice 2 rule more exact).** For
the instance file, Dafny makes NO new proof task for the inherited
members. The proofs are those of the abstract module. What the instance
adds is the resolution of the bound implementation: a member without a
body, or a print effect of the bound core, is reported there. Example:
a core whose `Decide` prints and is marked `{:print}` passes
`dafny verify` and `dafny audit` when it is checked alone (exit 0, 0);
only the instance is refused (exit 2). The EXIT script has that control.

## 4. The boundary (what runs, and what is trusted)

    optimizer (any language, own process)        NOT trusted for what it sends
        |   runs under the macOS sandbox tool: no file write, no network, no signal
        | one line in, one line out; 16,384 bytes; time limit
    runner  ts/booking-certificate/guest.ts      makes no decision
        | the line as text
    issuer  ts/booking-certificate/issuer.ts     trusted, not proved
        |   decision = compiled BookingCertificate.Decide (proved at source level)
        |   Ed25519 key only in this process; line limit 65,536 bytes
        | token (canonical JSON text)
    sink    ts/booking-certificate/sink.ts       trusted, not proved
            public key, two pinned ids, hash of the first board, largest gap; SQLite

The token names: domain, specification id, checker id, pre-state hash
(the stored board), batch hash (the stored batch with its request id),
request id, allocation, gap, value, and the board after the allocation.
The sink commits if and only if the token text is canonical and has the
pinned ids, the gap is not above the largest gap of the sink, the
signature verifies, the request id is not settled, the batch with that
id waits there with that hash, and the stored board has that hash. One
SQLite IMMEDIATE transaction. No booking rule is in the sink. These are
statements about `commit`. A process that writes the database file
behind the sink is outside them; that is why the optimizer process is
isolated (below).

Trusted and not proved: the Dafny JavaScript back end and runtime,
`bignumber.js`, the three TypeScript files of issuer and sink with the
canonical form of Slice 1, Node with OpenSSL and SQLite, process
isolation, key secrecy, and the sandbox tool of macOS with the profile
of `guest.ts`.

**Isolation of the optimizer process (review finding R1).** An
optimizer runs as the same operating-system user as the sink. The first
version of the runner started it with no isolation, and the reviewer's
optimizer wrote the board in the sink's database behind the sink. Now
the runner starts every optimizer under `/usr/bin/sandbox-exec` with a
profile that denies file writes, network use, signals and the task port
of other processes, for the process and for every process that it
starts. Reading files stays allowed. This tool is trusted and not
proved; its vendor marks it as deprecated; it exists on macOS only (on
another platform the runner starts no optimizer). So the exact
statement is: an optimizer is not trusted for what it SENDS; that it
cannot act in another way rests on the sandbox, shown by finite control
rows.

**rustc.** Optimizer v2 is safe Rust (`#![forbid(unsafe_code)]`, built
with `rustc -D unsafe_code -D warnings`, standard library only, no Cargo,
no crate). `rustc 1.92.0 (ded5c06cf 2025-12-08)` was already installed
on this machine. It is NOT pinned and NOT part of any proof. The
evidence record holds its version text and the hash of the Rust source.
It holds no hash and no path of the binary.

## 5. The optimizer swap (finite recorded runs)

70 batches: the 46 instances of Rounds 2 and 3, and 24 batches with the
capacity 1 and one unbroken run of slots for each request. At most 14
requests each, so a search over all subsets gives the optimum for the
test's reference. Largest gap of the sink: 2000 basis points.

| Optimizer | Language | Batches | Tokens | Committed | Of them at gap 0 | Tokens above the largest gap | Effects without a commit |
| --- | --- | --- | --- | --- | --- | --- | --- |
| v1 | TypeScript (a solver function of Rounds 2 and 3) | 70 | 70 | 49 | 17 | 21 | 0 |
| v2 | safe Rust (dynamic program for unit capacities; greedy for the rest) | 70 | 70 | 35 | 26 | 35 | 0 |
| v3, 12 modes that send a wrong proposal | Python | 70 each | 0 | 0 | — | — | 0 |
| v3, 4 modes that break the line (too long; no line; no answer in time; control characters) | Python | 2 each | 0 | 0 | — | — | 0 |

84 allocations committed, each for a token. The 12 adversary modes:
overbooking, a request booked twice, a forged certificate (prices only
for the booked requests), negative prices, "nothing is optimal", a gap
below 0, a gap above 10000, a wrong shape, a number of 30 digits, a JSON
number, one key more, a line that is not JSON. For 8 of them the
untrusted side also offered the sink a token that it signed itself: 560
offers, 560 rejected. The full table of the 18 runs:
[records/SWAP_REPORT.md](records/SWAP_REPORT.md).

For every optimizer the same checks run (`tests/booking-certificate/swap.ts`
does not know which optimizer it runs): the issuer gives a token exactly
when a second implementation of the check accepts; every token is
feasible and within its gap of the optimum by the search; a token within
the largest gap commits exactly once and its second use has 0 effects; a
token above the largest gap has 0 effects; a proposal without a token
has 0 effects, also when the untrusted side signs a token for it with
its own key.

What "no new proof" means here, and what is checked: the EXIT script
compiles the core once. Then the 18 optimizer runs follow, and they are
the only commands that the script starts. The script checks that the
compiled module has the same bytes before and after, that the five proof
input files did not change, and that every run reports the module hash,
checker id and specification id that a new computation from the files
gives. It does NOT observe the processes that an optimizer run starts
(review finding R5); the first version of this text said "0 starts of
Dafny", which was a count over the script's own commands. This is a
statement about the recorded runs. The reason that it holds in general
is the design: no optimizer file is an input of the proof.

## 6. Controls

**Wrong cores (21).** Each is a refinement of the candidate
specification with one defect. The same procedure that accepts the core
must refuse each one, for its own reason
(`scripts/exit_slice3.py --case core-controls`):

| Refused by | Count | Wrong cores |
| --- | --- | --- |
| the verifier, at the decision clause of the contract | 9 | no 0/1 check; no capacity check; no certificate check; negative slot prices; negative request prices; no gap check; gap above 10000; issues everything; refuses everything |
| the verifier, at the token clause | 7 | wrong state hash; wrong batch hash; wrong request id; wrong value; another allocation; old capacities; states the gap 0 |
| a Dafny error before any proof | 2 | prints (F1.2); needs a precondition |
| the non-abstract instance only | 1 | prints and is marked `{:print}` (F1.2) |
| the Dafny audit only | 1 | "proves" the contract with an assumption |
| the refused word only | 1 | a run-time halt statement (`expect`) in place of the proof |

**Clearing control (1).** A planted candidate specification that lets
the checker refuse an accepted certificate gets CHOICE (two verified
refinements give a token and a refusal for one proposal), not NO_CHOICE.

**Issuer, sink and runner (finite suite).** 104 rows, 0 failed
(`scripts/exit_slice3.py --case sink-controls`): 41 issuer rows (the
decision is the compiled core; shape and size refusals; line limit; a
grid of 288 proposals against the reference; numbers of 17 digits); 25
rows for a missing, forged or changed token; 9 rows for a store that is
not what the token names (stale board, other batch, no batch); 5 replay
rows; 2 rows for the one effect; 5 rows for the largest gap; 1 race row
(6 processes offer 6 valid tokens for one board at one time: 1 commit);
6 audit rows and 1 row that shows a stated limit of the audit; 8 runner
rows (byte limit, time limit, no line, control characters, a file write
by an optimizer and by a process that it leaves behind, a child process
that is left); 1 row that compares the ids with the files. Rejection
attempts at the sink: 33; their effects: 0.

**That the controls can fail.** One-off, in a scratch tree: the three EXIT cases
on the unchanged tree end with exit 0, 0, 0. Then 26 copies, each with
ONE check removed from the sink, the issuer, the runner, the encoding or
the EXIT script (19 before the review; 7 more for the reviewer's
cases, with the missing adversary program among them). The EXIT case
ended with a non-zero exit for 26 of 26, each at the row of its removed
check: [records/removed-check-copies.json](records/removed-check-copies.json).
(Before the review: 19 of 19.)

## 7. Actual exits

| Check | Actual exit | Result |
| --- | --- | --- |
| pinned Dafny, core with the claim lemmas: attempts 1 and 2 | 4; 0 | attempt 1: one non-vacuity lemma out of resource; attempt 2: 65 verified |
| pinned Dafny, bridge lemma: attempts 1 and 2 (limit 5) | 4; 0 | attempt 1: one assertion; attempt 2: proved |
| `scripts/exit_slice3.py --case core-proof`, attempt 1 | 0 | core, claims, bridge, non-abstract instance, audit of every reached file |
| `--case clearing`, attempt 1 | 0 | NO_CHOICE and ACCEPTS; the planted loose specification: CHOICE |
| `--case core-controls`: attempt 1 (20 wrong cores, before the review); attempt 2 (21) | 0; 0 | each refused for its own reason |
| `--case sink-controls`: attempt 1 (93 rows, before the review); attempt 2 (104 rows) | 0; 0 | 0 failed rows |
| `--case swap`: attempt 1 (17 optimizer runs, before the review); attempt 2 (18) | 0; 0 | counts of section 5 |
| the repaired control suite alone, first run | 1 | the author's new check for a left-over process matched the author's own shell command; corrected; next run 0 |
| copies with one check removed (one-off, scratch tree): before the review; after the repairs; after the move of six files | non-zero for 19 of 19; for 26 of 26; for 26 of 26 | the unchanged tree: 0, 0, 0 each time |
| `--case evidence`: attempt 1 (before the review); attempt 2 (after the repairs); attempt 3 (final, after the move) | 0; 0; 0 | each: two runs byte-identical; bundles `f42bb8c2…`, `4ed7a2c4…` (both replaced) and `3cdfebfc0ae96adafccc7f417bcd9113aaa63df9c9cd31583983c3b2e11bddb4` |
| first scratch clone of `462f9e2e` plus the files of this slice (`run_regression.py`) | 28 Stage cases 0 each; Slice 1, 2, 3 evidence 0, 0, 0 | the Slice 2 bundle was `d0a9a621…`, NOT the `2721a293…` of `main` (see below) |
| second scratch clone (final): 28 Stage EXIT cases (Stages 1, 2, 3, 4, 5, 6, 8, 11) | 0 each | 28 of 28 |
| the same clone: `check_frozen_pr_gate.py HEAD`; `check_links.py` for `FORGE_MASTER_IDEA.md`, `ROADMAP.md`, this report; for all 88 Markdown files outside `results/` | 0; 0, 0, 0; 1 | the 2 older Stage 9 links without a target; none new |
| the same clone: `scripts/exit_slice1.py --case evidence`; `scripts/exit_slice2.py --case evidence` | 0; 0 | bundles `c7f2f41c…` and `2721a293…`, as on `main` |
| the same clone: `scripts/exit_slice3.py --case evidence` | 0 | bundle SHA-256 equal to the working tree's (`3cdfebfc…`) |
| Stage 7; Stage 9; Stage 10; hosted gate | NOT RUN | Docker time; deferred; no EXIT script on `main`; no pull request when this report was written (expected exit 3) |

**The Slice 2 bundle difference.** The first version of this slice put
its candidate specification files in a folder under `clearing/`. The
EXIT script of Slice 2 lists every Dafny file under `clearing/` in the
source manifest of its record. So the Slice 2 record of the first
scratch clone had six more manifest entries and another SHA-256. No
verdict and no other field differed. The six files were moved to a new
folder `certificate/` (paths only; no check changed). After the move
the Slice 2 record is again the one of `main`. `unsure.md` U454 and U455
name the old folder.

The final bundle is [records/evidence.json](records/evidence.json). It
holds no time, no absolute path, no key and no signature. It names its
own class: `gate_accepted: false`, `policy: null`. Regression record:
[records/regression.json](records/regression.json) (path-free). The
Slice 3 files were committed in the scratch clone only, so that the
revision-based checks could see them. After that run only document
files changed; the frozen-gate check and the link checks ran again on
the final documents (`records/links-final.json`).

## 8. Review and defects

One fresh-context review (a separate agent; it got the code and the
questions, not the author's conclusions). Its verdict: no input to
`Sink.commit` made an effect without a token (60,000 changed token
texts and about 40 chosen cases), and the issuer signed nothing that the
compiled core did not issue (6,000 cases against two other
implementations of the check). Those are finite tests. It found:

| # | Severity | Defect | Repair |
| --- | --- | --- | --- |
| R1 | HIGH | The runner started an optimizer as the same user with no isolation. The reviewer's optimizer wrote the board in the sink's database behind the sink; the run reported PASS; the audit reported nothing. The author's sentence "it cannot make the sink take an allocation without a token" was false for such a process. | Sandbox tool for every optimizer (trusted, not proved); pin of the first board in the sink; new rows; the sentence corrected |
| R2 | HIGH | The 15 adversary runs passed when the adversary program did not exist: the EXIT script checked only "0 tokens". | Exact counts and row texts pinned for every mode |
| R3 | MEDIUM | A line of control characters from an optimizer made the issuer client wait for ever. | Local refusal and a time limit in the client |
| R4 | MEDIUM | The runner killed only the direct child of an optimizer. | Kill of the process group |
| R5 | MEDIUM | "0 starts of Dafny" was a count over the script's own commands; one record field was a constant; the sink pins came from the issuer's own word. | Ids computed again from the files; claims reworded; constant removed |
| R6 | LOW to MEDIUM | The audit took the first board hash from the same database. | Pin of the first board; more audit rows; two limits stated |
| R7 to R12 | LOW | Token not bound to one sink; no sign rule; misleading refusal text for very large numbers; rows that cannot find a loss of precision; no backpressure in the issuer; loose controls. | Some small repairs; the rest stated (section 10) |

Before the review, by the author: a suite row was missing for the rule
"the token must be a text" (a copy of the sink without that rule would
not have failed); the row was added.

The repairs were made in one pass. No second review ran. Full text and
the disposition of every finding: [REVIEW.md](REVIEW.md).

## 9. Evidence classes (kept separate in the record)

| Class | What it holds in this slice |
| --- | --- |
| `source_proof` | Q1 to Q6: Dafny proofs about the Dafny sources |
| `binary_proof` | none |
| `in_logic_compiler_proof` | none |
| `runtime_certificate_checked` | R1: each committed allocation of the recorded runs has a token of the compiled core |
| `tested_against_proved_model` | T1: the issuer against a second implementation of the check, and against the optimum by search, on the recorded proposals |
| `unit_tested` | Z1: the recorded swap with 0 starts of Dafny |
| `floor_controls` | the wrong cores and the rows of the control suite |

A count in the last four rows is never a proof.

## 10. Limits

1. Sound, not complete (section 2). A system needs a fallback for
   batches without a token within the largest gap. In the recorded runs:
   v1 has 21 and v2 has 35 of 70 tokens above the largest gap.
2. The batch model is not approved intent (section 2). The bridge covers
   one predicate and one batch shape. It does not link the batch model
   to the approved method `Apply`.
3. Source level. The proof does not cover the compilation to JavaScript,
   the issuer, the encoding, the hashes, the signature, the sink, the
   storage or the deployment. The two hash texts are inputs of the core.
4. The issuer cannot know what the sink stores. The sink binds the token
   to its store. Several valid tokens can exist for one board; the sink
   commits the first. A token is not bound to one sink: two sinks with
   the same keys, ids and board take the same token, and a token is
   valid again when the board returns to the value that it names
   (review R7).
5. Intake of batches (`Sink.submit`) is trusted. A wrong batch at the
   intake is certified as it is. Needs, capacities and values below zero
   are allowed (the proof holds for all integers); a need below zero
   makes capacity grow (review R8).
6. Sizes: at most 32 slots, 64 requests, 18 digits per number. A token
   whose value or remaining capacity needs more digits is refused. The
   compiled check uses recursion over the length of a sequence.
7. The optimizer process is isolated by a trusted tool of one platform
   (section 4). It can still read files. The time limit and the kill of
   its process group are housekeeping, not containment. The owner
   accepted this tool for the slice as documented (owner text G,
   `unsure.md` U457). That is an acceptance, not a proof.
8. The audit of the sink does not see a database that is set back as a
   whole to an earlier state of its own chain, and not a waiting batch
   that is changed before its commit (one suite row shows the first
   case as it is).
9. A person must read the hand-written claim lemmas and the subject list
   (the Slice 2 limit). The clearing tool does not detect a ghost
   definition without a body in a specification (Slice 2 limit).
10. One machine, one platform (macOS arm64). `rustc` is not pinned.
11. The scripts and the test code are not proved. One fresh-context
    review (section 8); its repairs were not reviewed again.
12. Finite runs: 70 batches of at most 14 requests, three optimizers.
    The recorded batches have numbers of at most 2 digits; one suite
    row uses 17 digits.

## 11. Files

| Part | Files |
| --- | --- |
| Candidate specification, claims, bridge, subject list | `certificate/` |
| Checker core | `impl/BookingCertificate.dfy` |
| Issuer, sink, encoding, runner | `ts/booking-certificate/` |
| Optimizers (untrusted) | `guests/booking/` |
| Wrong cores, suites, reference, batches | `tests/booking-certificate/` |
| EXIT script | `scripts/exit_slice3.py` |
| This packet | `proposals/forge2-slice3-runtime-certificates/` |

Reused unchanged: `proposals/forge2-pillar3-dual-certificate/BookingDualCert.dfy`
and `finality/solvers.ts`; `ts/refund-finality/encoding.ts`;
`scripts/spec_clearing.py`; `impl/Booking.dfy`.

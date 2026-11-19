# Refresh of the 45-link assurance graph after the night shift of 2026-11-19

CURRENT none. Stage 9 deferred. Stage 12 unauthorized.
`end_to_end=false`. **Verdict: M1-B OPEN.**

This file refreshes [TOP_LEVEL_GRAPH.md](TOP_LEVEL_GRAPH.md) (sections 2,
7, 8 and 9). That file is NOT edited: its bytes are named in the binding
manifest draft. Read this file after it.

The integrator wrote this file by READING the three final records:
[orch-A/FINAL.md](../night-shift-20261119/orch-A/FINAL.md) (section 4 is
the source of rows X1 to X16, S4 to S7, V4, V5),
[orch-B/FINAL.md](../night-shift-20261119/orch-B/FINAL.md) and
[orch-C/FINAL.md](../night-shift-20261119/orch-C/FINAL.md). The
integrator ran no proof for this table. It proves nothing. A row is only
as good as the evidence named in it.

Rules for every row:

- Class is one of MACHINE-CHECKED (MC), ASSUMPTION, TESTED-UNPROVED (TU),
  MISSING. The class of a row is the class of its WEAKEST part. A
  machine-checked sub-part does not raise the row.
- Every HOL result: MODEL level, same machine, stored older parent
  theories, not a clean replay, not an independent-machine replay.
- Every Dafny result: a source-level result about a MODEL. None is bound
  to the running TypeScript by proof.
- "Hardened" code (sink, minter, dispatcher, provider adapter) is NOT on
  `main` and is NOT applied by this pull request. It is the unapplied
  diff `../night-shift-20261119/unapplied/hardening-B-12d634f6.diff`.
  A test result for hardened code says nothing about the merged code.
- "Reviewer", "red team" and "independent" mean separate workers of the
  same model family on the same machine.

## 1. The 45 links

### Chain S (ApprovedSpec, first half)

| Link | Class before | Change tonight (evidence) | Class now | Known limit / still open |
| --- | --- | --- | --- | --- |
| S1 | MISSING | none | MISSING | no approval channel that the agent cannot forge; `main` is not protected |
| S2 | MC | none | MC (unchanged) | partial correctness only (section 7 of the graph) |
| S3 | MC | B ran the stored record again from `git archive 985f5eaf`: 1489 verified (B's morning record, section 1 row 13) | MC (unchanged) | controls that fail by "out of resource" are not refutations |
| S3a | MC | the same re-run: 1486 verified | MC (unchanged) | the recorded closure still contains the axiom's module |
| S4 | TU | none in HOL; B's `ExportBridge.dfy` (1823) and `SliceSafetyFromExport.dfy` (1892) relate the export bytes, read by a second reader, to the flat contract (Dafny model; hypothesis A6x) | TU (export file); exporter fidelity ASSUMPTION (T4) | the exporter build is absent; rebuild and byte-equal re-export NOT DONE |
| S5 | MC on 2026-11-04 only | link cases R1, R2, R3 replayed (go exit 0; second tries for R2, R3 after a path fix) | MC (replayed 2026-11-19, same machine) | clean and independent replay |
| S6 | MISSING | link cases H1, H2 (`exported_contract_on_refund_fields`, `exported_contract_exact`), H4, E0: exit 0; controls NC1 to NC6, NS1 to NS3, NR1, NB1 exit 1 as required; H1 reproduced from the branch | MC (model; same machine; run plus repeat) | `check.py` defects A and B; the export digest is not in the theorem; input encoding T4i MISSING; output decoding MISSING; H4 and E0 have no separate review verdict |
| S7 | ASSUMPTION (narrowed) | none | ASSUMPTION (BETA) | no artefact relates the Dafny and HOL semantics |
| S8 | ASSUMPTION (canonical input only) | none | ASSUMPTION | input encoding (stdin bytes to the nine values, T4i): MISSING |

### Chain X (ApprovedSpec, second half)

| Link | Class before | Change tonight (evidence) | Class now | Known limit / still open |
| --- | --- | --- | --- | --- |
| X1 | MC | none (not re-run tonight) | MC (unchanged) | clean and independent replay |
| X2 | MC | none; the go.logs of the earlier compiler-correctness chain were not seen tonight (T7 UNCONFIRMED tonight) | MC (unchanged) | the same |
| X3 | MC (model, 11 premises) | restated forms: L2-0003, L2c-0001, L2d-0001, MT-0001 (exit 0) | MC (unchanged; model) | no resource bound; premises not met by the real C (X6) |
| X4 | MC for one state, ideal environment | NV-0003: joint witness of the shape antecedent for every request, abstract environment | MC (unchanged scope) | no witness for MT1 or MG-0001; no Success-with-frame witness; no real loader state |
| X5 | ASSUMPTION | none for the entry state | ASSUMPTION | T10: ML-10 MISSING; N16 ASSUMPTION |
| X6 | ASSUMPTION, probably false | L1-0001 (totalisation); review of L2d-0001: no environment that describes the present C meets the shape contract | ASSUMPTION, FALSE as an all-states contract for the present C | owner item A-3 (C patch, or R6) |
| X7 | MISSING | L1-0001, L2-0003, L2b-0003, L2c-0001, L2d-0001, MG-0001, MT-0001; R6 pieces R6base-0001, R6ffi-0002, R6w-0004, R6r-0004, R6t-0004 (exit 0 each) | MISSING | R6 main specification, state facts, link to machine `io_events`, "no close/open_in"; native contract at valid calls is an ASSUMPTION |
| X8 | MISSING | generic trace core only: TR1-0001, TR2-0001; MT-0001 is the model target | MISSING | **the smallest missing refinement boundary**: statement draft v3 by reading only; ML-01 to ML-15: none stored; x8glue draft NOT RUN; 23 native rows (17 ASSUMPTION, 6 enforced by an unverified prototype) |
| X9 | MISSING | LO-0006: model I/O events to `fd1_written`, under premises that include `refund_env_ok_sl` (false for the real C) | MISSING as a row (model part MC; owner item A-2 pending) | real descriptor-1 bytes = model bytes: inside X8 |
| X10 | MISSING | LE-0004: model halt to register value; same premises | MISSING as a row | halt-value range; real exit path; the exit status carries no proof meaning |
| X11 | ASSUMPTION | X11e sub-results: E1-0003, EF-0001, EE-0001 (one step) | ASSUMPTION; X11e MISSING | run lift ML-08, ML-09; ML-05; non-vacuity with TBI0/SA0 set |
| X12 | TU | none | TU | X8 |
| X13 | TU | PF-0004, PX-0001, NN-0002: about the HOL function `refund_strict_parse` | TU as a row | Python `frame.strict_parse` = the HOL parser: TU (T14a) |
| X14 | MC | none | MC (unchanged) | — |
| X15 | MISSING | none by proof. Prototype `launch/launcher_v2.py`: red team's 24 lifecycle tests exit 0 in 5 of 5 runs (C-LAUNCH-01 closed on v2; v1 exit 1) | MISSING (deployed path) | prototype is TU, NOT deployed, unverified Python; owner item A-5; a consumer must accept only "AUTHORIZED line AND launcher exit 0"; rows AC2-n2, AC2-n3 open; NO attack run with the real refund program (C-1) |
| X16 | MISSING | none | MISSING | the issuer calls the compiled Dafny checker, not M1 (B-6) |

### Chain U (UniqueAuthorization)

| Link | Class before | Change tonight (evidence) | Class now | Known limit / still open |
| --- | --- | --- | --- | --- |
| U1 | MC at source level | `IssueBytes2.dfy`: bytes iff the checker authorizes and the body is well-formed (Dafny model) | MC at source level (unchanged) | the compiled JavaScript is not proved |
| U2 | TU | merged `minter.ts`: unchanged on `main`. Model: `IssueAuth.dfy` 194 verified, exit 0 (one byte string per charge id and request id; a refusal changes nothing). Hardened minter (decisions D-1, D-2): B's regressions exit 0; red team re-test PASS for C-ATT-03, 05, 15, 29, 30, 38, 39, 40 | TU | the model's stored state, settled flag, pre-state hash and memory are FREE inputs (STORE-READ, G-H); KEYID-GLUE outside the model; zero-amount mint on the real state takes a request id (`m3_zero_squat_limit` exit 1); a lost mint record file gives a second valid token (MEMORY-FILE-INTACT); key check covers the last path part only (KEY-DIR-TRUSTED); OQ-H2-2 open |
| U3 | TU | **the merged `sink.ts` on `main` has two duplicate-effect counterexamples** (red team E1, E2: exit 1 on merged `4af09308`; B's regressions x1 to x6 FAIL on the merged sink). Hardened sink: db_safeguards 69 PASS; regressions exit 0; red team re-test PASS for C-ATT-02, 04, 06, 10, 11, 12, 20, 23, 24, 26, 33, 34, 35 | TU, and KNOWN DEFECTIVE on `main` until the owner applies a fix | "at most one effect per request id" for the composed system is TESTED, not proved; C-ATT-21 and 27 rest on named assumptions; C-ATT-25 closed only with the dispatcher's outside head; no migration of old stores |
| U4 | MC (model) | none | MC (model; unchanged) | — |
| U5a | MC (model, with an assumption that cannot be met) | layered byte-level lemma WITHOUT the impossible IdealMac assumption: `ControlsBytesV6`, `TopV6Export`, `KeyedV6` 2352 verified, exit 0 (approval of committed effects with no signing hypothesis at layer 0); `ShellCoreV6.dfy` 192 | MC (model) | reading CTX-SINK (owner decision B-10); H1B and B5 at layer 1; A6b or A6x; hash glue G-H; byte-layer injectivity is false for the real token |
| U5b | MISSING | hardened sink against the approved specification: 5,000 sequences x 3 modes, no violation (at `f08a21c1`). The differential against the V6 core gave NO result (harness error) | MISSING as a proof (TU on the hardened sink) | nothing is proved about any TypeScript, compiled JavaScript, SQLite or the running process |
| U6 | ASSUMPTION | decision D-1 (key file, key id, allowlist): 13 `kf_*` tests exit 0; red team's own key-file script exit 0 twice (hardened minter only) | ASSUMPTION | key custody; same-uid attacker out of the claims (SAME-UID); key-id substitution tested by B's tests only |
| U7 | TU for a process crash | hardened sink: real kill 24 rounds, 0 failures; red team crash script exit 0 after the fix | TU (process crash) | power loss NOT TESTED for sink, ledger, mint record (FS-SYNC); exactly-once delivery NOT claimed (in-doubt record for an operator); a window inside SQLite's commit remains |
| U8 | MISSING | negative results, MC: `Restart` 1686, `KeyedStore` 1820, `AttackRestart` 1831 (a rollback and a forged initial state pass any database audit). `Anchor.dfy` 61 (a rollback to a prefix is detected against an outside head; model) | MISSING at the level of approved intent | rollback resistance ONLY with the outside head AND the ledger floor (ASSUMPTIONS ANCHOR-OUTSIDE, ANCHOR-FRESH, SINGLE-WRITER); full restore without a floor re-sends effects (exit 1); provider tested with a FAKE provider only; owner items B-12, B-14, B-20 |

### Chain V (ValidArtifact)

| Link | Class before | Change tonight (evidence) | Class now | Known limit / still open |
| --- | --- | --- | --- | --- |
| V1 | MC (second extraction TU, not independent) | none | unchanged | the same |
| V2 | MISSING | none | MISSING | — |
| V3 | TU | none | TU | — |
| V4 | MISSING | none: `hash_parents.py` records parent `.dat` after the run; `inputs_unchanged_after` covers `.sig/.sml` only | MISSING | pinned definition closure |
| V5 | MISSING | reproduction from the branch: 18 of 18 cases, objects byte-equal; SAME machine, same agent family | MISSING | independent replay |
| V6 | TU | none | TU | minter identity does not bind loaded code on the `tsx` start path (C-ATT-14, 31: exit 1) |
| V7 | TU (a draft) | B's ledgers (identity and record consistency only) | TU (a draft) | — |

### Chain E (enforcement)

| Link | Class before | Change tonight (evidence) | Class now | Known limit / still open |
| --- | --- | --- | --- | --- |
| E1 | MISSING | three subset rules: rule 2 bypassed, rule 3 admits a bodiless `ensures false` lemma and refuses correct work; the JavaScript bound checker accepts modules that do not finish (C-GATE-07, 08; B's own two breaks) | MISSING | no static rule tonight is a sound safety argument; the checker is ADVISORY ONLY (B-17 correction); the gate options "warnings are errors" and the audit step are load-bearing |
| E2 | MISSING | none | MISSING | `main` is not protected |
| E3 | MC for one instance | none | unchanged | an instance, not a rule |
| E4 | MISSING | none | MISSING | one administrator identity on one machine |
| E5 | MISSING | none | MISSING | nothing is deployed |

## 2. What moved, and what did not

- Moved to MACHINE-CHECKED (model level, same machine): **S6**. Replayed:
  **S5**.
- No other row changed class. X3, X4, X7, X8, X9, X10, X11, X13, U2,
  U5a, U8 gained machine-checked SUB-PARTS only.
- Worse than recorded before: **U3** (the merged sink has two shown
  duplicate-effect defects), **X6** (false as an all-states contract).
- A count of rows is not a measure of completion and is not given.

## 3. Exact unproven transitions to `end_to_end=true`

Source: [orch-A/FINAL.md](../night-shift-20261119/orch-A/FINAL.md)
section 5 and
[END_TO_END_GAPS_v2.md](../night-shift-20261119/orch-A/END_TO_END_GAPS_v2.md),
then B's deployed-path items. AS = ASSUMPTION, MI = MISSING, TU =
TESTED-UNPROVED, EP = enforced by an unverified prototype launcher.

| # | Transition | Class | Link |
| --- | --- | --- | --- |
| T2b | the reader of the export bytes is right | AS | S5 |
| T3 | Dafny meaning of the 3 clauses = HOL meaning | AS | S7 |
| T4 | exporter fidelity (Dafny source to export bytes) | AS | S4 |
| T4i | stdin bytes = `refund_request` of the intended nine values | MI | S8 |
| T7 | compiler correctness to the exact code slices | MC earlier; UNCONFIRMED tonight | X2 |
| T8 | model run to strict parse to exported clauses | MC under premises T9 to T13 ONLY | X3 |
| T8v | the premises hold together | MC for the shape antecedent only; none for MT1; no Success-with-frame witness | X4 |
| T9 | FFI premise | MI (R6 open; native contract AS; owner item A-3) | X6, X7 |
| T10 | entry state at `cml_main` | MI | X5 |
| T11 | processor bits TBI0, TBI1, SA0, EL0, E0E | MI (one step MC; run lift MI) | X11 |
| T12 | descriptors 0 and 1 | MI (parts EP) | X15 |
| T12k | kernel read and write results = model oracle | AS (no launcher can enforce it) | X11 |
| T13 | X8: the real process refines the totalised model | **MI: the smallest missing refinement boundary** | X8 |
| T14o | the consumer reads the process's descriptor-1 bytes | AS | X9 |
| T14a | `frame.strict_parse` = `refund_strict_parse` | TU | X13 |
| T14b | the program prints non-negative amount and count only | MC at model level (NN-0002); about the HOL parser only | X13 |
| T15 | launch environment (no injected loader code; fixed environment; pinned image) | AS (parts EP; owner item A-5; NO red-team run with the real program, C-1) | X15 |
| T16 | native result to issuer decision | MI in the deployed path | X16 |
| T17 | issuer to token to sink to committed state, for DEPLOYED code | MI | U2, U3, U5b |
| T18 | trust base; clean and independent replay | MI | V4, V5 |
| T19 | the hardened sink, minter and dispatcher become the merged code | NOT APPLIED: owner decisions B-15, B-16 (changed suite expectations; new bundle digests) | U2, U3 |
| T20 | rollback and a forged initial database | AS: outside head and ledger floor, kept fresh by the host; a database cannot authenticate its own history | U8 |
| T21 | provider behaviour (key window, idempotent key, honest answers) | AS: tested with a FAKE provider only | U8 |
| T22 | durable state after power loss | NOT TESTED | U7 |
| T23 | an admitted module terminates within a bound | MI: no sound static rule | E1 |
| T24 | approval that the agent cannot forge; enforced merge rule; separate trust domains | MI | S1, E2, E4 |

One line: **X8 / T13 — "a real run of image b8ed5ec2…7bb8 that meets the
native rows is a run of the totalised machine model from `ms_27`"; its
model part (ML-01 to ML-15) has no stored lemma, and its native part
cannot be closed by HOL.** On the trust side the nearest gap is **T19**:
the fixes exist and are tested, but the merged sink is still the
defective one.

## 4. Known limits (open items; none is hidden)

Money safety (from B's final record, section c):

1. Full restore of every local file WITHOUT an outside ledger floor:
   effects are sent again (red team: exit 1).
2. Without anchors, a rollback plus the same request id with another
   amount is paid again (decision D-3 puts the amount in the provider
   key; owner item B-20).
3. Every provider property is an ASSUMPTION. After the key window a
   request id can pay twice.
4. Exactly-once delivery is NOT claimed.
5. A zero-amount mint on the real state with a victim's request id takes
   that id (no caller identity).
6. A deleted or restored mint record file brings a second valid token
   back after a restart. Power loss is NOT TESTED.
7. The key-file check covers only the last path part. A same-uid
   attacker and a party that can create files in the database directory
   are OUT of the claims.
8. No migration: stores of earlier formats and old-format tokens are
   refused.

Gate: items 9 to 12 of B's final record (the checker is advisory only;
no sound static rule; an unfinished supervised-execution lead; two
load-bearing gate options).

Judges and tests: three defective inputs passed both judges at
`cf242303`; the rebuild at `7667574c` was NOT re-tested by the red team.
`scripts/exit_m1_conformance.py` is unchanged and cannot start the new
minter.

Proof track: every weakness in section 8 of A's final record (same
machine; parents are stored older theories; 9 theorem statements elided
in the logs; `check.py` defects; a case started after the wind-down
order, disclosed there).

NOT RUN: the red team's tests with the real refund program against code
injected at load, and tests of the FFI C code (C-1: stopped by a safety
classifier seven times; never retried or rephrased); gate candidates U04
to U11 and K17; B's real-kill regression by anyone but B; any power-loss
test; the full gate with the B-17 diff; the x8glue case; the 122-row
suite of B-16 as first proposed (B later ran an adapted 126-row suite:
exit 0, with expectations the owner has not accepted).

## 5. Owner decisions that the rows wait for

A-1 (swap rule), A-2 (accept LO-0006 and LE-0004), A-3 (FFI premise: R6
or the C patch), A-5 (launch path), C-1 (who runs the native launch-path
attacks), B-12 (meaning of request-open), B-13 (id length and NUL
limits), B-14 (anchor operation), B-15 and B-16 (changed suite
expectations), B-17 (gate route), OQ-H2-2 of B-18 (store mode only),
B-20 (amount in the provider key). Text:
[OWNER_REQUIRED.md](../night-shift-20261119/OWNER_REQUIRED.md).

Decided by the owner on 2026-11-19 (recorded there by the launcher):

- D-1: persistent minter key from a checked key file; key id; allowlist.
- D-2: a minter refusal closes only that attempt, not the request id.
- D-3: local floor plus outside head is the rollback anchor; the
  provider key is a second layer.
- D-4: the JavaScript bound checker stays ADVISORY ONLY. No blocking
  gate rule comes from it. Blocking rules stay strictly sound (lexical
  checks); slow code is handled by hard time and memory limits (E1).
- D-5: rollback resistance REQUIRES both anchors: local floor AND
  outside head. Provider idempotency keys are a second layer only,
  inside their retention window (U8, T20, T21).
- D-6: C-1 stays permanently NOT RUN. The open non-critical items
  (B-12 to B-20, A-3, A-5) are the known limits of section 4; no new
  work is planned for them (X15, T15).
- Owner plan: B-15 and B-16 (changed suite expectations, with the
  hardening diff) come in ONE later pull request. Until then T19 stays
  NOT APPLIED and U3 stays KNOWN DEFECTIVE on `main`.

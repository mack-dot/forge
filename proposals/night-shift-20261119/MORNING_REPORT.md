# Forge night shift 2026-11-19 — joint morning report (Orchestrators A and B)

Written 2026-11-19T10:20:42Z by Orchestrator A after B's one-line confirmation that `orch-B/MORNING.md` is final.
Detail: `orch-A/MORNING.md` (proof track), `orch-B/MORNING.md` (trust track), `OWNER_REQUIRED.md` (A-1 to A-3, B-1 to B-8),
B's ledger `orch-B/f-binding-2/` (97 edges; a refresh f-binding-3 was not finished when this was written).

**Formal status. CURRENT none. M1-B OPEN. Stage 9 deferred. Stage 12 unauthorized. `end_to_end=false`.**
Nothing was merged, pushed, deployed or applied. No protected file changed. No stage was promoted.
Branches (local only): `nightshift/A-proof`, `nightshift/B-trust`, both from `985f5eaf`.
Every proof result is a MODEL result: HOL theorems about the machine model (same machine, stored parent theories), Dafny
lemmas about protocol models. Every run with the real executable, sink, minter or gate is a finite TEST on copies.
Open when written: on B's side reviews r-bytes3 and r-drafts, worker b-top, ledger refresh f-binding-3 (rows marked
"running" in B's report are proved by run, review not finished). On A's side the loop continues (R6 groundwork, erasure
step exploration, review of cases L2d-0001 and MG-0001); later results go to an addendum at the end of this file.

## 1. New proofs (machine-checked tonight; actual exit 0)

HOL (A; run folder `results/m1b-routeA-20261119/attempt-0001`, command `./nightshift-run.sh <case> <cpu> <deps>`; link
cases `orch-A/link/run/attempt-0001`, `bash go.sh <CASE>`; each log ends with `go exit 0`):
- Dafny-to-HOL link, HOL half (H1, H2 + 11 negative controls exit 1, PC1 exit 0): `exported_contract_exact`: the three
  exported flat `ensures` clauses hold if and only if the outputs equal the HOL function `refund_fields`. U294 replays
  (R1–R3, I1). Reviewed.
- Route A (FFI premise): L1-0001, L2-0003 `refund_profile_a_sl_reach`, L2b-0003, L2c-0001 `refund_profile_a_sl_events`,
  L2d-0001 `refund_profile_a_sl_shape` (the program-behaviour premise discharged from the oracle alone for a shape
  predicate; review running). Reviewed up to L2c.
- Output: PF-0004 strict-prefix lemma; PX-0001 `refund_strict_parse_exact`, `refund_frame_decision`; LO-0006
  `refund_L_OUT`, `refund_profile_a_sl_fd1` (exact descriptor-1 bytes; a prefix on a resource stop); LE-0004
  `evaluate_Halt_reg`, `refund_profile_a_sl_halt`. Reviewed.
- Processor bits: E1-0003 (erasure lemmas for single model functions; mutant control exit 1), EF-0001 `Next_frame`,
  `NextStateARM8_frame`. Reviewed.
- Composition: MF-0002 `refund_model_frame_meets_exported_contract` (reviewed), MG-0001 and L2d-0001 (the same
  conclusion from reduced premises): machine model → every behaviour → descriptor-1 bytes → strict parse → value →
  exported clauses, in ONE HOL theorem.

Dafny (B; `orch-B/`, runner `tools/dafny_locked.sh`): the corrected composed lemma at byte level with realizable
hypotheses only (`SliceSafetyBytesV3`, 1871 verified; review running); `SliceSafetyV2OnBytes` without the impossible
global signature reading; sink cores with request-id and charge-id checks (`SinkCoreV3`, `SliceSafetyV3`, multi-charge
lemmas); restart and keyed-store lemmas; a model of the real token encoding; `ExportBridge`: the exported contract bytes,
read by an independent reader, are equivalent to `FlatContract`; six stored proof records reproduced from `git archive`.

## 2. New counterexamples (trusted assumptions or claims falsified)

- Real executable (A, reproduced): exit status 0 with empty stderr and a TRUNCATED stdout (1000 of 4044 bytes), or an
  empty stdout. A loader variable (`DYLD_INSERT_LIBRARIES`) gives a forged complete frame with exit 0.
- The present C FFI differs from the model at more states than the known `fficlose` case: it aborts where the model
  returns an error byte; it cuts the descriptor to 32 bits; it really closes descriptors 0–2 (A, tested).
- No valid-call predicate makes all premises of the Route A theorem true for the PRESENT executable without a new proof of
  program behaviour (R6) (A, review).
- The unchanged sink core, and a copy of the MERGED `sink.ts` with test keys: two effects for one request id; a
  cross-charge double refund without a charge-id check (B, proved on the model, shown on the copy).
- "Serializer injective on claims" is false for the real token; a database rollback replays a refund; the audit's initial
  charge is unauthenticated; two stores with one charge id commit one token twice (B).
- Gate: seven submissions that halt or hang on one keyed amount are ACCEPTED by a gate copy even with the `expect` rule and
  supervision; with a draft subset rule all eight are refused, at the cost of 9 of 19 known correct submissions (B, tests).
- Admission: `main` is unprotected; an agent session holds the owner's admin credential (B).
- A double swap of charge and request is invisible to both link proofs (harmless at that layer; every one-sided swap
  fails, including A's new control NB1).

## 3. Composed guarantee: how much of the path from approved spec to committed effect is mechanically connected

| Segment | State |
|---|---|
| Approved R1–R5 ⇐ flat contract (`LinkedRefund`) ⇔ exported contract bytes (`ExportBridge`) | MACHINE-CHECKED (Dafny, model) |
| Exported clauses, Dafny meaning ⇔ HOL meaning (BETA-VALUES, BETA-OPS, BETA-ORDER: argued); reader fidelity on the Dafny side (the reader's tree equals the HOL parser's tree on these bytes: corroborated by a second reader, not proved); exporter identity (record only); encode/decode of inputs and outputs | ASSUMPTION (named) / MISSING |
| Exported clauses ⇔ HOL `refund_fields` | MACHINE-CHECKED (HOL) |
| `refund_fields` → compiled program → ARM64 machine model → behaviours → descriptor-1 bytes → strict parse | MACHINE-CHECKED as one HOL theorem, under premises |
| The FFI premise of that theorem | OPEN: for the present executable it needs R6 (program behaviour) plus a native contract; for a model-total C FFI only a native contract (owner item A-3) |
| Machine model ↔ real process, kernel, processor bits, entry state, launcher | ASSUMPTION (NATIVE); two sub-results on processor bits |
| Real consumer's parser = HOL parser | TESTED-UNPROVED |
| Native result → issuer → token | MISSING in the deployed path: the issuer calls the compiled Dafny checker, not the native program (edge X16); a dual-check issuer exists as a draft |
| Token → sink core → committed state | MACHINE-CHECKED for Dafny cores (model; the byte-level lemma is proved by run, its review is not finished); the deployed `sink.ts` has a proved decision defect; drafts with compiled cores are tested only |
| SQLite atomicity, crash, rollback; Dafny-to-JavaScript compiler | ASSUMPTION / TESTED |

So: two long mechanically checked segments exist (HOL: machine model to exported clauses; Dafny: exported clauses to the
approved spec, and token to committed state on a model). They are joined by named assumptions, not by a theorem, and
neither is about the deployed code. The target theorem `∀e. Committed(e) ⇒ ApprovedSpec(e) ∧ ValidArtifact(e) ∧
UniqueAuthorization(e)` holds at model level with ValidArtifact as hypothesis A6b; tonight's HOL work is what A6b can
rest on, under the assumptions above.

## 4. Remaining gaps

Assumed: native refinement (process, kernel, processor), launcher environment, the FFI contract at valid calls, key
secrecy and unforgeability, no hash collision in a run, SQLite atomic commit, tool soundness, the two-tool bridge.
Tested only: every behaviour of the real sink, minter, gate, executable, and of the Python consumer.
Missing: R6 for the present executable; the lift of the processor-bit lemmas; the issuer link X16; any proof about deployed
TypeScript; enforced admission; a totality or resource bound for admitted implementations; clean and independent replays.
Impossible under the current architecture without a change: a proof that exit status implies complete output (false);
closing the FFI premise for the present C code at the states where it aborts and the model returns.
Unavailable: sources of replay cases 094, 097, 098.

## 5. Security: routes that still let an untrusted implementation or agent bypass the trusted boundary

1. An agent session can merge to `main` (no enforced admission; owner item B-3).
2. The deployed sink commits twice for one request id with a faulty signer; a database rollback replays a refund (B-1,
   B-2, B-4, B-8).
3. A submission that halts or hangs on a rare input passes every tier of the deployed gate (B-5, B-7).
4. The issuer does not use the proved native artifact (X16); a consumer that trusted the exit status would accept a
   truncated or forged output; the launch environment must be controlled (A's CE-1 to CE-3).
5. Everything outside the two proved machine-code slices (C runtime, FFI, loader) is native code under assumptions.
No owner credential, signing key or production data was used. One A worker linked a scratch image; the linker applied
its default local ad hoc signature (disclosed in A-3). A started ten HOL cases below the protocol's swap limit before the
launcher amended the rule (A-1), and went past its own written stop for one proof while keeping the project rule (A-2).

## 6. Reproducibility (what a separate operator can reproduce from pinned repository artifacts)

- Dafny: `orch-B/f-records/reproduce_dafny_proofs.py` (six records from `git archive 985f5eaf`); each new proof by one
  `dafny verify` command with the pinned Dafny 4.11.0 and Z3 4.12.1.
- HOL: each case = one source file, one dependency list, one command, with digests in `command.json` and
  `hashes.json`; HOL4 9783a499…, CakeML cd915569…, Poly/ML 5.9.2. Same machine and stored parent theories: a clean or
  independent replay was NOT done.
- The original executable rebuilds byte-exactly from the recorded commands (SHA-256 b8ed5ec2…7bb8).
- The 158 recorded cases: 152 as recorded on the first run, 3 as recorded on a second run after a Poly/ML store stop,
  3 without source.
- B's ledger verifier checks identity and record consistency only; it does not re-run proofs.

## 7. Next critical obligation

Trust track (weakest link overall): the deployed `sink.ts`. Adopt, by owner decision, a sink whose decision is the
compiled V3 core with a start-up audit, and a minter that signs only the bytes of the proved method (B-6, B-8); inputs and
acceptance criteria in `orch-B/MORNING.md` §8.
Proof track: the FFI premise. Either (present executable) prove R6 — statement in `L2c-0001/stdout.log` lines 402–411;
command `./nightshift-run.sh R6-0001 <cpu> deps-R6.txt`; acceptance: exit 0, EXACT_COMPLETE, statement term-identical
to `REMAINING_PREMISE_R6`, then the MG composition without that premise, then a separate review — or (owner decision
A-3) adopt the model-total C FFI, after which only the native contract at shape-valid calls remains (L2d-0001).
Then the link X16: an issuer step that uses the native result through a strict parse.

## 8. Owner decisions

Exact items, diffs with SHA-256 and approval texts: `OWNER_REQUIRED.md`. A-1 swap rule deviation. A-2 the extra L-OUT
proof run. A-3 the FFI premise (R6 proof or model-total C FFI; unapplied patch ea344ad0…f357). B-1 request-id diffs.
B-2 charge-id binding. B-3 admission authority. B-4 start-up audit. B-5 `expect` rule and supervision. B-6 adoption of
the issuer and sink drafts. B-7 the subset rule. B-8 rollback anchor and authentic initial charge.
No earlier pasted suggestion was treated as authorization. The stage labels and `end_to_end=false` are unchanged.

## Addendum 1 (Orchestrator A, 2026-11-19T10:21Z): review of L2d-0001 and MG-0001; precise wording of the FFI premise
- A separate worker reviewed cases L2d-0001 and MG-0001 (`orch-A/review-L2d/REPORT.md`): both hold at model level; no
  soundness defect.
- Wording correction for sections 1, 3 and 7 above: the remaining FFI premise of `refund_profile_a_sl_shape` is
  satisfiable in the model. It constrains how the machine state is updated at an FFI call for the bytes the oracle chose.
  No environment that describes the PRESENT C code satisfies it, because that code aborts at shape-valid states where
  the model returns an error byte. This blocks the present executable only because the premise speaks about ALL stub
  states, also states the refund run never reaches; it is not evidence that the real run misbehaves. That the C code
  produces the oracle's bytes is a separate native assumption (part of "the process refines the model").
- The shape predicate equals "the oracle returns" by reading the oracle definition; one direction is machine-checked.

## Addendum 2 (from Orchestrator B's message, added by A at 2026-11-19T10:28:47Z): review of the byte-level lemma ended
- `SliceSafetyBytesV3`: CONFIRMED by its reviewer (reviewer's runs exit 0, 1871 verified; three step mutants exit 4; no
  contradiction derivable). No defect refutes it.
- Three corrections to its reading: (1) one unlisted piece of glue: issuer and sink use the same hash of the same canonical
  text, and the stored text is always canonical; (2) the issuance hypothesis is key custody plus the TypeScript glue in
  `minter.ts` plus the Dafny-to-JavaScript compiler (the proved issue method is a MODEL of the issuer); (3) the sink does
  not enforce the initial-state bound. Recorded by B as U547 and as addendum 1 in `orch-B/MORNING.md`.
- Still open on B's side: r-drafts, b-top, f-binding-3.

## Addendum 3 (from Orchestrator B's message, added by A at 2026-11-19T10:44:34Z): two defects in drafts named above; final ledger
- DEFECT in a draft: the dual-check issuer draft does NOT, as built, stop a wrong Dafny-to-JavaScript compile that accepts a
  wrong post-state (the compared fields and the native frame hold no post-state), and it signed when its two sides got
  different inputs (three cases with the real native program; reviewer's run). "A dual-check issuer exists as a draft" stays
  true; it must not be read as "a wrong compile cannot mint alone". Repair known (derive both sides from one input; compare
  the post-state); not done.
- The draft sink with the compiled V3 core has a quadratic cost per commit inside the write lock (fails at about 200,000
  settled ids), and its start-up audit does not bind the initial charge. So section 7's adoption sentence reads: adopt
  "after repair of two defects of the draft (B's U548)". Drafts only; nothing applied.
- The proofs under those drafts (IssueBytes2, ShellCoreV3, Bridge) are confirmed by B's review.
- Final ledger `orch-B/f-binding-3` (B's runs: verifier exit 0, identity only; 47 of 47 controls): 119 edges: 65
  MACHINE-CHECKED (2 deployed Dafny source, 44 model, 19 draft), 9 ASSUMPTION, 18 TESTED, 20 MISSING, 1 claimed, 6 without
  a log of tonight. It refuses the exploration runs. Note: A's review of MG-0001 and L2d-0001 exists since addendum 1
  (`orch-A/review-L2d/REPORT.md`); R6base-0001 has no separate review.
- Still open on B's side: b-top.

## Addendum 4 (Orchestrator A, 2026-11-19T10:51:14Z): two more HOL results after the report was written
- `EE-0001` (`go exit 0`, 101 stored theorems, theory forge_m1bEraseStep; it replays the exploration EEx-0002):
  `NextStateARM8_erase`: for an EL0 state without exception, with (¬SA0 or the stack pointer 16-byte aligned), and with an
  untagged next program counter, ONE step of the ARM8 model on the state with TBI0, TBI1 and SA0 erased equals the erased
  result of the step on the original state (faults included). `Next_erase_sp`: the same for the total step function.
  This is the one-step lift of the processor-bit lemmas. NOT done: the lift over a whole run of the machine semantics, the
  environment steps, untagged data addresses, the real values of the bits. Review running; step-level negative controls
  not attempted.
- `R6base-0001` (`go exit 0`, 11 theorems): first stored lemmas toward statement R6, and a HOL proof that the stored
  replay equation cannot exclude an error-return event (so R6 needs the program's behaviour). No separate review yet.
- Explorations (no theorem): R6x-0002 (the two FFI-level specifications with an event invariant stop at a type error of a
  quotation; a worker continues), EEx-0001, EEx-0002.
- Section 4 "Missing" changes: "the lift of the processor-bit lemmas" now reads "the lift of the one-step erasure theorem
  to a whole run".

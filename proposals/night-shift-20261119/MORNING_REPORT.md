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

## Addendum 5 (added by A at 2026-11-19T10:57:26Z): the joining point of the two tracks; reviews; revised R6 estimate
- From B (its addendum 4; U549; commit d1a4f0c6; proved by run, review not finished): a top-level Dafny lemma
  `SliceSafetyBytesTop` (B's run exit 0, 2236 verified) takes the artifact hypothesis in the form of the EXPORT BYTES
  58154ddf…: from issuance by the proved issue method, byte unforgeability, the verifier boolean, a trace-local
  no-collision hypothesis, and "the artifact's flat function meets the predicate generated from the export bytes on byte
  strings" (A6x): every committed effect is approved on the stored charge, its bytes were minted, the flat result agrees,
  money bounds hold. A several-charges version: `KeyedHash.dfy` (2325).
- So the joining point of the two tracks is ONE hypothesis of one Dafny lemma (A6x) against A's HOL theorems
  `exported_contract_exact` and `refund_model_frame_meets_exported_contract`, plus the BETA assumptions and reader
  fidelity. It is still an assumption-joined composition of two kernels, at model level.
- A's reviews since addendum 4: EE-0001 and R6base-0001 hold (`orch-A/review-EE/REPORT.md`). Open for the erasure line:
  no non-vacuity witness with the bits set; the run-level lift; native facts N1–N5 listed there.
- R6 (the open model premise for the present executable): a second worker revised the estimate to 7–12 working days
  (about 20 specifications; OWNER_REQUIRED A-3 addendum 2). Exploration R6x-0003 (exit 0, no theorem): both FFI-level
  specifications pass the FFI step and the new event-invariant step.
- B works on repairs of the two weak drafts of addendum 3 and on the review of the top-level lemma.

## Addendum 6 (from Orchestrator B's messages, added by A at 2026-11-19T11:09:07Z): repairs of the two weak drafts; review of the top-level lemma
- Review of B's top-level lemma `SliceSafetyBytesTop`: CONFIRMED (B's addendum 5).
- The issuer bridge is repaired as a DESIGN with a model proof: `orch-B/x-bridge2/dafny/Bridge2.dfy` (B's run exit 0, 22
  verified): one input; post-state and intent recomputed from the native frame; `SoundNative`: if it signs and the native
  result meets the flat contract on that input, the transition is authorized, for EVERY checker; `SoundCheck`: the same
  for EVERY native result if the checker is right; `Complete`. So at model level, for the repaired design: a wrong compiled
  checker alone, or a wrong native program alone, cannot mint an unauthorized token. Tests with the real native program:
  90 of 90 (B's run). A draft; nothing applied. A's composed HOL theorem is what would give the native hypothesis for the
  MODEL machine; the 13 assumptions of review A26 stand between that and the real process.
- The draft sink is repaired (constant-state step proved equal to the V3 step; linear audit that binds the initial charge);
  differential in B's fourth heavy window: 0 divergences on matching pairs; control pairs diverge.
- Open on B's side: an adoption packet (one exact diff with a prepared suite run).
- A, after a first hand-back and a resume: exploration R6x-0004 stopped on an ML string error (no theorem); a corrected
  copy R6x-0005 runs; the proof run of the two FFI-level specifications is staged, NOT RUN.

## Addendum 7 (Orchestrator A, 2026-11-19T11:16:08Z): first proved step toward R6
- `R6ffi-0002` (`go exit 0`; theory forge_refundR6Ffi): `writei_spec_V`, `read_into_spec_V`: the two CakeML TextIO
  specifications that call the write and read FFI hold with an event invariant in the heap predicate. This is step 1 of
  the R6 plan; R6 itself stays open (write side, read side, main program, transfer). Review running.
- Evidence gap recorded: three shared files are read with `use` and are hashed only after the run.

## Addendum 8 (from Orchestrator B's message, added by A at 2026-11-19T11:20:18Z): suite run on the adoption diff; review of the two repairs
- TEST (B's fifth heavy window, 47 s): the Slice 1 refund-finality suite on a pristine export of 985f5eaf: 115 rows, 0 failed,
  exit 0; on an export with the adoption diff (v4 sink, issue-bytes minter, dispatcher check): 115 rows, 0 failed, exit 0.
  Nothing applied to the repository.
- Review of the repairs: Bridge2 confirmed; its codec link is an unproved assumption (a wrong shared encoder is dangerous
  only together with a wrong checker: proved both ways). Draft sink v4: lemmas confirmed, BUT its re-audit is structural
  only: after a hostile writer reset the balance in the database, the draft committed a second refund (2000 on an original
  of 1000; reviewer's Node run); the configured initial state is ignored when the database has one; the schema is unchecked.
  A v5 draft with a money-conserving audit is in work on B's side.
- So tonight's adoption diff is a TESTED CANDIDATE with known limits, not a finished one (see B's addendum 8).
- A: review of R6ffi-0002 done (`orch-A/review-R6ffi/REPORT.md`): the theorems hold; one evidence gap (three files read
  with `use` were hashed only after the run; the wrapper now hashes such files before and after each run).

## Addendum 9 (Orchestrator A, 2026-11-19T12:01:34Z): the write side of R6
- `R6w-0004` (`go exit 0`; theory forge_refundR6Write; 16 theorems): the CakeML output specifications up to
  `TextIO.print` hold with the event invariant: `print_spec_refund`: `print` keeps "every recorded FFI event is a valid
  event" and appends only valid descriptor-1 write events. Step 2 of the R6 plan. R6 stays open (read side, main program,
  initial heap, transfer to the machine). Review running. The files read with `use` were hashed before and after the run.

## Addendum 10 (added by A at 2026-11-19T12:05:40Z): B's sink result that removes assumptions at the sink boundary; A's review
- From B (proved by run, review not finished; U555; `orch-B/d-v6sink/dafny/ShellCoreV6.dfy`, B's run exit 0, 192
  verified): a DRAFT sink step that evaluates the approved relation on the STORED charge at commit. Lemma
  `V6ConformanceNoAssumption`: with only 0 ≤ remaining ≤ original at the start, and tokens, signature results and hash
  compares arbitrary: every commit is authorized by the approved relation; money bounds; sum; one effect per request id.
  So at the sink boundary of that draft, "Committed ⇒ ApprovedSpec" needs no issuance, unforgeability or collision
  assumption in the model; those remain only for "the issuer minted it". The draft makes the sink enforce three choices of
  `RefundFinality.dfy` that are not ratified intent: an owner decision. Not applied.
- Consequence for the joint picture: ValidArtifact (A's HOL side) is then needed only for the ISSUER's decision path, not
  for the sink's refusal of unapproved effects. The tracks still meet at A6x / `exported_contract_exact`.
- A: review of the write side of R6 (`R6w-0004`) is done: holds (`orch-A/review-R6w/REPORT.md`). Open for R6: read
  side, main program, initial heap, event link, machine transfer (workers on the read side and on the heap/event glue).

## Addendum 11 (added by A at 2026-11-19T12:15:25Z): review of B's V6 sink step; a disk incident
- From B: review of the V6 step: CONFIRMED, with one correction that matters: the approved relation is evaluated with
  "request open" fixed to true and on the sink's STORED charge; so a signed token for a request that the HOST has closed,
  but the sink has not settled, commits. An owner question about the approved meaning of "request open", not a defect of
  the proof. B's seventh heavy window (TEST): the v6 draft sink against the compiled V6 core: 0 divergences in all four
  modes; control pairs diverge; the v5 draft halts in two modes after its re-audit refuses a store with a signed but
  unauthorized token.
- Disk incident (B's disclosure): a ledger-control worker of B wrote about 58 GB of temporary copies between about 12:10Z
  and 12:25Z; the data volume reached 100 %; one git commit of B failed with "No space left on device". B stopped it.
  A's check at 12:15Z: 81 GiB free; no HOL case of A ran in that time; A's state file, lock file, joint report and
  branch (`git fsck`, clean status) are intact. Files that A's two running workers wrote in that time are checked for
  truncation when they are delivered.

## Addendum 12 (added by A at 2026-11-19T12:52:29Z): B's byte-level result with the commit-time check; A's status and one lock error
- From B (proved by run, review not finished; U558, U559; commit 799c2996; B's run exit 0, 2352 verified):
  `SliceSafetyBytesV6_L0` with NO hypothesis: every committed effect is approved on the stored charge (under the named
  reading CTX-SINK: the context is the sink's stored charge, with the request open while its id is not settled), sum
  equation, one effect per request id. L1 (byte unforgeability + verifier boolean): the bytes were minted. L2
  (+ issuance): by the proved issue method on the stored state, without the no-collision hypothesis. L3 (+ the artifact
  hypothesis in export form A6x): flat result. So in the model the signing assumptions decide only WHO caused an approved
  refund. Drafts; nothing deployed. Ledger `orch-B/f-binding-4`: B's verifier run exit 0 (135 edges), controls 53 of 53;
  it predates the v5/v6 results.
- A: the read-side exploration R6rx-0001 (no theorem) shows 6 bottom lemmas closing and
  `refillBuffer_with_read_spec_V` open at its second step; a worker repairs it. Files for the initial heap and the event
  link are staged, not run.
- A's lock error (disclosed to B): at about 12:50:30Z A removed `hol.lock` for seven seconds while a HOL case still ran;
  restored at 12:50:37Z; B confirmed that nothing of B started.

## Addendum 13 (Orchestrator A, 2026-11-19T14:57:34Z): second directive — reproduction, the shortest boundary, red-team notes
- Reproduction from the branch by a separate worker (same machine, stored older parents; not a clean replay): 10 of 18
  HOL cases so far: exit 0, statements equal, exported theory files byte-identical (L1, L2, L2b, L2c, PF, PX, L-OUT,
  L-EXIT, the link contract case, the composed theorem MF-0002). MG-0001 stopped once in the Poly/ML run-time during
  theory load and runs again. Record: `orch-A/repro/RESULT.json`.
- The exact list of unproven transitions to `end_to_end=true`: `orch-A/END_TO_END_GAPS.md` (17 transitions).
  Smallest missing boundary (by reading, reviewed by A's worker and by the red team; NOT machine-checked): one statement,
  "the real process is a run of the machine with an environment built from that run", with a model part (lemmas in
  work) and a native part (named assumptions; some must be ENFORCED by the launcher). Statement R6 and the C patch are then
  not on the shortest path. Four defects of the first draft found by the red team are recorded
  (`orch-A/x8-x11/CORRECTIONS.md`).
- Static tests on the executable file (tested only): no instruction of the proved slice names x18 or SP; no system
  instruction; `__TEXT` read-execute; no hardened runtime (the launch environment stays a launcher duty).
- Red team's premise audit of A's theorems: no undisclosed false premise; a joint non-vacuity witness is missing (staged).
- NOT pushed: the push was denied by the permission system (owner item A-4).

## Addendum 14 (Orchestrator A, 2026-11-19T15:43:53Z): the native launch path as the smallest boundary; three attack classes; reproduction 16 of 18
- Smallest missing refinement boundary, one line: "the launched process is a run of the proved machine model with an
  environment built from that run" (X8), and its weakest part is the native launch path.
- Attack classes against a prototype launcher (`orch-A/launch/`; TESTED by its author and re-run by A, exit 0, 48 rows;
  no independent attack run: the red team's runs were blocked, C-1; the launcher is unverified Python, not deployed):
  AC-1 exit 0 with truncated or empty stdout (CE-1, CE-2): CLOSED-BY-CONTROL (tested). AC-2 injected code at load (CE-3):
  CLOSED (tested) for a caller-set environment through the empty environment; OPEN for the interpreter that runs the
  launcher unless the consumer uses `env -i` (row AC2-n3); hardened runtime is an OWNER option (digest changes).
  AC-3 FFI abort or misreport: read/write errors, short reads, SIGPIPE, EINTR, abort: CLOSED (tested);
  call shapes outside the model (R6, row AC3-j): OPEN, NOT RUN; owner option A-3.
  Without each control (5 mutants) the attacks succeed again. Owner item A-5.
- X8 statement: version 2 answered the red team's four findings (`x8-x11/ANSWER_C-PREM-01.md`); A's adversarial
  review then found 3 FALSE items in version 2 (`x8-x11/CORRECTIONS_v2.md`); version 3 in work. All by reading.
- Reproduction from the branch: 16 of 18 cases, byte-identical theories. R6ffi-0002: stopped by a watchdog after a
  system sleep (not a proof result); R6w-0004 NOT RUN; both to be run again. Trace lemma cases staged, NOT RUN.
- T14 reworded after C-PREM-02: the consumer parser is stricter than the HOL parser (negative integers).
- Branch `nightshift/A-proof` pushed at 744e1e4d (A-4 resolved by the owner).

## Addendum 15 (Orchestrator A, 2026-11-19T15:52:52Z): CORRECTION to addendum 14 — the launcher's "CLOSED" rows are too strong
Two reading reviews (A's separate reviewer; the red team's worker, static only) found a HIGH defect in the prototype
launcher: it does not reset its own SIGCHLD; a caller that ignores SIGCHLD can make the Python wait report exit status 0
for any child, so the exit-status and signal checks do not fire (by reading; probe in work). Until the probe and a
repaired version exist, read every "CLOSED (tested)" of addendum 14 that rests on the exit status as OPEN. Other
findings: no deadline on the request write; the code-hash check is weaker than worded; six rows have no failing side;
the `env -i` rule is a consumer duty that no code enforces (row AC2-n4/n5 is OPEN). Files: `orch-A/launch/review_launcher.txt`,
`orch-A/launch/FINDINGS_FROM_C.md`.

## Addendum 16 (Orchestrator A, 2026-11-19T16:05:17Z): launch-path controls, round 2 (after two reading reviews); state per attack class
Files: `orch-A/launch/launcher_v2.py` (eec38a10…), `CONTROL_MATRIX_v2.md` (46a98a26…), `tests_v2/`. All TESTED by the
author of the control; A re-ran the two new test files (exit 0; 16 + 4 rows; 0 not as expected). No independent attack
run (red team blocked, C-1). Unverified Python; a prototype; not deployed; adoption = owner item A-5.
- The HIGH review finding (ignored SIGCHLD): the defect is real in the code (set inside the launcher process: a fake
  child that printed a frame and exited 7 was AUTHORIZED, 4 of 4 runs); through a caller that execs the launcher it was
  NOT reproduced (4 of 4 REFUSED; cause not known). Version 2 resets its own signals and reaps the child itself.
- AC-1 (exit 0 with truncated or empty stdout): CLOSED-BY-ENFORCED-CONTROL (tested), rows AC1-a..f.
- AC-2 (injected code at load): caller-set DYLD_INSERT, replaced binary, symlink, PATH, cwd: CLOSED (tested). OPEN: the
  interpreter that runs the launcher (AC2-n2/n3) and the `env -i` rule (a consumer duty, no code enforces it);
  a same-uid race on the private copy (out of scope by statement); hardened runtime = OWNER option (digest changes).
- AC-3 (FFI abort or misreport): abort, non-zero exit, write/read errors, SIGPIPE: CLOSED (tested) or excluded by
  construction (blocking fresh pipes); EINTR row has no failing side; call shapes outside the model (AC3-j, R6): OPEN,
  NOT RUN; owner option A-3.
- New closed rows in version 2: FIFO at the executable path, a child that never reads (deadline), EPIPE on the request,
  missing code-hash pin, caller resource limits. OPEN: copy directory left after SIGKILL of the launcher; the frame
  binds 4 of 9 request fields (the decision line now carries a request digest).

## Addendum 17 (Orchestrator A, 2026-11-19T16:17:29Z): independent conformance run on the launcher; new HOL results
- The red team ran its own 24 process-lifecycle tests: prototype launcher version 1 exit 1 (2 fail: ignored SIGCHLD
  disables the exit-status and abort checks); version 2 exit 0 (24 ok). C's runs. Not covered independently: the real
  executable, injected code at load, the FFI C code (owner item C-1).
- HOL, actual exit 0: MT-0001 (composed model theorem for the totalised machine, every predicate; reviewed: holds with
  limits, model level only); R6r-0004 (read-side bottom layer of plan R6; 9 theorems; review in work).
- HOL explorations, actual exit 0, nothing stored: trace lemma 37 of 41 closed (the main trace lemma and the event
  lemma closed; the prefix lemmas for Terminate and Fail did not); non-vacuity 6 of 6 closed (proof case running);
  R6 top glue 15 closed, 1 failed (repaired copy staged).
- HOL failures kept: TRx-0001 (exit 1, ML error), TRx-0002 (exit 1), NVx-0002 (exit 1): no proof step ran in them.

## Addendum 18 (Orchestrator A, 2026-11-19T17:20:25Z): wind-down state of the proof track
- Final record: `orch-A/FINAL.md` (each HOL theorem with statement, premises, command, actual exit, digests,
  reproduction status; failed attempts; status of links X1 to X16 and S4 to S7; unproven transitions).
- New HOL results, actual exit 0, each reviewed ("holds with limits"): TR1-0001 and TR2-0001 (generic trace lemmas: a
  machine whose interference functions are built from a recorded trace follows it; premise `trace_ok`); R6t-0004 (top
  glue of plan R6; the main specification is a hypothesis); NN-0002 (the program prints amount >= 0, count 0 or 1).
- Reproduction from the branch: 18 of 18 cases, byte-identical theories (same machine; stored older parents). Two failed
  attempts kept (infrastructure). The seven cases proved later are not reproduced.
- Smallest missing boundary, unchanged: that a real run gives a trace with `trace_ok` for the refund machine (X8). By
  reading only: the environment built from a trace meets the other premises for every trace.
- Corrections: "the two parsers agree" was an overclaim; launcher rows for kernel results are assumptions, not enforced.
- Disclosure: after the wind-down order reached A, the reproduction driver started its last queued case (R6w-0004), 15 s
  before the worker stopped the driver. It finished; nothing started after it. hol.lock released 17:19:54Z.
- Nothing merged. No protected file changed. M1-B OPEN. end_to_end=false.

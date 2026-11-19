# One top-level theorem and one dependency graph (M1-B mission, step B7)

CURRENT none. Stage 9 deferred. Stage 12 unauthorized.
`end_to_end=false`. **Verdict: M1-B OPEN.** This file is the
orchestrator's join of the worker reports under [reports/](reports/).
It proves nothing. A row is only as good as the evidence named in it.

## 1. The target

The owner's target (text 5 of the
[decisions file](../m1-owner-review-20261119/OWNER_DECISIONS.md)), for
ONE narrow refund slice and for the ACTUAL execution system:

> for every effect e: Committed(e) ⟹ ApprovedSpec(e) ∧ ValidArtifact(e) ∧ UniqueAuthorization(e)

No such theorem exists. No tool states it. The three conjuncts break
into the four chains below. Two labels are used for the execution
part, in the exact sense of [drafts/M1_EXACT_CLAIM.md](drafts/M1_EXACT_CLAIM.md):

- **verified machine-model behaviour**: what the HOL4 theorem
  `refund_profile_a_sl` establishes, about a mathematical machine that
  holds the code bytes, under 11 premises. This EXISTS (same-machine
  replay).
- **verified native execution**: a theorem about runs of the real
  process. This DOES NOT EXIST, and HOL work alone cannot reach it: the
  step from the real process to the model stays an assumption that
  proof work can only make small, specific and falsifiable.

## 2. The graph

Class is exactly one of: MACHINE-CHECKED (a tool ran and a record
holds its exit), ASSUMPTION (with the owner decision that covers it,
or "not approved"), TESTED-UNPROVED (a finite test), MISSING (no
statement and no test).

### Chain S: from the approved contract to the HOL functions (ApprovedSpec, first half)

| # | From | To | Statement | Class | Evidence | What would upgrade it |
| --- | --- | --- | --- | --- | --- | --- |
| S1 | the owner's intent | the approved spec on `main` | none | MISSING | no approval channel exists that the agent cannot forge (report B5) | an owner signature over the exact digest, made with a key that the agent cannot use |
| S2 | approved `RefundSpec.Assess` (R1 to R5) | `impl/Refund.dfy` | the refinement `Refund refines RefundSpec` | MACHINE-CHECKED | pinned Dafny, refund gate (Stage 8; Slice 1 record) | — |
| S3 | approved contract (R1 to R5, datatypes, Unicode strings) | the FLAT contract (three `ensures` of `AssessFlat` on UTF-8 bytes) | `LinkedRefund refines RefundSpec`; `Uniqueness`; `FlattenInjective`; `FlatYieldsOnlyImages` | MACHINE-CHECKED | pinned Dafny 4.11.0, gate options: exit 0, 1489 verified; run by the worker and again by the orchestrator; control with exchanged ids exit 4 ([proofs/linked-refund](proofs/linked-refund/STATEMENTS.md)) | a second run on another machine; the library axiom below removed from the closure |
| S3a | the Dafny library that S3 includes | no axiom in the closure | none | ASSUMPTION (not approved) | the audit of all reached files names one bodiless `@Axiom` lemma (`Std.Strings.HexConversion.CharsConsistent`); by reading it is not called | a proof that it is not used (a build without that module), or an owner decision |
| S4 | the flat contract text in Dafny | the exported S-expression (3,621 bytes, SHA-256 `58154ddf…`) | none | ASSUMPTION (not approved) | a patched Dafny exporter of 2026-11-04 (declares 4.10.1; the proofs use 4.11.0); its build is no longer on this machine (reports I.1a, I.1b) | a rebuild and a byte-equal re-export; a review of the 3,621 bytes against the Dafny text by a person |
| S5 | the exported bytes | the parsed HOL contract and its truth for all typed inputs (`source_decode`, `source_postconditions`, `source_full_result`, `source_compiled_fields`) | stored theorems of U294 | MACHINE-CHECKED on 2026-11-04 ONLY | the U294 records on the backup branch; NOT in the replay of 2026-11-18; these theories are not built in the present tool tree | replay the three U294 scripts (minutes of HOL) |
| S6 | the exported contract | the HOL functions `eligible`, `refund_fields` as ONE statement | `eligible_link_guard_value` (draft); `exported_contract_on_refund_fields` (named, not written) | MISSING | drafts only ([drafts/link-eligible](drafts/link-eligible/STATEMENTS.md)); nothing ran | run the draft with its controls (minutes of HOL); then the tuple and the output encoding |
| S7 | the meaning of `&&`, `<=`, `==` … in Dafny | their meaning in the HOL Dafny semantics; `int`, `bool`; a Dafny string of bytes and an `mlstring` | none | ASSUMPTION (not approved) | no tool relates the two semantics (reports I.1a, I.2 rows 1 to 4) | cannot be closed with the pinned tools; it can be kept to this small named fragment |
| S8 | the wire text that a producer writes | the nine typed fields | `refund_wire_roundtrip` for the canonical text only | ASSUMPTION (owner decisions Q1 and Q5: canonical input only) | the reader takes `040`, `+40`, `"40"` (Wave Gate 1; review row 18: does not hold for the accepted language) | a strict reader, or the bounded binary frame of the F2.7 draft |

### Chain X: from the HOL functions to the bytes that a caller reads (ApprovedSpec, second half)

| # | From | To | Statement | Class | Evidence | What would upgrade it |
| --- | --- | --- | --- | --- | --- | --- |
| X1 | HOL functions | CakeML code | translator certificate theorems | MACHINE-CHECKED | HOL4; replay M1R-1 (same machine) | clean and independent replay |
| X2 | CakeML code | the code bytes | the instance of `compile_correct` (compiler premises discharged inside the scripts) | MACHINE-CHECKED | HOL4; cases C32 and C34 of the replay, exit 0 | the same |
| X3 | the code bytes in the MODEL at `cml_main`, under 11 premises | the model's output: success with the rendered result, or a resource stop with a PREFIX of it (also the empty one) | `refund_profile_a_sl`, `refund_profile_a_sl_every_machine_run` | MACHINE-CHECKED | HOL4, `e4-0001/stdout.log` lines 240 to 331 | a resource bound (none is proved); the same replays |
| X4 | the premises of X3 hold together | — | `refund_profile_a_sl_all_premises_satisfiable_at_0x4000` | MACHINE-CHECKED for ONE constructed state at ONE slide, with the ideal environment `refund_abs_env` | HOL4, `fs-r4-0001` | every permitted slide; a state that a real loader makes |
| X5 | the entry state of the real process | premises P1 to P6 | none | ASSUMPTION (Q3a) | everything before `cml_main` (`dyld`, `_main`, `malloc`) is outside every proof | entry step theorems, or a run-time without them (report B2) |
| X6 | the real C FFI code | premise P7 `refund_env_ok_sl` (a contract at ALL call states) | none | ASSUMPTION, NOT approved in this form, and PROBABLY FALSE | smallest counterexample: `fficlose` with `x3 = 0`: the contract demands a return, the C code runs `assert(alen >= 1)` and aborts (U393; pinned `basis_ffi.c` line 192) | X7 |
| X7 | the contract at ALL call states | the contract at the calls that this program REACHES | `refund_ffi_contract_at_totalise` (L1), agreement of the two machines (L2), the reachable calls per FFI name (L3) | MISSING | named by two workers independently; script drafts in preparation (tracker step C1a) | run L1 (minutes of HOL), then L2 and L3 (hours) |
| X8 | the real process | the model machine | `native_refines` (a candidate) | MISSING | assumption A3 of the profile text: "NOT formalized" | a stated relation as a premise (route A); a proof down to the system calls needs another run-time (report B2) |
| X9 | the model's I/O events | the bytes written on descriptor 1 | L-OUT (a candidate) | MISSING | report B1 | a HOL lemma over `extract_fs` |
| X10 | the model's halt | the exit status of the process | L-EXIT (a candidate) | MISSING | without it a resource stop in the model can be exit 0 in the process (report B1) | a step theorem for the exit path |
| X11 | the processor and the kernel between steps | the L3 model and `interference_ok` | none | ASSUMPTION (Q1) | in the pinned L3 model a system call instruction is a fault: every route ends at a named kernel assumption | none by proof |
| X12 | a run of the real executable | the model's output | none | TESTED-UNPROVED | 2,466 vectors, 0 findings (Wave Gate 1) | X8 |
| X13 | the output bytes | no strict prefix of a result parses as a result | a candidate HOL lemma | TESTED-UNPROVED | 8,011 strict prefixes of 68 real outputs: a strict parser accepts 0 (report B3; the worker's run) | the HOL lemma with its three controls |
| X14 | a full output | its six fields | `refund_render_fields_roundtrip` | MACHINE-CHECKED | HOL4; replay M1R-1 | — |
| X15 | the process result (exit code, stdout, stderr) | a caller's decision | none in the repository | MISSING | no component consumes M1 output; a reference caller with 13 refusal steps is a draft ([drafts/fail-closed](drafts/fail-closed/FAIL_CLOSED_CONTRACT.md)), TESTED-UNPROVED on 82 planted results | put the caller into the repository with an EXIT script; then a proved caller |
| X16 | the M1 decision | the authorization token | none | MISSING | the issuer calls the compiled Dafny checker, not M1 | connect M1 (or the F2.7 program) to the signer |

### Chain U: from a token to committed state (UniqueAuthorization)

| # | From | To | Statement | Class | Evidence | What would upgrade it |
| --- | --- | --- | --- | --- | --- | --- |
| U1 | a request and a candidate transition | `RefundFinality.Check` (claims P1 to P4) | Dafny contract and binding file | MACHINE-CHECKED at source level | Slice 1 record | the compiled JavaScript is not proved |
| U2 | the `Check` result | a signed token | `minter.ts` | TESTED-UNPROVED | Slice 1 suite, 115 rows | a proved issuer (the F2.7 draft) |
| U3 | a token | a commit in the sink | `sink.ts` (signature, pinned ids, state hash, fresh request id, one transaction) | TESTED-UNPROVED | the same suite; the demo of Wave Gate 3 | a refinement proof against U4 |
| U4 | the protocol MODEL | its invariant | `CommitPreservesInv`, `MintPreservesInv` under assumptions A1 to A4 | MACHINE-CHECKED for the model only | pinned Dafny, F2.0 packet | the link model to `sink.ts` (U5) |
| U5 | the model | `sink.ts` | none | MISSING | — | a proof, or a sink generated from the model |
| U6 | Ed25519 and the secrecy of the key | assumption A1 | none | ASSUMPTION (not approved) | — | an owner decision |
| U7 | a commit | durable state after a crash | none | ASSUMPTION (not approved) | one SQLite transaction; no real crash test | a storage contract and a real crash-recovery test |
| U8 | the approved spec | no second authorization of the same refund | none in the approved spec: `remaining` is an input and `Assess` has no state | MISSING at the level of approved intent | reports V (M3) and Slice 1 (the state rule is a choice of the slice, not ratified) | a spec proposal for stored state |

### Chain V: identity (ValidArtifact)

| # | From | To | Check | Class | Evidence | What would upgrade it |
| --- | --- | --- | --- | --- | --- | --- |
| V1 | the HOL constants for code and bitmaps | two slices of the executable file | `forge_refundImage` | MACHINE-CHECKED | HOL4; the file reader and the offsets come from outside HOL (Q3c: conditional; the second extraction is NOT DONE) | the second, independent extraction |
| V2 | the rest of the file (`__DATA` with the GOT, `__LINKEDIT`), `dyld`, `libSystem` | anything | none | MISSING | report V (M1) | an in-HOL check of load commands and binds, or a run-time without them |
| V3 | the final theorem | its 541 ancestor theories by content | the SHA-1 chain inside the `.dat` files | TESTED-UNPROVED | a hash walk of the real files, 0 mismatches (report B4; the worker's run; same machine) | the walk inside the import check, with a load guard |
| V4 | the final statement | the definitions under it | none: the import check compares the statement text only | MISSING | report B4: confirmed from the HOL source; a `.dat` changed on disk loads without an error | a pinned definition closure ([drafts/proof-identity](drafts/proof-identity/CLOSURE_SPEC.md)) |
| V5 | the recorded hashes | values that somebody else computed | none | MISSING | every reference value is from the same agent family on the same machine | the independent replay |
| V6 | the executable | what is run or deployed | a SHA-256 assert in scripts | TESTED-UNPROVED | `run_case.py`, the conformance script | an admission check at the consumer (chain E) |
| V7 | all of the above as one answer | "is this artifact covered by this proof against this contract under these assumptions" | the manifest verifier | TESTED-UNPROVED (a draft) | it REFUSES today's evidence at both levels, as it must; 56 control runs (report II; the worker's runs) | protected pins, a schema, and the missing evidence itself |

### Chain E: enforcement

| # | From | To | Rule | Class | Evidence | What would upgrade it |
| --- | --- | --- | --- | --- | --- | --- |
| E1 | new code | a gate verdict about it | none | MISSING | the hosted gate answered UNSUPPORTED for every pull request of Slices 1 to 3 and Wave Gates 1 to 3: it ran no proof, no type check and no test on that code (report B5) | gate obligations for the new files (an exact-diff proposal for a frozen module) |
| E2 | a gate verdict | a merge | none | MISSING | the gate status is not a required check; every merge since pull request 38 bypassed the review rule | a ruleset that the agent's identity cannot bypass |
| E3 | a change of a protected file | a refusal | `gate/approval.py`, records read from the trusted base only | MACHINE-CHECKED for the refusal | hosted run 44454558079 (REJECTED) | — |
| E4 | checker, proof-producing agent, deployment authority | three separate trust domains | none | MISSING | one GitHub account with administrator rights and one machine user (report B5) | a separate non-admin identity for the agent; an owner key on another device |
| E5 | a merge | what reaches protected state | none | MISSING | nothing is deployed; no admission check exists | the admission boundary of the draft |

> Section 2 above is the state of U473. Rows S2, S3a, S4, S7, X5, X9,
> X10, U3, U5, U7, V1 have CHANGED: read section 7 and section 8 with
> them. Labels such as "(Q1)" or "(Q3a)" name answers in owner text 1,
> a PASTED text that the agent took as the owner's decision (an
> inference, U473). "Independently" in this file means: by separate
> workers of the same model family on the same machine.

## 3. Counts, and the first missing link

| Chain | MACHINE-CHECKED | ASSUMPTION | TESTED-UNPROVED | MISSING |
| --- | --- | --- | --- | --- |
| S | 3 | 4 | 0 | 2 |
| X | 5 | 3 | 2 | 6 |
| U | 2 | 2 | 2 | 2 |
| V | 1 | 0 | 3 | 3 |
| E | 1 | 0 | 0 | 4 |
| all | 12 | 9 | 7 | 17 |

(S5 is counted as machine-checked with its limit: checked on
2026-11-04 only.)

- The first missing link, nearest to the owner: **S1**, from the
  owner's intent to an approval that the agent cannot forge.
- The first missing link in the PROOF chain: **S6**, the exported
  contract on the HOL functions. Its Dafny partner S3 is done.
- The critical missing link: **X8**, with X7, X9 and X10 before it.
  Until X7 passes, premise P7 is probably false for the real code and
  the theorem X3 may say nothing about the real process.

## 4. Blockers, ranked

| Rank | Blocker | Links | Exact statement | Smallest counterexample or control | Assumptions that stay | Effort (the workers' estimates; low confidence) | Next checkable obligation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | No formal claim about the real executable | X6 to X10 | `refund_ffi_contract_at_totalise`, then L2, L3, L-OUT, L-EXIT; `native_refines` as a stated premise ([drafts/M1_EXACT_CLAIM.md](drafts/M1_EXACT_CLAIM.md)) | `fficlose` with `x3 = 0` | even at the end: the native relation, the kernel, the processor | route A: 0.1 to 0.4 M1 units; a closed argument needs another run-time: 0.7 to 1.5 units and a NEW executable (report B2; the decision waits for step C2) | L1, minutes of HOL, stored theories only |
| 2 | The contract is not linked to the HOL functions | S4 to S7 | `eligible_link_guard_value`; `exported_contract_on_refund_fields` | a guard with one changed conjunct must fail | the exporter, the operator meanings, strings as bytes | minutes to hours of HOL after S3 | the 3-line load probe, then the draft theorem |
| 3 | Nothing consumes the output fail-closed | X13, X15, X16 | the prefix lemma; the contract D0 to D12 | the 23 bytes `(refund-result-v1 True ` are accepted by a careless reader | the pipe carries the written bytes; no authentication without a signature | a caller with an EXIT script: hours; the lemma: hours of HOL | put the reference caller and its controls into the repository |
| 4 | Proof identity rests on statement text and same-machine hashes | V3 to V5, V7 | the closure specification | a parent theory with a changed definition and the same names (never built: the fixture fails at 52 s) | the HOL kernel, the exporter script, the operator who pins | hours, plus the independent replay | the micro control R1 (two parents with one name) in HOL, seconds |
| 5 | Enforcement does not exist | S1, E1, E2, E4, E5 | none: these are controls, not theorems | every merge since pull request 38 | the owner's own device; GitHub as a service | three owner actions today (report B5) | the owner reads the live ruleset |
| 6 | The sink is tested, not proved; the approved spec has no state | U2, U3, U5, U7, U8 | a refinement of the F2.0 model; a spec proposal for stored state | repeated zero-amount tokens each commit | Ed25519, the storage | not estimated | a real crash-recovery test |

The replay of the 158 recorded cases is NOT in this table: it closes
none of these links (owner text 3, point 7). The clean replay is not
to start before blocker 1 has fixed the claim (owner text 4).

## 5. What can run next, in order, when the HOL slot is free

Each is small, uses stored theories, and has a control. None is run.

1. The load probe and the draft theorem `eligible_link_guard_value`
   with two of its controls (blocker 2).
2. The replay of the three U294 scripts (link S5).
3. `refund_ffi_contract_at_totalise` with its two controls (blocker 1).
4. The micro control of the identity check (blocker 4).

Already runnable without HOL, and run: the Dafny half
(`proofs/linked-refund/run_check.py`).

## 6. Verdict

- M1-B: **OPEN**. Criterion 1 (a machine-checked connection from the
  approved contract to the HOL decision semantics) has its Dafny half;
  the HOL half and the cross-tool assumptions are open.
- M1-A: not reached either: no reviewed link by a reviewer that the
  owner named, the replays are not complete, and blocker 1 shows that
  the claim itself must be worded as machine-model behaviour.
- `end_to_end=false`. Stage 12 unauthorized. Stage 9 deferred.

## 7. Changes after wave 4 (twelve workers, 2026-11-19; tracker steps D1 to D12)

No link moved to MACHINE-CHECKED by a draft. Changes of class are only
where a run exists. "Worker's run" means: not run again by the
orchestrator.

| Link | Change | Evidence |
| --- | --- | --- |
| S2 | LIMIT ADDED: partial correctness only. A body `expect false; …` verifies against the approved spec (orchestrator's run: exit 0, 6 verified). "Verified" means: IF `Assess` returns, the result is allowed. The gate's source scan does not look for `expect` (worker's reading) | report D5 |
| S3 | stays MACHINE-CHECKED; a fresh adversarial review found no defect; not vacuous (worker's runs); some controls fail partly by "out of resource", which is not a refutation | report D10 |
| S3a | candidate for MACHINE-CHECKED: with the axiom's module removed the proof verifies (exit 0, 1486) and the audit equals the empty baseline. RUN AGAIN BY THE ORCHESTRATOR (2026-11-19T06:29Z): `dafny verify LinkedRefund.dfy` on that closure: exit 0, 1486 verified; audit of its 34 files: 0 findings, byte-equal to `gate/expected-audit.md`; the proof file is byte-equal to the recorded one. S3a: ASSUMPTION → MACHINE-CHECKED (the result does not need the axiom). The recorded closure in `proofs/linked-refund/inputs` still CONTAINS the module; the removal is `review-controls/S3a-remove-hex-module.diff` | report D10 |
| S4 | ASSUMPTION → TESTED-UNPROVED for this one export file: four readings agree with the Dafny text; the Dafny source of the export is byte-equal to the flat contract file of S3 (digests checked by the orchestrator; now pinned in `run_check.py`) | reports D2, D12 |
| S6 | stays MISSING; the full draft with 11 controls is ready to run | report D2 |
| S7 | stays ASSUMPTION, narrowed: 8 operators, three integer literals, four ASCII strings; exact wording given; a Dafny mirror of the HOL rules agrees (a proof about a transcription, not about HOL) | report D12 |
| X5, X11 | WORDING MUST CHANGE: `arm8_ok` requires TBI0 = F and SA0 = F at every step; Linux and the public XNU source set both to 1 for user space. The premise is literally false for a state that copies the real registers; it holds for an "erased" copy only. New link X11e (the erasure is sound): MISSING | report D11 |
| X6 | more counterexample states for `read`, `write`, `open_in` (wrong configuration length, top bit of the length, descriptor bytes of 0x80 or more) | report D3 |
| X7 | stays MISSING. L1: pre-flight found no defect. L3 needs about 15 text I/O specifications proved again with two FFI names (days). The program never calls close or open_in (by reading the source) | reports D1, D3 |
| X9 | stays MISSING; the form in the exact-claim draft is FALSE (free external oracle); repaired draft at `no_ext` | report D4 |
| X10 | stays MISSING, and worse than stated: exit status 0 does NOT imply success. `_cml_exit` tests the low 32 bits of x0 (read by the orchestrator); the status is the low 8 bits; the model tests 64 bits. Safety must rest on a strict parse of the output, not on the exit status | report D4 |
| X13 | stays TESTED-UNPROVED; HOL draft with a strict parser defined | report D4 |
| U3, U7 | U7: ASSUMPTION → TESTED-UNPROVED for a PROCESS crash (486 kills, 0 violations; worker's run); power loss stays an ASSUMPTION (SQLite defaults, no full fsync). U3: "one commit per pre-state" is FALSE for amount 0 | report D6 |
| U5 | split. U5a model → Dafny sink core: MACHINE-CHECKED under named assumptions (orchestrator's run: exit 0, 56 verified). U5b sink core → `sink.ts`: MISSING. By reading: `sink.ts` does not check that the token's request id equals the intent's | report D7 |
| U8 | stays MISSING; `ZeroAmountRepeats` proves that the approved relation lets two zero-amount claims commit; an unapplied spec draft exists | report D7 |
| V1 | the Q3c second extraction: TESTED-UNPROVED, NOT independent (same model family, same machine). First derivation of the offsets from the file's symbols; equal values (digests checked by the orchestrator) | report D9 |
| V2 | stays MISSING; full inventory: C run-time, 22 stubs, 23 binds, `__LINKEDIT`; a changed byte outside the two slices is caught by the whole-file hash only | report D9 |
| E2, E4 | stay MISSING, with live facts: `main` is NOT protected (HTTP 403: the plan gives no rulesets to a private repository; read by the orchestrator); this machine holds the administrator identity and a second write identity | report D8 |
| E1 | stays MISSING; an unapplied admission rule (exit 3 admits documents only) is drafted and tested on two real receipts | report D8 |

New counts are not given: a count is not a measure of completion, and
three links were split. The first missing links are unchanged: S1
(nearest the owner), S6 (proof chain), X8 with X7, X9, X10 (critical).
Two premises of the machine-model theorem are now known to be false
for real machines as written: the FFI contract (X6) and the processor
bits (X5).

## 8. Corrections after the reconciliation audit (step G11; 2026-11-19T06:58Z)

| Link | Correction |
| --- | --- |
| U5a | MACHINE-CHECKED only in this sense (reviews G4 and G10, the workers' runs): the 28 rows of `SinkCore` by `dafny verify` (record: `proofs/sink-core/records/orchestrator-verification.csv`); the 15 inherited lemmas are checked for the instance by `dafny build` (71 rows), not by `verify`. Its assumption A1 (`IdealMac`) as written CANNOT be met by a real signature scheme (proved by the reviewer): the theorem is about a verifier that accepts a fixed finite set of pairs. A step-local A1 that can be met is proved to suffice for the invariant, but the headline lemmas are not restated with it. T1 to T5 are for ONE charge. So: a model result under an assumption that needs rewording, not yet a usable link |
| S3a | The orchestrator's verify run has no stored log: stated only. Stored: the worker's run (`proofs/linked-refund/records/S3a-worker-verify-*.txt`: exit 0, 1486) and the orchestrator's audit output, byte-equal to the empty baseline. The class stays MACHINE-CHECKED on the worker's stored run |
| S3 | records now stored: `proofs/linked-refund/records/` (runs 1 and 2 of `run_check.py`). The present `run_check.py` with the FlatCore pin has not run yet |
| E3 | one hosted run REJECTED: an instance, not a rule; link E2 shows that a merge can go around it |
| V1 | the second extraction is done (section 7), not independent |
| all | the replay cannot reach 158: three recorded cases have no source file |
| U5b | stays MISSING as a proof; now TESTED: 5,500 sequences, the unchanged `sink.ts` against the compiled core, 0 divergences (the worker's run); `sink.ts` is stricter than the core in eight places |
| U3 | by a run: `sink.ts` (and the core) accept a token whose body request id differs from the intent's, if the signing key signs it; the real issuer refuses to sign it |

## 9. The first composed statement (step G9; 2026-11-19T07:12Z)

A single Dafny lemma now has the SHAPE of the owner's target for one
charge: `SliceSafety` in `proofs/slice-theorem/inputs/SliceTheorem.dfy`
(orchestrator's run with a stored log: exit 0, 1570 verified).

    Committed(e) ⇒ ApprovedSpec(e) ∧ FlatResultAgrees(e) ∧ UniqueAuthorization(e)
    under A1 (ideal MAC at each delivery), A2 (mint only on Check),
    A5 (verifier matches), A6 (the artifact computes the flat contract)

| Conjunct of the target | In this lemma | Kind |
| --- | --- | --- |
| ApprovedSpec | proved: the approved `Eligible` on the state stored at commit time | Dafny MODEL |
| UniqueAuthorization | proved: one token, one request id, no second commit | Dafny MODEL |
| ValidArtifact | NOT proved: hypothesis A6 on a parameter `art`; closing it is links S4 to S7 and X1 to X16 | ASSUMPTION |

It is NOT a link to anything real yet: A1 as written cannot be met by
a real signature scheme (section 8, U5a); `sink.ts`, the issuer glue,
compiled code, storage and native execution are outside it. It joins
the existing rows S2, S3, U1, U4 and U5a into one statement; it adds
no new link class.

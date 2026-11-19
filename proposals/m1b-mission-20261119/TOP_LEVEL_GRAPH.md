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

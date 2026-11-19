# M1-B mission text (as received on 2026-11-19)

Saved verbatim. It arrived as a pasted text. The owner's own words with
it: "spin up as many opus 5.5 subagents with a fable ocrhsrat that we
need to get this done. ,make sure to put it in the md and make sure th
agents track ths teps lets ruip this and et it going."

The text approves no protected change, does not unlock Stage 9, does
not authorize Stage 12 and closes nothing. One line arrived garbled
("Integer and Boolean domain cortring, byte, and Unicode
representation."); it is kept as it arrived. The step tracker of this
mission is [TRACKER.md](TRACKER.md).

---

# FORGE — FROM HUMAN INTENT TO VERIFIED SILICON

## Mission

Build toward the following end-to-end assurance chain:

**Human-approved specification → mechanically verified implementation → verified compilation → exact machine-code artifact → authenticated provenance → enforced execution boundary.**

The long-term objective is straightforward:

> An untrusted AI can write software, but that software cannot be promoted to a trusted execution boundary unless independent verification establishes its required properties.

We are not trying to make the AI trustworthy. We are trying to make trusting the AI unnecessary.

## 0. Read and reconstruct the actual project state

Read in full:

- `AGENTS.md`
- `README.md`
- `ROADMAP.md`
- `FORGE_MASTER_IDEA.md`
- `unsure.md`
- `proposals/m1-owner-review-20261119/REVIEW_PACKET.md`
- `proposals/refund-executable-feasibility/m1-chain-replay-20261118/REPORT.md`
- `proposals/forge2-m1-conformance/REPORT.md`
- Stage 9 provenance contracts, locks, gate implementation, and existing EXIT records.

Inspect the active branch, recent commits, working-tree state, current proof artifacts, and any running M1 replay processes.

Do not assume earlier status reports are current.

Establish the exact status of:

1. The 95 replayed HOL4 theories.
2. The 158 additional M1 cases.
3. The 18-row Dafny-to-HOL correspondence review.
4. The independent review and mechanical-correspondence agents.
5. Profile A and the accepted trust assumptions.
6. The compiler-premise ledger and slide obligations.
7. The exact ARM64 executable and its SHA-256.
8. Stage 9's current implementation locks and provenance requirements.

Report actual evidence, not inferred success.

---

# PHASE I — CLOSE M1-B

## 1. Mechanical correspondence

Establish a machine-checked connection between the approved refund contract R1–R5 and the HOL4 model used by the CakeML compilation proof.

Do not rely solely on agreement across finite test vectors or human review.

Begin with:

- Integer and Boolean domain cortring, byte, and Unicode representation.
- Refund eligibility predicate.
- Reason-code constraints.
- Authorized and rejected decisions.
- Complete six-field decision tuple.
- Output serialization and canonical encoding.

Preserve the approved contract exactly.

Prefer a small translation or refinement proof with independently checked semantic preservation over a manually asserted equivalence.

If full equivalence cannot be established, identify the precise missing theorem, counterexample, or trusted assumption.

Do not substitute a hand-written assertion for a proof.

## 2. Independent specification review

Complete the independent review of all 18 correspondence rows.

Prioritize rows 16–18 because they connect boundary definitions, the approved `Assess` implementation, and the wire protocol.

The reviewer must independently inspect original definitions and proof statements.

Record:

- Exact source and target definitions.
- Verified equivalences.
- Unverified assumptions.
- Potential mismatches.
- Counterexamples, if discovered.
- Reviewer findings and dispositions.

No author self-certification.

## 3. Profile A closure

Use the owner's approved direction:

- Profile A, preserving R1–R5.
- Narrowly excluded OS read errors.
- Explicit loader and entry-state assumptions.
- Explicit CakeML basis C/FFI simulation assumption.
- Conditional trust in validated file-reader and offset tools.
- Absent stdin excluded from the theorem, with operational fail-closed behavior.

Every assumption must appear in the final theorem statement or its explicit trust-boundary ledger.

A simulation assumption must never be described as a verified native C implementation.

Do not claim physical hardware or operating-system correctness.

## 4. Replay and compiler closure

Determine whether the 158-case replay has actually finished.

If it has, verify all recorded exit codes, hashes, controls, repeats, and import checks.

If it has not, report the exact status and remaining blockers. Do not silently launch another expensive replay.

Discharge the remaining compiler configuration, initialization, and slide obligations as far as the actual theorem permits.

Prepare the clean replay and independent replay with reproducible manifests, pinned dependencies, and explicit acceptance criteria.

Do not claim successful replay until the commands have executed and their evidence has been independently inspected.

### M1-B acceptance criteria

M1-B is closed only when:

1. The approved contract is mechanically connected to the HOL4 decision semantics.
2. The HOL4 theorem connects those semantics to the exact ARM64 code under explicitly enumerated premises.
3. The relevant proof obligations are discharged or expressly identified as approved assumptions.
4. The full controls and replay requirements pass.
5. Independent review and independent replay are complete.
6. Artifact identities and proof dependencies are recorded.
7. No unresolved issue contradicts the claimed theorem.

Otherwise report **M1-B OPEN**.

---

# PHASE II — PROOF-TO-BINARY IDENTITY

Develop a minimal, auditable evidence manifest binding:

- Approved specification digest.
- Source implementation digest.
- HOL4 theorem identifiers and statements.
- Proof dependency identities.
- Compiler configuration and toolchain pins.
- Compiled artifact SHA-256.
- Trusted assumption profile.
- Replay and independent-review evidence.

The result should let an independent verifier answer:

**Is this exact artifact covered by this exact proof, against this exact approved contract, under these exact assumptions?**

All identity comparisons must fail closed.

Reject substituted artifacts, stale proof records, weaker verification methods, unapproved specification changes, and mismatched compiler configurations.

Keep the trusted verification mechanism small.

Do not introduce a new cryptographic protocol unnecessarily.

---

# PHASE III — PREPARE STAGE 9

Stage 9 establishes provenance and supply-chain integrity. It does not prove program correctness.

Inspect the existing:

- `gate/provenance/implementation.lock`
- `spec/provenance/spec.lock`
- Protected-file ratification rules.
- Pinned dependency and compiler identities.
- Hosted signing workflow.
- Sigstore/Rekor integration.
- Six Stage 9 EXIT cases.

Identify stale entries, uncovered executable files, missing identities, and approval-boundary weaknesses.

Prepare an exact-diff proposal to bind Stage 9 to the finalized M1-B artifacts.

**Do not activate Stage 9 yet.**

The owner deliberately deferred Stage 9 until the silicon verification work is sufficiently stable.

Do not modify protected paths, authorize hosted signing, create permanent transparency-log records, or initiate the large agent benchmark without separate explicit approval.

### Stage 9 acceptance criteria

Stage 9 can be considered complete only when the appropriate approved lock and signing changes are applied, all required EXIT cases run successfully, and an independent verifier can authenticate the provenance of the exact approved artifacts.

A successful signature alone is not a proof of software correctness.

---

# PHASE IV — DEFINE THE NEXT SILICON-TO-SINK FRONTIER

After M1-B, specify the smallest credible F2.7 implementation.

Target one machine-code theorem covering:

1. Bounded, canonical input parsing.
2. Structured request validation.
3. Approved policy evaluation.
4. Certificate or proof verification where applicable.
5. Authorization-token construction.
6. Output framing and canonical serialization.

Analyze whether signature verification should be included in the proved kernel or represented by an explicitly named cryptographic assumption.

Prove relevant safety properties under bounded resource and environmental assumptions.

Investigate malformed frames, extreme lengths, Unicode differences, integer boundaries, early EOF, partial writes, and adversarial byte streams.

Do not promise universal crash freedom, termination, or finite-memory behavior without the corresponding theorem.

Separately define the trusted finality sink:

- Signature and token validation.
- Binding to pre-state and request identity.
- Atomic state transition.
- Durable idempotency.
- Concurrency safety.
- Recovery from partial failure.
- Prevention of unauthorized bypass paths.

Distinguish a verified decision from an executed external effect. Third-party systems remain outside Forge's proof unless explicitly modeled and covered by justified assumptions.

---

# PHASE V — INDEPENDENT ADVERSARIAL VALIDATION

Use fresh-context reviewers to challenge the following:

- Whether the theorem proves the claim stated.
- Whether a proof obligation is vacuous.
- Whether the specification permits unintended behavior.
- Whether the binary identity is correctly bound.
- Whether an attacker can bypass the effect boundary.
- Whether a forged or stale receipt can be accepted.
- Whether a proof from another program can be substituted.
- Whether runtime failures lead to unauthorized effects.
- Whether the gate can approve its own modification.

Every claimed check needs a negative control where practicable.

Preserve all failures and unexpected observations.

A green test suite is evidence of successful tests, not universal correctness.

---

# EXECUTION RULES

1. Prefer finishing existing proof obligations over expanding scope.
2. Preserve all approved specifications.
3. Never weaken a theorem to make its proof pass without a separately approved change to the claim.
4. Never silently add axioms, trusted assumptions, or unverified external functions.
5. Never use `sorry`, `admit`, assumed lemmas, or equivalent escape hatches as completed proof evidence.
6. Keep `end_to_end=false` until the actual claimed end-to-end boundary is established.
7. Keep Stage 12 unauthorized.
8. Preserve exact-diff approval requirements for protected files.
9. Keep proof, test, conformance, provenance, and deployment evidence in distinct categories.
10. Run read-only inspection and appropriately bounded local checks first. Obtain separate approval before protected writes, hosted signing, large expenditures, or long-running verification.
11. Record real commands, actual exits, hashes, and unresolved uncertainty.
12. If an item cannot be proved, produce the smallest reproducible blocker rather than an optimistic completion claim.

---

# DELIVERABLE

Produce a concise, evidence-backed report containing:

**A. Current state:** What is actually proved, tested, open, or assumed.

**B. M1-B closure matrix:** Each proof obligation, its dependency, exact current status, and acceptance condition.

**C. Next executable step:** One highest-leverage action that can be performed safely now.

**D. Stage 9 proposal:** The exact provenance changes needed after M1-B, without activating them.

**E. F2.7 architecture:** A minimal proposed proof boundary from untrusted input bytes to authorization output bytes.

**F. Residual trusted computing base:** Every component that remains unverified.

**G. Final verdict:** `M1-B CLOSED` or `M1-B OPEN`, supported by evidence. Separately report `end_to_end=false` unless the broader claim has actually been justified.

The standard is not whether the demo looks impressive.

**The standard is whether a skeptical formal-methods researcher can inspect the theorem, independently replay the evidence, verify the exact artifact identity, and identify every remaining assumption.**

Start with the current-state audit. Then pursue the smallest missing theorem that materially advances M1-B. Do not start Stage 9 signing or F2.7 implementation prematurely.

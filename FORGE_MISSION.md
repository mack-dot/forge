# /goal — Forge: Continuous Proof-Carrying Software

## Mission

Transform Forge from a formal verification research prototype into a working, independently verifiable system for **continuous proof-carrying software engineering**.

Forge's purpose is to let autonomous software engineering agents propose changes while independent, established verification systems determine whether those changes satisfy human-approved requirements.

The ultimate objective:

**Every admitted change to a supported critical software component must carry independently reproducible evidence that its required properties hold for the exact artifact being admitted, under explicitly stated assumptions.**

Forge must not trust the proposing agent to declare its own work correct.

The intended lifecycle is:

**Human-approved intent → formal specification → agent-proposed implementation → verified behavior → concrete executable → authenticated evidence → independent admission → continuous incremental verification.**

The goal is not to accumulate isolated theorems, successful CI runs, signed artifacts, or impressive benchmarks.

The goal is to create a system in which software correctness evidence can be produced, independently checked, preserved, reused safely, and enforced throughout the engineering lifecycle.

---

# 0. EXECUTION PRIORITY — READ FIRST

The most important instruction in this entire mission:

**Establish one complete, nontrivial, executable-level correctness vertical slice before generalizing the system.**

Do not make the following prerequisites for the first vertical slice:

- Generic cross-run proof caching.
- General-purpose CLI development.
- Multi-project adoption.
- Broad language support.
- Extensive performance optimization.
- New orchestration infrastructure.
- Universal QEMU or operating-system correctness proofs.

These are legitimate future objectives, but they must not distract from the first defensible executable correctness result.

At every iteration, identify:

1. What exact behavioral property are we trying to establish?
2. What evidence already establishes part of that property?
3. What is the single highest-priority missing assurance link?
4. What is the smallest experiment or implementation that could close it?
5. What real test would demonstrate success or falsify the hypothesis?

Prioritize the critical path.

If a task does not improve the correctness chain, resolve a blocking trust assumption, or enable independent reproduction, defer it.

Do not substitute planning for implementation.

Do not substitute implementation for actual verification.

Do not substitute passing tests for a correctness theorem.

## Milestone hierarchy

### M1 — Executable behavioral correctness

Establish one nontrivial behavioral property for one exact executable under documented assumptions.

### M2 — Independently enforced admission

Demonstrate that a trusted mechanism admits a valid artifact, rejects invalid evidence or violated requirements, and refuses unsupported claims.

### M3 — Continuous incremental verification

Demonstrate safe reuse and invalidation when the supported implementation changes.

### M4 — Developer usability and measurable effectiveness

Make the system usable by another engineer and evaluate whether it improves the verification lifecycle.

These milestones are sequential research priorities, not permission to bypass existing repository stage or approval rules.

The first milestone is the primary objective.

---

# 1. INSPECT THE ACTUAL REPOSITORY

Repository: `mack-dot/forge`

Begin by establishing the authoritative current state.

Inspect:

- Current `main`, exact commit and tree.
- `README.md`
- `ROADMAP.md`
- `VISION.md`
- `AGENTS.md`
- Relevant `unsure.md` entries.
- Current gate, obligation and coverage implementations.
- Approved specifications and policies.
- Evidence schemas and implementation locks.
- Existing Dafny and Rocq verification pipelines.
- Stage 7 binary proof and assumption audit.
- Stage 8 refund correctness evidence.
- Stage 9 provenance and release-admission implementation.
- Stage 11 incremental verification.
- Current CI workflows.
- Open and recently merged PRs.
- Relevant local worktrees and unpublished research commits.

Specifically investigate PRs #34, #36 and #37, plus any newer work.

Inspect hosted booking verification run `41523691535` and its actual evidence, if accessible.

Recover the latest RISC-V research involving:

- Fixed ELF SHA-256 `8ced2ab6c7160338899056fe51bacb23d86d81705eacfdd1e992cf5252bdaeb6`.
- Existing termination theorem.
- Proposed memory-independent termination claim.
- Fixed GCD functional-result proof.
- Actual QEMU/GDB execution observations.
- Register and memory observations.
- Concrete-to-model correspondence findings.
- Independent Rocq kernel results.
- Proof-object reproducibility.
- Producer identity and provenance checks.
- Remote-backup verification status.

Verify claims from source, actual logs, authenticated artifacts and independent checking wherever possible.

Do not rely on summaries when stronger evidence is available.

Historical documentation may be stale. Do not silently rewrite it.

## Initial deliverable

Produce a capability and trust-boundary inventory.

Classify each relevant capability as:

- `ESTABLISHED`
- `TESTED`
- `LOCALLY_VALIDATED`
- `PROPOSED`
- `UNSUPPORTED`
- `NOT_ESTABLISHED`

For every established claim, identify:

- Exact proposition.
- Artifact identity.
- Verification method.
- Checked dependency closure.
- Trusted computing base.
- Relevant assumptions.
- Independent reproduction status.
- Remaining assurance boundaries.

Use this inventory to select the shortest viable route to M1.

---

# 2. PRESERVE GOVERNANCE AND SOUNDNESS

The repository's existing authorization and governance rules take precedence over this prompt.

Current known boundaries:

- Stage 11 merged.
- Stage 12 unauthorized.
- Protected changes require exact human approval.
- Independent code-owner review is required.
- `end_to_end=false` remains in force.
- Cross-run receipt reuse is not generally authorized.
- Existing release and signing authority must not be expanded implicitly.

This prompt authorizes read-only inspection, safe local experiments, reproduction of existing evidence, proposals and work already permitted under existing project rules.

It does not independently authorize protected changes, publication, merging, workflow dispatch, signing, release, deployment, or Stage 12.

Never:

- Self-approve a change.
- Use administrator bypass.
- Modify an approved specification to make an implementation pass.
- Allow candidate code to select its own verification authority.
- Trust candidate-provided proof policy.
- Promote tests to universal proofs.
- Invent evidence or execution results.
- Accept incomplete obligation coverage.
- Treat missing evidence as success.
- Hide failed experiments.
- Weaken adversarial controls.
- Claim correctness beyond the actual theorem.

At an authorization boundary, prepare the exact approval packet and stop that branch of work.

Continue independent authorized work where possible.

**Mathematical correctness, evidence authenticity, and authorization are separate requirements.**

All three must be respected.

---

# 3. M1 — ESTABLISH ONE NONTRIVIAL EXECUTABLE CORRECTNESS RESULT

This is the highest-priority research milestone.

Choose one existing Forge component with a meaningful approved behavioral specification.

Prefer the ledger or refund boundary if either provides a tractable path to machine-code verification.

Do not assume that the most sophisticated example is the best first target.

Evaluate the actual technical feasibility first.

## 3A. Select the target

Compare the existing ledger, booking and refund components.

For each, determine:

- Which properties are already formally proved.
- How complete the approved specification is.
- Which implementation language is involved.
- Whether an established backend can connect the proof to actual executable behavior.
- Which compiler and runtime assumptions remain.
- Whether a supported artifact can be independently reproduced.
- What new proof obligations would be required.
- Which existing infrastructure can be reused.

Select the component with the shortest justified route to one meaningful executable-level result.

Do not select solely based on ease of proving termination.

The target must demonstrate behavior that matters.

Examples include:

**Ledger**
- Conservation of funds.
- Correct debit and credit.
- No negative balances under the approved contract.
- Rejected requests leave specified state unchanged.
- Accepted retries do not duplicate effects.

**Refund**
- Authorized refunds do not exceed the remaining refundable amount.
- Valid requests receive the specified decision.
- Repeated accepted requests do not duplicate the modeled effect.
- Rejected requests preserve specified financial state.
- Every supported operation terminates under declared assumptions.

These are examples, not automatic authorization to modify the approved claims.

## 3B. Freeze the behavioral contract

Recover the exact approved specification.

Identify:

- Valid input domain.
- Required preconditions.
- State invariants.
- Postconditions.
- Rejection behavior.
- Termination requirements.
- Arithmetic assumptions.
- Relevant environmental assumptions.
- Explicitly excluded behavior.

Preserve a non-vacuity witness.

Do not make the theorem easy by silently restricting legitimate inputs or weakening requirements.

If a specification change is necessary, prepare an exact human-approval proposal.

Do not implement the changed specification before authorization.

## 3C. Verify implementation behavior

Use established verification tools.

Prove the required behavioral properties over the declared domain.

Audit:

- Axioms.
- Trusted lemmas.
- Proof dependency closure.
- Bypassed verification.
- Unproved assumptions.
- Resource limits.
- Required obligations.
- Toolchain versions.

Do not count a theorem that proves a weaker property as satisfying the approved contract.

Do not infer behavioral correctness from successful compilation or execution.

## 3D. Connect the proof to the executable

This is the central technical challenge.

Establish a justified relation between the verified implementation and the exact executable.

Investigate existing approaches in this order:

1. Reuse an established verified compilation pipeline where supported.
2. Use existing checked machine-code semantics and binary-level proofs.
3. Apply established translation-validation techniques to the exact artifact.
4. Establish a narrowly scoped compositional argument with explicit, independently reviewable trust assumptions.

Do not build a custom theorem prover, proof checker, solver, or machine semantics.

Account for all relevant:

- Source and binary representations.
- Compiler transformations.
- Numeric representations and overflow.
- Memory layout.
- Input and output representations.
- Calling conventions.
- Entry-state initialization.
- Processor semantics.
- Runtime dependencies.
- External calls.
- Undefined behavior.
- Termination and resource assumptions.

Define the concrete-to-abstract state relation.

A finite trace is useful experimental evidence, but is not universal execution correspondence.

A matching artifact hash proves identity, not behavioral equivalence.

A valid source proof does not automatically apply to the compiled executable.

## 3E. Use the existing RISC-V research strategically

The current fixed ELF and LPS work are valuable supporting assets.

Reuse:

- Existing Rocq proofs.
- Independent kernel checking.
- Exact binary identity.
- Observed machine-state comparisons.
- QEMU/GDB traces.
- Memory-read evidence.
- Existing assumption audits.
- Stage 9 provenance machinery.

But do not confuse the historical self-test theorem with proof of ledger or refund correctness.

The existing fixed-ELF research can serve as:

- A correspondence-method testbed.
- A proof and evidence reproducibility baseline.
- A machine-semantics validation fixture.
- A provenance and admission reference.

The functional vertical slice must concern its own selected implementation and required properties.

If the existing binary framework cannot support that component, produce a concrete feasibility finding and investigate established alternatives.

Do not spend unlimited effort extending the self-test while the actual component correctness objective remains untouched.

## M1 success condition

A specific, nontrivial behavioral claim is established for an exact executable, either directly or through a soundly justified semantic-preservation chain, under explicit assumptions.

An independent checker validates the required proof.

The executable and relevant proof dependencies are exactly identified.

Any correspondence that remains an assumption is clearly identified and must be compatible with the approved assurance profile.

If the required link cannot be justified, M1 remains `PARTIAL`.

Do not change `end_to_end=false` to manufacture completion.

---

# 4. M2 — INDEPENDENT PROOF-CARRYING ADMISSION

Once M1 has established a sufficient executable-level assurance argument, connect it to a trusted admission decision.

Reuse the existing Stage 9 provenance and release infrastructure wherever possible.

The proposing agent must not control the authority that decides whether its artifact is admissible.

## Admission architecture

The controller receives:

- Approved claim set.
- Exact specification identity.
- Exact implementation and artifact identities.
- Required verification methods.
- Proof and evidence identities.
- Relevant dependency closures.
- Authorized trust assumptions.
- Expected producer identity.
- Approved policy and epoch.
- Intended execution environment.

It independently validates those inputs.

The controller must not derive expected trusted values from the candidate it is evaluating.

## Decision semantics

Produce three top-level decisions:

**ADMIT**

All properties required by the approved policy have sufficient authenticated evidence for the exact artifact and declared environment.

**REJECT**

The candidate violates an established requirement, an authorization constraint fails, or evidence fails required integrity or provenance validation.

**UNSUPPORTED**

The required assurance cannot be established because of incomplete coverage, unsupported semantics, missing proof correspondence, unavailable verification, or unresolved assumptions.

Internally preserve more precise diagnostic states, including checker errors and `NOT_ESTABLISHED`.

A failed proof attempt does not necessarily mean a program is incorrect.

An admission refusal does not necessarily establish a behavioral counterexample.

Do not conflate policy rejection with mathematical falsification.

## Required controls

Reject or refuse as appropriate:

- Unapproved specification changes.
- Candidate-controlled verification code.
- Candidate-controlled trusted roots.
- Altered evidence.
- Missing obligations.
- Substituted executables.
- Incorrect artifact digests.
- Invalid producer identities.
- Stale release requests.
- Invalid signatures.
- Incompatible assumptions.
- Unsupported execution environments.
- Unproved source-to-executable links.

## M2 success condition

Using a real independently checked behavioral proof:

- A valid candidate receives an authorized ADMIT decision.
- A candidate with an established behavioral violation is rejected.
- Forged or substituted evidence is rejected.
- A candidate without sufficient correspondence or coverage is refused as unsupported.

These decisions must concern the actual approved property and exact artifact, not a toy substitute unrelated to M1.

The demonstration must not perform an unauthorized production deployment.

---

# 5. M3 — CONTINUOUS INCREMENTAL VERIFICATION

Only after the first correctness and admission slice works should broader continuous verification become the primary development objective.

Reuse the existing obligation registry, coverage model and receipt infrastructure.

## Change-impact analysis

For a proposed change, determine:

- Affected claims.
- Required verification obligations.
- Relevant dependency closure.
- Reusable evidence.
- Invalidated evidence.
- Missing coverage.
- Required backends.
- Required trust assumptions.

A change must never be admitted based solely on proofs of unrelated components.

Unknown dependencies fail closed.

Uncovered changes must not silently inherit a successful verdict.

## Safe evidence reuse

Preserve existing same-process integrity guarantees.

Investigate authenticated reuse across processes and CI runs as a separate capability.

A reusable proof must remain bound to:

- Exact claim and specification.
- Proof method.
- Exact artifact and relevant inputs.
- Complete dependency closure.
- Verification harness.
- Toolchain and configuration.
- Assumptions.
- Trusted producer.
- Required policy.
- Authorized execution environment.

A hash stored beside an untrusted receipt does not establish authenticity.

A candidate cannot create trusted evidence merely by setting `established=true`.

Use existing Sigstore/in-toto and provenance infrastructure where appropriate.

Do not introduce new persistent infrastructure without a demonstrated need.

## Invalidation requirements

Demonstrate that changing a relevant dependency triggers required new verification or conservative refusal.

Test:

- Modified implementation.
- Changed specification.
- Changed proof dependency.
- Changed verification harness.
- Changed toolchain.
- Changed policy.
- Corrupted receipt.
- Substituted artifact.
- Coordinated evidence tampering.
- Stale execution identity.
- Prior-process evidence.
- Missing provenance.

Do not loosen invalidation merely to improve cache hit rates.

## M3 success condition

On a frozen candidate corpus:

- Valid unchanged evidence is safely reused.
- Reused work is demonstrably not executed again.
- Relevant changes invalidate evidence.
- Unsupported changes do not produce acceptance.
- No adversarial fixture produces a known false admission.
- The acceptance decision remains equivalent to the approved fresh-verification baseline for supported cases.

Report actual authentication overhead a--

# 6. M4 — MAKE FORGE USABLE

After correctness, admission and continuous verification have a working integrated demonstration, make Forge accessible to another engineer.

Do not build the developer interface before the relevant trust and evidence contracts stabilize.

Prefer a small interface over another platform.

Candidate commands:

- `forge init`
- `forge check`
- `forge explain`
- `forge replay`
- `forge admit`

These are desired capabilities, not a mandate to add five independent implementations.

Design the smallest interface that supports the validated workflow.

An engineer should be able to determine:

- What changed.
- What Forge checked.
- What was formally proved.
- What was only tested.
- What evidence was reused.
- Which assumptions remain.
- Why a change was rejected.
- Why a claim is unsupported.
- What exact artifact is admissible.
- How to independently reproduce the evidence.

Use understandable claim reports.

Do not let the CLI introduce a new admission authority or bypass protected policy.

## M4 success condition

An independent developer can:

1. Clone a supported project.
2. Install the documented dependencies.
3. Check a supported change.
4. Review its correctness evidence.
5. Reproduce the relevant proof.
6. Understand the admission decision.

The developer must not need the original proposing agent's private cache, credentials or workspace.

---

# 7. EXPERIMENTAL VALIDATION

Forge's claims must be falsifiable.

Build a frozen acceptance matrix for the first complete vertical slice.

Required cases:

| Experiment | Required outcome |
|---|---|
| Valid behavior-preserving change | ADMIT |
| Proven violation of an approved invariant | REJECT |
| Unapproved specification weakening | REJECT |
| Modified binary after proof | REJECT |
| Forged evidence | REJECT |
| Substituted proof artifact | REJECT |
| Missing required correspondence | UNSUPPORTED |
| Uncovered change | UNSUPPORTED |
| Valid authenticated proof reuse | ADMIT without redundant computation |
| Changed relevant dependency | Reverify or refuse |
| Clean independent reproduction | Same justified decision |

For the M1–M2 milestone, the reuse cases may remain pending until M3. Do not block the first executable correctness result on cross-run caching.

Each experiment must record:

- Exact source revision.
- Exact executable identity.
- Applicable specification and assumptions.
- Real checker command.
- Actual numeric exit code.
- Proof and evidence identity.
- Accepted or refused claim.
- Diagnostic reason.
- Reproduction instructions.

Do not count expected results as executed results.

Do not count infrastructure errors as successful security rejections.

Preserve every failed attempt.

Where hosted GitHub CI is required, use actual hosted execution after the relevant authorization.

---

# 8. PERFORMANCE AND RESEARCH EVALUATION

Once the integrated verification mechanism works, compare:

1. Fresh full verification.
2. Existing backend-native caching.
3. Forge authenticated incremental verification.

Hold constant, wherever possible:

- Candidate corpus.
- Approved claims.
- Verifier and solver versions.
- Relevant hardware class.
- Resource budgets.
- Correctness acceptance rules.
- Execution environment.

Measure:

- Cold wall time.
- Warm wall time.
- Solver work.
- CPU time.
- Runner-minutes.
- Authentication overhead.
- Valid proof reuse.
- Invalidation correctness.
- False acceptance in tested adversarial cases.
- False rejection of supported valid cases.
- Unsupported-change rate.
- Independent reproducibility.
- Human intervention.
- Specification maintenance.
- Proof maintenance.

Do not claim speedups based on cache-hit labels alone.

Do not claim broad superiority from a single benchmark.

The system must first be correct, then efficient.

---

# 9. USE ESTABLISHED RESEARCH

Study relevant published methods from:

- Dafny and Boogie.
- Rocq.
- Existing RISC-V and Linux process semantics.
- Verified compilation.
- Translation validation.
- Proof-carrying code.
- Incremental verification.
- Sigstore and in-toto.
- Theorem's published proof and sandbox infrastructure.

For each potentially useful external method, identify:

- Exact property established.
- Trust assumptions.
- Applicable artifact types.
- Reproduction requirements.
- Limitations.
- Integration cost.

Prefer using established methods over recreating them.

Forge's differentiation should not be an invented theorem prover.

Its research thesis is the **independently enforced, continuous correctness lifecycle**:

Approved intent → correct implementation → checked executable → authenticated evidence → safe incremental verification → trusted admission.

Be explicit about existing work that already solves portions of this problem.

Do not invent competitive advantages.

---

# 10. ARCHITECTURAL RESTRAINT

Keep the system minimal.

Reuse current:

- Verification backends.
- Gate code.
- Obligation registry.
- Coverage machinery.
- Evidence schemas.
- Implementation locks.
- Provenance components.
- GitHub workflows.
- Existing research examples.

Before adding a new service, cache, policy language, database, proof abstraction or orchestration framework, establish:

1. Which concrete requirement the existing implementation cannot satisfy.
2. Why the new component is necessary.
3. Which trust boundary it introduces.
4. Which invariant it preserves.
5. What experiment proves the improvement.

No unrelated refactors.

No new frameworks simply because they are interesting.

No broad redesign when a local change suffices.

**Complexity must be justified by correctness or measured utility.**

---

# 11. GOAL-SEEKING EXECUTION PROTOCOL

Operate as an autonomous engineering research agent within existing authority.

At each iteration:

### A. Establish state

Inspect actual code and evidence.

### B. Select the bottleneck

Choose the single missing assurance link that most directly prevents the active milestone from succeeding.

### C. State the hypothesis

Explain what result would close the gap.

### D. Execute

Implement the smallest authorized change or experiment.

### E. Verify

Run real established checkers.

### F. Attack

Run positive and negative controls.

### G. Reproduce

Check exact identities, dependencies and evidence.

### H. Decide

Compare actual results with the frozen acceptance criteria.

### I. Continue

Advance only when the current milestone has enough evidence and required authorization.

Do not loop indefinitely on an unchanged failure.

Do not repeatedly rewrite plans instead of executing them.

If one approach fails, preserve the evidence and investigate a justified alternative.

If a proof is infeasible, identify exactly why.

Distinguish:

- Fundamental undecidability or an insufficient theorem.
- Missing proof infrastructure.
- Unsupported semantics.
- Unverified environmental assumptions.
- Toolchain limitations.
- Resource exhaustion.
- Operational or authorization blockers.

Do not label all failures as engineering bugs.

---

# 12. APPROVAL BOUNDARIES

At every protected action, prepare an exact approval packet.

Include:

- Proposed change.
- Reason.
- Relevant source and artifact hashes.
- Required theorem or policy change.
- Expected security impact.
- Actual tests already run.
- Remaining assumptions.
- Reproduction commands.
- Negative controls.
- Required approving identity.

Do not create artificial approvals.

Do not use another account to evade independent review.

Do not weaken branch protection.

Do not sign or deploy without explicit authorization.

If approval is unavailable, continue another independent authorized task that advances the active milestone.

Do not mistake the absence of approval for a mathematical verification failure.

---

# 13. COMPLETION STANDARDS

## M1 — Executable correctness

Required:

- Approved nontrivial behavioral specification.
- Verified implementation-level property.
- Exact concrete executable.
- Checked connection between required property and executable behavior, under explicit assumptions.
- Independent proof checking.
- Exact artifact and dependency identities.
- Reproducible evidence.
- Negative controls rejecting invalid claims.

## M2 — Trusted admission

Required:

- Authenticated evidence.
- Trusted admission policy.
- Real positive admission.
- Real negative rejection.
- Unsupported-case refusal.
- Exact artifact binding.
- No candidate-controlled authority.
- Independent reproduction.

**After M1 and M2 pass, Forge has its first complete vertical slice.**

This is a major research milestone and should be reported separately.

It does not mean generic continuous software verification is complete.

## M3 — Continuous verification

Required:

- Correct affected-claim identification.
- Sound invalidation.
- Authenticated proof reuse within its declared trust boundary.
- Demonstrated reduction of redundant work.
- No observed false admission in the frozen adversarial matrix.
- Fresh-verification equivalence for supported cases.

## M4 — Practical developer system

Required:

- Working documented interface.
- Independent developer reproduction.
- Useful diagnostics.
- Frozen benchmark results.
- Measured verification costs.
- Explicit limitations.
- No hidden dependency on the author's workspace.

Do not announce overall mission completion before M1–M4 are established.

However, do not withhold a legitimate M1–M2 success merely because M3 or M4 is incomplete.

Report milestone-level successes precisely.

---

# 14. REQUIRED OUTPUTS

Maintain a compact, evidence-backed research record containing:

1. Current repository and authorization status.
2. Current active milestone.
3. Exact highest-priority assurance gap.
4. Approved behavioral claim and relevant assumptions.
5. Proof and executable identity.
6. Concrete-to-abstract correspondence record.
7. Independent verification results.
8. Adversarial acceptance matrix.
9. Provenance and admission evidence.
10. Incremental verification measurements, when applicable.
11. Remaining blockers.
12. Next smallest executable task.

For every check, include its actual exit code or mark `NOT RUN`.

Preserve historical evidence and failures.

Do not overwrite the original uncertainty log.

Make progress measurable by completed assurance links, not code volume, prompt length, proof-module counts or elapsed agent time.

---

# 15. FIRST ACTIONS — EXECUTE NOW

Begin with the current repository.

**Step 1:** Establish the exact current status of main, PRs #34/#36/#37, and the hosted booking experiment.

**Step 2:** Examine the existing functional proofs for ledger and refund against available executable-verification techniques.

**Step 3:** Determine whether the current RISC-V proof infrastructure can establish a nontrivial property of one of these components without requiring a new general-purpose verifier.

**Step 4:** Select the smallest meaningful component and freeze the intended correctness claim. If the necessary contract is not already approved, prepare it for human approval.

**Step 5:** Identify the single missing proof or correspondence link preventing M1.

**Step 6:** Execute the smallest authorized feasibility experiment that addresses that link.

**Step 7:** Run actual proof checks, negative controls and reproducibility checks.

**Step 8:** Produce a decisive feasibility verdict:

- `FEASIBLE_WITH_EXISTING_BACKEND`
- `FEASIBLE_WITH_ADDITIONAL_ESTABLISHED_TOOLING`
- `BLOCKED_BY_SPECIFICATION`
- `BLOCKED_BY_CORRESPONDENCE`
- `BLOCKED_BY_RUNTIME_ASSUMPTION`
- `NOT_ESTABLISHED`

**Step 9:** If feasible and authorized, continue implementing the vertical slice until the M1 acceptance criteria are met.

**Step 10:** Once M1 is established, connect it to trusted admission under M2.

Do not initiate M3 or M4 merely because M1 becomes difficult.

Do not treat more work on the old fixed-ELF example as progress toward a nontrivial behavioral vertical slice unless it closes a dependency required by the selected target.

Preserve all existing verified results.

Do not start Stage 12 without explicit authorization.

---

# FINAL DIRECTIVE

Forge is not trying to prove that an AI agent can generate a plausible implementation.

It is trying to establish that software produced by an untrusted agent can be independently checked against approved behavior and admitted only when the required correctness evidence is sufficient.

The foundational research question is:

**Can a software engineering system continuously produce, verify, authenticate, reuse and enforce correctness evidence about the exact executable artifacts created by autonomous agents?**

First answer the hardest part:

**Can we establish one nontrivial behavioral correctness claim about a real executable and enforce that claim through independent admission?**

Then extend it to changes over time.

Then make it efficient.

Then make it usable.

Prioritize soundness over acceptance rate.

Prioritize real experiments over plans.

Prioritize independently checked evidence over model confidence.

Prioritize the smallest complete correctness chain over additional isolated proofs.

Preserve human authority over specifications and trust-critical policy.

Never manufacture success by weakening a required guarantee.

**Build the smallest genuine, independently reproducible implementation of continuous proof-carrying software engineering.**

Start with the repository. Identify the next missing assurance link. Execute every authorized step toward closing it.

Do not stop at planning.

Do not claim completion without passing the actual acceptance criteria.
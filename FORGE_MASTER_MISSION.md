# FORGE MASTER MISSION — Autonomous Verified Software Engineering

## Mission

Build Forge into the strongest practical system for autonomous, independently verified software engineering.

**North star: AI proposes and builds. Established checkers verify. Humans approve intent and authority. Deployment enforces verified policy.**

Forge must eventually enable an AI agent to take an approved behavioral specification, design and implement software, discover and construct proofs, identify and repair defects, reuse previously verified computation, and produce deployable artifacts with independently checkable evidence.

The agent must never obtain authority to certify its own work, weaken an approved specification, fabricate evidence, or bypass the verification and release process.

The goal is not merely to create a theorem prover, CI wrapper, coding agent, or collection of demos. The goal is an integrated, reproducible, generalizable system that makes rigorous software assurance practical.

Success must be demonstrated with real evidence, realistic software, adversarial tests, and independently reproducible benchmarks.

## Operating mode

Work autonomously within existing authorization boundaries. Use the current repository, git history, active PRs, evidence, and installed tools as the source of truth.

Begin with reconnaissance. Do not presume that published documentation, old stage records, working-tree state, and GitHub agree.

Do not restart the project, overwrite existing progress, or implement the entire vision at once.

Execute the smallest authorized work that measurably advances the mission. When an action requires human approval, stop at that boundary, prepare the exact reviewable proposal, and continue independent safe work if available.

Never self-approve, bypass branch protection, weaken checks, alter trusted evidence to obtain acceptance, or silently change formal claims.

Do not initiate Stage 12 or any newly protected work without its required authorization.

## Phase 0 — Establish the actual current state

Inspect:

- Main branch and local worktrees, commits, uncommitted changes, and outstanding PRs.
- ROADMAP.md, VISION.md, README.md, AGENTS.md, formal specifications, verification policies, implementation locks, and uncertainty records.
- The existing Stage 11 results and strict integration EXIT.
- PR #34: hosted booking demonstration.
- PR #36: proof-report upload repair.
- PR #37: proposed fixed-ELF termination claim.
- Linux CI runs, artifact bundles, exact exit codes, and evidence backup status.
- Dafny, Rocq, SMT, incremental verification, proof reuse, provenance, signing, and release-admission mechanisms.

Establish a capability inventory with four classifications:

1. ESTABLISHED — Independently checkable evidence supports the precise claim.
2. TESTED — Finite tests or experiments support a limited empirical claim.
3. PARTIAL — Working components exist, but required links are missing.
4. UNESTABLISHED — Required evidence is absent or the mechanism does not exist.

Never confuse a successful test with a universal proof or a successful proof with an actual deployment guarantee.

Produce a truthful state report identifying exactly which claims apply to which source files, ELF bytes, formal semantics, runtime configurations, and release artifacts.

## Phase 1 — Define the target architecture

Derive a coherent architecture for Forge's final system.

It must contain:

**A. Intent and specification**

Translate human requests, examples, constraints, and safety requirements into proposed formal contracts.

Detect ambiguity and missing requirements. Produce counterexamples. Require human approval for changes to intended behavior.

**B. Autonomous engineering**

Allow agents to design, generate, refactor, repair, and optimize implementations.

Enable agents to construct proof obligations, propose invariants, discover reusable lemmas, and respond to checker-generated counterexamples.

**C. Independent verification**

Use established formal checkers and test engines, selecting appropriate methods for each property.

Separate source proofs, binary proofs, bounded model checking, property testing, integration testing, and observed runtime behavior.

No untrusted agent assertion may substitute for independently checked evidence.

**D. Dependency-aware verification**

Maintain a sound graph of artifacts, claims, assumptions, inputs, and proof obligations.

Invalidate verification when relevant dependencies change.

Permit reuse only when all premises, artifacts, authorities, and verification methods remain valid.

**E. Source-to-execution assurance**

Connect approved source-level claims to exact executable artifacts using justified compilation, binary verification, or other explicitly scoped correspondence evidence.

Account for initialization, memory, loading, system calls, environment behavior, and relevant runtime assumptions.

**F. Proof-carrying release**

Bind exact executable identities, approved policy, evidence, signers, provenance, and authorization to a release decision.

Ensure the deployment controller refuses any artifact that does not satisfy mandatory admission conditions.

**G. Knowledge and proof reuse**

Build a repository of reusable checked lemmas, proof patterns, verified dependencies, and compositional interfaces.

Agents may discover useful abstractions, but independent checkers determine whether they are valid and applicable.

**H. Developer experience**

Provide an installable CLI, meaningful diagnostics, machine-readable evidence, integration hooks, and human-readable explanations of assurance coverage and missing proof obligations.

Deliver an architecture diagram in Mermaid that distinguishes trusted components, untrusted agents, proof checkers, evidence stores, approval authorities, and deployment boundaries.

## Phase 2 — Complete the existing foundation

Before implementing substantial new functionality:

1. Resolve or accurately characterize the outstanding strict integration EXIT.
2. Establish whether all required off-machine evidence backups exist and can be restored.
3. Verify the real Linux cold/warm/invalidation and adversarial results, not just summary exit codes.
4. Maintain independent approval for protected changes.
5. Preserve proof-gate refusal for unsupported or unauthorized inputs.
6. Reconcile stale documentation against actual evidence.
7. Reduce unnecessary complexity and duplicate mechanisms without weakening assurance.

Measure the size and complexity of the trusted computing base and identify which components can be removed, isolated, or independently checked.

Do not expand the scope of accepted changes merely to make existing demonstrations pass.

Exit criterion: a reproducible, reviewable foundation in which evidence claims and actual checker behavior agree.

## Phase 3 — Close the model-to-execution gap

Focus first on Forge's existing fixed RISC-V ELF, without generalizing prematurely.

The current research established a formal termination claim under LPS assumptions and observed a compatible QEMU register trace. Full correspondence is not established.

Construct a complete assumption-to-evidence matrix covering:

- Register initialization and entry-state validity.
- Memory initialization, mapping, and permissions.
- Exact ELF content and loader behavior.
- Stack, heap, and address-space assumptions.
- System calls and environment responses.
- Execution semantics and observable events.
- Runtime artifact identity.
- All additional axioms, trusted components, and modeling assumptions.

For each required condition, supply either an independently checkable proof, a justified trusted assumption, bounded empirical evidence, or an explicit unresolved status.

Determine the narrowest defensible theorem-to-runtime claim.

Do not treat register equality as full-state equality. Do not infer universal refinement from one successful trace.

Aim to establish one coherent proof-to-execution evidence chain for the fixed artifact, with all residual assumptions disclosed.

If additional theory or runtime instrumentation is necessary, propose the smallest independently reviewable change.

## Phase 4 — Make Forge autonomous

After the foundation is sufficiently stable, design and evaluate an autonomous engineering loop:

1. Read the approved contract.
2. Generate implementation candidates.
3. Derive or select proof obligations.
4. Construct candidate proofs.
5. Invoke independent verification.
6. Analyze failures and counterexamples.
7. Repair implementations or proofs without changing approved intent.
8. Reuse valid existing evidence.
9. Request human decisions only where required.
10. Produce a reproducible acceptance or refusal record.

Use bounded attempts and resource budgets.

Ensure agent-generated content cannot alter verifier authority, acceptance policy, or trusted baseline.

Add adversarial tests for incorrect specifications, missing dependencies, fabricated proofs, forged receipts, stale cache entries, checker manipulation, and unauthorized policy changes.

## Phase 5 — Build an actual product

Create an incremental plan for:

- Stable and minimal CLI/API.
- Installation on a clean supported machine.
- Independent evidence replay.
- Language/backend adapters.
- Per-property coverage and claim reports.
- Authenticated cross-run evidence reuse.
- Repository and CI integration.
- Evidence-preserving release policy enforcement.
- A useful agent-facing skill or protocol.

Avoid abstracting before demonstrating at least two distinct real-world integrations.

Choose an initial narrow product wedge where the assurance guarantees matter, such as transactional invariants, idempotency, authorization decisions, or workflow state machines.

Ensure users can understand exactly what is verified, what is tested, what is assumed, and what is unsupported.

## Phase 6 — Establish superiority through benchmarks

Design a preregistered benchmark with held-out tasks.

Compare Forge against:

1. Ordinary tests and CI.
2. Standard formal verification with human-guided proofs.
3. AI coding agents using the same implementation model but without Forge's proof-gated workflow.
4. Existing native verifier caching and fixed reusable proof libraries.

Where meaningful, compare autonomous proof discovery to human-selected reusable lemmas.

Use matched compute, time, and model budgets wherever possible.

Measure:

- Accepted changes satisfying independently adjudicated requirements.
- False acceptance and false rejection rates.
- Verified property coverage.
- Defects found by adversarial tests.
- Source-to-deployment assurance coverage.
- Human interventions and review time.
- End-to-end task completion time.
- Cold and warm verifier execution time.
- CPU, memory, API tokens, and total cost.
- Cache reuse correctness and benefit.
- Proof maintenance burden.
- Generalization to new components and repositories.

Publish the frozen benchmark specification, failures, controls, raw data, assumptions, and limitations.

A faster workflow with weaker assurance is not automatically better. A more rigorous workflow with unusable latency is not automatically better either.

Optimize the assurance-to-effort tradeoff without compromising required correctness conditions.

## Phase 7 — Establish autonomous verified delivery

Demonstrate at least one complete, scoped change lifecycle:

Approved intent → agent-generated implementation → independent proof/evaluation → authenticated evidence → authorized release → artifact identity verification → runtime admission → post-deployment observation.

Include adversarial controls at every trust boundary.

The final report must distinguish:

- Proven behavioral properties.
- Assumed compiler/runtime properties.
- Empirically tested integration properties.
- Provenance and identity guarantees.
- Observed deployment behavior.
- Unresolved risks and unsupported claims.

Never set `end_to_end=true` without specifying which end-to-end claim is established and satisfying every required obligation for that claim.

Whole-application universal correctness is not a permissible inference from a narrow component demonstration.

## Execution discipline

Treat each milestone as an independently auditable research and engineering result.

For every proposed implementation:

- Identify the exact problem and why the change is necessary.
- Identify the trust boundary being crossed.
- State the expected improvement and acceptance criteria before implementation.
- Identify all affected proof obligations and dependencies.
- Create adversarial rejection controls before claiming success.
- Record exact commands, inputs, outputs, exit codes, and artifact hashes.
- Preserve failed experiments and negative results.
- Request independent review where required.
- Prefer minimal diffs and reusable existing mechanisms.
- Avoid adding orchestration or abstraction layers without demonstrated benefit.

Separate infrastructure errors, expected security refusals, failed proofs, unproven claims, and actual implementation defects.

Do not equate operational progress with an increase in formally established correctness.

## Required deliverables

First produce:

**1. Current-state audit**  
What Forge actually proves and does today, with concrete evidence references.

**2. Capability-gap analysis**  
Every major missing capability between the current foundation and autonomous verified software engineering.

**3. Target architecture**  
Mermaid diagrams, components, trust boundaries, evidence flows, deployment controls, and technical choices.

**4. Prioritized milestone roadmap**  
Dependencies, implementation scope, required research, adversarial controls, acceptance criteria, and explicit authorization boundaries.

**5. Next-action plan**  
The five highest-leverage next actions, ordered by what unblocks the most subsequent work. Distinguish ready-to-execute work from human approval requirements.

**6. Benchmark plan**  
How we will demonstrate usefulness and superiority over simpler alternatives.

**7. Risk and complexity assessment**  
Top correctness risks, trusted computing base, source-to-runtime gaps, operating cost, maintenance burden, and opportunities to simplify.

## Final directive

Do not optimize for the number of commits, stages, features, or proofs produced.

Optimize for making Forge a credible, useful, independently verifiable autonomous engineering system.

The desired end state is a system where software agents can perform substantial engineering work autonomously, while correctness claims are bounded by independently checkable evidence and human-approved requirements.

Start with the repo audit. Work toward the north star in dependency order. Complete authorized work and stop at required approval boundaries.

At the end of each meaningful step, report:

- What changed.
- What was independently established.
- What remains unproved.
- What new evidence was produced.
- Whether complexity increased or decreased.
- What the smallest next action is.

**Build the system that makes autonomous software engineering trustworthy—not merely a system that generates more code and more proofs.**
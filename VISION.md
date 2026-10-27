# Forge: horizon and limits

This file describes long-term directions only. Do not implement these items
through the current roadmap. Follow [ROADMAP.md](ROADMAP.md) and work only on
its CURRENT stage.

## Horizon

- **Verified compilers per language.** Connect a source theorem to an executable
  through a checked semantic-preservation argument. State which language subset,
  compiler passes, runtime, and linking steps that argument covers.
- **Independent proof kernels.** Check appropriately translated claims with more
  than one established kernel. Record the translation and shared assumptions.
  Agreement is useful evidence, not automatic independence of failure modes.
- **Public registry of verified dependencies.** Publish claims, exact artifact
  identities, assumptions, toolchain pins, and reproducible evidence. Reuse must
  preserve the premises under which a dependency was checked.
- **Proof-carrying deployment.** Let a runtime refuse uncertified code under an
  explicit policy. Connect admission to the actual loaded artifact and its
  dependencies, rather than only a release label.
- **Verified OS and hardware links.** Extend checked coverage through operating
  system and hardware models where established tools support it. State remaining
  model-to-machine assumptions.
- **Spec elicitation from dialogue.** Turn discussions, examples, and rejected
  cases into proposed specifications. Humans approve the intended behavior and
  boundaries before those specifications govern acceptance.

## Irreducible limits

**Specification and human intent.** A checker establishes a formal statement.
It cannot establish that the statement fully captures what a person wanted.
Examples, review, and operational feedback remain necessary.

**Physical hardware and the world.** A theorem concerns a model. Hardware faults,
physical effects, and external systems can differ from that model. Name the
assumptions instead of treating the modeled system as the entire world.

**Root-of-trust consistency.** Every result depends on a logical foundation and
trusted components. Checking more links does not remove that root of trust.
Disclose axioms, kernels, semantics, and other relied-upon tools.

**Undecidability.** No general procedure proves every true property of arbitrary
programs. Some correct code will remain unproven. A failed proof attempt may
reflect resource limits, missing lemmas, or tool limitations rather than a bug.

**Goals without a complete formal specification.** UX quality, usefulness, and
ML output quality remain measured where no adequate formal claim is available.
Do not rename evaluations or observations as proofs.

## Product hypothesis

### Two separate research objectives

**First: concrete binary evidence.** Complete Stage 7 with the published
Rocq/RISC-V pipeline. Replay an upstream proof, require rejection of an invalid
proof, and check an own C or Rust binary proof with `rocqchk` and the assumption
audit. Bind each result to the exact binary and model. This is the current
research objective. Release provenance and deployed identity remain separate
links in the foundation; a binary theorem alone does not establish deployment
coverage.

**After Stages 0–10: agent discovery of reusable abstractions.** Investigate
whether agents can identify, propose, prove, and use general lemmas or interfaces
across tasks. Stage 6 demonstrated deliberate reuse of ledger lemmas in booking
and measured the existing verifier's cache. It did not measure an autonomous
abstraction-discovery system or establish an advantage over existing tooling.

Compare the proposed discovery system with fixed specifications and equal
resource budgets against fresh verification, the existing native cache, and
human-selected shared lemmas. Use held-out tasks and domains. Count discovery,
failed candidates, proof and maintenance costs, tokens, attempts, verifier work,
and human interventions. Measure whether total cost falls while checked claim
coverage and rejection controls remain intact. Report negative results and
limits. Cache reuse alone cannot establish the discovery hypothesis.

Agents may propose abstractions; established checkers must validate their proofs
and the premises at each use. Discovery must not weaken protected specifications
or introduce unchecked assumptions. This is future research, not current
implementation scope.

### First public product priorities

These are the first productization priorities after the foundation. Document
them here now; do not implement later-stage work while Stage 7 is current.

1. **Installable CLI.** Provide a documented installation and a small, stable
   command interface for checking a project and reading its evidence.
2. **Independent replay.** Let a developer reproduce a bundle from its exact
   inputs on a clean supported host, without the producer's cache or workspace.
   State the shared toolchain and trust assumptions; replay does not imply an
   independent proof kernel.
3. **Agent skill.** Provide instructions that agents can use to propose changes,
   respect specification approval, invoke the CLI, and report failures honestly.
4. **Verification impact reports.** Show affected claims, checked and reused
   obligations, assumptions, artifact identities, costs, and remaining gaps in
   language that a developer can act on.

Measure installation success, replay success, time to a first useful report,
diagnostic usefulness, and adoption costs on real projects. These are product
hypotheses, not results established by the existing examples.

The system may benefit many engineers if it makes rigorous checks practical for
small, important parts of ordinary applications. It must give useful diagnostics,
keep setup and verification costs manageable, and make each evidence boundary
clear. Its value across projects must be demonstrated through actual use.

The aim is precise, inspectable assurance. No badge or evidence bundle should
suggest that all behavior, all environments, or human intent have been proved.

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

The system may benefit many engineers if it makes rigorous checks practical for
small, important parts of ordinary applications. It must give useful diagnostics,
keep setup and verification costs manageable, and make each evidence boundary
clear. Its value across projects must be demonstrated through actual use.

The aim is precise, inspectable assurance. No badge or evidence bundle should
suggest that all behavior, all environments, or human intent have been proved.

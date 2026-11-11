# Forge PR verification: product contract (Stage 11, proposal v1)

Owner mission 2026-10-30. Builds on PR #27 (not assumed merged). Nothing here is
installed. `end_to_end=false`.

## 1. What the product says about a PR

The gate publishes one **outcome** for the whole PR and one **scope line per claim**.
The outcome never says more than the claim lines establish.

| Outcome | Exit | Meaning |
| --- | ---: | --- |
| `VERIFIED` | 0 | Every change in the PR is an input of at least one obligation, and every obligation whose inputs changed was re-established on the exact candidate bytes (fresh run or identical-identity reuse). Nothing else is claimed. |
| `UNSUPPORTED` | 3 | Some change is not an input of any obligation, or is a bound harness input that no run can judge (`NOT_REESTABLISHABLE`), or some reader of a changed file has no obligation that re-establishes it. Obligations do not run while a change is uncovered, so a defect in the covered part of such a PR is reported only after the PR is fully covered. A statement about evidence, not a defect. |
| `REJECTED` | 1 | An obligation failed (proof, test, binding, reproduction) or a policy/authorization rule was violated. |
| `NOT_ESTABLISHED` | 2 | A tool, dependency pin, toolchain, revision or I/O error stopped the check. |

**Verified properties vs whole-change verification.** `VERIFIED` means exactly: "the
listed claims hold for the listed artifacts by the listed methods, and the PR touches
nothing outside those artifacts' input sets." It does not mean the software is
correct. The report lists each claim with its method (`source_proof`,
`tested_against_proved_model`, `property_tested`) and its artifact digest, so a
property-tested claim is never shown as proved.

## 2. Obligations and the dependency graph

An **obligation** is an existing trusted gate command with:

- `claims`: the claim ids and methods it establishes;
- `inputs`: the exact paths it hashes (its own `trusted_input_sha256` keys plus its
  `source_manifest` paths). The registry declares them; after every run the gate's
  bundle is compared with the declaration, and a mismatch is `NOT_ESTABLISHED`
  (`OBLIGATION_INPUTS_DRIFT`). The declaration is therefore checked against the
  gate, not trusted on its own.
- `subjects`: the inputs under test (the gate's source manifest, plus an explicit
  evidence argument). They may differ from the trusted base. **Every other input must
  equal the trusted base's bytes**, checked before the run (candidate bytes) and after
  it (the digests the gate recorded), except `impl/Ledger.dfy` and approved spec
  inputs, which another obligation of the same run establishes. A difference is
  `REJECTED: TRUSTED_INPUT_CHANGED`. The harness files that obligations execute
  (`scripts/javascript_env.py`, `scripts/build_model.py`, `interop/*`,
  `tests/ledger.property.ts`, `tsconfig.json`, `package.json`, `package-lock.json`)
  are also protected files, so a PR that touches them is rejected before anything runs.
  An obligation therefore never executes candidate-authored code, with one deliberate
  consequence: the TypeScript harnesses (`tests/ledger.property.ts`,
  `gate/refund/hostile.ts`) load the code under test into their own process, where a
  changed subject could rewrite the verdict. So `ts/ledger.ts`, `ts/types.ts`,
  `ts/refund.ts` and the Stage 5 witness file are **bound inputs**, not subjects: a PR
  that changes them is `UNSUPPORTED` (`NOT_REESTABLISHABLE`) until those harnesses run
  the subject in a separate process. The TypeScript model and the hostile tests still
  re-establish their claims when the *Dafny* side changes (the model is recompiled from
  the candidate ledger; the unchanged wrapper is tested against it). The only candidate
  code that executes is the audited, verified Dafny implementation compiled to
  JavaScript. It can print to the harness's stdout (which no gate parses), read
  `process.argv`, run at module load if it declares `Main`, and halt with exit code 1;
  it cannot read or write files or set exit code 0, so it cannot change a verdict.

Initial registry (all exist today):

| Obligation | Command | Claims |
| --- | --- | --- |
| `ledger-proof` | the existing snapshot proof in `incremental.py` | C1–C5 `source_proof` |
| `ledger-evidence` | `gate/gate.py --check-evidence evidence.json` | the committed evidence reproduces |
| `ledger-model` | `gate/gate.py --backend typescript --impl ts/ledger.ts --tier standard` | C1–C5 `tested_against_proved_model` for `ts/ledger.ts` |
| `ledger-witness` | pinned `dafny audit` (against `gate/expected-audit.md`) and `dafny verify` of `tests/stage5/SuccessfulExecution.dfy`, requiring the named members `SuccessfulExecution.Witness`, `Ledger.Apply`, `LedgerSpec.Apply` | witness obligation W (`tests/Basic.dfy` is covered by no obligation) |
| `booking` | `gate/booking.py` | B1–B4 `source_proof` |
| `refund-proof` | `gate/refund.py --tier critical` | R1–R5 `source_proof` |
| `refund-tests` | `gate/refund.py --tier hostile-tests` | T1–T3 `property_tested` |

The **dependency graph** is: changed path → obligations that list it as an input →
claims. It is derived from the gates' declared and self-reported input sets, never
from file names alone and never from text the PR supplies. Two extra edges come
from the tree itself: Dafny `include` lines and approved `spec/**/spec.lock` pins.
A path reached by those edges that is an input of no obligation is an **unknown
dependency** → `UNSUPPORTED`.

**Affected obligations** = those with an input in `Changed(B, C)` ∪ {`ledger-proof`}.
Every affected obligation runs on the **verification tree**: an immutable copy of the
candidate whose protected manifest (`gate/`, `policy/`, `spec/`, `toolchain/`,
`schemas/`, `.github/`, `spec.lock`, `AGENTS.md`) equals the trusted base's, with the
trusted base's `.toolchain` and `node_modules` linked in. The gate code that runs is
therefore byte-identical to the trusted gate.

**Reuse.** An obligation is reused instead of run only when a record produced by
this trusted gate and stored in its content-addressed cache has the same key: the
obligation's declaration, every input's inventory entry, the trusted base's protected
manifest and its toolchain pins. Records are stored only after the verification tree
re-hashed identically. Any difference is a fresh run. Reuse never changes the decision.

**Execution hygiene.** Obligations run in their own process sessions and everything
they forked is killed when they return; bytecode is neither read from nor written to
the candidate tree (`__pycache__` removed from the copy, `PYTHONDONTWRITEBYTECODE`,
a private `PYTHONPYCACHEPREFIX`); a candidate's `.pyc` files count as changes.
Obligations do not run at all while any change is uncovered: the PR is `UNSUPPORTED`
first, and defects in its covered parts are reported once the PR is fully covered.

## 3. Invariant

```
Verified(PR) =>
  forall p in Changed(B, C): exists o in Obligations: p in inputs(o)              (covered)
  and forall o in Affected(B, C): established(o, C)                             (re-established)
  and forall r in Readers(C, Changed): exists o: r in inputs(o)                 (no unknown dependency)
  and protected(B) = protected(C) or approved exactly                          (authorization)
  and every established(o, C) rests on a checker run on C's bytes or an
      identical-identity bundle from a trusted run                             (no stale evidence)
```

## 4. Threat model and trusted computing base

Adversary: the PR author, including an AI agent, controls every byte of the
candidate tree and may craft file names, links, includes, evidence files, and
generated artifacts. The adversary does not control the trusted base checkout, the
runner, GitHub's event data, or the pinned toolchain bytes.

Trusted: the trusted base checkout (obtained outside the PR); Dafny 4.11.0, Z3,
Node 24.3.0 and the pinned npm packages as content-pinned; Python 3.10.11 and the
pinned validator packages; the gate code and this registry; the CI runner and GitHub.
Not trusted: anything in the candidate, including its copy of the gate (used only
because it is proven byte-identical to the trusted copy).

## 5. Known limitations (disclosed, not fixed here)

- **CI shape.** The dependent gates select the local (macOS) toolchain pins and need
  `node` plus the pinned `node_modules`; the current workflow installs neither on Linux.
  In CI today every affected JavaScript or Dafny sub-gate would be `NOT_ESTABLISHED`.
  The Stage 11 EXITs are established on the owner's recorded host only. Linux pins for
  node and per-gate profile selection are a separate change.
  *Update 2026-10-30 (candidate `561d2dda`, not merged):* host-profile pin selection and
  `toolchain/javascript-linux-pins.json` were built and exercised on a fresh ubuntu-22.04
  x86_64 container: booking and refund alternatives VERIFIED with their dependent
  obligations re-established; a ledger change is NOT_ESTABLISHED there because the
  committed `evidence.json` binds the macOS pin files (`EVIDENCE_PROFILE`). The workflow
  still lacks the Node step. See `results/ops-readiness/`.
- **Dependency edges modelled:** Dafny `include` lines, approved spec-lock pins and the
  obligations' declared inputs. TypeScript imports are not modelled. Because every
  TypeScript file an obligation executes is bound to the trusted base, no PR can add a
  cross-file import through this gate; the import graph can only change under review.
- **Useful acceptance today is limited to the Dafny side**: `impl/Ledger.dfy` (with
  regenerated `evidence.json`), `impl/Booking.dfy`, `impl/Refund.dfy`, their specs by
  approval, and the booking witness. TypeScript changes are UNSUPPORTED until the
  harnesses isolate the subject (next engineering item). A ledger change that alters
  the observable behaviour of `Apply` fails `ledger-model` (the trusted wrapper no
  longer matches the new model) and is REJECTED; the wrapper cannot be updated through
  the gate, so such a change and its wrapper must both change under review.
- `proposals/*-decision.md` records are hashed inputs of the booking and refund gates
  and are bound to the trusted base; a PR that edits them is rejected until the gate
  itself is changed under review.
- Obligation processes run as the same user as the gate. A process that leaves its
  session (`setsid`) survives the group kill; the only candidate code that executes is
  audited Dafny compiled to JavaScript, which has no file or network I/O without
  externs (excluded by the byte checks and the empty audit table); its remaining
  effects are stdout, `process.argv` reads, exit code 1 and resource exhaustion
  (timeout → NOT_ESTABLISHED). A persistent
  local obligation cache is trusted to be writable only by the gate; CI starts empty.
- Over-rejection by contract: documentation, new tests, new modules, `app/`,
  `results/` changes are `UNSUPPORTED`; an approved ledger spec change is
  `UNSUPPORTED` while fixtures in `bugs/` and proposal copies include the spec with no
  obligation covering them.

## 6. Non-claims

Not correctness of the whole program; not compiled-binary, deployment or runtime
behaviour; not independence from the authors; not a proof about the implementation
of the gate (the model theorem is about the model).

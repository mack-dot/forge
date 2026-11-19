# Stage 9 binding proposal (DRAFT)

**NOT APPLIED. NOT AUTHORIZED.** This is a draft of worker W6, step III of
the M1-B mission, written 2026-11-19. It changes no file. It unlocks nothing.
Stage 9 stays deferred by the owner's decision (`unsure.md` U470). No
signature, no workflow dispatch, no Rekor entry follows from this text.
Every digest below is an observation of the working tree at `HEAD`
`8e772b55` (branch `docs/m1-owner-decisions`). Each one goes stale when a
listed file or the tree under `scripts/`, `gate/provenance/` or
`examples/binary/` changes. Recompute all of them at the time of use.

## 0. What Stage 9 binds today

- Contract `spec/provenance/protocol.md` 1.0.0 (`2784bdd0…`), policy
  `forge-stage9-provenance` 1.0.0 epoch 1 (`9e27f627…`), lock
  `spec/provenance/spec.lock` (`43610d81…`), implementation lock
  `gate/provenance/implementation.lock` (`76b983ac…`).
- One release artifact: the Stage 7 RISC-V ELF
  `results/stage7/accepted/own/gcd-selftest.elf`, 1,240 bytes, `8ced2ab6…`.
  Claims `S7-OWN-TERMINATION`, `S7-OWN-VALID-EXECUTION`, method
  `kernel_checked_proof` (Rocq `rocqchk`). Stage 8 refund evidence is
  supplementary only.
- Signer: `https://github.com/mack-dot/forge/.github/workflows/provenance.yml@refs/heads/main`,
  issuer GitHub Actions OIDC, repository ID 1434789853, owner ID 235131950.
- Nothing in Stage 9 names the M1 executable `b8ed5ec2…7bb8`
  (`proposals/forge2-m1-conformance/artifacts/refund-arm64-macho`, ARM64
  Mach-O, 238,776 bytes) or a HOL4 theorem. The contract text says "The only
  release artifact is the 1,240-byte ELF". So a binding to M1 is a new
  contract version, not a lock refresh.

## 1. Preconditions (evidence that must exist first)

| ID | Evidence | Who |
| --- | --- | --- |
| P1 | M1-B CLOSED, recorded in `unsure.md` with the owner's decision | owner |
| P2 | Phase II manifest final: spec digest, source digest, HOL4 theorem names and statements, proof dependency identities, compiler configuration and pins, artifact SHA-256, assumption profile, replay and review evidence; its own SHA-256 | W5 + owner review |
| P3 | No more code planned under `scripts/`, `gate/provenance/`, `examples/binary/` before the rebind (each new code file makes the lock stale; U469, U470) | owner |
| P4 | Account separation: the agent's `gh` login is a non-admin machine account (`gh api user --jq .login` is not `mack-dot`; `.permissions.admin` is `false`). Precondition of `proposals/provenance-hosted-v33/INSTALL.md`; false today (U469) | owner |
| P5 | Owner decision: track R (refresh of contract 1.0.0 only), track M (new contract 2.0.0 for M1), or both in sequence | owner |
| P6 | Owner decision on the U166/U169 residual findings F1, F3, F4 of the observer and package check (fix before a wider threat model) | owner |
| P7 | Owner decision on the deployment model for a Mach-O (see M4) | owner |

## 2. Track R: refresh of the existing contract 1.0.0 (smallest step)

Purpose: make Stage 9 v1.0.0 pass its own lock check on the present `main`
again. It binds nothing new. Order of changes:

| # | File | Protected | Change | Why | Evidence first |
| --- | --- | --- | --- | --- | --- |
| R1 | `spec/provenance/spec.lock` | yes (`spec/`; PR gate protected manifest, `gate/incremental.py:38`) | 8 digests of `locked_existing_files` to the current bytes (packet part B2) | `context()` refuses each with `LOCKED_INPUT` (`gate/provenance/common.py:139-140`) | P3, P5 |
| R2 | `gate/provenance/implementation.lock` | yes (`gate/`; excluded from Tier-0, `gate/approval.py:22`) | 8 digests (A1); add `gate/ratification.py` (A2); add the 6 unlocked scripts (B1) plus any script added since; `spec/provenance/spec.lock` digest from R1 (B3) | `bootstrap.py:73-78`, `common.py:197-205` refuse unlocked code and changed inputs | R1 bytes final |
| R3 | `.github/workflows/booking-reuse.yml` line 43 | yes (`.github/`) | old lock value `76b983ac…` to the new lock value | the only other tracked pin of the lock digest (line 42 pins `bootstrap.py` `8895a088…`; it stays valid if `bootstrap.py` does not change) | R2 digest final |
| R4 | `governance/ratifications/0002-baseline-<commit>.json` (new) | yes (`governance/`) | baseline record that names a `main` commit after the administrator merges, with its tree and lock, and lists the unapproved merges as audited (same schema as record 0001) | `approved_lineage` (`common.py:304-331`) needs an owner review of the exact head for every first-parent commit back to a ratified baseline. 17 of 27 first-parent commits since `19c4896b` have author `mack-dot`; the merges of this effort were administrator merges without a review (U463 to U471). Inference, not run: the release check rejects `UNAPPROVED_LINEAGE:NO_EXACT_HEAD_OWNER_APPROVAL` today | P4; a GitHub API audit of every commit since `19c4896b` (needs the network; not run here) |
| R5 | `ROADMAP.md`, `unsure.md` | no | records | AGENTS.md | after the merge |

R1 to R4 go in ONE pull request, authored by the machine account and
approved by the owner's review of the exact head (no administrator bypass),
because the lineage check reads that review. The hosted PR gate will report
REJECTED (exit 1) for it: `gate/provenance/` and `governance/` are not
ratifiable (`gate/approval.py:19-32`). That is expected and is no approval.

### The lock refresh as it would look (values valid on 2026-11-19 only)

The unapplied packet `proposals/stage9-lock-rebind-20261119/proposed.diff`
(`64c1b3d9…`) still applies to `HEAD` `8e772b55` (`git apply --check`: exit
0). Applied in a scratch copy it gives `implementation.lock` `190f938e…`
(107 entries, 107 equal to the working tree) and `spec.lock` `256310d8…`
(47 entries, 47 equal), and no unlocked code file in the three roots.

| File | Today | Proposed (2026-11-19 tree) |
| --- | --- | --- |
| `gate/provenance/implementation.lock` | `76b983ac279a80ab42bf15c7446ee997a2bcd9b25a003db829f7e8fb2d4b8cd9` | `190f938e387a92ef891a4a286c5d08ce4803d36fdb34a7d074631043aabb4a6b` |
| `spec/provenance/spec.lock` | `43610d8123ce21fdd1f9dac9469f78ad3efcb3af271a86011a18790099811a33` | `256310d851669cdeab2498b0a58fe6bcd4b7ba1f741396a9f608d644fa72a976` |

Regeneration rule at the time of use: (1) compute the SHA-256 of every
`files` entry and every `locked_existing_files` entry from the merged tree;
(2) list every tracked file under `gate/provenance/` and every file with a
code suffix under `scripts/` and `examples/binary/`; (3) write `spec.lock`
first, then its digest into `implementation.lock`; (4) run in a clean clone
without `scripts/__pycache__`:
`python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 <new> --check`
(expected `BOOTSTRAP_VERIFIED`; that is a lock check, not an EXIT result).

Reusable from the packet: its method, the A1/A2/B1/B2/B3 lists and (if the
tree is unchanged) its exact bytes. Not in the packet: R3 (the
`booking-reuse.yml` pin) and R4 (the baseline record). Not reusable under
track M: the bytes, because track M rewrites both locks.

## 3. Track M: new contract 2.0.0 bound to the M1-B artifacts

Every file below is protected. Each needs the owner's approval of exact
bytes. The contract change (M1 to M3) needs a new owner-approved contract
version (as `097431cf` was for 1.0.0), not a lock refresh. The code change
(M4 to M9) needs a separate exact implementation approval
(`activation_requires_separate_exact_implementation_approval: true` in
`spec.lock`). Order:

| # | File | Change | Why | Evidence first |
| --- | --- | --- | --- | --- |
| M1 | `spec/provenance/protocol.md` (or a new `spec/provenance/v2/protocol.md`) | version 2.0.0: release artifact `b8ed5ec2…7bb8`; claims and methods from the Phase II manifest (HOL4 kernel replay instead of `rocqchk`); assumption profile (Profile A, compiler premises, Mach-O loader, libSystem); scope of deployment; `end_to_end=false` | 1.0.0 names only the Stage 7 ELF and Rocq | P1, P2, P7 |
| M2 | `policy/provenance.json` | `version` 2.0.0, `epoch` 2; `release_artifact` (path, 238,776 bytes, kind, target `aarch64-apple-darwin` or as recorded); `required_claims` with HOL4 theorem IDs and `spec_sha`; `proof` section; `deployment` section; consider a new `predicate_type` `…/provenance/v2` | the verifier binds request and evidence to these fields (`release.py:237-271`) | M1 approved |
| M3 | `spec/provenance/spec.lock` | new contract and policy digests; replace Rocq lists (`checked_modules`, `theorem_assumptions`, `witness_assumptions`, `independent_closure_assumptions`) by HOL4 identities from P2; `locked_existing_files` with the M1 sources, HOL scripts, Phase II manifest, refund contract `spec/refund/spec.lock` `8b131ab8…` | the lock is the contract's identity list | M1, M2 |
| M4 | `gate/provenance/artifact-identities.json` | `receipt` (now Rocq `.vo` closure, `rocqchk` command) to the HOL4 replay receipt; `package` (linux/amd64 image, `/opt/forge/gcd-selftest.elf`) to the chosen deployment model | `release.py:61-148`, `producer.py:117-138` read these | P7, M3 |
| M5 | `gate/provenance/producer.py`, `release.py`, `observe.py`, `hosted_setup.py`, `preflight.py`, `runtime.json`, `Dockerfile` | replay job for HOL4 instead of `stage7_own_job.py`; receipt check without `rocqchk` and ELF magic rules; statement subject name (now `forge:gcd-selftest.elf`, `producer.py:211`); package and observer for a Mach-O | all are Rocq/ELF-specific today | M4 |
| M6 | `gate/provenance/common.py`, `bootstrap.py` | extend `CODE_SUFFIXES` (`.sml`, `.sig`, `.ts`, `.js`, `.cjs`, `.mjs`, `.dfy`) and, if HOL sources sit outside the three roots, `EXECUTABLE_ROOTS` | today `scripts/generate_examples.ts` is code and is allowed unlocked; HOL scripts would be too | M5 |
| M7 | `scripts/exit_stage_9.py` | fixtures that name the ELF | it runs the six cases | M5 |
| M8 | `.github/workflows/provenance.yml`, `provenance-negative.yml` | toolchain steps; `timeout-minutes` (300 today; a hosted job stops at 360). The time of a hosted HOL4 replay of the M1 chain is NOT measured | the sign job runs these | M5; a measured replay time |
| M9 | `gate/provenance/implementation.lock` | regenerate LAST over all of the above (rule of section 2) | every change above changes it | M1 to M8 merged |
| M10 | `.github/workflows/booking-reuse.yml`, `governance/ratifications/000N-…json` | as R3 and R4 | as R3 and R4 | M9 |

Open design questions for the owner (not decided here): (a) a Mach-O cannot
run in the linux/amd64 package of today; file identity in a container is
possible, execution is not; (b) whether the hosted Linux runner can rebuild
or re-check the M1 bytes, or only replay the HOL4 theories; (c) whether
contract 1.0.0 stays in force beside 2.0.0.

## 4. After the merge (each needs the owner personally)

1. Fresh clone at merged commit C; `producer.py --action request` (Docker
   Desktop 4.48.0 with the pinned buildx builder) writes the controller
   database and request. `main` must not move until the last EXIT case.
2. Owner: set `FORGE_SIGNING_AUTHORIZED=true`; dispatch `provenance.yml`
   (R1) with the request and the new lock value; dispatch
   `provenance-negative.yml` with `producer_run_id=R1` (R2); delete the
   variable.
3. `write_controller_config.py` (in `proposals/provenance-hosted-v33/`)
   writes `.toolchain/stage9/controller.json`.
4. The six cases through `bootstrap.py … -- scripts/exit_stage_9.py --case X`
   with the read-only verifier token in the environment only;
   `deployed-identity` last (it consumes the request).

Public and permanent: 7 Rekor entries per signing attempt (6 under
`provenance.yml@refs/heads/main`: 1 release and 5 security controls; 1 under
`provenance-negative.yml@refs/heads/main`). They show the repository, the
workflow, the commit and the statement digests to everyone, and they cannot
be deleted. The project has 20 such entries already (U159, U162, U169). A
failed or repeated attempt adds 7 more.

Needs the owner personally: approval of the contract text (M1 to M3); the
exact implementation approval (M4 to M9); the review that approves each exact
PR head (from the owner account, on a PR from another account); the merge;
the signing variable (owner-only on a personal-account repository, U170);
the two dispatches (or an explicit delegation); a read-only verifier token;
acceptance of the public Rekor entries; the ratification record's statement.

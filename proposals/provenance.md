# Stage 9 provenance trust proposal — awaiting exact approval

Base: `80a65d46b1dbc8f3ccfd249bfd628568406c5774` (completed Stage 8).
No protected target has been added or changed. Stage 9 is CURRENT. All six
Stage 9 EXIT commands are NOT RUN. No signature or deployment exists for Stage 9.
`end_to_end=false`.

## Decision requested

Approve only these three exact additions, as bound by this published revision,
the [manifest](provenance/approval-manifest.json), and the complete
[patch](provenance/protected.diff). Review the candidate files before approval.

| Protected target | Candidate | SHA-256 |
| --- | --- | --- |
| `spec/provenance/protocol.md` | [Contract](provenance/protocol.md) | `2784bdd04f0c89871e243df2402bd689546595835e28e7480fff5968e705ed69` |
| `policy/provenance.json` | [Policy](provenance/provenance-policy.json) | `9e27f627a2b1924fc2f4f86346efaa06755a2c47a366fb3437e54a105d65f22b` |
| `spec/provenance/spec.lock` | [Identity lock](provenance/spec.lock) | `43610d8123ce21fdd1f9dac9469f78ad3efcb3af271a86011a18790099811a33` |

Manifest SHA-256: `92c56b5d36c44242a826905f2c7194052b802b7079d0d0130d686dbf885551cf`.
Patch SHA-256: `ebbbeb7e19c3b3cec846a91133e01653a53bc5bd6b95f63645a8e1ec0c338dff`.

This approval would authorize a research trust contract, not real payments,
production deployment, a release, or future unspecified protected changes.
It does not authorize new gate code or a signing workflow. Those exact bytes,
their complete execution inputs and pins require separate approval. The proposed
policy refuses release while that implementation approval is absent.

## Reason and proposed trust decisions

Forge currently has accepted proof evidence but no approved signer identity,
signature trust roots, release policy, or deployed-identity acceptance boundary.
Existing `passed` records are unsigned. Signing such a record cannot itself
establish its truth. The user explicitly requires exact approval before protected
changes; ROADMAP's hard rules also require a proposal and a stop.

The proposed signer is one GitHub Actions workload:
`https://github.com/mack-dot/forge/.github/workflows/provenance.yml@refs/heads/main`,
with issuer `https://token.actions.githubusercontent.com`. Exact workflow commit,
event, ref, repository and approved executable bytes must match. A valid
certificate for the path alone is insufficient. Numeric repository and owner IDs
also bind the repository through authenticated GitHub API metadata.

Cosign 3.1.4 is proposed, with exact macOS ARM64 and Linux AMD64 executable
hashes. Trust starts in that pinned executable's embedded public Sigstore TUF
bootstrap. TUF-authenticated updates, expiry checks, Fulcio certificate checks,
CT and Rekor inclusion, and authenticated signing time remain required. This
explicitly trusts GitHub, Sigstore authorities, the tool distribution and the
controller/host. No local agent key is an authorized release identity.

The only release binary is the accepted 1,240-byte Stage 7 ELF,
`8ced2ab6c7160338899056fe51bacb23d86d81705eacfdd1e992cf5252bdaeb6`.
Both its universal normal-termination claim and valid-entry witness require
`kernel_checked_proof`. Fresh real proof and binding compilation, full independent
`rocqchk`, and assumption audits precede signing. The lock preserves 47 existing
files, 579 checked modules, 13 assumptions per theorem and all 86 permitted
closure assumptions. Existing logs remain historical evidence, not new checks.

The signed statement binds the ELF, package, exact evidence, specifications,
policy, tools, trusted implementation and request. A controller-owned, single-use
challenge rejects stale admission requests. Historical verification remains
distinct from authorization for another deployment. Signature metadata and
request records stay separate from deterministic canonical proof evidence.

The deployment experiment will start an isolated local container and read the
actual ELF through its filesystem namespace. It must detect substitution in that
deployed view. The claim is **deployed file identity at observation time**. It
does not claim execution of the RISC-V ELF, loader correctness, persistent
runtime integrity or whole-application deployment correctness. The container
may run an idle supervisor; this limitation is part of the exact contract.

Stage 8 evidence remains supplementary: R1–R5 are source proofs; T1–T3 are finite
property tests. Neither establishes properties of this C binary. Model quality
remains unmeasured. No evidence method changes.

## Preparation and remaining checks

The proposal-only integrity command is:

```bash
python3 proposals/provenance/check_proposal.py
```

It checks exact bytes, baseline identities, assumption lists and patch
applicability. It is not a proof checker, signature verifier, or Stage 9 EXIT.
Actual records are in [results/stage9/preparation](../results/stage9/preparation/).

Cosign is not currently installed on this host. It has not been installed or run
for this proposal. No failed tool installation, signature verification or Stage 9
EXIT is being hidden. Release metadata and CLI source inspection establish only
candidate pins and documented interfaces. Actual identity, TUF, signature and
container capabilities remain to be executed after the required approvals. If a
required capability fails, preserve the actual error and stop. Do not relax policy.

The exact CLI invocation and fixtures will be frozen with the gate proposal.
That proposal must also show how every negative reaches its intended security
check, including an authentic wrong signer, an authorized signature over a wrong
artifact/policy, stale admission, altered evidence, and real deployed substitution.

## Primary references inspected

- [Cosign 3.1.4 release](https://github.com/sigstore/cosign/releases/tag/v3.1.4):
  executable asset digests. These were read from GitHub metadata; no cryptographic
  verification of the downloaded tool has occurred in this preparation.
- [Pinned Cosign certificate options](https://github.com/sigstore/cosign/blob/0e48502cf5ef34e2e60bbd3617aa19945712f705/cmd/cosign/cli/options/certificate.go):
  exact identity, issuer and workflow claim options.
- [Pinned attestation verifier](https://github.com/sigstore/cosign/blob/0e48502cf5ef34e2e60bbd3617aa19945712f705/cmd/cosign/cli/verify/verify_blob_attestation.go)
  and [attestation producer](https://github.com/sigstore/cosign/blob/0e48502cf5ef34e2e60bbd3617aa19945712f705/cmd/cosign/cli/attest/attest_blob.go):
  established DSSE statement production and verification.
- [Pinned dependencies](https://github.com/sigstore/cosign/blob/0e48502cf5ef34e2e60bbd3617aa19945712f705/go.mod):
  in-toto/attestation 1.2.0 and sigstore-go 1.3.0.
- [Sigstore trust configuration](https://docs.sigstore.dev/cosign/system_config/custom_components/):
  embedded TUF bootstrap and authenticated trust material distribution.
- [in-toto Statement v1](https://github.com/in-toto/attestation/blob/df02077bf97218a8860a5c534eff1f1381f56984/spec/v1/statement.md):
  subject digest and predicate structure.

# Security policy

Forge is a research prototype. It has no production releases, and no Stage 9
signed release exists yet. Security reports still matter, because Forge's value
depends on its gates rejecting what they must reject.

## Report a vulnerability privately

Use GitHub private vulnerability reporting:
**Security** tab → **Report a vulnerability** on
[mack-dot/forge](https://github.com/mack-dot/forge/security).

Do not open a public issue or pull request for a vulnerability. Do not include
working exploit code in public discussions.

Include:

- the affected file, workflow or command, and the commit you tested;
- what the gate or workflow should have done, and what it did;
- the smallest reproduction you have, with real exit codes and output.

This is a volunteer research project. There is no bug bounty and no guaranteed
response time. We aim to acknowledge reports within 7 days.

## In scope

- **Gate bypass:** a change, artifact or evidence bundle that a gate accepts
  although its required claim was not established by the stated method. This
  includes promoting a test result to a proof, a stale or substituted
  evidence bundle, or an accepted `assume`, `{:axiom}`, `Admitted`, `sorry` or
  similar construct.
- **Approval bypass:** changing `spec/**`, `spec.lock`, `policy/**` or `gate/**`
  so that a change is accepted without the exact-byte human approval the
  process requires.
- **Provenance and signing:** any way for a pull request, fork or other
  unprivileged actor to obtain the GitHub OIDC token of the Stage 9 signer
  workflow, produce a signature that the release verifier accepts, change an
  approved lock, or trigger deployment.
- **Workflow privilege:** code from a pull request running with write
  permissions or secrets, including through `pull_request_target`, artifacts or
  caches.
- **Supply chain:** a pinned tool, image, action or dependency that can be
  replaced without a digest or hash check failing.

## Out of scope

- A specification that does not capture what a person wanted. Report it as a
  normal issue: Forge proves the stated specification, not the intent.
- Claims that the records already mark as unproved, untested or
  `end_to_end=false`.
- Findings that need write access to this repository or control of GitHub,
  Sigstore or the maintainer's machine. Those are stated trust assumptions; see
  [spec/provenance/protocol.md](spec/provenance/protocol.md).

## After a report

We confirm the finding, record it in the append-only [unsure.md](unsure.md)
without exploit detail, fix it through the normal exact-approval process for
protected files, and credit the reporter unless they ask us not to.

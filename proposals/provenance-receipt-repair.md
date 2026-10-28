# Stage 9 receipt integrity repair — exact approval required

Status: **proposed, not applied**. Stage 9 stays CURRENT and blocked.
`end_to_end=false`. The installed gate remains the exact 11-file implementation
approved at `06b40caa6bf5fb6963756b39646413559f84c61d`.
The public audit checkpoint is
[`9679265c326d8d630e54c728f307891e5d6422ab`](https://github.com/mack-dot/forge/commit/9679265c326d8d630e54c728f307891e5d6422ab).

## Problem and exact scope

The installed validator accepted invalid dependency hashes and a substituted
or missing copied ELF when the receipt's own manifest was updated. Its manifest
checked consistency within candidate data. It did not bind all required bytes
to independently fixed identities. The original failed audit remains in
`results/stage9/implementation-adoption/receipt-audit-0001/`.

This proposal changes four protected files only. It leaves the contract,
policy, six EXIT requirements, workflows, theorem, assumptions and actual
kernel-checking procedure unchanged.

| Target | Change and reason |
| --- | --- |
| `gate/provenance/release.py` | Require all 601 artifact copies and hash their actual bytes against fixed identities. Require exact dependency names, digests and raw kernel membership. Preserve existing checks. |
| `gate/provenance/producer.py` | Copy all 579 actual dependency objects into the receipt. Use a fixed build path on a fresh isolated volume, so exact object hashes are meaningful. Retain fresh compilation and full kernel checking. |
| `gate/provenance/receipt-identities.json` | Add independent identities for 22 existing program/proof artifacts plus 579 dependency copies, the exact closure and kernel command. |
| `gate/provenance/implementation.lock` | Bind those three files; retain all other executable input pins. |

The full [diff](provenance-receipt-repair/proposed.diff) and
[manifest](provenance-receipt-repair/approval-manifest.json) contain every
before/after hash and all proposed bytes. There are no placeholders.

| Approval input | SHA-256 |
| --- | --- |
| Manifest | `9e246009199f4a976df151309f63c67a09a51dcac3b3763c6383c9f8c5a19bd3` |
| Complete patch | `30435b460a34d76b1eb0e511dc71706cd33e8a36817f29d13ffaa60d6b4f16f8` |
| Proposed implementation lock | `298c8754dcae31b3a80c87d7524f2ab87c766d07b3aaa2e7f417af06cb6a0d87` |

Approval must name the published revision and exact inputs. File approval would
not authorize registration, dispatch, public signing or deployment.

## Independent identity binding

Expected values come from the verifier's protected checkout, bound by the
separately approved implementation lock. The receipt and its signature cannot
choose replacement reference values.

Each required artifact must exist and its actual bytes must match the protected
SHA-256. This covers the ELF, C source, proof sources, generated ELF image
inputs, compiled proof objects and all dependency copies. Removing a file from
the receipt's own manifest cannot remove the requirement. Missing artifacts
receive explicit integrity errors. Extra artifacts with the specified
proof/program suffixes also reject.

Dependency names must equal the approved closure. Every digest must have the
correct format **and** equal the fixed reference. Every copied dependency's
actual bytes must also match. Correct digest strings cannot hide substituted
or missing objects. Raw kernel-loaded paths, checked module names and the full
recorded kernel command must match the approved identities.

The 601 copies include the nine own-proof objects in both their original proof
directory and the complete dependency directory. Diagnostic logs, timing files
and receipt metadata are not additional proof inputs. Their consistency remains
checked by the file manifest and later signature. They cannot supply expected
artifact identities.

## Reference provenance and stable paths

The reference uses genuine Stage 7 artifacts and its successful complete
kernel log. The preserved container `forge-stage7-own-proof-0001` was inspected
while stopped. Its image reference matches the pinned checker, its root is
read-only, and its recorded exit is 0. Read-only `docker cp` calls retrieved
all 579 named objects: 568 image-library objects, two upstream build objects
and nine own-proof objects. The nine own-proof objects match the published
Stage 7 archive. Total object bytes: 59,310,679. No container or kernel started.

These hashes are proposed identities for independent approval, not a new proof
result. Collection occurred after the historical check. It cannot create
contemporaneous records that Stage 7 did not retain. The two writable-volume
dependency hashes are not retroactively claimed to have been captured at the
old checking instant. The pinned image, preserved storage and future fresh
checking remain explicit trust boundaries.

All nine own-proof objects contain their physical build path. Changing that
path changes their exact bytes. The proposed producer uses
`/work/.forge-stage7/own-proof/attempt-0001` on a **fresh dedicated volume**.
The request nonce still names the container and binds the receipt. The existing
Stage 7 job refuses an existing attempt directory. Never delete a historical
attempt, reuse a proof result or normalize object bytes to force a match.
Provision a separate seed without that output directory; preserve the original
volume. See the [runner isolation plan](stage9-runner-provisioning.md).

This explains the small producer change. It adds artifact transport and a
stable build location. It changes no proof rules or machine semantics. Fresh
compilation may expose further byte-reproduction constraints. Such a mismatch
must block; it cannot automatically update the reference.

## Actual controls

The candidate was imported from the proposal directory. Installed protected
files remained unchanged. The positive case used the complete genuine Stage 7
corpus and actual dependency objects. Its test receipt is explicitly labelled
a **historical byte-validation control**, not fresh Stage 9 evidence.

| Control | Actual candidate result |
| --- | --- |
| Complete historical proof corpus | Accepted by the identity validator. |
| Invalid dependency hash syntax | `DEPENDENCY_DIGEST_FORMAT` |
| Incorrect well-formed digest | `DEPENDENCY_DIGEST_MISMATCH` |
| Substituted dependency bytes, updated manifest | `PROOF_ARTIFACT_BYTES:dependencies/0000.vo` |
| Missing dependency bytes, updated manifest | `PROOF_REQUIRED_ARTIFACT_MISSING:dependencies/0000.vo` |
| Incorrect dependency membership | `DEPENDENCY_CLOSURE_MEMBERSHIP` |
| Substituted ELF, updated manifest | `PROOF_ARTIFACT_BYTES:linux/gcd-selftest.elf` |
| Missing ELF, updated manifest | `PROOF_REQUIRED_ARTIFACT_MISSING:linux/gcd-selftest.elf` |
| Nonce substitution | `STALE_PROOF_RECEIPT` |
| Mutation after manifest creation | `PROOF_RECEIPT_BYTES` |

| Command actually run | Exit code |
| --- | --- |
| `python3 scripts/collect_stage9_receipt_reference.py --output results/stage9/receipt-repair-preparation/reference-0001 --work build/stage9-receipt-reference-0001` | 1 |
| `python3 scripts/collect_stage9_receipt_reference.py --output results/stage9/receipt-repair-preparation/reference-0002 --work build/stage9-receipt-reference-0002` | 0 |
| `python3 proposals/check_provenance_receipt_repair.py --reference-work build/stage9-receipt-reference-0002 --output results/stage9/receipt-repair-preparation/candidate-check-0001 --work build/stage9-receipt-candidate-0001` | 0 |
| `git apply --check /Users/mackianni/forge/proposals/provenance-receipt-repair/proposed.diff` | 0 |

The first collector failed because Docker returned the same mount set in a
different order. Both raw inspections, all 579 successful copy commands and
the original collector source remain preserved. Sorting mounts by destination
while comparing every field fixed this diagnostic script. The second
collection passed. Neither result is a proof check or security rejection.
Both candidate Python files and the embedded collector code passed syntax
compilation. The proposed producer's Docker path has not executed.

The [preparation records](../results/stage9/receipt-repair-published/README.md)
retain failures, commands, raw logs, reference digests, control manifests and
mutated bytes. Reproduction needs Python 3.10.11, the original Stage 7 archive
and a read-only collection from the preserved Stage 7 environment. Use new
output directories. The original library objects come from the pinned image
and Stage 7 build; all collection digests are published.

## Remaining requirements

A **fresh legitimate Stage 9 receipt must still pass** after exact repair
approval and separate execution authorization. It must include new compilation,
binding checks, full `rocqchk`, the assumption audit and all six EXITs. The
historical positive case does not satisfy that requirement. Kernel and signature
checks were NOT RUN for this proposal; no exit codes are invented for them.

Matching metadata does not authenticate execution time. Signer isolation,
GitHub's authenticated job/artifact handoff and approved trust roots remain
required. A compromised authorized producer can sign lies. This repair closes
the demonstrated byte-integrity gaps; it does not remove the producer trust
boundary or establish deployment correctness.

The [history audit](../docs/stage9-history-audit.md) records observed accounts,
workflow revisions and public push events. Stop for exact protected-file
approval. No workflow or policy change is included here.

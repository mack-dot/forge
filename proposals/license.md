# License decision: Apache-2.0

Decision (2026-10-28): the owner chose Apache-2.0 ("lets do apache 2.0", then
"i just want to do what the best is for the projet"). LICENSE, NOTICE and
THIRD_PARTY_NOTICES.md are added in the contributor-readiness pull request.
Copyright holder (2026-10-28): the owner said "just treat it as my project tis is
different than my engineering loop i made at spm". NOTICE names mack-dot and
Forge contributors. The owner was advised to check their employment agreement,
because some work was done on company time.

Original status: recommendation only. No LICENSE file is added. Public visibility does
not grant anyone the right to use, change or share the code. The owner must
choose. See U097.

## Recommendation: Apache License 2.0

| Reason | Detail |
| --- | --- |
| Patent grant | Contributors grant a patent license for their contributions. This matters for a verification tool that companies may adopt. |
| Contribution terms | Section 5 makes contributions licensed under the same terms by default ("inbound = outbound"), so no separate CLA is needed for a research project. |
| Compatibility | All observed dependencies and upstream sources are MIT or Apache-2.0 (below). |
| Common practice | Sigstore/Cosign and BuildKit, which Forge uses, are Apache-2.0. |

**Alternative: MIT.** It is shorter and matches the upstream proof repositories,
but it has no explicit patent grant and no contribution clause.

## Decide first: who holds the copyright

The owner said they now work for the company behind the `superpowermentors-1`
organization, and briefly moved the repository there. An employment agreement
can assign copyright in work done for the employer. Confirm
who the copyright holder is (the individual or the company) before choosing a
license, and name that holder in the LICENSE file. This is a legal question that
this recommendation does not answer.

## Third-party material that needs a notice under any choice

| Source | License (GitHub) | Where in this repository |
| --- | --- | --- |
| theorem-labs/oss-verify-proofs | MIT | Logs and 23 `.v`/`.vo`/`.py`/`.c` entries inside `results/stage7/published/*/records.tar.xz`; logs under `results/stage7/` |
| theorem-labs/rocq-linux-process-semantics | MIT | Imported by `examples/binary/*.v`; compiled objects in the archives above |
| dafny-lang/dafny | MIT text ("Copyright (c) Microsoft Corporation"); GitHub reports NOASSERTION | Not tracked; downloaded into ignored `.toolchain/` |
| sigstore/cosign, moby/buildkit | Apache-2.0 | Not tracked; downloaded at run time |
| npm: bignumber.js, fast-check, tsx, @types/node / typescript | MIT / Apache-2.0 | Not tracked (`node_modules/` is ignored) |

Add a `THIRD_PARTY_NOTICES.md` that reproduces the MIT notices of the two
theorem-labs repositories for the archived material. Verify each upstream
LICENSE file text at the pinned commits before publishing it; this table uses
GitHub's license detection and one file read, not a legal review.

## To adopt (after the owner's choice)

1. Add `LICENSE` with the exact license text and the confirmed copyright holder.
2. Add `THIRD_PARTY_NOTICES.md`.
3. Update the README "License" section.

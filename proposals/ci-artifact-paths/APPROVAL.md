# Exact artifact packaging repair — ready for separate review

Base: main `f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3`.
Only file: `.github/workflows/proof-gate.yml`.

| Review item | SHA-256 |
| --- | --- |
| Current workflow preimage | `e3904debcd4cd06b04bf82cab2e8b21ab1a0ed4f480798d3e3457054e142d87a` |
| [fix.patch](fix.patch) | `7bf529ab595c1244451dd0c80aaa845bdd4210ccf7c6da31442e5a72a98619b1` |
| [Proposed workflow](proof-gate.yml.proposed) | `295b760ac2986d921c0459673c86d800784e81d248406b91454d5c85a5fc4e83` |

`git apply --check /Users/mackianni/forge/proposals/ci-artifact-paths/fix.patch`
ran against that main checkout and exited 0 in the campaign audit.
Actual fixed upload: NOT RUN. This patch is not applied, published or merged.

Requested next authorization: publish this exact one-file change as a contributor
PR for independent owner review. Publication does not authorize approval or merge.
If base or bytes change, recheck and review the exact new head. Use the existing
normal merge procedure only after exact-head review and explicit merge authority.

Problem: genuine PR 34 verification and fresh replay passed, but artifact upload
rejected a colon in copied historical results. This patch excludes only that
historical subtree from the upload. It keeps fresh receipts, proof output and logs.
It changes no verification inputs, coverage, permissions, pins, signing or trust
policy. See [REVIEW.md](REVIEW.md) for the observed failure and filename audit.

Suggested PR title: `Fix proof report upload for historical result filenames`.

Suggested PR body:

> A supported booking change verifies successfully, but uploading its report fails
> because copied historical result filenames contain colons. Exclude only the
> copied historical results subtree from the artifact upload. Keep fresh proof
> output, receipts and logs. Verification input binding and policy stay intact.
>
> Validation: exact patch preimage check passed; the observed invalid filenames
> lie under the excluded subtree. A successful hosted upload is not yet established.

PR 34 is a demonstration candidate and must not be merged under this packet.
The already-authorized manual booking dispatch needs a working API route, not
another approval. No Node, signing, deployment, protection or Stage 12 change.

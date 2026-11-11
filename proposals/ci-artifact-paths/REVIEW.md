# Preserve passing verification reports without invalid historical filenames

Observed failure: real booking PR #34 passes its trusted Linux gate (0),
re-establishes booking, and reproduces identical evidence (replay 0). Artifact
upload then fails on a colon in a copied historical file:
`check/verify/results/stage9/v33-controls-0001/bootstrap:_root_bytecode_cache.log`.
The reporting job cannot find the failed upload. Overall CI remains FAILURE.

Prepared fix.patch changes only the proof-gate workflow's upload path. It
excludes the copied candidate's historical `results/**` subtree. All observed
51 colon-bearing tracked paths lie under that subtree. Fresh verifier output
under `check/verify/build`, the main receipt/evidence, command logs and replay
logs remain in the upload. Historical source is still bound by the immutable
candidate commit/tree and is still included in the gate's verification input
inventory. The patch changes packaging, not acceptance, coverage, provenance
policy, verification execution, permissions, actions or signing.

Patch preimage check: 0. Filename inventory check: 0. Real upload with this
change: NOT RUN. This separate protected workflow change is not applied,
published or merged and needs review/authorization before installation.

The approved manual booking experiment already selects fresh proof/observation
directories rather than complete copied source trees, so this failure does not
by itself establish that the manual experiment's artifact upload will fail.
Do not modify its policy or weaken any negative case to work around this issue.

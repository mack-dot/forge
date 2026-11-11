A disk receipt with a matching key and `result=established` could be adopted after its evidence and artifact digests were changed. This change permits reuse only when the same trusted verifier process retains the complete receipt and proof-artifact integrity anchor from actual verification. Missing authority, modified receipts, and substituted artifacts cause refusal. New CLI processes run fresh dependent proofs. Cross-run reuse stays disabled.

Production scope: `gate/obligations.py`, `gate/incremental.py`, and their two implementation-lock entries. Two permanent tests preserve the original counterexample and exercise the repaired full gate, including missing/invalid anchors and observed subprocess launches. No signing-policy, specification, workflow, Node, branch-protection, or deployment change.

Dependency: PR #30 at `561d2dda904daf18f17a0fede93f28b502d72884`. The exact production diff applies to that head and fails against current main. Review and merge #30 first, then this separate repair; do not run hosted reuse between them. The original #30 head is unchanged by this local preparation.

Validation and exact results are recorded in `results/ops-readiness/finalize-2026-11-02/STATUS.md`. Local execution is distinct from GitHub-hosted evidence. Hosted execution is NOT RUN. `end_to_end=false`. Human approval, publication, and merge authorization remain required.

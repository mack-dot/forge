# v3.3 proposal (protected changes; nothing applied)

Each diff is against main d43f5f4d (lock be23ec85). The diffs parse; none has
run in a workflow. After approval, a new lock and a full control run are needed.

| Diff | Fixes | Evidence |
| --- | --- | --- |
| v1-v2-v4-guard.diff | V1: `-I -m ensurepip` in all three OIDC-capable jobs. V2: `-I` for the child `pip` in hosted_setup.py. V4: release.py stops claiming a fresh kernel receipt (`producer_receipt_labels_consistent`, `proof_freshness_bound_to_challenge: false`). Guard: any Actions marker refuses the verifier. | results/stage9/v32-audit-0001 c02–c05, c11, c17, c18 |
| exit-harness.diff | D1: unsigned marker for Cosign 3.1.4. D3: EXITs launch the verifier through the bootstrap. | results/stage9/cosign-offline-0001; EXIT readiness report |
| credential-isolation.diff | git never receives the token variable; no credential for a public fetch. | U116, U119 |

Not yet written (need design and tests): V3, the inventory scope (reject
Python-importable entries at the repository root in bootstrap and
source_tree); V4 binding (feed the challenge into the proof workload); D4
(consume the request after the container exists); D10 (stale
check_stage9_installation.py and audit_stage9_receipts.py); request expiry.

Superseded on 2026-10-29 by proposals/provenance-hosted-v33/ (proposed.diff,
approval-manifest.json); the diffs here are early drafts kept as records.

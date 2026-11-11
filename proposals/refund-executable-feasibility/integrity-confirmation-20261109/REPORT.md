# U336: completed preflight confirmed without a second hosted job

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
TRANSFER_INTEGRITY_ESTABLISHED for the frozen published inputs.

The requested preflight was already complete at U335 when this run started.
Fresh GitHub reads confirm [run42624212334](https://github.com/mack-dot/forge/actions/runs/42624212334),
attempt1, one successful job129183679727. No new job or retry was started.
The full fresh decoded log matches U335 byte for byte. The separate evidence
reader ran again against fresh run, job, log and resource records. It exited0.

| Executed command/check | Actual exit/result |
| --- | --- |
| `python3 -I -B proposals/refund-executable-feasibility/integrity-confirmation-20261109/records/confirm.py` | 0 |
| Its `python3 -I -B proposals/refund-executable-feasibility/integrity-confirmation-20261109/records/readback.py` child | 0 |
| `python3 -I -B proposals/refund-executable-feasibility/integrity-confirmation-20261109/records/update_tracking.py` | 0 |
| Existing hosted integrity process, confirmed from full log | 0 |
| Existing hosted mutation controls | Three expected ValueError rejections; no child exit codes |
| Fresh GitHub run/list/job/workflow/log/timing reads | Six tool successes; no OS exit codes |
| New hosted job / HOL proof | NOT RUN |

The exact executed workflow is U335's13735-byte artifact, SHA256
`b8c96c19049e04aedc5b2902b9342ec26db4234690d2c5cce589bbd1730016e9`.
It has one Ubuntu job, timeout5 minutes, permissions{}, no secrets, privileged
operations or proof execution. It retains U334's refusal before following
redirects and adds the requested mutations and exit/resource records. The
original U333 workflow remains NO-GO because it checked redirects after following
them. This confirmation does not describe U333's11609-byte file as executed.

Workflow commit: `fca212c45ccce9f27ffdf2d51ccf9ee96bce7162`.
Source commits: `21c4bdf958627e6a24e8dee9a45d90568b3e3c20` and
`ac05eaf972b8c98784466ae063fca505aaaf25f4`.
Complete decoded log SHA256:
`b22630463ade3fc54f9481975f528de87ef283a94a05dd4dc496c062958b4187`.
The reader checks all1475+18 member records against the frozen manifests,
ten package files, two commit identities, download counts, original quotation,
all three mutation reasons, complete result and shell exit0. The hosted checker
also checks tree/blob, archive and member size/mode bindings before success.
The complete fresh reader result is byte-identical to U335's result.

Observed hosted use remains26196042 payload bytes plus36303 metadata bytes;
9.004512771s checker wall,1.68537s user CPU,0.050339s system CPU,48684KiB peak RSS.
Provider duration16000ms; one job;0 billable Ubuntu ms reported. These are the
existing run's measurements, not a new execution or performance estimate.

All181 manifest-listed files in U333/U334/U335 match their preserved hashes.
All50 protected paths and the mission match the existing baseline. No old
packet, failure, proof input or protected file was modified. Local Git metadata
was not repaired; no local commit is claimed. Only the root tracker/journal is
updated by U336; no synchronization of another review workspace is claimed.

[Assurance matrix](ASSURANCE.md) retains the provider, OS, Python/hash/TLS and
connector trust limits. This is tested byte integrity, not software correctness.
The existing [TextIO.read proof proposal](../hosted-integrity-run-20261109/PROOF-RUN-APPROVAL.md)
and its frozen workflow remain unchanged and unrun. The workflow SHA256 remains
`1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1`.
Separate proof authorization remains the next boundary. Native memory/frame,
whole-program correspondence and independent21-snapshot replay remain open.

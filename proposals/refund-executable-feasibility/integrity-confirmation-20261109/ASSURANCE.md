# U336 assurance matrix

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Claim | Status | Evidence and limit |
| --- | --- | --- |
| Frozen transferred bytes | TESTED | U335 hosted exit0; fresh full-log equality and evidence reader0. TRANSFER_INTEGRITY_ESTABLISHED. |
| All1475+18 inputs, ten package files and source identities | TESTED | Fresh reader matches every member digest to frozen manifests; U335 checker enforces size/mode, commit/tree/blob and archive bindings. |
| Integrity mutations | TESTED | Three exact ValueError rejections in existing hosted run; no separate OS exits. |
| Exact one-job integrity scope | TESTED | Fresh workflow byte equality; one job,5-minute cap,permissions{}, no secrets/privilege/proof; attempt1 and one run at this head. |
| Exit and resource evidence | TESTED | Full fresh log, run/job status and timing agree with U335. No second hosted execution. |
| Prior evidence and protected files | TESTED | All181 U333–U335 packet members,50 protected paths and mission hashes match. |
| Provider,OS,Python/hash/TLS and connector | ASSUMED | Same provider and agent; no independent administrative assurance or formal verification of checker. |
| TextIO.read theorem and closure | NOT_ESTABLISHED | Existing exact proposal remains prepared; HOL is unrun and requires separate authorization. |
| Native memory/frame, whole-program correspondence, independent21-snapshot replay | NOT_ESTABLISHED | No new evidence for these claims. |
| Full M1 software correctness | NOT_ESTABLISHED | M1 stays open; end_to_end=false. |

U335's [matrix](../hosted-integrity-run-20261109/ASSURANCE.md) and all previous
failures remain unchanged. This update confirms the completed preflight only.

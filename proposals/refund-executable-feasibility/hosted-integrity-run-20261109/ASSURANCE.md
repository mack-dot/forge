# U335 assurance matrix

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Claim | Status | Evidence and trust limit |
| --- | --- | --- |
| Exact published source/package bytes | TESTED |TRANSFER_INTEGRITY_ESTABLISHED; run42624212334; checker exit0;26196042 payload bytes. |
| All1475+18 pinned files and original quotation | TESTED |1493 member records match frozen manifests; unchanged quotation289b8be8c848dc3debddbac5184e613e2c1e127c56dddd574e5b43087cc8c29a. |
| Both source commit/tree/blob bindings | TESTED |21c4bdf/ac05eaf; raw commit hashes,six trees,ten blobs and archive/member hashes checked. Unsigned identity,not a signing claim. |
| Three integrity mutation controls | TESTED |Expected ValueError reasons for changed commit,manifest and part; no separate child exit invented. |
| Exact checker workflow and observed exit | TESTED |Commitfca212c; SHA256b8c96c19049e04aedc5b2902b9342ec26db4234690d2c5cce589bbd1730016e9; full log and shell exit0. |
| Separate evidence readback | TESTED |readback.py exits0; no producer checker import; same agent,not independent administrative control. |
| Resource limits and observed use | TESTED |9.0045s checker wall,48684KiB peak RSS;16s provider duration; one job,0 billable Ubuntu ms reported. |
| GitHub runner/control plane,OS,Python/hash/TLS,connector | ASSUMED |Provider execution and decoded-log authenticity remain trust. This is not a kernel proof of the hashing program or host isolation. |
| Frozen TextIO.read theorem and dependency closure | NOT_ESTABLISHED |No HOL run. Candidate7e36c486 and full premises preserved. Separate bounded proposal prepared only. |
| Native memory/frame and whole-program correspondence | NOT_ESTABLISHED |No new native or semantic proof evidence. Full runtime/resource/initialization premises remain. |
| Independent21-snapshot replay | NOT_ESTABLISHED |Separate and unrun. |
| ARM64 ISA implementation,documented OS behavior,HOL/kernel | ASSUMED |Existing owner-approved software boundary; no silicon work or new axiom. |
| Full specification-to-native software correctness | NOT_ESTABLISHED |M1 remains open; end_to_end=false. Prior conditional source/compiler proofs retain their recorded scope. |

GO:transfer-integrity milestone. NO-GO:hosted HOL execution without separate
authorization. U333/U334 packets,failures and separate journal prefixes remain.

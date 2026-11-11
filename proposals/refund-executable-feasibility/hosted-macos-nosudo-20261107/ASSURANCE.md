# Assurance delta at U326

| Claim | Classification | Evidence and limit |
| --- | --- | --- |
| Prior exception/compiler composition | PROVED,previous modeled claim | U310; original runtime/resource/event premises retained |
| Prior published read/error buffer lemmas | PROVED,previous model claim | U315; no physical correspondence added |
| Permitted hosted temporary-file/process/memory environment | TESTED | OPERATIONS.json; actual syscall returns and command exits |
| Unchanged SAT diagnostic executes and reports a HOL theorem | TESTED execution; checked diagnostic result | HOL actual exit0; sat.stdout contains `⊢ probe ∨ ¬probe`; no general refund claim |
| Runtime,states,diagnostic inputs unchanged | TESTED identities |18 files before/after;36 hashes; RESULT-REVIEW.json |
| Native MiniSat executable was run | NOT_ESTABLISHED | Frozen original executable path unavailable; built-in proof fallback applies |
| No privileged setup or protected change | TESTED scope/preservation | Published workflow has no sudo;51 protected/mission bindings match |
| Zero metered macOS compute in this run | TESTED/reported | Timing API total_ms0; run duration47000ms; no account invoice claim |
| Host and provider isolation/integrity | ASSUMED | Fresh VM claim; no proof of administrator/control-plane exclusion |
| Logic/kernel and pinned-state bootstrap integrity | ASSUMED | Same existing trusted tools; independent production replay absent |
| Exact STRB/error-return instruction/frame theorem | NOT_ESTABLISHED | NEXT-STEP.md only; no instruction theorem produced |
| Complete physical ffiread and native I/O behavior | NOT_ESTABLISHED | OS/buffer/filesystem/return/FFI-frame relation remains open |
|21-snapshot independent full-chain replay | NOT_ESTABLISHED | NOT RUN |

Logical Success,modeled events,native process status and physical OS behavior
remain distinct. Scoped diagnostic execution succeeded; M1 remains open.
Stage12 unauthorized. end_to_end=false.

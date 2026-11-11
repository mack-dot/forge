# U340 assurance matrix

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Claim | Status | Evidence and limit |
| --- | --- | --- |
| Single frozen retry scope | TESTED | One rerun call; same SHAf1e4a080; attempt2,one job129430257438; no further attempt. |
| Runner/image/environment availability | OBSERVED for this retry | Required Darwin arm64,image20261104.0514.1; setup and probes passed. No future availability guarantee. |
| Pinned transfers and input preservation | TESTED | Ten download records match manifests;26196042 bytes;1493 before/after input checks; private-library gate passes. |
| HOL execution | OBSERVED FAILURE | First child exit1,not timed out; workflow step exit1; stopped immediately. |
| Parent theory loading | FAILED | ENOENT at duplicated .hol/objs/.hol/objs path; packaged single-path file present. Bootstrap integration defect. |
| Generic TextIO.read theorem | NOT_REACHED / UNESTABLISHED | Candidate source not invoked; no theorem result,export or new dependency closure. Not disproved. |
| Repeat/import/two negative HOL controls | NOT RUN | No child exits; success prerequisite absent. |
| Historical three integrity controls | TESTED, retained | In-process ValueError rejections; no separate OS exits. Enclosing checker exit0 only. |
| Evidence decoding and independent binding | TESTED | Stream reader0; initial reader1 preserved; corrected reader0 checks complete records. This is not proof success. |
| Resource observations | PARTIAL |31s workflow step;approx17.468184s invocation/result log interval; provider343000ms; reported billing0. Actual CPU/peak RSS unavailable. |
| Earlier static review | LIMITED | Identity/syntax checks passed but missed a loader integration defect known in U282/U291. U340 supersedes readiness confidence. |
| Provider/OS/runtime/connector/cached ancestry | ASSUMED | No independent administrative assurance or whole-chain replay. |
| Native correspondence,composition,independent replay | NOT_ESTABLISHED | Separate and unrun. |
| M1 full software correctness | NOT_ESTABLISHED | M1 stays open; end_to_end=false. |

Next issue is the bootstrap's theory-file path convention. No proof weakening,
dependency change,orchestration repair or further execution occurred.

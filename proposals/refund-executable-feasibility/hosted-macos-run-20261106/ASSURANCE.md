# M1 assurance delta at U324

| Claim | Classification | Exact evidence and limit |
| --- | --- | --- |
| Prior CakeML exception/compiler composition | PROVED (previous modeled claim) | U310,dde26bed; no new HOL proof in this run; premises retained |
| Prior published read/error buffer lemmas | PROVED (previous modeled claim) | U315; no extension to physical I/O |
| Hosted /var/tmp access,mkstemp,read/write,process and memory probes | TESTED | OPERATIONS.json; syscall returns and process exits above; finite observations |
| Hosted negative file-permission control | TESTED | EACCES13 for own mode000 fixture |
| Hosted original installation-path creation | TESTED: rejected | mkdir /Users/mackianni EACCES13; step78 |
| Published inputs and workflow match prepared bytes | TESTED | Remote blob/size readback,workflow byte equality,INPUTS.json and RESULT-REVIEW.json |
| Exact pinned HOL/SAT execution on hosted VM | NOT_ESTABLISHED | No sat_invocation or input download reached |
| SAT input unchanged | TESTED | bc3fb212a4037ae8e8ebd500f9843bff9cd93cbfcbc76501c7a152a9004af108 |
| Zero metered compute for this run | TESTED/reported | GitHub timing API MACOS.total_ms=0; run_duration_ms=12000; public standard class pricing |
| VM isolation and host/control-plane integrity | ASSUMED | GitHub fresh-VM guarantee; no peer/admin noninterference theorem |
| Independent toolchain bootstrap/source-to-binary provenance | NOT_ESTABLISHED | Local pins and byte identity do not independently prove production correctness |
| Complete physical ffiread/native I/O correspondence | NOT_ESTABLISHED | Original OS result,full buffer,filesystem,return state and FFI-frame obligation remains |
| Independent21-snapshot proof-chain replay | NOT_ESTABLISHED | NOT RUN |
| Additional directory setup and conditional SAT run | NOT_ESTABLISHED | Prepared only; approval pending; no automatic retry |

M1 open. Stage12 unauthorized. end_to_end=false.

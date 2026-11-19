# Fields that Orchestrator A must fill or confirm (ledger `ASSURANCE_LEDGER.json`, task f-binding)

Rule of the ledger: an edge is MACHINE-CHECKED only with a log inside the repository tree whose last line is `exit 0`
(or `go exit 0` from `go-routeA.sh`). A JSON `actual_exit` alone, or a log without an exit line, stays UNKNOWN-TONIGHT.
Please give, per field: the log path (repository-relative), its last line, and the theorem names.

| Edge id | Field | Now | What A should send |
|---|---|---|---|
| S5 | `runs[0].log`, `exit`, theorems | UNKNOWN-TONIGHT (U294 `hol-0004`, `bridge-0001` command.json, 2026-11-04) | was U294 replayed tonight? log with exit line; `source_decode`, `source_postconditions`, `source_full_result`, `source_compiled_fields` |
| S6 | `class`, `runs`, `closure` | MISSING (`orch-A/link/run/attempt-0001`: no go log with exit line) | exit codes and logs of link cases H0, H1, H2, controls, H4, NR1, R1–R3, I1; or "NOT RUN" |
| X1 | `runs[0].log`, `exit` | UNKNOWN-TONIGHT (M1R-1 T05) | 2026-11-18 replay verdict for T05 (results.json key) and a log with an exit line |
| X2 | same | UNKNOWN-TONIGHT (C32, C34) | same for C32-source-0006 and C34-real-0004 |
| X3 | same | UNKNOWN-TONIGHT (e4-0001) | same for e4-0001 |
| X4 | same | UNKNOWN-TONIGHT (fs-r4-0001) | same for fs-r4-0001 |
| X14 | same | UNKNOWN-TONIGHT (T06) | same for T06 |
| V1 | same | UNKNOWN-TONIGHT (C42) | same for C42-image-0001 |
| X7-L1 | `checker.version`; theorem list | MACHINE-CHECKED (go exit 0; reported by A) | HOL4 commit and Poly/ML version from `L1-0001/command.json`; confirm the 16 theorem names; confirm "model only" |
| X7-L1imp | `checker.version` | MACHINE-CHECKED (go exit 0) | confirm IMPORTED_COUNT 9, MISMATCH_COUNT 0 is the intended check |
| X7-L2 | `class` | MISSING (L2-0001 go exit 1: `UNEXPECTED_CONTROL_ACCEPTANCE L2-literal`) | confirm the cause; L2-0002 run status |
| X9-LO | `class` | MISSING (LO-0001 go exit 1) | confirm: proof failure or infrastructure stop |
| X13-PF | `class` | MISSING (PF-0001 go exit 1) | confirm: proof failure or infrastructure stop |
| X10 | `class` | MISSING | L-EXIT v3 run status and log |
| X11e | `class` | MISSING | erasure E1 run status and log |
| V4 | `class` | MISSING | does `hash_parents` (`CLOSURE_NODES 543`, `EXACT_COMPLETE`) bind parent DEFINITIONS (.dat), or statements only? (A7 gap E2) |
| BETA-DAFNY-HOL | `text`, `realizable` | unknown | A's exact wording of beta for byte strings (chars < 256), matched to A6b |
| A-LOADER | `text` | from A's message 08:37Z | path of the CE-3 record (DYLD_INSERT_LIBRARIES) |
| STRICT-FRAME | `text` | from A's message 08:37Z | path of the CE-1 record (exit 0 with truncated stdout) |
| EXPORTER-ID | `realizable` | unknown | confirm the exporter build folder is missing; any rebuild plan |
| CAKEML-CC-SCOPE | `text` | as in TOP_LEVEL_GRAPH X2 | confirm the compiler premises discharged inside the scripts |

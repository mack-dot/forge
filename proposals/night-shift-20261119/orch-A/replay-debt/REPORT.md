# A1 replay debt (worker report, spot-checked by Orchestrator A at 2026-11-19T08:00Z)

## Missing sources: UNAVAILABLE (3 of 3)
| Case | Source | Recorded SHA-256 (prefix…suffix) | Result |
|---|---|---|---|
| 094 | base-0003.sml | 78c55073…285f | UNAVAILABLE |
| 097 | quick-0001.sml | 5809a989…7235 | UNAVAILABLE |
| 098 | replay-0026.sml | 4d815de1…099e | UNAVAILABLE |
Searched: all 13542 git blobs of the object store (`git-blob-sha256.txt`), 22854 files on disk
(`fs-sml-sha256.txt`: results/, proposals/, .toolchain/experiments/, all forge scratchpads), names by
`find` and `mdfind`. 0 hits. Orchestrator check: `grep -c` of the three prefixes in both lists gives 0 and 0.
No record names a generator. No substitute source was made.

## Case 005 and case 130: Poly/ML store exhaustion during parent load
- stderr line 1 of both: `Run out of store - interrupting threads` (Poly/ML 5.9.2,
  `libpolyml/processes.cpp:1025`): an allocation failed after a full GC. Then `Interrupt` in theory load.
- No `--maxheap`; default limit = 80 % of RAM (about 12.8 GiB). Max RSS 1952 MiB (005), 1449 MiB (130).
- Sibling cases with the same heap and parents passed directly before and after at higher RSS.
- Class: INFRASTRUCTURE stop, result INCONCLUSIVE. NOT a semantic result. NOT shown to be a kernel OOM.
  UNKNOWN: heap-limit or failed OS allocation; heap size at the failure.
- 005: recorded exit 1 ("unsolved goals"), actual exit 1 (Interrupt): equal codes by coincidence.
- 130 (`m1-memory-domain-20261115-dom-repeat`): recorded exit 0, actual 1: driver verdict EXIT_DIFFERS.
  The driver queues a second run only for 005. Case 130 needs a second run too (`driver3.py rerun`).

# Slice 3 — optimizer swap record (made from the evidence record by `scripts/exit_slice3.py`)

Finite recorded runs. `end_to_end=false`. Not gate evidence. A count is not a proof.

Compiled core module SHA-256 `f3d79bf627cbdf5e13e364cbea8cc694167d7ddc0ad9e0e3485cd819866a34fa`. Checker id `4f9e1ff3257a12b3aa7a0845efed41b3c415c6ecc51837b8a6646314b9327414`. The same for every optimizer, and equal to a new computation from the files.
Commands of the EXIT script between the first and the last optimizer: 18, all optimizer runs; Dafny or Z3 among them: 0. Largest gap of the sink: 2000 basis points.

| Optimizer | Language | Batches | Lines | Tokens | Committed | At gap 0 | Tokens above the largest gap | No token | Effects without a commit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| v1 | TypeScript (the baseline of Rounds 2 and 3, solver 11) | 70 | 70 | 70 | 49 | 17 | 21 | 0 | 0 |
| v2 | safe Rust (built by the rustc of this machine) | 70 | 70 | 70 | 35 | 26 | 35 | 0 | 0 |
| v3-overbook | Python (the adversary) | 70 | 70 | 0 | 0 | 0 | 0 | 70 | 0 |
| v3-double-book | Python (the adversary) | 70 | 70 | 0 | 0 | 0 | 0 | 70 | 0 |
| v3-forged-certificate | Python (the adversary) | 70 | 70 | 0 | 0 | 0 | 0 | 70 | 0 |
| v3-negative-prices | Python (the adversary) | 70 | 70 | 0 | 0 | 0 | 0 | 70 | 0 |
| v3-nothing-claims-optimal | Python (the adversary) | 70 | 70 | 0 | 0 | 0 | 0 | 70 | 0 |
| v3-gap-below-zero | Python (the adversary) | 70 | 70 | 0 | 0 | 0 | 0 | 70 | 0 |
| v3-gap-above-all | Python (the adversary) | 70 | 70 | 0 | 0 | 0 | 0 | 70 | 0 |
| v3-wrong-shape | Python (the adversary) | 70 | 70 | 0 | 0 | 0 | 0 | 70 | 0 |
| v3-huge-number | Python (the adversary) | 70 | 70 | 0 | 0 | 0 | 0 | 70 | 0 |
| v3-json-number | Python (the adversary) | 70 | 70 | 0 | 0 | 0 | 0 | 70 | 0 |
| v3-extra-key | Python (the adversary) | 70 | 70 | 0 | 0 | 0 | 0 | 70 | 0 |
| v3-not-json | Python (the adversary) | 70 | 70 | 0 | 0 | 0 | 0 | 70 | 0 |
| v3-oversize | Python (the adversary) | 2 | 0 | 0 | 0 | 0 | 0 | 2 | 0 |
| v3-no-line | Python (the adversary) | 2 | 0 | 0 | 0 | 0 | 0 | 2 | 0 |
| v3-silent | Python (the adversary) | 2 | 0 | 0 | 0 | 0 | 0 | 2 | 0 |
| v3-control-bytes | Python (the adversary) | 2 | 2 | 0 | 0 | 0 | 0 | 2 | 0 |

| Wrong core | Refused by | Detail |
| --- | --- | --- |
| `CoreAssumes.dfy` | audit | audit exit 2 |
| `CoreGapAboveAll.dfy` | postcondition | decision |
| `CoreHaltsAtRunTime.dfy` | word | the word `expect` is in tests/booking-certificate/fixtures/CoreHaltsAtRunTime.dfy |
| `CoreIssuesEverything.dfy` | postcondition | decision |
| `CoreKeepsCapacity.dfy` | postcondition | token |
| `CoreNeedsPrecondition.dfy` | error | a refining method is not allowed to add preconditions |
| `CoreNegativeRequestPrices.dfy` | postcondition | decision |
| `CoreNegativeSlotPrices.dfy` | postcondition | decision |
| `CoreNoBinaryCheck.dfy` | postcondition | decision |
| `CoreNoCapacityCheck.dfy` | postcondition | decision |
| `CoreNoDualCheck.dfy` | postcondition | decision |
| `CoreNoGapCheck.dfy` | postcondition | decision |
| `CoreOtherAllocation.dfy` | postcondition | token |
| `CorePrints.dfy` | error | to use a print statement, the enclosing method must be marked with {:print} |
| `CorePrintsMarked.dfy` | instance | to call a method with print effects, the enclosing method must be marked with {:print} |
| `CoreRefusesEverything.dfy` | postcondition | decision |
| `CoreStatesZeroGap.dfy` | postcondition | token |
| `CoreWrongBatchHash.dfy` | postcondition | token |
| `CoreWrongRequestId.dfy` | postcondition | token |
| `CoreWrongStateHash.dfy` | postcondition | token |
| `CoreWrongValue.dfy` | postcondition | token |

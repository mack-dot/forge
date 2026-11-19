# Accepted-assumptions list for `end_to_end` (DRAFT: needs the owner's sign-off, line by line)

Status: SIGNED by the owner 2026-11-19 (P1 to P6 ACCEPTED as written; see the end of this file). Drafted 2026-11-19 by the launcher on the owner's word ("Draft the Accepted-Assumptions List
from the 6 physical boundaries"). `end_to_end=false`: the list covers only the six transitions named in it.

## The rule this list serves

`end_to_end=true` may be stated for the refund slice ONLY when every transition of
[TOP_LEVEL_GRAPH_REFRESH_20261119.md](../m1b-mission-20261119/TOP_LEVEL_GRAPH_REFRESH_20261119.md), section 3,
is either MACHINE-CHECKED or one of the signed assumptions below. A transition that is MISSING, TESTED-UNPROVED,
or recorded as FUTURE WORK keeps `end_to_end=false`. Moving a transition to FUTURE WORK does not make it an
accepted assumption; only a signed line of this list does.

## The six physical boundaries

Each line: the exact statement, the transition it covers, why no proof in this repository can close it, how it
could fail, and what reduces the risk. "Covers" means only that transition, nothing else.

| # | Assumption (exact statement) | Covers | Why it cannot be proved here | How it can fail | Mitigation in place or planned |
|---|---|---|---|---|---|
| P1 | The macOS kernel returns, for `read`, `write`, `flock` and `fcntl(F_FULLFSYNC)` on the sink's descriptors, the results that the HOL basis oracle and the sink's code assume. | T12k | The kernel is outside every proof in this repository. | Kernel bug; a different OS version. | Pinned OS version in records; torture suite (`EIO` injection, kill points) as TESTED evidence. |
| P2 | The consumer of the refund process reads exactly the bytes the process wrote to descriptor 1. | T14o | The pipe and the reading process are outside the proved program. | A different reader, a shim, a broken pipe. | Exact-frame check and complete-output check in the launcher (tested by `test_process_lifecycle.py`, 24 tests). |
| P3 | A rollback of the whole volume (every local file restored together) is detected ONLY with the outside head and the ledger floor kept fresh by the host; without them it is not detected. | T20 | A store cannot authenticate its own history (owner decision D-5). | The host does not keep the outside head fresh. | D-5: both anchors are required for any rollback claim. |
| P4 | The payment provider honours idempotency keys within its stated key window and answers honestly. | T21 | The provider is a third party; tested only against a fake provider. | Key reuse after the window; a dishonest or faulty provider. | D-3: key bound to (charge id, request id, amount); replayed answers checked against the committed row. |
| P5 | After `F_FULLFSYNC` returns success, the written bytes survive a power cut. | T22 | Drive firmware and power physics. NOTE: power-cut behaviour is NOT TESTED (a SIGKILL is not a power loss). | Drive cache that ignores the flush; firmware bug. | Records state the drive model; a real power-cut test is FUTURE WORK. |
| P6 | The Apple ARM64 processor executes the instructions of the image as the HOL4 ARMv8 model specifies them, for the instructions and processor modes the image uses. | the CPU part of T11 and T13 only | Silicon is outside every proof. | Processor errata; a mode not covered by the model. | Pinned image digest `b8ed5ec2…7bb8`; the processor bits (TBI0, TBI1, SA0, EL0, E0E) remain a SEPARATE transition (T11), not covered here. |

## What this list does NOT cover (stays MISSING, TESTED-UNPROVED, or FUTURE WORK)

- **T13 / X8, minus the CPU part:** that a real process of the image, as the loader starts it, is a run of the
  totalised machine model from its entry state. Loader, entry state (T10), processor bits (T11), descriptors
  (T12) and the FFI premise (T9) are software and system facts, not silicon. With the owner's time-box (item 5),
  T9 (R6 FFI) and the APEX-3 WAL fold are recorded as FUTURE WORK. They keep `end_to_end=false`.
- **T2b, T3, T4, T4i:** the Dafny-to-HOL contract link and exporter fidelity. APEX-2 is the next bounded step.
- **T14a, T15, T16, T17, T18, T23, T24:** parser equality, launch environment, the deployed issuer and sink
  path, independent replay, termination of admitted modules, and approval that the agent cannot forge.
- **T19:** the hardened sink on `main`. Approved by the owner (B-15, B-16); in progress as its own PR.

## Owner sign-off

For each of P1 to P6: "accepted", "accepted with change: …", or "rejected". Until then, this file is a draft.

## Signed (owner's words, verbatim, recorded 2026-11-19T23:08Z)

> - P1 (Kernel syscalls): ACCEPTED as written.
> - P2 (Output reader): ACCEPTED as written.
> - P3 (Volume rollback): ACCEPTED as written (requiring outside head / provider anchor).
> - P4 (Provider behavior): ACCEPTED as written (retention window assumption).
> - P5 (Power cuts): ACCEPTED as written (untested power-loss physics; WAL recovery trims torn writes).
> - P6 (ARMv8 silicon): ACCEPTED as written (CPU matches ARMv8 ISA; loader/entry state in X8).
>
> All 6 lines P1–P6 are formally ACCEPTED. The queue order is approved.

Launcher notes: each line is accepted AS WRITTEN in the table above; the owner's parentheses are summaries. For
P3 the written line and decision D-5 require BOTH the outside head and the ledger floor; the provider key is a
second layer only (D-3, D-5). P6 covers the CPU only; loader and entry state stay in X8 (T13, T10), MISSING.
After this sign-off the MISSING transitions are still T4i, T9, T10, T11, T12, T13, T16, T17, T18, T23, T24;
T14a is TESTED-UNPROVED; T19 is in progress. So .

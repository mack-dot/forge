# Forge M1 completion and blocked audit — U317

CURRENT none. M1 open. Stage12 unauthorized. `end_to_end=false`.
Parent commit: `6ce40d4663e17499b6157f9b83d669e44b0208a6` (U316).
Audit verdict: **BLOCKED; full objective NOT_ACHIEVED**.
Goal service status: **blocked**, confirmed in [goal-status.json](records/goal-status.json).

The exact native refund correctness goal remains intact. A validated independent
execution/replay context and source/bootstrap provenance are still unavailable
in the inspected mission evidence. The current instruction-proof route also
has a preserved standard HOL SAT dependency failure. No new context or successful
dependency/observer run has been supplied or found. Repeating those commands,
using producer caches as independent evidence, or changing proof machinery would
not close the required gap within the existing constraints.

## Requirement-by-requirement assurance

The complete [U315 premise matrix](../read-runtime-20261105/ASSURANCE.md) and
[U316 checkpoint](../native-error-instructions-20261105/ASSURANCE.md) remain in
force. This audit removes no premise and grants no trust waiver.

| User requirement | Status of evidence | Completion judgment |
| --- | --- | --- |
|1. Inspect ffiread error/frame semantics and native behavior | PROVED model facts; TESTED native observations | Inspection completed in U315/U316. The exact physical relation remains unproved. |
|2. Establish correspondence through published infrastructure | NOT_ESTABLISHED | U315 proves four published-model lemmas. U316 identifies six exact native error-return words but exports no instruction theorem. No checked C/libc/Darwin refinement is available in the inspected chain. |
|3. Audit installation, resources, memory, linking, loading and OS premises | PROVED conditional compiler/model claims; ASSUMED environmental boundaries; NOT_ESTABLISHED physical applicability | The full matrix is retained. Installed state, complete memory/frame relation, installer applicability, resource adequacy and physical source/I/O correspondence remain open. |
|4. Native negative controls, distinct from proof | TESTED | U315 retains two matching eight-case runs:14 normal exit0 observations and two SIGPIPE(-13) terminations. Earlier native controls remain. These finite cases do not prove universal semantics or logical Success. |
|5. Independent21-snapshot replay after validated prerequisites | NOT_ESTABLISHED | Source identities match. Reviewer-controlled clean context and independent source/bootstrap provenance are not validated. Replay NOT RUN. |
|6. Independent closures, artifacts, executable, signatures and exits | TESTED local identities; PROVED prior conditional statements; NOT_ESTABLISHED independent full-chain assurance | U310/U315 exact imports and closure audits remain unchanged. Native bytes still match the historically verified signatures. Same-host readback is not independent source replay or production authentication. |
|Full success criterion | NOT_ESTABLISHED | No complete independently checkable specification-to-physical-execution correspondence package exists yet. |

Unicode, empty IDs, exact integer amounts, reasons and caller IDs retain their
full original source/model contracts. No valid input is excluded. Complete event
traces, the error predicate, heap relations and runtime/resource premises remain.
The four existing Boolean foundations and trust in HOL logic/kernel, Poly/ML,
host execution and cached ancestry remain explicit. Physical CPU/OS, C/libc,
Clang/linker/loader and interference assumptions remain as listed in U315.

## Three-turn blocked audit

| Consecutive goal turn | Progress classification | Common unresolved prerequisite |
| --- | --- | --- |
|Original turn: U315 | Progress: model lemmas, native controls and artifact audit | No validated clean independent execution context or source/bootstrap provenance; replay NO_GO. |
|First continuation: U316 | Progress: exact native word binding and dependency diagnosis | Same replay prerequisite remains open. The published instruction evaluator fails before a theorem; the separate SAT diagnostic reports EPERM. |
|Current continuation | Completion/blocker audit; no new proof progress | No validated replacement context or provenance has been supplied or found in the inspected mission/replay evidence. No authorized available route can close the physical relation and independent replay here. |

The repeated condition is the missing validated execution/replay prerequisite.
The SAT EPERM itself is not counted as three separate goal turns or attributed
to an unidentified syscall. U315/U316 progress is preserved and is not relabeled
as failed work. All our prior proof/observer handles returned terminal codes;
there is no verified live process to await. No failed command was restarted.
The blocked threshold is satisfied; the goal must stop for an external-state
change, rather than continue with status-only turns or repeated failing proofs.

## Exact smallest obligation and unblock condition

One real `ffiread` call must refine the unchanged published `ffi_read` in all
of its effects: actual OS return/error, complete output buffer, filesystem state,
valid return state, and full required memory/register frame. U315's ready/error
model facts and U316's instruction identities do not establish that relation.
Logical `Success`, modeled FFI events, native process exit0 and physical OS
behavior remain separate claims.

The retained U316 diagnostic is:

```text
HolSatLib.SAT_PROVE (probe OR NOT probe)
SysErr ("Operation not permitted", SOME EPERM)
```

Actual historical exit:1. The denied syscall/path is unknown; this does not
establish whether process creation or temporary-file access failed. It is an
OS-reported error, not an automatic approval-review rejection. No solver,
temporary path, permissions or proof machinery was changed to reroute it.

Unblock by supplying an explicitly authorized working proof/observer context
and a reviewer-controlled clean replay environment with verified source and
bootstrap provenance. In that context, run the unchanged standard dependency
diagnostic first and identify any remaining denied operation. If it passes,
inspect all six exact ARM8 instruction premises before composing the error-return
proof. That proof would still need the syscall and whole-function relation.
Use the unchanged [U310 replay plan](../exception-compiler-20261105/records/REPLAY-PLAN.md)
only after its prerequisites pass. Do not mount producer heaps or proof caches
as independent evidence. No implementation, specification or acceptance criterion
may be weakened to make the resumed work pass.

## Actual checks in this audit

| Executed command/check | Actual exit | Scope |
| --- | ---: | --- |
| `python3 results/refund-native-audit-2026-11-04/attempt-0012/audit.py` |0|487 prior packet members,21 original/snapshot pairs, accepted theorem data, both native files,50 protected paths and journal prefixes match. |
| Worktree HEAD / clean status / protected-path diff |0/0/0|HEAD6ce40d46; clean before audit documentation. |
| Scoped replay/environment evidence inventory |0|55 matching paths inspected; no validated replacement context record identified. This is not an exhaustive assertion about external infrastructure. |
| New HOL/SAT/observer/native/signature/replay execution |NOT RUN|Historical exits are preserved, not relabeled as fresh runs. |

Accepted native SHA256 remains
`b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`.
U310 theory data remains
`6b8a9a3cb7ecf6746d407b22d840f414b2d6d4e2618c8afc87680a6c94f0917f`;
U315 theory data remains
`32d97ebfdd39e761c4b9ea8905a2f6090df23b9c9985dafc2c508b266abaf050`.
Their recorded486/147-node closures and four Boolean foundations are prior
checked evidence. This turn verifies identity; it does not rerun the proofs.

All failures and immutable packets remain. Separate U314 work and U290/U297
stopped routes are unchanged. No protected change, release signing, deployment,
admission, hosted dispatch, publication, push, merge or stage transition occurred.

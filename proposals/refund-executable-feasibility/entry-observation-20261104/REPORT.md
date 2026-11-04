# Refund entry observation: failed debugger attempts

CURRENT stage: none. M1 remains open. Stage 12 is unauthorized.
`end_to_end=false`. Entry-state correspondence is `NOT_ESTABLISHED`.

The existing native executable and frozen input were used without rebuilding
or signing. Three LLDB invocations failed with SIGBUS inside the debugger.
No accepted entry-state record or target process-exit record was produced.
These failures are not behavioral counterexamples or successful rejection tests.

## Actual results

Commands ran from `/Users/mackianni/forge`. All local paths below start with
`results/refund-entry-observation-2026-11-04/`. Exact child arguments and hashes
are retained in each copied `records/<attempt>/command.json`.

| Command or check | Actual exit | Result |
| --- | --- | --- |
| `python3 -B .../attempt-0001/run.py` | child -10; launcher 246 | LLDB crashes during target creation; no process observation |
| Target-open diagnostic, exact argv in its record | 0 | File opens with eager symbol loading disabled; no target execution |
| `python3 -B .../attempt-0002/run.py` | child -10; launcher 246 | Numeric hardware-breakpoint setup; crash during dynamic-loader attach |
| `python3 -B .../attempt-0003/run.py` | child -10; launcher 246 | Disabling automatic symbol-script loading still crashes during attach |
| Initial `readback.py` | 1 | Expected symbolic stack in the wrong file; diagnostic failure retained |
| `readback_0002.py` | 0 | Uses preserved OS diagnostic for attempt 1; verifies all saved identities |
| Exact-target process query | 0 | No matching target process remains; its exit status is NOT_RECORDED |
| Existing compiler behavior process query | 0 | Original runner and Holmake remain live; proof exit is IN_PROGRESS |

The initial readback failure did not execute a debugger or proof. Its correction
uses the already preserved OS diagnostic for attempt 1 and debugger logs for
attempts 2 and 3. It does not change acceptance conditions or the failed records.
The expired tool handle for attempt 3 is not a new execution result. Its saved
terminal record establishes child exit -10. The Python runner propagates that
return code as shell status 246.

## Exact identities

| Input | SHA-256 |
| --- | --- |
| Complete native executable | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |
| LLDB executable, lldb-1700.0.9.502 | `89c7d02af88f43932a4481027df291ebb38f53e2cd058e0bc876f53553e68ece` |
| Frozen eligible-duplicate stdin | `7b450385073cc30d774749b240a8eb8252bfb9ba89b9af62d0f1e1435297c84f` |
| Attempt 1 observer | `245737631ed00299bb17ee8082a282b4d55776931fe4039ed94cf5c573f9cf49` |
| Attempts 2 and 3 observer | `e2c9653704ae4eb728149de3f9c47ac0abddbac5ccc903648f5889d673d23270` |

The readback verifies the unchanged executable, observer sources, command
scripts, debugger, full mission and 30 frozen implementation/policy inputs.
Hash checks establish identity only. They do not authenticate a producer.

## Observed failure and limits

The first crash's OS report identifies `ObjectFileMachO::ParseSymtab` through
`SymbolFileDWARFDebugMap::InitOSO` and `Module::PreloadSymbols`. Disabling eager
symbol loading lets LLDB open the exact file. Attempts 2 and 3 reach launch,
then fail in the same symbol parser during dynamic-loader attachment.
The logs retain the actual stacks. The exact defective object or parser input
has not been isolated. No conclusion about program correctness follows.

The raw OS crash report stays private locally. Its hash is
`d3dcd7fddb102665cfa1d49f4bfe86e28f9eec3ace5c14f2e23d0fe222b99919`.
Only its diagnostic summary is included here. The full debugger logs and all
three failed source/configuration versions remain in the evidence packet.

The attempted observation would read the stopped `cake_main` entry, general
registers, 130436 code bytes, 2531 bitmap words, five heap-header pointers and
selected memory regions. None of those observations completed. Attempts 2 and
3 require hardware breakpoints. They do not fall back to patching code bytes.
The observer does not establish universal instruction, loader, FFI or OS semantics.

Physical ARM control registers remain UNOBSERVED. Complete installed memory,
runtime/library identity, source/Unicode/model binding, FFI behavior, resource
sufficiency and exit correspondence remain NOT_ESTABLISHED. The full premise
matrix remains in [the compiler/runtime audit](../arm8-assurance-audit-20261104/REPORT.md).
The historical fixed RISC-V ELF work remains supporting evidence, not proof of
this refund executable. No theorem, specification or policy changed here.

## Smallest next action

Finish the existing compiler behavior invocation before interpreting its theorem.
Its process and log-tail checkpoint are included. Do not launch a duplicate.
If it succeeds, inspect its exact conclusion, run binding controls and reproduce
its exports. A successful compile equation alone does not establish behavior.

For the observation branch, isolate the debugger's exact symbol-loading failure
before another launch. Preserve the native file and signing boundary. Do not
strip, rebuild or re-sign it merely to bypass the observer failure. No unchanged
fourth attempt is proposed. The separate U278 builder EPERM investigation keeps
its own boundary; this task does not reroute its denied proof command.

Independent final-chain replay, exact claim/profile review, authenticated new
provenance/admission, and off-machine archive hash plus restore remain open.
Publication, protected adoption, merge, dispatch, release signing and deployment
require their corresponding authority. M2–M4 remain later work.

Integration EXIT: **NOT_ESTABLISHED**. No new executable correctness is claimed.

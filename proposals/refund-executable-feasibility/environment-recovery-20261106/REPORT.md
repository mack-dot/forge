# U318 — Bounded environment diagnosis; M1 remains blocked

CURRENT none. M1 open and blocked. Stage12 unauthorized. end_to_end=false.
Parent checkpoint: U317, commit a62970da86c484c76dea6ca412c8770fd347b47c.
This inspection follows the owner's request to recover execution capability
before more proof work. It does not resume the full goal.

## Result

The exact operation denied in U316 remains NOT_ESTABLISHED. There is a new,
source-backed explanation for the ambiguous error and a smaller diagnostic
target. No verifier, SAT solver, debugger, native refund process, or replay ran.

Pinned Poly/ML's `raiseSycallWithLocation` uses the standard errno message when
the error number is nonzero. It discards the call site's descriptive string.
Thus `mkstemp failed` and `Function system failed` can both become
`SysErr ("Operation not permitted", SOME EPERM)`. The text alone cannot select
one operation. See `polyml/libpolyml/run_time.cpp:239` and `run_time.h:74` in
the source snapshots.

The same runtime macro supplies `__FILE__` and `__LINE__` to the exception
packet. `PolyML.Exception.exceptionLocation` exposes the optional location.
The retained diagnostic prints `Feedback.exn_to_string ex`; it does not print
this location. No exception packet or location was retained after that process
exited. Whether an intervening ML raise replaced the original location is also
unestablished. A future location may identify a runtime raise site; it is not a
complete syscall/path trace and cannot retrospectively identify U316's failure.

## Source path and limits

| Source | Operation visible in the pinned source | Evidence limit |
| --- | --- | --- |
| HOL `minisatProve.sml:140`, `satConfig.sml:33` | SAT_PROVE uses the standard configuration, initializes DIMACS before solver invocation, and requests checked proof replay. | Static source path; no new execution. Initialization can return a theorem early. |
| HOL `dimacsTools.sml:253` | `FileSys.tmpName`, then `TextIO.openOut` and DIMACS writes. | The saved log does not show which step was reached. |
| Poly/ML `basis/OS.sml:782`, `libpolyml/basicio.cpp:1002` | Temporary-name operation uses P_tmpdir or the compiled fallback `/tmp`; it creates an MLTEMP file. | The inspected source has a mkstemp branch and a fallback open branch. This audit does not establish the exact binary's preprocessing or a failed path. No TMPDIR override is proposed. |
| HOL `minisatProve.sml:60`, `satTools.sml:53`, `tools-poly/Holmake/unix-systeml.sml:57` | Executable-access check; `Systeml.system_ps` calls `OS.Process.system`. | Executable mode bits would not establish permission to launch. |
| Poly/ML `basis/OS.sml:1117`, `libpolyml/process_env.cpp:569` | Unix system implementation uses vfork, then execv of `/bin/sh`, then waitpid. | vfork and waitpid failures raise SysErr. A failed child execv exits1 in this implementation. These distinctions are conditional source reasoning, not observations of U316. |
| HOL `SatSolvers.sml:92`, `satTools.sml:72` | Shell runs the pinned minisat command, redirects statistics, then HOL reads results and replays the proof. | No solver start or result file is established by the historical diagnostic log. |

These are candidate boundaries, not an exhaustive dynamic trace. The inspection
does not prove that every earlier DECIDE error had the same cause. It does not
prove either physical ffiread refinement or a mathematical impossibility.

## Exact next experiment — NOT RUN

1. Establish an explicitly authorized execution context with the existing
   isolation protections intact. Record its owner, architecture, permission
   scope, source/tool identities, bootstrap provenance, writable output area,
   and resource limits. Do not infer capability from file access bits alone.
   No replacement context was validated by this inspection.
2. In that context, run the unchanged retained dependency diagnostic first.
   Preserve its exact argv, cwd, inputs, stdout, stderr and actual process exit.
   The source SHA256 must be
   `bc3fb212a4037ae8e8ebd500f9843bff9cd93cbfcbc76501c7a152a9004af108`.
   Exact historical invocation: `records/historical-diagnostic/invocation.json`.
   Output routing must preserve the old records. Do not alter solver selection,
   temporary-path behavior, proof tools, specification or sandbox protections.
3. If that unchanged run fails, stop proof work. Preserve the failure. In the
   authorized diagnostic context, the next separately identified observation
   is the exception's optional `PolyML.Exception.exceptionLocation ex`, together
   with its errno. This is a proposed additive diagnostic only; no modified
   diagnostic was built or run here. If no original runtime location survives,
   an authorized host-level failure record is required. Do not guess or reroute.
4. A successful SAT result establishes that dependency query in that context.
   It does not close the native instruction theorem or physical I/O relation.
   Inspect the original ARM8 premises before further composition. Run the
   21-snapshot independent replay only after the U310 replay provenance and
   clean-environment gates pass. Producer heaps are not independent replay inputs.

No current permission change is requested. No environment-recovery command has
passed. The current failure is OS-reported EPERM, not an approval-review rejection.

## Assurance update

| Claim | Status | Evidence / remaining trust |
| --- | --- | --- |
| Twelve inspected source files match the local pinned Git objects | TESTED | `records/source-audit.json`; HOL9783a499, Poly/ML45575540;14 Git reads exit0. Local identity does not authenticate acquisition or source-to-binary production. |
| Saved diagnostic and relevant tool/heap identities remain intact | TESTED | Six historical files copied byte for byte; diagnostic historical exit1; no new diagnostic exit. |
| Generic errno text loses the operation-specific message | TESTED by source inspection | Pinned runtime source shown above; not a newly checked HOL theorem. |
| Exact denied syscall/path and exception location for U316 | NOT_ESTABLISHED | Historical output contains no location or syscall record. |
| Working authorized replacement context | NOT_ESTABLISHED | No validated replacement supplied or established here. |
| Original source/compiler/model theorems | PROVED at prior conditional scopes | U310/U315 evidence remains in force; this turn does not replay those proofs or discharge their premises. |
| Physical runtime, full FFI frame, installation and OS correspondence | NOT_ESTABLISHED | U315/U317 assurance matrices remain unchanged; environmental assumptions remain explicit. |
| Independent full-chain replay | NOT_ESTABLISHED | NOT RUN; clean environment and independent provenance remain prerequisites. |
| Protected paths and frozen mission | TESTED |50 paths and mission hash match the prior baseline. |

Logical Success, modeled FFI events, a native process exit0, and physical OS
behavior remain separate claims. No error predicate, full event trace, valid
input domain, heap relation, runtime premise or resource premise changed.

## Actual command results

| Command/check | Actual exit | Result |
| --- | ---: | --- |
| `python3 -B results/refund-environment-recovery-20261106/attempt-0001/source_audit.py` |0|12 pinned sources,6 retained diagnostic files,relevant tools/heaps,50 protected paths and frozen mission match. |
| Initial read-only source lookup batch |2|Missing guessed `libpolyml/exceptions.cpp`; corrected lookup found `run_time.cpp`. No tool execution or proof attempt. |
| New SAT/proof/native/independent replay |NOT RUN|Blocked context retained. |

Read-only lookup failures are recorded in `records/inspection-errors.md`.
The evidence recorder binds files and command results; it is not a proof checker.
All existing failures and immutable evidence remain. U290/U297 stopped routes
and the separate U314 work are untouched. No protected edit, stage transition,
release signing, deployment, publication or remote execution occurred.

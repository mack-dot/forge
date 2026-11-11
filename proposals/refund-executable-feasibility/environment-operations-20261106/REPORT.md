# U319 — Read-only execution diagnostic locates a filesystem permission denial

CURRENT none. M1 open and blocked. Stage12 unauthorized. end_to_end=false.
Parent checkpoint: U318, commit4aa8f08a2d19172cd91637b085fdc422fb95c7a5.

## Actual result

The corrected operation-specific diagnostic executes in the current managed
context and exits0. The exact pinned HOL executable and existing ARM8 heap load.
The diagnostic reads64 bytes from the unchanged U316 input, allocates65536 bytes,
and completes `OS.Process.system "/usr/bin/true"` with `SYSTEM_SUCCESS true`.
This is environment evidence, not a new theorem or a clean independent replay.

The HOL write-access query for `/var/tmp` returns false. A separate read-only
libc query records the precise failure:

```text
access("/var/tmp", W_OK)         = -1, errno=1 (EPERM)
access("/private/var/tmp", W_OK) = -1, errno=1 (EPERM)
```

No temporary-file creation probe was attempted. This establishes a denied permission query in
the new diagnostic. It does not identify U316's historical failing operation.
The libc query ran in the recorder's Python process. The HOL observation is its
own Boolean access result; no errno is attributed to that process by inference.

| Read-only query | Observed result |
| --- | --- |
| `/var/tmp` and resolved `/private/var/tmp`: existence,read,search |return0, errno0 |
| Same directory: write permission |return-1, EPERM |
| `/private/tmp` and Forge: all four access queries |return0, errno0 |
| Known absent path under the evidence directory |return-1, ENOENT for all four queries; no file created |
| `/var/tmp` metadata |Directory, mode01777, uid0, gid0 |

Mode01777 does not explain the write-access denial by itself. The observed errno
is a permission error, not the missing-path error seen in the control. The issuer
of the denial remains NOT_ESTABLISHED: these records do not distinguish sandbox,
ACL, TCC or another policy. No host denial log or syscall trace was captured.

## Why this narrows recovery

The retained source audit shows that HOL's standard SAT path generates a temporary
DIMACS file before solver execution. Pinned Poly/ML implements `tmpName` using
`P_tmpdir` when defined. The installed SDK's `_stdio.h:212` defines that macro as
`/var/tmp/`. The same source/SDK relationship was already recorded in the earlier
[temporary-path audit](../native-audit-followup-20261104/records/temp-path-source-audit.json).
U319 adds actual access observations; it does not replace that hypothesis with
a captured failing `mkstemp` or prove the exact binary's preprocessing choices.

Pinned `basicio.cpp:744` explains the Boolean HOL result: `fileAccess` calls
`access` and returns false for every nonzero result. This separate errno recorder
therefore supplies information absent from the HOL Boolean query. Both sources
and the SDK header retain their earlier hashes.

The process command's success means a blanket inability to execute a child
command is not observed by this current test. It does not prove all forms of
fork, exec, debugger launch or sandbox creation work. The memory probe covers
only65536 bytes. No resource-limit failure occurred in this diagnostic; resource
adequacy for compilation, proofs or independent replay remains unestablished.

## Separate failure boundaries

| Boundary | Evidence | Attribution limit |
| --- | --- | --- |
| Current operation-specific HOL diagnostic |Initial instrumentation compile exit1; corrected run exit0 |Initial error is `int` versus `FixedInt.int` in location formatting. No probe ran in that first attempt. |
| Current libc permission query |Recorder exit0; `/var/tmp` W_OK returns-1/EPERM |Exact API/path denial observed. Denial issuer and actual temporary-file creation remain unobserved. |
| Historical U316 SAT diagnostic |exit1, generic SysErr EPERM |No exception location or syscall trace. Not rerun; causal operation still unknown. |
| Earlier Holmake fixtures |Historical1/1, EPERM before proof |Temporary-path source hypothesis remains; no causal trace. No new Holmake execution. |
| Swarm sandbox launcher |Historical exit71, `sandbox_apply: Operation not permitted` |Separate sandbox-creation boundary; probe body did not run. No swarm or sandbox launcher retried. |

Evidence recorders write only their new result files under the authorized Forge
results directory. The probe operations themselves perform no filesystem writes.
References to read-only operation and no file creation have that scope.

The first diagnostic failure is preserved in `records/attempt-0002`. Only the
four exception-location conversions changed to `FixedInt.toString` in
`attempt-0003`. Both exact SML inputs, runner scripts, invocations, streams,
resource limits, hashes and actual exits remain. The exception-location handler
typechecks in the corrected run but was not exercised by a runtime exception.
Opaque `SYSTEM_STATUS ?` is retained; `SYSTEM_SUCCESS true` is the observed
standard API result. No numeric child status was extracted from that opaque text.

The CPU limit remains3600 seconds and core limit0, as in U316. Inherited memory,
stack,descriptor and process limits are recorded, not increased. Execution uses
the current Darwin27.0.0 arm64 context. Existing tool identities match their
earlier records. The Poly/ML runtime dylib hash is recorded before/after this run;
that fresh identity alone does not authenticate its production. No independent
bootstrap provenance or replacement environment is claimed.

## Smallest recovery step — not executed

Provide a separately authorized, isolated macOS ARM64 diagnostic context that
can run the same pinned tool bytes and has a private, writable `/var/tmp` for
their standard temporary files. Validate the context identity, source/tool
provenance, isolation, permission scope and resource limits before execution.
Use its own temporary filesystem; do not grant broad access to the host.
No change to this session's sandbox policy is proposed or made here.

Run the unchanged U316 diagnostic first in that validated context, preserving
the original SML SHA256:
`bc3fb212a4037ae8e8ebd500f9843bff9cd93cbfcbc76501c7a152a9004af108`.
If it fails, retain the new failure and obtain its original exception location
or an authorized host denial record before more proof work. Do not reroute the
solver, override the temporary directory, patch the runtime, or weaken proof
requirements. A successful dependency query would still not prove physical I/O.

No such replacement context is available through the validated evidence here.
The unchanged SAT query, full proof work, native refund execution, swarm and
21-snapshot independent replay remain NOT RUN. Independent replay requires its
separate clean-environment and independent source/bootstrap provenance gates.

## Assurance update

| Claim | Status | Exact scope |
| --- | --- | --- |
| Pinned HOL/ARM8 heap can execute the bounded diagnostic here | TESTED |Corrected actual exit0; no theorem constructed. |
| Current read,memory and system-command probes | TESTED |64 bytes,65536 bytes,standard system success. Finite observations only. |
| Current `/var/tmp` write-access query is denied with EPERM | TESTED |libc return-1,errno1; HOL independently reports Boolean false. |
| Temporary creation caused historical SAT or Holmake EPERM | NOT_ESTABLISHED |Source-supported hypothesis; no historical location or creation trace. |
| Exact denial issuer | NOT_ESTABLISHED |Permission result alone does not identify the enforcing mechanism. |
| Full resource and environment applicability | NOT_ESTABLISHED |Recorded limits and small probes do not discharge universal premises. |
| Prior refund source/compiler/model theorems | PROVED at their prior conditional scopes |U310/U315 evidence and full trace/error/heap/runtime/resource premises unchanged. |
| Physical ffiread relation and independent full-chain replay | NOT_ESTABLISHED |No new correspondence proof or replay. |
| Logic/kernel,physical ISA/OS and source-to-tool production boundaries | ASSUMED where used |Prior trust disclosures remain; these probes discharge none of them. |

Logical Success, modeled FFI events, OS process exit and physical behavior remain
distinct. No source specification,input domain,event requirement or theorem was
changed. All50 protected paths and the frozen mission match before/after both
HOL diagnostic attempts. No new release signing,protected change,Stage12 action,
deployment,remote execution or publication occurred. M1 stays blocked.

## Actual EXIT records

| Executed command | Actual exit | Record |
| --- | ---: | --- |
| `python3 -B .../attempt-0002/run_operations.py` |1|SML formatting type error; no operations reached |
| `python3 -B .../attempt-0003/run_operations.py` |0|All four probes reached; standard system success |
| `python3 -B .../attempt-0003/access_errno.py` |0|20 read-only access results; EPERM and ENOENT retained |

The raw prefix is `results/refund-environment-recovery-20261106/`.
One read-only SDK symbol search exited1 because `sandbox_check` declarations
were not found; no tracing API or sandbox command was invoked. An initial
navigation command displayed binary HOL bytes as text; this output supplied no
source evidence. Neither lookup changed a file. The diagnostic recorders are
observers, not new trusted proof machinery.

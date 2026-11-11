# U320 — Default Poly/ML temporary creation fails at mkstemp

CURRENT none. M1 execution blocked. Stage12 unauthorized. end_to_end=false.
Resumed from U319, commit3cbd82d29875351192389550626a35d1d615c6c2.

## Result

One targeted dependency diagnostic exits1. The private scratch read/write control
passes. The unchanged term `probe OR NOT probe` produces one CNF variable and
two clauses through the pinned `def_cnf.to_cnf`. The standard SAT configuration
therefore reaches the DIMACS branch that calls `OS.FileSys.tmpName`.

That function fails in the new diagnostic:

```text
OP_BEGIN OS.FileSys.tmpName
OP_EXCEPTION OS.FileSys.tmpName
EXCEPTION SysErr ("Operation not permitted", SOME EPERM)
ERRNO EPERM
EXCEPTION_LOCATION basicio.cpp:1025:1025-0:0
```

The complete location string is preserved without normalizing its other fields.
Its file and startLine identify the pinned `mkstemp` failure branch. This is a
current operation-specific failure. It does not retroactively identify the
operation that failed in U316's uninstrumented SAT run.

The full unchanged SAT diagnostic was not rerun. No refund theorem, instruction
proof, native refund execution, swarm, or independent replay ran.

## The directory is fixed in this runtime path

The pinned source makes an important distinction:

| Path | Temporary-directory selection |
| --- | --- |
| `basicio.cpp`, operation67 / `OS.FileSys.tmpName` |Uses compiled `P_tmpdir`, or `/tmp` only when that macro is absent. Does not read `TMPDIR`. |
| `osmemunix.cpp`, memory backing file creation |Reads `TMPDIR`, then tries compiled/default fallbacks. This is a different operation. |

Both files match Poly/ML commit4557554077078decce4ce5f90da00a713cfc32e4.
The existing `TMPDIR` already names the permitted per-user temporary area.
Changing it would not configure the pinned `tmpName` branch. No setting was
changed and no unsupported redirection was attempted.

Standard `otool` disassembly of the exact runtime exits0 and corroborates the
compiled branch:

| Runtime address | Standard disassembly observation |
| --- | --- |
|0x3a444 |Literal `/var/tmp/` |
|0x3a45c |Literal `/MLTEMPXXXXXX` appended to the directory |
|0x3a480 |Call to `_mkstemp` |
|0x3a498–0x3a49c |Test for return-1 and branch to the error handler |
|0x3a9e4 |Literal `mkstemp failed` |
|0x3a9f8–0x3a9fc |Line constant0x401 (1025), then `raiseSycallWithLocation` |

Thus the inspected runtime constructs `/var/tmp//MLTEMPXXXXXX`; the double slash
is retained in this description. The failed call's generated random suffix was
not captured. This is standard disassembly and runtime diagnostic evidence,
not a new formal machine-code theorem or proof of the OS implementation.

| Identity | SHA256 |
| --- | --- |
| Existing HOL executable |736c669e220381ddb6042fda624db79326aaa0075fe6ff9de4751bad75e8c4dd |
| Existing ARM8 heap |787499c5305260a0dcf93cab119e0cb2f830c539ddf9327c433758f0a92350a9 |
| Inspected Poly/ML runtime dylib |3f8fe4bc24c68d7d30840e2dd31966b50a02751d292fed3e67716b3575fa74fe |
| New dependency instrumentation |2c0fc86f4d6fd53b0b7ac660873427201334886b0811ba1d7270f2b96992fdff |
| Preserved unchanged U316 SAT source |bc3fb212a4037ae8e8ebd500f9843bff9cd93cbfcbc76501c7a152a9004af108 |

The new input uses the exact original term and the published CNF function. It
then probes the published temporary-name function separately, with exception
location output. It does not replace the frozen SAT input or alter proof tools.
Local file identity is not independent acquisition or bootstrap provenance.

## Likely enforcement boundary and limits

The current managed writable roots include Forge, `/private/tmp`, and the
per-user temporary directory. They exclude `/private/var/tmp`. U319 recorded
write-access EPERM for that directory despite mode01777, while permitted-path
controls passed. The current private scratch write/read also passes.

A single host-log query restricted to MLTEMP messages exits64 with:

```text
log: Cannot run while sandboxed
```

The managed filesystem sandbox is therefore the likely enforcement boundary.
This is an inference from the declared permission profile and observed errors.
No kernel denial event was obtained, so the exact denying rule or policy issuer
is NOT_ESTABLISHED. No escalation,alternate logging route or retry followed.
The historical Holmake and swarm `sandbox_apply` failures remain distinct.

CPU3600/core0 remain unchanged. Other inherited resource limits are recorded.
No memory/resource failure is observed here; resource adequacy for full proofs
or replay remains unestablished. A mode0700 scratch directory does not establish
a separate OS isolation boundary. Evidence files and the benign scratch file
are the only new authorized workspace writes. No global permissions changed.

## Smallest authorized unblock action

Provide an existing authorized isolated macOS ARM64 host/VM with its own private
filesystem and writable `/var/tmp`, keeping host protections intact. The pinned
runtime needs that path; its memory-related TMPDIR setting does not fix this
operation. No change to the current sandbox,global directory permissions,
runtime source or proof machinery is proposed.

The scoped inventory found no supported VM command among tart,utmctl,prlctl,
limactl,vfkit,VBoxManage, and no UTM,Parallels,VMware Fusion or VirtualBox app at
the inspected standard paths. This does not assert that no external host exists.
No replacement host or connection has been supplied. The user has been asked
for the existing authorized execution target. Dependent work remains pending.

Before using that target, validate its architecture,permission scope,enforced
isolation,source/tool production provenance and resources. Run the requested
read/write,process,memory,temporary-file and negative permission controls there.
Then run the frozen SAT source first, saving complete streams and actual exit.
If it fails, retain the failure and obtain an original exception location or
authorized denial record before further proof work. Do not change the theorem,
solver,temp API or premises to make it pass.

Only after that result may the physical ffiread investigation resume. Its
smallest unresolved contract still joins OS result,complete buffer,filesystem
effect,return state and full FFI frame. The frozen21-snapshot replay additionally
requires a clean environment and independent source/bootstrap provenance;
producer heaps or caches are not independent replay evidence.

## Assurance update

| Claim | Status | Evidence / limitation |
| --- | --- | --- |
| Original term takes the nonempty DIMACS branch | TESTED |Published CNF initialization reports1 variable,2 clauses; standard source calls tmpName on this branch. No full SAT execution. |
| Default temporary creation fails at mkstemp | TESTED |Current SysErr EPERM and runtime location1025; compiled error branch corroborates it. |
| Runtime temporary directory for that path is `/var/tmp/` | TESTED |Pinned source and standard disassembly; no custom decoder. |
| Temporary-directory selection in pinned tmpName | TESTED by source/static inspection |It does not read TMPDIR. That setting applies to the separate memory backing path. |
| Managed filesystem sandbox caused the current denial | ASSUMED as the leading explanation |Permission roots and blocked host-log query support the inference; exact denying rule remains unestablished. |
| Historical SAT/Holmake failed for this same reason | NOT_ESTABLISHED |No original exception location or trace. |
| Authorized validated replacement context | NOT_ESTABLISHED |No target supplied or available through the scoped inventory. |
| Prior refund/source/compiler/model results | PROVED at prior conditional scopes |U310/U315 statements and full error,trace,heap,runtime/resource premises remain. |
| Physical ffiread correctness and independent replay | NOT_ESTABLISHED |No new correspondence theorem or full-chain replay. |

No unchecked axiom,specification weakening,premise removal or trusted-tool change.
Logical Success,modeled FFI events,native process exit and physical OS behavior
remain separate. All86 recorded input bindings,including50 protected paths and
the frozen mission,match before/after the diagnostic. Earlier failures remain.

## Actual commands

| Command | Actual exit | Result |
| --- | ---: | --- |
| `python3 -B results/refund-environment-recovery-20261106/attempt-0004/run_temp_requirement.py` |1|Scratch control and CNF stage pass; default tmpName raises EPERM at mkstemp. |
| `otool -tvV -p _PolyBasicIOGeneral .../libpolyml.16.dylib` |0|Static runtime path and failure branch inspected; no target launch. |
| `log show --style ndjson --last 15m --predicate 'eventMessage CONTAINS "MLTEMP"' --info` |64|Cannot run while sandboxed; no denial events retrieved. |
| Initial metadata lookup using `/usr/bin/ls` |127|Wrong executable location; corrected `/bin/ls` lookup exits0. No target operation. |
| Full unchanged SAT / physical proof / replay |NOT RUN|Required replacement context remains absent. |

Two external pinned-source fetches returned tool-level Cache miss; no source was
taken from those failures. Local pinned Git objects supply the source evidence.
Proof development and the swarm stay stopped. No Stage12,release signing,
deployment,protected change,remote execution or publication occurred.

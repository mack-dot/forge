# U326: Unchanged SAT diagnostic executes without privilege

CURRENT none. M1 open. Stage12 unauthorized. end_to_end=false.

The one additional authorized GitHub-hosted ARM64 job ran the unchanged SAT
source successfully. HOL exited0 and printed `⊢ probe ∨ ¬probe` followed by
NATIVE_STEP_COMPLETE. The source,the five saved states,the runtime and libraries
retain their exact pinned bytes. No sudo,protected change,rebuild,heap rewrite,
solver rebinding or theorem change occurred.

**Limit:** the embedded original MiniSat path was not executable. The unchanged
HOL library's existing proof fallback was available. This is a successful HOL
SAT diagnostic,not evidence that the external native MiniSat binary ran. The
same HOL checker remained in use; no replacement checker or tactic was injected.
A passing tautology diagnostic does not prove physical ffiread correspondence.

[Run42400884739](https://github.com/mack-dot/forge/actions/runs/42400884739),
[job128488158467](https://github.com/mack-dot/forge/actions/runs/42400884739/job/128488158467),attempt1.
The API reports completed/success for the single job. The logged SAT subprocess
return code is0; no inference from the job status alone is needed.

| Executed check | Actual exit/result |
| --- | --- |
| Local published loader API check |0; no SAT in the blocked local context |
| Matched pinned sources and local workflow static checks |0 |
| Hosted sw_vers,sysctl,true,otool |0 each |
| Hosted /var/tmp access,mkstemp,read/write | Access0; mkstemp fd3; errno0;33 bytes match |
| Negative read-permission control | EACCES13 on own mode000 file |
| Private writable root | UID501,mode0700,under RUNNER_TEMP |
| Exact HOL/SAT subprocess |0; theorem and completion marker printed |
| Separate API/log/stream/input/source review |0;36 remote input hashes and18 current sources match |
| New physical instruction/FFI proof or full replay |NOT RUN |

## Safe path selection and fixed inputs

NEXT-ACTION.md proposed mkdir and chown through sudo. Both target one new
private directory,but both require privilege. The latest user constraint
prohibits sudo,so neither command was used. The replacement uses mkdtemp under
the existing runner-owned temporary root:
`/Users/runner/work/_temp/forge-m1-pnsscbe1`,UID501,mode0700.
No permission change to /Users or /Users/mackianni was attempted.

Published `PolyML.SaveState.loadHierarchy` accepts the five parent filenames
explicitly. The pinned implementation checks saved-state compatibility and
parent relationships. It loads the same bytes from their new storage locations.
No renameParent call,modified state,custom loader,axiom or proof-library rewrite.
The initializer only loads those states,prints their identity/solver reachability,
and dispatches the unchanged preload and SAT source through QUse.use.
The original default solver binding remains unchanged.

The input bundle is reused from commitac05eaf972b8c98784466ae063fca505aaaf25f4.
Input manifest SHA256:
6822d1ae4ef5ca78ae14e352c5b1e222ed113bba1f3760d9b0141b70386c51a7.
SAT source SHA256:
bc3fb212a4037ae8e8ebd500f9843bff9cd93cbfcbc76501c7a152a9004af108.
Workflow commit:8ad9de1e538edd48a2084796510e784913eaef8b.
Workflow SHA256:65e3addb289c29650fd7c84b2d3894c8d468a351a422778e9a1c9a9ec6a87027.
Remote workflow readback matches exact local bytes. The commit modifies only
this workflow on the proposal branch; it leaves protected/default-branch files alone.
No additional toolchain payload was uploaded.

Before and after execution,the job checks every one of the18 files against the
same manifest. Separate local review matches all36 records and all18 original
source files. The loader prints exactly five loaded saved-state paths. Dyld
records the copied pinned libpolyml and libgmp paths. Existing source revisions
HOL9783a49979c94c401ff8c0e51b2eefae7ea95ae3 and
PolyML4557554077078decce4ce5f90da00a713cfc32e4 match the inspected API/solver sources.

## Runtime and observed result

macOS15.8.2 build24H232; Darwin24.6.0; ARM64; image20261104.0514.1.
Python3.9.6 executable SHA256
5c5950c62eee5fd227a67e4bdfcde81c9add59799bba0949635f3d5ba9661c26.
Reported memory7516192768 bytes; temporary disk free49232515072 bytes.
CPU limit120 seconds per process; HOL maxheap1024MiB; core limit0; stream-file
limit32MiB. The15-minute job ceiling bounds infrastructure use and is not a
proof-acceptance criterion. No limit was increased to force a result.

The complete1061-byte stdout has SHA256
bcce9389ee783189c6d405c0b6d69589ce71a63c6cc7ab8be988d80822e1d6dc.
The complete96531-byte stderr has SHA256
c99d288e5bd61647b47a432efc5e5047ecca5c38597d9213e48ec5e03530c60b.
Both streams were transferred as base64 records and independently size/hash
checked after decoding. The complete172948-byte retrieved job log has SHA256
909cc3cdfe9daae052dcab8103e5ce63a5bb183979f91a40b77976172bec68cc.
Raw provider timestamps are retained to preserve the exact requested log; a
separate normalized view removes only provider timestamp prefixes/ANSI escapes.

The log prints FROZEN_SOLVER_EXECUTABLE false. The matched `minisatProve.sml`
uses DPLL_TAUT when its configured executable is unavailable; SAT_PROVE keeps
is_proved=true. U320's same pinned diagnostic CNF has one variable/two clauses.
The fallback classification follows those observations and the matched source;
no separate internal-function trace was captured. Do not count this run as
external MiniSat execution or exact reproduction of its old installation path.

GitHub's timing API reports one job,0 billable MACOS milliseconds and47000ms
run duration. No account-wide invoice or unrelated charges were inspected.
The prior U324 exit78 and every earlier failure remain preserved. This run
introduces no new failed proof attempt. U324's incorrect manifest environment
key is corrected; its original workflow and failure records remain unchanged.

## Remaining scope

[Exact next physical-proof step](NEXT-STEP.md). The previous six-word instruction
fragment remains bound to the native executable; none of its instruction/frame
theorems was checked in this run. First test the unchanged ARM8 evaluator load
in the permitted context,then request the exact STRB step and inspect all premises.

The existing compiler composition and four model-read lemmas are unchanged.
Full OS read/buffer/filesystem/return-state/FFI-frame correspondence,independent
bootstrap provenance and the21-snapshot clean replay remain NOT_ESTABLISHED.
The provider VM,OS/loader,HOL logic/kernel and previously built states remain
trusted. This hosted diagnostic reuses pinned producing artifacts; it is not an
independently controlled full-chain replay. Logical Success,modeled FFI events,
OS exit0 and physical behavior remain separate claims.

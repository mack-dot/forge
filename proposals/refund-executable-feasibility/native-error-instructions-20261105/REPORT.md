# Exact native error instructions; proof dependency blocked — U316

CURRENT none. M1 open. Stage12 unauthorized. `end_to_end=false`.
Parent local commit: `2e4315138a6984268d4ad1297748337af3adcec3` (U315).
The previous goal turn made progress through four checked filesystem lemmas,
native controls and exact artifact readback. Those results remain unchanged.

The28 instruction words printed for the native `ffiread` match both executable
files. This identifies the exact six-instruction error-return path for a proposed
ARM8 proof. **No native instruction theorem was produced.** The published HOL
instruction evaluator fails while loading. A separate standard HOL SAT diagnostic
exposes `SysErr ("Operation not permitted", SOME EPERM)`.

## Actual executions

| Command/check | Actual exit | Result |
| --- | ---: | --- |
| Pinned LLDB static disassembly and section listing | 0 | Exact bytes and file layout; no process launch |
| Native-word binding | 0 |28 words/112 bytes match both existing executables |
| `run_hol.py inspect-steps inspect-steps.sml` | 1 | Relative load cannot find arm8_stepLib.ui |
| `run_hol_0002.py inspect-steps-0002 inspect-steps.sml` | 1 | Absolute load fails in utilsLib/numLib.DECIDE |
| `run_arm8.py inspect-arm8-steps inspect-arm8-steps.sml` | 1 | Published ARM8 heap reaches stepLib, then numLib.DECIDE fails |
| `run_dependency_diagnostic.py dependency-diagnostic diagnose-sat.sml` | 1 | Standard SAT_PROVE reports EPERM |
| `readback.py` / `readback_0002.py` | 1 / 0 | First reader looked only at stdout; corrected reader checks both retained streams |
| New instruction proof, repeat, exact import and negative controls | NOT RUN | No instruction theorem or export was reached |
| New native execution / debugger launch / independent full-chain replay | NOT RUN | Required environment conditions remain unvalidated |

The full argv, source hashes, output hashes and actual child exits are in
[COMMANDS.md](COMMANDS.md) and `records/*/command.json`. CPU limit:3600 seconds per
HOL process. No new build, signature, executable, solver, or proof machinery was
installed or changed. No denied operation was rerouted.

## Exact instruction identity

Pinned LLDB23.1.5 reports the `__TEXT` segment at unslid VM address0x100000000
with file offset0. The selected instruction words below match the actual file
bytes, in little-endian order. HOL's published ARM8 evaluator was selected to
give them semantics; the byte-binding script does not decode instructions.

| Unslid VM address | File offset | Word | Standard disassembler text |
| --- | ---: | --- | --- |
|0x1000251ac|151980|37f800c0|tbnz w0,#31,0x1000251c4|
|0x1000251c4|152004|52800028|mov w8,#1|
|0x1000251c8|152008|39000268|strb w8,[x19]|
|0x1000251cc|152012|a9417bfd|ldp x29,x30,[sp,#16]|
|0x1000251d0|152016|a8c24ff4|ldp x20,x19,[sp],#32|
|0x1000251d4|152020|d65f03c0|ret|

The entire112-byte disassembled function spans file offsets151920–152031.
Fragment SHA256:
`ec5f3b8045a2d7038e8645acd7bd72a001bddc75ab24b7fd913c4d36cc163bf4`.
Both whole executables remain:
`b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`.
The fragment does not include the called libc read implementation, OS kernel,
or separate cold assertion routines. It is not their dependency closure.

No program was launched during this inspection. Static image metadata for
dependent libraries is not evidence of a running process or physical load state.
The old failed debugger launches remain stopped; they were not retried.

## Exact dependency failure

The first load uses a relative library name from the CakeML basis working
directory and fails at lookup. The second uses the existing pinned absolute
path. It finds the library but fails while loading the unchanged `utilsLib`.
The third uses HOL's existing ARM8 heap, the target specified by the published
`arm8/step/Holmakefile`. It gets past utilsLib and fails in `arm8_stepLib`.
Both later load errors report `numLib.DECIDE`. No requested instruction theorem
is printed in any run. No fourth library-load attempt occurred.

Read-only source inspection shows that `DECIDE` can fall back to `TAUT_PROVE`,
which uses HOL's SAT proof infrastructure. A separate process, with no repeated
step-library load, calls the unchanged `HolSatLib.SAT_PROVE` on the explicitly
constructed term `probe ∨ ¬probe`. It prints:

```text
DIAGNOSTIC_DEPENDENCY_FAILURE
SysErr ("Operation not permitted", SOME EPERM)
```

The diagnostic proves an execution restriction in that standard proof path.
It does not identify the exact denied syscall or path. The evidence does not
distinguish process creation from temporary-file operations. It also does not
prove that every earlier DECIDE failure had this same cause; the matching failure
chain is an inference supported by the inspected source. No mathematical
counterexample to the native instruction claim was obtained.

The tool route is now stopped. No alternate solver, temporary path, helper
process, permission setting, or evaluator patch was used. This is an OS-reported
EPERM, not an automatic approval-review rejection. The underlying instruction
proof remains NOT_ESTABLISHED. Library-load failures are not passing negative
controls, and no partial helper is promoted to an accepted theorem.

## Remaining physical obligation and next check

U315's four model theorems still require a physical relation for one complete
`ffiread` call: actual syscall result, full returned buffer, filesystem effects,
valid return state, and complete FFI memory/register frame must agree together.
A proof for these six instructions would cover only the post-syscall error
return, under its exact machine-state, code, stack, separation and return-address
premises. It would not establish the syscall, full function entry/prologue,
physical ISA behavior, or the original complete FFI relation by itself.

The next smallest tool check is the unchanged dependency diagnostic in an
explicitly authorized context where its underlying operation is permitted.
Identify the failed syscall/path there before proposing any environment change.
Do not retry the same blocked context. Once that diagnostic passes, load the
unchanged ARM8 evaluator, inspect every premise of the six exact instruction
theorems, and only then construct the composition. Require complete statement
checks, dependency closure, repeat, meaningful controls and byte readback before
accepting it. No theorem statement or approved input domain may be weakened.

The independent21-snapshot replay remains NOT RUN. Its source identities were
validated in U315, but an independently controlled clean environment and source/
bootstrap provenance have not been established. The current dependency failure
does not authorize a rebuild, permission change, or cache-based substitute.

## Readback and trust

The corrected byte readback verifies2659 U310 parent bindings, ten unchanged
upstream snapshots, the additional standard ARM8 tool identities,270 U315 packet
members,134 U310 packet members, both native files,50 protected paths, frozen
mission bytes and both existing uncertainty-log prefixes. The first readback
failure is retained; it searched stdout for a loader error written to stderr.
The correction changes only that evidence reader, not proof code or outputs.

The accepted U315 data hash remains
`32d97ebfdd39e761c4b9ea8905a2f6090df23b9c9985dafc2c508b266abaf050`.
Its fresh proof/import,147-node closure and four Boolean foundations are prior
results, not new executions here. Existing native signatures are reused only
through unchanged exact executable identity; they were not re-signed or freshly
verified in this turn. No new theorem closure exists to audit.

HOL source revision remains `9783a49979c94c401ff8c0e51b2eefae7ea95ae3` with a
clean tracked diff. The local ARM8 heap is
`787499c5305260a0dcf93cab119e0cb2f830c539ddf9327c433758f0a92350a9`;
the local L3 heap is
`9a59e119969c4a180d1eaa19104f92237054ca5e81fe3298e5ad9843b440052c`.
These hashes establish local identity, not independently authenticated bootstrap
production. [ASSURANCE.md](ASSURANCE.md) retains the full proof and trust limits.

## Preservation checks

The full staged whitespace check exits2 for exact disassembler output and the
pinned arm8_stepScript.sml source. The authored Markdown check exits0.
Those evidence bytes remain unchanged. `records/whitespace-checks.json` and its
full output retain the distinction. All original failures remain available.

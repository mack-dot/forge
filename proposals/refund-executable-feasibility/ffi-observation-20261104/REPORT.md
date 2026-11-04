# Refund native FFI observations

CURRENT stage: none. M1 remains open. Stage 12 is unauthorized.
`end_to_end=false`. This packet records finite native calls. It does not prove
the C runtime, operating system, complete memory frame, or executable behavior.

The existing exact refund executable performs three `ffiread` calls and one
`ffiwrite` call for the frozen eligible request. Two complete observations record
the full configuration and data buffers before and after each call. Each call
returns to the saved link-register address. Registers x19–x28 and SP agree across
each call. Both processes reach `cml_exit` with argument 0 and actually exit 0.

## Actual execution results

Let `R=results/refund-ffi-observation-2026-11-04` under the owner workspace.
The records retain exact argv, source, tool hashes, buffers, logs and exit codes.

| Command or check | Actual exit | Result |
| --- | --- | --- |
| Authenticated observer CLI help | 0 | Inspected existing breakpoint and memory commands |
| `python3 -B $R/discovery-0001/run.py` | 0 | Three reads, one write, then exit; no open or close call observed |
| `python3 -B $R/capture-0001/run.py` | 0 | Four complete before/after captures; native exit 0 |
| `python3 -B $R/capture-repeat/run.py` | 0 | Identical observer source; native exit 0 |
| Initial saved-capture readback | 0 | Four byte comparisons and return/register checks |
| `python3 -B $R/validate_observations.py` | 0 | 38 byte comparisons; complete call order, hardware breakpoints and two observed exits |
| `python3 -B $R/run_model_check.py positive` | 1 | HOL record type annotation did not parse; no accepted theorem |
| Focused parser diagnostic | 0 | Original record fails; spacing before the type annotation parses |
| `python3 -B $R/run_model_check.py positive-0002` | IN_PROGRESS | Original child 91810 remains live; terminal result not available |
| Altered-read-byte and wrong-write-descriptor model controls | NOT RUN | Prepared; require the positive model check first |
| Model proof reproduction and independent import | NOT RUN | No accepted model proof yet |
| Six pinned upstream source checks | 0 | No tracked change; exact hashes in `semantics-inputs.json` |
| Original compiler behavior invocation | IN_PROGRESS | Runner 47209 and Holmake 47239 remain live |

An unexecuted source draft also contained a newline escaping error in diagnostic
print strings. It was corrected before any proof invocation. That draft remains
under `draft-before-escape-correction/`. It is not a failed theorem check.

The actual first HOL attempt failed on `|>:IO_fs`. A separate parser diagnostic
reproduced that failure and accepted `|> : IO_fs`. The second attempt changes
that spacing and its output directory only. No observation, expected result,
filesystem operation, or required assertion changed. The saved second-attempt
log is explicitly a snapshot. A live process is not a passing proof.

## Identity and observation boundary

The exact executable remains
`b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`.
The frozen stdin is 62 bytes, SHA-256
`7b450385073cc30d774749b240a8eb8252bfb9ba89b9af62d0f1e1435297c84f`.
The expected stdout is 64 bytes, SHA-256
`629d44e9f09823060942f4b75007dcf87ddce9c505314a4b74f9ac19d9d84cee`.
Both observations produce those stdout bytes and empty stderr.

The observer uses the same authenticated LLVM 23.1.5 LLDB and existing Apple
debugserver recorded in the [entry packet](../entry-capture-20261104/REPORT.md).
Every invoked observer and input is identified in each `command.json`.
Hardware breakpoints are required and confirmed after installation. Temporary
return breakpoints are also hardware breakpoints. The observer reads memory
through debugger commands. Its persistent address expressions disable JIT.
It does not inject a helper, rebuild the executable, or sign anything.

Loaded code matches the HOL-derived 130436-byte payload at entry and immediately
before native exit. All 20248 bitmap bytes also match. The two runs have different
ASLR addresses. Their call buffers and fixed payloads agree byte for byte.
The 96 loaded bytes containing the existing FFI stubs also agree between runs;
this is not a separate proof of those stubs' machine semantics.

| Observed call | Configuration | Data-buffer length | Recorded response header |
| --- | --- | ---: | --- |
| Read 1 | fd 0, eight bytes | 4100 | `00 00 3e 30` |
| Read 2 | fd 0, eight bytes | 4100 | `00 00 00 30` |
| Read 3 | fd 0, eight bytes | 4100 | `00 00 00 30` |
| Write | fd 1, eight bytes | 2052 | `00 00 40 00` |

The native C source encodes these as success and transfer counts 62, 0, 0 and64.
The entire returned buffers are retained, including unchanged padding and tail
bytes. The HOL check must validate all bytes against the existing model; a header
match alone is insufficient. No open or close breakpoint was hit in this fixture.

## Exact model check in progress

The proposed check uses the existing `basis_ffi_oracle no_ext` and `fsFFI`
definitions at CakeML commit `cd9155694c16831373ab695a670794f23282ed62`.
HOL remains `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`. No new semantics,
verifier, axiom or acceptance policy is introduced.

For each captured call, the required HOL equation relates its complete observed
input buffers and modeled filesystem to its complete observed output buffers
and next modeled filesystem. Stdin starts with the independently frozen request.
Stdout and stderr start empty. Descriptor positions must advance as required.
The model's first four transfer-choice entries are4096. The remaining stream
`ns` and command-line value `cl` stay arbitrary in the equations.

This is a finite conformance check for one observed request. It does not prove
that every native call implements the oracle, that the actual descriptor state
equals the constructed filesystem, or that the unobserved stream is live.
Even a successful check will not discharge `wfFS`, full installed-state,
physical ARM control-state, whole-memory preservation, external interference,
resource sufficiency or universal OS exit obligations.

Two prepared controls retain the captured inputs and required outcomes. One
changes a returned read byte. The other substitutes fd0 for the write descriptor.
They must fail at the corresponding HOL equation. They have not run at this
checkpoint. They are model-input mutations; no mutated executable is run.

## Next action and remaining assurance gaps

Poll the existing model child91810 and compiler child47239. Do not launch a
duplicate merely because observation is slow. Inspect actual terminal results.
If the model equation checks, run the two controls, reproduce the proof objects,
and independently import the exact theorem with its dependency closure.

The separate U284 source theorem retains the complete modeled event trace. Its
basis extraction and exact program initialization remain separate work. Neither
that source theorem nor these finite observations establish universal C/POSIX
refinement. Keep the full approved refund domain and every unresolved premise.

Independent final-chain replay, exact claim/profile review, authenticated Forge
provenance and admission, and independent-copy archive hashes plus restore remain
open. Upstream debugger authentication does not authenticate local Forge evidence.
No hosted runtime or savings result is claimed. M2–M4 remain later priorities.

Integration EXIT: **NOT_ESTABLISHED**. No protected adoption, publication, merge,
dispatch, release signing, admission, deployment or Stage12 ran here.

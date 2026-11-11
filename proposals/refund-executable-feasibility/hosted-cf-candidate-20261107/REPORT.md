# U329: generic FFI execution package prepared; hosted approval pending

CURRENT none. M1 PARTIAL. Stage12 unauthorized. `end_to_end=false`.
Parent checkpoint:U328, commit `b8586b6fc3d37d5423114fc7a8cf96b4030403ec`.
This work prepares the exact next experiment. It establishes no new behavioral
theorem and does not resolve the native read-error correspondence.

## Actual local results

| Command/check | Actual exit | Result |
| --- | --- | --- |
| Public saved-state parent inspection |0|Four required states identified |
| Public loaded-module/path metadata inspection |0|549 modules preloaded; cfLib absent |
| Static input collection and deterministic packaging |0/0|280 module nodes;1,475 new files,three archive parts |
| Relocated input/term inspection |0|1,493 input hashes match before/after; exact statement parses; no theorem attempted |
| Prepared workflow/Python validation |0|One job; token permissions empty; one commit-ID placeholder |
| Log roundtrip and transport controls |0|Three files reconstructed byte for byte |
| Wrong archive hash / path traversal / symlink controls |1/1/1|Intended assertion refusals; no forbidden file created |
| First artifact readback |1|Wrong cross-workspace protected baseline; failure preserved |
| Corrected separate-baseline readback |0|Root historical50 paths and review worktree prior commit remain unchanged |
| Generic candidate / hosted run / independent replay |NOT RUN|New hosted-run and transfer approval pending |

The actual local invocation, stdout and stderr are in
[records/local-inspection](records/local-inspection). It loads four unchanged
states with public `PolyML.SaveState.loadHierarchy`, registers the private
HOLDIR/CAKEMLDIR roots through `holpathdb.extend_db`, relocates Meta.loadPath,
loads the basis theory and parses the exact candidate quotation. It resolves
the cfLib module path but never loads that library. No local SAT, ARM8 evaluator
or failed proof route was retried. The runtime load log names the private copies
of the pinned Poly/ML and GMP libraries. OS frameworks remain environmental.

The four states are HOL/bin/hol.state0, HOL/src/num/termination/numheap,
HOL/bin/hol.state and cakeml/misc/cakeml-heap. Their exact hashes appear in the
two input manifests. Public path registration changes search paths; it does not
rewrite saved states, theorem files, solver bindings or proof machinery.

The static collector follows published .ui/.uo file references and adds the
existing U328 cached proof ancestry. It finds no absolute module-file references
that require source rewriting. Its limited source scan finds no additional
literal load/use references in the inventoried non-Theory library sources.
This is not a proof of all possible dynamic file dependencies. A missing file
on the runner must fail visibly. Cached-parent provenance is reused, not
independently reproduced.

## Exact prepared artifacts

The [new manifest](payload/INPUTS.json) is932,639 bytes; SHA256
`6822e8da53f477f991bfa4a7cab02ffc59906a58460048a49af190fb42b2c105`.
It binds1,475 files totaling111,912,627 raw bytes. Three parts reconstruct the
9,882,464-byte archive; SHA256
`1f7a009b866b18c8299aac5d36b6ad59e54bfb73d4bba568da98ebde3c2146e1`.
The existing base manifest binds18 additional files and remains
`6822d1ae4ef5ca78ae14e352c5b1e222ed113bba1f3760d9b0141b70386c51a7`.
Total proposed new publication:10,815,103 bytes, plus the prepared workflow.

Candidate SHA256 remains
`7e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6`.
The candidate statement is now parsed in the relocated context. Its proof
tactics, theorem conclusion and dependency closure are still unchecked.
The unchanged U328 failure remains the last actual cfLib attempt:exit1 during
helperLib/numLib.DECIDE, before the theorem. No syscall errno was captured there.
This preparation does not establish that it had the same cause as U320.

The reviewed workflow has exactly one dynamic field:the new immutable input
commit SHA. Its template hash and driver hash appear in [APPROVAL.md](APPROVAL.md).
All13 workflow files at the observed proposal head are matched to Git blob
identities. No other workflow would trigger on the proposed input/workflow
branch pushes under those inspected definitions. Publication must recheck the
branch head and exact bytes before the single trigger. No remote write occurred.

The local inspection used driver-v0. The final driver preserves its exact
bootstrap and adds a150-second child wall limit, explicit runtime-path gates
and earlier identity/resource logging. These driver changes pass syntax/static
review; their hosted process behavior is not tested locally. The 4 MiB child
file cap is an explicit experiment resource bound, not a native-program premise.
If output is incomplete or missing, evidence validation fails.

## Remaining obligation and next action

U328 proves that guarded status1 read events make complete basis-FFI replay
return NONE. U310 requires SOME. The ext parameter cannot override read. This
is a checked model obstruction, not a proved native counterexample. Do not
delete error events or infer a no-error input restriction from OS trust.

The smallest proposed semantic obligation is `read_error_generic`:from an
explicit generic FFI status1 transition, derive the unchanged TextIO read
function's InvalidFD exception, exact buffer, FFI state and full event append.
The transition is a premise to be discharged by native/runtime correspondence;
it is not a newly accepted assumption or custom oracle definition.

After approval, execute the unchanged candidate once in the validated context.
If it fails, preserve the exact exception/residual and stop. Only if it passes,
run the bounded repeat/import/two statement controls in the same job. Then
inspect the real theorem premises and closure before any composition. No result
can be predicted from parsing, library loading, hashes or expected exit codes.

Even a checked candidate would leave native C reads/frame effects, partial
reads/EOF, inputAllFrom/refund_main composition, stdout, runtime memory,
installation/resources, linker/loader semantics and independently controlled
21-snapshot replay open. Logical Success, modeled events, native exit status
and physical effects remain distinct. ISA implementation, documented OS syscall
behavior and HOL/kernel are explicit owner trust assumptions. No silicon proof
is required. No new axiom, stronger behavioral assumption or protected edit.

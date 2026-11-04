# Refund native boundary audit

CURRENT none. M1 remains open. Stage12 is unauthorized. `end_to_end=false`.
This packet records native build preparation and independent saved-record checks.
It does not contain a native refund executable or an accepted native proof.
It reuses U262 and commit73728c2; the completed Unicode proof did not rerun.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Docker image inventory | 1 | Socket access refused with EPERM; no Linux run |
| First unchanged C runtime compile | 1 | `assert.h` unavailable without an explicit SDK |
| `build_runtime.py` | 0 | Two child compiles0/0 with the installed SDK; identical objects |
| `otool -hv`, `nm -u`, `clang --version`, `otool -L clang` | 0 each | Object architecture, unresolved symbols and compiler dependencies recorded |
| `prepare_corpus.py` | 0 |22 fixed cases prepared; no expectation accepted as proved |
| `run_corpus.py dry-run` | 0 | Only the new fixture theory needed a build |
| `run_corpus.py 0001` | 1 | HOL single-job driver refused with EPERM before proof |
| `run_corpus.py 0002 2` | 1 | HOL multi-job driver also refused before proof |
| `readback.py` | 0 | Source, header, object and saved schema evidence hashes match |

Exact argv and working directories are in `records/*/command.json` and
`records/tool-inspection-commands.json`. Raw results remain at
`results/refund-native-audit-2026-11-04/attempt-0001/`.
The permission failures are infrastructure failures. They are not negative
refund controls. No escalation, permission change or redirected execution was used.
The exact denied operating-system call inside Holmake has not been established.

## Native target and artifact identity

The selected candidate is Darwin arm64, using the pinned CakeML arm8 export.
CakeML commit: `cd9155694c16831373ab695a670794f23282ed62`.
HOL4 commit: `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`.
Poly/ML5.9.2 commit: `4557554077078decce4ce5f90da00a713cfc32e4`.
The published exporter contains Apple symbol and assembly branches. Source
inspection establishes an available target route, not target correctness.

The unchanged `basis/basis_ffi.c` SHA256 is
`e65a58121bcf7c32501ed01f75783f08ec30653192b2265665a9cdae199ab2a1`.
Its two separately built ARM64 object files have SHA256
`74f9efbf5132301386c2656638f826e6e5fec2593e99d406aa9618851dc94a55`.
They are object files, with unresolved CakeML entry and heap/stack symbols.
No native refund executable has been linked, hashed or executed.

Apple clang17.0.0 uses the installed macOS15.5 SDK. Its exact executable hash,
SDKSettings hash and108 compiler-listed source/header hashes are recorded.
The initial missing-SDK failure is preserved. This is local object build
reproduction. The compiler's dynamic dependencies and the host are not a fully
closed, reproducible environment. Neither object hashing nor compilation proves
the C runtime correct.

## Compiler theorem and open premises

The inspected published theorem is `backendProof.compile_correct` at
`compiler/backend/proofs/backendProofScript.sml:4952` in the pinned source.
It requires the exact successful compile result, primitive source initialization,
absence of source failure, valid backend/machine configuration, initial machine
state and `targetSem.installed` for the exact bytes, bitmaps and FFI names.
`records/readback.json` records exact Git-blob equality for the inspected sources.
The theorem has not been instantiated or replayed for a native refund program.

Its conclusion permits `extend_with_resource_limit`: resource termination may
produce only a prefix of the expected I/O trace. It does not prove complete
normal output for every input. The stronger space theorem needs additional
safe-for-space premises for every pointer-equality oracle and matching machine
limits. No such refund proof has run. The unbounded source input domain must
remain intact; finite native resources must be explicit in the execution claim.

`targetSem.installed` checks modeled code/data placement, alignment, heap/stack
bounds, bitmap metadata and FFI installation. A hash of an executable does not
discharge those logical premises. The assembled/linked code and data sections,
startup wrapper, actual FFI entry points and loader state still need binding.
The pinned C runtime, C compiler, assembler, linker, operating system and actual
read/write behavior remain outside the currently checked refund relation.

## Real transport gap

U263 checks twelve schema/model theorems. Independent saved-record readback
confirms its positive/repeat0/0, six identical exports and four intended
theorem failures1/1/1/1. It also confirms the recorded159-node dependency list,
12 own tags and four existing HOL foundation axioms. This readback did not run
a new independent kernel replay. Imported DISK_THM data is not authenticated
proof evidence merely because it has a local hash.

The published `SexpProg.inputSexp_spec` leaves an arbitrary remainder in the
input stream. The proposed `refund_decode_wire` requires an empty remainder.
The native wrapper must explicitly check the remaining stream. A pure
trailing-input theorem does not establish that actual stdin rejects a second
request. Output encoding, write completion and error behavior also need the
whole-program theorem. The schema proof alone does not establish the library
heap/frame relation needed by the generated refund method.

The22 prepared fixtures cover allowed reasons, zero and maximum accepted
amounts, Unicode scalar boundaries, NUL/escaped IDs, empty IDs, invalid flags,
invalid reasons, upper/lower bounds and integers of magnitude2^256. Their
expectations are explicit data. The proposed HOL checks compare them with the
existing `refund_expected_tuple`; they introduce no new decision algorithm.
Both build attempts stopped before those checks. No fixture expectation is
accepted as proved, and no native positive, negative, mutation or reproduction
control has run. Python UTF-8 encoding only materializes fixture bytes; it is
not used as proof of the Unicode relation.

## Next smallest steps

Complete the exact generated method's characteristic-formula heap/frame proof
and compose the existing stream I/O rules, including explicit end-of-input
handling. Resolve the denied fixture-build operation within authorized
permissions before another fixture proof attempt. Then compile the same
whole program through the existing arm8 in-logic compiler and retain its exact
byte/data/configuration theorem. Native execution controls follow that artifact.
Do not substitute a separately reimplemented refund function.

All50 frozen protected paths and the mission bytes remained unchanged. The
prior516530 uncertainty-log bytes still match. No signing, admission, deployment,
protected-policy change or Stage12 action occurred.

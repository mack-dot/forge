# Refund compiler and runtime premise audit

CURRENT stage: none. M1 remains open. Stage12 is unauthorized.
`end_to_end=false`. This audit preserves the full refund R1–R5 contract.
It does not approve a reduced claim, a new trust profile or a release.

The compilation equation is checked and reproduced. The same compiled code
and bitmap bytes are present in both native executables. Their whole-file SHA256
is `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`.
The compiler behavior proof is still building published dependencies. No final
behavior theorem is accepted at this checkpoint.

## Results actually inspected or executed

| Check | Actual exit | Scope |
| --- | --- | --- |
| Original closure inspection | child−15; launcher241 | Deliberately stopped while formatting a generated term; incomplete audit |
| `run_closure_0002.py` | 0 | Fresh import; all10 own export tags inspected |
| `dependency_snapshot_0002.py` | 0 |378 theory nodes;377 loader file sets; kernel seed min |
| Closure readback | 0 | Four existing foundation axioms; zero explicit hypotheses on10 own exports |
| Initial source collection | 1 | Record basename collision; partial files retained; no proof ran |
| `collect_sources.py` | 0 |13 exact pinned upstream sources; HOL/CakeML tracked diffs0/0 |
| Separate HOL code/data extraction, inspected here | 0 |130436 code bytes and2531 bitmap words extracted by existing HOL evaluation |
| Separate native identity matrix, inspected here | 0 | Two complete executable copies; exact compiled code and bitmap bytes |
| Separate altered-code hash / signature control | 1/1 | Intended digest mismatch and invalid signature |
| `native-byte-readback.json` | 0 | Rechecked two executable slices and saved rejection reasons |
| Compiler behavior composition | IN_PROGRESS | No terminal exit or accepted conclusion yet |

The original audit printed all closure names, then spent its work expanding
`refund_prog_cv_eq` for display. SIGTERM stopped that diagnostic. Its log,
source and numeric result remain intact. The revised audit changes only output:
it prints every own tag and the exact compilation theorem. It does not alter
any theorem, proof object, dependency, assumption or acceptance condition.

The four foundation axioms are SELECT_AX, INFINITY_AX, ETA_AX and BOOL_CASES_AX.
The10 inspected own exports retain DISK_THM imports. Fresh import and hashes do
not authenticate a producer or replay every upstream source. The separate
identity matrix uses existing HOL, nm, otool, shasum and codesign. It does not
decode machine instructions or prove Mach-O loading semantics.

Code SHA256: `3c67983c93b3f7bbb340c2c517f6315ae2dc6260f2b401fb09d3b5a24ba15deb`.
Bitmap SHA256: `68d3f080066fdaeb12ff1c061a875b1502172be0857a2af02f77f6f18f36fb76`.
The native file offsets are16592 and180248. These are file offsets, not observed
runtime addresses. An ad hoc signature checks local byte integrity. It is not
authenticated Forge release provenance or independent owner review.

## Exact conditional model claim

The published `compile_correct` theorem requires the successful compilation
equation, a non-failing source semantics, a valid backend configuration, a valid
machine configuration, compatible initialization and `installed` code/data.
It concludes:

```text
machine_sem mc ffi ms ⊆ extend_with_resource_limit(source_semantics)
```

`extend_with_resource_limit` includes `Terminate Resource_limit_hit` with an
I/O prefix of the source behavior. Therefore a successful application of this
theorem alone does not guarantee complete output or normal termination.
The stronger published `compile_correct_is_safe_for_space` also requires
`is_safe_for_space` for every pointer-equality oracle and matching `read_limits`.
Neither extra obligation is discharged for the full refund domain here.

Source references below refer to the13 frozen copies in `upstream/`.
Their complete hashes and pinned commit are in `source-inspection.json`.
All refer to CakeML `cd9155694c16831373ab695a670794f23282ed62`.

## Assumption-to-evidence matrix

PROVED means a checked model claim within its stated trusted base. TESTED means
finite observations or byte checks. ASSUMED identifies an explicit trust
boundary, not an approved waiver. NOT_ESTABLISHED means a missing proof or
concrete premise. The status always applies to the relation named in its row.

| ID | Required relationship | Status | Evidence or unresolved premise |
| --- | --- | --- | --- |
| S1 | Full approved refund R1–R5 intent and source implementation | PROVED at source | Earlier source checks and original-input locks remain intact; stateless decision and intent, not actual financial effects |
| S2 | All nine typed model inputs and six result fields | PROVED in model | U267/U271; canonical requests give the complete modeled response, including rejected decisions |
| S3 | Full source Unicode/integer domain reaches the exact model representation | NOT_ESTABLISHED as complete chain | Earlier UTF-8 source proof preserves emptiness, approved reasons and IDs; the complete source/model/native binding remains open |
| S4 | `stdin_content fs` is the exact serialized canonical request at offset0 | TESTED for fixtures; general concrete relation NOT_ESTABLISHED | TextIOProofScript.sml:6244; both22-case typed runs supplied exact frozen bytes, but no universal native input relation is proved |
| S5 | `wfcl cl`: valid arguments, nonempty list, length below65536 | NOT_ESTABLISHED as concrete model witness | CommandLineProofScript.sml:12 and clFFIScript.sml:12; recorded argv is finite, but the instantiated command-line/state relation is not exported |
| S6 | `wfFS fs`: descriptor bounds, inode contents and consistent file mapping | NOT_ESTABLISHED | fsFFIPropsScript.sml:221; native pipes do not alone establish the formal filesystem witness |
| S7 | Filesystem liveness: infinite transfer-choice stream, eventual nonzero capacity | ASSUMED for general execution; NOT_ESTABLISHED for a concrete witness | fsFFIPropsScript.sml:202; finite completed tests do not prove perpetual progress or scheduling fairness |
| S8 | `STD_streams fs`: stdin fd0 in read mode; stdout/stderr fd1/fd2 at their append offsets | TESTED at pipe interface; full relation NOT_ESTABLISHED | fsFFIPropsScript.sml:1310; actual output bytes observed, no complete OS/model descriptor relation |
| S9 | Initial FFI oracle, state `(cl,fs)` and empty I/O history | NOT_ESTABLISHED concretely | basis_ffiScript.sml:19,94; required concrete FFI events must correspond to the basis oracle, not a candidate-selected substitute |
| C1 | Exact `refund_prog` compilation, oracle witness and final configuration | PROVED in model | Repeated refund_arm8_compiled equation, code/data/FFI/symbol/configuration bindings; U275 |
| C2 | Source non-failure and compiler behavior theorem compose for this exact program | NOT_ESTABLISHED yet | `run_behavior.py 0001 repeat` remains active; successful dependencies are not its conclusion |
| C3 | Runtime target is the published ARM64 target; argument registers0/1/2/3 and callee-saved19–28 match | NOT_ESTABLISHED concretely | arm8_configProofScript.sml:11; backend mapping checked by published proofs under this premise; platform ABI correspondence remains open |
| C4 | Backend and machine initialization configurations agree | NOT_ESTABLISHED for the concrete process | backendProofScript.sml:136; word width, register mapping, endianness, link register and target config must agree |
| E1 | Machine state satisfies `arm8_ok` | NOT_ESTABLISHED; system registers UNOBSERVED | arm8_targetScript.sml:20 requires EL0, E0E=false, SA0=false, TBI0=false, TBI1=false, NoException and4-byte-aligned PC. No physical control-register observations establish these premises. Do not infer them from successful native tests |
| E2 | Concrete PC/register/memory state relates to the abstract assembly state | NOT_ESTABLISHED | asmPropsScript.sml:57; equal PC, all program-domain bytes and all32 registers except18/26/31. Arbitrary initial values are permitted only where the relation and initialization allow them |
| E3 | Floating-point and reserved-register obligations match this configuration | PROVED as configuration facts; concrete relation NOT_ESTABLISHED | arm8_targetScript.sml:343 has fp_reg_count0 and avoid_regs18/26/31. The register relation has no FP equality obligation here; do not add a fabricated FCSR proof or ignore ARM state validity |
| E4 | Initial PC is the exact `cake_main` entry and has required alignment | TESTED in file metadata only | Exported symbols and code offsets are checked. No stopped process-state witness binds the entry PC to the loaded mapping |
| E5 | Halt/install/FFI addresses have the required relative layout and lie outside program/shared domains | NOT_ESTABLISHED concretely | targetSemScript.sml:279 start_pc_ok; wrapper uses16-byte FFI blocks, but installed address domains and loaded offsets remain to be checked |
| E6 | `target_configured`: no failed abstract state, correct endianness/alignment, memory domain and link register | NOT_ESTABLISHED concretely | targetSemScript.sml:247; source configuration facts do not create an actual state witness |
| M1 | Loaded instruction bytes equal the compiled bytes | TESTED for executable files; loading NOT_ESTABLISHED | Both file slices match130436 HOL-derived bytes. No process-memory snapshot or loader theorem establishes code_loaded |
| M2 | All abstract data words correspond to byte memory with little-endian word views | NOT_ESTABLISHED concretely | targetSemScript.sml:444 good_init_state; compiler bitmaps match files, but the quantified memory-word relation is unobserved |
| M3 | Data/shared domains are byte-closed and program/shared domains are disjoint | NOT_ESTABLISHED | good_init_state; zero compiled shared-memory extras does not itself prove complete mapping disjointness |
| M4 | Heap/stack region boundaries are aligned, ordered and at least1024 words apart | NOT_ESTABLISHED as state relation | installed_def at targetSemScript.sml:487; basis_ffi.c:850 allocates contiguous memory and computes three boundaries. Actual malloc/loader state and model relation remain open |
| M5 | Bitmap region is aligned and disjoint from heap/stack; all2531 words match | TESTED for bitmap file bytes; runtime separation NOT_ESTABLISHED | Native bitmaps match the HOL numeral list in both files. No loaded address/separation witness exists |
| M6 | First five heap words hold exact bitmap start/end, data end and code-buffer start/end | NOT_ESTABLISHED | installed_def; generated cml_main stores these pointers at offsets0/8/16/24/32. Inspecting instructions is not proof that a concrete entry state has these values |
| M7 | Extra data space has the required readable word footprint, without assuming initialization | NOT_ESTABLISHED | `word_list_exists` permits arbitrary contents but requires a valid separated footprint. Do not substitute zero initialization or omit unobserved pages |
| M8 | Code buffer fits address space and does not overlap data | NOT_ESTABLISHED | good_init_state requires each buffer byte in the program domain, outside data, and `cbspace + LENGTH code < 2^64`; actual ranges/permissions are unobserved |
| M9 | Required memory access and executable permissions are honored | ASSUMED at the OS/ISA boundary; full relation NOT_ESTABLISHED | Formal memory domains are not a Mach-O/MMU permission proof. Complete runtime loading, writable data and instruction fetching still need justification |
| F1 | Exact FFI names, index order, relative entry addresses and register lengths/pointers match | TESTED in generated files; runtime relation NOT_ESTABLISHED | Compilation binds names; installed/start_pc_ok bind entries; wrapper exposes read/write/close/open_in. The loaded machine configuration is not yet instantiated |
| F2 | Every FFI returns with valid machine state, link-register return PC, preserved callee-saved registers and only the permitted buffer update | ASSUMED runtime ABI contract; NOT_ESTABLISHED formally | targetSemScript.sml:317 ffi_interfer_ok is universal. Finite output matches do not prove this memory/frame condition |
| F3 | Concrete read/write/close/open behavior implements the basis FFI oracle | ASSUMED C/POSIX boundary; NOT_ESTABLISHED formally | basis_ffi.c:138–202 and basis_ffiScript.sml:19; source and object hashes fix identity, not semantics of clang, libc or kernel I/O |
| F4 | Code installation preserves state, returns correctly and has memmove overlap semantics | NOT_ESTABLISHED | targetSemScript.sml:380 install_interfer_ok. Even if this program never invokes installation, the proposed theorem retains the premise unless an existing checked argument removes it |
| F5 | MMIO index/range/record mapping matches shared-memory extras | NOT_ESTABLISHED concretely | installed_def ties shmem_extra to entries and mmio_info. The compiler proves an empty extras list; no concrete configuration witness is supplied |
| I1 | Between-instruction interference preserves the projected state | ASSUMED environment boundary; NOT_ESTABLISHED formally | asmPropsScript.sml:77; ARM projection includes PSTATE, SCTLR, TCR, exception, registers, program memory and PC. Signals, debuggers, threads and scheduling cannot silently violate this condition |
| R1 | Enough stack/heap for full output over each supported input | NOT_ESTABLISHED | compile_correct permits resource-limit prefixes. The stronger is_safe_for_space/read_limits obligations remain open; two256MiB environment settings are not a proof over unbounded strings/integers |
| X1 | Modeled halt maps to actual process termination/status | TESTED for56 processes; universal relation NOT_ESTABLISHED | targetSemScript.sml:127 checks ptr_reg0 at halt_pc; generated cake_exit branches to cml_exit; basis_ffi.c:721 calls exit(arg). libc/OS behavior is outside the checked model |
| X2 | Malformed input follows the required whole-program exception/rejection contract | NOT_ESTABLISHED | U274 has five failed checks. Six malformed fixtures per run emit no output and exit0. Neither that observation nor a checker exit1 proves a native error-status contract |
| T1 | Actual processor/OS steps refine the published ARM semantics | ASSUMED boundary requiring review; NOT_ESTABLISHED by this audit | Exact code identity does not prove physical instruction semantics, cache behavior, MMU state, interrupts or platform model equivalence |
| T2 | Independent source replay and authenticated producer | NOT_ESTABLISHED | Imported DISK_THM closure inspection is local. No clean replay independent of this producer workspace/cache or new release provenance is claimed |
| T3 | Independent admission for this exact claim, artifact and environment | NOT_ESTABLISHED | Historical Stage9 signatures authorize historical artifacts. New claim/profile review and corresponding release authority remain required |

## Smallest next actions and boundaries

Finish the existing compiler behavior build. Inspect its actual statement before
calling it a behavioral guarantee. Then use targeted binding substitutions and
a fresh repeat. The current successful compilation remains separate from that
unfinished proof.

The highest-value concrete observation is an entry-state witness at `cake_main`:
loaded code/data bytes, PC, heap/stack registers, the five header words, ranges
and memory permissions. Standard debugger observations can test those finite
facts. They cannot prove universal FFI interference, OS semantics, scheduling
fairness or resource sufficiency. The ARM control-register premises must remain
explicit if they cannot be observed or justified by a checked projection.

Do not weaken the full source domain to fit finite heap measurements. A resource
conditional claim must state its condition and obtain exact profile review.
No such profile has been adopted. Continue the source/model/Unicode binding and
the preserved exception gap. A separate inspection of a failed goal does not
establish that goal or authorize a blind sixth retry.

No theorem, specification, runtime implementation or protected policy changed.
No new semantic framework or persistent infrastructure was introduced. This
audit performed no signing, native execution, publication, merge, dispatch,
admission or deployment. The separate native task owns its limited local
signing authorization. Independent-copy archive hashes and restore are still
unverified. M1 and strict integration EXIT remain NOT_ESTABLISHED.

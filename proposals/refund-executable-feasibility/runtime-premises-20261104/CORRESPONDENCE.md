# Refund runtime correspondence — U296

CURRENT none. M1 remains open. Stage12 is unauthorized. `end_to_end=false`.
This reconciles U277 with U283, U289, U291, U294 and U295. Earlier reports
remain historical. No source specification, input domain or acceptance policy changes.

The target is the refund decision and intent, under the complete approved R1–R5
contract. It is not a bank transfer, arbitrary stateful application, or the fixed
RISC-V GCD example. The exact native ARM64 file is:
`b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`.

PROVED refers to a checked mathematical statement under its listed premises and
trusted base. OBSERVED refers to retained finite measurements. DERIVED refers
to arithmetic or identity checks from those measurements. ASSUMED identifies
a proposed trust boundary, not an approved waiver. UNOBSERVED and
NOT_ESTABLISHED remain open. Several statuses can apply to different parts of
one relationship. No observation establishes a universal refinement theorem.

The exact source definitions are retained in `upstream/`. CakeML source commit:
`cd9155694c16831373ab695a670794f23282ed62`. `input-readback.json` binds the
13 original source files, 12 capture members and 50 unchanged protected files.

| ID | Required relationship | Status and exact evidence or missing obligation |
| --- | --- | --- |
| S1 | Approved eligibility and all six refund fields | PROVED at source and model, under their respective semantics. U262/U267/U271/U294/U295; no actual financial effect is claimed. |
| S2 | All nine inputs, including complete Unicode strings and mathematical integers, reach the same model values | PROVED shared byte-list contracts in U295; U294 checks parsed AST/model/compiler-input equality. Cross-kernel interpretation and the unverified C# serializer still need independent review. No input precondition was added. |
| S3 | Exact canonical serialized request is `stdin_content fs` at offset zero | PROVED model wire round trips; OBSERVED only for recorded fixtures. A general relation from the external producer's bytes to the source values is NOT_ESTABLISHED. |
| S4 | `wfcl cl` | NOT_ESTABLISHED for a complete concrete witness. Requires nonempty arguments, every argument valid, and fewer than 65536 arguments. See `basis/CommandLineProofScript.sml:12` and `clFFIScript.sml`. |
| S5 | `wfFS fs`: descriptor bounds, referenced inodes, consistent file mapping | NOT_ESTABLISHED physically. Model predicates are explicit in `basis/fsFFIPropsScript.sml:221`. Native pipe observations are insufficient to establish the full witness. |
| S6 | `live_numchars`: infinite choice stream and eventual nonzero capacity | ASSUMED for general runtime progress; not discharged by four finite FFI events. See `fsFFIPropsScript.sml:202`. |
| S7 | `STD_streams fs`: fd0 readable at the input position; fd1/fd2 writable at their append offsets | OBSERVED pipe behavior; full state relation NOT_ESTABLISHED. Requires descriptor modes, offsets, unique associations and stdout/stderr inode membership; see `fsFFIPropsScript.sml:1310`. |
| S8 | Initial basis FFI state and empty event history | PROVED model initialization; concrete `(cl,fs)`/oracle relation NOT_ESTABLISHED. U289 proves four events for one input and an arbitrary remaining choice stream. |
| C1 | Exact program compiles to exact code, bitmap and configuration | PROVED U275/U291. Loaded/file code SHA256 `3c67983c93b3f7bbb340c2c517f6315ae2dc6260f2b401fb09d3b5a24ba15deb`; bitmap SHA256 `68d3f080066fdaeb12ff1c061a875b1502172be0857a2af02f77f6f18f36fb76`. |
| C2 | Conditional compiler behavior for the full result | PROVED U291. Its `extend_with_resource_limit` conclusion allows incomplete output prefixes. It is not an unconditional success/termination guarantee. |
| C3 | Runtime machine configuration uses the published ARM64 target, ptr/length registers 0/1 and 2/3, callee-saved 19–28 | PROVED configuration facts conditional on `is_arm8_machine_config`; concrete ABI correspondence remains ASSUMED/NOT_ESTABLISHED. See `arm8_configProofScript.sml:11`. |
| C4 | Backend initialization and target configuration agree | PROVED published implications under C3; applying them to the physical process requires the concrete state relation. Word width, link register, endianness and register mapping cannot be inferred from a passing fixture. |
| E1 | `arm8_ok`: EL0, E0E=false, SA0=false, TBI0=false, TBI1=false, NoException, aligned PC | PC alignment DERIVED from the recorded PC; CPSR is OBSERVED. SCTLR_EL1 and TCR_EL1 fields are UNOBSERVED. Complete state validity is NOT_ESTABLISHED. See `arm8_targetScript.sml:20`. |
| E2 | `target_state_rel`: equal PC, all program-domain bytes, all non-avoided GPRs | 34 named entry values OBSERVED, including x0–x30, SP, PC and CPSR. No complete quantified memory relation is established. Required GPR indices exclude 18,26,31; see `asmPropsScript.sml:57`. |
| E3 | FP and reserved-register relation | PROVED configuration fact `fp_reg_count=0`, avoided registers 18,26,31. The FP equality clause is vacuous for this target. No FCSR guarantee is fabricated. ARM validity conditions still apply. |
| E4 | Entry PC equals loaded `cake_main` and is aligned | OBSERVED PC 4300243152 and exact loaded payload. DERIVED 4-byte alignment. U283 retains the authenticated debugger producer and stopped-state capture. |
| E5 | `start_pc_ok`: halt/install/FFI layout, aligned entries, exclusions from program/shared domains, MMIO ordering | Partial offsets DERIVED under uniform relocation. Complete predicate NOT_ESTABLISHED. U290 stopped after five failures; no sixth retry. See `targetSemScript.sml:279`. |
| E6 | `target_configured`: no failed abstract state, little endian, alignment, memory-domain and link-register agreement | Configuration facts PROVED; concrete state witness NOT_ESTABLISHED. See `targetSemScript.sml:247`. |
| E7 | Stack pointer and allocation registers | OBSERVED SP 6166656464, x1=496542679040, x2=496811114496, x3=497079549952. SP alignment 16 and range arithmetic DERIVED. These do not prove all ABI or memory premises. |
| M1 | Every loaded instruction byte is the compiled byte | OBSERVED 130436 bytes; exact file offset 16592 slice and HOL-derived payload match. This is code identity, not a universal Mach-O loader or physical instruction-semantics proof. |
| M2 | All program-domain bytes and abstract memory words have coherent little-endian views | NOT_ESTABLISHED. `good_init_state` quantifies the memory relation; the captured code, bitmaps and header do not cover all heap/stack or all abstract addresses. See `targetSemScript.sml:444`. |
| M3 | Data/shared domains are byte-closed; data is in program domain; program/shared domains are disjoint | Candidate address intervals are DERIVED; the complete witness is NOT_ESTABLISHED. Empty compiled shared-memory extras alone do not prove these quantified conditions. |
| M4 | Heap/stack boundaries are aligned, ordered, at least 1024 words apart and mapped | OBSERVED four adjacent read/write 128 MiB regions. DERIVED total span 536870912 bytes, ordered/aligned recorded bounds. Formal separated memory witness remains open. |
| M5 | Bitmap bytes, alignment and separation from heap/stack | OBSERVED 20248 bytes, corresponding to 2531 words, at 4300406808. Exact bytes and interval disjointness DERIVED; complete `word_list`/memory relation remains open. |
| M6 | Five heap header words bind bitmap start/end, data end, code-buffer start/end | OBSERVED words [4300406808,4300427056,4300427056,4300373588,4300374016]. DERIVED arithmetic matches bitmap/code lengths. Formal witness remains open. |
| M7 | Extra data footprint and uninitialized/unread memory | Header gives DERIVED candidate `data_sp=0`, hence an empty extra-data footprint. The remaining heap/stack contents are UNOBSERVED. The model allows arbitrary values where specified; do not assume zero-filled memory. |
| M8 | Code buffer lies in the program domain, outside data; size arithmetic fits 64 bits | DERIVED candidate buffer 428 bytes at [4300373588,4300374016). Complete domain relation NOT_ESTABLISHED. Its observed mapping is read/execute, not writable. See runtime finding below. |
| M9 | Actual mappings permit modeled instruction fetches, reads and writes | OBSERVED code mapping r-x, bitmap/data rw-, heap/stack rw-. Universal MMU/loader/ISA access correspondence is ASSUMED and requires independent justification. |
| F1 | FFI names/order, entry layout and argument registers | Compiler names PROVED; generated offsets DERIVED. Complete loaded `start_pc_ok`/machine-configuration witness remains open. No candidate-selected oracle is accepted. |
| F2 | Each FFI preserves valid state, aligned return PC, all required callee-saved GPRs and every byte outside the allowed output buffer | NOT_ESTABLISHED universally. `ffi_interfer_ok` quantifies every relevant state and call; finite read/write buffers do not prove the frame condition. See `targetSemScript.sml:317`. |
| F3 | Concrete read/write/close/open calls implement the basis FFI semantics | U289 PROVES four exact modeled equations for observed buffers: read 62 bytes, EOF, EOF, write 64 bytes. C/POSIX/compiler/OS correspondence remains ASSUMED and unreviewed. |
| F4 | Installation implements memmove, returns destination, preserves state and frames | NOT_ESTABLISHED. `install_interfer_ok` remains a universal premise even if no installation was observed. Current code-buffer permissions and runtime build need specific review; see below. |
| F5 | Shared-memory/MMIO entries and ranges match compiled extras | Empty compiled extras PROVED; exact concrete configuration/domain witness NOT_ESTABLISHED. The empty list must be connected to actual entries, indices and `mmio_info`. |
| I1 | Between-step interference preserves the entire projected state | ASSUMED, not proved by stopped-register equality. Projection includes PSTATE, SCTLR, TCR, exceptions, GPRs, program memory and PC. Scheduling, signals, other threads, debugger and external writes must satisfy it; see `asmPropsScript.sml:77`. |
| R1 | `read_limits` equals the theorem's stack/heap limits | U291 PROVES 33554384 stack words and 16777216 heap words under exact recorded register equalities. Physical applicability still requires the complete relation. |
| R2 | `is_safe_for_space` for every pointer-equality oracle | NOT_ESTABLISHED for the concrete process or full input domain. A finite 256 MiB heap/stack observation is insufficient for unbounded strings/integers. See `backendProofScript.sml:2819,5005`. |
| X1 | Modeled successful halt yields complete intended six-field output | U291 only bounds behavior with resource prefixes. The stronger specialization in this packet retains R2 explicitly; no proof of R2 follows from it. |
| X2 | Modeled halt/status maps to actual C `exit(arg)` and OS process completion | OBSERVED native exit 0 in prior fixtures and entry captures. Universal C/libc/OS progress/status correspondence is ASSUMED, not a consequence of the model theorem. See `basis_ffi.c:721`. |
| X3 | Malformed wire input has a complete native rejection/status theorem | NOT_ESTABLISHED. Earlier U274 failures stay preserved. Six malformed fixtures emitted no output and exited 0; those observations do not prove an exception or nonzero-status contract. Canonical rejected refund requests remain distinct from malformed wire input. |
| T1 | Physical CPU/OS transitions refine the published ARM model | ASSUMED, unreviewed. Exact bytes and finite observations do not prove physical ISA, caches, control registers, exceptions or scheduling. No universal hardware proof is claimed. |
| T2 | Proof production is independently reproduced and authenticated | NOT_ESTABLISHED for the complete new chain. Local fresh proofs and exact imports use cached DISK_THM parents. Historical upstream package authentication does not authenticate local proof production. |
| T3 | Exact new claim, toolchain, artifact and environment are admitted under approved policy | NOT_ESTABLISHED. Historical Stage9 signatures cover their historical release. New profile/claim approval, provenance and independent admission remain separate. |
| O1 | Independent backup contains the required archives and restores them exactly | Owner confirmation preserved; exact independent-device hashes and restore are NOT VERIFIED. Local bundles do not discharge this operational requirement. |
| O2 | Effective governance is current and independently reviewed | Latest historical exports remain evidence for their capture time only. No new GitHub inspection, protection change, publication or merge ran in this checkpoint. |

## Runtime installation concern

The observed 428-byte candidate code buffer lies inside the read/execute text
mapping. The recorded runtime compilation has no `-DEVAL` option.
`basis_ffi.c:810–833` calls `memmove`; its permission changes are conditional on
`EVAL`. This does not justify the universal `install_interfer_ok` premise for
the real runtime. No executable was altered and no faulting install was run.
Source/flag inspection plus observed permissions identify an unresolved premise;
they are not a checked physical counterexample or proof of reachability.

The smallest useful next local check is to inspect the published compiler's
existing no-install/reachability results for this exact refund program. A checked
unreachability result could justify an ideal installation relation only outside
reachable executions, with a separate actual/model simulation argument. If that
argument is unavailable, preserve the premise as unsupported. Do not silently
drop it, change permissions, enable EVAL, or retry U290's stopped proof route.

## Proposed assurance boundary; not adopted

Preserve the exact full R1–R5 input domain and complete six-field result. A claim
of modeled complete success must retain the exact installed-state, environment,
resource and configuration premises. A physical claim additionally needs a
justified concrete/model relation and C/OS/ISA progress assumptions. Neither a
false runtime premise nor an unproved resource condition can be called satisfied.

Independent review must cover the source/AST serializer, the shared Dafny/HOL
representation contract, complete dependency closure, physical runtime relation,
resource condition and exact claim/profile. Protected adoption, publication,
signing and admission need their corresponding authorization. This document
grants none. It does not narrow the specification to finite tested fixtures.

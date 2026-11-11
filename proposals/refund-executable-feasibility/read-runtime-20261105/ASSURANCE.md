# Exact refund assurance matrix

CURRENT none. M1 open. `end_to_end=false`. Stage12 unauthorized.
This updates U296 and U310 without rewriting either packet. PROVED means a
checked conditional mathematical claim. TESTED means finite observation or byte
checking. ASSUMED names a required trust boundary, not an approved waiver.
NOT_ESTABLISHED means that required evidence is absent. Multiple labels identify
different parts of a row, not interchangeable levels of assurance.

Exact native SHA256:
`b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`.
The U296 identifiers retain their original meaning. The detailed retained
conditions are in its [matrix](../runtime-premises-20261104/CORRESPONDENCE.md).
The new exact source snapshots and hashes are in `records/source-inspection.json`.

| Claim / prior IDs | Status | Exact evidence and remaining condition |
| --- | --- | --- |
| Approved refund eligibility and six output fields; S1 | PROVED | U262/U267/U271/U294/U295 source/model claims under their own semantics. No financial transfer is claimed. |
| Nine values, Unicode, empty IDs, exact integers, reasons and caller IDs; S2 | PROVED / NOT_ESTABLISHED | U295 shared byte-list contract is checked. Independent cross-kernel interpretation and the external C# serializer remain open. Valid inputs are not restricted. |
| External bytes equal canonical model stdin; S3 | PROVED / TESTED / NOT_ESTABLISHED | Model round trips are proved; recorded byte fixtures are tested. Universal transport/producer relation is not established. |
| `wfcl`; S4 | NOT_ESTABLISHED | Required on the successful source branch. Actual complete command-line witness remains open. It is not added to U310's exception theorem, which does not state it. |
| `wfFS`; S5 | NOT_ESTABLISHED | Physical descriptor/inode/bounds witness remains open. Model assumptions are explicit in fsFFIPropsScript.sml. |
| Infinite/progress choice stream; S6 | ASSUMED | `live_numchars` is not supplied by a finite syscall trace. Its relation to physical availability/progress remains unproved. |
| `STD_streams`; S7 | TESTED / NOT_ESTABLISHED | Finite pipe/file observations exist. Modes, offsets, uniqueness and inode membership need a complete physical witness. Closed/unreadable stdin controls do not satisfy this premise. |
| Initial FFI state and empty events; S8 | PROVED / NOT_ESTABLISHED | U286 concrete modeled initialization is checked. Actual process-to-`(cl,fs)`/oracle relation remains open. |
| Exact CakeML compilation; C1 | PROVED | U275/U291 compiler theorems bind exact code, data and configuration. This run verifies those unchanged artifacts, without recompilation. |
| Complete successful modeled output; C2,X1 | PROVED | U296 `refund_compiled_precise` retains exact installed state, source/environment, limits and universal safe-for-space premises. Earlier resource-prefix claims remain weaker historical results. |
| Complete modeled exception behavior | PROVED | U310 `refund_error_compiled_precise` retains all eight premise groups, outer heap frame, `Fail_exn`, exact complete io_events, replay and consumed stdin. U310 data SHA `6b8a9a3cb7ecf6746d407b22d840f414b2d6d4e2618c8afc87680a6c94f0917f` is unchanged. |
| Static ARM8 configuration; C3 | PROVED / NOT_ESTABLISHED | `is_arm8_machine_config_def` fixes target, ptr/length registers and saved registers only. Connecting it to the physical ABI is open. This corrects U310 report prose, not its theorem. |
| Backend/target config validity; C4 | PROVED / NOT_ESTABLISHED | Published config implications are checked. Actual physical configuration/state applicability remains required. |
| ARM state validity; E1 | TESTED / ASSUMED | Historical PC/CPSR observations exist. EL0, SCTLR E0E/SA0, TCR TBI0/TBI1, NoException and alignment must hold. Some control fields are unobserved; physical-model adequacy is trusted. |
| PC/GPR/program-memory relation; E2 | TESTED / NOT_ESTABLISHED | Historical entry-register snapshots cover finite projections. `target_state_rel` requires all relevant memory bytes and non-avoided registers together. |
| FP/avoided-register clauses; E3 | PROVED | Target has zero FP registers and avoided GPRs18,26,31. This does not discharge ARM validity or physical state correspondence. |
| Loaded entry PC and alignment; E4 | TESTED | U283 historical capture and exact payload match. No fresh successful debugger launch occurred here. |
| Halt/install/FFI entry layout; E5 | NOT_ESTABLISHED | Full `start_pc_ok` includes domain exclusions, address equations, MMIO ordering and entry identities. U290's stopped route stays stopped. |
| Abstract target configured; E6 | PROVED / NOT_ESTABLISHED | Static endian/alignment facts are checked; failed flag, domains, link register and physical witness remain required by `target_configured`. |
| Entry allocation/stack registers; E7 | TESTED | Historical observed values and arithmetic remain evidence for that stopped process. Complete applicability is not inferred. |
| File and loaded code bytes; M1 | TESTED | Fresh file code/bitmap hashes and historical loaded capture match. This is identity evidence, not a universal loader theorem. |
| Complete word/byte memory relation; M2 | NOT_ESTABLISHED | `good_init_state` relates all program memory to abstract words; captured code/header/bitmap regions are incomplete. |
| Memory/shared-domain closure and separation; M3 | NOT_ESTABLISHED | Data subset, byte closure, and program/shared disjointness remain quantified requirements. |
| Heap/stack mapping, alignment, span; M4 | TESTED / NOT_ESTABLISHED | Historical regions and bounds match expected arithmetic. Separated-memory witness remains open. |
| Bitmap identity, alignment, separated footprint; M5 | TESTED / NOT_ESTABLISHED | Exact2531-word payload matches. Complete `word_list` and domain relation remain open. |
| Five heap-header words; M6 | TESTED / NOT_ESTABLISHED | Recorded headers match bitmap/data/code-buffer calculations. Universal initializer state relation is not established physically. |
| Extra data and unread memory; M7 | NOT_ESTABLISHED | Candidate data_sp=0 is supported by header arithmetic. No unsupported zero-fill claim is made for unobserved heap/stack. |
| Code-buffer domain and size; M8 | TESTED / NOT_ESTABLISHED | Recorded428-byte candidate lies in r-x text. Complete domain premise and write applicability remain open. |
| MMU mapping and access refinement; M9 | TESTED / ASSUMED | Historical mapping permissions observed. General load/store/fetch correspondence relies on hardware/OS assumptions. |
| FFI names, entries, argument ABI; F1 | PROVED / TESTED / NOT_ESTABLISHED | Compiler list and exact assembly are bound. Loaded `start_pc_ok` and physical configuration remain incomplete. |
| FFI return-state and complete memory frame; F2 | NOT_ESTABLISHED | `ffi_interfer_ok` under `good_init_state` requires return PC, valid state, saved GPRs and every program-domain byte except permitted output effects. New debugger launches provide no frame capture. |
| Read model success/status/error frame; F3 part | PROVED | Four new exact lemmas, source SHA `2ebad35c506b95ab9a3f209341777514fbd75e679fb0f673e91d32553845fa7a`; data SHA `32d97ebfdd39e761c4b9ea8905a2f6090df23b9c9985dafc2c508b266abaf050`. |
| Native C/libc/OS read, write, open, close refine FFI; F3 remainder | NOT_ESTABLISHED | Exact C/object identity and prior four modeled equations do not prove physical refinement. Ready-model reads exclude some OS errors; error offset and untouched-buffer requirements are open. No new trusted oracle is introduced. |
| Installer transition and reachability; F4 | NOT_ESTABLISHED | `install_interfer_ok` requires memmove effects and a complete frame. Existing runtime lacks EVAL permission changes while code buffer is r-x. No new faulting install or stopped-route retry. Separate U313/U314 initializer work does not remove this premise. |
| Shared-memory entries; F5 | PROVED / NOT_ESTABLISHED | Empty compiled extras are checked. Complete actual entry/domain/MMIO configuration remains required. |
| Between-step interference; I1 | ASSUMED | Scheduling, signals, threads, debugger and external memory changes must preserve the model projection. A stopped snapshot is insufficient. |
| Actual `read_limits`; R1 | PROVED / TESTED / NOT_ESTABLISHED | U291 derives limits from exact recorded-register equalities. Fresh artifact identity is tested. Universal physical initialization relation remains open. |
| Space adequacy for every pointer oracle; R2 | NOT_ESTABLISHED | `is_safe_for_space` includes exact data program, limits, stack-frame sizes and GC condition. No fixed finite allocation guarantees arbitrary unbounded input. Full approved input domain remains unchanged. |
| Logical `Success` to OS exit; X2 | TESTED / NOT_ESTABLISHED | New cases exit0 or SIGPIPE(-13). No universal `Success`→exit0 or OS progress theorem follows. C `exit(arg)` and signals require their own relation. |
| Malformed input and exceptions; X3 | PROVED / TESTED / NOT_ESTABLISHED | U310 closes the modeled error path under its full premises. Native malformed/error controls are finite. Physical decoding, read errors, exceptions, full events and exit correspondence remain open. |
| Clang, assembler, linker and executable binding | TESTED / ASSUMED |2727 prior chain files,311 standard-checksum members, both code/bitmap slices and signatures match. Correct compilation/linking of the C runtime and OS loader semantics remain trusted, not proved by hashes. |
| Physical CPU implements ARM model; T1 | ASSUMED | ISA, caches, system fields, exceptions and scheduling remain part of the environmental trust boundary. |
| Local theorem closure | PROVED / TESTED | Fresh exact import exits0;147 nodes,870 hashed parent files, four Boolean foundations. Kernel/logic and cache provenance are explicit trust dependencies. |
| Independent full-chain replay; T2 | NOT_ESTABLISHED |21 snapshots and pins pass identity checks. Independent clean environment, source acquisition and bootstrap provenance remain unvalidated; execution NOT RUN. |
| Current claim admission; T3 | NOT_ESTABLISHED | Existing ad hoc signatures verify identity only. No release signing, policy adoption or admission authority follows. |
| Independent backup/restore; O1 | NOT_ESTABLISHED | Owner report remains distinct from exact other-device archive hashes and a restore test. No new operational check here. |
| Current governance; O2 | NOT_ESTABLISHED | No fresh protection export or change. Historical exports remain time-scoped evidence. |
| End-to-end native refund correctness | NOT_ESTABLISHED | Physical FFI/runtime/state/resource/source-transport relations and independent full-chain assurance remain incomplete. `end_to_end=false`. |

All eight U310 premise groups remain: installed; read_limits; wfFS; STD_streams;
stdin_content; exact wire error; is_arm8_machine_config; universal safe-for-space.
Its complete heap/event/error conclusion is unchanged. The matrix also preserves
the successful branch's additional source/command-line requirements.

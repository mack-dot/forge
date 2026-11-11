# M1 software assurance matrix — U328

CURRENT none. M1 PARTIAL. Stage12 unauthorized. `end_to_end=false`.
This matrix applies the owner's software boundary. Silicon verification is
outside scope. ASSUMED entries do not discharge unrelated software premises.

| Requirement | Classification | Exact evidence or remaining premise |
| --- | --- | --- |
| HOL logic/kernel and four Boolean foundations | ASSUMED | Explicit owner trust boundary. U327 closure lists SELECT_AX, INFINITY_AX, ETA_AX, BOOL_CASES_AX. No new axioms. |
| Physical CPU implements ARM64 ISA | ASSUMED | Explicit owner boundary; no chip-level proof or attestation claimed. |
| OS implements the documented syscalls | ASSUMED | Explicit owner boundary. It permits errors; it is not a guarantee that reads succeed. Exact supported OS profile remains to be bound. |
| Basis read is independent of ext | PROVED | New basis_read_ignores_ext; arbitrary ext and ext' give the same read result. |
| Complete replay rejects guarded status1 read events | PROVED | New stdin_error_complete_trace_rejected retains replayed prefix,all byte pairs and arbitrary suffix; extract_fs returns NONE. Data SHA256 60261ea96a993d62c971769d642c9ab1b9dbc558ccd31f41d9e4e3ef00202357. |
| U328 statements,closure and mutations | TESTED | Proof/repeat/import0/0/0; four identical exports;217 nodes,1287 closure files,2668 input bindings; wrong-result and omitted-event controls1/1. Same-host caches,not independent replay. |
| Generic FFI TextIO read-error theorem | NOT_ESTABLISHED | Candidate unchanged; cfLib loading exits1 in helperLib/numLib.DECIDE before any theorem. No errno captured; historical EPERM causation unproved. |
| Original refund contract, Unicode, empty IDs, exact amounts, reasons, caller IDs | PROVED | Existing source/model results including U262 commit73728c2 are reused at their existing scope. Physical byte transport is a separate open requirement. |
| Initialized modeled exception semantics and complete events | PROVED | U286 and U310 `refund_error_compiled_precise`; all eight premise groups, heap frame, Fail_exn, full events, consumed-stdin replay retained. U310 data SHA256 `6b8a9a3cb7ecf6746d407b22d840f414b2d6d4e2618c8afc87680a6c94f0917f`. |
| CakeML ARM8 compiler composition | PROVED | Existing U310 conditional theorem. Does not prove that the OS/native runtime satisfies its premises. |
| Well-formed standard stdin supplies read inputs | PROVED | New `wf_read_inputs` and `stdin_read_inputs`. |
| Guarded modeled stdin read is total and returns status0 | PROVED | New `stdin_ffi_read_total` and `stdin_ffi_read_status_zero`. Final data SHA256 `3192e34a57ac581727a3ce8c56770e7354242577d35bc4229903fe28020e671d`. |
| U327 exact statements, dependencies and exports | TESTED | Fresh proof/repeat/import0/0/0; four identical exports;148 theory nodes;876 parent files;2665 input bindings. Same-host cached parents remain trusted pending independent replay. |
| Wrong status and dropped descriptor guard rejected | TESTED | Exact-claim controls1/1. These check statement binding, not a universal proof that the changed claims are false. |
| Native empty-pipe EAGAIN versus EOF | TESTED | New libc observations-1/errno35 and0/errno0.16-byte buffer unchanged. Two exact executable runs exit0 with empty streams. Child syscalls were not traced. |
| Native read errors correspond to the current complete event model | NOT_ESTABLISHED | Status-zero and complete-replay rejection theorems expose the domain mismatch. ext cannot override read. No no-error assumption is accepted. |
| Native successful/partial reads and EOF correspond universally | NOT_ESTABLISHED | Model U315 formulas are proved. Actual buffer, offsets, counts, lifetimes and event relation remain open. |
| Native stdin decoding and stdout encoding/effects | NOT_ESTABLISHED | Existing wire proofs and finite28-case runs do not establish universal physical transport or write effects. |
| Native memory safety, heap relation, initialization and exception frame | NOT_ESTABLISHED | Existing model initialization/heap results remain conditional. Physical allocation, C runtime operations, aliasing, stack/return frame and syscall effects require correspondence. |
| Installation and resource premises | NOT_ESTABLISHED | `installed`, read_limits and universal is_safe_for_space remain explicit. CPU/memory limits used for proof jobs do not discharge these native program premises. |
| Assembly/runtime/linker/executable identity | TESTED | Prior identity evidence reused; current native SHA256 `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` matches. Hash equality is not linking correctness. |
| Linking, loader and dynamic library semantic correspondence | NOT_ESTABLISHED | Exact mapped sections, relocations, ABI, runtime objects and entry state still need their software argument. No blanket trust grant inferred. |
| Existing signatures and two native builds | TESTED | U326/prior verified signature and byte-identity records reused. No new signing. Authentication does not prove behavior. |
| Logical Success equals native OS exit0 | NOT_ESTABLISHED | No equivalence inferred. New controls deliberately exhibit identical exit0 observations for different read outcomes. |
| Independently controlled21-snapshot source replay | NOT_ESTABLISHED | Frozen snapshots preserved; independent environment/provenance not validated for execution; no replay run. |
| End-to-end software correctness for exact native executable | NOT_ESTABLISHED | Runtime/FFI relation, physical premises and independent full-chain assurance remain open. |

The new result uses no stronger environmental assumption and changes none of
the original theorem statements. U327 entries below are reused historical results. See [REPORT.md](REPORT.md) for current actual exits,
source references and limits, and [NEXT-STEP.md](NEXT-STEP.md) for the precise
unresolved domain check. The earlier environment blocker is not presented as
the cause of this new proof finding.

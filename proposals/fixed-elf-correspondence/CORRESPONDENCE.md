# Exact executable correspondence

CURRENT none. Stage12 unauthorized. `end_to_end=false`.
ELF: `8ced2ab6c7160338899056fe51bacb23d86d81705eacfdd1e992cf5252bdaeb6`.
This document supplements U229–U253 and the earlier84-condition inventory.
It does not replace any original failure or observation.

## Four distinct claims

**A — Model theorem.** For the exact generated image and observed register
initializer, arbitrary data memory, reservation and FCSR, and any typed Model
with `m_halted=None` and `m_vm_lazy=[]`, the existing LPS semantics compute the
fixed GCD result and must terminate normally with status0. The new ExitBridge
also derives an LPS trace ending in `ExitEv 0 fs` and a halted Model. All original
premises remain. This is a model statement, not a QEMU theorem.

**B — Concrete observation.** A fresh run of the held ELF under the pinned
QEMU/GDB environment records the same459-line trace as the prior debug run,
matching404 file-backed LOAD bytes, guest exit0 and parent-observed QEMU exit0.
The observer did not terminate QEMU. The data are finite measurements.

**C — Correspondence.** Existing kernel-checked projection and process-prefix
lemmas provide a finite LPS execution whose PC/GPR/FPR values match the recorded
21 pre-instruction frames. Model data-access reports are empty on that prefix.
This supports a finite projected-trace embedding, conditional on faithful
capture and the exact image binding. Full concrete machine/OS-state refinement
is NOT_ESTABLISHED. In particular, no captured physical field is the LPS lazy
allocation ledger. An arbitrary chosen Model is not evidence of its physical
applicability.

**D — Runtime behavior.** The recorded run exited0. Its intermediate register
value21 agrees with the model's fixed GCD computation. Transferring the universal
model termination theorem to all admissible physical executions additionally
requires reviewed entry abstraction, instruction/exit fidelity, noninterference
and progress assumptions. These are not kernel-proved physical facts.

## Evidence key

- B: `rebuild/Behavior.v`, unchanged source5a230c7e; exact source/object hashes in
  `reproduction.json`. Fixed inputs1071/462; result21.
- E: `bridge/ExitBridge.v`; exact source/object hashes in `bridge-reproduction.json`.
- P: prior `runtime-process-prefix-2026-11-03/attempt-0002/positive/ProcessPrefix.v`.
- O: prior `campaign-runtime-projection-2026-11-02/transition-hidden-fields/ObservedTransitions.v`.
- A: prior `runtime-access-batch-2026-11-03/attempt-0002/trial/AllAccesses.v`.
- N: current `baseline/capture/`, exact argv in `observation-commands.json`.
- H: N/held-elf-headers.stdout; N/instruction-trace.log; N/debugger.stdout.
- Q: authenticated source under `qemu-source-assumption-audit-2026-11-03/attempt-0002/extracted/qemu-source/`.
- R: pinned LPS source in `fixed-elf-assumption-matrix-2026-11-03/attempt-0001/published-source/`.
- K: current `kernel-output/`; its terminal result determines full replay status.
- S: historical Stage9 signed release at source624c9faf, lock5f78da21; previous
  turn's real consumer/Cosign controls in `vertical-slice-audit-2026-11-03/attempt-0001/`.

PROVED means a statement checked in the formal system under its listed trust
base. OBSERVED identifies a producer measurement. DERIVED identifies a stated
inference from those records. ASSUMED is an explicit trust condition, not a pass.
UNOBSERVED means no measurement was obtained. NOT_ESTABLISHED means the required
relation or authority is absent. Multiple labels identify different assertions.

## Correspondence matrix

| Field or boundary | Classification | Exact support and remaining obligation |
| --- | --- | --- |
| Held ELF identity | OBSERVED |1240 bytes; approved digest above checked before/after execution. SHA256 and expected-anchor authenticity remain ASSUMED. |
| Model image identity | PROVED / ASSUMED |Exact Program module is in K's held closure. The original loader/read-file image binding remains a declared TCB component. |
| File-backed LOAD bytes | OBSERVED |N compares344 bytes at10000 and60 bytes at11158 with independently held ELF slices, cmp0/0. |
| Instruction fetches | PROVED / OBSERVED |O checks13 distinct words at21 PCs using published fetch/step functions. N reproduces the corresponding raw trace exactly. Actual fetch/capture fidelity remains ASSUMED. |
| Initial PC | OBSERVED / PROVED |GDB and trace11158; O establishes generated image entry11158. |
| Initial GPRs | OBSERVED / PROVED |All32 logged values match O's initializer; x0=0, x2=2aaaab2abc30, other GPRs0. Faithful register reporting is ASSUMED. |
| Initial FPRs | OBSERVED / PROVED |All32 raw register values0 match O. Floating-point behavior outside this integer path is not claimed. |
| Stack pointer | OBSERVED / DERIVED |2aaaab2abc30; alignment modulo16 is0. It is below the historical Sv48 valid-entry lower bound7fff80000000. |
| Applicability of original Stage7 entry | NOT_ESTABLISHED |The observed SP violates that theorem's valid-entry condition. Its proof remains valid in its stated domain. |
| Applicability of new SP condition | PROVED / OBSERVED |PR37 quantifies sp; B uses the exact observed sp. This does not discharge the other state/environment relations. |
| Mapping permissions | OBSERVED |QEMU page log reports RO10000–11000, RX11000–12000, stack guard/RW and extra RX vDSO page. Logger correctness and permission enforcement remain ASSUMED. |
| Full mapping/permission refinement | NOT_ESTABLISHED |No complete guest page-table/host memory model equivalence proof. File-backed identity alone does not imply every mapping property. |
| Initialized data | OBSERVED / PROVED |Two LOAD segments have equal file/memory sizes; their404 bytes match. B quantifies arbitrary data memory. No general loader initialization proof. |
| BSS/uninitialized data | DERIVED / UNOBSERVED |This ELF has no extra LOAD BSS tail. Other guest memory is not fully captured; it remains arbitrary in the proof. |
| Guest architectural data reads/writes | PROVED / ASSUMED |A establishes empty data-access reports for all21 modeled instructions. Transfer to actual guest accesses depends on instruction fidelity. QEMU's internal host loads are not guest architectural accesses. |
| Unread memory, stack contents | PROVED / UNOBSERVED |Model behavior is independent of arbitrary data memory. Concrete stack/heap bytes need not equal one invented snapshot; full memory equality is not claimed. |
| ROM function outside used fetches | NOT_ESTABLISHED |Held LOAD bytes and used instruction words are bound. A complete physical-to-total-ROM-function relation is not measured. |
| Reservation state | UNOBSERVED / PROVED |Physical value unobserved. B quantifies any reservation value, so this result does not require reconstructing it. |
| FCSR | OBSERVED / PROVED |New GDB run reports0. B quantifies any FCSR; the result does not depend on this observation. Earlier run's hidden value remains unknown. |
| Initial pending syscall | PROVED / ASSUMED |O initializes None and P proves None before each instruction. Mapping an entry-stop QEMU state to that logical field requires a reviewed entry abstraction. |
| Model halted=None | PROVED / DERIVED |Existing initializer witness supplies the formal premise. A live stopped guest is consistent with running state. The concrete-to-Model interpretation remains ASSUMED. |
| Model lazy=[] | PROVED / NOT_ESTABLISHED |Existing initializer witness supplies the formal premise. This is a sparse allocation-accounting ledger, not physical demand paging; no direct physical equality was observed. |
| Other Model components | PROVED / NOT_ESTABLISHED |Typed fields are universally quantified; A preserves Model on the prefix. Universality is not proof that an arbitrary physical OS is represented by those types and relations. |
| argv/env/rnd/uid/hw | PROVED / UNOBSERVED |B quantifies these parameters; relevant behavior is independent of them after arbitrary memory substitution. Their full physical representation is not captured or asserted equal. |
| Control-flow and register transitions | PROVED / OBSERVED |O's21-state equality and P's existing sstep_cfg/star_cfg composition; N gives the same finite projected trace. This is not a universal QEMU simulation theorem. |
| Arithmetic input/result | PROVED / OBSERVED |B proves1071/462 →462/147 →147/21 →21/0. After15 modeled instructions, a0=Z.gcd1071 462=21; matching N frame atPC11174. |
| External result | OBSERVED / DERIVED |21 is an intermediate register value, not stdout or persistent memory output. a0 is later overwritten with status0 before the syscall. |
| ecall instruction | PROVED / OBSERVED |Final pre-instruction PC1118c, word73; a7=94 and a0=0. Reaching it differs from executing a process exit. |
| Modeled syscall request | PROVED |O proves pendingSome94 and argument0 after21 CPU steps. Raw run_steps alone does not dispatch the syscall. |
| Modeled exit transition | PROVED |E uses published must_exit_at_cfg_realizes to obtain ExitEv0 and haltedSome0; the universal must-exit conclusion is retained separately. |
| QEMU syscall dispatch | DERIVED / ASSUMED |Q/linux-user/riscv/cpu_loop.c:48–60 reads a7 for non-RVE ELF flags4 and a0 for status. syscall.c:11065–11067 calls host exit_group. Source inspection is not source-to-binary or OS refinement. |
| GDB guest exit notification | OBSERVED / DERIVED |$_exitcode0. Q/linux-user/exit.c:35 calls gdb_exit during cleanup, before the host syscall. This observation alone cannot establish host termination. |
| Actual process termination | OBSERVED |Python parent wait records QEMU return0 and terminated_by_observer=false. This adds host normal-exit evidence, subject to Python/Linux/host fidelity. |
| Linux honoring exit_group | ASSUMED |Source call and measured normal exit support the finite result. No formal Linux implementation refinement or general liveness proof. |
| External interference | ASSUMED / OBSERVED |Readonly isolated baseline limits exposure. New GDB control changes a2 from21 to22; guest exits2 and observer rejects1. No claim survives arbitrary state mutation. |
| Scheduling/progress | ASSUMED |The finite run completed. Universal physical termination additionally requires continued scheduling and no out-of-model kill, hang, debugger stop, host failure or adversarial intervention. |
| QEMU/GDB producer identity | OBSERVED / ASSUMED |Existing Ubuntu repository-signature/package chain passes;413 observer members match before/after. Authenticity is distinct from implementation correctness. |
| Runtime/host stack | OBSERVED / ASSUMED |Pinned amd64 checker container; Docker28.5.1 on arm64 Linux6.10.14-linuxkit. The host's amd64 execution/translation layer is not formally verified or newly pinned by this observation. |
| vDSO | OBSERVED / NOT_ESTABLISHED |Auxv identifies page2aaaab2ac000; it is outside the used path. Preserve GDB/readelf diagnostics. No full-vDSO validity or behavior claim. |
| New theorem provenance/admission | NOT_ESTABLISHED |S authenticates only the old release. New exact claim/profile, producer binding, signature and independent admission remain unapproved/unexecuted. |

## Narrow relation and minimum conditions

Let pi be O.project_registers and s(k) the states produced by the existing LPS
run_steps from O.observed_initial_machine. For this finite record define
R(k,c,s) to mean: the trusted observation of concrete state c has pi(s), the
instruction at its PC equals the held image word, and the relevant LOAD-byte
binding is intact. This defines a relation over observations; it introduces no
machine semantics, ISA decoder or new verifier.

O proves the recorded projections equal pi(s(k)) for k=0..20. P proves the same
modeled states compose through the published process relation. A proves no
modeled guest data accesses. E supplies the modeled terminal event. N supplies
the actual finite observations and parent exit. Together these justify a finite
projected embedding under faithful observation and artifact identity. They do
not prove that every concrete successor preserves R, that the concrete terminal
step refines the model, or that hidden OS state equals Model.

The smallest sufficient conditional transfer also needs: (1) an approved entry
abstraction supplying the remaining logical pending/Model premises; (2) fidelity
of only the used instruction path and instruction capture; (3) preserved image
and relevant registers/no interference; (4) correct syscall94/status0 handling
and parent exit observation; (5) progress for any universal physical termination
claim. These assumptions are narrower than universal QEMU correctness. Their
review is still required. They cannot be converted into PROVED labels by a hash.

Direct applicability of PR37's canonical initializer is still incomplete: its
reservation=None field is not measured. The separately checked B theorem
quantifies the reservation and FCSR and supplies the required behavioral
consequence without that physical-value premise. This is an explicit stronger
model argument, not an edit to PR37 or an invented observation. B still requires
its complete observable initializer and the two Model premises.

Choosing init_model gives a valid formal witness with halted=None and lazy=[].
It does not by itself prove a physical state relation. A reviewed abstraction
may hide irrelevant OS fields because this path has no guest data accesses or
allocation syscalls. Its preservation and exit meaning must remain explicit
obligations. Merely choosing the witness must never count as having observed
the Linux kernel's state.

## Functional statement and limits

The result is the value of register x10/a0 after15 instructions, before the
success/failure status is selected. B.loop_result_is_fixed_pair_gcd relates that
value to the standard Rocq Z.gcd on fixed1071 and462. B.fixed_pair_gcd computes21.
The exact image, canonical initial GPR/FPR/PC/SP and arbitrary hidden/data state
are explicit in B. It does not prove arbitrary-input GCD, source-level C safety,
compiler correctness, emitted output21, or stateful service correctness.

## Remaining trust assumptions

Retain the exact13 direct and86 full-closure primitive names, Rocq/kernel/runtime
soundness, the published loader/image binding, held expected-digest authenticity
and SHA256 collision resistance. Retain QEMU instruction/loader/logger/GDB
fidelity, source-to-distribution-binary trust, Linux syscall/wait fidelity,
Docker/VM/host translation and hardware trust, isolation, and required progress.
Distribution signatures authenticate producer bytes; they do not prove these
behaviors. No new axiom is introduced into the Rocq development.

The strongest current overall verdict is PARTIALLY_ESTABLISHED. The modeled
behavior and finite observations have a reproducible correspondence argument.
Full executable-level accepted assurance remains NOT_ESTABLISHED pending the
reviewed conditional contract and new
authenticated runtime/admission binding. Strict operational integration is a
separate status; backup validation cannot substitute for these mathematical gaps.

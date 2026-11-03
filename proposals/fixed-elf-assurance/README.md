# Proposed fixed-ELF memory-independent termination claim

**Proposal only. Not an approved specification or admission profile.**
Stage 12 remains unauthorized. `end_to_end=false`.

## Exact intent decision

For the exact 1,240-byte ELF with SHA-256
`8ced2ab6c7160338899056fe51bacb23d86d81705eacfdd1e992cf5252bdaeb6`, approve or
reject the additional mathematical claim in **MemoryIndependent.v**:

For every stack pointer and other initializer parameter, for arbitrary data
memory, and for any unhalted LPS model with no lazy mappings, the fixed program
started with the stated register/FP initializer must terminate normally with
exit status 0 under `may_fail_cfg`.

Exact source SHA-256:
`ffe5a677e14b5d426196b3c8e56c821f4775037855b63c2a902c2f253c7cebfc`.
This removes native `valid_entry`/`valid_input` restrictions from an additional
abstract-model claim. It does not change the existing accepted theorem, assert
arbitrary-input GCD correctness, or prove QEMU correct.

## Actually executed

| Check | Actual exit | Scope |
| --- | --- | --- |
| Proposed theorem compilation |0|Real pinned Rocq 9.2 |
| Published binding-wrapper compilation/audit |0|13 permitted primitive assumptions |
| Full independent `rocqchk` |0|569 modules; 86 permitted closure assumptions |
| Kernel/container postflight |0|No OOM; source/object hashes unchanged |
| Fresh separate-process source and wrapper rebuild |0/0|Both .vo objects byte-identical |
| Actual QEMU ELF execution |0|Same exact ELF bytes;21 instruction frames |
| Full observed PC/GPR/FPR transition comparison |0|Published LPS `run_steps`, for arbitrary data/reservation/FCSR |
| Independent observation-module kernel check |0|567 modules;86 permitted closure assumptions |
| Instruction-word / intermediate-register tampering |1/1|Expected Rocq equality failures |
| Corrupted / valid weaker proof-object identity guards |1/1|Expected held-anchor refusals before kernel launch |

`Wrapper.v` uses the unchanged published binding template. `proof-context.json`
contains exact recursive dependencies, object hashes, actual assumptions and
kernel command. `kernel-check.log.xz` is the real raw independent-check log.
`rebuild-check.json` records a fresh compilation in empty output directories.
The published checker and allowlist remain unchanged; all 569 loaded objects come
from the historical authenticated pool or the two exactly hashed new objects.
No imported dependency was admitted or skipped.

The full kernel check took 1599.281 seconds including container orchestration.
These are local Docker/amd64-emulation measurements, not native-host benchmarks,
GitHub job-minutes or savings. Per-run timing records are separate from proof bytes.

## Actual execution and its limits

The pinned Ubuntu QEMU 8.2.2 executable hash is
`be89e201dc6112ef101617ab575c95119ad123f80ca2b51b6c36ef218ac9df65`.
Its package chain was checked against signed Ubuntu metadata. Help confirmed
`-one-insn-per-tb` and the used logging flags. `observed-execution.log.xz` records
readonly header and RX code mappings, PC 0x11158,21 instruction frames and
`exit_group(0)`. The source ELF and loaded private copy have the expected hash.

`ObservedTransitions.v` asks the existing LPS `run_steps` to compute all21
preinstruction PC/32GPR/32FPR snapshots. Rocq accepted the equality and rejected a
single changed intermediate register. It quantifies arbitrary data memory,
reservation and FCSR values. These hidden values were not observed; their values
are not prerequisites for this projected finite equality. The modeled step 21
pending syscall 94/argument0 is model computation, not an observed post-ecall frame.

This is **finite projected observation conformance**. It is not a universal
QEMU/ISA refinement theorem, complete physical-state abstraction, permission/
loader proof or whole-service guarantee. QEMU reporting/fidelity, system-call
behavior, host OS/hardware, published model/ELF-loader fidelity and absence of
outside interference remain explicit trust boundaries. The observation object also passed a separate full `rocqchk`:567 actual modules
and86 permitted closure assumptions. This checks the finite model equality in
ObservedTransitions.v. Its kernel check did not use a typed claim-binding wrapper.
The full569-module check above covers the separate termination claim.

The old public theorem's native SP premise is still false for this observation:
SP 0x2aaaab2abc30 is below 0x7fff80000000. This proposal never marks it valid.
The memory-independent proposition instead states a distinct abstract property.

A separate arbitrary-initial-register experiment exhausted the unchanged 4 GiB
limit and exited 137/OOM. Its result is NOT_ESTABLISHED and is preserved locally.
No budget was raised. The claim in this packet was compiled before that
experiment and retains its original defined-register initializer.

## Provenance and reproduction inputs

The existing signed producer artifact is available from GitHub run 40966460258,
artifact 12939158560, at historical source 624c9faf… . ZIP SHA-256:
`8ded75a093cb5d9c1e24f240c4209279b363e4d5fc3338a73a20b086c984cfb4`.
A fresh download matched that authenticated API digest and the previous ZIP.
All 881 extracted file members matched the held signed bundle. Fresh unchanged
historical TUF/Cosign/full-consumer verification passed before and after eleven
adversarial mutations. Those mutations rejected with exact intended reasons.

The old signature authenticates the old ELF/evidence/package, **not this new
statement or a new runtime package**. The research execution ran a private exact-
byte copy in the checker image. It is not a new admitted deployment of the old
signed container. No consumed release request was reused.

Use the existing checker image:
`ghcr.io/theorem-labs/oss-fuzz-theorems-checker@sha256:cc9ae43a9f4b0dd59d7c8d30727d36e039bfe72a2a9f9c4a99c68e413037e902`.
The historical archive's `proof/dependencies/work` mounts readonly at `/work`.
Place MemoryIndependent.v at `/trial/MemoryIndependent.v`, and Wrapper.v at
`/binding/Wrapper.v`, in separate fresh writable output directories. Compile with
virtual load paths shown in the recorded kernel command, then execute that exact
`rocqchk` command. Preserve UID/GID 1000, CPU 0, memory/swap 4g, pids 512, stack=-1,
readonly roots/inputs, no network and a private writable log directory.

`environment-inputs.json` lists the pinned upstream source, exact audit-tool/
allowlist and Python package inputs used with unchanged `oft.check._rocqchk`.
These are existing Stage7 dependencies, not a new framework. Obtain them through
the existing recorded Stage7 setup. The raw virtual kernel command is tested;
commands with `<...>` host-path placeholders in observation-checks are documented
adaptations of actual calls, not a claim of fresh-host execution. No independent
third-party physical-host reproduction is claimed.

## PR and authority boundary

This packet adds proposed proof and research evidence only. It activates no gate,
workflow, schema, receipt reuse, admission or deployment. Main remains unchanged.
Existing green ledger checks would not certify this additional proposal.

An intent approval permits preparation of the exact protected evidence/profile
change. Publication, independent exact-head review, merge, workflow execution,
signing and deployment retain their corresponding authorization boundaries.
The existing policy must refuse an unsupported new claim; do not alter it merely
to obtain a passing result. Do not promote this packet to `end_to_end=true`.

Original archive backup remains unconfirmed. GitHub storage of this one signed
bundle is not backup of the raw/sanitized archive pair or later local evidence.
Current GitHub rules require review but lack required status checks. No protection
was changed. Packaging PR 36 remains a separate independent-review boundary.

Raw QEMU and kernel logs are stored with lossless XZ compression. Decompressed
bytes retain the original output, including trailing spaces. No log was edited.


## Completed observation check and object-integrity controls

This revision includes observation-kernel.log.xz and observation-kernel-context.json.
The exact observation source/object identities, actual567-member closure and86
assumptions, permitted580-object pool, unchanged audit inputs and fresh byte-
identical rebuild are recorded there. Context operational durations are separate
from proof identity. The compressed log preserves every original byte.

object-integrity-controls.tar.xz retains the original positive object, held
expectation and unchanged driver, both hostile fixtures, raw logs and exact
commands. One fixture changes one object byte. The second compiles a valid20-
state proposition under the same module/lemma names as the required21-state
proposition. Both guards exit1 at exactly DEPENDENCY_BYTES:/observed/ObservedTransitions.vo;
neither starts the kernel. These are identity refusals, not semantic kernel
rejections. The weaker proposition is compiler-valid but has a different identity.

The corrupted fixture's inherited compiled-candidate flag describes its ancestor;
its mutated bytes were not compiler-produced. The archive retains the raw flag
and explicit correction. A second correction identifies unused inherited wrapper/
baseline lists in the positive driver inputs. Actual closure and assumption
outputs determine the positive result. No wrapper check is claimed for that root.

The held expectation is outside candidate mounts. This does not authenticate an
expectation supplied together with an untrusted candidate, establish durable
provenance for the new claim or resist rewriting candidate and anchor together.
The original receipt corruption regression remains in the existing main gate
suite; these additional compiled-object controls do not replace it.

The current trusted incremental gate classifies the original proposal snapshot
as UNSUPPORTED(exit3), with11 uncovered proposal paths and no evidence written.
The expanded data packet also requires a separate coverage check before
publication. No gate/registry exception is introduced. This is a draft proposal
for independent review, not a claim that existing CI admits the new theorem.
The existing ordinary PR workflow may run automatically on publication; no manual
workflow dispatch, profile activation or merge is authorized by publication.

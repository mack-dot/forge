# Proposed fixed-ELF observation supplement

Status: local experiment preparation. Not an approved verification profile.
CURRENT none. Stage 12 unauthorized. `end_to_end=false`.

Problem: the recorded QEMU CPU log omits FCSR, reservation state and a complete
live image read-back. The accepted checker image contains no GDB. The original
termination theorem and its two Model premises stay unchanged.

Use the established GDB remote protocol and a version-pinned Ubuntu
`gdb-multiarch` package, acquired through the same authenticated APT mechanism
used for QEMU. Download and unpack packages only. Use an ephemeral container
with no external network, UID1000 and fixed resource limits for observation.
Do not add a service, a decoder, a verification framework or a policy exception.

Before execution, freeze the exact package/dependency digests. Run the exact
held ELF and pinned QEMU binary. Disable GDB user initialization, target
auto-loading and debuginfod. A debugger connection must stay on container
loopback. Preserve command output and failures. No signing/admission occurs.

Local acceptance criteria:

- The observer reports the ELF's actual entry PC and all available entry
  registers, including FCSR when the target exposes it.
- The observer reads both complete file-backed LOAD ranges. Their bytes match
  the independently held ELF through established binutils/file operations.
- Auxiliary-vector information identifies the RX page only if the target
  actually provides it; otherwise keep the identity unresolved.
- Continue the unmodified ELF and record both QEMU and debugger exit outcomes.
- Corrupting a captured byte must fail the held-image identity comparison.
- Missing registers or unsupported operations remain explicit. In particular,
  architectural GDB registers do not automatically expose QEMU's LR/SC
  reservation ledger or the LPS Model's sparse-allocation ledger.

This is a new observed run. It cannot establish unrecorded hidden values in the
old run. It does not prove QEMU/Linux fidelity, source-to-binary compilation,
universal refinement, complete physical-state equality or whole-executable
correctness. GDB and the runtime remain trusted observers, not proof kernels.

Exact commands, package pins and results belong under
`results/fixed-elf-observer-2026-11-03/`. The local experiment is authorized
readiness work. Publication, any adoption as authoritative evidence, protected
toolchain/profile changes, independent review, signing and admission retain
their separate authorization boundaries. No accepted file is changed here.

## Frozen local pins and actual results

- GDB package: `15.1-1ubuntu1~24.04.1`; executable SHA256:
  `0baeb299d3aa39f40ca72c3cb8ae5b15a5bd01f1995583a52cfdd7527bfffe07`.
- The authenticated package/dependency manifest is
  `results/fixed-elf-observer-2026-11-03/attempt-0001/packages/observer-packages.json`.
  Thirteen packages were downloaded and unpacked. No package install or
  maintainer script ran. The accepted checker image was not changed.
- Current local capture: attempt0003. QEMU0/GDB0; both complete LOAD ranges
  match the held ELF; corrupt capture cmp1. All9 exact-marker controls pass.
- The original metadata prefix checks could accept a nonzero FCSR or a PC
  suffix. The counterexample, original source and first result are preserved.
  Current checks require exactly one complete field with the expected value.
- Auxv identifies the new run's vDSO page. GDB string-table and readelf dynamic-
  section diagnostics remain unresolved as full file/validity checks. A zero
  readelf exit is not used as a proof of vDSO correctness.
- Reservation, sparse-allocation ledger, runtime refinement and old hidden
  state remain unestablished. No theorem, acceptance policy or profile changed.

## Complete observer-content check

The first version probe ran with a writable unpacked package tree. It created22
Python bytecode caches. The strict comparison against a fresh authenticated
package extraction rejected those extra files, even though the GDB executable
hash still matched. The failed tree and check remain preserved.

Current execution uses a fresh authenticated package tree mounted read-only,
with `PYTHONDONTWRITEBYTECODE=1`. The unchanged strict producer matcher passes:
two Ubuntu repository signatures, four signed binary-index digests, all13
package archives, and all413 file/symlink members. The post-execution comparison
also passes with no extra cache files. No expected member was excluded and no
old cache/evidence was deleted to obtain this result.

This authenticates distribution content under the stated Ubuntu-key trust. It
does not prove debugger correctness or authenticate a new verification claim.
Observer output still needs the required trusted-producer/profile approval
before authoritative use. Generic proof-receipt reuse remains disabled.

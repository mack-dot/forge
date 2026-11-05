# Refund captured FFI calls checked in HOL — U289

CURRENT stage: **none**. M1 remains open. Stage 12 is unauthorized.
Integration EXIT: **NOT_ESTABLISHED**. `end_to_end=false`.

Four kernel-checked equations now connect the complete captured call buffers to
the existing CakeML basis FFI model for one recorded refund request. A fresh
rebuild reproduces all four exported files. A separate standard-heap import
checks the exact statements and their dependency closure. Both altered-evidence
controls are rejected at the required equation, with residual goal `F`.

This is finite model conformance, not universal C/POSIX refinement or a complete
refund executable theorem. The separate compiler behavior proof remains live.
The prior goal turn made tracking progress. This turn completes a real proof,
its adversarial controls, reproduction and fresh import.

## Commands and actual exits

Let `R=results/refund-ffi-observation-2026-11-04` in the owner workspace.
Exact argv, sources, tool/heap hashes, outputs and command records are in
`records/`. The prior observation and diagnostic packets remain unchanged.

| Command/check | Actual exit | Result |
| --- | --- | --- |
| `python3 -B $R/run_model_check.py positive-0002` | 1 | Three read equations pass; write proof leaves the tail-drop identity unresolved |
| Constructor controls `altered-read-byte-0003` / `wrong-write-descriptor-0003` | 1 / 1 | Intended false equations; no complete export |
| `python3 -B $R/run_model_check.py positive-0004` | 0 | All four unchanged equations proved and exported |
| `python3 -B $R/run_model_check.py altered-read-byte-0004` | 1 | Altered read response fails `observed_ffi_0`; residual `F` |
| `python3 -B $R/run_model_check.py wrong-write-descriptor-0004` | 1 | Three correct read equations pass; wrong write fd fails `observed_ffi_3`; residual `F` |
| `python3 -B $R/run_model_check.py repeat` | 0 | Identical source; four byte-identical exported files |
| `python3 -B $R/import_model_audit.py` | 0 | Exact four statements, zero explicit hypotheses/tagged axioms; only `DISK_THM` tags |
| `python3 -B $R/readback_model_complete.py` | 1 | File inventory expected a separate data file for built-in `min`; failure preserved |
| `python3 -B $R/readback_model_complete_0002.py` | 0 | Explicit kernel root; 215 closure nodes and 1068 file identities; 24 captured buffers match |
| Protected-input and process readback | 0 | 50 protected paths and mission unchanged; original compiler job remains live |
| Original compiler behavior invocation | IN_PROGRESS | Runner47209/Holmake47239; no terminal conclusion at this checkpoint |

The existing `positive-0003` draft was not run. The suffixes identify preserved
preparations, not four executed positive attempts. The first syntax failure is
retained in the [U285 packet](../ffi-observation-20261104/REPORT.md). Constructor
diagnostics and the guard that prevented interruption are in the
[U287 checkpoint](../ffi-model-checkpoint-20261104/REPORT.md).

The second positive run terminated on its own with exit1. Its residual was
`THE (LDROP 1 (4096:::ns)) = ns`. HOL marks the `LDROP` definition `nocompute`.
The existing `llistTheory.LDROP_1` proves the needed identity. The final write
tactic adds that simplification. No expected equation, captured byte, model
definition, theorem premise or acceptance rule changes. The typed constructor
path reconstructs every original equation exactly. All failures stay visible.

The first file audit incorrectly required a `minTheory.dat`. HOL's existing
kernel installs `min` as its parentless root. The corrected inventory records
the root, kernel source hashes and standard heap explicitly. Every other closure
node still requires its data, signature and source files. No proof was rerun or
weakened to fix the inventory.

## Exact claim and identities

The theory is `forge_refundObservedFFITheory`. Its four exported theorems are
`observed_ffi_0`, `observed_ffi_1`, `observed_ffi_2`, and `observed_ffi_3`.
Each theorem has the form below, with the complete literal arrays and filesystem
values retained in [the checked source](records/model-positive-0004/check.sml):

```text
basis_ffi_oracle no_ext (ExtCall operation)
  (cl, filesystem_before) captured_configuration captured_before
= Oracle_return (cl, filesystem_after) captured_after
```

| Theorem | Operation | Descriptor | Modeled transfer |
| --- | --- | --- | --- |
| `observed_ffi_0` | read | 0 | 62 bytes; stdin offset becomes62 |
| `observed_ffi_1` | read | 0 | EOF, zero bytes |
| `observed_ffi_2` | read | 0 | EOF, zero bytes |
| `observed_ffi_3` | write | 1 | 64 exact stdout bytes; stdout offset becomes64 |

The command line `cl` and remaining choice stream `ns` stay arbitrary. The
first four modeled transfer-choice entries are4096. Stdin is the independently
frozen62-byte request; stdout/stderr initially contain no bytes. The complete
configuration, data padding and unmodified tails are checked. All twelve arrays
match each of the two prior native captures, for24 direct byte comparisons.

- Proof source: `b1daaa48e84b9946b0160da2f70c50d11cac0314c25c032cf1bfea13b7adbc78`.
- Proof data: `5af94f633ccc88472f38e863a2beb9d80adb867589ce95a460743c7c65009747`.
- Exact native executable: `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`.
- Frozen stdin: `7b450385073cc30d774749b240a8eb8252bfb9ba89b9af62d0f1e1435297c84f`.
- Frozen stdout: `629d44e9f09823060942f4b75007dcf87ddce9c505314a4b74f9ac19d9d84cee`.
- CakeML: `cd9155694c16831373ab695a670794f23282ed62`.
- HOL: `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`.

[Complete readback](records/model-complete-readback.json) contains each export,
the closure graph, all1068 file hashes, capture bindings and actual control
results. The closure retains the four existing bool foundation axioms:
`SELECT_AX`, `INFINITY_AX`, `ETA_AX`, and `BOOL_CASES_AX`. Logic/kernel, Poly/ML,
the loader, host and imported parent proof data remain trusted. Fresh local
import is not clean independent replay of every dependency.

## Correspondence boundary and next check

| Relationship | Status | Remaining condition |
| --- | --- | --- |
| Four exact model call equations | PROVED | Limited to the recorded buffers and explicit filesystem witnesses |
| Buffers bound to both native captures | OBSERVED / DERIVED | Trust local observer and saved records; no new native run here |
| Loaded code/bitmap and call-return observations | OBSERVED, prior U283/U285 | Finite evidence does not prove universal installed-state or memory-frame conditions |
| Complete actual filesystem equals model witness | NOT_ESTABLISHED | Descriptor/memory/environment relation remains required |
| Unobserved choice stream is live; `wfFS` | NOT_ESTABLISHED | Four finite observations do not establish liveness of the remaining stream |
| Universal C/ABI/OS behavior and physical ARM state | NOT_ESTABLISHED | Explicit runtime, frame, scheduling, resource and exit assumptions remain |
| Full approved source/domain to native behavior | NOT_ESTABLISHED | Complete the compiler composition and source/runtime premise discharge |
| New authenticated Forge claim and independent admission | NOT_ESTABLISHED | Exact approved profile, independent review and authorized provenance/admission |

The next smallest action is to finish the original compiler behavior proof,
inspect its exact conclusion, then run binding controls and reproduction.
Keep U284's source initialization/event work separate. Preserve full integer
and Unicode coverage. Do not replace the approved domain with this one fixture.
M2–M4 and the unrelated swarm experiment do not change this priority.

Off-machine exact archive hashes and restore remain unverified. The owner's
backup confirmation is preserved. Publication, protected adoption, merge,
dispatch, signing, admission and deployment retain their approval boundaries.
No such operation ran here. Hosted refund measurements remain **NOT RUN**.
Local monotonic durations are recorded in command JSON; no speedup claim follows.

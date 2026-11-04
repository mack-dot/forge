# Forge — immediate vertical slice

CURRENT none. Stage11 merged. Stage12 unauthorized. `end_to_end=false`.
This audit preserves the master mission and earlier evidence. It sets the
immediate priority; it does not adopt a specification or acceptance profile.

The immediate target is one approved behavior carried through one exact
executable, a justified concrete/abstract relation, authenticated provenance
and independent release admission. Proof reuse across changes, benchmarks and
a developer interface are later horizons. They do not block this work.

## Current chain

| Link | Established support | Remaining gap |
| --- | --- | --- |
| Approved specification | Stage7 fixes this ELF's modeled normal exit0; Stage9 locks that claim | PR37's additional entry domain and the new arithmetic consequence remain unapproved |
| Checked implementation | Historical kernel579 checks the exact machine program; kernel569 checks the proposed broader-memory theorem | Source-level C correctness and arbitrary-input GCD correctness are not established; Dafny component proofs do not transfer to this ELF |
| Exact compiled executable | Two historical compiler runs produced the same1240-byte ELF, SHA256 `8ced2ab6c7160338899056fe51bacb23d86d81705eacfdd1e992cf5252bdaeb6`; current identity audit matches held bytes and objects | Reproducibility alone is not compiler correctness; the binary proof directly targets these bytes |
| Concrete/abstract correspondence | Historical595-module process-prefix kernel; new observer captures404 LOAD bytes and matching register trace | Full physical process/Model relation and QEMU/Linux syscall fidelity remain unestablished; finite observation does not prove all physical executions |
| Authenticated provenance | Fresh unchanged consumer accepts the historical signed release with real Cosign verification | That signature binds the old theorem/source/profile. Existing policy explicitly claims file materialization, not RISC-V execution |
| Independent release admission | Historical approved admission and replay controls exist | No new runtime claim was signed or admitted. New exact claim/profile approval and a fresh authorized release request are required |

The ELF executes a real remainder loop for1071 and462, then checks21. The
approved exit0 claim is meaningful only for that fixed-input self-test. It is
not an arbitrary-input GCD service, ledger application or whole-program product
guarantee. Expanding its input contract would require separate intent approval.

## Work executed in this audit

Commands and raw output are in
`results/vertical-slice-audit-2026-11-03/attempt-0001/`.

| Actual command or child execution | Exit | Result |
| --- | ---: | --- |
| `python3 -B .../compile_cases.py positive` |0|Rocq checks exact loop pairs1071/462 →462/147 →147/21 →21/0, result `Z.gcd 1071 462`, and modeled normal exit0 |
| `python3 -B .../compile_cases.py negative` |1|Intended rejection:21 does not satisfy the claimed result22 |
| `python3 -B .../compile_cases.py audit` |0|Fully qualified direct assumptions printed |
| Existing published parser in pinned Linux checker |0|13 direct assumptions; all within the prior86-name closure |
| `python3 -I -S -B .../audit_identities.py` with pinned Python3.10.11 |0|39 held host proof objects and28 source identities match; old ELF and authenticated evidence match |
| Unchanged historical consumer: baseline |0|Real Cosign0; no controller access or admission |
| Same consumer: unsigned execution / correspondence additions |1/1|Real Cosign0/0, then `EVIDENCE_DIGEST` at the exact intended boundary |
| `python3 -B .../finish_audit.py` |0|All expected new local outcomes and actual signature exits checked |
| Existing strict integration status command |1|Only `off_machine_backup_confirmed` remains false in its unchanged input policy |

The new modeled termination consequence quantifies arbitrary reservation and
FCSR values. Reconstructing those two physical values is therefore unnecessary
for this particular proposed claim. Their historical values remain unknown.
This does not close the actual machine/process abstraction relation. The Model
premises `m_halted=None` and `m_vm_lazy=[]` remain explicit. The sparse lazy
allocation ledger is not the host's physical demand paging state.

New proof source SHA256:
`5a230c7e1b99652e720fbe134c383a66247a0f08f460ea98546f136831a731aa`.
Compiled object SHA256:
`f1d3b7e22f0ba9f40607f555c7fc15b85fdf84598bc1a5b6d47d7f1a33af8cca`.
Rocq compilation is actual. A fresh full independent recursive kernel run for
this new root is **NOT RUN**. Earlier569/567/595 results are historical and do
not become a new root replay. No assumption allowlist or original theorem changed.

Two metadata-audit failures are preserved. Importing Linux-pinned YAML code on
macOS failed1. Running the existing parser in Linux then rejected short axiom
names with1. A separate fully qualified Print Assumptions module corrected the
input format; the unchanged parser passed. Neither failure counts as a proof
refusal or a successful execution. No tool was installed or policy weakened.

## Shortest remaining path

1. Review the exact intended fixed-input behavior and PR37 head
   `fc85ecc2c7f12caa6c8991fa002410bdf78dd51d`. It is still draft/open,
   unmerged, with no submitted reviews. New source5a230c7e is a separate local
   supplement; it is not covered by review of that head. Preserve exact review
   and claim/profile-adoption boundaries. A PR merge alone cannot activate it.
2. Close the run-specific relation to the existing LPS process model. Relate
   measured entry PC/GPR/FPR/ROM and pending-syscall state to the selected machine
   state; justify the two Model premises and the exit_group94/status0 boundary.
   Distinguish checked model facts, observations and runtime trust assumptions.
   Do not relabel source inspection or finite trace agreement as refinement.
   Reservation/FCSR capture and full vDSO validation are not prerequisites for
   this claim when its existing model path neither depends on those values nor
   executes the vDSO. Keep the diagnostics and full-runtime gap explicit.
3. Check the final exact theorem/binding and full dependency closure independently.
   Freeze the claim, source, ELF, loader/runtime profile and observation identities.
   Prepare only the protected changes needed to bind those exact inputs through
   the existing producer and consumer. Stop for approval of the concrete diff.
4. After corresponding approvals, perform the fresh producer/signature check and
   independent admission under one new controller request. Preserve tampering,
   wrong-claim, substitution and replay refusals. New signing/admission execution
   requires its explicit authorization. The old signed bundle cannot be upgraded.

The current approved protocol explicitly excludes RISC-V execution at
`spec/provenance/protocol.md:174`; `policy/provenance.json:28` is false. Changing
those claims requires reviewed evidence and an exact protected proposal, not
flipping that field. No new signing service or general verification framework
is needed to prepare this narrow extension.

## Operational status and verdict

Main remains `f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3`. PR36's upload repair
stays separate. The owner reports a backup on another device. Exact archive
identity, newer-evidence coverage and remote integrity/restore remain unverified.
Preserve that attestation; do not describe the copy as absent. Resolve archive
validation in parallel; it does not replace the technical correspondence work.
Effective rules were previously inspected; review controls exist, but no required
status checks/workflows were configured. No protection settings changed.

Immediate vertical slice: **NOT_ESTABLISHED**. Strict integration:
**NOT_ESTABLISHED**. New hosted execution, new authenticated runtime claim and new
release admission: **NOT RUN**. Do not start Stage12 or claim end-to-end correctness.


## New executable correspondence result — U254

The fresh full recursive independent replay passed597 modules with exactly the
same86 allowed assumptions. Behavior and explicit ExitEv0 proofs rebuilt byte
for byte. This supersedes the earlier new-root NOT RUN status, without changing
the historical record. The new runtime observation matches21 frames and404 LOAD
bytes. Parent process exit is0. Register interference produces exit2 and refusal1.

The precise field matrix, replay evidence and inactive approval packet are in
results/executable-correspondence-2026-11-03/attempt-0001/REPORT.md and its linked
CORRESPONDENCE.md. Overall PARTIALLY_ESTABLISHED; end_to_end=false. Full physical
state refinement and new authenticated release admission remain unestablished.
The next boundary is exact conditional claim/profile and independent source
review. No Stage12, accepted-policy change, publication, merge or dispatch.
The owner reports an off-machine backup. Its exact hashes/restore remain NOT RUN;
fresh local restore0 does not close strict integration EXIT1.

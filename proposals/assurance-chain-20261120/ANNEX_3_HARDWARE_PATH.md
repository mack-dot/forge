# Annex 3: the silicon-rooted path and the hardware side of exact-artifact binding

Investigation document, 2026-11-20. Investigator 3 of 3, mission section 7.
`end_to_end=false`. M1-B OPEN. This document approves nothing and starts nothing.

Base read: `origin/main` = `058eabcb`. No HOL, Holmake, Dafny or build ran for this annex.
Commands that ran (read-only, each exit 0): `grep`, `sed`, `shasum -a 256`, `file`,
`codesign -dvvv`, `otool -L`, `nm -U`, `sw_vers`, `sysctl -n machdep.cpu.brand_string`.
Web searches used generic terms only. No information about this project or its owner went to
an outside service.

The owner's rule applies: silicon verification is NOT a prerequisite for software assurance.
Section 6 lists the software milestones that depend on none of this annex.

Status words (mission vocabulary): MACHINE_CHECKED, INDEPENDENTLY_REPLAYED, TESTED_ONLY,
ASSUMED, INCOMPLETE, MISSING.

Source marks:

- READ: I read it in this repository.
- WEB: a public source, listed in section 9 with the date fetched.
- UNCONFIRMED: my prior knowledge or a weak source. I did not confirm it in this run. Do not
  use it as evidence until someone checks it.

## 1. Findings: the lowest proved level today

F1. The lowest proved level is a HOL4 theorem about an ISA model, not about a CPU (READ). The
model is the L3-derived ARMv8 model. Its step function is `NextStateARM8` in HOL `9783a499`,
`arm8/model/arm8Script.sml`. The CakeML premise `arm8_ok` is in CakeML `cd915569`,
`compiler/encoders/arm8/arm8_targetScript.sml` lines 20-26. Evidence:
`proposals/m1b-mission-20261119/reports/D11-processor-state-bits.md`, findings 1-3. Tool pins:
Poly/ML 5.9.2 `4557554077078decce4ce5f90da00a713cfc32e4`, HOL
`9783a49979c94c401ff8c0e51b2eefae7ea95ae3`, CakeML `cd9155694c16831373ab695a670794f23282ed62`
(`proposals/m1b-mission-20261119/drafts/CLEAN_REPLAY_PLAN.md` lines 33-35). The model is
AArch64 only. It has a flat 2^64 memory. It has no MMU, no caches, no TBID and no nRW field
(D11, finding 3).

F2. The model theorems are MACHINE_CHECKED. They are not INDEPENDENTLY_REPLAYED (READ). Record:
`proposals/refund-executable-feasibility/m1-chain-replay-20261118/REPORT.md`. It shows 71 of 71
theories replayed with exit 0 on 2026-11-18, on the same machine with the same pins. The report
says: "It is not a clean-room replay and not an independent replay." The contract link uses
theorem R1 `refund_route_a_flat_plain_shape`. R1 has 12 premises
(`proposals/apex2-contract-link-20261119/README.md`, section 3 rows R1-R3 and section 6).

F3. The 12 premises of R1 are assumptions about the real machine. The README says: "None is
proved for the real process" (apex2 README, section 6) (READ). Premise P1 is FALSE for a
faithful copy of the real registers. Theorem R3 `refund_entry_refuses_tagged_user_state` shows
that a state with TBI0 or SA0 set does not meet P1. Linux v6.12 and XNU both set TBI0 = 1 and
SA0 = 1 (D11, finding 4, table). So the theorem speaks of an "erased" state only. The run-level
erasure lemmas ML-08 and ML-09 are MISSING (apex2 README, section 6, P1 bullet;
`proposals/forge2-v2-formal-ceiling/DESIGN.md`, section 2, row "TBI0/SA0").

F4. The binary runs natively on the owner's Mac today (READ and this run).

- File: `proposals/forge2-m1-conformance/artifacts/refund-arm64-macho`.
- SHA-256 `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` (`shasum`, this
  run).
- `file` gives "Mach-O 64-bit executable arm64".
- The host is macOS 27.0.1 (build 26A434) on an "Apple M1 Pro" (`sw_vers`, `sysctl`, this run).
- Goal 19 ran the binary on "one machine (macOS 27.0.1, arm64)"
  (`proposals/forge2-native-silicon-sink/REPORT.md`, lines 6-7).
- The Goal 19 path does not use QEMU and does not use a Linux guest.
- A Linux route-A design exists. Its run records (`results/m1b-routeA-20261119/`) are
  untracked in the owner's working tree. I did not find them on `main`.

F5. The executed file holds more than the proved code (this run).

- `otool -L` shows that the file links `/usr/lib/libSystem.B.dylib`, so `dyld` loads it.
- `nm -U` shows these symbols:
  - `_cml_main` at `0x100004000`;
  - the CakeML code buffer from `0x100023e54` to `0x100024000`;
  - the C FFI functions `_ffi`, `_fficlose` and `_fficustom`. They have `.cold` parts, so they
    are clang-compiled C.
- No theorem covers the C FFI, the Mach-O loader, `dyld`, libSystem or XNU.
- The apex2 README, section 6, last bullet, says: "Not in any premise: the ARMv8 model is the
  silicon; `basis_ffi` is the real kernel I/O; the loader."

F6. The binary has an ad-hoc linker signature (this run).

- `codesign -dvvv` gives:
  - `flags=0x20002(adhoc,linker-signed)`;
  - `CDHash=7c0eef4687359f32f0f393e9063a96024fd4229d`;
  - `CandidateCDHashFull sha256=7c0eef4687359f32f0f393e9063a96024fd4229d3db9bceec5e961e4368552ac`.
- UNCONFIRMED: on Apple silicon, the kernel checks code pages against this code directory at
  page-in.
- If that holds, the signature is an unused hook for exact-artifact binding (section 5, H0).
- No repository code uses the cdhash today. `grep -i -E "codesign|ad-hoc|adhoc|cdhash"` on
  `src/silicon_sink/sink.rs` and `scripts/exit_silicon_sink.py` found nothing.
- The sink hashes the file before launch. The Goal 19 REPORT, section 1, says the EXIT script
  "does the launcher's duty: it hashes the binary".
- A hash before `exec` has a time-of-check/time-of-use gap. It does not bind the pages that
  ran.

F7. Forge v1 already had one RISC-V binary-level proof, with a different tool chain (READ).

- A 1240-byte RISC-V ELF `8ced2ab6…` was built with clang/lld 20.1.8.
- A proof showed that it terminates under the published LPS Rocq model of the Theorem pipeline
  (`unsure.md` U002, U068).
- An independent `rocqchk` checked 569 modules (`unsure.md`, near line 6037).
- The same records show the gap that this annex is about:
  - Under pinned QEMU (Ubuntu 8.2.2 static runtime), the observed initial SP was
    `0x2aaaab2abc30`.
  - That SP is below the model's `valid_sp_va` minimum, so the entry premise of the theorem
    was false for that run.
  - The record says: "Do not interpret a successful run as theorem instantiation" (`unsure.md`,
    about lines 5876-5885).
- Lesson: an ISA-model theorem and a real run do not compose without a checked relation for the
  entry state.

F8. Today, the hardware fidelity of the L3 model is an owner-signed ASSUMPTION, and the
processor bits are an open transition (READ).

- Owner-signed assumption P6 covers "the CPU part of T11 and T13 only".
- P6 excludes the processor bits. DESIGN.md, section 1, quotes the mitigation cell: "the
  processor bits (TBI0, TBI1, SA0, EL0, E0E) remain a SEPARATE transition (T11), not covered
  here."
- The processor bits are therefore an open transition:
  - T11, the run lift, is MISSING;
  - the native rows N02-N04 are ASSUMED and nobody has observed them.

## 2. The gap from model to real machine, as named assumptions

Each item is necessary to get from "a theorem about `NextStateARM8`" to "this run on this M1 Pro
under macOS 27.0.1".

| Id | Named assumption | Status | Evidence path |
| --- | --- | --- | --- |
| HW-1 | ISA fidelity: each executed AArch64 instruction of the code buffer behaves on the M1 Pro as L3 `NextStateARM8` says (EL0, the instructions that CakeML emits) | ASSUMED (signed P6, CPU part only) | DESIGN.md section 1; D11 finding 5 ("real hardware is not L3") |
| HW-2 | Processor-bit erasure: a real run with TBI0 = SA0 = 1 agrees with the erased model run (D11 wording "A-PROC") | INCOMPLETE (one step MACHINE_CHECKED; run lift ML-08/ML-09 MISSING; native rows ASSUMED) | D11 finding 5; apex2 README section 6 |
| HW-3 | The microarchitecture is invisible at the ISA level: caches, TLB, speculation, out-of-order execution and Apple extensions (PAC; TBID0 when HAS_APPLE_PAC is set) change no architectural result | ASSUMED. The repository names only TBID0 ("not modelled") | D11 finding 4, table row TBID0 |
| HW-4 | Memory: the virtual memory that the kernel maps equals the model's flat memory on `mem_domain`; no other writer exists (other thread, debugger, DMA, another process with `task_for_pid`) | ASSUMED (premises P2-P7, interference) | apex2 README section 6 |
| HW-5 | Loader: `dyld` and XNU put the exact code bytes at the theorem's addresses and enter `cml_main` in the premise state | MISSING (T10, ML-10) | TOP_LEVEL_GRAPH_REFRESH_20261119.md section 3, rows T10, T15 |
| HW-6 | FFI: the clang-compiled C `basis_ffi` and the kernel give the results of the model oracle | ASSUMED / MISSING (T9, T12k) | DESIGN.md section 2 row "R6 FFI"; GRAPH row T12k |
| HW-7 | Privilege: the process runs at EL0; the kernel keeps the EL1 registers fixed during the run and across FFI calls | ASSUMED (`interference_ok` keeps PSTATE, SCTLR and TCR fixed in the model only) | D11 finding 2 |
| HW-8 | Artifact identity: the pages that executed are the pages of file `b8ed5ec2…` | TESTED_ONLY (pre-exec hash in the sink; no record of what ran) | Goal 19 REPORT section 1; F6 |
| HW-9 | Physical integrity: no fault during the run (voltage glitch, rowhammer, bit flip, hardware erratum) | ASSUMED, not named in the repository | none found |
| HW-10 | Manufacturing provenance: the chip is the design that Apple specified, with no implant | ASSUMED, not named; the owner cannot check it | none found |

## 3. The six levels: what each can verify for Forge, and the trust it adds

| Level | What could be verified for Forge | By which tool (public) | What is trusted in addition | Realistic for Forge? |
| --- | --- | --- | --- | --- |
| Architectural model verification | A binary-level theorem on an ISA model (done today on L3 ARMv8); validation of the model against hardware by differential tests | HOL4 and CakeML (done); L3 and Sail ISA models; for Arm, Arm's ASL specification and its Sail translation (UNCONFIRMED for current versions) | The model is the architecture; the tests are finite | YES. In progress (M1-B) |
| RTL verification | The RTL implements the ISA specification for all reachable states | Silver: a HOL4 proof from the ag32 ISA to Verilog (WEB, PLDI 2019); CHERIoT-Ibex against Sail by Jasper model checking (WEB, 2025); riscv-formal for many RISC-V cores (UNCONFIRMED) | The Verilog semantics; the match between the RTL specification and the ISA specification; for model checking, the bounds and the property coverage | Only on an open core. NOT for Apple, Intel or AMD CPUs, because their RTL is closed |
| Gate-level verification | The netlist equals the RTL | Lutsig, a verified synthesis tool to FPGA LUTs, for Silver (WEB); commercial or Yosys-based equivalence checkers (UNCONFIRMED) | Cell-library models; the equivalence checker; timing closure | Only on an FPGA or an own ASIC |
| Physical silicon validation | The chip behaves as the netlist (post-silicon tests, fault campaigns) | Vendor test, scan chains, BIST; no public proof tool | Test coverage; the fab process; the test equipment | NO for the owner |
| Manufacturing provenance | The chip is the design that was taped out; no implant; supply chain | Vendor certificates, split manufacturing, chip imaging; no proof tool | The vendor, the fab, the distribution chain | NO for the owner; only as a signed assumption |
| Runtime hardware attestation | A hardware root signs "this measurement ran in this environment" | TPM 2.0 with measured boot and IMA; AMD SEV-SNP; Intel TDX; Arm CCA; AWS Nitro Enclaves (all UNCONFIRMED as to current details); Apple App Attest (macOS 27, full apps only; WEB, forum replies) | Vendor keys and certificate chain; firmware and microcode; the measured code itself (a measurement is not correctness); for confidential VMs, the vendor security processor (not the hypervisor) | YES (stage H1), on commodity cloud hardware |

Attestation binds IDENTITY. It does not bind BEHAVIOUR. It can move HW-8 from TESTED_ONLY to
"vendor-attested". It adds the vendor root to the trusted base. It does not touch HW-1 to HW-7.

## 4. Candidate extensions, ranked by assurance gained per unit of work

### Rank 1. Kernel-enforced code identity, no new hardware (stage H0)

- Extends: HW-8 (the exact executed artifact), on the present Mac.
- Level: none of the six. It is an operating-system mechanism. It is next to runtime
  attestation, but it has no hardware signature.
- How:
  1. Record the cdhash `7c0eef46…52ac` together with the artifact SHA-256 in the bundle and in
     the receipt.
  2. A witness process under a SECOND uid asks the kernel for the code identity of the live
     process and writes it into the receipt. Candidate APIs: `csops(pid, CS_OPS_CDHASH)`, or
     `SecCodeCopyGuestWithAttributes` with `SecCodeCheckValidity`. The API names and whether a
     non-root uid may use them are UNCONFIRMED.
  3. Launch with hardened runtime and library validation, and with no `DYLD_*` variables, so
     the kernel refuses injected code. This also helps T15.
  4. On Linux the equivalent is an fs-verity digest and the IMA measurement of the exec
     (UNCONFIRMED details).
- Adds to the trusted base: the XNU code-signing enforcement (or Linux IMA); the witness
  program; the separation between the two uids.
- Public tools: Apple code signing (built in); Linux fs-verity and IMA.
- Effort: small (days). There is no proof. The result is a NATIVE CHECK.
- Does NOT establish:
  - that `libSystem` and `dyld` are unmodified (Apple signs them, so Apple is trusted);
  - that the root user did not forge the receipt (no hardware key);
  - ISA fidelity (HW-1).

### Rank 2. Commodity remote attestation of the measured binary (stage H1)

- Extends: HW-8, to a verifier outside the machine. A confidential VM also covers part of HW-4
  (memory isolation from the host).
- Level: runtime hardware attestation.
- Options:
  - AMD SEV-SNP or Intel TDX confidential VM (UNCONFIRMED: current cloud availability). The
    launch measurement covers the guest firmware and kernel image. To bind the refund binary,
    a measured chain inside the guest is necessary (vTPM, or IMA). Trusted: AMD or Intel keys,
    the security firmware, microcode, the guest kernel. The hypervisor is not trusted for
    confidentiality. Effort: medium (1 to 3 weeks). An AArch64 Linux ELF of the refund program
    is necessary, and the M1 chain must then be made again for that image (the theorem is per
    image; DESIGN.md section 0, point 3, and section 4.3).
    Note: SEV-SNP and TDX are x86. For an x86 guest the CakeML x64 target would be needed, and
    the whole M1 chain would change target. An AArch64 option keeps the ARMv8 proof target.
  - AWS Nitro Enclaves (UNCONFIRMED: current details). The Nitro root signs an attestation
    document. Its PCRs cover the enclave image file. Trusted: the AWS Nitro hypervisor and the
    AWS root. Effort: medium. The note on the Linux rebuild also applies here.
  - Arm CCA. The architecture is published. Shipping silicon with RME on and with attestation
    usable by customers is UNCONFIRMED. The web search found one Fujitsu MONAKA blog and one
    personal blog that nobody has checked. CCA would keep the ARMv8 proof target. Effort:
    unknown.
  - TPM 2.0 with measured boot and IMA on a Linux machine. A quote over PCR 10 together with
    the IMA log names the hash of the executed file. Trusted: the TPM vendor, the firmware
    (CRTM), the kernel. Effort: small to medium.
  - Apple App Attest. On macOS 27 it works for full Mac apps in a user context only. It does not
    work for daemons or command-line tools (WEB; replies by an Apple engineer on the developer
    forums, not official documentation). It attests an app identity (team ID and bundle ID)
    and a Secure Enclave key. It does not attest the hash of a subprocess. It cannot bind the
    CakeML subprocess directly. Low rank for this need.
  - RISC-V Keystone. A research enclave. Its production status is UNCONFIRMED. Low rank.
- Does NOT establish: correct behaviour of the binary (that is the job of the theorem); ISA
  fidelity of the real CPU (HW-1); absence of side channels; durability of the effect.

### Rank 3. An isolation layer with a kernel proof (seL4)

- Extends: HW-4 and HW-7 (no other writer; the privilege boundary). The proof is about the
  seL4 kernel, not about XNU or Linux.
- Level: architectural model verification of the kernel, over the kernel's own ISA model.
- Status (WEB, official page, fetched 2026-11-20):
  - AArch32 (`ARM`): C-level functional correctness with fast path; integrity; confidentiality;
    "binary correctness, covering C functions that have C-level verification".
  - AArch64: C-level functional correctness with fast path; integrity and availability;
    confidentiality; "Further properties are under development". No binary correctness.
  - RISCV64: C-level functional correctness, no fast path; integrity; confidentiality. No
    binary correctness listed.
  - A 2021 seL4 Foundation post says that RISC-V proofs reached the binary. The current official
    page does not list binary correctness for RISCV64. This is a DISCREPANCY. Status
    UNCONFIRMED.
- Adds: the stated seL4 exclusions (WEB): "none of our verified configurations take into
  account address translation for devices (System MMU or IOMMU), debug/profiling/printing
  interfaces, or the kernel startup at boot". It also adds the assumption that the seL4 ISA and
  MMU model match the hardware. A new FFI to seL4 services is necessary. The CakeML basis FFI
  has a POSIX shape. A verified CakeML-on-seL4 FFI is UNCONFIRMED (I know of none).
- Effort: large (months). It ranks below H1 because it needs a new platform and a new FFI
  proof, although it replaces XNU trust with a smaller trusted base.

### Rank 4. A verified ISA-to-RTL stack on an FPGA (Silver / ag32)

- Extends: HW-1, by proof, for an FPGA core. The chain is the CakeML ag32 target, the Silver
  proof from ISA to Verilog, and Lutsig synthesis. All three are in HOL4 (WEB: Lööw et al.,
  PLDI 2019; repository `CakeML/hardware`, folder `ag32`).
- Level: RTL verification and gate-level verification (FPGA LUTs).
- What Silver covers (WEB): ag32, a custom 32-bit ISA. It is not ARM and not RISC-V. Its I/O
  goes through a memory-mapped interface with a simple FFI. It ran on an FPGA board.
- What Silver does not cover: the FPGA vendor tools after Lutsig (place and route, bitstream);
  the FPGA silicon, the board and the power supply.
- Maintenance: the repository README warns that the Silver theories do not build at the latest
  commit, because the Verilog semantics changed, and points to an older commit (WEB). I found
  no public activity after 2019. Maintenance status UNCONFIRMED.
- Effort: large. It is the only public path where one proof assistant (HOL4, which Forge already
  uses) goes from CakeML source to Verilog. It is a research demonstration. It is not a platform
  for a durable WAL with `fsync`.

### Rank 5. RISC-V with a formally checked core

- Extends: HW-1, for an open core.
- Facts:
  - The Sail RISC-V model "has been adopted by RISC-V International" (WEB, README). The README
    does not call it ratified. The ratified text is the prose ISA manual (WEB search summary).
  - The README says the model exports to "Isabelle, Rocq, and Lean". It does not list HOL4
    (WEB, fetched 2026-11-20).
  - CakeML has a RISC-V target. The CPP 2017 paper lists RISC-V among the targets (WEB). That
    the target uses an L3 RISC-V model is UNCONFIRMED.
  - CHERIoT-Ibex was checked against its Sail specification with Jasper. The result is
    equivalence of memory-interaction traces, plus liveness (WEB, arXiv 2502.04738, February
    2025). A bug in PMP checks for instruction fetch was found in vanilla Ibex.
  - Ibex is a 32-bit core. The CakeML RISC-V target is 64-bit (UNCONFIRMED). So no direct
    composition exists today.
- Gaps: the CakeML RISC-V model and the Sail model are different models. A model-equivalence
  argument is MISSING. The model-checking proofs live in a different tool than HOL4, so the
  composition would be ASSUMED at the tool boundary.
- Effort: very large. A research project.

### Rank 6. RTL-to-gate equivalence, physical silicon, manufacturing provenance

The owner cannot reach these levels for any CPU that Forge uses. Equivalence checking trusts the
cell library and the checker. Silicon validation trusts the test coverage. Provenance trusts the
vendor and the fab. Use them only as signed assumptions (HW-9, HW-10).

## 5. Staged recommendation

### H0. No new hardware (do first; days)

Steps:

1. Bind the cdhash to the artifact digest in the bundle.
2. A witness under a second uid reads the kernel's code identity and the executable path of the
   live process and writes them into the receipt.
3. Launch with hardened runtime and library validation, with no `DYLD_*` variables.
4. Observe the processor bits with the five indirect tests of D11, finding 6 (native rows
   N02-N04).
5. Write HW-1 to HW-10 as assumption lines. The owner signs or rejects each line.

Acceptance criteria (checkable):

- A receipt contains `artifact_sha256 = b8ed5ec2…7bb8` and `cdhash = 7c0eef46…52ac`, and the
  witness value equals both.
- A changed copy (one byte) gives a different cdhash, and the sink refuses it with a recorded
  non-zero exit code (negative control).
- A run with `DYLD_INSERT_LIBRARIES` is refused, with a recorded exit code.
- The five D11 tests run, and their exit codes are recorded.

Trusted assumptions that remain: XNU, `dyld`, libSystem, the M1 Pro, the root user, Apple.

Does NOT establish: that the receipt came from this machine (no hardware key); ISA fidelity;
that the erased-state theorem applies (that needs ML-08 and ML-09).

### H1. Commodity attestation (weeks)

Steps:

1. Move the run to AArch64 Linux in a confidential VM, a Nitro Enclave, or a Linux machine with
   a TPM. AArch64 keeps the ARMv8 target.
2. Make the M1 chain again for the ELF image.
3. Produce a vendor-signed quote whose measurement covers the refund ELF.
4. The receipt carries the quote.

Acceptance criteria:

- A verifier outside the machine, with only the vendor root certificate and the published
  digest, checks the quote offline with exit 0.
- A one-byte change of the ELF makes the check fail with a non-zero exit code.
- The measurement recipe is reproducible from the repository by recorded commands.

Trusted assumptions that remain: the vendor root, the security firmware, microcode, the guest
kernel (measured, not verified), HW-1 to HW-7.

Does NOT establish: correct behaviour; ISA fidelity of the real CPU; durability of the effect.

### H2. A verified-stack platform on an FPGA (months; research)

Steps:

1. Run a refund decision (without the WAL) on Silver/ag32 with the CakeML ag32 target.
2. Prove the decision theorem again for that target.
3. Compose it with the Silver theorem in HOL4.

Acceptance criteria:

- One HOL4 theorem with a conclusion about the I/O of the Verilog circuit. Its premise list is
  printed and audited.
- The bitstream is built from the proved Verilog by recorded commands.
- The FPGA output on a fixed test set equals the output that the theorem predicts.

Trusted assumptions that remain: the Verilog semantics in HOL4, the FPGA tools after the
netlist, the FPGA silicon, the board, the I/O devices, the host that collects the receipt.

Does NOT establish: anything about the production Mac path or a cloud path; durable storage.

### H3. Silicon (not recommended now)

Use HW-9 and HW-10 only as signed assumptions. Acceptance would be a vendor statement, not a
proof. H3 establishes nothing that the owner can check.

## 6. Software milestones that depend on NONE of this

None of the following milestones depends on H0 to H3:

- the M1-B model lemmas ML-01 to ML-15, including the TBI0/SA0 run lift ML-05, ML-07, ML-08 and
  ML-09;
- the model part of the R6 FFI (T9);
- the entry state ML-10 (the model part of T10);
- the descriptors ML-04 (T12);
- T4i, the input encoding;
- T14a, a verified parser;
- T16 and T17, the issuer bridge;
- T18, the clean and independent replay;
- the WAL fold (F2.7);
- every Dafny/HOL contract link (T3, BETA-PLAIN).

All of them are statements about models or code. Hardware work changes only which ASSUMED rows
(HW-1 to HW-10) lie under them.

## 7. Edge table (the hardware part of the chain)

| Edge | Source -> destination | Required invariant | Proof | Checker | Environmental assumptions | Status | Remaining work |
| --- | --- | --- | --- | --- | --- | --- | --- |
| E-H1 | VERIFIED COMPILATION -> EXACT EXECUTED ARTIFACT | The file `b8ed5ec2…` is the image that the theorem names | The image digest in the M1 records (see the other annexes) | `shasum -a 256` | The file does not change between the check and `exec` | TESTED_ONLY (hash before exec) | H0 steps 1-3: kernel cdhash witness. No theorem |
| E-H2 | EXACT ARTIFACT -> RUNTIME (loaded process) | The code pages at run time are the proved bytes at the proved addresses; the entry state meets P1 | none | none | HW-5, HW-8 | MISSING | ML-10 and native rows; H0 witness |
| E-H3 | RUNTIME on the CPU -> model run | Each EL0 step equals one `NextStateARM8` step on the erased state | Step lemmas E1-0003, EF-0001, EE-0001 (MACHINE_CHECKED, one step; apex2 README section 6) | HOL4, records cited in the apex2 README | HW-1, HW-3, HW-7, HW-9 | INCOMPLETE (run lift MISSING) and ASSUMED (P6, ISA fidelity) | ML-05, ML-07, ML-08, ML-09 (4 lemmas; reuse candidates `arm8_step`, `targetSem`, `interference_ok`); a signed A-PROC line |
| E-H4 | real CPU -> ISA model | The silicon implements AArch64 for the emitted instructions | None is possible for Apple silicon | none | HW-1, HW-9, HW-10 | ASSUMED (P6, CPU part) | Not feasible on this CPU; only H2 on an FPGA core |
| E-H5 | EXECUTION -> RECEIPT with a hardware root | A third party can check "this measurement ran" | none | a vendor verifier | Vendor keys, firmware | MISSING | H1 |

Size of the remaining work, honest estimate (this annex; no committed source): E-H1 and E-H2
native part: days. E-H3 model part: the four lemmas; GAPS section 7 sizes them "small" to
"medium", with no day number. E-H4: not closable for this CPU. E-H5: weeks, plus a new M1 chain
for a new image.

## 8. What I could not establish

- Whether `csops` or the `SecCode` APIs give the cdhash of a running ad-hoc-signed process to a
  different non-root uid on macOS 27. UNCONFIRMED; not run.
- Whether the Apple silicon kernel checks code pages against the code directory at page-in for
  an ad-hoc-signed command-line binary. UNCONFIRMED.
- Whether XNU on macOS 27 sets HAS_APPLE_PAC or TBID0 for user processes (D11 did not find it).
- The current RISC-V binary-verification status of seL4 (the official page and the 2021 post
  conflict).
- Whether the current CakeML RISC-V target uses an L3 model or a Sail model, and whether it is
  64-bit only. Whether a HOL4 export of Sail RISC-V still exists (the README lists none).
- Which shipping Arm server silicon turns on RME/CCA attestation for customers.
- The 2026 maintenance status of Keystone and of Silver.
- The real `dyld` layout against the addresses in premises P5 and P6.
- Whether a route-A Linux image is committed on `main` (not found there).
- Current details of TPM 2.0/IMA, fs-verity, SEV-SNP, TDX, Nitro Enclaves and riscv-formal. I
  did not re-confirm them in this run.

## 9. Sources

Repository (READ, base `058eabcb`):

- `proposals/forge2-v2-formal-ceiling/DESIGN.md`, sections 0-3
- `proposals/m1b-mission-20261119/reports/D11-processor-state-bits.md`
- `proposals/m1b-mission-20261119/TOP_LEVEL_GRAPH_REFRESH_20261119.md`, section 3
- `proposals/apex2-contract-link-20261119/README.md`, sections 3 and 6
- `proposals/forge2-native-silicon-sink/REPORT.md`, sections 1-2
- `proposals/refund-executable-feasibility/m1-chain-replay-20261118/REPORT.md`
- `proposals/m1b-mission-20261119/drafts/CLEAN_REPLAY_PLAN.md`, lines 33-35
- `proposals/forge2-m1-conformance/artifacts/refund-arm64-macho` (inspected with `file`,
  `codesign`, `otool`, `nm`)
- `unsure.md`: U002, U068, lines about 5700-5890, about 6030-6045, about 6655-6680

Web (all fetched or searched on 2026-11-20):

- Lööw et al., "Verified Compilation on a Verified Processor", PLDI 2019:
  https://trustworthy.systems/publications/abstracts/Loeoew_KTMNAF_19.abstract
- CakeML hardware repository (Silver in `ag32`): https://github.com/cakeml/hardware
- Lööw, thesis: https://www.doc.ic.ac.uk/~aloow/papers/thesis.pdf
- Fox et al., "Verified Compilation of CakeML to Multiple Machine-Code Targets", CPP 2017:
  https://www.cl.cam.ac.uk/~mom22/cpp17.pdf
- seL4 verified configurations (page fetched):
  https://docs.sel4.systems/projects/sel4/verified-configurations.html
- seL4 on RISC-V verified to binary code (2021 post):
  https://microkerneldude.org/2021/05/05/sel4-on-risc-v-verified-to-binary-code/
- Sail RISC-V model README (page fetched): https://github.com/riscv/sail-riscv
- Ploix et al., formal verification of CHERIoT-Ibex against Sail, February 2025:
  https://arxiv.org/abs/2502.04738
- Apple App Attest on macOS 27 (developer forum threads, engineer replies, not official
  documentation): https://developer.apple.com/forums/thread/836329 ;
  https://developer.apple.com/forums/thread/831492
- Apple DCAppAttestService documentation:
  https://developer.apple.com/documentation/devicecheck/dcappattestservice
- Arm CCA on Fujitsu MONAKA (vendor blog):
  https://developer.arm.com/community/arm-community-blogs/b/servers-and-cloud-computing-blog/posts/how-fujitsu-implemented-confidential-computing-on-fujitsu-monaka-with-arm-cca

UNCONFIRMED (my prior knowledge, not re-confirmed in this run): TPM 2.0 and IMA, fs-verity,
AMD SEV-SNP, Intel TDX, AWS Nitro Enclaves, riscv-formal, Keystone, Apple code-signing page
validation, the `csops` and `SecCode` APIs, the model behind the CakeML RISC-V target.

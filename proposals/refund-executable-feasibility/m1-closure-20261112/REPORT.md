# U350–U351: M1 verification and composition continuation — matrix, graph, inventory, plan

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false. Nothing committed.
All new results are local: same machine, same agent, cached parent theories.
No result here is independent verification.

Statuses: PROVED (machine-checked by HOL in this session, local scope),
FAILED (an executed attempt did not succeed), ASSUMED, NOT_RUN.

## 1. Independent replay — NOT_RUN

No clean replay ran. Same-machine repetition was not substituted for it.

| Blocker | Measured fact |
| --- | --- |
| Host disk | 4.7 GiB free (99% used) at the start; 1.1–2.3 GiB during the work. A from-source build of PolyML, HOL and the CakeML basis needs about 2.5–3 GiB by the size of the pinned local trees (HOL 900 MB, CakeML basis chain about 200 MB plus heaps, tools and base image). The compiler proofs need at least 2 GiB more. |
| Host memory | 16 GiB RAM, 15–16 GiB swap in use. One local HOL run added a 1 GiB swap file twice. |
| Docker VM | 10 CPUs, 8.2 GiB RAM. The stack-proof context reached 2.4 GiB RSS; the compiler proof build needs more than the basis build. |
| Independent host | None available without publication and dispatch, which are approval boundaries. |

A same-host container would also not be an independent operator or host.

Prerequisite checked instead, and not a substitute for replay:

| Check | Actual exit | Result |
| --- | --- | --- |
| Unauthenticated GitHub API read of the three pinned commits | 200/200/200 | Commit and tree IDs exist upstream and equal the local `HEAD` and `HEAD^{tree}`. |
| `python3 -I -B verify_sources.py upstream-api` | 0 | Every tracked regular file hashes to its Git index entry; index equals `HEAD`: HOL 7805 files, CakeML 2018, PolyML 857. 55 symlink or submodule entries are not content-hashed. |

Pins: HOL `9783a49979c94c401ff8c0e51b2eefae7ea95ae3` (tree `29cad92945bc239c6389d991c6ae6b3ead1f6da3`),
CakeML `cd9155694c16831373ab695a670794f23282ed62` (tree `fda479738d1902849e80a90b5cf93298c04c36d8`),
PolyML `4557554077078decce4ce5f90da00a713cfc32e4` (tree `190217a8d58ef06a6ec327e35c8470313d51b7e5`).
This binds the local sources to upstream objects under Git SHA-1. It does not
check the built heaps, object files or the Forge parent theories.

Replay plan, NOT RUN: in a fresh Linux arm64 container, fetch the three
commits by ID, build PolyML and HOL, build only the needed theories, run the
recorded candidate, import and control sources, and compare statements by
`aconv`, tags, closure node lists and exits. Start with
`ffiread_error_return`: its closure has 97 nodes and no CakeML theory. Then
`read_error_generic` and `basis_read_error_oracle` without the two Forge
parent theories, which the proofs do not use. The stack and initializer
theorems need the whole Forge chain and the compiler proofs.

## 2. U298 — installer exclusion: inspected; NOT_RUN in HOL

Frozen obligation (U298, unchanged): for the exact refund program, every formal
`TimeOut` prefix of `targetSem$evaluate` avoids `mc.install_pc`. With it,
`machine_sem_install_irrelevant` and `complete_prefix_suffices` remove the
dependence on the installer handler.

Smallest candidate obligation inspected: the published syntactic chain
`word_to_stack_compile_no_install` and `stack_to_lab_compile_no_install`
(`word_to_stackProofScript.sml:12741`, `stack_to_labProofScript.sml:5276`).
Its premise is `no_install_code (fromAList prog)` for the word program.

Finding by source reading, not checked in HOL: `data_to_wordScript.sml:720`
defines `Install_code` with a `wordLang` `Install` instruction, and line 3406
puts `(Install_location, 3, Install_code data_conf)` in the stub list of every
compiled program. So the premise is false for the stub list. Whether the exact
post-`word_to_word` refund program still holds that stub was not evaluated.
On this reading the syntactic route does not apply, and the semantic route
(U299–U305 single-epoch results) is the only one left.

Unresolved subgoal: a target-level invariant that the program counter never
equals `mc.install_pc` on any prefix. The published lab-to-target theorems
state behavior inclusion, not this invariant. No statement was changed. No
HOL attempt ran: the memory guard stopped further runs (section 7).

## 3. ARM8 composition — PROVED, local

[U348 report](../arm8-compose-local-20261112/REPORT.md). The six-step
error-return theorem `ffiread_error_return` is proved against the exact bytes
of the native executable. Library availability (U346) and the composed
instruction-level proof are separate results; only the second is a proof.

## 4. FFI assurance

Exact oracle equation assumed by `read_error_generic` (U345):

```
u «read» (n2w8 fd) (n2w2 n ++ h3::h4::rest) s =
  SOME (FFIreturn (1w::n2w n::h3::h4::rest) s')
```

It says: the oracle `u` answers this `read` call with status byte 1, leaves
bytes 1.. of the buffer unchanged and moves the oracle state from `s` to `s'`.

| Obligation | Status | Evidence |
| --- | --- | --- |
| The published basis oracle satisfies the equation when `read fd fs n = NONE` | PROVED, local | `forge_refundFfiOracle.basis_read_error_oracle`, run `oracle-0001`, exit 0. State is unchanged (`encode fs`). Premises: `fd < 256**8`, `n < 2**(2*8)`, `n ≤ LENGTH rest`. |
| Instance of `read_error_generic` for the published oracle | FAILED | One attempt in the same run: `MATCH_MP_TAC: No match`. Not disproved. Not retried: memory guard. |
| For well-formed standard input the published oracle gives status 0 | PROVED earlier | U327. So the equation is never true for stdin in the published model. |
| A native `read` error on an open descriptor (for example `EIO`, `EINTR`) | ASSUMED absent | Outside the published oracle. No approved extended oracle exists. |
| Native code writes status 1 and no other byte after a negative `read` result | PROVED, local, model level | U348, six instructions, under its premises. |
| Register 19 is the buffer address; prologue and call frame | NOT_RUN | Needs the earlier instructions of `ffiread`. |
| The system call leaves the buffer unchanged on error and returns negative only on error | ASSUMED | Operating system. |
| Descriptor decoding | NOT_RUN | Observation only: the U316 disassembly loads 4 bytes at offset 4 of the 8-byte encoding. No proof relates this to `w82n`. |

Import, repeat and controls for `forge_refundFfiOracle` are NOT_RUN (memory
guard). Its theory data SHA256 is
`b0927759510a0b8730d791d9f6e431368bc9b7f3d3f57a6e926cd35c498e9a3c`.

Smallest sound path. Option A: keep the standard CakeML environment
assumption, "the environment behaves as the published basis oracle". Then
native read errors on open descriptors are excluded by assumption, the error
branch is unreachable for stdin (U327) and `read_error_generic` is not on the
critical path. Option B: admit native read errors. That needs an extended
oracle, a new whole-program proof for it, and an approved contract for the
error behavior. B is a model change and needs a separate proposal. Either
choice is the owner's; neither is adopted here.

## 5. Initialization — PROVED, local; controls NOT_RUN

[U349 report](../initializer-machine-local-20261112/REPORT.md). Nine of the 14
conditions are discharged by the published `is_arm8_machine_config`. Six
premises remain. The report ranks all 14.

## 6. Evidence integrity

| Check | Actual exit | Result |
| --- | --- | --- |
| `python3 -I -B verify_cases.py` | 0 | Binds source, stream and export hashes, exits and markers for the ARM8 and initializer cases. Binds the ARM8 statement text to the native executable hash. |
| Same reader on a copy with one byte appended to an exported theory file | 1 | Rejected: exports differ from record. |
| Same reader on a copy with an acceptance marker appended to a control stream | 1 | Rejected: hash and forbidden marker. |
| Packet manifests (`MANIFEST.json`) for all 2026-11-12 packets | see U350 | SHA256 of every member. |

Artifact integrity and semantic validity are different properties:

- Integrity (hashes, manifests, readers): the files are the ones the HOL child
  read and wrote, and each case ended as recorded. A reader cannot tell
  whether a theorem is true. Hashes made by the producer on the producer's
  machine do not show who made the files.
- Semantic validity: HOL's kernel accepted the proof (`store_thm` succeeded,
  tags show `DISK_THM` only, no hypotheses, no tagged axioms). It rests on the
  trusted base in section D3, including cached parent theories.
- Each theorem is bound to: its source hash, its exported theory hashes, its
  closure node list in the import log, the tool pins, and, for the ARM8
  theorem, the native executable hash.

## 7. Resource incident

Several HOL jobs ran at the same time. Between 16:36 and 16:58 three 1 GiB
swap files appeared, and free disk fell from 4.7 to about 1 GiB. The
attribution to these jobs is the leading inference. The background batch was
stopped with SIGTERM at 17:03 (its shell exit 144). One audit case was
interrupted and has no result record. Two later single runs each added one
swap file. A guard then refused further HOL runs below 1.4 GiB free disk.
No file was lost. Runs must be serial on this host until disk is freed.

## D1. Verification matrix

Exit codes are actual. "Repeat" is a same-host rerun and is not a replay.

| Obligation | Exact command (in its results directory) | Exit | Result | Artifact SHA256 (theory data) | Assumptions | Replay |
| --- | --- | --- | --- | --- | --- | --- |
| `read_error_generic` (U345) | `run_case.py proof-0001 generic-read-0002.sml` | 0 | PROVED | `0fc13181…cd32c0044` | FFI oracle equation; cached parents | Repeat 0, identical; clean NOT_RUN |
| its import and two controls | `run_case.py import/wrong-exception/omitted-event ...` | 0/1/1 | as intended | — | — | NOT_RUN |
| Stack `good_code`, 14-premise initializer (U347) | `run_stack_case.py code-0004 code-local-0004.sml` | 0 | PROVED | `76a5b037…3980aed` | 14 conditions; cached parents | Repeat 0, identical; clean NOT_RUN |
| its audit and three controls | `run_stack_case.py audit/... ` | 0/1/1/1 | as intended | — | — | NOT_RUN |
| `ffiread_error_return` (U348) | `run_arm8_case.py compose-0001 compose-0001.sml` | 0 | PROVED | `2cd33309…daec841` | L3 model; listed premises; loader and CPU | Repeat 0, identical; clean NOT_RUN |
| its import and three controls | `run_arm8_case.py import/wrong-status/missing-separation-v2/untaken-branch-v2 ...` | 0/1/1/1 | as intended | — | — | NOT_RUN |
| two first-version controls | `run_arm8_case.py missing-separation/untaken-branch ...` | 1/1 | SCRIPT ERROR, not counted | — | — | — |
| `refund_initialization_machine` (U349) | `run_stack_case.py machine-0001 machine-0001.sml ...` | 0 | PROVED | `8e8cb008…c4af72` | 6 premises; cached parents | Repeat 0, identical; clean NOT_RUN |
| its audit | `run_stack_case.py audit-0002 audit.sml ...` | 0 | as intended | — | Expected statement derived from the base | NOT_RUN |
| its two controls | prepared sources | — | NOT_RUN | — | — | — |
| `basis_read_error_oracle` (U351) | `run_case.py oracle-0001 oracle-0001.sml ...` | 0 | PROVED | `b0927759…498e9a3c` | Published oracle definition; cached parents | Repeat, import NOT_RUN |
| `read_error_basis_instance` | same run | — | FAILED | — | — | — |
| FFI explorations 1 and 2 | `run_case.py explore-0001/0002 ...` | 1 / −9 | SCRIPT ERROR / WALL TIMEOUT under load, not counted | — | — | — |
| U298 exclusion for the exact program | none | — | NOT_RUN | — | — | — |
| Native read error on an open descriptor | none | — | ASSUMED absent | — | — | — |
| Source identity against upstream | `verify_sources.py upstream-api` | 0 | TESTED | `source-identity.json` in records | Git SHA-1; GitHub API | — |
| Evidence reader and two altered copies | `verify_cases.py` | 0 / 1 / 1 | as intended | `verify-cases.json` in records | — | — |
| Clean or independent replay of any theorem | none | — | NOT_RUN | — | — | — |
| Hosted job (U341) | none | — | NOT_RUN | — | — | — |

Full hashes are in each packet's `MANIFEST.json` and `command.json` files.

## D2. Dependency graph: source properties to native execution

```
Approved Dafny spec and Refund.dfy  (R1–R5)            [Dafny/Boogie/Z3; LOCALLY_VALIDATED, earlier]
  │ flat bridge, Unicode/UTF-8 relation                 [Dafny; earlier]
  ▼
HOL4 Dafny model of the refund method                   [PROVED earlier, conditional]
  │ Dafny→CakeML relation, caller, wire, stdio model    [PROVED earlier, conditional]
  ▼
CakeML program refund_prog  + basis library
  │ in-logic compile (cv evaluation)  → code, data, config   [PROVED earlier: refund_arm8_compiled]
  │ published compile_correct (arm8)  needs:
  │   ├ backend_config_ok, machine config                [PROVED: published + is_arm8_machine_config]
  │   ├ initializer conditions            14 → 6        [U347, U349 PROVED local; 6 open]
  │   ├ installed state: code, memory, registers         [ASSUMED / NOT_ESTABLISHED: matrix E, M rows]
  │   ├ install handler (install_interfer_ok)            [bridge U298 PROVED; exclusion NOT_RUN]
  │   ├ FFI oracle = published basis oracle              [ASSUMED for the real environment]
  │   │    ├ read error, invalid descriptor              [basis_read_error_oracle PROVED local]
  │   │    └ read error, open descriptor                 [ASSUMED absent; U345 covers the library side only]
  │   └ resource limits (is_safe_for_space)              [conclusion allows resource-limit prefixes]
  ▼
Machine semantics of the ARM8 model (machine_sem)
  │ native FFI code basis_ffi.c, compiled by clang
  │   └ ffiread error return, 6 instructions             [ffiread_error_return PROVED local, model level]
  │   └ prologue, call, success path, other FFI functions [NOT_RUN]
  │ L3 ARMv8 model = processor behavior                  [ASSUMED]
  │ Mach-O link and load = stated memory layout          [ASSUMED; finite observations earlier]
  │ macOS system calls                                   [ASSUMED]
  ▼
Native ARM64 executable  b8ed5ec2…a39007bb8
```

## D3. Trusted computing base and assumption inventory

Trusted for every HOL result here:

1. HOL4 kernel at the pinned revision, and PolyML 5.9.2 running it.
2. The cached saved states and parent theories (`DISK_THM`). They were built
   on this machine by an earlier agent. No fresh kernel replay of them ran.
3. The published definitions: CakeML semantics, compiler and basis oracle;
   the L3 ARMv8 model. A proof about a model is only as good as the model.
4. macOS, the file system and the hardware of this host.
5. The runner and reader scripts for evidence handling. They are not proof
   checkers and are not trusted for truth.

Trusted for earlier links, not re-checked here: Dafny 4.11.0, Boogie, Z3
4.12.1; the cv evaluation used for the in-logic compile; clang and the linker
for `basis_ffi.c`; LLDB for the static layout (U316).

New in this session, reduced: source files of HOL, CakeML and PolyML are now
bound to upstream commit objects (TESTED). Nine initializer conditions are no
longer assumptions.

Open assumptions, none approved as a profile:

- Six initializer premises (U349), including `memory_assumption`.
- FFI oracle premise of `read_error_generic`; environment equals the
  published basis oracle; no read errors on open descriptors.
- Installer exclusion for the exact program (U298).
- Runtime matrix rows marked ASSUMED or NOT_ESTABLISHED
  ([CORRESPONDENCE.md](../runtime-premises-20261104/CORRESPONDENCE.md)):
  entry state, memory relation, FFI frame, interference, processor, loader.
- Premises of `ffiread_error_return`: control-register bits, alignment,
  separation of the status address from the remaining code bytes.

## D4. Proof obligations

Closed in this continuation, local scope:

1. Six-step ARM8 error-return composition on the exact native bytes (U348).
2. Initializer: nine machine-configuration conditions (U349).
3. Published basis oracle satisfies the read-error equation for an unreadable
   descriptor (U351).
4. Source identity of the three toolchain repositories (U350).

Closed earlier today: `read_error_generic` (U345); stack `good_code` (U347).

Remaining:

1. Clean replay and independent replay of every theorem above.
2. Negative controls for U349; import, repeat and controls for the oracle lemma.
3. `read_error_basis_instance` (one failed attempt).
4. Installer exclusion for the exact program (U298).
5. Composition of the error path through `inputAllFrom` and `refund_main`,
   if the profile admits native read errors.
6. ARM8: prologue, call frame and success path of `ffiread`; other FFI functions.
7. Initializer premises 2–5 from the published installed-state predicate;
   `memory_assumption` for the physical process.
8. Approved assurance profile; admission (M2).

## D5. Next actions, ordered by expected effect on closure

1. Owner: free at least 20 GiB of disk and clear swap (restart). This blocks
   every further run, local or replay.
2. Clean-container replay, in this order: `ffiread_error_return`;
   `read_error_generic` with `basis_read_error_oracle`; then the Forge chain.
3. Owner decision on the FFI environment assumption (section 4, option A or
   B) and on the assurance profile. This decides which obligations exist.
4. Run the pending controls and imports (U349, oracle lemma); retry the
   instance theorem with a corrected tactic.
5. Derive initializer premises 2–5 from the published installed-state
   predicate.
6. U298: seek the target-level program-counter invariant, or keep
   `install_interfer_ok` as an explicit profile assumption.
7. Extend the ARM8 composition over the `ffiread` prologue and call.

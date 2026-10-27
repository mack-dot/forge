# Stage 7: binary verification

Stage 7 is DONE. The upstream replay, intended negative control, and own-binary
EXIT each returned 0. Stage 8 is CURRENT; its implementation has not started.
The authoritative EXIT record is in [ROADMAP.md](../ROADMAP.md).
`end_to_end=false`.

## Pinned scope

The selected upstream statement is `zlib/checksum_fuzzer/plain_halts` from
[`bf6a65114ed2e255098e213e183e83f63c2cabcc`](https://github.com/theorem-labs/oss-verify-proofs/tree/bf6a65114ed2e255098e213e183e83f63c2cabcc).
It concerns the plain RISC-V executable with SHA-256
`4f04e95082d3e0baa9d55c72288945d99e64bb7503e39c0e644f4b38a7781af2`.
Its formal statement is:

```rocq
halts_within_budget Budgets.Standard.lim_source Exits.ok_or_refused Images.plain
```

The statement quantifies over valid process inputs and valid entry states.
Under the model's `forced_only` environment, and provided no memory request is
refused for exceeding the 16 GiB budget, every execution must call `exit_group`
with status 0 or 2. It excludes crashes, signals, stuck execution, and infinite
execution within that model. It makes no claim about output bytes. This is the
statement accepted by the complete upstream replay in attempt 0003.
It does not concern other builds, other target architectures, the entire zlib
library, or Forge's ledger and booking claims.

The checker image, platform manifest, Rocq, dependencies, semantics revision,
resource settings, and selected executable are pinned in
[stage7-pins.json](../toolchain/stage7-pins.json). The installed package inventory
is recorded for each run. The image supplies prebuilt model libraries; its
publisher and build provenance remain part of the trusted base.

The recovery check hashed all 201 LPS source files inside the image. Their
aggregate hash matches the pinned upstream Dockerfile:
`c69c38f381767a112d0b4d5692548369f65cbf3a73ba198f76f98310894dd4de`.
The command returned 0. Exact tool executable hashes are also retained under
`results/stage7/commands/recovery-tool-identities/`. These are identity checks,
not proof results.

## Filesystem and user requirements

The upstream tree has 110 groups of case-distinct names, covering 222 paths.
A case-insensitive host checkout cannot preserve these inputs. Do not rename
the files or accept the changed tree.

The recovered checkout resides in the Docker volume
`forge-stage7-upstream-bf6a65114ed2`, on ext4. Its owner is the image's existing
`opam` user, UID/GID 1000:1000. Git and proof commands use that non-root user.
The earlier clone used UID/GID 501:20 against a 1000-owned directory and failed.
No privileged container, global Docker change, or broad host permission change
is required by the recovered path.

The Linux clone shares the Git objects in the read-only mount `/git-source`.
That mount comes from `.toolchain/stage7/upstream/.git` and must remain available.
The macOS working files are not proof inputs. The exact successful fetch, clone,
checkout, dependency-install, and binary-copy commands are retained under
[results/stage7/commands](../results/stage7/commands). A fresh environment must
provide those pinned objects, dependencies, image, and release binaries before
running an EXIT. No clean-host replay result is claimed yet.

## Reproduction and actual checking

From the Forge root, run:

```sh
python3 scripts/exit_stage_7.py --case upstream-replay
```

The runner creates a new attempt directory and retains a named container. It
checks every tracked source file against its Git blob and records a SHA-256
manifest. It checks all case-distinct paths for distinct inodes and confirms the
selected executable's digest. It repeats source and binary identity after a
successful checker run.

The checker runs offline with the pinned CPU, memory, process, and stack limits.
There is no proof time limit. The upstream invocation is equivalent to:

```sh
./oft check zlib/checksum_fuzzer --parts statements,proofs --rocqchk
```

Forge uses a read-only Python trace around the same `oft` module to record actual
`subprocess.run` arguments and return codes. It does not replace upstream
functions, modify return values, alter theorem statements, or determine logical
correctness. All upstream source bytes must remain unchanged.

The upstream tool builds statements and proofs, compiles its own theorem-binding
wrapper, and audits assumptions. With `--rocqchk`, it independently checks the
statements and the proof-wrapper closure using `rocqchk -o -bytecode-compiler no`.
Both independent commands must actually exit 0. A startup check, reused build
output alone, or infrastructure rejection cannot satisfy an EXIT.

Each attempt retains container status, real command codes, full raw checker
output, the upstream work directory, and source identities. Operational paths
and container metadata are not canonical proof evidence. Failed attempts are
never overwritten or reclassified as proof successes.

## Assumptions and remaining gaps

The upstream allowlist contains 98 names: Rocq primitive types and their
specifications, plus six standard-library logical axioms. An audit must report
which are actually used. Both independent passes reported 86 allowed
assumptions in their closures. The theorem-specific wrapper reported 15:
Rocq primitive arrays, integers, and strings; classical logic; and dependent
functional extensionality. The exact names are retained in the raw audits.
Both independent passes returned 0, with no unsafe fixpoints, assumed
positivity, or type-in-type dependencies. Pre/post source and ELF hashes match.

The semantics revision's [scope document](https://github.com/theorem-labs/rocq-linux-process-semantics/blob/f1006fe8178338a499b5e5c41be83006c4edd058/SCOPE.md)
is part of the interpretation. It includes a single-thread model, restricted
signals and files, an 8 MiB stack limit, argument restrictions, and assumptions
about external interference and static ELF loading. Model fidelity to Linux,
the ELF snapshot tool, the kernel and primitive implementations, and physical
execution remain explicit trust boundaries.

The negative-control EXIT returned 0. The prepared bad proof returned 1 with
the intended type mismatch. A separate True certificate compiled with 0, but
the unchanged published binding-wrapper template rejected it with 1 because
its type was True instead of the required binary theorem. Post-check source
and ELF digests match. These are rejection-test results, not another binary
theorem.

The own C binary proof also passed; its exact scope is below. No compiler
correctness, deployment identity, whole-service correctness, or end-to-end
coverage follows from either binary theorem.

## Forge's exact compiled self-test

The [C program and proof](../examples/binary/README.md) concern the 1,240-byte ELF
with SHA-256 `8ced2ab6c7160338899056fe51bacb23d86d81705eacfdd1e992cf5252bdaeb6`.
Two real clang 20.1.8 builds returned 0 and produced identical bytes. The
compiler image, flags, linker, target, C source, and proof sources are pinned in
[stage7-own-pins.json](../toolchain/stage7-own-pins.json).

Its exact termination proposition is:

```rocq
halts_may_fail [verdict_accept] Images.program
```

For every valid LPS process input and entry, every modeled execution terminates
normally with status 0. The environment may refuse any call that LPS permits it
to refuse. The single-binary budget is 16 GiB, with no budget-refusal exemption.
The program computes the fixed pair embedded in its instructions. This is not
GCD correctness for arbitrary numerical inputs or a C source-semantics theorem.

The separate `WitnessSpec.selftest_has_valid_execution` proposition requires
an actual valid input and entry, plus the same termination property there.
Its checked proof uses a concrete valid input and the published constructive
image-entry lemma for this exact ELF. Image validity alone is not used as a
substitute for the witness.

The published `elf-snapshot` tool generated the image directly from the pinned
ELF. The proof applies the published `exits_c` soundness theorem to its checked
execution certificate with fuel 128. The resulting `must_exit_in_scfg` claim
covers all modeled successors and normal termination; it is not bounded testing.
Both bindings use the unchanged upstream `WRAPPER` template. The own runner
uses the published loader, semantics, compiler, wrapper/audit functions, and
independent `_rocqchk` path. It does not add this ELF to the upstream catalog or
replace those components with custom semantics or a custom verifier.

Actual attempt 0001 results:

| Step | Actual exit code | Scope |
| --- | --- | --- |
| Before/after complete upstream identity | 0 / 0 | All 149,053 tracked files; case-distinct paths retained. |
| Published core dependency build | 0 | Existing build reused; no fresh compilation logged here. |
| Image, statement, execution proof, termination proof, witness statement and proof | 0 each | Seven fresh module compilations, including generated image. |
| Termination and witness binding wrappers | 0 / 0 | Exact required propositions; 13 permitted primitive assumptions each. |
| Independent `rocqchk -o -bytecode-compiler no` | 0 | All 579 dependency modules; 86 permitted closure assumptions. |
| Complete own-proof EXIT | 0 | All audits and final source/ELF identities passed. |

The full audit reports no type-in-type, unsafe fixpoints, or assumed positivity.
All opaque dependencies in the required closure went through the real checker.
The unchanged allowlist, full raw output, exact commands, generated sources,
compiled objects, and before/after source manifests are retained in
`results/stage7/own-proof/attempt-0001/`. A post-check SHA-256 inventory of all
579 compiled dependency files is in
`results/stage7/commands/own-compiled-dependency-identities/`; hashing is not
another kernel check.

[Canonical evidence](../results/stage7/accepted/own/evidence.json), the
[full assumption and module audit](../results/stage7/accepted/own/assumption-audit.json),
and the [exact ELF](../results/stage7/accepted/own/gcd-selftest.elf) are published
together. The evidence uses the existing format-1 schema. Schema validation and
two serializations returned 0; a real directory comparison returned 0. This is
deterministic serialization of this actual run, not a second proof replay.
It is unsigned research evidence, not production-policy or deployment approval.

The ELF snapshot loader and `rocq-read-file` data import, prebuilt dependency
provenance, Rocq primitives, LPS-to-machine fidelity, container execution, host
runtime, and hardware remain trust boundaries. The theorem-specific 13
assumptions and the closure's 86 assumptions are separate lists in the audit.
No new axiom or relaxed assumption allowlist was introduced.

On the prepared volume, run `python3 scripts/exit_stage_7.py --case own-proof`.
The two earlier EXITs must have passed with the same pins, and the exact own ELF
must be at `linux_binary` in the own pins. The own example README explains the
build and fresh-volume prerequisites. A clean-host product installer is not
claimed by this result. Per the user's stop instruction, verification-economics
experiments remain deferred; no timing, peak-memory, or speedup claim is made.

## Public operational records

The complete upstream and negative-control records are packaged under
`results/stage7/published/upstream-and-negative/`. The index lists every
original path, size, and SHA-256. The archive uses standard tar/xz; it retains
raw commands, failed attempts, input manifests, proof output, and audits.
Extract it from the repository root with:

```sh
tar -xJf results/stage7/published/upstream-and-negative/records.tar.xz
```

Operational logs include run paths and container metadata. They are separate
from canonical evidence. Original local records remain in place, unchanged.

The completed record set, including the own build and proof, is in
`results/stage7/published/stage7-complete/`. Its standard tar/xz archive and index
preserve the earlier failures as well as the final successes. Extract it with:

```sh
tar -xJf results/stage7/published/stage7-complete/records.tar.xz
```

# Stage 7: binary verification

Stage 7 is in progress. The upstream replay passed with independent checking.
The negative control also passed. The own-binary EXIT remains incomplete. The authoritative
EXIT status is in [ROADMAP.md](../ROADMAP.md). Keep `end_to_end=false`.

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

The own compiled C/Rust binary, its independent kernel check, and the final
Stage 7 evidence bundle remain pending. No compiler
correctness, deployment identity, whole-service correctness, or end-to-end
coverage follows from this setup or from the upstream example alone.

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

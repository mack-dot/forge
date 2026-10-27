# Own binary: fixed-input GCD self-test

This C program computes the GCD of 1071 and 462 in a runtime loop. It calls
Linux `exit_group` with status 0 when the result is 21, or 2 otherwise. An empty
compiler barrier preserves the computation. The executable contains its own
system-call instruction and links no C runtime.

The intended binary theorem is normal termination with status 0 under the
pinned published LPS execution model, for every valid modeled process input
and entry. The program ignores arguments and environment data. This does not
claim GCD correctness for arbitrary numerical inputs, source-level C safety,
compiler correctness, or deployment correctness. `end_to_end=false`.

The C source, compiler image, compiler/linker versions, flags, target, and
resulting ELF must be pinned before proof acceptance. Use the published
`elf-snapshot`, LPS execution lemmas, Rocq compiler, wrapper audit, and full
independent `rocqchk` path. Own-proof attempt 0001 completed with EXIT 0.
The termination theorem, valid-execution witness, and both binding wrappers
compiled with 0. Independent checking returned 0 over 579 modules. Each theorem
audit lists 13 permitted primitive assumptions; the full closure lists 86.
Pre/post source and ELF identities match. The
[complete audit](../../results/stage7/accepted/own/assumption-audit.json) retains
the exact assumption names and module list.

The exact ELF is 1,240 bytes, with SHA-256
`8ced2ab6c7160338899056fe51bacb23d86d81705eacfdd1e992cf5252bdaeb6`.
The two clang 20.1.8 builds in `results/stage7/own-build/attempt-0001/`
returned 0 and produced identical bytes. The target is `riscv64-linux-musl`,
with RV64G instructions and no linked C runtime. Flags and the immutable builder
image are in [stage7-own-pins.json](../../toolchain/stage7-own-pins.json).

`Statements.selftest_halts` uses the published shape
`halts_may_fail [verdict_accept] Images.program`. It has no memory-budget refusal
premise. `WitnessSpec.selftest_has_valid_execution` additionally requires a valid
input and entry and the same termination property at that entry. The witness
uses one empty argument, no environment, an empty initial filesystem, and EOF on
standard input. The published image-entry lemma supplies an entry for this ELF.
It does not replace the universal termination theorem.

The published `exits_c` soundness theorem converts the checked execution
certificate (fuel 128) into `must_exit_in_scfg`. That inductive property requires
progress, excludes errors, and covers every modeled successor until status 0.
The independently accepted result is a termination proof under the model,
not a report that a bounded test found no error.

The proof construction adapts these MIT-licensed upstream files at the pinned
commit, using their existing semantics and soundness lemmas:

- [Exit0Run.v](https://github.com/theorem-labs/oss-verify-proofs/blob/bf6a65114ed2e255098e213e183e83f63c2cabcc/tests/proofs/lib/Exit0Run.v)
- [plain_halts_may_fail/Proof.v](https://github.com/theorem-labs/oss-verify-proofs/blob/bf6a65114ed2e255098e213e183e83f63c2cabcc/tests/proofs/toy/exit0/plain_halts_may_fail/Proof.v)

Forge applies these components to its own compiler-produced image. This is not
an upstream catalog submission. Upstream notices remain in the record archives.
The ELF loader, `rocq-read-file` data import, Rocq primitives, model fidelity,
container provenance, host runtime, and hardware remain trusted boundaries.

On the prepared Linux volume, reproduction commands are:

```sh
python3 scripts/stage7_build_own.py
python3 scripts/exit_stage_7.py --case own-proof
```

Each build retains a new numbered output. The proof reads the exact ELF at
`linux_binary` in the pins; that path must contain the digest above. On a fresh
volume, restore that exact artifact from the public records or a matching
rebuild to the pinned path. Do not change the digest to accept a different build.
The upstream replay and negative control must already have passed with the same
pins. See [the setup record](../../docs/stage7-binary.md) for other prerequisites.

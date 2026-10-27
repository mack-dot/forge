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
independent `rocqchk` path. No proof has been established for this program yet.

# Smallest unresolved runtime check

The open mathematical obligation is a single physical `ffiread` transition
refining the unchanged published `ffi_read`, together with its filesystem and
complete `ffi_interfer_ok` frame. Neither whole-process exit0 nor matching final
stdout supplies that relation.

The smallest next observation is an empty nonblocking stdin pipe with its writer
held open. The actual executable must remain
`b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`.
The recorded command-only observer cannot currently launch even a known-valid
input. Do not retry it without an identified environment change. First validate
an authorized observer context with that unchanged known-valid control. Preserve
the failing context and all current records. Do not change code signatures,
permissions, runtime code or protected configuration to obtain a capture.

Once that prerequisite is met, record one call in the same process:

1. Stop before `read` inside the exact `ffiread`. Record loaded addresses and
   executable/object identity; fd/flags; descriptor bytes; all N+4 buffer bytes;
   saved registers, SP, return PC, and relevant mappings.
2. Step over the actual syscall and stop at the published static disassembly's
   next instruction (unslid Mach-O VM address `0x1000251ac`, adjusted using
   the observed ASLR slide). Record the actual return register before later code overwrites
   it. Record errno only through an existing read-only method with known identity;
   do not inject a function call or infer errno from process exit.
3. Stop at the `ffiread` return (`0x1000251d4` before relocation). Record the
   complete output buffer, saved registers, return PC and observable frame.
   For this pipe, record the offset's lack of applicability rather than inventing
   a seek position. A regular-file error case is a separate later experiment.
4. Compare the bytes with `ffi_read_ready_status` and
   `ffi_read_unavailable`. Preserve any mismatch. Decide whether a valid model
   state relation exists under the existing source premises; do not reinterpret
   a native error as EOF merely because both whole-process runs printed nothing.

This remains a finite experiment. It can expose a mismatch but cannot establish
the universal buffer/register/memory frame. A checked physical proof requires
an established semantics for the exact runtime instructions and the OS call,
plus a concrete filesystem relation. That machinery has not been identified
in the available pinned chain. If it remains absent, mark this link
NOT_ESTABLISHED and disclose any proposed environmental assumption explicitly.
Do not add an axiom, narrow the valid refund inputs, or change the existing
theorem to manufacture closure.

For independent replay, validate a separately controlled authorized ARM64/macOS
environment, independent source acquisition and bootstrap inputs first. Then use
the unchanged [U310 replay plan](../exception-compiler-20261105/records/REPLAY-PLAN.md).
The21 prepared snapshots are source inputs, not proof that these prerequisites
hold. Do not import producer heaps or proof caches as independent evidence.

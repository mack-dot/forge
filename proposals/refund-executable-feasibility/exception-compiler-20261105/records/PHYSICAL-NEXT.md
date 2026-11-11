# Smallest physical FFI obligation — NOT ESTABLISHED

The new compiler theorem has not discharged `is_arm8_machine_config mc` or
`installed ... ms` for the physical process. Within that boundary, isolate one
call to the exact native `ffiread` implementation and the published `ffi_read`
model. This is narrower than a proof of the full C runtime or operating system.

Pinned source: `basis/basis_ffi.c:160` and `basis/fsFFIScript.sml:307`, copied
unchanged under `upstream/`. The runtime C SHA256 is
`e65a58121bcf7c32501ed01f75783f08ec30653192b2265665a9cdae199ab2a1`.
The existing native executable is
`b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`.

Required single-call relation:

1. Bind the actual entry bytes to the pinned runtime object and linker inputs.
   State the pointer validity, buffer lengths, aliasing, descriptor, ABI and
   physical-to-model filesystem relations. Derive guards from the verified
   calling path where possible; do not restrict approved refund values.
2. For each successful or short read, prove the exact returned bytes, count,
   untouched buffer tail and modeled descriptor position. Include zero bytes
   at EOF. Bind any transfer-choice witness to the same filesystem relation.
3. Treat a negative read return separately. C writes `a[0]=1`; the published
   HOL fallback returns the error byte with the original filesystem state.
   The pinned HOL source itself warns that real error behavior may leave file
   position unspecified. No actual Darwin counterexample is claimed here.
   First determine the exact descriptor/OS conditions under which unchanged
   position is justified. If this fails, preserve the counterexample or unmet
   condition. Do not silently assume the relation or alter the approved model.
4. Prove the `ffi_interfer_ok` frame: return PC is saved LR, required registers
   are preserved, state remains valid, and every program-memory byte outside
   the permitted output buffer is unchanged. The exact published predicate is
   copied in `upstream/compiler/backend/semantics/targetSemScript.sml`.

The next concrete experiment is an audit of this one read-error obligation:
compare the exact physical descriptor/syscall contract with the unchanged-fs
fallback in `ffi_read`, using an established C/OS proof framework if available.
No such framework or checked C/POSIX-to-ARM relation is supplied by this packet.
Do not create a custom verifier or accept finite read tests as a universal proof.
If no established method can discharge it, retain the explicit trust assumption
and stop at this obligation. A runtime/specification correction would require
the approved change process; this plan does not authorize one.

The whole-machine memory/entry, installer, interference and space premises also
remain open. U305's separate lower-pass proof work does not close this C/OS
relation. No read-error experiment or fault injection ran in this checkpoint.

Logical `Success` classifies the source/target semantic outcome. Modeled FFI
events describe the abstract oracle. Native process status is an observed exit
code. Physical OS behavior includes actual descriptors, signals and scheduling.
None of these four levels implies the next without its own relation. In
particular, `cml_exit(arg)` calling C `exit(arg)` at line721 does not prove a
universal OS exit0 theorem. Keep end_to_end=false.

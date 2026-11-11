# Smallest remaining correspondence experiment

Do not repeat the blocked local SAT or ARM8 loader diagnostic. Do not launch
another hosted job until the owner approves its concrete scope.

The immediate question is whether the approved physical stdin domain admits
a readable nonblocking pipe that currently has no data and still has a writer.
No proved physical-state relation currently answers that question. The new
status theorem shows why silently assuming a relation is unsound.

Use this minimal paired event case for the next correspondence check:

1. Model configuration: eight zero bytes, so the descriptor is0. Use a
   five-byte FFI buffer `[0w;1w;0w;0w;0w]`, so the request is one byte and
   the existing length guard holds. Preserve `wfFS` and `STD_streams`.
2. Native boundary: descriptor0 is a readable nonblocking empty pipe with a
   writer still open. Use the exact pinned `ffiread` entry and a valid buffer.
3. Check the candidate physical-state relation before and after the call.
   Retain descriptor modes, memory ownership, full buffer, filesystem state,
   initialization, return address, stack, and the complete FFI event.
4. Under documented EAGAIN behavior the C source takes its status1 path.
   The checked HOL theorem forces status0 in the stated model domain.
   Identify the precise relation premise that admits or excludes this case.
   Do not count matching final stdout or process exit as matching events.

Steps1–4 describe a planned refinement check, not a completed native trace or
new theorem. The existing two-case test used a16-byte request, not this one-byte
FFI call. Direct native instruction/frame proof and an internal syscall trace
remain unestablished. The model theorem itself is universal in request length.

First inspect the already approved environment/transport contract and upstream
TextIO relation for the missing domain fact. If no existing approved condition
excludes the native event, a direct event-preserving bridge to this fixed model
cannot cover that case. Stop and prepare an exact change proposal using
established verification infrastructure. Do not alter the approved contract,
drop error events, invent a trusted model, or insert a no-error assumption.

A separate authorized ARM8 store/frame check can still supply useful memory
evidence, but it will not resolve this semantic domain issue. After the relation
is established, close success/partial-read/EOF/write effects, memory/install/
loader/resource premises, and then validate independent replay provenance.
The frozen21-snapshot replay remains separate from this workspace and unrun.

# Next smallest physical ffiread proof step

Status: identified only; NOT RUN by U326. No additional hosted run is authorized.

1. Use a separately authorized run with the same checked runtime/image/input
   identities and public loadHierarchy path. Validate the exact dependency
   closure needed to load the unchanged published arm8_stepLib. U326's18-file
   diagnostic bundle does not contain that complete source/object closure.
2. Start from the preserved U316 evaluator-load input:
   ../native-error-instructions-20261105/records/inspect-arm8-steps/proof.sml.
   Confirm whether its earlier numLib.DECIDE failure persists. A passing SAT
   diagnostic does not prove that every earlier library failure had the same cause.
3. The smallest useful instruction obligation is the published ARM8 step for
   word39000268 at unslid address0x1000251c8,file offset152008:
   `strb w8,[x19]`. Under the exact state/code/address/permission/alignment premises,
   establish the one-byte error-status store and its complete memory/register
   frame. Inspect every generated premise before constructing any composition.
4. Only after that check,compose the preserved error path:
   37f800c0,52800028,39000268,a9417bfd,a8c24ff4,d65f03c0.
   Keep branch,stack,saved-register,return-address and separation premises.
   Require fresh check,repeat,exact import,closure audit,meaningful negative
   controls and byte readback before accepting an instruction theorem.

Existing native executable SHA256:
b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8.
Existing112-byte ffiread fragment SHA256:
ec5f3b8045a2d7038e8645acd7bd72a001bddc75ab24b7fd913c4d36cc163bf4.
These are prior U316 identities,not new native executions or fresh signature checks.

Even a checked six-instruction theorem covers only the post-syscall error
return under its premises. A full physical call must additionally connect the
OS return value,all output bytes,filesystem/offset effects,valid return state
and the complete ffi_interfer_ok frame to the published model. In particular,
read error must not silently imply preservation of buffer or file position.
The published model's error-array/filesystem preservation requirements remain.
No new assumption,restricted input domain,custom semantics or event-trace
weakening is proposed. Native MiniSat's unavailable absolute path also remains
an execution-profile difference; U326 proves no external MiniSat run.

M1 open. Stage12 unauthorized. end_to_end=false.

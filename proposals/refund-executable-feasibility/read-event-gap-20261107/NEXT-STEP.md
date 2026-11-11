# Next executable experiment

The direct basis_ffi/stdin route cannot absorb status1 error events under the
checked guards. The ext parameter does not override read. Do not retry that
composition,drop the event,or insert a no-error transport assumption.

A separate proof through the existing generic FFI rules is a candidate route.
It can retain the actual error event and establish the unchanged library's
exception behavior. It would not,by itself,discharge native read/frame effects,
the refund-level contract mapping,whole-program initialization,compiler premises,
or the original U310 replay claim. Keep those distinctions explicit.

## Unchanged candidate

Source: `records/generic-read-0001.sml`.
SHA256: `7e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6`.
Exact HOL argv,heap,working directory and parent identities are in
`records/generic-0001/command.json`. CPU limit120 seconds. No new semantic
definition or axiom is proposed. The first command is `load "cfLib"`.

That load currently fails through helperLib at numLib.DECIDE. No theorem goal
was reached,so changing the candidate theorem cannot fix this observed failure.
The stderr does not identify an OS syscall or errno. Do not equate it with
the historical mkstemp failure without new evidence.

## Required next action

Prepare a narrowly scoped hosted payload for this unchanged library load and
candidate,using the U326 supported saved-state loading method and private
writable paths. Include the exact CakeML heap,theory closure,library source/
object dependencies,and pinned HOL/PolyML runtime bytes. Check supported path
configuration and exact identities before any external action.

Obtain explicit approval for one additional run and its exact input transfer
before publication or execution. No such approval is currently available.
This document is an execution requirement,not a completed workflow or a request
to approve an unspecified payload. Do not install infrastructure,use sudo,
modify saved states,replace a solver,or alter protected verification machinery.

In the validated context,first execute the unchanged load and capture complete
stdout/stderr and exception location. If it succeeds,run the unchanged candidate
and inspect the actual residual obligation or theorem. Stop on a new environment
failure. Do not claim proof success from a successful library load.

Only after a true generic error theorem is checked should it be composed through
inputAllFrom/refund_main and the compiler,with exact exception,event,memory and
initialization conditions. Compare the resulting behavior to the approved
contract. Any required behavioral/model change needs a concrete separate proposal;
the current work does not authorize that change. Independent21-snapshot replay
remains deferred until its provenance and the required chain are established.

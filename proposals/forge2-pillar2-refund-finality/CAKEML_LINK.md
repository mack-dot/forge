# How the M1 line could discharge the minter's compiler assumption (design note, U424)

Status: NOTE ONLY. Nothing here was run. No HOL context exists on this
machine since 2026-11-17 (U413); the rebuild did not reach the M1
chain (see the Round 2 plan).

## The assumption in question

In the Round 2 experiment the minter decides with the Dafny-generated
JavaScript kernel inside Node. Trusted and unproved there: the
Dafny-to-JavaScript compiler, the adapter, Node, and `minter.ts`. In
the protocol model this is assumption A2 ("the minter signs only when
the relation holds").

## What M1 already has for the decision part (model theorems, U262–U409)

- A CakeML program `refund` that reads one canonical request on
  standard input and writes the six-field decision.
- `refund_profile_a_sl`: for the exact ARM64 machine code of that
  program, under explicit premises (entry state, memory layout,
  environment predicate, canonical input), every run of the model
  machine ends with exactly the output `refund_render_fields
  (refund_fields …)` or stops at a resource limit.
- `byte_fields_result` and the boundary proofs (U295): `refund_fields`
  satisfies the approved decision relation over byte lists. The
  Dafny-to-HOL identification of R1–R5 is reviewed text, not a machine
  check (matrix A8, 18 rows NOT REVIEWED).

So for "decision = the approved relation applied to the request", the
compiler step IS covered by a machine-checked chain for the model
machine. That is the part a CakeML minter would reuse.

## What a CakeML minter still needs (all NOT DONE)

| Need | Why | Size |
| --- | --- | --- |
| The claim format as the program's input and output | today the program prints a decision, not a signed claim | small change of `refund_request` and the renderer, with their proofs |
| Post-state and intent computation in HOL | "post = pre − amount", "intent = plan[0]" are in `minter.ts` today | small; needs a spec decision for the state update, which the approved refund spec does not contain |
| Signature | Ed25519 in CakeML with a functional proof, or signing by a separate trusted component that receives only an accepted decision | large, or a trust decision |
| Key input | a second input channel; the basis FFI model must cover it | medium |
| The M1 assumptions themselves | entry state, loader, real FFI behaviour (`refund_env_ok_sl` is probably false for the real C code at every state), processor | open in M1 |
| Clean and independent replay | never run | owner budget |

## A smaller honest step

Keep signing outside. Let the proved program emit only "ACCEPT
<canonical claim bytes>" or "REJECT". A small signer signs exactly the
bytes after ACCEPT. Then A2 splits into: (a) the M1-style theorem for
the decision program (model, with its premises), and (b) "the signer
signs only what it was given", which is a small trusted component.
The compiler assumption for the decision would be discharged in the
model; the signer and the platform stay in the trusted base.

# Termination by construction (owner item B-7) as the route without a syntactic subset (h-gate; one page; ARGUMENT)

## What B-7 is today
B-7 (OWNER_REQUIRED.md, e-totality) is a SYNTACTIC subset: no loop, no recursion, literal-only products, etc. It
refused 6 of 19 correct files (rule 1) and grew into rule 3. It is a subset, not a construction.

## What "termination by construction" can mean without a subset
1. Dafny already proves TERMINATION of every compiled loop and recursion that has no `decreases *` (the gate
   verifies; `decreases *` is refused by the JS tier: A16/A32 compile to unbounded loops). Termination is
   therefore not the gap. The gap is a BOUND: E08 terminates after 10^18 iterations; H02 after 2^200 calls.
2. A bound by construction needs a COST that the verifier checks. Option T1 (fuel): the approved spec declares
   `method Assess(context, response, ghost fuel: nat) ... decreases fuel` style budget, or a ghost step counter
   threaded through every loop and call, with `ensures steps <= K(|input|)`; the gate checks syntactically that
   every loop body and every call decrements the counter (a SMALL syntactic rule on ghost code, not a subset of
   the compiled language). Option T2 (bounded quantification of `decreases`): require every `decreases` measure to
   be bounded by a literal or by |input|, and multiply bounds along nesting (this is what the JS checker does
   abstractly on the artifact).

## What T1 would prove
"The Dafny semantics of Assess performs at most K(n) counted steps", with K fixed in the approved spec. It would
cover loops, recursion, comprehensions (`seq(n, f)` costs n), and call fan-out. It would NOT cover the cost of one
step: equality on shared nested values (A01: one `==` costs 2^40), BigNumber growth (HV07), string doubling
(HV08): each is one source step. These need a size measure per value (the JS checker's SIZE rule) or a cost model
of each Dafny operation in the verifier (not available in Dafny 4.11: no cost semantics, no `reads` of time).

## What it costs
- A change of the APPROVED spec (spec/refund/RefundSpec.dfy, protected; owner approval; spec.lock change) to add
  the counter and K; every correct submission must thread the counter (all 77 correct files change; authors
  must prove counter bounds: loop invariants on the counter; extra proof work per loop).
- A gate rule that the counter is decremented in each loop body and call (ghost-code syntax check: small, linear).
- The compiler erases ghost code: the counter costs nothing at run time; the bound is about Dafny semantics only.

## What stays trusted
- The Dafny verifier and Z3 (as now); the erasure of ghost code by the compiler.
- The step-to-time relation: one source step can be expensive (see above) => a per-operation cost model or the
  SIZE rule is still needed. The Dafny-to-JavaScript compiler and the runtime (unchanged from today: J2, J3).
- Host limits (input size cap) and the supervision of e-expect/p3 (wall clock) as the last line.

## Judgement
T1 removes the need for a syntactic subset for CONTROL FLOW (loops, recursion, call fan-out) and puts the bound
under the verifier, which is a real improvement over any token or AST rule. It does not remove the need for a
VALUE-SIZE rule (A01, HV07, HV08 are one-step attacks). The cheapest sound combination now: the JS checker
(artifact-level, no spec change) for both; the long-term route: T1 for control flow plus a verified cost model of
the runtime primitives (or the checker itself verified, JS_CHECK_DESIGN.md, last section). Not started; NOT RUN.

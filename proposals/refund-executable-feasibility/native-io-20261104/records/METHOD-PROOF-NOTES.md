# Unfinished method proof — no accepted native claim

Generic EVAL route: five source attempts, all wrapper exit1. Attempts1/2/5
were manually interrupted (HOL child signal2); attempts3/4 failed helper proofs.
The final helper lemmas passed before the broad evaluation was stopped. Do not
run a sixth attempt of this route. No general-heap result theorem was exported.

Characteristic-formula route: method-0001 failed at an untyped AST empty list;
method-0002 failed because xlet_auto cannot handle cf_ref. Method-0003 and0004
remain failed, unaccepted proof attempts. These are not negative test successes.
The current direct diagnostic reaches allocations0–3 with explicit xlet/xref
and complete retained REF predicates. Allocation4 introduces Boolv enabled.
The next check must resolve that exact side goal. Applying Cases_on to the
whole theorem changes free parameters before later quoted postconditions; do
not silently introduce new unconstrained variables in those postconditions.
The raw diagnostics include this failed approach and an invalid PP.depth trace.
At most one further complete attempt remains for this same failing CF proof.
Do not reset the attempt count after a context or turn change.

The current model caller already proves the result under its constructed
primitive state. It does not discharge the library's arbitrary heap/frame
contract. The exact generated method remains unchanged. Its fresh Return
exception stamp is derived from the selected library state; do not reuse a
stamp from a different parent translation without checking it.

The wrapper must also establish its complete I/O behavior. Sexp.inputSexp
leaves a modeled rest; the new wrapper reads that same stream with inputAll
and tests the returned remainder before calling the method and printing.
Source presence is not a whole-program theorem. A tail-guard mutation is being
checked specifically to expose that remaining coverage gap. No native profile,
artifact admission or end-to-end guarantee is enabled by these local proofs.

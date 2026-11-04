# Refund compiler relation — checked local sub-obligation

CURRENT stage:none. Active milestone:M1. Stage12 unauthorized.
Verdict: **PARTIALLY_ESTABLISHED** for the compiler/model link.
Full component executable assurance: **NOT_ESTABLISHED**. `end_to_end=false`.

## Exact checked result

`forge_refund_compile.refund_compilation` establishes that the published
Dafny-to-CakeML translation maps the exact `refund_body` at loop level0 to the
exact CakeML expression `refund_cml`. The expression is computed through HOL's
checked evaluation machinery. A separate equality theorem binds that expression
to the translator result. This is an AST, not a native executable artifact.

`refund_static` discharges freshness, absence of shadowing and absence of
assertions for this body. No assertion is erased from this implementation.
`refund_compiler_relation` applies the published `correct_from_stmt` theorem.
`refund_fields_transfer` carries the six model outputs through its state
relation to actual values in the CakeML model's reference store and namespace.
`refund_compiled_behavior` composes these results.

The final behavioral theorem states: **if** `state_rel` connects the exact
refund initializer to a CakeML state and `env_rel` connects the environments,
**then** some finite added evaluator clock produces the modeled return and
all six correct output values. It also preserves the modeled FFI state, stamp
counters and evaluator state through `cml_state_preserved`.

The outputs are eligibility, amount, reason, charge ID, request ID and intent
count. Eligible inputs retain exact fields and count1. Rejected inputs produce
false, amount0, empty strings and count0. Inputs remain arbitrary model integers
and byte strings. No fixed example replaces these quantified inputs.

The body returns using the compiler's internal `Return` exception convention.
`stmt_res_rel (Rstop Sret)` connects that convention to the Dafny return.
This is not an external exception, process-exit or observable API theorem.
An enclosing checked method/calling wrapper still has to provide that boundary.

## Conditions preserved explicitly

| Relationship | Current evidence | Remaining obligation |
| --- | --- | --- |
| Exact body to CakeML expression | Kernel-checked compilation equality | Native code not produced or bound |
| Compiler static premises | Checked freshness/no shadowing/no assertions | None for this exact body |
| Six outputs in CakeML model | Checked under `state_rel` and `env_rel` | Construct and prove an applicable method entry/calling environment |
| Entry `state_rel` | Explicit theorem premise | Equal clocks, related heap/array mapping and local reference-store/namespace mapping |
| Entry `env_rel` | Explicit theorem premise | Constructor stamps, integer-to-string closure environment and callable/member bindings |
| Approved source to manual AST | Prior source equivalence plus separate model proof | Checked full representation relation remains open |
| Complete approved Unicode domain | Contract unchanged; U+0100 witness preserved | Justified encoding and round-trip/calling relation; no ASCII restriction |
| Returned value to observable API | NOT_ESTABLISHED | Established checked method/ABI or I/O interface |
| Native artifact and runtime | NOT_ESTABLISHED | Verified compilation and exact runtime/environment binding |
| Authenticated admission | NOT_ESTABLISHED | Independently reviewed claim/profile and separately authorized producer/admission |

Do not infer the entry premises from a passing conditional theorem. Do not
infer source translation correctness from matching handwritten predicates.
This experiment adds no precondition to the approved refund specification.
The complete specification remains the target; these are unresolved transfer
obligations, not accepted restrictions on legitimate callers.

## Actual commands and outcomes

`run.py` dispatches the existing pinned HOL4 `Holmake --no-cache -j 2
forge_refund_compileTheory.uo`. Every invocation has an exact argument array,
working directory, source SHA256, actual exit, local wall time and full logs.
It moves only this experiment's prior outputs aside. It does not reuse them as
successful new proof results. Failed proof heaps remain in the raw archive.

| Invocation | Actual exit | Local seconds | Result |
| --- | --- | ---: | --- |
| `python3 -B run.py 0001` | 1 | 12.646558083 | Static proof left the trivial quantified goal; preserved |
| `python3 -B run.py 0002` | 0 | 11.436381291 | Compiler relation checked; output projection not yet added |
| `python3 -B run.py 0003` | 1 | 11.532807417 | New projection script had an unqualified theorem name; preserved |
| `python3 -B run.py 0004` | 1 | 12.714518625 | Projection proof left value equalities unsubstituted; preserved |
| `python3 -B run.py 0005` | 0 | 12.681238458 | Complete output transfer checked |
| `python3 -B run.py final` | 0 | 11.344271750 | Same result after removing an unused existential variable |
| `python3 -B run.py substitution negative-compiled-substitution/forge_refund_compileScript.sml` | 1 | 11.130920416 | Changed compiled expression refused at `refund_compilation` |
| `python3 -B run.py repeat` | 0 | 11.609177791 | Fresh execution; six byte-identical exports |
| Acceptance and exact byte checks | 0 | — | Explicit expected rejection reason and no accepted negative output |
| Fresh HOL closure/theorem inspection | 0 | — |139 theory nodes; no missing parent/artifact; nine own theorems |

The negative changes only the proposed compiled expression to a unit expression.
The translator, source body and required compilation-equality claim stay fixed.
HOL refuses the equality; a parser or infrastructure failure does not count.
The earlier source-level amount-bound and reject-all controls remain in the
parent packet. No new version of those already checked claims was substituted.

Final proof source SHA256:
`17e6b07f69faacb9a6b68e4b538c7f817e7927467fde908809df514bed923f3d`.
Final theorem-data SHA256:
`c422a03764add97460c4280b3aab8015a30be9f4338402b12d27807d9dcf4b25`.
All export identities are in `acceptance-result.json`. Exact theorem statements
are in `proof-final/theory.log` and `closure-audit.log`.

## Checking and trust boundary

This uses the exact CakeML/HOL4/PolyML pins built for the prior experiment.
`parent-identity.json` binds the locally rebuilt parent source and exports.
The parent report was committed locally at
`d0269c051390ffe76b41ba1e522568870f3a4f83`.

The closure audit records139 theory nodes including builtin `min`. The nine
own theorem tags report DISK_THM and zero explicit hypotheses. Conditional
premises inside a proposition are still present; zero explicit hypotheses does
not make them unconditional. The complete import graph includes the same four
HOL foundation axioms: SELECT_AX, INFINITY_AX, ETA_AX and BOOL_CASES_AX.
No new axiom, oracle, machine model, verifier or acceptance framework was added.

The trusted base remains the HOL4 standard kernel, source elaboration and pinned
library builds, Poly/ML, GMP and the host. Fresh replay of the proof source is
the checking method. Exported theory data and hashes alone are not authenticated
provenance. The experimental checker/profile has not entered protected policy.

Reproduction: build the pinned parent tools and source theory using the parent
packet's instructions. Set process-local HOLDIR and CAKEMLDIR to those builds.
Create a new directory under CakeML's `compiler/dafny/`, copy the proof source
and Holmakefile, and run the recorded Holmake command. Run each negative and
repeat in a fresh result directory. Retain all actual outcomes and inputs.
The archived Python runner uses the original absolute paths; do not overwrite
old results when reproducing it elsewhere.

## Smallest next action

Use the published method/calling proof to construct an applicable entry and
return interface for the exact refund method. Prove the state/environment
premises and carry the tuple of outputs to the caller. In parallel logical
scope, preserve the full Unicode representation obligation; do not use upstream
Print as an observable-output proof. Then bind verified native compilation and
its explicit runtime assumptions. No new infrastructure is required by these
current findings.

No native refund execution, hosted refund run, signing, publication, merge,
policy adoption, admission or deployment occurred. All durations are local.
Hosted measurements remain NOT RUN. Operational backup and review controls
remain separate from these mathematical obligations. M1–M4 remain open.

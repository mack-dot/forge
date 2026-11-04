# Refund model caller — checked entry and returned tuple

CURRENT stage:none. Active milestone:M1. Stage12 unauthorized.
Verdict: **LOCALLY_VALIDATED** for this exact model caller.
Full executable-level refund assurance: **NOT_ESTABLISHED**.
`end_to_end=false`. The previous goal turn made verified progress; this run
continues the same full refund R1–R5 target and adds no acceptance authority.

## Assurance link closed

The prior body-to-CakeML theorem required `state_rel` and `env_rel` for an
unspecified caller. This experiment constructs a particular complete model
caller and checks its actual behavior in the published CakeML semantics.
It uses the existing compiler's generated method wrapper and return handler.
It introduces no verifier, machine semantics, axiom or proof framework.

`forge_refund_call.refund_method_compilation` binds the exact refund method to
its generated CakeML declaration. The method has nine input fields and six
output fields. Its body is the already checked `forge_refund.refund_body`.

`forge_refund_call.refund_caller_returns` proves the following for every typed
model input and arbitrary modeled FFI state:

- Start with CakeML's standard primitive state and constructor environment.
- Supply the nine inputs through the explicitly defined argument namespace.
- Declare Return and the generated recursive method closure.
- Invoke the fixed caller expression with the arguments in the compiler's
  required order. Allocate local references and execute the method.
- Catch the compiler's internal Return exception and bind the returned tuple
  to `answer` in the resulting namespace.
- Return all six required values and preserve the modeled FFI state.

The expected tuple contains eligibility, amount, reason, charge ID, request ID
and intent count. Eligible inputs retain their exact values and count1.
Ineligible inputs return false,0,three empty strings and count0. The theorem
checks all mathematical integers, booleans and model byte strings. It does not
replace the complete approved Unicode contract with a restricted contract.

The fixed caller/program AST contains variable references, not one hard-coded
input example. Input values vary in the constructed initial namespace.
The theorem has no remaining generic state/environment-relation premise.
This closes entry and return handling for this model caller. It does not assert
that a native executable or physical caller establishes this namespace.

The evaluator uses clock32. This is sufficient modeled call fuel, not a bound
on wall time, CPU instructions, memory use or physical process termination.

## Exact identities

Parent source/proof record commit:
`77ab7003bc11058954715535cd40ecd0ef005e7d`.
The pinned CakeML, HOL4 and Poly/ML commits are unchanged from the parent packet.
`parent-identity.json` records the exact local parent/compiler/semantics sources.

Final proof source SHA256:
`081becc8f43334e716d8d7657c65740394d554e812ded8bdc169bffac2c022fe`.
Theorem-data SHA256:
`d756c352edb5dee390d9004976a07ecd25d16cacf7b2aac7dec467ab19f996cd`.
`acceptance-result.json` records all six export hashes and their comparison.
The exact theorem statements are in `proof-0003/theory.log` and
`closure-audit.log`. Hashes establish identity, not producer authenticity.

## Actual execution and failures

Each `run.py` invocation dispatches the same pinned HOL4 command:
`Holmake --no-cache -j 2 forge_refund_callTheory.uo`.
Exact argument arrays, source snapshots, working directories, exits and elapsed
times are in the per-attempt command records. No old exported result is treated
as a new execution. Prior outputs are moved aside and retained.

| Invocation/check | Actual exit | Local wall seconds | Result |
| --- | --- | ---: | --- |
| `python3 -B run.py 0001` | 1 |189.569816208 |15 dependency theories built; own universal proof incomplete |
| Concrete diagnostic through HOL EVAL | 0 | — | Valid example returns the correct tuple; not universal acceptance |
| Unresolved-goal diagnosis | 0 | — | Exposed inconsistent conditional-Boolean assumptions; not a passing theorem |
| `python3 -B run.py 0002` | 1 |331.425340333 | Operator SIGINT after expensive broad rewrite; child signal2; no proof result accepted |
| `python3 -B run.py 0003` | 0 |74.594393292 | Universal caller theorem checked with narrow proved Boolean equalities |
| `python3 -B run.py swapped-ids ...` | 1 |71.976539459 | Caller-bound identity claim refused |
| `python3 -B run.py missing-argument ...` | 1 |16.748310667 | Missing input binding refused |
| `python3 -B run.py repeat` | 0 |69.620541958 | Fresh theorem execution; six byte-identical exports |
| Acceptance and export comparison | 0 | — | Both intended refusal reasons checked; no accepted negative exports |
| Fresh HOL closure inspection | 0 | — |156 theory nodes; three own theorems; no missing parent/artifact |
| Original owner-workspace input postflight | 0 | — |30 frozen inputs unchanged |

The first proof attempt left an impossible case: a conditional Boolean was
neither the True nor False constructor. Its failed proof state is preserved.
The second used broad conditional-distribution rules and was manually stopped.
That interruption was not an automatic timeout or a successful negative test.
The third adds two Boolean equalities proved by cases in HOL. The program and
required return theorem are unchanged. No domain, precondition or assertion
was weakened to make the proof pass.

## Caller-boundary adversarial controls

The acceptance plan was recorded before the controls ran. Both mutations keep
the generated method, approved parent body, expected tuple and return theorem
unchanged. They alter only the caller boundary.

| Mutation | Actual refusal reason |
| --- | --- |
| Swap charge/request argument positions | Unsolved `request = charge ∧ charge = request`; caller identity is not preserved for arbitrary distinct IDs |
| Rename the required arg0 binding | Return theorem reduces to false; the missing caller input does not count as a successful call |

Both fail at `refund_caller_returns`, with no accepted exports. Infrastructure
or parsing failures would not satisfy the controls. Prior bound, always-reject
and compiled-expression substitution controls remain unchanged in their own
packets. The initial concrete valid example remains only a diagnostic witness.

## Checking and remaining trust boundary

The checking method is fresh source execution through the existing HOL4 kernel
and published CakeML semantics. The imported graph has156 theory nodes,
including builtin min. Its four foundation axioms remain explicit:
`bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX`, `bool.BOOL_CASES_AX`.
The three own theorem tags contain DISK_THM and zero explicit hypotheses.
No new axiom or oracle was introduced. Imported libraries, source elaboration,
Poly/ML, GMP and the host remain in the stated trusted base. Loading untrusted
candidate exports is not an independent replay or provenance check.

| Boundary | Status |
| --- | --- |
| Generated method identity | CHECKED in HOL |
| Modeled primitive initialization and supplied typed arguments | EXPLICITLY CONSTRUCTED and checked |
| Call order, local references, Return handler and result tuple | CHECKED for every typed model input |
| Caller ID substitution and missing argument | REFUSED by the unchanged theorem |
| Original Unicode source to byte representation | NOT_ESTABLISHED; full approved domain retained |
| Physical input decoding and native calling convention | NOT_ESTABLISHED |
| Exact native artifact, runtime/loader relation and observed run | NOT_ESTABLISHED |
| Authenticated claim/profile and independent admission | NOT_ESTABLISHED; separate review/authorization required |

No direct native ABI or operating-system entry was proved. The constructed
namespace supplies typed values; it is not a verified network, file or CLI
parser. No bank/refund effect is executed: the approved component creates a
refund intent. M1–M4 remain open. Hosted refund execution and metrics are NOT RUN.
All recorded durations above are local proof observations, not performance
savings or hosted runner cost.

## Reproduction and next action

Use the unchanged pinned parent source builds. Place this source and Holmakefile
in a fresh directory under CakeML compiler/dafny. Set process-local HOLDIR and
CAKEMLDIR to those exact builds. Run the recorded Holmake command. For each
negative, use its retained source in a fresh output directory and require the
specific theorem failure. Restore the original source, execute again with no
cached own exports, and compare all output bytes. The retained runner records
the original absolute paths; use fresh paths for independent reproduction.

The next required correspondence is the full Unicode/byte representation and
input/output boundary. Establish an injective, empty-preserving representation
that preserves the exact ASCII reason literals and round-trips caller IDs.
The existing U+0100 control forbids low-byte truncation. Then connect this same
fixed method to an established native compiler and calling/I/O interface.
Do not add general CLI, caching or infrastructure work while this link is open.

No protected source or acceptance policy changed. No publication, merge,
dispatch, signing, admission or deployment occurred. Off-machine archive hash
and restore validation and independent review remain separate open controls.

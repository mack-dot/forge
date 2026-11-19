# JS bound check: design (h-gate, 2026-11-19). PROTOTYPE; nothing applied; claim = ARGUMENT, not a proof.

## What it checks
`js_bound_check.cjs` reads the JavaScript that the pinned Dafny 4.11.0 generates for impl/Refund.dfy: the gate
build (`dafny build --target js`, runtime prefix + modules) or a translation (`dafny translate js`, modules only).
It parses the module with the pinned TypeScript parser (5.9.3, `require('typescript')`; real syntax tree; names
resolved by scope, not by token). It refuses (fail closed, one reason code) unless all of these hold:
1. SHAPE/RUNTIME: the runtime prefix (lines 1-1188) has the pinned SHA-256; the top level holds only module frames
   `let M = (function() { let $module = {}; ... return $module; })();`; only `Refund` holds code; another module
   is empty and its name is not a JavaScript, global or runtime name (A03: `require`, `BigNumber`).
2. SPEC_TYPE/DATATYPE: the four approved datatypes are byte-identical to the approved compiled text (pinned
   digests); a user datatype holds only the members Dafny generates for a datatype, in their exact forms; field
   names are not runtime or Object.prototype names.
3. NAME/CALL: every identifier is a local, a parameter, or one of `_dafny`, `BigNumber`, `Refund` in a fixed form.
   Every call resolves to a static member of `Refund.__default`, a datatype constructor or `Default`, an
   immediately invoked lambda (Dafny let/match expressions), or an allow-listed runtime primitive (table COST).
   Anything else is refused: `this`, `new` (except BigNumber literals, CodePoint literals), function values,
   `for...of` (such-that search, comprehensions over ranges), `throw` (HALT: `expect`, failed `:|`).
4. LOOP/RECURSION/COST/SIZE: an ABSTRACT INTERPRETER runs `Refund.__default.Assess` once on symbolic inputs.
   Integers carry exact BigInt intervals where the code makes them exact; sequences carry length intervals.
   It unfolds every loop while its condition is not DEFINITELY false and the body can reach the next iteration
   (cap TRIP_MAX = 4096 per loop), and every recursion (including Dafny's `TAIL_CALL_START: while (true)` form)
   up to DEPTH_MAX = 64. Both branches of an `if` run unless the condition is definite. Every value carries a size
   bound a*N + b (N = input size; ints: bits; sequences, sets, maps, tuples, datatype values: tree nodes with
   SHARING COUNTED AS COPIES). Caps: a <= 16, b <= 2^20; abstract steps <= 10^6; weighted primitive cost
   c0 + c1*N + c2*N^2 with c0 <= 2^30, c1 <= 2^20, c2 <= 2^12 (L = linear, Q = product, S = square of the sum).
5. INPUT: modules over 1 MiB or bracket nesting over 200 are refused by a linear scan before parsing; a
   RangeError inside the checker is a refusal (CHECKER_DEPTH). The gate runs the checker in a child process with
   a 120 s bound (RESOURCE_LIMIT on timeout or signal; any non-ACCEPT line is a refusal: fail closed).
6. LOAD (hostile tier, full build only): the module (+ the gate footer) loads in a child Node with a scrubbed
   environment, 2 s SIGKILL, 200 MB heap, and exports `Refund.__default.Assess` with 2 parameters (P03:
   `static prototype` is a SyntaxError). The shape check runs first, so loading runs only module frames and
   class definitions.

## Which rule owns which unsafe class (the hybrid)
| class | owner |
|---|---|
| `expect` / run-time halt | source rule `expect` (e-expect) AND JS `throw` refusal (HALT) |
| unbounded loop, data-dependent loop, such-that search | JS LOOP / STATEMENT (for...of) |
| unbounded or exponential recursion | JS RECURSION / COST |
| huge allocation (`seq(n, f)`, comprehensions) | JS LOOP (Seq.Create length interval) |
| equality on shared nested values (B1, A01), string/sequence growth | JS SIZE (tree size with copies) |
| BigNumber growth (squaring, products in loops) | JS SIZE (bits add under `*`) and COST (Q) |
| exponential call fan-out (HV06, Y06) | JS COST (steps unfold every call site) |
| JavaScript name collisions (B3, P03) | JS NAME (module names) and LOAD |
| abstract module with an unchecked lemma (A11) | source rule `abstract` (new; the compiler drops it) |
| attributes, includes, CRLF, comments | source scope rules (scope-minimal + `@` by the expect lexer) |
| recognizer DoS (C-GATE-02: deep `{` nesting) | source lexer: one linear pass, 256 KiB and nesting 64 caps |
| time-of-check/time-of-use (C-GATE-03) | read once in main(): scope rules, identity(), snapshot share bytes |
| wall-clock or memory exhaustion that escapes all of the above | supervision (e-expect p3): RESOURCE_LIMIT |
Rule 3 (the Dafny-token recognizer) is NOT needed: no piece of it is kept except the idea of `abstract`.

## Trust claim (ARGUMENT)
If the checker accepts M, then one call of Assess, under the JavaScript semantics of the pinned Node and the
runtime prefix with the pinned digest, evaluates at most S = steps syntax nodes of M and calls primitives of total
cost at most c0 + c1*N + c2*N^2 unit operations, and every value it builds has at most 16N + 2^20 nodes or bits.
Reason: (a) the shape and name checks leave no code path except the interpreted ones (no dynamic dispatch except
datatype `equals` reached through areEqual, whose cost is linear in the operand trees); (b) the abstract domain
over-approximates every concrete state (intervals and size bounds are monotone under join; a dead branch is
skipped only when its condition is definite); (c) therefore each concrete loop iteration and call is matched by
an abstract one, and the abstract run is finite and within the caps; (d) each primitive's cost is within its
class in the sizes of its operands (table COST, read from the runtime source, not measured).

## Assumptions (named)
- J1 PARSER: the TypeScript 5.9.3 parser builds the same tree as Node 24.3.0 for these files (syntax errors that
  TypeScript tolerates are refused: PARSE; Node-only errors are caught by LOAD in the hostile tier).
- J2 DAFNY OUTPUT: the input is the output of the pinned Dafny for a well-typed program; a method name such as
  `plus` is therefore called on the runtime type it names. `translate js` equals the user part of `build`
  (TESTED on 1 file: impl/Refund.dfy, byte-equal).
- J3 RUNTIME TABLE: the cost class of each allow-listed primitive (COST) matches the pinned runtime prefix and
  BigNumber 9.x (schoolbook multiplication and division are quadratic in digits). Read, not proved.
- J4 HOST: Node, V8 and the OS keep their documented semantics; the caller caps the input size N.
- J5 CHECKER: the checker itself (about 700 lines) is correct. It is NOT verified. Its mutants (5) each admit a
  named unsafe file, which shows each check is load-bearing, not that the checker is complete.

## Known limits (refused by design: category C) and open points
- A loop or recursion whose bound depends on input data (e.g. `while i < |context.chargeId|`) is refused.
- Datatype `Default()` of the four spec types is taken as size 32 (fixed text); user `Default` is interpreted.
- The critical tier runs the check with `--no-load` on `translate js` output; LOAD is owned by the hostile tier.
- Production builds (scripts/build_model.py, protected) do not run the check yet: follow-up owner action.
- Red-team target: any accepted file whose real run exceeds the stated bound refutes J3 or the checker (J5).

## What would make it a proof
(1) A cost semantics for the admitted JavaScript subset (or for Dafny's compiled IR) and a mechanized proof that
the abstract interpreter is sound for it (abstract interpretation in Coq/Isabelle, or the checker written and
verified in Dafny over a JS AST datatype, with the runtime primitives as specified cost axioms).
(2) Or a verified translation: a cost-annotated Dafny-to-JS compiler fragment, so that a source-level cost proof
(Dafny `decreases` plus a fuel bound) transfers to the artifact.

# Bounded straight-line subset for impl/Refund.dfy (PROPOSAL; checker `subset_rule.py`; not applied)

## Scope and shape
- The file is exactly: `include "../spec/refund/RefundSpec.dfy"` and ONE `module Refund refines RefundSpec { ... }`.
  Nothing follows the module. No other module, `import`, `export`, `abstract`, `refines`, `include` (code SHAPE, FORBIDDEN).
- Module members: `function`, `predicate`, `method`, `lemma`, `const`, with the modifiers `ghost`, `static`, `opaque`.
  No `datatype`, `type`, `newtype`, `class`, `trait`, `iterator`, `codatatype`, least/greatest/twostate (DECLARATION).
- A member is GHOST if it is a `lemma` or carries `ghost`. Everything else is COMPILED. Each function, predicate,
  method and lemma needs a body (SHAPE). A compiled `const` needs an initializer.

## Everywhere (ghost code too), outside comments and literals
- Forbidden words: `expect`, `assume`, `print`, `new`, `array*`, `bv*`, `iset`, `imap`, `yield`, `modify`, `label`,
  `extern`, `axiom`, `:-`, `by method`, `decreases *`. Attributes: only `{:isolate_assertions}`; no `@`; a `{`
  followed by `:` across a comment is an attribute (ATTRIBUTE).
- Lexing fails closed (LEX): not UTF-8, NUL, any non-ASCII character or whitespace other than space, tab, CR, LF
  outside comments and string literals, an unterminated comment or literal. A `//` comment ends at the earliest
  CR, LF, VT, FF, NEL, LS or PS. File <= 65536 bytes; string literal <= 256, number <= 40 characters.

## Compiled code (bodies of compiled members, compiled const initializers)
- Ghost statements are skipped and NOT executed: `assert ...;`, `assert ... by {...}`, `calc {...}`, `reveal`, `hide`,
  `ghost var ...;`, a call of a lemma or ghost method. A skipped statement must not name a compiled method (GHOST).
- Allowed: `var`, `:=`, `return`, `if`/`else`, `if-then-else` expressions, `match` and `case`, comparisons,
  `&&` `||` `!` `==>` `<==>`, `in` `!in`, `|s|`, indexing and slices, `.field`, constructors and discriminators, string
  literals and equality, calls to the pinned spec predicates (Eligible, ValidContext, Money, AllowedReason) and to
  compiled local members.
- Forbidden (EXEC_FORBIDDEN): `while`, `for`, `forall`, `exists`, `::`, `:|`, `seq(`, `set`, `multiset`, `map`, `old`,
  `fresh`, `this`, `break`, `continue`, `by`, function types `->` `~>` `-->`, `!!`, specification clauses in bodies.
- Lambdas: a `=>` is allowed only after a `case` pattern (LAMBDA). Function types in a compiled signature, and default
  parameter values, are refused (HEADER). A spec predicate or compiled function used as a value is refused (FUNCTION_VALUE).
- Arithmetic (ARITHMETIC): `*`, `/`, `%` need an integer-literal operand. `+` needs an integer-literal operand, a
  length `|e|` operand, or a parenthesized `if ... else <literal>` operand. These operand shapes type the `+` as integer
  addition, so `+` can never be sequence or string concatenation. `-` is free (ints: one more bit; no sequence `-`).
- Braces (BRACE): a `{` must open a block (after an `if`/`match` guard, `else`, `=>`, `{`, `}`, `;`). Set and map
  displays outside an `if` guard are refused.
- Sequence displays (DISPLAY): at most 16 elements; each element is a literal, a nullary constructor, a spec record
  application (`Intent(...)`, `Authorized(...)`, `Candidate(...)`, `ChargeContext(...)`), a spec predicate call, or a
  boolean expression. Tuples (TUPLE) obey the same element rule, plus one sequence display as an element.
- Calls (RECURSION, SIZE): the call graph over compiled members (including const references) must be acyclic.
  Unfolded weight W(m) = executed tokens of m + 128 per spec-predicate call + W of each called local member (per call
  site). W(m) <= 4096 for every compiled member. W(Assess) is the bound N.

## Why there is no repeated doubling or exponential evaluation
- No loop and no recursion: each token of a body runs at most once per call. Each call site runs at most once per run
  of its caller, so one Assess run executes at most N = W(Assess) tokens (call trees are counted unshared, so a
  tower of helpers that each call the next twice reaches the cap: HV06 refused).
- Growth needs an operation whose result is larger than a constant plus its operands' sum, or a shared value used
  twice inside one larger value. `*` of two non-literals (squaring) is refused. `+` is typed integer and adds one bit.
  Sequence concatenation is unreachable. Displays and tuples cannot nest submission-built containers. The spec
  datatypes are not recursive and hold only int, bool and string fields.

## Totality claim (class: ARGUMENT about the subset, TESTED on the corpus; NOT machine-checked)
For an admitted submission and ANY typed input (context, response), one call of the compiled Assess executes at most
N = W(Assess) <= 4096 source-level operations (each pinned spec predicate counted as <= 128) and allocates at most N
objects. It makes at most (number of compiled members + 1) nested calls (stack depth bounded by program text).
Every integer value has at most B + 133*N bits and every string or sequence value has at most S + 16*N elements,
where B, S are the largest input or literal sizes. NOT BOUNDED by the rule: the cost of one operation on an input-sized
value. BigNumber `+`, `-`, comparison and multiplication by a literal cost O(bits of the operand); string and
sequence equality, `in`, and slices cost O(input length). So time is O(N * input size), linear in input size; memory is
O(N * input size). The input size itself (amount digits, reason length) is not bounded by Assess; the host decoder
must bound it. The argument also assumes: Dafny's JavaScript compiler maps each source operation to O(1) runtime
operations plus the operand-size cost above, erases ghost code, and adds no loops of its own; Node does not fail
on objects of the sizes above. A compiler or runtime bug breaks the claim.

## What a machine-checked version would need
A formal grammar of the subset over Dafny's resolved AST (not tokens); a cost semantics of compiled Dafny (or of the
generated JavaScript) with BigNumber cost; a mechanized proof that every program in the grammar has cost <= f(N, input
size); and a verified link from the checker's accepted set to that grammar (for example, the checker emitted as a
Dafny/HOL function and proved sound). None of these exists today.

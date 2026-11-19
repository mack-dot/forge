# Rule 3 design note (orch-B/e-subset3, night shift 2026-11-19). PROPOSAL; nothing applied.

## Choice
Choice (A), the strict core, with two additions that the review lessons force: a small KIND system and a
TREE measure. Choice (B) is an optional extra tier, not a guarantee. Choice (C) is the right long-term route.

Why not more token rules. Rule 2 argued about cost from token shapes. It broke on aliasing (B2: a local with
the name of a constant), sharing (B1: a DAG of displays) and name resolution (B3: a JavaScript name). Each
of these is a property of RESOLVED names and VALUES, not of tokens. Rule 3 therefore parses: it is an
allow-list recursive-descent recognizer with a name table and a kind for every expression. Anything it
cannot parse as an admitted form is refused (reason code SUBSET3_*).

## Admitted forms (complete list; everything else is refused)
- Exactly `include` + `module Refund refines RefundSpec { ... }`. No other module (A03, B3).
- Members: `const`, `function`/`predicate`, `method` (compiled); `lemma`, `ghost function|predicate|method|const`
  (ghost: skipped; the compiler erases them). Attributes only `{:isolate_assertions}`, `{:induction false}`.
- Compiled statements: `var` (typed or not, tuple pattern), assignment, `if`/`else`, `match { case }`, `return`,
  block, call of a compiled method (acyclic), and the ghost forms `assert [by {}]`, `ghost var`, lemma call.
  No `while`, `for`, `forall`, `break`, `label`, `:|`, `*` (havoc), lambda, `as`, indexing, slicing.
- Expressions: literals (decimal int <= 19 digits, string <= 256 chars, char, bool), names, fields of the four
  spec datatypes, discriminators, tuple selectors, constructor calls, `[..]`/`{..}` displays (<= 16 elements),
  tuples, `|x|`, if-then-else, match, `! - + - * / %`, comparisons, `in`, boolean connectives, calls of the
  four spec predicates and of compiled functions.
- Kinds: `+ - * / %` need two `int` operands (so string, sequence and set growth by `+` is refused: Y46, Y47).
  `*` needs a numeric literal on one side; `/ %` need a non-zero literal divisor.
- Helper parameters have fixed-shape types only (int, nat, bool, string, char, Context, ModelResponse,
  Decision, RefundIntent). Results may be sequences or tuples; their tree size is computed from the body.
- Names: every parameter, local, pattern variable and member name is new: not a spec or module name, not
  reused in the same member (even in disjoint branches), not a JavaScript reserved or global name, shape
  `[A-Za-z][A-Za-z0-9_']*` without `__` (A08, A09, A10).
- `{` in an if/match statement guard is refused (W3, HV23, HV26): Dafny's brace rule is not modelled.
- Comparison chains: an inner operand is compiled TWICE by Dafny (seen in js/Y14-*.js). It may not contain a
  call, `if`, `match` or a member name, and it is counted twice in W.

## Measures (computed by the recognizer)
- W = compiled tokens of a member, plus W(callee) per call site, plus 128 per spec predicate call, plus
  W(const) per constant reference. The call graph must be acyclic (A10, Y31, Y32). W <= 4096 per member.
- T = node count of a value, sharing counted as COPIES: literal/field/scalar = 1; display, tuple, constructor
  = 1 + sum of the parts; if/match = max of the arms; a local = max over all its assignments in text order.
  Fixed-shape parameters use their type size (Context 7, ModelResponse 3, Decision 3, RefundIntent 5). T <= 32.

## Trust claim (ARGUMENT, not machine-checked)
If rule 3 admits impl/Refund.dfy and Dafny verifies it, then one Assess call, as Dafny's semantics defines it,
executes each compiled source token at most once per unfolded call site (no loop, no recursion), so at most
W <= 4096 token evaluations (2 per chain-inner token). Every value is a tree of at most 32 nodes. Every leaf is
a literal, an input field, or an integer of at most I + 64*W bits (I = bits of the largest input integer:
each `+`/`-` adds 1 bit, each `*` by a literal below 10^19 adds 64 bits, `/ %` do not grow). Strings and
sequences never grow: no `+` on them, no slice. So each operation costs O(32^2 * (n + 64*W)) machine steps for
input size n (equality and membership compare at most 32x32 leaf pairs), and one run costs
O(4096 * 32^2 * (n + 2^18)): linear in the input, with an explicit constant. Recursion depth is the call-chain
length (< number of members). No program in the subset can loop, recurse or allocate more than that.

## Residual risks (not covered by the claim)
1. The Dafny-to-JavaScript compiler and runtime: code shapes (chain duplication was found; others may
   exist), `_dafny.Seq`, `areEqual`, BigNumber. TESTED-UNPROVED on 14 admitted attacks (js/), not proved.
2. BigNumber cost is linear in the digits of input integers; string compare is linear in input length. The
   bound is linear in n, not constant: the caller must cap the input size.
3. The lexer and parser are mine, not Dafny's. A disagreement in lexing (comments, strings, Unicode) can
   hide code. The rule-2 lexer was tested against Dafny controls L01-L19, K01-K08; rule 3 also refuses
   a backslash before a line break in a string (K01). This is the weakest link.
4. Ghost erasure is trusted (Dafny refuses compiled use of ghost entities). HV15 and Y17: the JavaScript
   contains no call of the ghost method (checked by grep, see report).
5. Name mangling: Dafny prefixes locals (`_0_eq`); member names are probed (P01-P03). The deny-list stays.
6. Kind inference is mine. A wrong kind could admit `+` on a sequence. Kinds come only from declared types,
   literals and constructor signatures; empty displays have an unknown element kind and never allow `+`.

## (B) A metered corpus tier
Running the compiled program on a fixed adversarial corpus under a step meter only shows the cost on those
inputs. A trigger on one input value (HV22, Y24, Y25 use amount == 123456789) is missed unless the corpus has
that value; search for such values is undecidable in general. So (B) gives no guarantee. It is still worth a
cheap tier: it would catch compiler-shape surprises (risk 1) on the canonical inputs. Not implemented here.

## (C) A parser-based rule
A rule over Dafny's own resolved AST removes risks 3, 5 and 6: names are resolved, types are known, ghost
status is the compiler's own. Need: a pinned `dafny` front-end entry (e.g. a small C# plugin or the
`--print` resolved program) that emits the compiled declarations as JSON; a checker over that JSON with the
same forms and measures; tests against this corpus. Estimate: 2-4 days of work plus a review; the plugin is
new trusted code in the toolchain lock. A HOL or Dafny proof of the cost claim over that AST is further work.

## Price (measured, pure Python; see report)
Rule 3 refuses loops, recursion, non-literal products, extra modules, local datatypes, maps, labels and
string `+`. Measured: 31 of 36 known correct, 46 of 67 correct files in total.

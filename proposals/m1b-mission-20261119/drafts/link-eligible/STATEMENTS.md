# M1-B step I.1b — eligibility link: exact statements and trust boundary (DRAFT)

Worker W2. Nothing in this folder has run. No statement below is proved until
the commands in `RUN_PLAN.md` give their expected exit codes. "Checked" in
this file means "intended to be checked by the named tool".

## 1. Chosen route and why

The approved text `RefundSpec.Eligible` cannot go through the pinned
CakeML Dafny front end as it is. Exact blockers (file:line):

| Feature used by the approved text | AST / semantics | Exporter (patched `Bake.cs`) | Result |
| --- | --- | --- | --- |
| datatypes `Context`, `ModelResponse`; `.Candidate?`; field select | no datatype type or value: `dafny_astScript.sml:11-17`, `dafny_semanticPrimitivesScript.sml:20-27`; program = one default class, `dafny_astScript.sml:127-131` | only a default class is accepted, `Bake.proposed.cs:50-53`; `MemberSelectExpr` only for array `Length`, `:491-503` | NOT SUPPORTED |
| set display membership `reason in {…}` | no set type or value (same lines) | `SetDisplayExpr` only as an empty frame, `:81`; `InSet` is not in the opcode map, `:579-597` | NOT SUPPORTED |
| `\|s\|` (string length) | `ArrLen` works only on `ArrV`, `dafny_semanticPrimitivesScript.sml:292-295` | unary map has only `BoolNot`, `:573-577` | NOT SUPPORTED (use `s != ""`) |
| string `==`, `!=` | `StrL mlstring` `dafny_astScript.sml:31`; `StrV`, `Eq`/`Neq` through `value_same_type`, `dafny_semanticPrimitivesScript.sml:217-237` | `SeqEq`/`SeqNeq` mapped only for two string operands, `:406-409` (patch) | SUPPORTED |
| chained `0 <= x <= y` | no node; Dafny resolves it to `&&` of two `<=` | exports the resolved form; visible in the real export (`BinOp And (BinOp Le …) (BinOp Le …)`) | SUPPORTED through resolution |
| `>` | no `Gt` in `bin_op`, `dafny_astScript.sml:24` | only `Lt`, `Le`, `Ge`, `:581-583` | NOT SUPPORTED (avoid) |
| `<==>` | none | `Iff` → `Eq`, `:586` (patch only) | SUPPORTED with the patch |
| `&&`, `\|\|`, `==>` | short circuit `do_sc`, `dafny_semanticPrimitivesScript.sml:197-211`; `evaluate_exp` BinOp, `dafny_evaluateScript.sml:55-68` | mapped, `:579-597` | SUPPORTED |
| function / predicate | `Function` member `dafny_astScript.sml:112-113`; `FunCall` `dafny_evaluateScript.sml:86-107`; parser `sexp_to_dafnyScript.sml:560-572` | `Bake.proposed.cs:123-140`, `:475-490` | SUPPORTED (route 1b) |

`Bake.proposed.cs` is the U294 patched exporter, on the backup branch at
`proposals/refund-executable-feasibility/source-model-binding-20261104/frontend/Bake.proposed.cs`.
The exporter itself says that it does not always reject unsupported
features (`Bake.proposed.cs:10-12`).

Route chosen: **(a′) = (a) on a flat source + a Dafny-checked bridge (c).**

- HOL side: the REAL exported AST of the flat source `FlatCore.dfy` (U294
  export, 3,621 bytes, SHA-256 `58154ddf…dd0d`), parsed in the kernel by the
  published `mlsexp$parse` and `sexp_to_dafny$to_program`, evaluated by the
  published `evaluate_exp`.
- Dafny side: lemmas checked by the pinned Dafny 4.11.0, in a CONCRETE module
  that imports the concrete `Refund` (the approved refinement of the abstract
  `RefundSpec`). They tie the approved `Eligible` to the flat predicate and to
  the exact `FlatCore.dfy` that was exported.
- The two halves meet at ONE expression: the right-hand side of the first
  ensures clause of `FlatCore.dfy`. Its meaning in Dafny and its meaning as an
  exported AST in HOL are identified by trust item T1/T2 (section 4).

This route reuses an export that already exists in git. It does not need the
patched exporter to be rebuilt (its build folder
`.toolchain/experiments/refund-dafny-frontend-20261104` is no longer on disk,
and a rebuild needs the network for the .NET SDK and NuGet).

Not chosen:
- (b) VCG (`dafny_vcgProofScript.sml:110` `stmt_vcg_correct`, `:230`
  `mets_vcg_correct`). It proves "the HOL method meets its exported ensures".
  For this straight-line code, direct evaluation gives the same (U294
  `source_postconditions`). It cannot reach the approved datatypes, so it adds
  no link to `RefundSpec`.
- (c-only) a hand-written HOL copy of `RefundSpec` (HOL datatypes). That is
  one more reading claim, the thing M1-B must remove.

## 2. Theorem statements (plain mathematical text)

Notation. `S` = the set of HOL `mlstring` values (finite byte strings). `ℤ` =
mathematical integers. `B` = booleans. `G` = the HOL term
`eligible_link_guard` (the right-hand side of the first exported ensures
clause). `init(h, c, q, o, m, e, p, k, a, r)` = `eligible_link_initial …`
(locals: the nine named typed inputs, six outputs unset, heap `h`, other fields
from `init_state 0`).

HOL `eligible c q o m e p k a r` (`forge_refund`, `eligible_def`) is
`c ≠ «» ∧ q ≠ «» ∧ e ∧ p ∧ 0 ≤ o ∧ o ≤ 9223372036854775807 ∧ 0 ≤ m ∧ m ≤ o ∧ k ∧ 0 ≤ a ∧ a ≤ m ∧ (r = «duplicate_charge» ∨ r = «service_not_delivered» ∨ r = «returned_item»)`.

### HOL theory `forge_refundEligibleLink` (file `forge_refundEligibleLinkScript.sml`)

- **L1 `eligible_link_decode`.** There is an S-expression `se` with
  `parse(text) = INR(se, [])` and `to_program(se) = INR P`, where `text` is the
  exact export and `P` is `eligible_link_program`. (Complete parse, no
  remainder.)
- **L2 `eligible_link_shape`.** `P` is exactly one method `AssessFlat` with
  inputs `chargeId:Str, requestId:Str, original:Int, remaining:Int,
  enabled:Bool, requestOpen:Bool, candidate:Bool, amount:Int, reason:Str`, no
  requires, no reads, no modifies, outputs `authorized:Bool, outputAmount:Int,
  outputReason:Str, outputCharge:Str, outputRequest:Str, intentCount:Int`; its
  first ensures clause is `authorized == G`; its body starts with
  `authorized := G`.
- **L3 `eligible_link_guard_value` (THE FIRST THEOREM).**
  For all `h`, `env`, `c q r ∈ S`, `o m a ∈ ℤ`, `e p k ∈ B`:
  `evaluate_exp (init(h,c,q,o,m,e,p,k,a,r)) env G = (init(h,c,q,o,m,e,p,k,a,r), Rval (BoolV (eligible c q o m e p k a r)))`.
  No error, no state change, value = `eligible`.
- **L4 `eligible_link_matches_compiled_guard`.** For the same inputs and any
  `h'`, `env'`: the result of `G` in `init(…)` equals the result of the
  constructed `refund_guard` (the guard inside `refund_body`, which
  `refund_method` and the compiled program are built from) in
  `refund_initial h' …`.
- **L5 `eligible_link_operators`.** `do_bop Eq (StrV s) (StrV t) = SOME (BoolV (explode s = explode t))`,
  the same for `Neq` with `≠`, and `do_bop Eq (BoolV a) (BoolV b) = SOME (BoolV (a ⇔ b))`.
  String equality in the model is equality of byte lists.

### Dafny module `RefundEligibleLink` (file `EligibleFlat.dfy`)

`EligibleFlat(c,q,o,m,e,p,k,a,r)` is a byte copy of the right-hand side of the
first ensures clause of `FlatCore.dfy`. `FlatAmount(r)` = `r.amount` if
`r.Candidate?`, else `0`. `FlatReason(r)` = `r.reason` if `r.Candidate?`, else
`""`. `FlatResponse(k,a,r)` = `Candidate(a,r)` if `k`, else `Missing`.

- **E1 `EligibleFlatMatchesApproved`.** For every approved `context` and every
  approved `response` (all seven constructors, all integers, all Unicode
  strings): `Refund.Eligible(context, response) = EligibleFlat(context.chargeId,
  context.requestId, context.original, context.remaining, context.refundEnabled,
  context.requestOpen, response.Candidate?, FlatAmount(response), FlatReason(response))`.
- **E2 `ApprovedMatchesEligibleFlat`.** For every flat nine-tuple:
  `EligibleFlat(c,q,o,m,e,p,k,a,r) = Refund.Eligible(ChargeContext(c,q,o,m,e,p), FlatResponse(k,a,r))`.
- **E3 `NonCandidatesAgree`.** Every non-`Candidate` response is ineligible
  (matrix row 7).
- **E4 `FlatCoreGuard`.** For every flat input, the `authorized` output of the
  exported method `FlatRefund.AssessFlat` equals `EligibleFlat(…)` and equals
  `Refund.Eligible(ChargeContext(…), FlatResponse(…))`.
- **E5 `ApprovedGuard`.** For every approved pair, the same, from the
  structured side.

`Refund.Eligible` is `RefundSpec.Eligible` unchanged (`Refund` refines
`RefundSpec` and gives only the body of `Assess`). The approved files are used
as byte copies with SHA-256 `90a21c71…fe57` (spec) and `04168824…a700` (impl);
these equal the current `spec/refund/RefundSpec.dfy` and `impl/Refund.dfy`
(measured with `shasum -a 256` on 2026-11-19).

### Dafny module `RefundEligibleUtf8` (file `EligibleFlatUtf8.dfy`, optional)

`Encoded(s)` is the unchanged U262 function: the UTF-8 bytes of `s`, one Dafny
char per byte value.

- **U1 `EligibleUnderUtf8`.** For every approved pair:
  `Refund.Eligible(context, response) = EligibleFlat(Encoded(context.chargeId),
  Encoded(context.requestId), context.original, context.remaining,
  context.refundEnabled, context.requestOpen, response.Candidate?,
  FlatAmount(response), Encoded(FlatReason(response)))`.
- **U2 `EncodedFieldsAreBytes`.** Every char of the three encoded fields is
  below 256.

### The composed statement (NOT one kernel theorem)

For every approved `context` and `response`, with `⌈s⌉` = the HOL `mlstring`
whose byte list is the code list of the byte-valued Dafny string `s`:

`RefundSpec.Eligible(context, response)` ⇔
`eligible ⌈Encoded(context.chargeId)⌉ ⌈Encoded(context.requestId)⌉ context.original context.remaining context.refundEnabled context.requestOpen response.Candidate? FlatAmount(response) ⌈Encoded(FlatReason(response))⌉`.

Chain: U1 (Dafny) → [T1/T2: Dafny meaning of the `FlatCore.dfy` guard text =
`evaluate_exp` meaning of its exported AST `G`] → L3 (HOL) → [T3/T4: `⌈·⌉`,
integer and boolean identification]. L4 then reaches `refund_guard`, and
`eligible` is the predicate inside `refund_fields`, which the existing compiled
theorems (U291; U387/U404, conditional) use. Two kernels check the two halves.
The joins are trust items, listed next. This replaces the author's reading
for matrix rows 5, 6, 7, 8, 9 (eligibility part) and narrows row 16. Rows 1–4
stay interface identifications.

## 3. What each statement connects

| Statement | From | To | Checker |
| --- | --- | --- | --- |
| E1, E2, E3, E5 | approved `RefundSpec.Eligible` | `EligibleFlat` | Dafny 4.11.0 + Z3 4.12.1 |
| E4 | `EligibleFlat` | `authorized` of the exact exported `FlatCore.dfy` (contract) | Dafny 4.11.0 |
| U1, U2 | approved `Eligible` on Unicode strings | `EligibleFlat` on UTF-8 byte strings | Dafny 4.11.0 |
| L1 | export bytes | HOL AST `P` | HOL4 kernel (evaluation) |
| L2 | `P` | `G` is both the contract guard and the body guard | HOL4 kernel |
| L3 | `G` under HOL Dafny semantics | HOL `eligible` | HOL4 kernel |
| L4 | `G` | constructed `refund_guard` of the compiled method | HOL4 kernel |
| L5 | model `Eq`/`Neq` on strings | byte-list equality | HOL4 kernel |

## 4. Still TRUSTED after this step

- **T1 Exporter.** The U294 Dafny front-end fork (upstream commit
  `6eb1ed63…`, patch SHA-256 `df88831b…a6a`, which declares version 4.10.1)
  turns the `FlatCore.dfy` guard text into `G` with the same meaning. Not
  verified. Its version differs from the pinned verifier 4.11.0. Only the
  constructs used are relied on: string `!=` and `==`, `&&`, `||`, `<==>`, int
  `<=` (chained), boolean variables, int and ASCII string literals.
- **T2 Semantic agreement.** Dafny's meaning of those operators equals the
  published CakeML Dafny semantics (`do_bop`, `do_sc`, `evaluate_exp`). Not
  machine-checked. Points to review: short circuit (same values for total
  boolean operands), unbounded integers (both sides), string equality
  (Dafny `seq<char>` equality vs `mlstring` byte equality, see T3).
- **T3 String representation.** An approved Dafny string `s` (a sequence of
  Unicode scalar values; Dafny 4 default `--unicode-char`) is represented in
  HOL by the `mlstring` whose bytes are UTF-8(`s`). U1 proves that this
  convention preserves `Eligible`, using the U262 lemmas `EncodedEmpty` and
  `SameReasons` (which rest on `EncodedInjective`). The step "byte-valued Dafny
  string ↔ HOL `mlstring` with the same byte values" crosses kernels and is not
  machine-checked (matrix row 3). The literals in `G` are ASCII, so their bytes
  equal their code points (U262 `AsciiFixed`). The exporter writes them as text
  and `mlsexp$parse` reads them as bytes (part of T1).
- **T4 Integer and boolean identification** across kernels (matrix rows 1–2).
- **T5 Dafny toolchain**: Dafny 4.11.0, Boogie, Z3 4.12.1, .NET runtime, for
  E1–E5, U1–U2 and for `FlatCore.dfy`'s own contract (used by E4).
- **T6 HOL toolchain**: HOL4 kernel, Poly/ML, the `cakeml-heap`, the loaded
  theory files. The parser and semantics are HOL definitions evaluated in the
  kernel, so they are not trusted as code; they are trusted only as "the
  definitions the compiler proof uses".
- **T7 File identity.** The runner's SHA-256 checks bind: the export bytes,
  `FlatCore.dfy` (the exporter input and the Dafny include are the same
  bytes), and the approved spec and impl copies.
- **T8 Downstream.** From `eligible` / `refund_fields` to the machine code, the
  existing conditional theorems and their Profile A assumptions apply
  unchanged. This step does not touch them.

## 5. NOT covered

- HOL byte strings that are not UTF-8 encodings of any Dafny string. L3 holds
  for them, but the approved contract says nothing about them. No claim
  relates them to approved inputs.
- Ill-typed inputs (for example a string where an int is expected) and other
  state layouts: L3 is only for `eligible_link_initial`.
- The six-field tuple, R1–R5, the wire decoding and the output encoding (later
  steps; see `RUN_PLAN.md`).
- Exporter correctness for any other Dafny construct.
- Unicode normalization: canonically equivalent but different strings stay
  different on both sides. No normalization claim.
- Recovery of the original Unicode IDs from bytes (U262 decoder; separate).
- The compiled binary, the loader, the OS and the FFI (Profile A, unchanged).
- A swap of `chargeId` and `requestId` inside the guard. The guard is
  symmetric in them, so a guard-level theorem cannot see the swap. The output
  tuple step must catch it (`outputCharge`, `outputRequest`).

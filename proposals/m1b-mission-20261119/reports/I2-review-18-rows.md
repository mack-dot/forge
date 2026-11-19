# Step I.2: review of the 18 rows (fresh-context agent, Fable, read-only; same model family as the author)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

# Review of the A8 matrix (18 rows) — read-only

Reviewer: a language model of the same family as the author of the proofs, in a fresh context. This is not a review by a different person or organization. I ran no Dafny, HOL or build. I changed no file.

Branch for all `git show` texts: `origin/backup/forge-local-2026-11-11` (short: BK). Base folder: `proposals/refund-executable-feasibility/` (short: PEF).

Files read, with git blob ids:
- Matrix: `PEF/m1-profile-a-slide0-20261117/A8_CONTRACT_REVIEW_MATRIX.md`.
- `PEF/byte-boundary-20261104/records/inputs/Boundary.dfy`, blob `ac544173`, SHA-256 `8ab7cd8a…9314` (equal to the report).
- `…/inputs/UnicodeRelation.dfy` blob `c8f27a5f`; `…/inputs/transport/Transport.dfy` blob `230b501f`; `…/transport/FlatCore.dfy` blob `766d795e`; `…/transport/impl/Refund.dfy` blob `4c61b7db`; `…/transport/spec/refund/RefundSpec.dfy` blob `ad456868`.
- `PEF/byte-boundary-20261104/records/byte-proof.sml` blob `23e8d5c4`, SHA-256 `2aea5fb7…bb41` (equal to the report); printed theorem in `records/hol-0003/stdout.log` line 14 onward.
- HOL sources, copy `PEF/exception-compiler-20261105/records/replay-sources/`: `forge_refund.sml` blob `42e65d07`; `forge_refund_io.sml` blob `ffdf5931`; `forge_refundCertifiedProg.sml` blob `5ff497d7`; `forge_refundWireProg.sml` blob `40b772e3`. The four scripts in `.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refund*_experiment/` have the same blob ids today.
- Working tree: `spec/refund/RefundSpec.dfy`, `spec/refund/protocol.md`, `impl/Refund.dfy`, `unsure.md` entries U262, U295, U404.
- Pinned CakeML (commit `cd915569`): `basis/pure/mlsexpScript.sml` (SHA-256 `c940680a…`), `basis/pure/mlintScript.sml` (SHA-256 `aba36383…`), `compiler/dafny/sexp_to_dafnyScript.sml` lines 19–92.

## 1. Table

| Row | Verdict | Reason |
| --- | --- | --- |
| 16 | HOLDS WITH A CONDITION | 12 guard conjuncts and 5 output equations pair one to one, same order, same `<=`. Condition: the HOL free variables `amount`, `rb` are instantiated with the Dafny `a`, `rb`. |
| 17 | HOLDS WITH A CONDITION (DOES NOT HOLD as worded) | `Boundary` has no `requires` and proves `ok <==> R.Eligible`. No exported statement mentions `Assess`, `Decision`, `plan` or `Intent`. The tie to `Assess` is body asserts in `Transport.dfy` plus a reading of R3/R4. The spec bytes are today's bytes. |
| 18 | DOES NOT HOLD as a description of the accepted wire language; HOLDS for the canonical text only | `refund_request_def` is one canonical writer. The reader accepts a strict superset. The S-expression text is not the approved wire format of `protocol.md`. |
| 1 | HOLDS WITH A CONDITION | No text to compare except type names. Only `<=`, `=`, literals are used on integers; no division or modulo. Condition: accept the standard identification. |
| 2 | HOLDS WITH A CONDITION | Same as row 1. Only `&&`, `||`, `<==>`, `if`. |
| 3 | HOLDS | Dafny proves all elements `< 256` (Boundary.dfy 73–76). HOL `byte_roundtrip`, `byte_string_codes` are stated for exactly that domain. |
| 4 | HOLDS WITH A CONDITION | On the HOL side `charge`, `request` are arbitrary `mlstring`s. "UTF-8 bytes of the Unicode string" is a duty of the producer. I did not read the library encoder bodies. |
| 5 | HOLDS | Literal `9223372036854775807` byte-identical in RefundSpec.dfy:3, Boundary.dfy:67, FlatCore.dfy:11, forge_refund.sml:59, byte-proof.sml:27. |
| 6 | HOLDS (with row 4) | Eight conjuncts on each side. Non-empty id ⇔ non-empty byte list is `EncodedEmpty` + `CodesIdentity`. |
| 7 | HOLDS on the Dafny text; CONDITION on the mapping | R3 gives one fallback for every `!Eligible`; `Eligible` needs `Candidate?`. The map of six constructors to `candidate = F` is made by the producer. No text states it. |
| 8 | HOLDS | Same two inequalities. For a non-candidate HOL permits any `amount`; the guard is false anyway. |
| 9 | HOLDS | Three strings byte-identical in all six files (compared as hex). ASCII only. |
| 10 | HOLDS WITH A CONDITION | The tuple represents only `(Decision, plan)` pairs that already satisfy R5. No text defines the map. See section 3 and 6. |
| 11 | HOLDS | `0 ≤ amount ≤ remaining ≤ original ≤ Max` gives `Money(amount)` by transitivity. |
| 12 | HOLDS | Third guard conjunct group; reasons equal by row 9. |
| 13 | HOLDS (with row 10) | `¬ok` gives `(F, 0, «», «», «», 0)`; Dafny `!ok` gives `0, [], [], [], 0`. |
| 14 | HOLDS (with row 10) | `ok` gives `(T, amount, reason, charge, request, 1)`. |
| 15 | HOLDS (with row 10) | Count is `1` iff `ok`, else `0`; type `int` on both sides. |

## 2. Rows 16, 17, 18 in detail

### Row 16 — line by line

Dafny: BK `…/inputs/Boundary.dfy` lines 61–76. HOL: BK `…/records/byte-proof.sml` lines 22–34 (same as the printed theorem in `hol-0003/stdout.log`).

Bindings.
| Dafny | HOL | Note |
| --- | --- | --- |
| `cb := Codes(U.Encoded(context.chargeId))` (62) | free `cb`, premise `EVERY (\n. n < 256) cb` (23) | Premise discharged by Boundary.dfy 73 |
| `qb := Codes(U.Encoded(context.requestId))` (63) | free `qb`, same premise | Discharged by line 74 |
| `rb := Codes(U.Encoded(if response.Candidate? then response.reason else ""))` (64) | free `rb`, same premise | Discharged by lines 75–76 |
| `a := if response.Candidate? then response.amount else 0` (65) | free `amount : int` | DIFFERENCE. HOL is more general. |
| `context.original`, `.remaining`, `.refundEnabled`, `.requestOpen`, `response.Candidate?` | `original`, `remaining`, `enabled`, `opened`, `candidate` | Types `int`, `bool` forced by `eligible_def` (forge_refund.sml:57) |

Guard (`ok <==> …`), Dafny lines 66–69, HOL lines 26–31.
| # | Dafny | HOL |
| --- | --- | --- |
| 1 | `cb != []` | `cb <> []` |
| 2 | `qb != []` | `qb <> []` |
| 3 | `context.refundEnabled` | `enabled` |
| 4 | `context.requestOpen` | `opened` |
| 5 | `0 <= context.original` | `0 <= original` |
| 6 | `context.original <= 9223372036854775807` | `original <= 9223372036854775807` |
| 7 | `0 <= context.remaining` | `0 <= remaining` |
| 8 | `context.remaining <= context.original` | `remaining <= original` |
| 9 | `response.Candidate?` | `candidate` |
| 10 | `0 <= a` | `0 <= amount` |
| 11 | `a <= context.remaining` | `amount <= remaining` |
| 12 | `rb == Codes("duplicate_charge") \|\| rb == Codes("service_not_delivered") \|\| rb == Codes("returned_item")` | `rb = byte_codes «duplicate_charge» \/ rb = byte_codes «service_not_delivered» \/ rb = byte_codes «returned_item»` |

Outputs, Dafny lines 70–72, HOL lines 32–34. Dafny returns `(ok, amount, reason, charge, request, count)`. HOL binds `(ok,a,r,c,q,n)`; `refund_fields_def` (forge_refundCertifiedProg.sml 10–16) gives the order ok, amount, reason, charge, request, count.
| Dafny | HOL |
| --- | --- |
| `amount == (if ok then a else 0)` | `a = (if ok then amount else 0)` |
| `reason == (if ok then rb else [])` | `byte_codes r = (if ok then rb else [])` |
| `charge == (if ok then cb else [])` | `byte_codes c = (if ok then cb else [])` |
| `request == (if ok then qb else [])` | `byte_codes q = (if ok then qb else [])` |
| `count == (if ok then 1 else 0)` | `n = (if ok then 1 else 0)`, `n : int` (`1:int` in `refund_fields_def`) |

Results of the checks you asked for.
- Missing conjunct: none. Dafny has one more clause, `ok <==> R.Eligible(context, response)` (line 61). It has no HOL partner, as expected.
- `<` against `<=`: all eight inequalities are `<=` on both sides. The only `<` is the byte bound `< 256` on both sides.
- Field order: same.
- Non-candidate case: Dafny fixes `a = 0` and `rb = Codes(Encoded(""))`. HOL leaves `amount` and `rb` free. With `candidate = F` the HOL guard is false for every `amount`, `rb`. So the HOL statement includes the Dafny one. The two formulas are the same only after the instantiation `amount := a`, `rb := rb_Dafny`. The matrix text "the two formulas must be the same formula" is not exact.
- Empty strings: `cb != []` on both. Reject output is `[]` on both.
- Byte lists against strings: Dafny outputs are `seq<nat>`. HOL outputs are `mlstring` under `byte_codes`. `byte_string_codes` makes `byte_codes` injective. No loss.
- Signed against natural: `amount`, `count` are `int` on both sides. List elements are `nat` / `num`.
- Constants: Dafny uses `Codes("…")`, not `Codes(Encoded("…"))`. For these ASCII strings `ReasonCodes` (line 45–46) covers it.

### Row 17

Signature (Boundary.dfy 55–76):
`method Boundary(context: R.Context, response: R.ModelResponse) returns (ok: bool, amount: int, reason: seq<nat>, charge: seq<nat>, request: seq<nat>, count: int)`, `modifies {}`, with `R = Refund`.
Ensures: (1) `ok <==> R.Eligible(context, response)`; (2) the formula of row 16; (3–5) the three byte bounds.
- `requires`: none on `Boundary`. None on `RefundUtf8Transport.Equivalent` (UnicodeRelation.dfy 239–248). `RefundStringTransport.Transport` (Transport.dfy 21–36) has four `requires`; `Equivalent` discharges them (lines 250–259).
- `assume`, `{:axiom}`, `expect`, `:extern`: none in `Boundary.dfy`, `UnicodeRelation.dfy`, `Transport.dfy`, `FlatCore.dfy`, `impl/Refund.dfy`, `RefundSpec.dfy` (git grep).
- Bodiless lemma: none in those six files. `EncodedIsBytes` has an empty body `{ }`, which is a body.
- Abstract module shape: `RefundSpec` is `abstract module` with a bodiless `method Assess`. This is the approved text. `module Refund refines RefundSpec` gives the body. `verification.csv` of `dafny-0002` has `Refund.Assess (correctness),Passed`. `Boundary` imports the concrete `Refund`. None of the transport files is abstract.
- In the library: `Std/Strings.dfy:18` `abstract module ParametricConversion` has a bodiless `lemma CharsConsistent()` (line 32). `Strings.dfy:185–187` has `@Axiom lemma CharsConsistent()` with no body in `HexConversion`. `Std/Unicode/UnicodeEncodingForm.dfy:20` is abstract with four bodiless functions (lines 50, 60, 76, 81); `Utf8EncodingForm` declares all four again (lines 17, 98, 113, 186). I did not read those bodies.
- Same bytes: `shasum -a 256 spec/refund/RefundSpec.dfy` = `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57`. `dafny-0002/command.json` records the same value for `transport/spec/refund/RefundSpec.dfy`. Git blob `ad456868` on both. `impl/Refund.dfy`: `0416882492de…a700` on both, blob `4c61b7db`.
- Recorded run: `dafny verify Boundary.dfy … --verify-included-files`, exit 0, "1458 verified, 0 errors". `dafny audit` was run on `Boundary.dfy` without that flag; its table is empty.

What does not hold. The matrix says "`Boundary` is tied to the approved `Assess`". The exported contract of `Boundary` names only `R.Eligible`. `Assess` is called once, in the body of `Transport` (Transport.dfy 43–49):
`assert ok <==> originalDecision.Authorized?; assert ok ==> reason == response.reason; assert ok ==> originalDecision == R.Authorized(amount, reason); assert ok ==> (originalPlan == [R.Intent(context.chargeId, context.requestId, amount, reason)]); assert !ok ==> originalDecision == R.Rejected && originalPlan == [];`
These asserts were verified, but they are not in any `ensures`. No assert relates the outputs `charge`, `request`, `count` to `originalPlan`. The step "six outputs = flattening of the result of `Assess`" is a reading of R3, R4, R5, not a checked statement.

### Row 18

Texts: `refund_request_def` (forge_refund_io.sml 9–17), `refund_decode_def` (19–29), `refund_decode_wire_def` (31–38); `to_bool_def`, `to_int_def`, `to_mlstring_def` (sexp_to_dafnyScript.sml 19–38); `mlint$fromString_def` (mlintScript.sml, "Definition fromString_def"); `lex_aux_def`, `read_symbol_def`, `read_string_aux_def`, `parse_def` (mlsexpScript.sml 31–201).

The only checked statement about wire text is for the canonical text: `refund_wire_roundtrip` and `byte_wire_inputs` speak about `sexp_to_string (refund_request …)`. The reader accepts more:
- Integers. `fromString` accepts a first character `~` or `-` (negative), `+`, or none, then one or more digits. No rule against leading zeroes. So `040`, `+40`, `-0`, `~0`, `0000` are accepted. This agrees with the test fact you gave (`040`, `+40`).
- Quoting. `lex_aux` makes the same `SYMBOL` for a bare atom and a quoted atom. So `"40"` is the integer 40 and `"True"` is the Boolean T.
- Bare atoms end only at `)` or a space character (`read_symbol_def`). `(` and `"` inside a bare atom are kept.
- White space (codes 9–13, 32) between tokens and before `(` is skipped. By my reading, any character after the closing `)`, including one newline, gives `rest ≠ []` and the error "refund: trailing input". I did not test this.
- Bytes ≥ 128 pass unchanged. Invalid UTF-8 is accepted.
- Unbounded integer length.

What "the producer is outside the claim" leaves open:
1. Which wire text stands for a given `(Context, ModelResponse)`. No definition states it: the UTF-8 encoding, the quoting and escaping of ids, `""` for an empty field, `~` for negatives, the map of six constructors to `False`, the filler amount and reason of a non-candidate.
2. The approved wire rules. `protocol.md` lines 45–49: "`amount_minor` must be `0` or a nonzero ASCII digit followed by zero to eighteen ASCII digits … signs, negative zero, leading zeroes, spaces … are unsupported and rejected." The compiled reader does none of this. A producer that copies the model's amount text into the atom makes `040` an authorization of 40. The same applies to the 4,096-byte cap, the JSON shape and "reject values above MaxMoney".
3. Many texts for one field tuple. Any component that signs, logs, deduplicates or parses the wire text in a different way can disagree with the program about the same text.
4. Field order. The program trusts positions 1 and 2 as charge and request.
The matrix cell "Wire text: decimal integers, `True`/`False` atoms" describes the writer. It does not describe the reader.

## 3. Differences and doubts, with quotes

D1 (row 16). Dafny `var a := if response.Candidate? then response.amount else 0;` against HOL free `amount`. Not the same formula; an instance.
D2 (row 17). No `ensures` in any file names `Assess`. See the quoted asserts above.
D3 (row 17, audit). U262 says "Selected24 unchanged source files contain no bypass scan match" and "Dafny audit0/zero findings". `library/Std/Strings.dfy:185` in the verified inputs reads `@Axiom` / `lemma CharsConsistent()` with no body. `UnicodeEncodingForm.dfy:22` has `import Strings` and line 310 calls `Strings.OfInt(index)`. I did not trace whether `OfInt` depends on the hex axiom; the name suggests the decimal module, whose `CharsConsistent` has a body `{}` (Strings.dfy 199–201). The empty audit table is not evidence about included files: either the audit did not cover them, or it does not report this `@Axiom`. The matrix sentence "The excluded upstream wrapper with an explicit axiom (U262) must stay excluded" does not mention this second axiom in the closure.
D4 (row 18). `fromString_def`: `if strsub str 0 = #"~" ∨ strsub str 0 = #"-" then … else if strsub str 0 = #"+" then …`. The writer uses only `~` (`toString_def1`: `int_to_string #"~" i`).
D5 (row 18). `protocol.md` line 38: "It does not prove a JSON parser." The S-expression format does not occur in `protocol.md`.
D6 (row 7). No text maps `Missing | TimedOut | Failed | Malformed | Oversized | Unsupported` to `candidate = F`. On the Dafny side the map is `response.Candidate?` (Transport.dfy 42). On the HOL side the flag is an input.
D7 (row 10). The tuple has one amount and one reason. It cannot express `(Authorized(5, r), [Intent(c, q, 6, r)])`, `(Rejected, [Intent …])` or `(Authorized …, [])`. Tuples such as `(T, 5, r, c, q, 0)` or `(F, 5, …)` or a count of 2 stand for no `(Decision, plan)` pair. The representation is a bijection only between the two R5-shaped families and the two tuple shapes. `refund_fields` produces only those two shapes, so nothing is wrong for this program. The reading rule for a consumer is not written anywhere.
D8 (rows 4, 6). The matrix says "non-empty string ⇔ non-empty byte list is proved on the Dafny side". Correct: `EncodedEmpty` (UnicodeRelation.dfy 147–153) and `CodesIdentity` second ensures.
D9. The date of the test fact you gave (2026-11-19) is after today's date in my environment (2026-11-18). I used the fact as given and did not verify it.

## 4. What a machine-checked link would have to state

Inside Dafny (possible today, not present):
- `function Flatten(d: R.Decision, p: seq<R.RefundIntent>): (bool, int, seq<nat>, seq<nat>, seq<nat>, int)` defined for every pair, plus a predicate `Conforming(d, p)` for the R5 shape.
- A postcondition, or a lemma over all `(d, p)` that satisfy the `ensures` of `RefundSpec.Assess` for `(context, response)`: `Boundary` outputs `== Flatten(d, p)`. `Assess` is a method, so the statement must quantify over every result that satisfies R1–R5, or `Assess` must get a function twin.
- `Flatten` injective on `Conforming` pairs (uses `EncodedInjective`).
- A function `Wire(context, response): seq<nat>` that states the canonical S-expression bytes, so that the producer has a specification.

Between Dafny and HOL:
- Relate `R.Eligible` to `eligible`, `Flatten ∘ Assess` to `refund_fields`, `Codes ∘ U.Encoded` to the argument strings, and `Wire` to `sexp_to_string (refund_request …)`.
- Blocks: no shared kernel or translation; Dafny `string` is a sequence of scalar values and HOL `mlstring` is a sequence of 8-bit characters, so the encoder itself must be part of the statement; `Assess` is a method with a relational contract; the seven constructors have no HOL counterpart; the HOL domain is wider (all byte strings), so the statement must be one-directional: for every approved input, the HOL function at its image equals the image of the approved result.
- A workable route: a deep embedding. U294 says the exported AST of `FlatCore` is compared with the HOL model. A link of that kind for `Boundary` or for `Refund.Assess` itself would replace rows 5–16. I did not read U294.

For the reader: a theorem that `refund_decode_wire w = INR fields` implies `w = sexp_to_string (refund_request fields)`. It is false today (`040`). Either a strict reader, or a canonical-form check in the program, would make it true.

## 5. Not read or not found

- Bodies of `Utf8EncodingForm.dfy`, `Std/Collections/Seq.dfy`, and the rest of the library. I cannot confirm that the library encoder is UTF-8.
- `COMMANDS.md`, `readback.json`, the `hol-import*` audits, the negative controls, `manifest.json`.
- `PEF/unicode-20261104/REPORT.md` (U262 packet). I read the U262 log entry and the `UnicodeRelation.dfy` copy in the U295 packet (blob `c8f27a5f`, the same blob as `unicode-20261104/UnicodeRelation.dfy`).
- `forge_refund_call`, `refund_program`, the compile and machine theorems (U387, U404). Row 23 of matrix section 1 is outside this review.
- Whether the compiled theory objects loaded by `byte-proof.sml` on 2026-11-04 were built from the scripts I read. Only the script blobs match today.
- The JSON adapter or any producer of the S-expression text. I found no definition of it in the files named.
- Whether `dafny audit` covers included files. I did not run it.
- The matrix records no file hashes for its own sources; I supplied them above.

## 6. Challenges to the definitions

C1. `eligible_def` against `Eligible` + `ValidContext`. Doubt: weaker or stronger? Reading: same eight context conjuncts, same two amount bounds, same three reasons; neither is weaker. Both agree with `protocol.md` lines 11–24 (inclusive bounds, zero allowed, case-sensitive reasons). On the Dafny side the formula is anchored by the checked `ok <==> R.Eligible`. On the HOL side the only anchor is the text match of row 16. Settles it: the cross-system statement of section 4.

C2. Boundary formula against the `ensures` of `Assess`. Doubt: the formula constrains six flat outputs; R1–R5 constrain `decision` and `plan`. The outputs `charge`, `request`, `count` are tied to `plan` by no checked statement. Counter-reading: none found that breaks R1–R5; R3 and R4 fix `decision` and `plan` uniquely, and the outputs are functions of the same inputs. Settles it: the `Flatten` postcondition of section 4.

C3. `byte_fields_result` is true for a near-trivial reason. It unfolds `refund_fields_def` and `eligible_def` and moves `byte_string` across. It is not vacuous: the premise `EVERY (\n. n < 256)` is satisfiable, all six outputs are fixed by equations, and no universally quantified variable empties it. Its value is only that its text can be compared with `Boundary.dfy`. It says nothing about any program other than the function `refund_fields`.

C4. Shared readings, where "they match" proves little. `FlatCore.dfy`, the `Boundary` formula, `eligible_def` and `refund_fields_def` have one template and one author family.
- Field order (ok, amount, reason, charge, request, count) and argument order (charge first, request second). A swap of charge and request made in the producer and in the consumer is invisible to both proofs. The Dafny side names `context.chargeId`; the HOL side has only positions.
- Reject filler: amount 0, empty strings, count 0. `Rejected` has no amount in the approved text. The filler is a Forge choice on both sides.
- Bytes: "string = UTF-8 bytes" is a choice made once and used on both sides. The approved text speaks only of `string`.
- Comparison of reasons on bytes. Correct for ASCII labels; anchored by `SameReasons`.
Settles it: the `Flatten` and `Wire` definitions in Dafny, each tied to the approved datatypes.

C5. HOL model wider than the approved domain.
- Byte strings that are not UTF-8. Input: charge = the single byte `0xFF`, request = `r`, 100, 60, True, True, True, 40, `returned_item`. `eligible` is true. No `Context` has this id. Settles it: a UTF-8 validity check in the program, or a claim limited to images of approved inputs (matrix section 3 says the second).
- `candidate = F` with any amount and reason. Harmless: guard false.
- `candidate = T` is always a `Candidate`. Whether the response should have been `Malformed`, `Oversized`, `Unsupported` or `TimedOut` is decided before the HOL model. Input: model text `{"amount_minor":"040","reason":"returned_item"}`. Approved result: unsupported, fallback. If the producer forwards `040` with `True`, the program authorizes 40. R1–R5 over datatypes are not violated; `protocol.md` lines 45–52 are. Settles it: a specified and checked producer, or a strict integer reader.
- Mathematical integers: same on both sides. No narrowing found.

C6. HOL model narrower than the approved domain. Not found, given the encoder. Every `Context` and `ModelResponse` has an image. Condition: the producer must quote and escape ids that contain space, `(`, `)`, `"`, `\`, NUL, or are empty, and the reason of a non-candidate must be written (for example `""`). A producer that fails gives a decode error or a field shift. The model's reason is the last field; with exact 9-field and no-trailing-input checks I found no shift that reaches an earlier field, but I did not prove it.

C7. Six-tuple: could a wrong program satisfy the HOL statement and violate R1–R5? Not the statement itself: it fixes `refund_fields` by equations. The risk is in the reading of the tuple.
- A consumer that reads only field 2. `(F, 0, …, 0)` and `(T, 0, r, c, q, 1)` both have amount 0. `protocol.md` line 25: "Zero is a legitimate authorization, distinct from fallback." The distinction lives only in `ok` and `count`.
- A consumer that acts when `count ≥ 1` or when `charge` is non-empty, not when `ok` is true. Equivalent for this program; not stated.
- Response text: `refund_response_def` writes `refund-result-v1`, then ok, amount, reason, charge, request, count. The response reader has the same non-injective integer and quoting rules.
Settles it: a written and checked decode `Unflatten(tuple) : (Decision, plan)` with `Unflatten(Flatten(d, p)) = (d, p)` on conforming pairs, and consumers that use only it.

C8. Is the approved `Eligible` right for the intent? Compared with `protocol.md` lines 11–33: ids non-empty, both flags true, `0 <= remaining <= original <= MaxMoney`, amount in `[0, remaining]`, three labels. They agree. One point is not in R1–R5: "reject values above MaxMoney" (line 47) is a parser duty; `Eligible` rejects such an amount only because `remaining <= MaxMoney`. Same outcome.

C9. `ok <==> R.Eligible` uses `Refund`, not `RefundSpec`. `Eligible` has a body in the abstract module and a refinement cannot change it. I see no gap.

C10. Trusted items that enter this link and are not in the matrix list: Dafny's default Unicode `char` mode (no flag in `command.json`; `CharScalar` asserts `0 <= c as int < 0x110000`, which fits that mode); the second `@Axiom` of D3; the claim that `Std.Unicode.Utf8EncodingForm` is UTF-8.


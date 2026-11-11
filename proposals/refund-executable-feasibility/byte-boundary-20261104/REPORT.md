# Refund Unicode/model boundary: shared byte-list contract

CURRENT none. M1 open. Stage12 unauthorized. `end_to_end=false`.
The prior turn made progress at local commit `f7224e9c3246abe5257a06fe3886783c3d127ea7`.
This experiment checks the next source/model representation link. It changes no
approved specification, runtime, native executable, accepted policy or authority.

## Result

The source and model now have checked contracts over the same mathematical
interface: nine inputs and six result fields, with strings represented as finite
lists of byte values. The source proof has **no input precondition**. It preserves
every approved Unicode string, mathematical integer and response constructor.
The model's byte bounds are discharged on the source side by the existing UTF-8
proof, not by restricting the original input domain to ASCII or small integers.

This establishes a locally checked representation argument in two proof systems.
It is not a mechanically verified translation between their semantics. Independent
review must accept the identification of their Boolean, integer, sequence and
character-value interfaces. The source frontend and serializer remain unverified.
The physical runtime and authenticated admission gaps remain open.

## Exact correspondence

The new source proof imports the unchanged U262 library and transport. `Codes(s)`
projects each character to its natural-number value. `EncodedCodes(s)` proves
that `Codes(RefundUnicode.Encoded(s))` equals the actual byte values from the
existing UTF-8 library. It also proves each value is below 256. `CodesIdentity`
proves injectivity and empty-string preservation. `ReasonCodes` preserves the
three exact permitted reason strings.

`RefundByteBoundary.Boundary` calls the existing full-domain transport. It proves
both the approved `Refund.Eligible` decision and the exact model-shaped result:

- Authorization equals the original guard over the encoded charge/request IDs,
  original and remaining amounts, flags, candidate status, amount and reason.
- Acceptance preserves amount and the exact encoded reason and caller IDs;
  count is one.
- Rejection produces false, zero amount/count and empty string fields.

HOL's `byte_string bs = implode (MAP CHR bs)` and
`byte_codes s = MAP ORD (explode s)` are type projections. They are **not** new
UTF-8 encoding or decoding algorithms. The existing HOL character type supplies
the byte bound and CHR/ORD inverse properties. Seven theorems establish:

| Theorem in forge_refundByteBoundary | Checked statement |
| --- | --- |
| byte_roundtrip | Every finite list of values below 256 survives model string construction and projection exactly |
| byte_string_codes | Every existing model string survives projection and reconstruction |
| byte_string_eq | Equality to any model string is exactly equality of its byte-value list |
| byte_codes_empty | The empty model string projects to the empty list |
| byte_fields_result | The exact existing refund_fields function satisfies the source boundary's decision and six-field relation |
| byte_wire_inputs | The existing complete-input parser preserves all nine canonical request fields and their exact byte lists |
| byte_wire_outputs | The existing serializer/parser preserves all six response fields and consumes the entire output |

The new source boundary uses the same unchanged FlatCore as U294. U294 already
checks that its actual exported AST agrees with the original model and with
`refund_fields`. U291 uses that exact `refund_fields` in its compiled behavior
theorem. This experiment adds the representation link; it does not rerun or
silently strengthen the compiler theorem.

| Interface field | Source side | HOL/model side | Remaining interpretation boundary |
| --- | --- | --- | --- |
| charge/request strings | UTF-8 encoding, then exact natural-number projection | CHR/ORD byte-list bijection | Identification of finite sequences and values between kernels |
| reason | Same encoding; exact allowed-reason equivalence | Exact byte-string equality to the same three constants | Review of corresponding literal identities |
| original/remaining/amount | Mathematical integers; no input range precondition | HOL integers; unbounded parser representation | Cross-system integer identification |
| enabled/open/candidate | Booleans; all response variants retained | The same three Boolean inputs | Constructor-to-candidate mapping remains the checked source relation |
| authorization/amount/count | Exact approved decision and numeric values | Same guard and six-field relation | No physical I/O or bank effect implied |
| output IDs/reason | Exact projected bytes or empty on rejection | Same byte lists, preserved by the existing wire format | Actual caller must use the intended representation |

The source's published inverse decoder still justifies recovery of the original
Unicode caller IDs. No claim says encoded bytes equal original Unicode characters.
Non-UTF-8 arbitrary byte requests are not relabeled as approved Unicode inputs.
HOL's wider byte-domain theorem does not enlarge the accepted source contract.

## Actual executions

[Full command ledger](COMMANDS.md), [identity/outcome readback](records/readback.json).
Raw directory: `results/refund-byte-boundary-2026-11-04/attempt-0001/`.
Every record includes actual arguments, working directory, source identities,
numeric exit and local duration. Expected outcomes remain separate from observations.

| Command/check | Actual exit | Observed result |
| --- | --- | --- |
| run_dafny.py dafny-0001 | 4 | Missing sequence-element projection fact; boundary proof resource exhaustion; warnings retained |
| run_dafny.py dafny-0002 / dafny-repeat | 0 / 0 | 1458 assertion batches each, including all source dependencies |
| run_frontend_verify.py frontend-verify | 0 | Same 1458 batches pass with the exact experimental extraction frontend build |
| Dafny audit | 0 | Zero audit findings; this command does not itself verify proofs |
| run_hol.py hol-0001 / hol-0002 / hol-0003 | 1 / 1 / 0 | Induction normalization failure; opaque empty projection; seven theorems pass |
| run_hol.py hol-repeat | 0 | All four theory exports reproduce byte for byte |
| run_import.py hol-import / hol-import-0002 | 1 / 0 | Initial universal-quantifier mismatch in the audit; corrected exact comparison passes |
| Source lossy projection / output swap | 4 / 4 | Intended assertion or postcondition failure; no resource or parse failure |
| HOL lossy projection / output swap | 1 / 1 | Intended byte inverse or six-field theorem refusal |
| readback.py | 0 | Source preservation, exact outcomes, exports, closure and prior packets checked |
| Native/hosted execution, complete independent replay, new admission | NOT RUN | No stronger executable or authority claim |

The Dafny correction made sequence-element facts explicit and split obligations
with the established assertion-isolation mechanism. It used the existing resource
budget mechanism, including 20 million solver resources for the composed method.
It did not weaken any postcondition. HOL first expanded the projections before
induction, then unfolded the empty projection explicitly. The accepted statements
remain unchanged. These are new boundary proofs; U290's entry-layout route remains
stopped at five attempts.

The fresh import checks seven theorem statements and two definitions. The first
audit compared a universally quantified definition with an open expected term.
The corrected audit compares their universal specializations. The same statements,
zero explicit hypotheses, permitted tags and exact theorem count remain required.
This is a same-host exact import, not an independent reviewer or full-chain kernel
rebuild. The closure has 231 nodes and 1,146 hashed theory files. Its only declared
axioms are the existing bool.SELECT_AX, INFINITY_AX, ETA_AX and BOOL_CASES_AX.
The built-in root and exact heap have separate identity records.

The source built frontend reports version 0.0.0.0. Its pin declares 4.10.1; use
the exact driver hash below. Running all source obligations with that same build
removes an untested frontend-version compatibility step. It does **not** prove
universal equivalence to Dafny 4.11 or correctness of Bake serialization. The
source parser, Dafny/Boogie/Z3, host, prior package-authentication limitation and
semantic identification between Dafny and HOL remain explicit trust boundaries.

## Adversarial evidence

| Change | Exact observed reason |
| --- | --- |
| Source Codes projection reduced modulo 128 | Numeric identity assertions fail; actual UTF-8 byte-list postcondition fails |
| Source caller-ID outputs exchanged | Complete boundary postcondition fails at the request-ID binding |
| HOL byte construction reduced modulo 128 | byte_roundtrip leaves ORD(CHR(h MOD 128)) = h |
| HOL expected caller-ID fields exchanged | byte_fields_result leaves cb = qb and qb = cb |

Both original domains remain universal in the positive claims. The negative cases
are proof/binding refusals. They are not release-admission decisions or a universal
security theorem. No negative was accepted merely because an infrastructure check
failed. All failed positive attempts and the initial failed import are retained.

## Identities and reproduction

| Artifact | SHA256 |
| --- | --- |
| New Boundary.dfy | `8ab7cd8a22adc527cf8ac2ab22906adad79dfe9179a8c0f6c46650429c7a9314` |
| Accepted HOL proof script | `2aea5fb7bb1f4e3f4b1032acd5041ddeb7eed921657484bb7ea3ec53dda6bb41` |
| forge_refundByteBoundaryTheory.dat | `120d384aa1e3e42bb92228a5483aa918820dccba50cb6fcefc2906f7624c7860` |
| Same extraction frontend driver | `55d26351d36b660ac6b1ea6eac7515cc4b15bc9a5f139f375a1a9e6f90455acb` |
| Unchanged native refund | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |

The readback confirms all 30 U262 source dependencies remain unchanged, as do 50
protected inputs and the mission. It validates 492 prior packet members. Three
positive Dafny runs have identical source hashes and symbol/outcome sets; their
timing fields differ. HOL's four exports are byte-identical. Local times are in
COMMANDS.md. Hosted runtime, runner-minutes and cache savings are NOT RUN.

Use the retained inputs, pinned tools and scripts with a new case directory for
each replay. Scripts refuse to overwrite earlier attempts. The source runners
recheck all included files. The HOL runner loads the existing pinned heap and
theories. Reproducing this packet on another host requires those recorded upstream
toolchains and dependency objects; this packet does not claim a standalone clean
bootstrap or independent producer authentication. No new tool was installed.

## Next smallest task and approvals

The remaining highest-priority executable gap is **runtime applicability**:
the exact installed-state, memory-frame, ARM control-state, FFI, interference,
resource and exit premises behind U291's compiler result. Its resource-limit
prefix alternative still permits incomplete output. Do not convert that theorem
to unconditional successful termination or full output.

Next authorized work: compare those precise premises with the retained complete
entry and FFI observations. Identify the smallest missing observable relation and
the assumptions that cannot be observed. Prepare an exact assurance profile for
independent review. Do not retry U290's stopped proof or claim that finite traces
prove universal runtime correspondence. Preserve full source input coverage.

Independent review must also assess the shared byte-list interpretation and
U294's exact frontend patch before any protected adoption. Proposed assumptions
are not accepted assumptions until the required owner and independent reviewer
approve the exact claim/profile. Historical signatures do not authorize this claim.
No source contract, acceptance policy or branch protection changes here.

Exact independent-device archive hashes and a restore remain unverified. The
owner's backup report is retained. Local recovery is not proof of that copy.
Remote PR/ruleset state was not refreshed by this experiment. Keep separate
operational controls and the proof-report upload repair outside this proof claim.

Local proposal work and unsigned commits are authorized. Publication, push, merge,
dispatch, signing, admission, deployment and protected profile adoption still need
their corresponding authorization. No such operation ran. No Stage12 or M2–M4
work started. The full assurance verdict remains **PARTIALLY_ESTABLISHED**;
M1 and integration EXIT remain **NOT_ESTABLISHED**. `end_to_end=false`.

# W9 final statements (copied from `W9/proof/inputs/LinkedRefund.dfy`, SHA-256 `0d67b483…9f34`)

Reading rule. A Dafny method's ensures is a statement over all inputs. At a CALL, Dafny gives the
output fresh values that satisfy ONLY the callee's ensures. So a method whose body is calls states a
fact over ALL values that satisfy those contracts. `Assess` is known only through the approved ensures
of `spec/refund/RefundSpec.dfy` (inherited). `F.AssessFlat` is known only through its three ensures
(`FlatCore.dfy`, SHA-256 `a89484e3…`, the same bytes as the U294 export input).

## S1. Decoder and round trip

```dafny
opaque function Decode(b: string): string   // total; reads only b; "" on a char >= 256 or on non-UTF-8
lemma DecodeEncoded(s: string)
  ensures Decode(U.Encoded(s)) == s
```

## S2. The read-back of the six outputs

```dafny
function Unflatten(ok: bool, amount: int, reasonBytes: string, chargeBytes: string,
                   requestBytes: string, count: int): (Decision, seq<RefundIntent>)
{
  (if ok then Authorized(amount, Decode(reasonBytes)) else Rejected,
   if count == 1 then [Intent(Decode(chargeBytes), Decode(requestBytes), amount, Decode(reasonBytes))]
   else [])
}
```

## S3. Main link: flat contract ==> approved contract (inherited ensures R1-R5)

```dafny
module LinkedRefund refines RefundSpec {
  @IsolateAssertions
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var reasonIn := if response.Candidate? then response.reason else "";
    var amountIn := if response.Candidate? then response.amount else 0;
    var ok, a, rb, cb, qb, n := F.AssessFlat(
      U.Encoded(context.chargeId), U.Encoded(context.requestId),
      context.original, context.remaining, context.refundEnabled, context.requestOpen,
      response.Candidate?, amountIn, U.Encoded(reasonIn));
    U.EncodedEmpty(context.chargeId); U.EncodedEmpty(context.requestId); U.SameReasons(reasonIn);
    DecodeEncoded(context.chargeId); DecodeEncoded(context.requestId); DecodeEncoded(reasonIn);
    var result := Unflatten(ok, a, rb, cb, qb, n);
    decision := result.0;
    plan := result.1;
  }
```
Meaning: for every `context`, `response` and every `(ok, a, rb, cb, qb, n)` that satisfies the three
flat ensures on the encoded inputs, `Unflatten(ok, a, rb, cb, qb, n)` satisfies every ensures of the
approved `RefundSpec.Assess` (R1-R5), text not retyped.
Closes: row 17 and D2 (an `ensures`-level statement now names the approved `Assess`, through refinement);
rows 13, 14, 15 and C2 (`charge`, `request`, `count` are now tied to `plan` by a checked statement);
row 10 (the tuple-to-pair map is now written: `Unflatten`).
Does NOT close: that the HOL function `refund_fields` satisfies the exported flat contract, or that
Dafny and the HOL Dafny semantics read the flat contract the same way (route-study section 5,
items 2-4). That needs the HOL theorem `exported_contract_on_refund_fields` of Route D step 4.

## S4. Converse: approved result ==> flat outputs

```dafny
method ApprovedFlattensToFlat(context: Context, response: ModelResponse)
    returns (decision: Decision, plan: seq<RefundIntent>,
             ok: bool, a: int, rb: string, cb: string, qb: string, n: int)
  ensures Flatten(decision, plan) == (ok, a, rb, cb, qb, n)
  ensures (decision, plan) == Unflatten(ok, a, rb, cb, qb, n)
  ensures Conforming(decision, plan)
{ decision, plan := Assess(context, response); ... ok, a, rb, cb, qb, n := F.AssessFlat(<encoded inputs>); ... }
```
Meaning: any pair allowed by the approved ensures and any six values allowed by the flat ensures (same
encoded inputs) satisfy `Flatten(pair) == six` and `Unflatten(six) == pair`. With S3 this is an
equivalence on encoded approved inputs.
Closes: C2, C7 (a written, checked decode with `Unflatten(Flatten(d, p)) == (d, p)`), row 10.
Does NOT close: inputs that are not encodings of approved inputs (non-UTF-8 bytes in HOL; C5); the
cross-tool step.

## S5. Uniqueness of the approved result

```dafny
method Uniqueness(context: Context, response: ModelResponse)
    returns (d1: Decision, p1: seq<RefundIntent>, d2: Decision, p2: seq<RefundIntent>)
  ensures d1 == d2 && p1 == p2
{ d1, p1 := Assess(context, response); d2, p2 := Assess(context, response); }
```
And over the existing U410 predicate `Post` (`RefundDeterminism.dfy`, unchanged), in non-abstract `LinkedPost`
(`R = LinkedRefund`, `D = RefundDeterminismLinked`):
```dafny
method ApprovedImpliesPost(context: R.Context, response: R.ModelResponse)
    returns (decision: R.Decision, plan: seq<R.RefundIntent>)
  ensures D.Post(context, response, decision, plan)
{ decision, plan := R.Assess(context, response); }

method PostIsApproved(context: R.Context, response: R.ModelResponse,
                      decision: R.Decision, plan: seq<R.RefundIntent>)
    returns (approvedDecision: R.Decision, approvedPlan: seq<R.RefundIntent>)
  requires D.Post(context, response, decision, plan)
  ensures decision == approvedDecision && plan == approvedPlan
{ approvedDecision, approvedPlan := R.Assess(context, response); }

lemma PostUnique(context: R.Context, response: R.ModelResponse,
                 d1: R.Decision, p1: seq<R.RefundIntent>, d2: R.Decision, p2: seq<R.RefundIntent>)
  requires D.Post(context, response, d1, p1)
  requires D.Post(context, response, d2, p2)
  ensures d1 == d2 && p1 == p2
{ }
```
Meaning: `Post` and the approved ensures allow exactly the same pairs, and there is at most one.
Closes: route-study "Uniqueness"; with S3/S4 the flat outputs determine THE approved result (C2 counter-reading
settled).
Does NOT close: anything outside Dafny.

## S6. Flatten and its images

```dafny
function Flatten(d: Decision, p: seq<RefundIntent>): FlatTuple {
  (d.Authorized?, if d.Authorized? then d.amount else 0, if d.Authorized? then U.Encoded(d.reason) else "",
   if |p| > 0 then U.Encoded(p[0].chargeId) else "", if |p| > 0 then U.Encoded(p[0].requestId) else "", |p|)
}
predicate Conforming(d: Decision, p: seq<RefundIntent>) {
  (d.Rejected? && p == []) ||
  (d.Authorized? && |p| == 1 && p[0].amount == d.amount && p[0].reason == d.reason)
}
const RejectTuple: FlatTuple := (false, 0, "", "", "", 0)

lemma FlattenInjective(d1: Decision, p1: seq<RefundIntent>, d2: Decision, p2: seq<RefundIntent>)
  requires Conforming(d1, p1) && Conforming(d2, p2)
  requires Flatten(d1, p1) == Flatten(d2, p2)
  ensures d1 == d2 && p1 == p2

lemma FlattenShapes(d: Decision, p: seq<RefundIntent>)
  requires Conforming(d, p)
  ensures d.Rejected? ==> Flatten(d, p) == RejectTuple
  ensures d.Authorized? ==> (Flatten(d, p) ==
    (true, d.amount, U.Encoded(d.reason), U.Encoded(p[0].chargeId), U.Encoded(p[0].requestId), 1))

lemma AuthorizedPreimage(amount: int, reason: string, chargeId: string, requestId: string)
  ensures Conforming(Authorized(amount, reason), [Intent(chargeId, requestId, amount, reason)])
  ensures Flatten(Authorized(amount, reason), [Intent(chargeId, requestId, amount, reason)]) ==
    (true, amount, U.Encoded(reason), U.Encoded(chargeId), U.Encoded(requestId), 1)

lemma UnflattenFlatten(d: Decision, p: seq<RefundIntent>)
  requires Conforming(d, p)
  ensures var t := Flatten(d, p); Unflatten(t.0, t.1, t.2, t.3, t.4, t.5) == (d, p)

method FlatYieldsOnlyImages(context: Context, response: ModelResponse)
    returns (ok: bool, a: int, rb: string, cb: string, qb: string, n: int)
  ensures var r := Unflatten(ok, a, rb, cb, qb, n);
    Conforming(r.0, r.1) && Flatten(r.0, r.1) == (ok, a, rb, cb, qb, n)
  ensures (ok, a, rb, cb, qb, n) == RejectTuple ||
    (ok && n == 1 && response.Candidate? && rb == U.Encoded(response.reason) &&
     cb == U.Encoded(context.chargeId) && qb == U.Encoded(context.requestId))
{ ok, a, rb, cb, qb, n := F.AssessFlat(<encoded inputs>); ... }
```
Images: exactly `RejectTuple` and the tuples `(true, a, Encoded(r), Encoded(c), Encoded(q), 1)`.
Tuples such as `(true, 5, r, c, q, 0)`, `(false, 5, …)` or count 2 are images of no conforming pair,
and `FlatYieldsOnlyImages` shows the flat contract never yields them.
Closes: D7 (the reading rule for the tuple is now written and checked), row 10, C7 (in Dafny).
Does NOT close: C7 for a real consumer of the wire response text (a consumer must use `Unflatten`;
no consumer is specified), row 18 (wire text), C4 (a swap made in BOTH producer and consumer outside
Dafny stays invisible; inside Dafny the charge/request order is now fixed by S3, see controls N1/N1b).

## S7. Non-vacuity (through contracts and the lemmas above)

`WitnessAccepted` (`ChargeContext("ch_1","rq_1",100,60,true,true)`, `Candidate(40,"duplicate_charge")`):
approved contract gives `Authorized(40,"duplicate_charge")` and one intent; flat contract gives
`ok && a == 40 && n == 1`; `Flatten(d, p) == six` and `Unflatten(six) == (d, p)`.
`WitnessRejected` (`Candidate(61, …)`): `Rejected`, `[]`, and `RejectTuple`.
`WitnessUnicode` (ids `"\U{100}"`, `"\U{10FFFF}"`): flat `ok`, and `cb != qb` by `EncodedInjective`.
`WitnessUnique`, `LinkedPost.PostAcceptsAndRejects` (one accepted and one rejected `Post`).
Satisfiability of both contracts for EVERY input: `FlatRefund.AssessFlat (correctness)`,
`Refund.Assess (correctness)` and `LinkedRefund.Assess (correctness)` all pass in the same run.
Closes: vacuity doubt for S3-S6.

## What all of this does NOT close (common to every statement)

- The cross-tool step: Dafny's flat contract versus the HOL statement about `refund_fields` and the
  parsed `source_ensures`. Needs the HOL theorem of the route study (step 4), plus the trust in the
  exporter (`Bake.cs` patch), the fragment semantics, and char<256 string = `mlstring`.
- Rows 1-4 (type identification), 18 (wire text and reader), C5 (non-UTF-8 inputs, `040`), D6
  (map of the six non-candidate constructors is only `response.Candidate?` inside Dafny).
- Dafny/Boogie/Z3 soundness; the library claim that `Std.Unicode.Utf8EncodingForm` is UTF-8 (C10).

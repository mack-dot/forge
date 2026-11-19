// W9 (M1-B, Route D steps 1 and 2). Scratch proof. NOT approved. NOT part of the gate.
// The approved RefundSpec, impl/Refund.dfy, FlatCore.dfy (AssessFlat, the flat contract),
// UnicodeRelation.dfy (U262 encoder), RefundDeterminism.dfy and RefundExact.dfy are included
// unchanged (byte copies; hashes are in RESULTS.md).
include "UnicodeRelation.dfy"
include "transport/clearing/RefundExact.dfy"

// LinkedRefund refines the approved abstract module. The ensures of Assess are inherited from
// spec/refund/RefundSpec.dfy and are not written again here. The body encodes the approved
// inputs, calls the flat method AssessFlat (Dafny knows only its three ensures at the call), and
// builds decision and plan from the six flat outputs ONLY, through Unflatten.
module LinkedRefund refines RefundSpec {
  import U = RefundUnicode
  import F = FlatRefund
  import S = Std.Collections.Seq
  import E = Std.Unicode.Utf8EncodingForm

  type FlatTuple = (bool, int, string, string, string, int)

  // ---------------------------------------------------------------------------------------------
  // Decoder. A total function of the byte string only. It returns "" for a string that has a
  // character >= 256 or that is not well-formed UTF-8.
  opaque function Decode(b: string): string {
    if forall i | 0 <= i < |b| :: b[i] as int < 256 then
      var bytes: E.CodeUnitSeq := seq(|b|, i requires 0 <= i < |b| && b[i] as int < 256 => b[i] as int as bv8);
      var r := E.DecodeCodeUnitSequenceChecked(bytes);
      if r.Success? then S.Map(U.FromScalar, r.value) else ""
    else ""
  }

  lemma DecodeEncoded(s: string)
    ensures Decode(U.Encoded(s)) == s
  {
    reveal Decode();
    var b := U.Encoded(s);
    U.EncodedIsBytes(s);
    U.ByteViewIdentity(s);
    var w := E.EncodeScalarSequence(U.Scalars(s));
    var bytes: E.CodeUnitSeq := seq(|b|, i requires 0 <= i < |b| && b[i] as int < 256 => b[i] as int as bv8);
    assert bytes == w;
    assert E.IsWellFormedCodeUnitSequence(w);
    U.StringRoundTrip(s);
  }

  // The six flat outputs, read back. It reads its six arguments only.
  function Unflatten(ok: bool, amount: int, reasonBytes: string, chargeBytes: string,
                     requestBytes: string, count: int): (Decision, seq<RefundIntent>)
  {
    (if ok then Authorized(amount, Decode(reasonBytes)) else Rejected,
     if count == 1 then [Intent(Decode(chargeBytes), Decode(requestBytes), amount, Decode(reasonBytes))]
     else [])
  }

  // ---------------------------------------------------------------------------------------------
  // The refinement. Every ensures of RefundSpec.Assess (R1 to R5) is inherited and checked here.
  // IsolateAssertions: each inherited ensures is checked as its own batch (same resource limit).
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
    // Facts about the encoder on the INPUTS only. No output is read here.
    U.EncodedEmpty(context.chargeId);
    U.EncodedEmpty(context.requestId);
    U.SameReasons(reasonIn);
    DecodeEncoded(context.chargeId);
    DecodeEncoded(context.requestId);
    DecodeEncoded(reasonIn);
    var result := Unflatten(ok, a, rb, cb, qb, n);
    decision := result.0;
    plan := result.1;
  }

  // ---------------------------------------------------------------------------------------------
  // Flatten: total on every (Decision, plan) pair.
  function Flatten(d: Decision, p: seq<RefundIntent>): FlatTuple {
    (d.Authorized?,
     if d.Authorized? then d.amount else 0,
     if d.Authorized? then U.Encoded(d.reason) else "",
     if |p| > 0 then U.Encoded(p[0].chargeId) else "",
     if |p| > 0 then U.Encoded(p[0].requestId) else "",
     |p|)
  }

  // The R5 shape: a rejection with no intent, or an authorization with one intent that carries
  // the same amount and reason.
  predicate Conforming(d: Decision, p: seq<RefundIntent>) {
    (d.Rejected? && p == []) ||
    (d.Authorized? && |p| == 1 && p[0].amount == d.amount && p[0].reason == d.reason)
  }

  const RejectTuple: FlatTuple := (false, 0, "", "", "", 0)

  // Flatten is injective on conforming pairs (uses U262 EncodedInjective).
  lemma FlattenInjective(d1: Decision, p1: seq<RefundIntent>, d2: Decision, p2: seq<RefundIntent>)
    requires Conforming(d1, p1) && Conforming(d2, p2)
    requires Flatten(d1, p1) == Flatten(d2, p2)
    ensures d1 == d2 && p1 == p2
  {
    if d1.Authorized? {
      U.EncodedInjective(d1.reason, d2.reason);
      U.EncodedInjective(p1[0].chargeId, p2[0].chargeId);
      U.EncodedInjective(p1[0].requestId, p2[0].requestId);
      assert p1[0] == p2[0];
    }
  }

  // The images of conforming pairs are exactly two shapes.
  lemma FlattenShapes(d: Decision, p: seq<RefundIntent>)
    requires Conforming(d, p)
    ensures d.Rejected? ==> Flatten(d, p) == RejectTuple
    ensures d.Authorized? ==> (Flatten(d, p) ==
      (true, d.amount, U.Encoded(d.reason), U.Encoded(p[0].chargeId), U.Encoded(p[0].requestId), 1))
  {
  }

  // Every tuple of the second shape is an image: its preimage is the conforming pair below.
  lemma AuthorizedPreimage(amount: int, reason: string, chargeId: string, requestId: string)
    ensures Conforming(Authorized(amount, reason), [Intent(chargeId, requestId, amount, reason)])
    ensures Flatten(Authorized(amount, reason), [Intent(chargeId, requestId, amount, reason)]) ==
      (true, amount, U.Encoded(reason), U.Encoded(chargeId), U.Encoded(requestId), 1)
  {
  }

  // Unflatten is a left inverse of Flatten on conforming pairs.
  lemma UnflattenFlatten(d: Decision, p: seq<RefundIntent>)
    requires Conforming(d, p)
    ensures var t := Flatten(d, p); Unflatten(t.0, t.1, t.2, t.3, t.4, t.5) == (d, p)
  {
    var t := Flatten(d, p);
    if d.Authorized? {
      DecodeEncoded(d.reason);
      DecodeEncoded(p[0].chargeId);
      DecodeEncoded(p[0].requestId);
      assert t == (true, d.amount, U.Encoded(d.reason), U.Encoded(p[0].chargeId), U.Encoded(p[0].requestId), 1);
      assert p == [Intent(p[0].chargeId, p[0].requestId, d.amount, d.reason)];
      assert d == Authorized(d.amount, d.reason);
      assert Unflatten(t.0, t.1, t.2, t.3, t.4, t.5).0 == d;
      assert Unflatten(t.0, t.1, t.2, t.3, t.4, t.5).1 == p;
    } else {
      assert t == RejectTuple;
      assert Unflatten(t.0, t.1, t.2, t.3, t.4, t.5) == (Rejected, []);
    }
  }

  // The flat contract, on encoded approved inputs, yields only images of conforming pairs, and
  // Unflatten reads them back exactly. Dafny knows only the three ensures of AssessFlat here.
  method FlatYieldsOnlyImages(context: Context, response: ModelResponse)
      returns (ok: bool, a: int, rb: string, cb: string, qb: string, n: int)
    ensures var r := Unflatten(ok, a, rb, cb, qb, n);
      Conforming(r.0, r.1) && Flatten(r.0, r.1) == (ok, a, rb, cb, qb, n)
    ensures (ok, a, rb, cb, qb, n) == RejectTuple ||
      (ok && n == 1 && response.Candidate? && rb == U.Encoded(response.reason) &&
       cb == U.Encoded(context.chargeId) && qb == U.Encoded(context.requestId))
  {
    var reasonIn := if response.Candidate? then response.reason else "";
    var amountIn := if response.Candidate? then response.amount else 0;
    ok, a, rb, cb, qb, n := F.AssessFlat(
      U.Encoded(context.chargeId), U.Encoded(context.requestId),
      context.original, context.remaining, context.refundEnabled, context.requestOpen,
      response.Candidate?, amountIn, U.Encoded(reasonIn));
    DecodeEncoded(context.chargeId);
    DecodeEncoded(context.requestId);
    DecodeEncoded(reasonIn);
    assert U.Encoded("") == "" by { U.EncodedEmpty(""); }
  }

  // Converse direction. Both calls are known by contract only: Assess by the approved ensures,
  // AssessFlat by the flat ensures. Any approved result flattens to the flat outputs, and the
  // flat outputs read back to the approved result.
  method ApprovedFlattensToFlat(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>,
               ok: bool, a: int, rb: string, cb: string, qb: string, n: int)
    ensures Flatten(decision, plan) == (ok, a, rb, cb, qb, n)
    ensures (decision, plan) == Unflatten(ok, a, rb, cb, qb, n)
    ensures Conforming(decision, plan)
  {
    decision, plan := Assess(context, response);
    var reasonIn := if response.Candidate? then response.reason else "";
    var amountIn := if response.Candidate? then response.amount else 0;
    ok, a, rb, cb, qb, n := F.AssessFlat(
      U.Encoded(context.chargeId), U.Encoded(context.requestId),
      context.original, context.remaining, context.refundEnabled, context.requestOpen,
      response.Candidate?, amountIn, U.Encoded(reasonIn));
    U.EncodedEmpty(context.chargeId);
    U.EncodedEmpty(context.requestId);
    U.SameReasons(reasonIn);
    assert ok <==> Eligible(context, response);
    if decision.Authorized? {
      UnflattenFlatten(decision, plan);
    }
  }

  // Uniqueness. Dafny knows each call of Assess only through the approved ensures. So any two
  // pairs that satisfy the approved ensures for the same inputs are equal.
  method Uniqueness(context: Context, response: ModelResponse)
      returns (d1: Decision, p1: seq<RefundIntent>, d2: Decision, p2: seq<RefundIntent>)
    ensures d1 == d2 && p1 == p2
  {
    d1, p1 := Assess(context, response);
    d2, p2 := Assess(context, response);
  }

  // Non-vacuity. Assess is known here only by the approved ensures; AssessFlat only by the flat
  // ensures; the link facts come from the lemmas above. No body is read at these calls.
  method WitnessAccepted()
  {
    var c := ChargeContext("ch_1", "rq_1", 100, 60, true, true);
    var r := Candidate(40, "duplicate_charge");
    var d, p := Assess(c, r);
    assert d == Authorized(40, "duplicate_charge");
    assert p == [Intent("ch_1", "rq_1", 40, "duplicate_charge")];
    U.EncodedEmpty("ch_1");
    U.EncodedEmpty("rq_1");
    U.SameReasons("duplicate_charge");
    var ok, a, rb, cb, qb, n := F.AssessFlat(U.Encoded("ch_1"), U.Encoded("rq_1"), 100, 60, true, true,
      true, 40, U.Encoded("duplicate_charge"));
    assert ok && a == 40 && n == 1;
    assert Conforming(d, p);
    assert Flatten(d, p) == (ok, a, rb, cb, qb, n);
    UnflattenFlatten(d, p);
    assert Unflatten(ok, a, rb, cb, qb, n) == (d, p);
  }

  method WitnessRejected()
  {
    var c := ChargeContext("ch_1", "rq_1", 100, 60, true, true);
    var r := Candidate(61, "duplicate_charge");
    var d, p := Assess(c, r);
    assert d == Rejected && p == [];
    var ok, a, rb, cb, qb, n := F.AssessFlat(U.Encoded("ch_1"), U.Encoded("rq_1"), 100, 60, true, true,
      true, 61, U.Encoded("duplicate_charge"));
    assert !ok && a == 0 && n == 0 && rb == "" && cb == "" && qb == "";
    assert Flatten(d, p) == (ok, a, rb, cb, qb, n);
    assert Unflatten(ok, a, rb, cb, qb, n) == (d, p);
  }

  @IsolateAssertions
  method WitnessUnicode()
  {
    U.EncodedEmpty("\U{100}");
    U.EncodedEmpty("\U{10FFFF}");
    U.SameReasons("returned_item");
    var ok, a, rb, cb, qb, n := F.AssessFlat(U.Encoded("\U{100}"), U.Encoded("\U{10FFFF}"), 100, 60, true, true,
      true, 0, U.Encoded("returned_item"));
    assert ok && a == 0 && n == 1;
    U.EncodedInjective("\U{100}", "\U{10FFFF}");
    assert cb != qb;
  }

  method WitnessUnique()
  {
    var c := ChargeContext("ch_1", "rq_1", 100, 60, true, true);
    var d1, p1, d2, p2 := Uniqueness(c, Candidate(40, "duplicate_charge"));
    assert d1 == d2 && p1 == p2;
  }
}

// Reuse by inclusion of the existing Post predicate and the two-run lemma (U410), instantiated
// with the concrete LinkedRefund. The inherited bodies are verified again for this instance.
module RefundDeterminismLinked refines RefundDeterminism {
  import R = LinkedRefund
}

module RefundExactLinked refines RefundExact {
  import D = RefundDeterminismLinked
}

// Instance-level checks for LinkedRefund, in a NON-abstract module, so that nothing rests on the
// inherited (abstract-module) bodies above. D.Post is the existing U410 predicate over the
// approved predicates. R.Assess is known here only through the approved ensures.
module LinkedPost {
  import R = LinkedRefund
  import D = RefundDeterminismLinked

  // Approved ensures ==> Post.
  method ApprovedImpliesPost(context: R.Context, response: R.ModelResponse)
      returns (decision: R.Decision, plan: seq<R.RefundIntent>)
    ensures D.Post(context, response, decision, plan)
  {
    decision, plan := R.Assess(context, response);
  }

  // Post ==> the pair IS an approved result (so Post is not stronger than the approved text).
  method PostIsApproved(context: R.Context, response: R.ModelResponse,
                        decision: R.Decision, plan: seq<R.RefundIntent>)
      returns (approvedDecision: R.Decision, approvedPlan: seq<R.RefundIntent>)
    requires D.Post(context, response, decision, plan)
    ensures decision == approvedDecision && plan == approvedPlan
  {
    approvedDecision, approvedPlan := R.Assess(context, response);
  }

  // Post has at most one result (proved again here, not inherited).
  lemma PostUnique(context: R.Context, response: R.ModelResponse,
                   d1: R.Decision, p1: seq<R.RefundIntent>, d2: R.Decision, p2: seq<R.RefundIntent>)
    requires D.Post(context, response, d1, p1)
    requires D.Post(context, response, d2, p2)
    ensures d1 == d2 && p1 == p2
  {
  }

  // Post is satisfiable for one accepted and one rejected concrete case.
  lemma PostAcceptsAndRejects()
    ensures D.Post(R.ChargeContext("ch_1", "rq_1", 100, 60, true, true), R.Candidate(40, "duplicate_charge"),
                   R.Authorized(40, "duplicate_charge"), [R.Intent("ch_1", "rq_1", 40, "duplicate_charge")])
    ensures D.Post(R.ChargeContext("ch_1", "rq_1", 100, 60, true, true), R.Candidate(61, "duplicate_charge"),
                   R.Rejected, [])
  {
  }
}

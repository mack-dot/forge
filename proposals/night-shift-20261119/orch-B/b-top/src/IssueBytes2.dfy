// Night shift 2026-11-19, Orchestrator B, task d-minter. A DRAFT in an evidence folder. NOT gate evidence.
// M1-B stays OPEN. A Dafny statement about the METHOD IssueTokenBytes only. No claim about minter.ts,
// encoding.ts, Node, SHA-256, Ed25519 or the Dafny JavaScript back end.
//
// IssueTokenBytes is the whole issuance decision AND the whole token-body construction of the issuer:
//  - it calls the proved RefundFinality.Check (copy of impl/RefundFinality.dfy, SHA-256 in inputs-sha256.txt);
//  - it builds the REAL token-body shape of encoding.ts:14-17 (seven fields) from Check's token;
//  - it refuses a body that is not well-formed by SerModel.WfBody (the model of encoding.ts isTokenBody).
//    So the U+0000 case of review r-ser (IssueNotParseable) is refused HERE, in proved code;
//  - it returns the UTF-8 bytes of SerModel.SerBody(body) (the model of canon(body), encoding.ts:81).
// The caller (the TypeScript shell) signs exactly the returned bytes and does not build a body.
//
// NAMED GLUE ASSUMPTION G-H (A4 side): the shell passes preHashHex == lowercase hex SHA-256 of the UTF-8
// bytes of canon(pre) (encoding.ts:82 stateSha256(pre)), for the SAME pre that it passes as `pre`.
// This method cannot check it: it copies preHashHex into the body (Check copies it into the token).
// If the shell passes another hash text h' != H(pre):
//   (a) usually no stored state has hash h': the sink rejects the token ("stored state is not the token's
//       pre-state", sink.ts:102); no effect, but the issuer has signed a useless token;
//   (b) if the sink's stored state s' has H(s') == h' and s' != pre, the sink commits post/intent that were
//       checked against `pre`, not against s'. That is the same failure as a SHA-256 collision; it is excluded
//       only by G-H together with the no-collision hypothesis A4 (RepairedBytes.A4_NoCollisionInRun,
//       A4b_NoStoredStateCollision). A wrong h' for which some reachable s' exists breaks the slice theorem.
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "SerModel.dfy"
include "v3/inputs/transport/impl/RefundFinality.dfy"

module IssueBytes2 {
  import F = RefundFinality
  import R = Refund
  import SM = SerModel

  newtype uint8 = x: int | 0 <= x < 256

  // ---- the body for a checked transition (encoding.ts:14-17; minter.ts:53-56 builds the same fields) ----
  function Nat(x: int): nat { if x >= 0 then x else 0 }
  function StateOf(c: F.Charge): SM.ChargeState { SM.ChargeState(c.chargeId, Nat(c.original), Nat(c.remaining), c.refundEnabled) }
  function IntentOf(i: R.RefundIntent): SM.Intent { SM.Intent(i.chargeId, i.requestId, Nat(i.amount), i.reason) }
  // The body for (spec lock hex, checker hex, pre-state hash text, request id, post, intent) of t.
  function BodyFor(specHex: string, checkerHex: string, preHashHex: string, t: F.Transition): SM.TokenBody
  {
    SM.TokenBody(SM.DOMAIN, specHex, checkerHex, preHashHex, t.request.requestId, StateOf(t.post), IntentOf(t.intent))
  }
  // Nat() is the identity on the money fields of t (no value is clamped into the body).
  predicate NoClamp(t: F.Transition)
  {
    t.post.original >= 0 && t.post.remaining >= 0 && t.intent.amount >= 0
  }

  // ---- executable well-formedness (a length bound first, so a long text costs no deep recursion) ----
  lemma Utf16LenAtLeast(s: string)
    ensures SM.Utf16Len(s) >= |s|
    decreases |s|
  {
    if |s| > 0 { Utf16LenAtLeast(s[1..]); }
  }
  function TextExec(v: string): bool { |v| <= SM.MAX_TEXT && SM.Text(v) }
  lemma TextExecOk(v: string)
    ensures TextExec(v) == SM.Text(v)
  {
    Utf16LenAtLeast(v);
  }
  function WfBodyExec(b: SM.TokenBody): bool
  {
    b.domain == SM.DOMAIN && SM.Hex64(b.specLockSha256) && SM.Hex64(b.checkerSha256) && SM.Hex64(b.preStateSha256) &&
    TextExec(b.requestId) &&
    TextExec(b.post.chargeId) && SM.Money(b.post.original) && SM.Money(b.post.remaining) &&
    TextExec(b.intent.chargeId) && TextExec(b.intent.requestId) && SM.Money(b.intent.amount) && TextExec(b.intent.reason)
  }
  lemma WfBodyExecOk(b: SM.TokenBody)
    ensures WfBodyExec(b) == SM.WfBody(b)
  {
    TextExecOk(b.requestId); TextExecOk(b.post.chargeId); TextExecOk(b.intent.chargeId);
    TextExecOk(b.intent.requestId); TextExecOk(b.intent.reason);
  }

  // ---- UTF-8 bytes by a loop (no recursion over the whole body text) ----
  ghost function ToInts(u: seq<uint8>): seq<int> { seq(|u|, i requires 0 <= i < |u| => u[i] as int) }
  lemma Utf8Append(a: string, b: string)
    ensures SM.Utf8(a + b) == SM.Utf8(a) + SM.Utf8(b)
    decreases |a|
  {
    if |a| == 0 {
      assert a + b == b;
    } else {
      assert (a + b)[0] == a[0];
      assert (a + b)[1..] == a[1..] + b;
      Utf8Append(a[1..], b);
      calc {
        SM.Utf8(a + b);
        SM.Utf8Char(a[0]) + SM.Utf8(a[1..] + b);
        SM.Utf8Char(a[0]) + (SM.Utf8(a[1..]) + SM.Utf8(b));
        (SM.Utf8Char(a[0]) + SM.Utf8(a[1..])) + SM.Utf8(b);
        SM.Utf8(a) + SM.Utf8(b);
      }
    }
  }
  lemma Utf8CharRange(c: char)
    ensures forall i | 0 <= i < |SM.Utf8Char(c)| :: 0 <= SM.Utf8Char(c)[i] < 256
  {
    var v := c as int;
    assert v <= 0x10FFFF;
  }
  method Utf8Bytes(s: string) returns (u: seq<uint8>)
    ensures ToInts(u) == SM.Utf8(s)
  {
    u := [];
    var i := 0;
    while i < |s|
      invariant 0 <= i <= |s|
      invariant ToInts(u) == SM.Utf8(s[..i])
    {
      var c := SM.Utf8Char(s[i]);
      Utf8CharRange(s[i]);
      var cb := seq(|c|, k requires 0 <= k < |c| => c[k] as uint8);
      assert ToInts(cb) == c;
      assert SM.Utf8([s[i]]) == c + SM.Utf8([]);
      assert s[..i + 1] == s[..i] + [s[i]];
      Utf8Append(s[..i], [s[i]]);
      assert ToInts(u + cb) == ToInts(u) + ToInts(cb);
      u := u + cb;
      i := i + 1;
    }
    assert s[..|s|] == s;
  }

  // =============================================================================================
  // THE ISSUER CORE. The shell signs exactly r.value. No other code builds a body.
  method IssueTokenBytes(pre: F.Charge, t: F.Transition, specHex: string, checkerHex: string, preHashHex: string)
      returns (r: SM.Option<seq<uint8>>)
    // Exact issuance: bytes iff the proved checker authorizes AND the body is well-formed (isTokenBody model).
    ensures r.Some? <==> F.Authorizes(pre, t) && SM.WfBody(BodyFor(specHex, checkerHex, preHashHex, t))
    // The bytes are the UTF-8 form of the canonical text of exactly the body for this checked transition.
    ensures r.Some? ==> ToInts(r.value) == SM.Utf8(SM.SerBody(BodyFor(specHex, checkerHex, preHashHex, t)))
    // The model decoder reads that text back as exactly this body (no other body has this text).
    ensures r.Some? ==> SM.Parse(SM.SerBody(BodyFor(specHex, checkerHex, preHashHex, t))) ==
                        SM.Some(BodyFor(specHex, checkerHex, preHashHex, t))
    // No money value is clamped; the body carries the checked post-state and intent of t.
    ensures r.Some? ==> NoClamp(t) && t.intent.requestId == t.request.requestId &&
                        t.post == pre.(remaining := pre.remaining - t.request.amount)
  {
    var verdict, plan := F.Check(pre, preHashHex, t);
    if !verdict.Issue? {
      r := SM.None;
      return;
    }
    var tk := verdict.token;
    var body := SM.TokenBody(SM.DOMAIN, specHex, checkerHex, tk.preStateHash, tk.requestId,
                             StateOf(tk.post), IntentOf(tk.intent));
    assert body == BodyFor(specHex, checkerHex, preHashHex, t);
    WfBodyExecOk(body);
    if !WfBodyExec(body) {
      r := SM.None;
      return;
    }
    SM.RoundTrip(body);
    var bytes := Utf8Bytes(SM.SerBody(body));
    r := SM.Some(bytes);
  }

  // =============================================================================================
  // CONTROLS. Witnesses: an authorized transition and amount 0 issue; an unauthorized one and a U+0000 one
  // do not. Because WitnessIssue proves r.Some?, a reject-all method cannot satisfy the iff above.
  const HEXA: string := seq(64, _ => 'a')
  lemma HexWitness() ensures SM.Hex64(SM.ZERO64) && SM.Hex64(HEXA) {}
  lemma Tx1() ensures SM.Text("ch_1") { SM.TextSmall("ch_1"); }
  lemma Tx2() ensures SM.Text("rq_1") { SM.TextSmall("rq_1"); }
  lemma Tx3() ensures SM.Text("duplicate_charge") { SM.TextSmall("duplicate_charge"); }
  lemma Tx4() ensures SM.Text("rq_0") { SM.TextSmall("rq_0"); }
  // A concrete transition T(pre, rq, amount) has a well-formed body under these value conditions.
  lemma WfOfT(pre: F.Charge, rq: string, amount: int, sh: string, ch: string, h: string)
    requires SM.Text(pre.chargeId) && SM.Text(rq) && SM.Text("duplicate_charge")
    requires 0 <= amount <= pre.remaining && 0 <= pre.original < SM.MONEY_BOUND && pre.remaining < SM.MONEY_BOUND
    requires SM.Hex64(sh) && SM.Hex64(ch) && SM.Hex64(h)
    ensures SM.WfBody(BodyFor(sh, ch, h, T(pre, rq, amount)))
  {}
  const W_PRE: F.Charge := F.Charge("ch_1", 100, 60, true)
  function T(pre: F.Charge, rq: string, amount: int): F.Transition
  {
    F.Transition(F.Request(rq, amount, "duplicate_charge"), pre.(remaining := pre.remaining - amount),
                 R.Intent(pre.chargeId, rq, amount, "duplicate_charge"))
  }

  // Generic wrappers (no literals in their contexts): they only restate the iff of IssueTokenBytes.
  method IssueWhen(pre: F.Charge, t: F.Transition, sh: string, ch: string, h: string) returns (r: SM.Option<seq<uint8>>)
    requires F.Authorizes(pre, t) && SM.WfBody(BodyFor(sh, ch, h, t))
    ensures r.Some?
  {
    r := IssueTokenBytes(pre, t, sh, ch, h);
  }

  lemma W1Auth() ensures F.Authorizes(W_PRE, T(W_PRE, "rq_1", 40)) {}
  lemma W1Wf() ensures SM.WfBody(BodyFor(SM.ZERO64, SM.ZERO64, HEXA, T(W_PRE, "rq_1", 40)))
  {
    Tx1(); Tx2(); Tx3(); HexWitness();
    WfOfT(W_PRE, "rq_1", 40, SM.ZERO64, SM.ZERO64, HEXA);
  }
  lemma W0Auth() ensures F.Authorizes(W_PRE, T(W_PRE, "rq_0", 0)) { assert T(W_PRE, "rq_0", 0).post == W_PRE; }
  lemma W0Wf() ensures SM.WfBody(BodyFor(SM.ZERO64, SM.ZERO64, HEXA, T(W_PRE, "rq_0", 0)))
  {
    Tx1(); Tx3(); Tx4(); HexWitness();
    WfOfT(W_PRE, "rq_0", 0, SM.ZERO64, SM.ZERO64, HEXA);
  }
  method WitnessIssue() returns (r: SM.Option<seq<uint8>>)
    ensures r.Some?
  {
    W1Auth(); W1Wf();
    r := IssueWhen(W_PRE, T(W_PRE, "rq_1", 40), SM.ZERO64, SM.ZERO64, HEXA);
  }
  method WitnessZero() returns (r: SM.Option<seq<uint8>>)
    ensures r.Some?
    ensures T(W_PRE, "rq_0", 0).request.amount == 0
  {
    W0Auth(); W0Wf();
    r := IssueWhen(W_PRE, T(W_PRE, "rq_0", 0), SM.ZERO64, SM.ZERO64, HEXA);
  }
  method WitnessUnauthorized() returns (r: SM.Option<seq<uint8>>)
    ensures r.None?
  {
    r := IssueTokenBytes(W_PRE, T(W_PRE, "rq_1", 61), SM.ZERO64, SM.ZERO64, HEXA);
  }
  const NUL_PRE: F.Charge := F.Charge([0 as char] + "ch_1", 100, 60, true)
  method WitnessNul() returns (r: SM.Option<seq<uint8>>)
    ensures F.Authorizes(NUL_PRE, T(NUL_PRE, "rq_1", 40))     // the checker alone authorizes it ...
    ensures r.None?                                           // ... and the WfBody guard refuses it
  {
    var b := BodyFor(SM.ZERO64, SM.ZERO64, HEXA, T(NUL_PRE, "rq_1", 40));
    assert b.post.chargeId[0] as int == 0;
    assert !SM.Text(b.post.chargeId);
    r := IssueTokenBytes(NUL_PRE, T(NUL_PRE, "rq_1", 40), SM.ZERO64, SM.ZERO64, HEXA);
  }
}

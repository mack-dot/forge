// Night shift 2026-11-19, Orchestrator B, task b-ser2 (G1). A DRAFT in an evidence folder. NOT gate evidence.
// M1-B stays OPEN. A Dafny-MODEL statement only. NOT a proof about sink.ts, minter.ts, SQLite, Node, Ed25519,
// SHA-256 or compiled code.
//
// HashCore: a sink core whose token holds NO pre-state value. It mirrors what the real sink can do:
//  - the token carries the pre-state HASH text (encoding.ts TokenBody.preStateSha256) and the two pinned ids as
//    HEX TEXTS (sink.ts:84-85 compare texts); the core compares H(stored charge) with the token's hash text
//    (sink.ts:102), H a parameter function;
//  - the money fields of the token are NATURAL numbers (SM.ChargeState, SM.Intent). This is the decoder fact of
//    sink.ts:82 isToken (encoding.ts:22 MONEY regex ^(0|[1-9][0-9]{0,18})$) written as a TYPE: a decoded token
//    has no negative amount. The serializer is SerModel.SerBody on the body built from the token: a TOTAL
//    function of the token, no clamp, no ghost pre-state;
//  - plus the request-id and charge-id checks of SinkCoreV3 (d-reqid/diffs/sink-reqid-and-chargeid.diff; NOT in
//    the unpatched sink.ts). The charge id is compared with the STORED charge, the intent and the post-state.
// The structural lemmas of this file use NO assumption (arbitrary tokens, arbitrary sigOk, arbitrary H).
// IssueBytes: the issuer. It calls the PROVED F.Check and returns the signed bytes of the checked transition.
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "/Users/mackianni/forge/results/night-shift-20261119/orch-B/r-bytes3/work/SerModel.dfy"
include "/Users/mackianni/forge/results/night-shift-20261119/orch-B/r-bytes3/work/v3/inputs/transport/impl/RefundFinality.dfy"

module HashCore {
  import F = RefundFinality
  import R = Refund
  import SM = SerModel

  type Bytes = seq<int>
  type Tag = seq<int>                 // a signature is bytes (sink.ts:73 signatureBytes)
  type HashFn = F.Charge -> string    // the stored state -> its hash text (sink.ts:102 sha256hex(stored))

  // The pinned ids: 64 lower-hex texts (real shape; the values stand for sha256(spec.lock), sha256(checker)).
  const PIN_SPEC: string := Rep('a', 64)
  const PIN_CHK: string := Rep('b', 64)

  // n copies of c (a recursive function, not a seq lambda: a seq-lambda constant inside a quantifier crashes the
  // pinned Dafny 4.11.0 Boogie translation; logs/dev-scratch-SE.log).
  opaque function Rep(c: char, n: nat): string
    decreases n
  {
    if n == 0 then "" else [c] + Rep(c, n - 1)
  }
  lemma RepFacts(c: char, n: nat)
    ensures |Rep(c, n)| == n && forall i | 0 <= i < n :: Rep(c, n)[i] == c
    decreases n
  {
    reveal Rep();
    if n > 0 { RepFacts(c, n - 1); }
  }
  lemma RepHex64(c: char)
    requires SM.IsLowerHex(c)
    ensures SM.Hex64(Rep(c, 64))
  {
    RepFacts(c, 64);
  }
  lemma RepDistinct(c: char, d: char, n: nat)
    requires c != d && n > 0
    ensures Rep(c, n) != Rep(d, n)
  {
    RepFacts(c, n); RepFacts(d, n);
    assert Rep(c, n)[0] != Rep(d, n)[0];
  }

  // ---- the token (encoding.ts:14-17 TokenBody plus the signature) ----
  datatype HashToken = HashToken(specHex: string, checkerHex: string, preHash: string, requestId: string,
                                 post: SM.ChargeState, intent: SM.Intent, sig: Tag)

  // The body the sink rebuilds (domain fixed: encoding.ts:64 isTokenBody refuses another domain).
  function BodyOf(tok: HashToken): SM.TokenBody
  {
    SM.TokenBody(SM.DOMAIN, tok.specHex, tok.checkerHex, tok.preHash, tok.requestId, tok.post, tok.intent)
  }
  // The bytes the sink verifies: UTF-8 of canon(body) (encoding.ts:81). Total in the token.
  function BytesOf(tok: HashToken): Bytes { SM.SignedBytes(BodyOf(tok)) }

  function ChargeOfState(s: SM.ChargeState): F.Charge { F.Charge(s.chargeId, s.original, s.remaining, s.refundEnabled) }
  function IntentOfSM(i: SM.Intent): R.RefundIntent { R.Intent(i.chargeId, i.requestId, i.amount, i.reason) }

  // ---- the core ----
  datatype Core = Core(charge: F.Charge, settled: set<string>, outbox: seq<R.RefundIntent>)
  datatype Why = ReqIdMismatch | IdsNotPinned | SignatureInvalid | RequestSettled | PreStateMismatch | ChargeIdMismatch
  datatype Outcome = Committed | Rejected(why: Why)
  datatype StepResult = StepResult(core: Core, out: Outcome)

  predicate Match(tok: HashToken) { tok.intent.requestId == tok.requestId }
  predicate ChargeOk(stored: F.Charge, tok: HashToken)
  {
    stored.chargeId == tok.intent.chargeId && tok.post.chargeId == tok.intent.chargeId
  }

  // Order of the checks: ids (sink.ts:84-85), signature (:86), request id (patch), settled (:91), pre-state HASH
  // (:102), charge id (patch); commit (:106-108).
  function Step(H: HashFn, core: Core, tok: HashToken, sigOk: bool): StepResult
  {
    if tok.specHex != PIN_SPEC || tok.checkerHex != PIN_CHK then StepResult(core, Rejected(IdsNotPinned))
    else if !sigOk then StepResult(core, Rejected(SignatureInvalid))
    else if !Match(tok) then StepResult(core, Rejected(ReqIdMismatch))
    else if tok.requestId in core.settled then StepResult(core, Rejected(RequestSettled))
    else if H(ChargeOfState(tok.post)) != tok.preHash then StepResult(core, Rejected(PreStateMismatch))   // MUTANT post-hash
    else if !ChargeOk(core.charge, tok) then StepResult(core, Rejected(ChargeIdMismatch))
    else StepResult(Core(ChargeOfState(tok.post), core.settled + {tok.requestId}, core.outbox + [IntentOfSM(tok.intent)]),
                    Committed)
  }

  // ---- structural lemmas (NO assumption) ----
  // Exact acceptance: rules out a reject-all core and a commit-all core.
  lemma StepExact(H: HashFn, core: Core, tok: HashToken, sigOk: bool)
    ensures Step(H, core, tok, sigOk).out.Committed? <==>
      (tok.specHex == PIN_SPEC && tok.checkerHex == PIN_CHK && sigOk && Match(tok) &&
       tok.requestId !in core.settled && H(core.charge) == tok.preHash && ChargeOk(core.charge, tok))
    ensures Step(H, core, tok, sigOk).out.Committed? ==>
      Step(H, core, tok, sigOk).core ==
        Core(ChargeOfState(tok.post), core.settled + {tok.requestId}, core.outbox + [IntentOfSM(tok.intent)])
    ensures !Step(H, core, tok, sigOk).out.Committed? ==> Step(H, core, tok, sigOk).core == core
  {}

  lemma RejectedChangesNothing(H: HashFn, core: Core, tok: HashToken, sigOk: bool)
    ensures !Step(H, core, tok, sigOk).out.Committed? ==> Step(H, core, tok, sigOk).core == core
  {}

  lemma MismatchNeverCommits(H: HashFn, core: Core, tok: HashToken, sigOk: bool)
    requires !Match(tok)
    ensures !Step(H, core, tok, sigOk).out.Committed? && Step(H, core, tok, sigOk).core == core
  {}

  lemma ForeignChargeNeverCommits(H: HashFn, core: Core, tok: HashToken, sigOk: bool)
    requires tok.intent.chargeId != core.charge.chargeId || tok.post.chargeId != core.charge.chargeId
    ensures !Step(H, core, tok, sigOk).out.Committed? && Step(H, core, tok, sigOk).core == core
  {}

  lemma WrongHashNeverCommits(H: HashFn, core: Core, tok: HashToken, sigOk: bool)
    requires H(core.charge) != tok.preHash
    ensures !Step(H, core, tok, sigOk).out.Committed? && Step(H, core, tok, sigOk).core == core
  {}

  // Id binding: a commit fixes the pinned hex ids, the hash of the stored state, the request id and the charge id.
  lemma CommitBindsIds(H: HashFn, core: Core, tok: HashToken, sigOk: bool)
    requires Step(H, core, tok, sigOk).out.Committed?
    ensures tok.specHex == PIN_SPEC && tok.checkerHex == PIN_CHK && sigOk
    ensures H(core.charge) == tok.preHash && IntentOfSM(tok.intent).requestId == tok.requestId
    ensures IntentOfSM(tok.intent).chargeId == core.charge.chargeId && ChargeOfState(tok.post).chargeId == core.charge.chargeId
  {}

  // Zero amount stays a legitimate commit (spec/refund/protocol.md).
  lemma ZeroAmountStillCommits(H: HashFn, core: Core, tok: HashToken)
    requires tok.specHex == PIN_SPEC && tok.checkerHex == PIN_CHK && Match(tok)
    requires tok.requestId !in core.settled && H(core.charge) == tok.preHash && tok.intent.amount == 0
    requires tok.intent.chargeId == core.charge.chargeId && ChargeOfState(tok.post) == core.charge
    ensures Step(H, core, tok, true).out.Committed?
    ensures Step(H, core, tok, true).core == Core(core.charge, core.settled + {tok.requestId}, core.outbox + [IntentOfSM(tok.intent)])
  {}

  // No negative money in a decoded token (by type): the amount -1 token of r-ser B6Control has no HashToken.
  lemma DecodedMoneyNonNeg(tok: HashToken)
    ensures IntentOfSM(tok.intent).amount >= 0
    ensures ChargeOfState(tok.post).original >= 0 && ChargeOfState(tok.post).remaining >= 0
  {}

  lemma NoNegativeAmountTwin(tok: HashToken, c: string, r: string, reason: string)
    ensures IntentOfSM(tok.intent) != R.Intent(c, r, -1, reason)
  {}

  // The verified bytes determine the token (all fields but the signature). No well-formedness needed.
  lemma BytesInjective(t1: HashToken, t2: HashToken)
    requires BytesOf(t1) == BytesOf(t2)
    ensures t1.(sig := []) == t2.(sig := [])
  {
    SM.SignedBytesInjective(BodyOf(t1), BodyOf(t2));
  }

  // ---- runs of arbitrary deliveries (no assumption) ----
  datatype Delivery = Delivery(tok: HashToken, sigOk: bool)

  function Run(H: HashFn, core: Core, ds: seq<Delivery>): Core
    decreases |ds|
  {
    if |ds| == 0 then core else Run(H, Step(H, core, ds[0].tok, ds[0].sigOk).core, ds[1..])
  }

  lemma RunGrowth(H: HashFn, c: Core, ds: seq<Delivery>)
    ensures c.settled <= Run(H, c, ds).settled
    ensures |c.outbox| <= |Run(H, c, ds).outbox| && Run(H, c, ds).outbox[..|c.outbox|] == c.outbox
    ensures |Run(H, c, ds).outbox| - |c.outbox| == |Run(H, c, ds).settled| - |c.settled|
    ensures forall i | |c.outbox| <= i < |Run(H, c, ds).outbox| ::
      Run(H, c, ds).outbox[i].requestId in Run(H, c, ds).settled && Run(H, c, ds).outbox[i].requestId !in c.settled
    ensures forall i, j | |c.outbox| <= i < j < |Run(H, c, ds).outbox| ::
      Run(H, c, ds).outbox[i].requestId != Run(H, c, ds).outbox[j].requestId
    ensures Run(H, c, ds).charge.chargeId == c.charge.chargeId
    ensures forall i | |c.outbox| <= i < |Run(H, c, ds).outbox| ::
      Run(H, c, ds).outbox[i].chargeId == c.charge.chargeId && Run(H, c, ds).outbox[i].amount >= 0
    decreases |ds|
  {
    if |ds| > 0 {
      var d := ds[0];
      var c1 := Step(H, c, d.tok, d.sigOk).core;
      StepExact(H, c, d.tok, d.sigOk);
      RunGrowth(H, c1, ds[1..]);
      var c' := Run(H, c, ds);
      assert c' == Run(H, c1, ds[1..]);
      if Step(H, c, d.tok, d.sigOk).out.Committed? {
        var r := d.tok.requestId;
        var e := IntentOfSM(d.tok.intent);
        assert c1.settled == c.settled + {r} && r !in c.settled;
        assert |c1.settled| == |c.settled| + 1;
        assert c1.outbox == c.outbox + [e] && e.requestId == r;
        assert c1.charge.chargeId == c.charge.chargeId && e.chargeId == c.charge.chargeId && e.amount >= 0;
        assert c'.outbox[..|c1.outbox|] == c1.outbox;
        assert c'.outbox[..|c.outbox|] == c1.outbox[..|c.outbox|] == c.outbox;
        assert c'.outbox[|c.outbox|] == c1.outbox[|c.outbox|];
        forall i | |c.outbox| <= i < |c'.outbox|
          ensures c'.outbox[i].requestId in c'.settled && c'.outbox[i].requestId !in c.settled
          ensures c'.outbox[i].chargeId == c.charge.chargeId && c'.outbox[i].amount >= 0
        {
          if i == |c.outbox| {
            assert c'.outbox[i].requestId == r && c'.outbox[i] == e;
          }
        }
        forall i, j | |c.outbox| <= i < j < |c'.outbox|
          ensures c'.outbox[i].requestId != c'.outbox[j].requestId
        {
          if i == |c.outbox| {
            assert c'.outbox[i].requestId == r && r in c1.settled;
            assert c'.outbox[j].requestId !in c1.settled;
          }
        }
      } else {
        assert c1 == c;
      }
    }
  }

  // The store invariant: every outbox request id is settled, at most one entry per request id,
  // |outbox| == |settled|, every entry carries the stored charge id.
  ghost predicate GoodV3(c: Core)
  {
    (forall i | 0 <= i < |c.outbox| :: c.outbox[i].requestId in c.settled) &&
    (forall i, j | 0 <= i < j < |c.outbox| :: c.outbox[i].requestId != c.outbox[j].requestId) &&
    |c.outbox| == |c.settled| &&
    (forall i | 0 <= i < |c.outbox| :: c.outbox[i].chargeId == c.charge.chargeId)
  }

  lemma RunKeepsGoodV3(H: HashFn, c: Core, ds: seq<Delivery>)
    requires GoodV3(c)
    ensures GoodV3(Run(H, c, ds))
    ensures Run(H, c, ds).charge.chargeId == c.charge.chargeId
  {
    RunGrowth(H, c, ds);
    var c' := Run(H, c, ds);
    forall i | 0 <= i < |c'.outbox|
      ensures c'.outbox[i].requestId in c'.settled && c'.outbox[i].chargeId == c'.charge.chargeId
    {
      if i < |c.outbox| {
        assert c'.outbox[i] == c'.outbox[..|c.outbox|][i] == c.outbox[i];
      }
    }
    forall i, j | 0 <= i < j < |c'.outbox|
      ensures c'.outbox[i].requestId != c'.outbox[j].requestId
    {
      if j < |c.outbox| {
        assert c'.outbox[i] == c'.outbox[..|c.outbox|][i] == c.outbox[i];
        assert c'.outbox[j] == c'.outbox[..|c.outbox|][j] == c.outbox[j];
      } else if i < |c.outbox| {
        assert c'.outbox[i] == c'.outbox[..|c.outbox|][i] == c.outbox[i];
        assert c'.outbox[i].requestId in c.settled;
      }
    }
  }

  // Uniqueness per request id from a fresh store: any tokens, any sigOk, any H.
  lemma FromInitGood(H: HashFn, init: F.Charge, ds: seq<Delivery>)
    ensures GoodV3(Run(H, Core(init, {}, []), ds))
    ensures Run(H, Core(init, {}, []), ds).charge.chargeId == init.chargeId
  {
    RunKeepsGoodV3(H, Core(init, {}, []), ds);
  }

  // =============================================================================================
  // The issuer. IssueBody is the body that minter.ts builds from Check's token; it needs no clamp because
  // F.Authorizes gives non-negative money (AuthorizedMoneyNonNeg).
  predicate MoneyNonNeg(t: F.Transition)
  {
    t.post.original >= 0 && t.post.remaining >= 0 && t.intent.amount >= 0
  }
  function StateOfN(c: F.Charge): SM.ChargeState
    requires c.original >= 0 && c.remaining >= 0
  {
    SM.ChargeState(c.chargeId, c.original, c.remaining, c.refundEnabled)
  }
  function IntentOfN(i: R.RefundIntent): SM.Intent
    requires i.amount >= 0
  {
    SM.Intent(i.chargeId, i.requestId, i.amount, i.reason)
  }
  function IssueBody(H: HashFn, pre: F.Charge, t: F.Transition): SM.TokenBody
    requires MoneyNonNeg(t)
  {
    SM.TokenBody(SM.DOMAIN, PIN_SPEC, PIN_CHK, H(pre), t.request.requestId, StateOfN(t.post), IntentOfN(t.intent))
  }
  function IssueOut(H: HashFn, pre: F.Charge, t: F.Transition): Bytes
    requires MoneyNonNeg(t)
  {
    SM.SignedBytes(IssueBody(H, pre, t))
  }
  // "msg is an output of IssueBytes(pre, t)": the postcondition of IssueBytes on Some.
  ghost predicate IssuedFrom(H: HashFn, pre: F.Charge, t: F.Transition, msg: Bytes)
  {
    F.Authorizes(pre, t) && MoneyNonNeg(t) && msg == IssueOut(H, pre, t)
  }

  lemma AuthorizedMoneyNonNeg(pre: F.Charge, t: F.Transition)
    requires F.Authorizes(pre, t)
    ensures MoneyNonNeg(t)
    ensures 0 <= t.request.amount <= pre.remaining <= pre.original
    ensures t.post.original == pre.original && t.post.remaining == pre.remaining - t.request.amount
  {}

  method IssueBytes(H: HashFn, pre: F.Charge, t: F.Transition) returns (out: SM.Option<Bytes>)
    ensures out.Some? <==> F.Authorizes(pre, t)
    ensures out.Some? ==> IssuedFrom(H, pre, t, out.value)
  {
    var verdict, plan := F.Check(pre, H(pre), t);
    if verdict.Issue? {
      AuthorizedMoneyNonNeg(pre, t);
      var tk := verdict.token;
      var body := SM.TokenBody(SM.DOMAIN, PIN_SPEC, PIN_CHK, tk.preStateHash, tk.requestId,
                               StateOfN(tk.post), IntentOfN(tk.intent));
      assert body == IssueBody(H, pre, t);
      out := SM.Some(SM.SignedBytes(body));
    } else {
      out := SM.None;
    }
  }

  // Issued bytes read back: the token whose bytes equal IssueOut(H, pre, t) carries exactly H(pre), the pinned
  // ids, the checked post-state and intent (no well-formedness, no Text condition: r-ser item 4).
  lemma IssuedTokenFields(H: HashFn, pre: F.Charge, t: F.Transition, tok: HashToken)
    requires MoneyNonNeg(t)
    requires BytesOf(tok) == IssueOut(H, pre, t)
    ensures BodyOf(tok) == IssueBody(H, pre, t)
    ensures tok.preHash == H(pre) && tok.specHex == PIN_SPEC && tok.checkerHex == PIN_CHK
    ensures tok.requestId == t.request.requestId
    ensures ChargeOfState(tok.post) == t.post && IntentOfSM(tok.intent) == t.intent
  {
    SM.SignedBytesInjective(BodyOf(tok), IssueBody(H, pre, t));
  }
}

// Dafny program AuditCompile.dfy compiled into JavaScript
let Refund = (function() {
  let $module = {};

  $module.__default = class __default {
    constructor () {
      this._tname = "Refund._default";
    }
    _parentTraits() {
      return [];
    }
    static Assess(context, response) {
      let decision = Refund.Decision.Default();
      let plan = _dafny.Seq.of();
      if (Refund.__default.Eligible(context, response)) {
        decision = Refund.Decision.create_Authorized((response).dtor_amount, (response).dtor_reason);
        plan = _dafny.Seq.of(Refund.RefundIntent.create_Intent((context).dtor_chargeId, (context).dtor_requestId, (response).dtor_amount, (response).dtor_reason));
      } else {
        decision = Refund.Decision.create_Rejected();
        plan = _dafny.Seq.of();
      }
      return [decision, plan];
    }
    static Money(value) {
      return ((_dafny.ZERO).isLessThanOrEqualTo(value)) && ((value).isLessThanOrEqualTo(Refund.__default.MaxMoney));
    };
    static AllowedReason(reason) {
      return (_dafny.Set.fromElements(_dafny.Seq.UnicodeFromString("duplicate_charge"), _dafny.Seq.UnicodeFromString("service_not_delivered"), _dafny.Seq.UnicodeFromString("returned_item"))).contains(reason);
    };
    static ValidContext(context) {
      return (((((!_dafny.areEqual((context).dtor_chargeId, _dafny.Seq.UnicodeFromString(""))) && (!_dafny.areEqual((context).dtor_requestId, _dafny.Seq.UnicodeFromString("")))) && ((context).dtor_refundEnabled)) && ((context).dtor_requestOpen)) && (Refund.__default.Money((context).dtor_original))) && (((_dafny.ZERO).isLessThanOrEqualTo((context).dtor_remaining)) && (((context).dtor_remaining).isLessThanOrEqualTo((context).dtor_original)));
    };
    static Eligible(context, response) {
      return (((Refund.__default.ValidContext(context)) && ((response).is_Candidate)) && (((_dafny.ZERO).isLessThanOrEqualTo((response).dtor_amount)) && (((response).dtor_amount).isLessThanOrEqualTo((context).dtor_remaining)))) && (Refund.__default.AllowedReason((response).dtor_reason));
    };
    static get MaxMoney() {
      return new BigNumber("9223372036854775807");
    };
  };

  $module.Context = class Context {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_ChargeContext(chargeId, requestId, original, remaining, refundEnabled, requestOpen) {
      let $dt = new Context(0);
      $dt.chargeId = chargeId;
      $dt.requestId = requestId;
      $dt.original = original;
      $dt.remaining = remaining;
      $dt.refundEnabled = refundEnabled;
      $dt.requestOpen = requestOpen;
      return $dt;
    }
    get is_ChargeContext() { return this.$tag === 0; }
    get dtor_chargeId() { return this.chargeId; }
    get dtor_requestId() { return this.requestId; }
    get dtor_original() { return this.original; }
    get dtor_remaining() { return this.remaining; }
    get dtor_refundEnabled() { return this.refundEnabled; }
    get dtor_requestOpen() { return this.requestOpen; }
    toString() {
      if (this.$tag === 0) {
        return "Refund.Context.ChargeContext" + "(" + this.chargeId.toVerbatimString(true) + ", " + this.requestId.toVerbatimString(true) + ", " + _dafny.toString(this.original) + ", " + _dafny.toString(this.remaining) + ", " + _dafny.toString(this.refundEnabled) + ", " + _dafny.toString(this.requestOpen) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.chargeId, other.chargeId) && _dafny.areEqual(this.requestId, other.requestId) && _dafny.areEqual(this.original, other.original) && _dafny.areEqual(this.remaining, other.remaining) && this.refundEnabled === other.refundEnabled && this.requestOpen === other.requestOpen;
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return Refund.Context.create_ChargeContext(_dafny.Seq.UnicodeFromString(""), _dafny.Seq.UnicodeFromString(""), _dafny.ZERO, _dafny.ZERO, false, false);
    }
    static Rtd() {
      return class {
        static get Default() {
          return Context.Default();
        }
      };
    }
  }

  $module.ModelResponse = class ModelResponse {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Candidate(amount, reason) {
      let $dt = new ModelResponse(0);
      $dt.amount = amount;
      $dt.reason = reason;
      return $dt;
    }
    static create_Missing() {
      let $dt = new ModelResponse(1);
      return $dt;
    }
    static create_TimedOut() {
      let $dt = new ModelResponse(2);
      return $dt;
    }
    static create_Failed() {
      let $dt = new ModelResponse(3);
      return $dt;
    }
    static create_Malformed() {
      let $dt = new ModelResponse(4);
      return $dt;
    }
    static create_Oversized() {
      let $dt = new ModelResponse(5);
      return $dt;
    }
    static create_Unsupported() {
      let $dt = new ModelResponse(6);
      return $dt;
    }
    get is_Candidate() { return this.$tag === 0; }
    get is_Missing() { return this.$tag === 1; }
    get is_TimedOut() { return this.$tag === 2; }
    get is_Failed() { return this.$tag === 3; }
    get is_Malformed() { return this.$tag === 4; }
    get is_Oversized() { return this.$tag === 5; }
    get is_Unsupported() { return this.$tag === 6; }
    get dtor_amount() { return this.amount; }
    get dtor_reason() { return this.reason; }
    toString() {
      if (this.$tag === 0) {
        return "Refund.ModelResponse.Candidate" + "(" + _dafny.toString(this.amount) + ", " + this.reason.toVerbatimString(true) + ")";
      } else if (this.$tag === 1) {
        return "Refund.ModelResponse.Missing";
      } else if (this.$tag === 2) {
        return "Refund.ModelResponse.TimedOut";
      } else if (this.$tag === 3) {
        return "Refund.ModelResponse.Failed";
      } else if (this.$tag === 4) {
        return "Refund.ModelResponse.Malformed";
      } else if (this.$tag === 5) {
        return "Refund.ModelResponse.Oversized";
      } else if (this.$tag === 6) {
        return "Refund.ModelResponse.Unsupported";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.amount, other.amount) && _dafny.areEqual(this.reason, other.reason);
      } else if (this.$tag === 1) {
        return other.$tag === 1;
      } else if (this.$tag === 2) {
        return other.$tag === 2;
      } else if (this.$tag === 3) {
        return other.$tag === 3;
      } else if (this.$tag === 4) {
        return other.$tag === 4;
      } else if (this.$tag === 5) {
        return other.$tag === 5;
      } else if (this.$tag === 6) {
        return other.$tag === 6;
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return Refund.ModelResponse.create_Candidate(_dafny.ZERO, _dafny.Seq.UnicodeFromString(""));
    }
    static Rtd() {
      return class {
        static get Default() {
          return ModelResponse.Default();
        }
      };
    }
  }

  $module.Decision = class Decision {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Rejected() {
      let $dt = new Decision(0);
      return $dt;
    }
    static create_Authorized(amount, reason) {
      let $dt = new Decision(1);
      $dt.amount = amount;
      $dt.reason = reason;
      return $dt;
    }
    get is_Rejected() { return this.$tag === 0; }
    get is_Authorized() { return this.$tag === 1; }
    get dtor_amount() { return this.amount; }
    get dtor_reason() { return this.reason; }
    toString() {
      if (this.$tag === 0) {
        return "Refund.Decision.Rejected";
      } else if (this.$tag === 1) {
        return "Refund.Decision.Authorized" + "(" + _dafny.toString(this.amount) + ", " + this.reason.toVerbatimString(true) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0;
      } else if (this.$tag === 1) {
        return other.$tag === 1 && _dafny.areEqual(this.amount, other.amount) && _dafny.areEqual(this.reason, other.reason);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return Refund.Decision.create_Rejected();
    }
    static Rtd() {
      return class {
        static get Default() {
          return Decision.Default();
        }
      };
    }
  }

  $module.RefundIntent = class RefundIntent {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Intent(chargeId, requestId, amount, reason) {
      let $dt = new RefundIntent(0);
      $dt.chargeId = chargeId;
      $dt.requestId = requestId;
      $dt.amount = amount;
      $dt.reason = reason;
      return $dt;
    }
    get is_Intent() { return this.$tag === 0; }
    get dtor_chargeId() { return this.chargeId; }
    get dtor_requestId() { return this.requestId; }
    get dtor_amount() { return this.amount; }
    get dtor_reason() { return this.reason; }
    toString() {
      if (this.$tag === 0) {
        return "Refund.RefundIntent.Intent" + "(" + this.chargeId.toVerbatimString(true) + ", " + this.requestId.toVerbatimString(true) + ", " + _dafny.toString(this.amount) + ", " + this.reason.toVerbatimString(true) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.chargeId, other.chargeId) && _dafny.areEqual(this.requestId, other.requestId) && _dafny.areEqual(this.amount, other.amount) && _dafny.areEqual(this.reason, other.reason);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return Refund.RefundIntent.create_Intent(_dafny.Seq.UnicodeFromString(""), _dafny.Seq.UnicodeFromString(""), _dafny.ZERO, _dafny.Seq.UnicodeFromString(""));
    }
    static Rtd() {
      return class {
        static get Default() {
          return RefundIntent.Default();
        }
      };
    }
  }
  return $module;
})(); // end of module Refund
let RefundFinality = (function() {
  let $module = {};

  $module.__default = class __default {
    constructor () {
      this._tname = "RefundFinality._default";
    }
    _parentTraits() {
      return [];
    }
    static ContextOf(pre, requestId) {
      return Refund.Context.create_ChargeContext((pre).dtor_chargeId, requestId, (pre).dtor_original, (pre).dtor_remaining, (pre).dtor_refundEnabled, true);
    };
    static Check(pre, preStateHash, t) {
      let verdict = RefundFinality.Verdict.Default();
      let plan = _dafny.Seq.of();
      let _0_decision;
      let _1_assessed;
      let _out0;
      let _out1;
      let _outcollector0 = Refund.__default.Assess(RefundFinality.__default.ContextOf(pre, ((t).dtor_request).dtor_requestId), Refund.ModelResponse.create_Candidate(((t).dtor_request).dtor_amount, ((t).dtor_request).dtor_reason));
      _out0 = _outcollector0[0];
      _out1 = _outcollector0[1];
      _0_decision = _out0;
      _1_assessed = _out1;
      let _pat_let_tv0 = pre;
      let _pat_let_tv1 = _0_decision;
      if (((((_0_decision).is_Authorized) && ((new BigNumber((_1_assessed).length)).isEqualTo(_dafny.ONE))) && (_dafny.areEqual((t).dtor_post, function (_pat_let0_0) {
        return function (_2_dt__update__tmp_h0) {
          return function (_pat_let1_0) {
            return function (_3_dt__update_hremaining_h0) {
              return RefundFinality.Charge.create_Charge((_2_dt__update__tmp_h0).dtor_chargeId, (_2_dt__update__tmp_h0).dtor_original, _3_dt__update_hremaining_h0, (_2_dt__update__tmp_h0).dtor_refundEnabled);
            }(_pat_let1_0);
          }(((_pat_let_tv0).dtor_remaining).minus((_pat_let_tv1).dtor_amount));
        }(_pat_let0_0);
      }(pre)))) && (_dafny.areEqual((t).dtor_intent, (_1_assessed)[_dafny.ZERO]))) {
        verdict = RefundFinality.Verdict.create_Issue(RefundFinality.Token.create_Token(preStateHash, ((t).dtor_request).dtor_requestId, (t).dtor_post, (t).dtor_intent));
        plan = _dafny.Seq.of((t).dtor_intent);
      } else {
        verdict = RefundFinality.Verdict.create_Refuse();
        plan = _dafny.Seq.of();
      }
      return [verdict, plan];
    }
  };

  $module.Charge = class Charge {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Charge(chargeId, original, remaining, refundEnabled) {
      let $dt = new Charge(0);
      $dt.chargeId = chargeId;
      $dt.original = original;
      $dt.remaining = remaining;
      $dt.refundEnabled = refundEnabled;
      return $dt;
    }
    get is_Charge() { return this.$tag === 0; }
    get dtor_chargeId() { return this.chargeId; }
    get dtor_original() { return this.original; }
    get dtor_remaining() { return this.remaining; }
    get dtor_refundEnabled() { return this.refundEnabled; }
    toString() {
      if (this.$tag === 0) {
        return "RefundFinality.Charge.Charge" + "(" + this.chargeId.toVerbatimString(true) + ", " + _dafny.toString(this.original) + ", " + _dafny.toString(this.remaining) + ", " + _dafny.toString(this.refundEnabled) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.chargeId, other.chargeId) && _dafny.areEqual(this.original, other.original) && _dafny.areEqual(this.remaining, other.remaining) && this.refundEnabled === other.refundEnabled;
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return RefundFinality.Charge.create_Charge(_dafny.Seq.UnicodeFromString(""), _dafny.ZERO, _dafny.ZERO, false);
    }
    static Rtd() {
      return class {
        static get Default() {
          return Charge.Default();
        }
      };
    }
  }

  $module.Request = class Request {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Request(requestId, amount, reason) {
      let $dt = new Request(0);
      $dt.requestId = requestId;
      $dt.amount = amount;
      $dt.reason = reason;
      return $dt;
    }
    get is_Request() { return this.$tag === 0; }
    get dtor_requestId() { return this.requestId; }
    get dtor_amount() { return this.amount; }
    get dtor_reason() { return this.reason; }
    toString() {
      if (this.$tag === 0) {
        return "RefundFinality.Request.Request" + "(" + this.requestId.toVerbatimString(true) + ", " + _dafny.toString(this.amount) + ", " + this.reason.toVerbatimString(true) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.requestId, other.requestId) && _dafny.areEqual(this.amount, other.amount) && _dafny.areEqual(this.reason, other.reason);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return RefundFinality.Request.create_Request(_dafny.Seq.UnicodeFromString(""), _dafny.ZERO, _dafny.Seq.UnicodeFromString(""));
    }
    static Rtd() {
      return class {
        static get Default() {
          return Request.Default();
        }
      };
    }
  }

  $module.Transition = class Transition {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Transition(request, post, intent) {
      let $dt = new Transition(0);
      $dt.request = request;
      $dt.post = post;
      $dt.intent = intent;
      return $dt;
    }
    get is_Transition() { return this.$tag === 0; }
    get dtor_request() { return this.request; }
    get dtor_post() { return this.post; }
    get dtor_intent() { return this.intent; }
    toString() {
      if (this.$tag === 0) {
        return "RefundFinality.Transition.Transition" + "(" + _dafny.toString(this.request) + ", " + _dafny.toString(this.post) + ", " + _dafny.toString(this.intent) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.request, other.request) && _dafny.areEqual(this.post, other.post) && _dafny.areEqual(this.intent, other.intent);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return RefundFinality.Transition.create_Transition(RefundFinality.Request.Default(), RefundFinality.Charge.Default(), Refund.RefundIntent.Default());
    }
    static Rtd() {
      return class {
        static get Default() {
          return Transition.Default();
        }
      };
    }
  }

  $module.Token = class Token {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Token(preStateHash, requestId, post, intent) {
      let $dt = new Token(0);
      $dt.preStateHash = preStateHash;
      $dt.requestId = requestId;
      $dt.post = post;
      $dt.intent = intent;
      return $dt;
    }
    get is_Token() { return this.$tag === 0; }
    get dtor_preStateHash() { return this.preStateHash; }
    get dtor_requestId() { return this.requestId; }
    get dtor_post() { return this.post; }
    get dtor_intent() { return this.intent; }
    toString() {
      if (this.$tag === 0) {
        return "RefundFinality.Token.Token" + "(" + this.preStateHash.toVerbatimString(true) + ", " + this.requestId.toVerbatimString(true) + ", " + _dafny.toString(this.post) + ", " + _dafny.toString(this.intent) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.preStateHash, other.preStateHash) && _dafny.areEqual(this.requestId, other.requestId) && _dafny.areEqual(this.post, other.post) && _dafny.areEqual(this.intent, other.intent);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return RefundFinality.Token.create_Token(_dafny.Seq.UnicodeFromString(""), _dafny.Seq.UnicodeFromString(""), RefundFinality.Charge.Default(), Refund.RefundIntent.Default());
    }
    static Rtd() {
      return class {
        static get Default() {
          return Token.Default();
        }
      };
    }
  }

  $module.Verdict = class Verdict {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Refuse() {
      let $dt = new Verdict(0);
      return $dt;
    }
    static create_Issue(token) {
      let $dt = new Verdict(1);
      $dt.token = token;
      return $dt;
    }
    get is_Refuse() { return this.$tag === 0; }
    get is_Issue() { return this.$tag === 1; }
    get dtor_token() { return this.token; }
    toString() {
      if (this.$tag === 0) {
        return "RefundFinality.Verdict.Refuse";
      } else if (this.$tag === 1) {
        return "RefundFinality.Verdict.Issue" + "(" + _dafny.toString(this.token) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0;
      } else if (this.$tag === 1) {
        return other.$tag === 1 && _dafny.areEqual(this.token, other.token);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return RefundFinality.Verdict.create_Refuse();
    }
    static Rtd() {
      return class {
        static get Default() {
          return Verdict.Default();
        }
      };
    }
  }
  return $module;
})(); // end of module RefundFinality
let SinkCoreV3 = (function() {
  let $module = {};

  $module.__default = class __default {
    constructor () {
      this._tname = "SinkCoreV3._default";
    }
    _parentTraits() {
      return [];
    }
    static Enc(s) {
      if ((new BigNumber((s).length)).isEqualTo(_dafny.ZERO)) {
        return _dafny.ZERO;
      } else {
        return ((new BigNumber(((s)[_dafny.ZERO]).value)).plus(_dafny.ONE)).plus((SinkCoreV3.__default.B).multipliedBy(SinkCoreV3.__default.Enc((s).slice(_dafny.ONE))));
      }
    };
    static ClaimOf(tok) {
      return SinkCoreV3.Claim.create_Claim((tok).dtor_specId, (tok).dtor_checkerId, (tok).dtor_pre, SinkCoreV3.__default.Enc((tok).dtor_requestId), RefundFinality.Request.create_Request((tok).dtor_requestId, ((tok).dtor_intent).dtor_amount, ((tok).dtor_intent).dtor_reason), (tok).dtor_post, (tok).dtor_intent);
    };
    static Match(tok) {
      return _dafny.areEqual(((tok).dtor_intent).dtor_requestId, (tok).dtor_requestId);
    };
    static ChargeOk(stored, tok) {
      return (_dafny.areEqual((stored).dtor_chargeId, ((tok).dtor_intent).dtor_chargeId)) && (_dafny.areEqual(((tok).dtor_post).dtor_chargeId, ((tok).dtor_intent).dtor_chargeId));
    };
    static Step(core, tok, sigOk) {
      if ((!((tok).dtor_specId).isEqualTo(SinkCoreV3.__default.PINNED__SPEC)) || (!((tok).dtor_checkerId).isEqualTo(SinkCoreV3.__default.PINNED__CHK))) {
        return SinkCoreV3.StepResult.create_StepResult(core, SinkCoreV3.Outcome.create_Rejected(SinkCoreV3.Why.create_IdsNotPinned()));
      } else if (!(sigOk)) {
        return SinkCoreV3.StepResult.create_StepResult(core, SinkCoreV3.Outcome.create_Rejected(SinkCoreV3.Why.create_SignatureInvalid()));
      } else if (!(SinkCoreV3.__default.Match(tok))) {
        return SinkCoreV3.StepResult.create_StepResult(core, SinkCoreV3.Outcome.create_Rejected(SinkCoreV3.Why.create_ReqIdMismatch()));
      } else if (((core).dtor_settled).contains((tok).dtor_requestId)) {
        return SinkCoreV3.StepResult.create_StepResult(core, SinkCoreV3.Outcome.create_Rejected(SinkCoreV3.Why.create_RequestSettled()));
      } else if (!_dafny.areEqual((core).dtor_charge, (tok).dtor_pre)) {
        return SinkCoreV3.StepResult.create_StepResult(core, SinkCoreV3.Outcome.create_Rejected(SinkCoreV3.Why.create_PreStateMismatch()));
      } else if (!(SinkCoreV3.__default.ChargeOk((core).dtor_charge, tok))) {
        return SinkCoreV3.StepResult.create_StepResult(core, SinkCoreV3.Outcome.create_Rejected(SinkCoreV3.Why.create_ChargeIdMismatch()));
      } else {
        return SinkCoreV3.StepResult.create_StepResult(SinkCoreV3.Core.create_Core((tok).dtor_post, ((core).dtor_settled).Union(_dafny.Set.fromElements((tok).dtor_requestId)), _dafny.Seq.Concat((core).dtor_outbox, _dafny.Seq.of((tok).dtor_intent))), SinkCoreV3.Outcome.create_Committed());
      }
    };
    static NextToks(toks, tok, out) {
      if ((out).is_Committed) {
        return _dafny.Seq.Concat(toks, _dafny.Seq.of(tok));
      } else {
        return toks;
      }
    };
    static Run(core, ds) {
      TAIL_CALL_START: while (true) {
        if ((new BigNumber((ds).length)).isEqualTo(_dafny.ZERO)) {
          return core;
        } else {
          let _in0 = (SinkCoreV3.__default.Step(core, ((ds)[_dafny.ZERO]).dtor_tok, ((ds)[_dafny.ZERO]).dtor_sigOk)).dtor_core;
          let _in1 = (ds).slice(_dafny.ONE);
          core = _in0;
          ds = _in1;
          continue TAIL_CALL_START;
        }
      }
    };
    static AuditStart(c) {
      return (((_dafny.Quantifier(_dafny.IntegerRange(_dafny.ZERO, new BigNumber(((c).dtor_outbox).length)), true, function (_forall_var_0) {
        let _0_i = _forall_var_0;
        return !(((_dafny.ZERO).isLessThanOrEqualTo(_0_i)) && ((_0_i).isLessThan(new BigNumber(((c).dtor_outbox).length)))) || (((c).dtor_settled).contains((((c).dtor_outbox)[_0_i]).dtor_requestId));
      })) && (_dafny.Quantifier(_dafny.IntegerRange(_dafny.ZERO, new BigNumber(((c).dtor_outbox).length)), true, function (_forall_var_1) {
        let _1_i = _forall_var_1;
        return _dafny.Quantifier(_dafny.IntegerRange((_1_i).plus(_dafny.ONE), new BigNumber(((c).dtor_outbox).length)), true, function (_forall_var_2) {
          let _2_j = _forall_var_2;
          return !((((_dafny.ZERO).isLessThanOrEqualTo(_1_i)) && ((_1_i).isLessThan(_2_j))) && ((_2_j).isLessThan(new BigNumber(((c).dtor_outbox).length)))) || (!_dafny.areEqual((((c).dtor_outbox)[_1_i]).dtor_requestId, (((c).dtor_outbox)[_2_j]).dtor_requestId));
        });
      }))) && ((new BigNumber(((c).dtor_outbox).length)).isEqualTo(new BigNumber(((c).dtor_settled).length)))) && (_dafny.Quantifier(_dafny.IntegerRange(_dafny.ZERO, new BigNumber(((c).dtor_outbox).length)), true, function (_forall_var_3) {
        let _3_i = _forall_var_3;
        return !(((_dafny.ZERO).isLessThanOrEqualTo(_3_i)) && ((_3_i).isLessThan(new BigNumber(((c).dtor_outbox).length)))) || (_dafny.areEqual((((c).dtor_outbox)[_3_i]).dtor_chargeId, ((c).dtor_charge).dtor_chargeId));
      }));
    };
    static Charge0() {
      return RefundFinality.Charge.create_Charge(_dafny.Seq.UnicodeFromString("ch_1"), new BigNumber(100), new BigNumber(100), true);
    };
    static Charge2() {
      return RefundFinality.Charge.create_Charge(_dafny.Seq.UnicodeFromString("ch_2"), new BigNumber(50), new BigNumber(50), true);
    };
    static LastStore(init, log) {
      if ((new BigNumber((log).length)).isEqualTo(_dafny.ZERO)) {
        return init;
      } else {
        return ((log)[(new BigNumber((log).length)).minus(_dafny.ONE)]).dtor_post;
      }
    };
    static SumAmt(log) {
      let _0___accumulator = _dafny.ZERO;
      TAIL_CALL_START: while (true) {
        if ((new BigNumber((log).length)).isEqualTo(_dafny.ZERO)) {
          return (_dafny.ZERO).plus(_0___accumulator);
        } else {
          _0___accumulator = ((((log)[(new BigNumber((log).length)).minus(_dafny.ONE)]).dtor_eff).dtor_amount).plus(_0___accumulator);
          let _in0 = (log).slice(0, (new BigNumber((log).length)).minus(_dafny.ONE));
          log = _in0;
          continue TAIL_CALL_START;
        }
      }
    };
    static SumIntents(o) {
      let _0___accumulator = _dafny.ZERO;
      TAIL_CALL_START: while (true) {
        if ((new BigNumber((o).length)).isEqualTo(_dafny.ZERO)) {
          return (_dafny.ZERO).plus(_0___accumulator);
        } else {
          _0___accumulator = (((o)[(new BigNumber((o).length)).minus(_dafny.ONE)]).dtor_amount).plus(_0___accumulator);
          let _in0 = (o).slice(0, (new BigNumber((o).length)).minus(_dafny.ONE));
          o = _in0;
          continue TAIL_CALL_START;
        }
      }
    };
    static get PINNED__SPEC() {
      return _dafny.ONE;
    };
    static get PINNED__CHK() {
      return new BigNumber(2);
    };
    static get B() {
      return new BigNumber(1114113);
    };
  };

  $module.SinkToken = class SinkToken {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_SinkToken(specId, checkerId, pre, requestId, post, intent, sig) {
      let $dt = new SinkToken(0);
      $dt.specId = specId;
      $dt.checkerId = checkerId;
      $dt.pre = pre;
      $dt.requestId = requestId;
      $dt.post = post;
      $dt.intent = intent;
      $dt.sig = sig;
      return $dt;
    }
    get is_SinkToken() { return this.$tag === 0; }
    get dtor_specId() { return this.specId; }
    get dtor_checkerId() { return this.checkerId; }
    get dtor_pre() { return this.pre; }
    get dtor_requestId() { return this.requestId; }
    get dtor_post() { return this.post; }
    get dtor_intent() { return this.intent; }
    get dtor_sig() { return this.sig; }
    toString() {
      if (this.$tag === 0) {
        return "SinkCoreV3.SinkToken.SinkToken" + "(" + _dafny.toString(this.specId) + ", " + _dafny.toString(this.checkerId) + ", " + _dafny.toString(this.pre) + ", " + this.requestId.toVerbatimString(true) + ", " + _dafny.toString(this.post) + ", " + _dafny.toString(this.intent) + ", " + this.sig.toVerbatimString(true) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.specId, other.specId) && _dafny.areEqual(this.checkerId, other.checkerId) && _dafny.areEqual(this.pre, other.pre) && _dafny.areEqual(this.requestId, other.requestId) && _dafny.areEqual(this.post, other.post) && _dafny.areEqual(this.intent, other.intent) && _dafny.areEqual(this.sig, other.sig);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return SinkCoreV3.SinkToken.create_SinkToken(_dafny.ZERO, _dafny.ZERO, RefundFinality.Charge.Default(), _dafny.Seq.UnicodeFromString(""), RefundFinality.Charge.Default(), Refund.RefundIntent.Default(), _dafny.Seq.UnicodeFromString(""));
    }
    static Rtd() {
      return class {
        static get Default() {
          return SinkToken.Default();
        }
      };
    }
  }

  $module.Core = class Core {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Core(charge, settled, outbox) {
      let $dt = new Core(0);
      $dt.charge = charge;
      $dt.settled = settled;
      $dt.outbox = outbox;
      return $dt;
    }
    get is_Core() { return this.$tag === 0; }
    get dtor_charge() { return this.charge; }
    get dtor_settled() { return this.settled; }
    get dtor_outbox() { return this.outbox; }
    toString() {
      if (this.$tag === 0) {
        return "SinkCoreV3.Core.Core" + "(" + _dafny.toString(this.charge) + ", " + _dafny.toString(this.settled) + ", " + _dafny.toString(this.outbox) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.charge, other.charge) && _dafny.areEqual(this.settled, other.settled) && _dafny.areEqual(this.outbox, other.outbox);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return SinkCoreV3.Core.create_Core(RefundFinality.Charge.Default(), _dafny.Set.Empty, _dafny.Seq.of());
    }
    static Rtd() {
      return class {
        static get Default() {
          return Core.Default();
        }
      };
    }
  }

  $module.Why = class Why {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_ReqIdMismatch() {
      let $dt = new Why(0);
      return $dt;
    }
    static create_IdsNotPinned() {
      let $dt = new Why(1);
      return $dt;
    }
    static create_SignatureInvalid() {
      let $dt = new Why(2);
      return $dt;
    }
    static create_RequestSettled() {
      let $dt = new Why(3);
      return $dt;
    }
    static create_PreStateMismatch() {
      let $dt = new Why(4);
      return $dt;
    }
    static create_ChargeIdMismatch() {
      let $dt = new Why(5);
      return $dt;
    }
    static create_NoSuchCharge() {
      let $dt = new Why(6);
      return $dt;
    }
    get is_ReqIdMismatch() { return this.$tag === 0; }
    get is_IdsNotPinned() { return this.$tag === 1; }
    get is_SignatureInvalid() { return this.$tag === 2; }
    get is_RequestSettled() { return this.$tag === 3; }
    get is_PreStateMismatch() { return this.$tag === 4; }
    get is_ChargeIdMismatch() { return this.$tag === 5; }
    get is_NoSuchCharge() { return this.$tag === 6; }
    static get AllSingletonConstructors() {
      return this.AllSingletonConstructors_();
    }
    static *AllSingletonConstructors_() {
      yield Why.create_ReqIdMismatch();
      yield Why.create_IdsNotPinned();
      yield Why.create_SignatureInvalid();
      yield Why.create_RequestSettled();
      yield Why.create_PreStateMismatch();
      yield Why.create_ChargeIdMismatch();
      yield Why.create_NoSuchCharge();
    }
    toString() {
      if (this.$tag === 0) {
        return "SinkCoreV3.Why.ReqIdMismatch";
      } else if (this.$tag === 1) {
        return "SinkCoreV3.Why.IdsNotPinned";
      } else if (this.$tag === 2) {
        return "SinkCoreV3.Why.SignatureInvalid";
      } else if (this.$tag === 3) {
        return "SinkCoreV3.Why.RequestSettled";
      } else if (this.$tag === 4) {
        return "SinkCoreV3.Why.PreStateMismatch";
      } else if (this.$tag === 5) {
        return "SinkCoreV3.Why.ChargeIdMismatch";
      } else if (this.$tag === 6) {
        return "SinkCoreV3.Why.NoSuchCharge";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0;
      } else if (this.$tag === 1) {
        return other.$tag === 1;
      } else if (this.$tag === 2) {
        return other.$tag === 2;
      } else if (this.$tag === 3) {
        return other.$tag === 3;
      } else if (this.$tag === 4) {
        return other.$tag === 4;
      } else if (this.$tag === 5) {
        return other.$tag === 5;
      } else if (this.$tag === 6) {
        return other.$tag === 6;
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return SinkCoreV3.Why.create_ReqIdMismatch();
    }
    static Rtd() {
      return class {
        static get Default() {
          return Why.Default();
        }
      };
    }
  }

  $module.Outcome = class Outcome {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Committed() {
      let $dt = new Outcome(0);
      return $dt;
    }
    static create_Rejected(why) {
      let $dt = new Outcome(1);
      $dt.why = why;
      return $dt;
    }
    get is_Committed() { return this.$tag === 0; }
    get is_Rejected() { return this.$tag === 1; }
    get dtor_why() { return this.why; }
    toString() {
      if (this.$tag === 0) {
        return "SinkCoreV3.Outcome.Committed";
      } else if (this.$tag === 1) {
        return "SinkCoreV3.Outcome.Rejected" + "(" + _dafny.toString(this.why) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0;
      } else if (this.$tag === 1) {
        return other.$tag === 1 && _dafny.areEqual(this.why, other.why);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return SinkCoreV3.Outcome.create_Committed();
    }
    static Rtd() {
      return class {
        static get Default() {
          return Outcome.Default();
        }
      };
    }
  }

  $module.StepResult = class StepResult {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_StepResult(core, out) {
      let $dt = new StepResult(0);
      $dt.core = core;
      $dt.out = out;
      return $dt;
    }
    get is_StepResult() { return this.$tag === 0; }
    get dtor_core() { return this.core; }
    get dtor_out() { return this.out; }
    toString() {
      if (this.$tag === 0) {
        return "SinkCoreV3.StepResult.StepResult" + "(" + _dafny.toString(this.core) + ", " + _dafny.toString(this.out) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.core, other.core) && _dafny.areEqual(this.out, other.out);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return SinkCoreV3.StepResult.create_StepResult(SinkCoreV3.Core.Default(), SinkCoreV3.Outcome.Default());
    }
    static Rtd() {
      return class {
        static get Default() {
          return StepResult.Default();
        }
      };
    }
  }

  $module.Delivery = class Delivery {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Delivery(tok, sigOk) {
      let $dt = new Delivery(0);
      $dt.tok = tok;
      $dt.sigOk = sigOk;
      return $dt;
    }
    get is_Delivery() { return this.$tag === 0; }
    get dtor_tok() { return this.tok; }
    get dtor_sigOk() { return this.sigOk; }
    toString() {
      if (this.$tag === 0) {
        return "SinkCoreV3.Delivery.Delivery" + "(" + _dafny.toString(this.tok) + ", " + _dafny.toString(this.sigOk) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.tok, other.tok) && this.sigOk === other.sigOk;
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return SinkCoreV3.Delivery.create_Delivery(SinkCoreV3.SinkToken.Default(), false);
    }
    static Rtd() {
      return class {
        static get Default() {
          return Delivery.Default();
        }
      };
    }
  }

  $module.Claim = class Claim {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Claim(specId, checkerId, pre, reqId, req, post, eff) {
      let $dt = new Claim(0);
      $dt.specId = specId;
      $dt.checkerId = checkerId;
      $dt.pre = pre;
      $dt.reqId = reqId;
      $dt.req = req;
      $dt.post = post;
      $dt.eff = eff;
      return $dt;
    }
    get is_Claim() { return this.$tag === 0; }
    get dtor_specId() { return this.specId; }
    get dtor_checkerId() { return this.checkerId; }
    get dtor_pre() { return this.pre; }
    get dtor_reqId() { return this.reqId; }
    get dtor_req() { return this.req; }
    get dtor_post() { return this.post; }
    get dtor_eff() { return this.eff; }
    toString() {
      if (this.$tag === 0) {
        return "SinkCoreV3.Claim.Claim" + "(" + _dafny.toString(this.specId) + ", " + _dafny.toString(this.checkerId) + ", " + _dafny.toString(this.pre) + ", " + _dafny.toString(this.reqId) + ", " + _dafny.toString(this.req) + ", " + _dafny.toString(this.post) + ", " + _dafny.toString(this.eff) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.specId, other.specId) && _dafny.areEqual(this.checkerId, other.checkerId) && _dafny.areEqual(this.pre, other.pre) && _dafny.areEqual(this.reqId, other.reqId) && _dafny.areEqual(this.req, other.req) && _dafny.areEqual(this.post, other.post) && _dafny.areEqual(this.eff, other.eff);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return SinkCoreV3.Claim.create_Claim(_dafny.ZERO, _dafny.ZERO, RefundFinality.Charge.Default(), _dafny.ZERO, RefundFinality.Request.Default(), RefundFinality.Charge.Default(), Refund.RefundIntent.Default());
    }
    static Rtd() {
      return class {
        static get Default() {
          return Claim.Default();
        }
      };
    }
  }

  $module.System = class System {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Sys(store, log, settled, outbox, minted) {
      let $dt = new System(0);
      $dt.store = store;
      $dt.log = log;
      $dt.settled = settled;
      $dt.outbox = outbox;
      $dt.minted = minted;
      return $dt;
    }
    get is_Sys() { return this.$tag === 0; }
    get dtor_store() { return this.store; }
    get dtor_log() { return this.log; }
    get dtor_settled() { return this.settled; }
    get dtor_outbox() { return this.outbox; }
    get dtor_minted() { return this.minted; }
    toString() {
      if (this.$tag === 0) {
        return "SinkCoreV3.System.Sys" + "(" + _dafny.toString(this.store) + ", " + _dafny.toString(this.log) + ", " + _dafny.toString(this.settled) + ", " + _dafny.toString(this.outbox) + ", " + _dafny.toString(this.minted) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.store, other.store) && _dafny.areEqual(this.log, other.log) && _dafny.areEqual(this.settled, other.settled) && _dafny.areEqual(this.outbox, other.outbox) && _dafny.areEqual(this.minted, other.minted);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return SinkCoreV3.System.create_Sys(RefundFinality.Charge.Default(), _dafny.Seq.of(), _dafny.Set.Empty, _dafny.Seq.of(), _dafny.Set.Empty);
    }
    static Rtd() {
      return class {
        static get Default() {
          return System.Default();
        }
      };
    }
  }
  return $module;
})(); // end of module SinkCoreV3
let AuditCompile = (function() {
  let $module = {};

  $module.__default = class __default {
    constructor () {
      this._tname = "AuditCompile._default";
    }
    _parentTraits() {
      return [];
    }
    static Main(__noArgsParameter) {
      let _0_good;
      _0_good = SinkCoreV3.Core.create_Core(RefundFinality.Charge.create_Charge(_dafny.Seq.UnicodeFromString("ch_1"), new BigNumber(100), new BigNumber(90), true), _dafny.Set.fromElements(_dafny.Seq.UnicodeFromString("rq_1")), _dafny.Seq.of(Refund.RefundIntent.create_Intent(_dafny.Seq.UnicodeFromString("ch_1"), _dafny.Seq.UnicodeFromString("rq_1"), new BigNumber(10), _dafny.Seq.UnicodeFromString("duplicate_charge"))));
      let _1_foreign;
      _1_foreign = SinkCoreV3.Core.create_Core(RefundFinality.Charge.create_Charge(_dafny.Seq.UnicodeFromString("ch_1"), new BigNumber(100), new BigNumber(90), true), _dafny.Set.fromElements(_dafny.Seq.UnicodeFromString("rq_1")), _dafny.Seq.of(Refund.RefundIntent.create_Intent(_dafny.Seq.UnicodeFromString("ch_2"), _dafny.Seq.UnicodeFromString("rq_1"), new BigNumber(10), _dafny.Seq.UnicodeFromString("duplicate_charge"))));
      let _2_unsettled;
      _2_unsettled = SinkCoreV3.Core.create_Core(RefundFinality.Charge.create_Charge(_dafny.Seq.UnicodeFromString("ch_1"), new BigNumber(100), new BigNumber(90), true), _dafny.Set.fromElements(_dafny.Seq.UnicodeFromString("rq_x")), _dafny.Seq.of(Refund.RefundIntent.create_Intent(_dafny.Seq.UnicodeFromString("ch_1"), _dafny.Seq.UnicodeFromString("rq_1"), new BigNumber(10), _dafny.Seq.UnicodeFromString("duplicate_charge"))));
      process.stdout.write(_dafny.toString(SinkCoreV3.__default.AuditStart(_0_good)));
      process.stdout.write((_dafny.Seq.UnicodeFromString(" ")).toVerbatimString(false));
      process.stdout.write(_dafny.toString(SinkCoreV3.__default.AuditStart(_1_foreign)));
      process.stdout.write((_dafny.Seq.UnicodeFromString(" ")).toVerbatimString(false));
      process.stdout.write(_dafny.toString(SinkCoreV3.__default.AuditStart(_2_unsettled)));
      process.stdout.write((_dafny.Seq.UnicodeFromString("\n")).toVerbatimString(false));
      return;
    }
  };
  return $module;
})(); // end of module AuditCompile
let _module = (function() {
  let $module = {};

  return $module;
})(); // end of module _module
_dafny.HandleHaltExceptions(() => AuditCompile.__default.Main(_dafny.UnicodeFromMainArguments(require('process').argv)));

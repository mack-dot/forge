// Dafny program Refund.dfy compiled into JavaScript
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
      if (((Refund.__default.Eligible(context, response)) && (_dafny.areEqual(new _dafny.CodePoint('\u{1F600}'.codePointAt(0)), new _dafny.CodePoint('\u{1F600}'.codePointAt(0))))) && (!_dafny.areEqual(new _dafny.CodePoint('\u{1F600}'.codePointAt(0)), new _dafny.CodePoint('\u{1F601}'.codePointAt(0))))) {
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
let _module = (function() {
  let $module = {};

  return $module;
})(); // end of module _module

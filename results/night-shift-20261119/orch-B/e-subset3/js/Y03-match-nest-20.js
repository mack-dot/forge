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
      let _0_y;
      let _source0 = response;
      Lmatch0: {
        {
          if (_source0.is_Candidate) {
            let _1_a0 = (_source0).amount;
            let _2_r0 = (_source0).reason;
            let _source1 = response;
            Lmatch1: {
              {
                if (_source1.is_Candidate) {
                  let _3_a1 = (_source1).amount;
                  let _4_r1 = (_source1).reason;
                  let _source2 = response;
                  Lmatch2: {
                    {
                      if (_source2.is_Candidate) {
                        let _5_a2 = (_source2).amount;
                        let _6_r2 = (_source2).reason;
                        let _source3 = response;
                        Lmatch3: {
                          {
                            if (_source3.is_Candidate) {
                              let _7_a3 = (_source3).amount;
                              let _8_r3 = (_source3).reason;
                              let _source4 = response;
                              Lmatch4: {
                                {
                                  if (_source4.is_Candidate) {
                                    let _9_a4 = (_source4).amount;
                                    let _10_r4 = (_source4).reason;
                                    let _source5 = response;
                                    Lmatch5: {
                                      {
                                        if (_source5.is_Candidate) {
                                          let _11_a5 = (_source5).amount;
                                          let _12_r5 = (_source5).reason;
                                          let _source6 = response;
                                          Lmatch6: {
                                            {
                                              if (_source6.is_Candidate) {
                                                let _13_a6 = (_source6).amount;
                                                let _14_r6 = (_source6).reason;
                                                let _source7 = response;
                                                Lmatch7: {
                                                  {
                                                    if (_source7.is_Candidate) {
                                                      let _15_a7 = (_source7).amount;
                                                      let _16_r7 = (_source7).reason;
                                                      let _source8 = response;
                                                      Lmatch8: {
                                                        {
                                                          if (_source8.is_Candidate) {
                                                            let _17_a8 = (_source8).amount;
                                                            let _18_r8 = (_source8).reason;
                                                            let _source9 = response;
                                                            Lmatch9: {
                                                              {
                                                                if (_source9.is_Candidate) {
                                                                  let _19_a9 = (_source9).amount;
                                                                  let _20_r9 = (_source9).reason;
                                                                  let _source10 = response;
                                                                  Lmatch10: {
                                                                    {
                                                                      if (_source10.is_Candidate) {
                                                                        let _21_a10 = (_source10).amount;
                                                                        let _22_r10 = (_source10).reason;
                                                                        let _source11 = response;
                                                                        Lmatch11: {
                                                                          {
                                                                            if (_source11.is_Candidate) {
                                                                              let _23_a11 = (_source11).amount;
                                                                              let _24_r11 = (_source11).reason;
                                                                              let _source12 = response;
                                                                              Lmatch12: {
                                                                                {
                                                                                  if (_source12.is_Candidate) {
                                                                                    let _25_a12 = (_source12).amount;
                                                                                    let _26_r12 = (_source12).reason;
                                                                                    let _source13 = response;
                                                                                    Lmatch13: {
                                                                                      {
                                                                                        if (_source13.is_Candidate) {
                                                                                          let _27_a13 = (_source13).amount;
                                                                                          let _28_r13 = (_source13).reason;
                                                                                          let _source14 = response;
                                                                                          Lmatch14: {
                                                                                            {
                                                                                              if (_source14.is_Candidate) {
                                                                                                let _29_a14 = (_source14).amount;
                                                                                                let _30_r14 = (_source14).reason;
                                                                                                let _source15 = response;
                                                                                                Lmatch15: {
                                                                                                  {
                                                                                                    if (_source15.is_Candidate) {
                                                                                                      let _31_a15 = (_source15).amount;
                                                                                                      let _32_r15 = (_source15).reason;
                                                                                                      let _source16 = response;
                                                                                                      Lmatch16: {
                                                                                                        {
                                                                                                          if (_source16.is_Candidate) {
                                                                                                            let _33_a16 = (_source16).amount;
                                                                                                            let _34_r16 = (_source16).reason;
                                                                                                            let _source17 = response;
                                                                                                            Lmatch17: {
                                                                                                              {
                                                                                                                if (_source17.is_Candidate) {
                                                                                                                  let _35_a17 = (_source17).amount;
                                                                                                                  let _36_r17 = (_source17).reason;
                                                                                                                  let _source18 = response;
                                                                                                                  Lmatch18: {
                                                                                                                    {
                                                                                                                      if (_source18.is_Candidate) {
                                                                                                                        let _37_a18 = (_source18).amount;
                                                                                                                        let _38_r18 = (_source18).reason;
                                                                                                                        let _source19 = response;
                                                                                                                        Lmatch19: {
                                                                                                                          {
                                                                                                                            if (_source19.is_Candidate) {
                                                                                                                              let _39_a19 = (_source19).amount;
                                                                                                                              let _40_r19 = (_source19).reason;
                                                                                                                              _0_y = _dafny.ZERO;
                                                                                                                              break Lmatch19;
                                                                                                                            }
                                                                                                                          }
                                                                                                                          {
                                                                                                                            _0_y = _dafny.ONE;
                                                                                                                          }
                                                                                                                        }
                                                                                                                        break Lmatch18;
                                                                                                                      }
                                                                                                                    }
                                                                                                                    {
                                                                                                                      _0_y = _dafny.ONE;
                                                                                                                    }
                                                                                                                  }
                                                                                                                  break Lmatch17;
                                                                                                                }
                                                                                                              }
                                                                                                              {
                                                                                                                _0_y = _dafny.ONE;
                                                                                                              }
                                                                                                            }
                                                                                                            break Lmatch16;
                                                                                                          }
                                                                                                        }
                                                                                                        {
                                                                                                          _0_y = _dafny.ONE;
                                                                                                        }
                                                                                                      }
                                                                                                      break Lmatch15;
                                                                                                    }
                                                                                                  }
                                                                                                  {
                                                                                                    _0_y = _dafny.ONE;
                                                                                                  }
                                                                                                }
                                                                                                break Lmatch14;
                                                                                              }
                                                                                            }
                                                                                            {
                                                                                              _0_y = _dafny.ONE;
                                                                                            }
                                                                                          }
                                                                                          break Lmatch13;
                                                                                        }
                                                                                      }
                                                                                      {
                                                                                        _0_y = _dafny.ONE;
                                                                                      }
                                                                                    }
                                                                                    break Lmatch12;
                                                                                  }
                                                                                }
                                                                                {
                                                                                  _0_y = _dafny.ONE;
                                                                                }
                                                                              }
                                                                              break Lmatch11;
                                                                            }
                                                                          }
                                                                          {
                                                                            _0_y = _dafny.ONE;
                                                                          }
                                                                        }
                                                                        break Lmatch10;
                                                                      }
                                                                    }
                                                                    {
                                                                      _0_y = _dafny.ONE;
                                                                    }
                                                                  }
                                                                  break Lmatch9;
                                                                }
                                                              }
                                                              {
                                                                _0_y = _dafny.ONE;
                                                              }
                                                            }
                                                            break Lmatch8;
                                                          }
                                                        }
                                                        {
                                                          _0_y = _dafny.ONE;
                                                        }
                                                      }
                                                      break Lmatch7;
                                                    }
                                                  }
                                                  {
                                                    _0_y = _dafny.ONE;
                                                  }
                                                }
                                                break Lmatch6;
                                              }
                                            }
                                            {
                                              _0_y = _dafny.ONE;
                                            }
                                          }
                                          break Lmatch5;
                                        }
                                      }
                                      {
                                        _0_y = _dafny.ONE;
                                      }
                                    }
                                    break Lmatch4;
                                  }
                                }
                                {
                                  _0_y = _dafny.ONE;
                                }
                              }
                              break Lmatch3;
                            }
                          }
                          {
                            _0_y = _dafny.ONE;
                          }
                        }
                        break Lmatch2;
                      }
                    }
                    {
                      _0_y = _dafny.ONE;
                    }
                  }
                  break Lmatch1;
                }
              }
              {
                _0_y = _dafny.ONE;
              }
            }
            break Lmatch0;
          }
        }
        {
          _0_y = _dafny.ONE;
        }
      }
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
let _module = (function() {
  let $module = {};

  return $module;
})(); // end of module _module

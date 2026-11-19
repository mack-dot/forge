// Dafny program SerModel.dfy compiled into JavaScript
let SerModel = (function() {
  let $module = {};

  $module.__default = class __default {
    constructor () {
      this._tname = "SerModel._default";
    }
    _parentTraits() {
      return [];
    }
    static Utf16Len(s) {
      let _0___accumulator = _dafny.ZERO;
      TAIL_CALL_START: while (true) {
        if ((new BigNumber((s).length)).isEqualTo(_dafny.ZERO)) {
          return (_dafny.ZERO).plus(_0___accumulator);
        } else {
          _0___accumulator = (_0___accumulator).plus((((new BigNumber(65536)).isLessThanOrEqualTo(new BigNumber(((s)[_dafny.ZERO]).value))) ? (new BigNumber(2)) : (_dafny.ONE)));
          let _in0 = (s).slice(_dafny.ONE);
          s = _in0;
          continue TAIL_CALL_START;
        }
      }
    };
    static Text(v) {
      return ((SerModel.__default.Utf16Len(v)).isLessThanOrEqualTo(SerModel.__default.MAX__TEXT)) && (_dafny.Quantifier(_dafny.IntegerRange(_dafny.ZERO, new BigNumber((v).length)), true, function (_forall_var_0) {
        let _0_i = _forall_var_0;
        return !(((_dafny.ZERO).isLessThanOrEqualTo(_0_i)) && ((_0_i).isLessThan(new BigNumber((v).length)))) || (!(new BigNumber(((v)[_0_i]).value)).isEqualTo(_dafny.ZERO));
      }));
    };
    static Money(n) {
      return (n).isLessThan(SerModel.__default.MONEY__BOUND);
    };
    static IsLowerHex(c) {
      return (((new _dafny.CodePoint('0'.codePointAt(0))).isLessThanOrEqual(c)) && ((c).isLessThanOrEqual(new _dafny.CodePoint('9'.codePointAt(0))))) || (((new _dafny.CodePoint('a'.codePointAt(0))).isLessThanOrEqual(c)) && ((c).isLessThanOrEqual(new _dafny.CodePoint('f'.codePointAt(0)))));
    };
    static Hex64(v) {
      return ((new BigNumber((v).length)).isEqualTo(new BigNumber(64))) && (_dafny.Quantifier(_dafny.IntegerRange(_dafny.ZERO, new BigNumber((v).length)), true, function (_forall_var_0) {
        let _0_i = _forall_var_0;
        return !(((_dafny.ZERO).isLessThanOrEqualTo(_0_i)) && ((_0_i).isLessThan(new BigNumber((v).length)))) || (SerModel.__default.IsLowerHex((v)[_0_i]));
      }));
    };
    static IsState(s) {
      return ((SerModel.__default.Text((s).dtor_chargeId)) && (SerModel.__default.Money((s).dtor_original))) && (SerModel.__default.Money((s).dtor_remaining));
    };
    static IsIntent(i) {
      return (((SerModel.__default.Text((i).dtor_chargeId)) && (SerModel.__default.Text((i).dtor_requestId))) && (SerModel.__default.Money((i).dtor_amount))) && (SerModel.__default.Text((i).dtor_reason));
    };
    static WfBody(b) {
      return ((((((_dafny.areEqual((b).dtor_domain, SerModel.__default.DOMAIN)) && (SerModel.__default.Hex64((b).dtor_specLockSha256))) && (SerModel.__default.Hex64((b).dtor_checkerSha256))) && (SerModel.__default.Hex64((b).dtor_preStateSha256))) && (SerModel.__default.Text((b).dtor_requestId))) && (SerModel.__default.IsState((b).dtor_post))) && (SerModel.__default.IsIntent((b).dtor_intent));
    };
    static HexDigit(n) {
      if ((n).isLessThan(new BigNumber(10))) {
        return new _dafny.CodePoint(((new BigNumber((new _dafny.CodePoint('0'.codePointAt(0))).value)).plus(n)).toNumber());
      } else {
        return new _dafny.CodePoint(((new BigNumber((new _dafny.CodePoint('a'.codePointAt(0))).value)).plus((n).minus(new BigNumber(10)))).toNumber());
      }
    };
    static HexVal(c) {
      if (((new _dafny.CodePoint('0'.codePointAt(0))).isLessThanOrEqual(c)) && ((c).isLessThanOrEqual(new _dafny.CodePoint('9'.codePointAt(0))))) {
        return (new BigNumber((c).value)).minus(new BigNumber((new _dafny.CodePoint('0'.codePointAt(0))).value));
      } else {
        return ((new BigNumber((c).value)).minus(new BigNumber((new _dafny.CodePoint('a'.codePointAt(0))).value))).plus(new BigNumber(10));
      }
    };
    static NamedControl(v) {
      return (((((v).isEqualTo(new BigNumber(8))) || ((v).isEqualTo(new BigNumber(9)))) || ((v).isEqualTo(new BigNumber(10)))) || ((v).isEqualTo(new BigNumber(12)))) || ((v).isEqualTo(new BigNumber(13)));
    };
    static EscChar(c) {
      if (_dafny.areEqual(c, new _dafny.CodePoint('"'.codePointAt(0)))) {
        return _dafny.Seq.of(new _dafny.CodePoint('\\'.codePointAt(0)), new _dafny.CodePoint('"'.codePointAt(0)));
      } else if (_dafny.areEqual(c, new _dafny.CodePoint('\\'.codePointAt(0)))) {
        return _dafny.Seq.of(new _dafny.CodePoint('\\'.codePointAt(0)), new _dafny.CodePoint('\\'.codePointAt(0)));
      } else if ((new BigNumber((c).value)).isEqualTo(new BigNumber(8))) {
        return _dafny.Seq.of(new _dafny.CodePoint('\\'.codePointAt(0)), new _dafny.CodePoint('b'.codePointAt(0)));
      } else if ((new BigNumber((c).value)).isEqualTo(new BigNumber(9))) {
        return _dafny.Seq.of(new _dafny.CodePoint('\\'.codePointAt(0)), new _dafny.CodePoint('t'.codePointAt(0)));
      } else if ((new BigNumber((c).value)).isEqualTo(new BigNumber(10))) {
        return _dafny.Seq.of(new _dafny.CodePoint('\\'.codePointAt(0)), new _dafny.CodePoint('n'.codePointAt(0)));
      } else if ((new BigNumber((c).value)).isEqualTo(new BigNumber(12))) {
        return _dafny.Seq.of(new _dafny.CodePoint('\\'.codePointAt(0)), new _dafny.CodePoint('f'.codePointAt(0)));
      } else if ((new BigNumber((c).value)).isEqualTo(new BigNumber(13))) {
        return _dafny.Seq.of(new _dafny.CodePoint('\\'.codePointAt(0)), new _dafny.CodePoint('r'.codePointAt(0)));
      } else if ((new BigNumber((c).value)).isLessThan(new BigNumber(32))) {
        return _dafny.Seq.of(new _dafny.CodePoint('\\'.codePointAt(0)), new _dafny.CodePoint('u'.codePointAt(0)), new _dafny.CodePoint('0'.codePointAt(0)), new _dafny.CodePoint('0'.codePointAt(0)), SerModel.__default.HexDigit(_dafny.EuclideanDivision(new BigNumber((c).value), new BigNumber(16))), SerModel.__default.HexDigit((new BigNumber((c).value)).mod(new BigNumber(16))));
      } else {
        return _dafny.Seq.of(c);
      }
    };
    static EscBody(s) {
      let _0___accumulator = _dafny.Seq.of();
      TAIL_CALL_START: while (true) {
        if ((new BigNumber((s).length)).isEqualTo(_dafny.ZERO)) {
          return _dafny.Seq.Concat(_0___accumulator, _dafny.Seq.of());
        } else {
          _0___accumulator = _dafny.Seq.Concat(_0___accumulator, SerModel.__default.EscChar((s)[_dafny.ZERO]));
          let _in0 = (s).slice(_dafny.ONE);
          s = _in0;
          continue TAIL_CALL_START;
        }
      }
    };
    static Q(s) {
      return _dafny.Seq.Concat(_dafny.Seq.Concat(_dafny.Seq.of(new _dafny.CodePoint('"'.codePointAt(0))), SerModel.__default.EscBody(s)), _dafny.Seq.of(new _dafny.CodePoint('"'.codePointAt(0))));
    };
    static NatToDec(n) {
      let _0___accumulator = _dafny.Seq.of();
      TAIL_CALL_START: while (true) {
        if ((n).isLessThan(new BigNumber(10))) {
          return _dafny.Seq.Concat(_dafny.Seq.of(SerModel.__default.HexDigit(n)), _0___accumulator);
        } else {
          _0___accumulator = _dafny.Seq.Concat(_dafny.Seq.of(SerModel.__default.HexDigit((n).mod(new BigNumber(10)))), _0___accumulator);
          let _in0 = _dafny.EuclideanDivision(n, new BigNumber(10));
          n = _in0;
          continue TAIL_CALL_START;
        }
      }
    };
    static SerBool(b) {
      if (b) {
        return _dafny.Seq.UnicodeFromString("true");
      } else {
        return _dafny.Seq.UnicodeFromString("false");
      }
    };
    static SerState(s) {
      return _dafny.Seq.Concat(SerModel.__default.KS0, _dafny.Seq.Concat(SerModel.__default.Q((s).dtor_chargeId), _dafny.Seq.Concat(SerModel.__default.KS1, _dafny.Seq.Concat(SerModel.__default.Q(SerModel.__default.NatToDec((s).dtor_original)), _dafny.Seq.Concat(SerModel.__default.KS2, _dafny.Seq.Concat(SerModel.__default.SerBool((s).dtor_refundEnabled), _dafny.Seq.Concat(SerModel.__default.KS3, _dafny.Seq.Concat(SerModel.__default.Q(SerModel.__default.NatToDec((s).dtor_remaining)), SerModel.__default.KEND))))))));
    };
    static SerIntent(i) {
      return _dafny.Seq.Concat(SerModel.__default.KI0, _dafny.Seq.Concat(SerModel.__default.Q(SerModel.__default.NatToDec((i).dtor_amount)), _dafny.Seq.Concat(SerModel.__default.KI1, _dafny.Seq.Concat(SerModel.__default.Q((i).dtor_chargeId), _dafny.Seq.Concat(SerModel.__default.KI2, _dafny.Seq.Concat(SerModel.__default.Q((i).dtor_reason), _dafny.Seq.Concat(SerModel.__default.KI3, _dafny.Seq.Concat(SerModel.__default.Q((i).dtor_requestId), SerModel.__default.KEND))))))));
    };
    static SerBody(b) {
      return _dafny.Seq.Concat(SerModel.__default.KB0, _dafny.Seq.Concat(SerModel.__default.Q((b).dtor_checkerSha256), _dafny.Seq.Concat(SerModel.__default.KB1, _dafny.Seq.Concat(SerModel.__default.Q((b).dtor_domain), _dafny.Seq.Concat(SerModel.__default.KB2, _dafny.Seq.Concat(SerModel.__default.SerIntent((b).dtor_intent), _dafny.Seq.Concat(SerModel.__default.KB3, _dafny.Seq.Concat(SerModel.__default.SerState((b).dtor_post), _dafny.Seq.Concat(SerModel.__default.KB4, _dafny.Seq.Concat(SerModel.__default.Q((b).dtor_preStateSha256), _dafny.Seq.Concat(SerModel.__default.KB5, _dafny.Seq.Concat(SerModel.__default.Q((b).dtor_requestId), _dafny.Seq.Concat(SerModel.__default.KB6, _dafny.Seq.Concat(SerModel.__default.Q((b).dtor_specLockSha256), SerModel.__default.KEND))))))))))))));
    };
    static Expect(lit, inp) {
      if (((new BigNumber((lit).length)).isLessThanOrEqualTo(new BigNumber((inp).length))) && (_dafny.areEqual((inp).slice(0, new BigNumber((lit).length)), lit))) {
        return SerModel.Option.create_Some((inp).slice(new BigNumber((lit).length)));
      } else {
        return SerModel.Option.create_None();
      }
    };
    static SimpleUnescape(e) {
      if (_dafny.areEqual(e, new _dafny.CodePoint('"'.codePointAt(0)))) {
        return SerModel.Option.create_Some(new _dafny.CodePoint('"'.codePointAt(0)));
      } else if (_dafny.areEqual(e, new _dafny.CodePoint('\\'.codePointAt(0)))) {
        return SerModel.Option.create_Some(new _dafny.CodePoint('\\'.codePointAt(0)));
      } else if (_dafny.areEqual(e, new _dafny.CodePoint('b'.codePointAt(0)))) {
        return SerModel.Option.create_Some(new _dafny.CodePoint((new BigNumber(8)).toNumber()));
      } else if (_dafny.areEqual(e, new _dafny.CodePoint('t'.codePointAt(0)))) {
        return SerModel.Option.create_Some(new _dafny.CodePoint((new BigNumber(9)).toNumber()));
      } else if (_dafny.areEqual(e, new _dafny.CodePoint('n'.codePointAt(0)))) {
        return SerModel.Option.create_Some(new _dafny.CodePoint((new BigNumber(10)).toNumber()));
      } else if (_dafny.areEqual(e, new _dafny.CodePoint('f'.codePointAt(0)))) {
        return SerModel.Option.create_Some(new _dafny.CodePoint((new BigNumber(12)).toNumber()));
      } else if (_dafny.areEqual(e, new _dafny.CodePoint('r'.codePointAt(0)))) {
        return SerModel.Option.create_Some(new _dafny.CodePoint((new BigNumber(13)).toNumber()));
      } else {
        return SerModel.Option.create_None();
      }
    };
    static ParseStrBody(inp) {
      if ((new BigNumber((inp).length)).isEqualTo(_dafny.ZERO)) {
        return SerModel.Option.create_None();
      } else if (_dafny.areEqual((inp)[_dafny.ZERO], new _dafny.CodePoint('"'.codePointAt(0)))) {
        return SerModel.Option.create_Some(_dafny.Tuple.of(_dafny.Seq.of(), (inp).slice(_dafny.ONE)));
      } else if (_dafny.areEqual((inp)[_dafny.ZERO], new _dafny.CodePoint('\\'.codePointAt(0)))) {
        if ((new BigNumber((inp).length)).isLessThan(new BigNumber(2))) {
          return SerModel.Option.create_None();
        } else if ((SerModel.__default.SimpleUnescape((inp)[_dafny.ONE])).is_Some) {
          let _0_valueOrError0 = SerModel.__default.ParseStrBody((inp).slice(new BigNumber(2)));
          if ((_0_valueOrError0).IsFailure()) {
            return (_0_valueOrError0).PropagateFailure();
          } else {
            let _1_rest = (_0_valueOrError0).Extract();
            return SerModel.Option.create_Some(_dafny.Tuple.of(_dafny.Seq.Concat(_dafny.Seq.of((SerModel.__default.SimpleUnescape((inp)[_dafny.ONE])).dtor_value), (_1_rest)[0]), (_1_rest)[1]));
          }
        } else if ((((((((_dafny.areEqual((inp)[_dafny.ONE], new _dafny.CodePoint('u'.codePointAt(0)))) && ((new BigNumber(6)).isLessThanOrEqualTo(new BigNumber((inp).length)))) && (_dafny.areEqual((inp)[new BigNumber(2)], new _dafny.CodePoint('0'.codePointAt(0))))) && (_dafny.areEqual((inp)[new BigNumber(3)], new _dafny.CodePoint('0'.codePointAt(0))))) && (SerModel.__default.IsLowerHex((inp)[new BigNumber(4)]))) && (SerModel.__default.IsLowerHex((inp)[new BigNumber(5)]))) && ((((SerModel.__default.HexVal((inp)[new BigNumber(4)])).multipliedBy(new BigNumber(16))).plus(SerModel.__default.HexVal((inp)[new BigNumber(5)]))).isLessThan(new BigNumber(32)))) && (!(SerModel.__default.NamedControl(((SerModel.__default.HexVal((inp)[new BigNumber(4)])).multipliedBy(new BigNumber(16))).plus(SerModel.__default.HexVal((inp)[new BigNumber(5)])))))) {
          let _2_valueOrError1 = SerModel.__default.ParseStrBody((inp).slice(new BigNumber(6)));
          if ((_2_valueOrError1).IsFailure()) {
            return (_2_valueOrError1).PropagateFailure();
          } else {
            let _3_rest = (_2_valueOrError1).Extract();
            return SerModel.Option.create_Some(_dafny.Tuple.of(_dafny.Seq.Concat(_dafny.Seq.of(new _dafny.CodePoint((((SerModel.__default.HexVal((inp)[new BigNumber(4)])).multipliedBy(new BigNumber(16))).plus(SerModel.__default.HexVal((inp)[new BigNumber(5)]))).toNumber())), (_3_rest)[0]), (_3_rest)[1]));
          }
        } else {
          return SerModel.Option.create_None();
        }
      } else if ((new BigNumber(((inp)[_dafny.ZERO]).value)).isLessThan(new BigNumber(32))) {
        return SerModel.Option.create_None();
      } else {
        let _4_valueOrError2 = SerModel.__default.ParseStrBody((inp).slice(_dafny.ONE));
        if ((_4_valueOrError2).IsFailure()) {
          return (_4_valueOrError2).PropagateFailure();
        } else {
          let _5_rest = (_4_valueOrError2).Extract();
          return SerModel.Option.create_Some(_dafny.Tuple.of(_dafny.Seq.Concat(_dafny.Seq.of((inp)[_dafny.ZERO]), (_5_rest)[0]), (_5_rest)[1]));
        }
      }
    };
    static ParseStr(inp) {
      let _0_valueOrError0 = SerModel.__default.Expect(_dafny.Seq.of(new _dafny.CodePoint('"'.codePointAt(0))), inp);
      if ((_0_valueOrError0).IsFailure()) {
        return (_0_valueOrError0).PropagateFailure();
      } else {
        let _1_r = (_0_valueOrError0).Extract();
        return SerModel.__default.ParseStrBody(_1_r);
      }
    };
    static IsDigit(c) {
      return ((new _dafny.CodePoint('0'.codePointAt(0))).isLessThanOrEqual(c)) && ((c).isLessThanOrEqual(new _dafny.CodePoint('9'.codePointAt(0))));
    };
    static IsCanonDec(s) {
      return (((_dafny.ONE).isLessThanOrEqualTo(new BigNumber((s).length))) && (_dafny.Quantifier(_dafny.IntegerRange(_dafny.ZERO, new BigNumber((s).length)), true, function (_forall_var_0) {
        let _0_i = _forall_var_0;
        return !(((_dafny.ZERO).isLessThanOrEqualTo(_0_i)) && ((_0_i).isLessThan(new BigNumber((s).length)))) || (SerModel.__default.IsDigit((s)[_0_i]));
      }))) && (((new BigNumber((s).length)).isEqualTo(_dafny.ONE)) || (!_dafny.areEqual((s)[_dafny.ZERO], new _dafny.CodePoint('0'.codePointAt(0)))));
    };
    static DecVal(s) {
      if ((new BigNumber((s).length)).isEqualTo(_dafny.ZERO)) {
        return _dafny.ZERO;
      } else {
        return ((SerModel.__default.DecVal((s).slice(0, (new BigNumber((s).length)).minus(_dafny.ONE)))).multipliedBy(new BigNumber(10))).plus((new BigNumber(((s)[(new BigNumber((s).length)).minus(_dafny.ONE)]).value)).minus(new BigNumber((new _dafny.CodePoint('0'.codePointAt(0))).value)));
      }
    };
    static ParseMoney(inp) {
      let _0_valueOrError0 = SerModel.__default.ParseStr(inp);
      if ((_0_valueOrError0).IsFailure()) {
        return (_0_valueOrError0).PropagateFailure();
      } else {
        let _1_p = (_0_valueOrError0).Extract();
        if (SerModel.__default.IsCanonDec((_1_p)[0])) {
          return SerModel.Option.create_Some(_dafny.Tuple.of(SerModel.__default.DecVal((_1_p)[0]), (_1_p)[1]));
        } else {
          return SerModel.Option.create_None();
        }
      }
    };
    static ParseBool(inp) {
      if ((SerModel.__default.Expect(_dafny.Seq.UnicodeFromString("true"), inp)).is_Some) {
        return SerModel.Option.create_Some(_dafny.Tuple.of(true, (SerModel.__default.Expect(_dafny.Seq.UnicodeFromString("true"), inp)).dtor_value));
      } else if ((SerModel.__default.Expect(_dafny.Seq.UnicodeFromString("false"), inp)).is_Some) {
        return SerModel.Option.create_Some(_dafny.Tuple.of(false, (SerModel.__default.Expect(_dafny.Seq.UnicodeFromString("false"), inp)).dtor_value));
      } else {
        return SerModel.Option.create_None();
      }
    };
    static ParseState(inp) {
      let _0_valueOrError0 = SerModel.__default.Expect(SerModel.__default.KS0, inp);
      if ((_0_valueOrError0).IsFailure()) {
        return (_0_valueOrError0).PropagateFailure();
      } else {
        let _1_r0 = (_0_valueOrError0).Extract();
        let _2_valueOrError1 = SerModel.__default.ParseStr(_1_r0);
        if ((_2_valueOrError1).IsFailure()) {
          return (_2_valueOrError1).PropagateFailure();
        } else {
          let _3_a = (_2_valueOrError1).Extract();
          let _4_valueOrError2 = SerModel.__default.Expect(SerModel.__default.KS1, (_3_a)[1]);
          if ((_4_valueOrError2).IsFailure()) {
            return (_4_valueOrError2).PropagateFailure();
          } else {
            let _5_r1 = (_4_valueOrError2).Extract();
            let _6_valueOrError3 = SerModel.__default.ParseMoney(_5_r1);
            if ((_6_valueOrError3).IsFailure()) {
              return (_6_valueOrError3).PropagateFailure();
            } else {
              let _7_b = (_6_valueOrError3).Extract();
              let _8_valueOrError4 = SerModel.__default.Expect(SerModel.__default.KS2, (_7_b)[1]);
              if ((_8_valueOrError4).IsFailure()) {
                return (_8_valueOrError4).PropagateFailure();
              } else {
                let _9_r2 = (_8_valueOrError4).Extract();
                let _10_valueOrError5 = SerModel.__default.ParseBool(_9_r2);
                if ((_10_valueOrError5).IsFailure()) {
                  return (_10_valueOrError5).PropagateFailure();
                } else {
                  let _11_c = (_10_valueOrError5).Extract();
                  let _12_valueOrError6 = SerModel.__default.Expect(SerModel.__default.KS3, (_11_c)[1]);
                  if ((_12_valueOrError6).IsFailure()) {
                    return (_12_valueOrError6).PropagateFailure();
                  } else {
                    let _13_r3 = (_12_valueOrError6).Extract();
                    let _14_valueOrError7 = SerModel.__default.ParseMoney(_13_r3);
                    if ((_14_valueOrError7).IsFailure()) {
                      return (_14_valueOrError7).PropagateFailure();
                    } else {
                      let _15_d = (_14_valueOrError7).Extract();
                      let _16_valueOrError8 = SerModel.__default.Expect(SerModel.__default.KEND, (_15_d)[1]);
                      if ((_16_valueOrError8).IsFailure()) {
                        return (_16_valueOrError8).PropagateFailure();
                      } else {
                        let _17_r4 = (_16_valueOrError8).Extract();
                        return SerModel.Option.create_Some(_dafny.Tuple.of(SerModel.ChargeState.create_ChargeState((_3_a)[0], (_7_b)[0], (_15_d)[0], (_11_c)[0]), _17_r4));
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    };
    static ParseIntent(inp) {
      let _0_valueOrError0 = SerModel.__default.Expect(SerModel.__default.KI0, inp);
      if ((_0_valueOrError0).IsFailure()) {
        return (_0_valueOrError0).PropagateFailure();
      } else {
        let _1_r0 = (_0_valueOrError0).Extract();
        let _2_valueOrError1 = SerModel.__default.ParseMoney(_1_r0);
        if ((_2_valueOrError1).IsFailure()) {
          return (_2_valueOrError1).PropagateFailure();
        } else {
          let _3_a = (_2_valueOrError1).Extract();
          let _4_valueOrError2 = SerModel.__default.Expect(SerModel.__default.KI1, (_3_a)[1]);
          if ((_4_valueOrError2).IsFailure()) {
            return (_4_valueOrError2).PropagateFailure();
          } else {
            let _5_r1 = (_4_valueOrError2).Extract();
            let _6_valueOrError3 = SerModel.__default.ParseStr(_5_r1);
            if ((_6_valueOrError3).IsFailure()) {
              return (_6_valueOrError3).PropagateFailure();
            } else {
              let _7_b = (_6_valueOrError3).Extract();
              let _8_valueOrError4 = SerModel.__default.Expect(SerModel.__default.KI2, (_7_b)[1]);
              if ((_8_valueOrError4).IsFailure()) {
                return (_8_valueOrError4).PropagateFailure();
              } else {
                let _9_r2 = (_8_valueOrError4).Extract();
                let _10_valueOrError5 = SerModel.__default.ParseStr(_9_r2);
                if ((_10_valueOrError5).IsFailure()) {
                  return (_10_valueOrError5).PropagateFailure();
                } else {
                  let _11_c = (_10_valueOrError5).Extract();
                  let _12_valueOrError6 = SerModel.__default.Expect(SerModel.__default.KI3, (_11_c)[1]);
                  if ((_12_valueOrError6).IsFailure()) {
                    return (_12_valueOrError6).PropagateFailure();
                  } else {
                    let _13_r3 = (_12_valueOrError6).Extract();
                    let _14_valueOrError7 = SerModel.__default.ParseStr(_13_r3);
                    if ((_14_valueOrError7).IsFailure()) {
                      return (_14_valueOrError7).PropagateFailure();
                    } else {
                      let _15_d = (_14_valueOrError7).Extract();
                      let _16_valueOrError8 = SerModel.__default.Expect(SerModel.__default.KEND, (_15_d)[1]);
                      if ((_16_valueOrError8).IsFailure()) {
                        return (_16_valueOrError8).PropagateFailure();
                      } else {
                        let _17_r4 = (_16_valueOrError8).Extract();
                        return SerModel.Option.create_Some(_dafny.Tuple.of(SerModel.Intent.create_Intent((_7_b)[0], (_15_d)[0], (_3_a)[0], (_11_c)[0]), _17_r4));
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    };
    static ParseBodyRaw(inp) {
      let _0_valueOrError0 = SerModel.__default.Expect(SerModel.__default.KB0, inp);
      if ((_0_valueOrError0).IsFailure()) {
        return (_0_valueOrError0).PropagateFailure();
      } else {
        let _1_r0 = (_0_valueOrError0).Extract();
        let _2_valueOrError1 = SerModel.__default.ParseStr(_1_r0);
        if ((_2_valueOrError1).IsFailure()) {
          return (_2_valueOrError1).PropagateFailure();
        } else {
          let _3_chk = (_2_valueOrError1).Extract();
          let _4_valueOrError2 = SerModel.__default.Expect(SerModel.__default.KB1, (_3_chk)[1]);
          if ((_4_valueOrError2).IsFailure()) {
            return (_4_valueOrError2).PropagateFailure();
          } else {
            let _5_r1 = (_4_valueOrError2).Extract();
            let _6_valueOrError3 = SerModel.__default.ParseStr(_5_r1);
            if ((_6_valueOrError3).IsFailure()) {
              return (_6_valueOrError3).PropagateFailure();
            } else {
              let _7_dom = (_6_valueOrError3).Extract();
              let _8_valueOrError4 = SerModel.__default.Expect(SerModel.__default.KB2, (_7_dom)[1]);
              if ((_8_valueOrError4).IsFailure()) {
                return (_8_valueOrError4).PropagateFailure();
              } else {
                let _9_r2 = (_8_valueOrError4).Extract();
                let _10_valueOrError5 = SerModel.__default.ParseIntent(_9_r2);
                if ((_10_valueOrError5).IsFailure()) {
                  return (_10_valueOrError5).PropagateFailure();
                } else {
                  let _11_it = (_10_valueOrError5).Extract();
                  let _12_valueOrError6 = SerModel.__default.Expect(SerModel.__default.KB3, (_11_it)[1]);
                  if ((_12_valueOrError6).IsFailure()) {
                    return (_12_valueOrError6).PropagateFailure();
                  } else {
                    let _13_r3 = (_12_valueOrError6).Extract();
                    let _14_valueOrError7 = SerModel.__default.ParseState(_13_r3);
                    if ((_14_valueOrError7).IsFailure()) {
                      return (_14_valueOrError7).PropagateFailure();
                    } else {
                      let _15_st = (_14_valueOrError7).Extract();
                      let _16_valueOrError8 = SerModel.__default.Expect(SerModel.__default.KB4, (_15_st)[1]);
                      if ((_16_valueOrError8).IsFailure()) {
                        return (_16_valueOrError8).PropagateFailure();
                      } else {
                        let _17_r4 = (_16_valueOrError8).Extract();
                        let _18_valueOrError9 = SerModel.__default.ParseStr(_17_r4);
                        if ((_18_valueOrError9).IsFailure()) {
                          return (_18_valueOrError9).PropagateFailure();
                        } else {
                          let _19_pre = (_18_valueOrError9).Extract();
                          let _20_valueOrError10 = SerModel.__default.Expect(SerModel.__default.KB5, (_19_pre)[1]);
                          if ((_20_valueOrError10).IsFailure()) {
                            return (_20_valueOrError10).PropagateFailure();
                          } else {
                            let _21_r5 = (_20_valueOrError10).Extract();
                            let _22_valueOrError11 = SerModel.__default.ParseStr(_21_r5);
                            if ((_22_valueOrError11).IsFailure()) {
                              return (_22_valueOrError11).PropagateFailure();
                            } else {
                              let _23_rq = (_22_valueOrError11).Extract();
                              let _24_valueOrError12 = SerModel.__default.Expect(SerModel.__default.KB6, (_23_rq)[1]);
                              if ((_24_valueOrError12).IsFailure()) {
                                return (_24_valueOrError12).PropagateFailure();
                              } else {
                                let _25_r6 = (_24_valueOrError12).Extract();
                                let _26_valueOrError13 = SerModel.__default.ParseStr(_25_r6);
                                if ((_26_valueOrError13).IsFailure()) {
                                  return (_26_valueOrError13).PropagateFailure();
                                } else {
                                  let _27_sp = (_26_valueOrError13).Extract();
                                  let _28_valueOrError14 = SerModel.__default.Expect(SerModel.__default.KEND, (_27_sp)[1]);
                                  if ((_28_valueOrError14).IsFailure()) {
                                    return (_28_valueOrError14).PropagateFailure();
                                  } else {
                                    let _29_r7 = (_28_valueOrError14).Extract();
                                    return SerModel.Option.create_Some(_dafny.Tuple.of(SerModel.TokenBody.create_TokenBody((_7_dom)[0], (_27_sp)[0], (_3_chk)[0], (_19_pre)[0], (_23_rq)[0], (_15_st)[0], (_11_it)[0]), _29_r7));
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    };
    static Parse(inp) {
      let _0_valueOrError0 = SerModel.__default.ParseBodyRaw(inp);
      if ((_0_valueOrError0).IsFailure()) {
        return (_0_valueOrError0).PropagateFailure();
      } else {
        let _1_p = (_0_valueOrError0).Extract();
        if ((_dafny.areEqual((_1_p)[1], _dafny.Seq.of())) && (SerModel.__default.WfBody((_1_p)[0]))) {
          return SerModel.Option.create_Some((_1_p)[0]);
        } else {
          return SerModel.Option.create_None();
        }
      }
    };
    static Utf8Char(c) {
      let _0_v = new BigNumber((c).value);
      if ((_0_v).isLessThan(new BigNumber(128))) {
        return _dafny.Seq.of(_0_v);
      } else if ((_0_v).isLessThan(new BigNumber(2048))) {
        return _dafny.Seq.of((new BigNumber(192)).plus(_dafny.EuclideanDivision(_0_v, new BigNumber(64))), (new BigNumber(128)).plus((_0_v).mod(new BigNumber(64))));
      } else if ((_0_v).isLessThan(new BigNumber(65536))) {
        return _dafny.Seq.of((new BigNumber(224)).plus(_dafny.EuclideanDivision(_0_v, new BigNumber(4096))), (new BigNumber(128)).plus((_dafny.EuclideanDivision(_0_v, new BigNumber(64))).mod(new BigNumber(64))), (new BigNumber(128)).plus((_0_v).mod(new BigNumber(64))));
      } else {
        return _dafny.Seq.of((new BigNumber(240)).plus(_dafny.EuclideanDivision(_0_v, new BigNumber(262144))), (new BigNumber(128)).plus((_dafny.EuclideanDivision(_0_v, new BigNumber(4096))).mod(new BigNumber(64))), (new BigNumber(128)).plus((_dafny.EuclideanDivision(_0_v, new BigNumber(64))).mod(new BigNumber(64))), (new BigNumber(128)).plus((_0_v).mod(new BigNumber(64))));
      }
    };
    static Utf8(s) {
      let _0___accumulator = _dafny.Seq.of();
      TAIL_CALL_START: while (true) {
        if ((new BigNumber((s).length)).isEqualTo(_dafny.ZERO)) {
          return _dafny.Seq.Concat(_0___accumulator, _dafny.Seq.of());
        } else {
          _0___accumulator = _dafny.Seq.Concat(_0___accumulator, SerModel.__default.Utf8Char((s)[_dafny.ZERO]));
          let _in0 = (s).slice(_dafny.ONE);
          s = _in0;
          continue TAIL_CALL_START;
        }
      }
    };
    static LeadLen(b) {
      if ((b).isLessThan(new BigNumber(128))) {
        return _dafny.ONE;
      } else if ((b).isLessThan(new BigNumber(224))) {
        return new BigNumber(2);
      } else if ((b).isLessThan(new BigNumber(240))) {
        return new BigNumber(3);
      } else {
        return new BigNumber(4);
      }
    };
    static DecodeFirst(m) {
      let _0_n = SerModel.__default.LeadLen((m)[_dafny.ZERO]);
      if ((_0_n).isEqualTo(_dafny.ONE)) {
        return (m)[_dafny.ZERO];
      } else if ((_0_n).isEqualTo(new BigNumber(2))) {
        return ((((m)[_dafny.ZERO]).minus(new BigNumber(192))).multipliedBy(new BigNumber(64))).plus(((m)[_dafny.ONE]).minus(new BigNumber(128)));
      } else if ((_0_n).isEqualTo(new BigNumber(3))) {
        return (((((m)[_dafny.ZERO]).minus(new BigNumber(224))).multipliedBy(new BigNumber(4096))).plus((((m)[_dafny.ONE]).minus(new BigNumber(128))).multipliedBy(new BigNumber(64)))).plus(((m)[new BigNumber(2)]).minus(new BigNumber(128)));
      } else {
        return ((((((m)[_dafny.ZERO]).minus(new BigNumber(240))).multipliedBy(new BigNumber(262144))).plus((((m)[_dafny.ONE]).minus(new BigNumber(128))).multipliedBy(new BigNumber(4096)))).plus((((m)[new BigNumber(2)]).minus(new BigNumber(128))).multipliedBy(new BigNumber(64)))).plus(((m)[new BigNumber(3)]).minus(new BigNumber(128)));
      }
    };
    static SignedBytes(b) {
      return SerModel.__default.Utf8(SerModel.__default.SerBody(b));
    };
    static Q0(s) {
      return _dafny.Seq.Concat(_dafny.Seq.Concat(_dafny.Seq.of(new _dafny.CodePoint('"'.codePointAt(0))), s), _dafny.Seq.of(new _dafny.CodePoint('"'.codePointAt(0))));
    };
    static SerIntentNoEsc(i) {
      return _dafny.Seq.Concat(SerModel.__default.KI0, _dafny.Seq.Concat(SerModel.__default.Q0(SerModel.__default.NatToDec((i).dtor_amount)), _dafny.Seq.Concat(SerModel.__default.KI1, _dafny.Seq.Concat(SerModel.__default.Q0((i).dtor_chargeId), _dafny.Seq.Concat(SerModel.__default.KI2, _dafny.Seq.Concat(SerModel.__default.Q0((i).dtor_reason), _dafny.Seq.Concat(SerModel.__default.KI3, _dafny.Seq.Concat(SerModel.__default.Q0((i).dtor_requestId), SerModel.__default.KEND))))))));
    };
    static SerIntentConcat(i) {
      return _dafny.Seq.Concat((i).dtor_reason, (i).dtor_requestId);
    };
    static get MAX__TEXT() {
      return new BigNumber(256);
    };
    static get MONEY__BOUND() {
      return new BigNumber("10000000000000000000");
    };
    static get DOMAIN() {
      return _dafny.Seq.UnicodeFromString("FORGE_REFUND_FINALITY_SLICE1_V1");
    };
    static get KS0() {
      return _dafny.Seq.UnicodeFromString("{\"chargeId\":");
    };
    static get KS1() {
      return _dafny.Seq.UnicodeFromString(",\"original\":");
    };
    static get KS2() {
      return _dafny.Seq.UnicodeFromString(",\"refundEnabled\":");
    };
    static get KS3() {
      return _dafny.Seq.UnicodeFromString(",\"remaining\":");
    };
    static get KEND() {
      return _dafny.Seq.UnicodeFromString("}");
    };
    static get KI0() {
      return _dafny.Seq.UnicodeFromString("{\"amount\":");
    };
    static get KI1() {
      return _dafny.Seq.UnicodeFromString(",\"chargeId\":");
    };
    static get KI2() {
      return _dafny.Seq.UnicodeFromString(",\"reason\":");
    };
    static get KI3() {
      return _dafny.Seq.UnicodeFromString(",\"requestId\":");
    };
    static get KB0() {
      return _dafny.Seq.UnicodeFromString("{\"checkerSha256\":");
    };
    static get KB1() {
      return _dafny.Seq.UnicodeFromString(",\"domain\":");
    };
    static get KB2() {
      return _dafny.Seq.UnicodeFromString(",\"intent\":");
    };
    static get KB3() {
      return _dafny.Seq.UnicodeFromString(",\"post\":");
    };
    static get KB4() {
      return _dafny.Seq.UnicodeFromString(",\"preStateSha256\":");
    };
    static get KB5() {
      return _dafny.Seq.UnicodeFromString(",\"requestId\":");
    };
    static get KB6() {
      return _dafny.Seq.UnicodeFromString(",\"specLockSha256\":");
    };
    static get R1() {
      return _dafny.Seq.UnicodeFromString("x\",\"requestId\":\"y");
    };
    static get CI1() {
      return SerModel.Intent.create_Intent(_dafny.Seq.UnicodeFromString("ch_1"), _dafny.Seq.UnicodeFromString("z"), _dafny.ZERO, SerModel.__default.R1);
    };
    static get R2() {
      return _dafny.Seq.UnicodeFromString("y\",\"requestId\":\"z");
    };
    static get CI2() {
      return SerModel.Intent.create_Intent(_dafny.Seq.UnicodeFromString("ch_1"), SerModel.__default.R2, _dafny.ZERO, _dafny.Seq.UnicodeFromString("x"));
    };
    static get ZERO64() {
      return _dafny.Seq.Create(new BigNumber(64), function (_0___v0) {
        return new _dafny.CodePoint('0'.codePointAt(0));
      });
    };
    static get CB1() {
      return SerModel.TokenBody.create_TokenBody(SerModel.__default.DOMAIN, SerModel.__default.ZERO64, SerModel.__default.ZERO64, SerModel.__default.ZERO64, _dafny.Seq.UnicodeFromString("z"), SerModel.ChargeState.create_ChargeState(_dafny.Seq.UnicodeFromString("ch_1"), new BigNumber(100), new BigNumber(100), true), SerModel.__default.CI1);
    };
    static get CB2() {
      return SerModel.TokenBody.create_TokenBody(SerModel.__default.DOMAIN, SerModel.__default.ZERO64, SerModel.__default.ZERO64, SerModel.__default.ZERO64, _dafny.Seq.UnicodeFromString("z"), SerModel.ChargeState.create_ChargeState(_dafny.Seq.UnicodeFromString("ch_1"), new BigNumber(100), new BigNumber(100), true), SerModel.__default.CI2);
    };
    static get TAIL() {
      return _dafny.Seq.UnicodeFromString("\"x\",\"requestId\":\"y\",\"requestId\":\"z\"}");
    };
    static get WB() {
      return SerModel.TokenBody.create_TokenBody(SerModel.__default.DOMAIN, SerModel.__default.ZERO64, SerModel.__default.ZERO64, SerModel.__default.ZERO64, _dafny.Seq.UnicodeFromString("rq_1"), SerModel.ChargeState.create_ChargeState(_dafny.Seq.UnicodeFromString("ch_1"), new BigNumber(100), new BigNumber(100), true), SerModel.Intent.create_Intent(_dafny.Seq.UnicodeFromString("ch_1"), _dafny.Seq.UnicodeFromString("rq_1"), _dafny.ZERO, _dafny.Seq.UnicodeFromString("duplicate_charge")));
    };
  };

  $module.Option = class Option {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_None() {
      let $dt = new Option(0);
      return $dt;
    }
    static create_Some(value) {
      let $dt = new Option(1);
      $dt.value = value;
      return $dt;
    }
    get is_None() { return this.$tag === 0; }
    get is_Some() { return this.$tag === 1; }
    get dtor_value() { return this.value; }
    toString() {
      if (this.$tag === 0) {
        return "SerModel.Option.None";
      } else if (this.$tag === 1) {
        return "SerModel.Option.Some" + "(" + _dafny.toString(this.value) + ")";
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
        return other.$tag === 1 && _dafny.areEqual(this.value, other.value);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return SerModel.Option.create_None();
    }
    static Rtd() {
      return class {
        static get Default() {
          return Option.Default();
        }
      };
    }
    IsFailure() {
      let _this = this;
      return (_this).is_None;
    };
    PropagateFailure() {
      let _this = this;
      return SerModel.Option.create_None();
    };
    Extract() {
      let _this = this;
      return (_this).dtor_value;
    };
  }

  $module.ChargeState = class ChargeState {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_ChargeState(chargeId, original, remaining, refundEnabled) {
      let $dt = new ChargeState(0);
      $dt.chargeId = chargeId;
      $dt.original = original;
      $dt.remaining = remaining;
      $dt.refundEnabled = refundEnabled;
      return $dt;
    }
    get is_ChargeState() { return this.$tag === 0; }
    get dtor_chargeId() { return this.chargeId; }
    get dtor_original() { return this.original; }
    get dtor_remaining() { return this.remaining; }
    get dtor_refundEnabled() { return this.refundEnabled; }
    toString() {
      if (this.$tag === 0) {
        return "SerModel.ChargeState.ChargeState" + "(" + this.chargeId.toVerbatimString(true) + ", " + _dafny.toString(this.original) + ", " + _dafny.toString(this.remaining) + ", " + _dafny.toString(this.refundEnabled) + ")";
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
      return SerModel.ChargeState.create_ChargeState(_dafny.Seq.UnicodeFromString(""), _dafny.ZERO, _dafny.ZERO, false);
    }
    static Rtd() {
      return class {
        static get Default() {
          return ChargeState.Default();
        }
      };
    }
  }

  $module.Intent = class Intent {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Intent(chargeId, requestId, amount, reason) {
      let $dt = new Intent(0);
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
        return "SerModel.Intent.Intent" + "(" + this.chargeId.toVerbatimString(true) + ", " + this.requestId.toVerbatimString(true) + ", " + _dafny.toString(this.amount) + ", " + this.reason.toVerbatimString(true) + ")";
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
      return SerModel.Intent.create_Intent(_dafny.Seq.UnicodeFromString(""), _dafny.Seq.UnicodeFromString(""), _dafny.ZERO, _dafny.Seq.UnicodeFromString(""));
    }
    static Rtd() {
      return class {
        static get Default() {
          return Intent.Default();
        }
      };
    }
  }

  $module.TokenBody = class TokenBody {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_TokenBody(domain, specLockSha256, checkerSha256, preStateSha256, requestId, post, intent) {
      let $dt = new TokenBody(0);
      $dt.domain = domain;
      $dt.specLockSha256 = specLockSha256;
      $dt.checkerSha256 = checkerSha256;
      $dt.preStateSha256 = preStateSha256;
      $dt.requestId = requestId;
      $dt.post = post;
      $dt.intent = intent;
      return $dt;
    }
    get is_TokenBody() { return this.$tag === 0; }
    get dtor_domain() { return this.domain; }
    get dtor_specLockSha256() { return this.specLockSha256; }
    get dtor_checkerSha256() { return this.checkerSha256; }
    get dtor_preStateSha256() { return this.preStateSha256; }
    get dtor_requestId() { return this.requestId; }
    get dtor_post() { return this.post; }
    get dtor_intent() { return this.intent; }
    toString() {
      if (this.$tag === 0) {
        return "SerModel.TokenBody.TokenBody" + "(" + this.domain.toVerbatimString(true) + ", " + this.specLockSha256.toVerbatimString(true) + ", " + this.checkerSha256.toVerbatimString(true) + ", " + this.preStateSha256.toVerbatimString(true) + ", " + this.requestId.toVerbatimString(true) + ", " + _dafny.toString(this.post) + ", " + _dafny.toString(this.intent) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.domain, other.domain) && _dafny.areEqual(this.specLockSha256, other.specLockSha256) && _dafny.areEqual(this.checkerSha256, other.checkerSha256) && _dafny.areEqual(this.preStateSha256, other.preStateSha256) && _dafny.areEqual(this.requestId, other.requestId) && _dafny.areEqual(this.post, other.post) && _dafny.areEqual(this.intent, other.intent);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return SerModel.TokenBody.create_TokenBody(_dafny.Seq.UnicodeFromString(""), _dafny.Seq.UnicodeFromString(""), _dafny.Seq.UnicodeFromString(""), _dafny.Seq.UnicodeFromString(""), _dafny.Seq.UnicodeFromString(""), SerModel.ChargeState.Default(), SerModel.Intent.Default());
    }
    static Rtd() {
      return class {
        static get Default() {
          return TokenBody.Default();
        }
      };
    }
  }
  return $module;
})(); // end of module SerModel
let _module = (function() {
  let $module = {};

  return $module;
})(); // end of module _module

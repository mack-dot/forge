// Dafny program Probe.dfy compiled into JavaScript
let Probe = (function() {
  let $module = {};

  $module.__default = class __default {
    constructor () {
      this._tname = "Probe._default";
    }
    _parentTraits() {
      return [];
    }
    static P01() {
      return _dafny.areEqual(_dafny.Seq.UnicodeFromString("x\ny"), _dafny.Seq.UnicodeFromString("x\ny"));
    };
    static P02() {
      return (new BigNumber((_dafny.Seq.UnicodeFromString("x\ny")).length)).isEqualTo(new BigNumber(3));
    };
    static P03() {
      return _dafny.areEqual(_dafny.Seq.UnicodeFromString("x\ny"), _dafny.Seq.UnicodeFromString("x\ry"));
    };
    static P04() {
      return _dafny.areEqual(_dafny.Seq.UnicodeFromString("x\r\ny"), _dafny.Seq.UnicodeFromString("x\r\ny"));
    };
    static P05() {
      return _dafny.areEqual(_dafny.Seq.UnicodeFromString("x\n\ny"), _dafny.Seq.UnicodeFromString("x\n\ny"));
    };
    static P06() {
      return _dafny.areEqual(_dafny.Seq.UnicodeFromString("x\n\r\ny"), _dafny.Seq.UnicodeFromString("x\n\r\ny"));
    };
    static P07() {
      return _dafny.areEqual(_dafny.Seq.UnicodeFromString("\u{1F600}"), _dafny.Seq.UnicodeFromString("😀"));
    };
    static P08() {
      return (new BigNumber((_dafny.Seq.UnicodeFromString("😀")).length)).isEqualTo(_dafny.ONE);
    };
    static P09() {
      return _dafny.areEqual(new _dafny.CodePoint('\u{1F600}'.codePointAt(0)), new _dafny.CodePoint('😀'.codePointAt(0)));
    };
    static P10() {
      return (new BigNumber((_dafny.Seq.UnicodeFromString("\u{10FFFF}")).length)).isEqualTo(_dafny.ONE);
    };
    static P11() {
      return (((new BigNumber((_dafny.Seq.UnicodeFromString("a b")).length)).isEqualTo(new BigNumber(3))) && (_dafny.areEqual(_dafny.Seq.UnicodeFromString("a b"), _dafny.Seq.UnicodeFromString("a\u{2028}b")))) && (_dafny.areEqual(_dafny.Seq.UnicodeFromString("a b"), _dafny.Seq.UnicodeFromString("a\u{2029}b")));
    };
    static P12() {
      return ((_dafny.areEqual(_dafny.Seq.UnicodeFromString("a	b"), _dafny.Seq.UnicodeFromString("a\tb"))) && (_dafny.areEqual(_dafny.Seq.UnicodeFromString("ab"), _dafny.Seq.UnicodeFromString("a\u{000C}b")))) && (_dafny.areEqual(_dafny.Seq.UnicodeFromString("ab"), _dafny.Seq.UnicodeFromString("a\u{000B}b")));
    };
    static P13() {
      return ((_dafny.areEqual(_dafny.Seq.UnicodeFromString("a\"b"), _dafny.Seq.UnicodeFromString("a\"b"))) && (_dafny.areEqual(_dafny.Seq.UnicodeFromString("\\"), _dafny.Seq.UnicodeFromString("\\")))) && (_dafny.areEqual(_dafny.Seq.UnicodeFromString("\\n"), _dafny.Seq.UnicodeFromString("\\n")));
    };
    static P14() {
      return ((((new BigNumber((_dafny.Seq.UnicodeFromString("\u0000")).length)).isEqualTo(_dafny.ONE)) && (_dafny.areEqual(_dafny.Seq.UnicodeFromString("\u0000"), _dafny.Seq.UnicodeFromString("\u{0}")))) && (_dafny.areEqual(_dafny.Seq.UnicodeFromString("\u00001"), _dafny.Seq.UnicodeFromString("\u{0}1")))) && ((new BigNumber((_dafny.Seq.UnicodeFromString("\u00001")).length)).isEqualTo(new BigNumber(2)));
    };
    static P15() {
      return (((!_dafny.areEqual(_dafny.Seq.UnicodeFromString("\r"), _dafny.Seq.UnicodeFromString("\n"))) && ((new BigNumber((_dafny.Seq.UnicodeFromString("\r\n")).length)).isEqualTo(new BigNumber(2)))) && (_dafny.areEqual(_dafny.Seq.UnicodeFromString("\'"), _dafny.Seq.UnicodeFromString("'")))) && (_dafny.areEqual(new _dafny.CodePoint('\"'.codePointAt(0)), new _dafny.CodePoint('"'.codePointAt(0))));
    };
    static P16() {
      return (((new BigNumber((_dafny.Seq.UnicodeFromString("ab")).length)).isEqualTo(new BigNumber(3))) && (_dafny.areEqual(_dafny.Seq.UnicodeFromString("ab"), _dafny.Seq.UnicodeFromString("a\u{85}b")))) && ((new BigNumber((_dafny.Seq.UnicodeFromString("﻿")).length)).isEqualTo(_dafny.ONE));
    };
    static P18() {
      return ((new BigNumber("9999999999999999999")).minus(new BigNumber("9007199254740993"))).isEqualTo(new BigNumber("9990992800745259006"));
    };
    static P19() {
      return ((((_dafny.EuclideanDivision(new BigNumber("9999999999999999999"), new BigNumber(7))).isEqualTo(new BigNumber("1428571428571428571"))) && (((new BigNumber("9999999999999999999")).mod(new BigNumber(7))).isEqualTo(new BigNumber(2)))) && ((_dafny.EuclideanDivision(new BigNumber("9999999999999999999"), new BigNumber(-7))).isEqualTo(new BigNumber("-1428571428571428571")))) && (((new BigNumber("9999999999999999999")).mod(new BigNumber(-7))).isEqualTo(new BigNumber(2)));
    };
    static P20() {
      return ((((_dafny.EuclideanDivision(new BigNumber("-9999999999999999999"), new BigNumber(7))).isEqualTo(new BigNumber("-1428571428571428572"))) && (((new BigNumber("-9999999999999999999")).mod(new BigNumber(7))).isEqualTo(new BigNumber(5)))) && ((_dafny.EuclideanDivision(new BigNumber("-9999999999999999999"), new BigNumber(-7))).isEqualTo(new BigNumber("1428571428571428572")))) && (((new BigNumber("-9999999999999999999")).mod(new BigNumber(-7))).isEqualTo(new BigNumber(5)));
    };
    static P21() {
      return ((!(new BigNumber("9007199254740993")).isEqualTo(new BigNumber("9007199254740992"))) && (!(new BigNumber("-9007199254740993")).isEqualTo(new BigNumber("-9007199254740992")))) && (((_dafny.ZERO).minus(new BigNumber("-9007199254740993"))).isEqualTo(new BigNumber("9007199254740993")));
    };
    static P22(s) {
      return (new BigNumber((_dafny.Set.fromElements(s, _dafny.Seq.UnicodeFromString("x"))).length)).isEqualTo(_dafny.ONE);
    };
    static P23(a) {
      return ((new BigNumber((_dafny.Set.fromElements(a, _dafny.ONE)).length)).isEqualTo(_dafny.ONE)) && ((new BigNumber((_dafny.Seq.of(a, _dafny.ONE)).length)).isEqualTo(new BigNumber(2)));
    };
    static P24(a) {
      return (new BigNumber((_dafny.Set.fromElements((a).minus(_dafny.ZERO), new BigNumber("9007199254740993"))).length)).isEqualTo(_dafny.ONE);
    };
    static P25(s) {
      return ((_dafny.Seq.contains(s, new _dafny.CodePoint('😀'.codePointAt(0)))) && (_dafny.areEqual(s, _dafny.Seq.UnicodeFromString("😀")))) && ((new BigNumber((s).length)).isEqualTo(_dafny.ONE));
    };
    static P26(a) {
      return ((_dafny.areEqual(_dafny.Seq.of(_dafny.Seq.of(a, new BigNumber(2)), _dafny.Seq.of(new BigNumber(3))), _dafny.Seq.of(_dafny.Seq.of(_dafny.ONE, new BigNumber(2)), _dafny.Seq.of(new BigNumber(3))))) && (_dafny.areEqual(_dafny.Tuple.of(a, _dafny.Seq.UnicodeFromString("q")), _dafny.Tuple.of(_dafny.ONE, _dafny.Seq.UnicodeFromString("q"))))) && ((_dafny.Set.fromElements(_dafny.Seq.of(a))).equals(_dafny.Set.fromElements(_dafny.Seq.of(_dafny.ONE))));
    };
    static P27(s) {
      return (((_dafny.Set.fromElements(_dafny.Seq.UnicodeFromString("x"), _dafny.Seq.UnicodeFromString("x"), _dafny.Seq.UnicodeFromString("y"))).contains(s)) && (_dafny.Seq.contains(_dafny.Seq.of(_dafny.Seq.UnicodeFromString("y"), _dafny.Seq.UnicodeFromString("x"), _dafny.Seq.UnicodeFromString("x")), s))) && ((new BigNumber((_dafny.Set.fromElements(_dafny.Seq.UnicodeFromString("x"), _dafny.Seq.UnicodeFromString("x"), s)).length)).isEqualTo(_dafny.ONE));
    };
    static P28(a) {
      return (((a).mod(new BigNumber(7))).isEqualTo(new BigNumber(5))) && ((_dafny.EuclideanDivision(a, new BigNumber(7))).isEqualTo(new BigNumber(-1)));
    };
    static P29(a, b) {
      return ((((_dafny.ZERO).isLessThanOrEqualTo(a)) && ((a).isLessThanOrEqualTo(b))) && ((b).isLessThan(new BigNumber(10)))) && (((a).isEqualTo(b)) && ((b).isEqualTo(new BigNumber(3))));
    };
    static P30(s) {
      return (new BigNumber((_dafny.Set.fromElements(s, _dafny.Seq.UnicodeFromString("x\ny"))).length)).isEqualTo(_dafny.ONE);
    };
    static P31(s) {
      return (new BigNumber((_dafny.Set.fromElements(s, _dafny.Seq.UnicodeFromString("x\ny"))).length)).isEqualTo(new BigNumber(2));
    };
  };
  return $module;
})(); // end of module Probe
let _module = (function() {
  let $module = {};

  return $module;
})(); // end of module _module

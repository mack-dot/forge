// Dafny program Refund.dfy compiled into JavaScript
// Copyright by the contributors to the Dafny Project
// SPDX-License-Identifier: MIT

const BigNumber = require('bignumber.js');
BigNumber.config({ MODULO_MODE: BigNumber.EUCLID })
let _dafny = (function() {
  let $module = {};
  $module.areEqual = function(a, b) {
    if (typeof a === 'string' && b instanceof _dafny.Seq) {
      // Seq.equals(string) works as expected,
      // and the catch-all else block handles that direction.
      // But the opposite direction doesn't work; handle it here.
      return b.equals(a);
    } else if (typeof a === 'number' && BigNumber.isBigNumber(b)) {
      // This conditional would be correct even without the `typeof a` part,
      // but in most cases it's probably faster to short-circuit on a `typeof`
      // than to call `isBigNumber`. (But it remains to properly test this.)
      return b.isEqualTo(a);
    } else if (typeof a !== 'object' || a === null || b === null) {
      return a === b;
    } else if (BigNumber.isBigNumber(a)) {
      return a.isEqualTo(b);
    } else if (a._tname !== undefined || (Array.isArray(a) && a.constructor.name == "Array")) {
      return a === b;  // pointer equality
    } else {
      return a.equals(b);  // value-type equality
    }
  }
  $module.toString = function(a) {
    if (a === null) {
      return "null";
    } else if (typeof a === "number") {
      return a.toFixed();
    } else if (BigNumber.isBigNumber(a)) {
      return a.toFixed();
    } else if (a._tname !== undefined) {
      return a._tname;
    } else {
      return a.toString();
    }
  }
  $module.escapeCharacter = function(cp) {
    let s = String.fromCodePoint(cp.value)
    switch (s) {
      case '\n': return "\\n";
      case '\r': return "\\r";
      case '\t': return "\\t";
      case '\0': return "\\0";
      case '\'': return "\\'";
      case '\"': return "\\\"";
      case '\\': return "\\\\";
      default: return s;
    };
  }
  $module.NewObject = function() {
    return { _tname: "object" };
  }
  $module.InstanceOfTrait = function(obj, trait) {
    return obj._parentTraits !== undefined && obj._parentTraits().includes(trait);
  }
  $module.Rtd_bool = class {
    static get Default() { return false; }
  }
  $module.Rtd_char = class {
    static get Default() { return 'D'; }  // See CharType.DefaultValue in Dafny source code
  }
  $module.Rtd_codepoint = class {
    static get Default() { return new _dafny.CodePoint('D'.codePointAt(0)); }
  }
  $module.Rtd_int = class {
    static get Default() { return BigNumber(0); }
  }
  $module.Rtd_number = class {
    static get Default() { return 0; }
  }
  $module.Rtd_ref = class {
    static get Default() { return null; }
  }
  $module.Rtd_array = class {
    static get Default() { return []; }
  }
  $module.ZERO = new BigNumber(0);
  $module.ONE = new BigNumber(1);
  $module.NUMBER_LIMIT = new BigNumber(0x20).multipliedBy(0x1000000000000);  // 2^53
  $module.Tuple = class Tuple extends Array {
    constructor(...elems) {
      super(...elems);
    }
    toString() {
      return "(" + arrayElementsToString(this) + ")";
    }
    equals(other) {
      if (this === other) {
        return true;
      }
      for (let i = 0; i < this.length; i++) {
        if (!_dafny.areEqual(this[i], other[i])) {
          return false;
        }
      }
      return true;
    }
    static Default(...values) {
      return Tuple.of(...values);
    }
    static Rtd(...rtdArgs) {
      return {
        Default: Tuple.from(rtdArgs, rtd => rtd.Default)
      };
    }
  }
  $module.Set = class Set extends Array {
    constructor() {
      super();
    }
    static get Default() {
      return Set.Empty;
    }
    toString() {
      return "{" + arrayElementsToString(this) + "}";
    }
    static get Empty() {
      if (this._empty === undefined) {
        this._empty = new Set();
      }
      return this._empty;
    }
    static fromElements(...elmts) {
      let s = new Set();
      for (let k of elmts) {
        s.add(k);
      }
      return s;
    }
    contains(k) {
      for (let i = 0; i < this.length; i++) {
        if (_dafny.areEqual(this[i], k)) {
          return true;
        }
      }
      return false;
    }
    add(k) {  // mutates the Set; use only during construction
      if (!this.contains(k)) {
        this.push(k);
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.length !== other.length) {
        return false;
      }
      for (let e of this) {
        if (!other.contains(e)) {
          return false;
        }
      }
      return true;
    }
    get Elements() {
      return this;
    }
    Union(that) {
      if (this.length === 0) {
        return that;
      } else if (that.length === 0) {
        return this;
      } else {
        let s = Set.of(...this);
        for (let k of that) {
          s.add(k);
        }
        return s;
      }
    }
    Intersect(that) {
      if (this.length === 0) {
        return this;
      } else if (that.length === 0) {
        return that;
      } else {
        let s = new Set();
        for (let k of this) {
          if (that.contains(k)) {
            s.push(k);
          }
        }
        return s;
      }
    }
    Difference(that) {
      if (this.length == 0 || that.length == 0) {
        return this;
      } else {
        let s = new Set();
        for (let k of this) {
          if (!that.contains(k)) {
            s.push(k);
          }
        }
        return s;
      }
    }
    IsDisjointFrom(that) {
      for (let k of this) {
        if (that.contains(k)) {
          return false;
        }
      }
      return true;
    }
    IsSubsetOf(that) {
      if (that.length < this.length) {
        return false;
      }
      for (let k of this) {
        if (!that.contains(k)) {
          return false;
        }
      }
      return true;
    }
    IsProperSubsetOf(that) {
      if (that.length <= this.length) {
        return false;
      }
      for (let k of this) {
        if (!that.contains(k)) {
          return false;
        }
      }
      return true;
    }
    get AllSubsets() {
      return this.AllSubsets_();
    }
    *AllSubsets_() {
      // Start by putting all set elements into a list, but don't include null
      let elmts = Array.of(...this);
      let n = elmts.length;
      let which = new Array(n);
      which.fill(false);
      let a = [];
      while (true) {
        yield Set.of(...a);
        // "add 1" to "which", as if doing a carry chain.  For every digit changed, change the membership of the corresponding element in "a".
        let i = 0;
        for (; i < n && which[i]; i++) {
          which[i] = false;
          // remove elmts[i] from a
          for (let j = 0; j < a.length; j++) {
            if (_dafny.areEqual(a[j], elmts[i])) {
              // move the last element of a into slot j
              a[j] = a[-1];
              a.pop();
              break;
            }
          }
        }
        if (i === n) {
          // we have cycled through all the subsets
          break;
        }
        which[i] = true;
        a.push(elmts[i]);
      }
    }
  }
  $module.MultiSet = class MultiSet extends Array {
    constructor() {
      super();
    }
    static get Default() {
      return MultiSet.Empty;
    }
    toString() {
      let s = "multiset{";
      let sep = "";
      for (let e of this) {
        let [k, n] = e;
        let ks = _dafny.toString(k);
        while (!n.isZero()) {
          n = n.minus(1);
          s += sep + ks;
          sep = ", ";
        }
      }
      s += "}";
      return s;
    }
    static get Empty() {
      if (this._empty === undefined) {
        this._empty = new MultiSet();
      }
      return this._empty;
    }
    static fromElements(...elmts) {
      let s = new MultiSet();
      for (let e of elmts) {
        s.add(e, _dafny.ONE);
      }
      return s;
    }
    static FromArray(arr) {
      let s = new MultiSet();
      for (let e of arr) {
        s.add(e, _dafny.ONE);
      }
      return s;
    }
    cardinality() {
      let c = _dafny.ZERO;
      for (let e of this) {
        let [k, n] = e;
        c = c.plus(n);
      }
      return c;
    }
    clone() {
      let s = new MultiSet();
      for (let e of this) {
        let [k, n] = e;
        s.push([k, n]);  // make sure to create a new array [k, n] here
      }
      return s;
    }
    findIndex(k) {
      for (let i = 0; i < this.length; i++) {
        if (_dafny.areEqual(this[i][0], k)) {
          return i;
        }
      }
      return this.length;
    }
    get(k) {
      let i = this.findIndex(k);
      if (i === this.length) {
        return _dafny.ZERO;
      } else {
        return this[i][1];
      }
    }
    contains(k) {
      return !this.get(k).isZero();
    }
    add(k, n) {
      let i = this.findIndex(k);
      if (i === this.length) {
        this.push([k, n]);
      } else {
        let m = this[i][1];
        this[i] = [k, m.plus(n)];
      }
    }
    update(k, n) {
      let i = this.findIndex(k);
      if (i < this.length && this[i][1].isEqualTo(n)) {
        return this;
      } else if (i === this.length && n.isZero()) {
        return this;
      } else if (i === this.length) {
        let m = this.slice();
        m.push([k, n]);
        return m;
      } else {
        let m = this.slice();
        m[i] = [k, n];
        return m;
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      }
      for (let e of this) {
        let [k, n] = e;
        let m = other.get(k);
        if (!n.isEqualTo(m)) {
          return false;
        }
      }
      return this.cardinality().isEqualTo(other.cardinality());
    }
    get Elements() {
      return this.Elements_();
    }
    *Elements_() {
      for (let i = 0; i < this.length; i++) {
        let [k, n] = this[i];
        while (!n.isZero()) {
          yield k;
          n = n.minus(1);
        }
      }
    }
    get UniqueElements() {
      return this.UniqueElements_();
    }
    *UniqueElements_() {
      for (let e of this) {
        let [k, n] = e;
        if (!n.isZero()) {
          yield k;
        }
      }
    }
    Union(that) {
      if (this.length === 0) {
        return that;
      } else if (that.length === 0) {
        return this;
      } else {
        let s = this.clone();
        for (let e of that) {
          let [k, n] = e;
          s.add(k, n);
        }
        return s;
      }
    }
    Intersect(that) {
      if (this.length === 0) {
        return this;
      } else if (that.length === 0) {
        return that;
      } else {
        let s = new MultiSet();
        for (let e of this) {
          let [k, n] = e;
          let m = that.get(k);
          if (!m.isZero()) {
            s.push([k, m.isLessThan(n) ? m : n]);
          }
        }
        return s;
      }
    }
    Difference(that) {
      if (this.length === 0 || that.length === 0) {
        return this;
      } else {
        let s = new MultiSet();
        for (let e of this) {
          let [k, n] = e;
          let d = n.minus(that.get(k));
          if (d.isGreaterThan(0)) {
            s.push([k, d]);
          }
        }
        return s;
      }
    }
    IsDisjointFrom(that) {
      let intersection = this.Intersect(that);
      return intersection.cardinality().isZero();
    }
    IsSubsetOf(that) {
      for (let e of this) {
        let [k, n] = e;
        let m = that.get(k);
        if (!n.isLessThanOrEqualTo(m)) {
          return false;
        }
      }
      return true;
    }
    IsProperSubsetOf(that) {
      return this.IsSubsetOf(that) && this.cardinality().isLessThan(that.cardinality());
    }
  }
  $module.CodePoint = class CodePoint {
    constructor(value) {
      this.value = value
    }
    equals(other) {
      if (this === other) {
        return true;
      }
      return this.value === other.value
    }
    isLessThan(other) {
      return this.value < other.value
    }
    isLessThanOrEqual(other) {
      return this.value <= other.value
    }
    toString() {
      return "'" + $module.escapeCharacter(this) + "'";
    }
    static isCodePoint(i) {
      return (
        (_dafny.ZERO.isLessThanOrEqualTo(i) && i.isLessThan(new BigNumber(0xD800))) ||
        (new BigNumber(0xE000).isLessThanOrEqualTo(i) && i.isLessThan(new BigNumber(0x11_0000))))
    }
  }
  $module.Seq = class Seq extends Array {
    constructor(...elems) {
      super(...elems);
    }
    static get Default() {
      return Seq.of();
    }
    static Create(n, init) {
      return Seq.from({length: n}, (_, i) => init(new BigNumber(i)));
    }
    static UnicodeFromString(s) {
      return new Seq(...([...s].map(c => new _dafny.CodePoint(c.codePointAt(0)))))
    }
    toString() {
      return "[" + arrayElementsToString(this) + "]";
    }
    toVerbatimString(asLiteral) {
      if (asLiteral) {
        return '"' + this.map(c => _dafny.escapeCharacter(c)).join("") + '"';
      } else {
        return this.map(c => String.fromCodePoint(c.value)).join("");
      }
    }
    static update(s, i, v) {
      if (typeof s === "string") {
        let p = s.slice(0, i);
        let q = s.slice(i.toNumber() + 1);
        return p.concat(v, q);
      } else {
        let t = s.slice();
        t[i] = v;
        return t;
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.length !== other.length) {
        return false;
      }
      for (let i = 0; i < this.length; i++) {
        if (!_dafny.areEqual(this[i], other[i])) {
          return false;
        }
      }
      return true;
    }
    static contains(s, k) {
      if (typeof s === "string") {
        return s.includes(k);
      } else {
        for (let x of s) {
          if (_dafny.areEqual(x, k)) {
            return true;
          }
        }
        return false;
      }
    }
    get Elements() {
      return this;
    }
    get UniqueElements() {
      return _dafny.Set.fromElements(...this);
    }
    static Concat(a, b) {
      if (typeof a === "string" || typeof b === "string") {
        // string concatenation, so make sure both operands are strings before concatenating
        if (typeof a !== "string") {
          // a must be a Seq
          a = a.join("");
        }
        if (typeof b !== "string") {
          // b must be a Seq
          b = b.join("");
        }
        return a + b;
      } else {
        // ordinary concatenation
        let r = Seq.of(...a);
        r.push(...b);
        return r;
      }
    }
    static JoinIfPossible(x) {
      try { return x.join(""); } catch(_error) { return x; }
    }
    static IsPrefixOf(a, b) {
      if (b.length < a.length) {
        return false;
      }
      for (let i = 0; i < a.length; i++) {
        if (!_dafny.areEqual(a[i], b[i])) {
          return false;
        }
      }
      return true;
    }
    static IsProperPrefixOf(a, b) {
      if (b.length <= a.length) {
        return false;
      }
      for (let i = 0; i < a.length; i++) {
        if (!_dafny.areEqual(a[i], b[i])) {
          return false;
        }
      }
      return true;
    }
  }
  $module.Map = class Map extends Array {
    constructor() {
      super();
    }
    static get Default() {
      return Map.of();
    }
    toString() {
      return "map[" + this.map(maplet => _dafny.toString(maplet[0]) + " := " + _dafny.toString(maplet[1])).join(", ") + "]";
    }
    static get Empty() {
      if (this._empty === undefined) {
        this._empty = new Map();
      }
      return this._empty;
    }
    findIndex(k) {
      for (let i = 0; i < this.length; i++) {
        if (_dafny.areEqual(this[i][0], k)) {
          return i;
        }
      }
      return this.length;
    }
    get(k) {
      let i = this.findIndex(k);
      if (i === this.length) {
        return undefined;
      } else {
        return this[i][1];
      }
    }
    contains(k) {
      return this.findIndex(k) < this.length;
    }
    update(k, v) {
      let m = this.slice();
      m.updateUnsafe(k, v);
      return m;
    }
    // Similar to update, but make the modification in-place.
    // Meant to be used in the map constructor.
    updateUnsafe(k, v) {
      let m = this;
      let i = m.findIndex(k);
      m[i] = [k, v];
      return m;
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.length !== other.length) {
        return false;
      }
      for (let e of this) {
        let [k, v] = e;
        let w = other.get(k);
        if (w === undefined || !_dafny.areEqual(v, w)) {
          return false;
        }
      }
      return true;
    }
    get Keys() {
      let s = new _dafny.Set();
      for (let e of this) {
        let [k, v] = e;
        s.push(k);
      }
      return s;
    }
    get Values() {
      let s = new _dafny.Set();
      for (let e of this) {
        let [k, v] = e;
        s.add(v);
      }
      return s;
    }
    get Items() {
      let s = new _dafny.Set();
      for (let e of this) {
        let [k, v] = e;
        s.push(_dafny.Tuple.of(k, v));
      }
      return s;
    }
    Merge(that) {
      let m = that.slice();
      for (let e of this) {
        let [k, v] = e;
        let i = m.findIndex(k);
        if (i == m.length) {
          m[i] = [k, v];
        }
      }
      return m;
    }
    Subtract(keys) {
      if (this.length === 0 || keys.length === 0) {
        return this;
      }
      let m = new Map();
      for (let e of this) {
        let [k, v] = e;
        if (!keys.contains(k)) {
          m[m.length] = e;
        }
      }
      return m;
    }
  }
  $module.newArray = function(initValue, ...dims) {
    return { dims: dims, elmts: buildArray(initValue, ...dims) };
  }
  $module.BigOrdinal = class BigOrdinal {
    static get Default() {
      return _dafny.ZERO;
    }
    static IsLimit(ord) {
      return ord.isZero();
    }
    static IsSucc(ord) {
      return ord.isGreaterThan(0);
    }
    static Offset(ord) {
      return ord;
    }
    static IsNat(ord) {
      return true;  // at run time, every ORDINAL is a natural number
    }
  }
  $module.BigRational = class BigRational {
    static get ZERO() {
      if (this._zero === undefined) {
        this._zero = new BigRational(_dafny.ZERO);
      }
      return this._zero;
    }
    constructor (n, d) {
      // requires d === undefined || 1 <= d
      this.num = n;
      this.den = d === undefined ? _dafny.ONE : d;
      // invariant 1 <= den || (num == 0 && den == 0)
    }
    static get Default() {
      return _dafny.BigRational.ZERO;
    }
    // We need to deal with the special case `num == 0 && den == 0`, because
    // that's what C#'s default struct constructor will produce for BigRational. :(
    // To deal with it, we ignore `den` when `num` is 0.
    toString() {
      if (this.num.isZero() || this.den.isEqualTo(1)) {
        return this.num.toFixed() + ".0";
      }
      let answer = this.dividesAPowerOf10(this.den);
      if (answer !== undefined) {
        let n = this.num.multipliedBy(answer[0]);
        let log10 = answer[1];
        let sign, digits;
        if (this.num.isLessThan(0)) {
          sign = "-"; digits = n.negated().toFixed();
        } else {
          sign = ""; digits = n.toFixed();
        }
        if (log10 < digits.length) {
          let digitCount = digits.length - log10;
          return sign + digits.slice(0, digitCount) + "." + digits.slice(digitCount);
        } else {
          return sign + "0." + "0".repeat(log10 - digits.length) + digits;
        }
      } else {
        return "(" + this.num.toFixed() + ".0 / " + this.den.toFixed() + ".0)";
      }
    }
    isPowerOf10(x) {
      if (x.isZero()) {
        return undefined;
      }
      let log10 = 0;
      while (true) {  // invariant: x != 0 && x * 10^log10 == old(x)
        if (x.isEqualTo(1)) {
          return log10;
        } else if (x.mod(10).isZero()) {
          log10++;
          x = x.dividedToIntegerBy(10);
        } else {
          return undefined;
        }
      }
    }
    dividesAPowerOf10(i) {
      let factor = _dafny.ONE;
      let log10 = 0;
      if (i.isLessThanOrEqualTo(_dafny.ZERO)) {
        return undefined;
      }

      // invariant: 1 <= i && i * 10^log10 == factor * old(i)
      while (i.mod(10).isZero()) {
        i = i.dividedToIntegerBy(10);
       log10++;
      }

      while (i.mod(5).isZero()) {
        i = i.dividedToIntegerBy(5);
        factor = factor.multipliedBy(2);
        log10++;
      }
      while (i.mod(2).isZero()) {
        i = i.dividedToIntegerBy(2);
        factor = factor.multipliedBy(5);
        log10++;
      }

      if (i.isEqualTo(_dafny.ONE)) {
        return [factor, log10];
      } else {
        return undefined;
      }
    }
    toBigNumber() {
      if (this.num.isZero() || this.den.isEqualTo(1)) {
        return this.num;
      } else if (this.num.isGreaterThan(0)) {
        return this.num.dividedToIntegerBy(this.den);
      } else {
        return this.num.minus(this.den).plus(1).dividedToIntegerBy(this.den);
      }
    }
    isInteger() {
      return this.equals(new _dafny.BigRational(this.toBigNumber(), _dafny.ONE));
    }
    // Returns values such that aa/dd == a and bb/dd == b.
    normalize(b) {
      let a = this;
      let aa, bb, dd;
      if (a.num.isZero()) {
        aa = a.num;
        bb = b.num;
        dd = b.den;
      } else if (b.num.isZero()) {
        aa = a.num;
        dd = a.den;
        bb = b.num;
      } else {
        let gcd = BigNumberGcd(a.den, b.den);
        let xx = a.den.dividedToIntegerBy(gcd);
        let yy = b.den.dividedToIntegerBy(gcd);
        // We now have a == a.num / (xx * gcd) and b == b.num / (yy * gcd).
        aa = a.num.multipliedBy(yy);
        bb = b.num.multipliedBy(xx);
        dd = a.den.multipliedBy(yy);
      }
      return [aa, bb, dd];
    }
    compareTo(that) {
      // simple things first
      let asign = this.num.isZero() ? 0 : this.num.isLessThan(0) ? -1 : 1;
      let bsign = that.num.isZero() ? 0 : that.num.isLessThan(0) ? -1 : 1;
      if (asign < 0 && 0 <= bsign) {
        return -1;
      } else if (asign <= 0 && 0 < bsign) {
        return -1;
      } else if (bsign < 0 && 0 <= asign) {
        return 1;
      } else if (bsign <= 0 && 0 < asign) {
        return 1;
      }
      let [aa, bb, dd] = this.normalize(that);
      if (aa.isLessThan(bb)) {
        return -1;
      } else if (aa.isEqualTo(bb)){
        return 0;
      } else {
        return 1;
      }
    }
    equals(that) {
      return this.compareTo(that) === 0;
    }
    isLessThan(that) {
      return this.compareTo(that) < 0;
    }
    isAtMost(that) {
      return this.compareTo(that) <= 0;
    }
    plus(b) {
      let [aa, bb, dd] = this.normalize(b);
      return new BigRational(aa.plus(bb), dd);
    }
    minus(b) {
      let [aa, bb, dd] = this.normalize(b);
      return new BigRational(aa.minus(bb), dd);
    }
    negated() {
      return new BigRational(this.num.negated(), this.den);
    }
    multipliedBy(b) {
      return new BigRational(this.num.multipliedBy(b.num), this.den.multipliedBy(b.den));
    }
    dividedBy(b) {
      let a = this;
      // Compute the reciprocal of b
      let bReciprocal;
      if (b.num.isGreaterThan(0)) {
        bReciprocal = new BigRational(b.den, b.num);
      } else {
        // this is the case b.num < 0
        bReciprocal = new BigRational(b.den.negated(), b.num.negated());
      }
      return a.multipliedBy(bReciprocal);
    }
  }
  $module.EuclideanDivisionNumber = function(a, b) {
    if (0 <= a) {
      if (0 <= b) {
        // +a +b: a/b
        return Math.floor(a / b);
      } else {
        // +a -b: -(a/(-b))
        return -Math.floor(a / -b);
      }
    } else {
      if (0 <= b) {
        // -a +b: -((-a-1)/b) - 1
        return -Math.floor((-a-1) / b) - 1;
      } else {
        // -a -b: ((-a-1)/(-b)) + 1
        return Math.floor((-a-1) / -b) + 1;
      }
    }
  }
  $module.EuclideanDivision = function(a, b) {
    if (a.isGreaterThanOrEqualTo(0)) {
      if (b.isGreaterThanOrEqualTo(0)) {
        // +a +b: a/b
        return a.dividedToIntegerBy(b);
      } else {
        // +a -b: -(a/(-b))
        return a.dividedToIntegerBy(b.negated()).negated();
      }
    } else {
      if (b.isGreaterThanOrEqualTo(0)) {
        // -a +b: -((-a-1)/b) - 1
        return a.negated().minus(1).dividedToIntegerBy(b).negated().minus(1);
      } else {
        // -a -b: ((-a-1)/(-b)) + 1
        return a.negated().minus(1).dividedToIntegerBy(b.negated()).plus(1);
      }
    }
  }
  $module.EuclideanModuloNumber = function(a, b) {
    let bp = Math.abs(b);
    if (0 <= a) {
      // +a: a % bp
      return a % bp;
    } else {
      // c = ((-a) % bp)
      // -a: bp - c if c > 0
      // -a: 0 if c == 0
      let c = (-a) % bp;
      return c === 0 ? c : bp - c;
    }
  }
  $module.ShiftLeft = function(b, n) {
    return b.multipliedBy(new BigNumber(2).exponentiatedBy(n));
  }
  $module.ShiftRight = function(b, n) {
    return b.dividedToIntegerBy(new BigNumber(2).exponentiatedBy(n));
  }
  $module.RotateLeft = function(b, n, w) {  // truncate(b << n) | (b >> (w - n))
    let x = _dafny.ShiftLeft(b, n).mod(new BigNumber(2).exponentiatedBy(w));
    let y = _dafny.ShiftRight(b, w - n);
    return x.plus(y);
  }
  $module.RotateRight = function(b, n, w) {  // (b >> n) | truncate(b << (w - n))
    let x = _dafny.ShiftRight(b, n);
    let y = _dafny.ShiftLeft(b, w - n).mod(new BigNumber(2).exponentiatedBy(w));;
    return x.plus(y);
  }
  $module.BitwiseAnd = function(a, b) {
    let r = _dafny.ZERO;
    const m = _dafny.NUMBER_LIMIT;  // 2^53
    let h = _dafny.ONE;
    while (!a.isZero() && !b.isZero()) {
      let a0 = a.mod(m);
      let b0 = b.mod(m);
      r = r.plus(h.multipliedBy(a0 & b0));
      a = a.dividedToIntegerBy(m);
      b = b.dividedToIntegerBy(m);
      h = h.multipliedBy(m);
    }
    return r;
  }
  $module.BitwiseOr = function(a, b) {
    let r = _dafny.ZERO;
    const m = _dafny.NUMBER_LIMIT;  // 2^53
    let h = _dafny.ONE;
    while (!a.isZero() && !b.isZero()) {
      let a0 = a.mod(m);
      let b0 = b.mod(m);
      r = r.plus(h.multipliedBy(a0 | b0));
      a = a.dividedToIntegerBy(m);
      b = b.dividedToIntegerBy(m);
      h = h.multipliedBy(m);
    }
    r = r.plus(h.multipliedBy(a | b));
    return r;
  }
  $module.BitwiseXor = function(a, b) {
    let r = _dafny.ZERO;
    const m = _dafny.NUMBER_LIMIT;  // 2^53
    let h = _dafny.ONE;
    while (!a.isZero() && !b.isZero()) {
      let a0 = a.mod(m);
      let b0 = b.mod(m);
      r = r.plus(h.multipliedBy(a0 ^ b0));
      a = a.dividedToIntegerBy(m);
      b = b.dividedToIntegerBy(m);
      h = h.multipliedBy(m);
    }
    r = r.plus(h.multipliedBy(a | b));
    return r;
  }
  $module.BitwiseNot = function(a, bits) {
    let r = _dafny.ZERO;
    let h = _dafny.ONE;
    for (let i = 0; i < bits; i++) {
      let bit = a.mod(2);
      if (bit.isZero()) {
        r = r.plus(h);
      }
      a = a.dividedToIntegerBy(2);
      h = h.multipliedBy(2);
    }
    return r;
  }
  $module.Quantifier = function(vals, frall, pred) {
    for (let u of vals) {
      if (pred(u) !== frall) { return !frall; }
    }
    return frall;
  }
  $module.PlusChar = function(a, b) {
    return String.fromCharCode(a.charCodeAt(0) + b.charCodeAt(0));
  }
  $module.UnicodePlusChar = function(a, b) {
    return new _dafny.CodePoint(a.value + b.value);
  }
  $module.MinusChar = function(a, b) {
    return String.fromCharCode(a.charCodeAt(0) - b.charCodeAt(0));
  }
  $module.UnicodeMinusChar = function(a, b) {
    return new _dafny.CodePoint(a.value - b.value);
  }
  $module.AllBooleans = function*() {
    yield false;
    yield true;
  }
  $module.AllChars = function*() {
    for (let i = 0; i < 0x10000; i++) {
      yield String.fromCharCode(i);
    }
  }
  $module.AllUnicodeChars = function*() {
    for (let i = 0; i < 0xD800; i++) {
      yield new _dafny.CodePoint(i);
    }
    for (let i = 0xE0000; i < 0x110000; i++) {
      yield new _dafny.CodePoint(i);
    }
  }
  $module.AllIntegers = function*() {
    yield _dafny.ZERO;
    for (let j = _dafny.ONE;; j = j.plus(1)) {
      yield j;
      yield j.negated();
    }
  }
  $module.IntegerRange = function*(lo, hi) {
    if (lo === null) {
      while (true) {
        hi = hi.minus(1);
        yield hi;
      }
    } else if (hi === null) {
      while (true) {
        yield lo;
        lo = lo.plus(1);
      }
    } else {
      while (lo.isLessThan(hi)) {
        yield lo;
        lo = lo.plus(1);
      }
    }
  }
  $module.SingleValue = function*(v) {
    yield v;
  }
  $module.HaltException = class HaltException extends Error {
    constructor(message) {
      super(message)
    }
  }
  $module.HandleHaltExceptions = function(f) {
    try {
      f()
    } catch (e) {
      if (e instanceof _dafny.HaltException) {
        process.stdout.write("[Program halted] " + e.message + "\n")
        process.exitCode = 1
      } else {
        throw e
      }
    }
  }
  $module.FromMainArguments = function(args) {
    var a = [...args];
    a.splice(0, 2, args[0] + " " + args[1]);
    return a;
  }
  $module.UnicodeFromMainArguments = function(args) {
    return $module.FromMainArguments(args).map(_dafny.Seq.UnicodeFromString);
  }
  return $module;

  // What follows are routines private to the Dafny runtime
  function buildArray(initValue, ...dims) {
    if (dims.length === 0) {
      return initValue;
    } else {
      let a = Array(dims[0].toNumber());
      let b = Array.from(a, (x) => buildArray(initValue, ...dims.slice(1)));
      return b;
    }
  }
  function arrayElementsToString(a) {
    // like `a.join(", ")`, but calling _dafny.toString(x) on every element x instead of x.toString()
    let s = "";
    let sep = "";
    for (let x of a) {
      s += sep + _dafny.toString(x);
      sep = ", ";
    }
    return s;
  }
  function BigNumberGcd(a, b){  // gcd of two non-negative BigNumber's
    while (true) {
      if (a.isZero()) {
        return b;
      } else if (b.isZero()) {
        return a;
      }
      if (a.isLessThan(b)) {
        b = b.modulo(a);
      } else {
        a = a.modulo(b);
      }
    }
  }
})();
// Dafny program systemModulePopulator.dfy compiled into JavaScript
let _System = (function() {
  let $module = {};

  $module.nat = class nat {
    constructor () {
    }
    static get Default() {
      return _dafny.ZERO;
    }
    static _Is(__source) {
      let _0_x = (__source);
      return (_dafny.ZERO).isLessThanOrEqualTo(_0_x);
    }
  };

  return $module;
})(); // end of module _System
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
      if (((response).is_Candidate) && (((response).dtor_amount).isEqualTo(new BigNumber(123456789)))) {
        let _0_x0;
        _0_x0 = (response).dtor_amount;
        let _1_x1;
        _1_x1 = (_0_x0).plus(_0_x0);
        let _2_x2;
        _2_x2 = (_1_x1).plus(_1_x1);
        let _3_x3;
        _3_x3 = (_2_x2).plus(_2_x2);
        let _4_x4;
        _4_x4 = (_3_x3).plus(_3_x3);
        let _5_x5;
        _5_x5 = (_4_x4).plus(_4_x4);
        let _6_x6;
        _6_x6 = (_5_x5).plus(_5_x5);
        let _7_x7;
        _7_x7 = (_6_x6).plus(_6_x6);
        let _8_x8;
        _8_x8 = (_7_x7).plus(_7_x7);
        let _9_x9;
        _9_x9 = (_8_x8).plus(_8_x8);
        let _10_x10;
        _10_x10 = (_9_x9).plus(_9_x9);
        let _11_x11;
        _11_x11 = (_10_x10).plus(_10_x10);
        let _12_x12;
        _12_x12 = (_11_x11).plus(_11_x11);
        let _13_x13;
        _13_x13 = (_12_x12).plus(_12_x12);
        let _14_x14;
        _14_x14 = (_13_x13).plus(_13_x13);
        let _15_x15;
        _15_x15 = (_14_x14).plus(_14_x14);
        let _16_x16;
        _16_x16 = (_15_x15).plus(_15_x15);
        let _17_x17;
        _17_x17 = (_16_x16).plus(_16_x16);
        let _18_x18;
        _18_x18 = (_17_x17).plus(_17_x17);
        let _19_x19;
        _19_x19 = (_18_x18).plus(_18_x18);
        let _20_x20;
        _20_x20 = (_19_x19).plus(_19_x19);
        let _21_x21;
        _21_x21 = (_20_x20).plus(_20_x20);
        let _22_x22;
        _22_x22 = (_21_x21).plus(_21_x21);
        let _23_x23;
        _23_x23 = (_22_x22).plus(_22_x22);
        let _24_x24;
        _24_x24 = (_23_x23).plus(_23_x23);
        let _25_x25;
        _25_x25 = (_24_x24).plus(_24_x24);
        let _26_x26;
        _26_x26 = (_25_x25).plus(_25_x25);
        let _27_x27;
        _27_x27 = (_26_x26).plus(_26_x26);
        let _28_x28;
        _28_x28 = (_27_x27).plus(_27_x27);
        let _29_x29;
        _29_x29 = (_28_x28).plus(_28_x28);
        let _30_x30;
        _30_x30 = (_29_x29).plus(_29_x29);
        let _31_x31;
        _31_x31 = (_30_x30).plus(_30_x30);
        let _32_x32;
        _32_x32 = (_31_x31).plus(_31_x31);
        let _33_x33;
        _33_x33 = (_32_x32).plus(_32_x32);
        let _34_x34;
        _34_x34 = (_33_x33).plus(_33_x33);
        let _35_x35;
        _35_x35 = (_34_x34).plus(_34_x34);
        let _36_x36;
        _36_x36 = (_35_x35).plus(_35_x35);
        let _37_x37;
        _37_x37 = (_36_x36).plus(_36_x36);
        let _38_x38;
        _38_x38 = (_37_x37).plus(_37_x37);
        let _39_x39;
        _39_x39 = (_38_x38).plus(_38_x38);
        let _40_x40;
        _40_x40 = (_39_x39).plus(_39_x39);
        let _41_x41;
        _41_x41 = (_40_x40).plus(_40_x40);
        let _42_x42;
        _42_x42 = (_41_x41).plus(_41_x41);
        let _43_x43;
        _43_x43 = (_42_x42).plus(_42_x42);
        let _44_x44;
        _44_x44 = (_43_x43).plus(_43_x43);
        let _45_x45;
        _45_x45 = (_44_x44).plus(_44_x44);
        let _46_x46;
        _46_x46 = (_45_x45).plus(_45_x45);
        let _47_x47;
        _47_x47 = (_46_x46).plus(_46_x46);
        let _48_x48;
        _48_x48 = (_47_x47).plus(_47_x47);
        let _49_x49;
        _49_x49 = (_48_x48).plus(_48_x48);
        let _50_x50;
        _50_x50 = (_49_x49).plus(_49_x49);
        let _51_x51;
        _51_x51 = (_50_x50).plus(_50_x50);
        let _52_x52;
        _52_x52 = (_51_x51).plus(_51_x51);
        let _53_x53;
        _53_x53 = (_52_x52).plus(_52_x52);
        let _54_x54;
        _54_x54 = (_53_x53).plus(_53_x53);
        let _55_x55;
        _55_x55 = (_54_x54).plus(_54_x54);
        let _56_x56;
        _56_x56 = (_55_x55).plus(_55_x55);
        let _57_x57;
        _57_x57 = (_56_x56).plus(_56_x56);
        let _58_x58;
        _58_x58 = (_57_x57).plus(_57_x57);
        let _59_x59;
        _59_x59 = (_58_x58).plus(_58_x58);
        let _60_x60;
        _60_x60 = (_59_x59).plus(_59_x59);
        let _61_x61;
        _61_x61 = (_60_x60).plus(_60_x60);
        let _62_x62;
        _62_x62 = (_61_x61).plus(_61_x61);
        let _63_x63;
        _63_x63 = (_62_x62).plus(_62_x62);
        let _64_x64;
        _64_x64 = (_63_x63).plus(_63_x63);
        let _65_x65;
        _65_x65 = (_64_x64).plus(_64_x64);
        let _66_x66;
        _66_x66 = (_65_x65).plus(_65_x65);
        let _67_x67;
        _67_x67 = (_66_x66).plus(_66_x66);
        let _68_x68;
        _68_x68 = (_67_x67).plus(_67_x67);
        let _69_x69;
        _69_x69 = (_68_x68).plus(_68_x68);
        let _70_x70;
        _70_x70 = (_69_x69).plus(_69_x69);
        let _71_x71;
        _71_x71 = (_70_x70).plus(_70_x70);
        let _72_x72;
        _72_x72 = (_71_x71).plus(_71_x71);
        let _73_x73;
        _73_x73 = (_72_x72).plus(_72_x72);
        let _74_x74;
        _74_x74 = (_73_x73).plus(_73_x73);
        let _75_x75;
        _75_x75 = (_74_x74).plus(_74_x74);
        let _76_x76;
        _76_x76 = (_75_x75).plus(_75_x75);
        let _77_x77;
        _77_x77 = (_76_x76).plus(_76_x76);
        let _78_x78;
        _78_x78 = (_77_x77).plus(_77_x77);
        let _79_x79;
        _79_x79 = (_78_x78).plus(_78_x78);
        let _80_x80;
        _80_x80 = (_79_x79).plus(_79_x79);
        let _81_x81;
        _81_x81 = (_80_x80).plus(_80_x80);
        let _82_x82;
        _82_x82 = (_81_x81).plus(_81_x81);
        let _83_x83;
        _83_x83 = (_82_x82).plus(_82_x82);
        let _84_x84;
        _84_x84 = (_83_x83).plus(_83_x83);
        let _85_x85;
        _85_x85 = (_84_x84).plus(_84_x84);
        let _86_x86;
        _86_x86 = (_85_x85).plus(_85_x85);
        let _87_x87;
        _87_x87 = (_86_x86).plus(_86_x86);
        let _88_x88;
        _88_x88 = (_87_x87).plus(_87_x87);
        let _89_x89;
        _89_x89 = (_88_x88).plus(_88_x88);
        let _90_x90;
        _90_x90 = (_89_x89).plus(_89_x89);
        let _91_x91;
        _91_x91 = (_90_x90).plus(_90_x90);
        let _92_x92;
        _92_x92 = (_91_x91).plus(_91_x91);
        let _93_x93;
        _93_x93 = (_92_x92).plus(_92_x92);
        let _94_x94;
        _94_x94 = (_93_x93).plus(_93_x93);
        let _95_x95;
        _95_x95 = (_94_x94).plus(_94_x94);
        let _96_x96;
        _96_x96 = (_95_x95).plus(_95_x95);
        let _97_x97;
        _97_x97 = (_96_x96).plus(_96_x96);
        let _98_x98;
        _98_x98 = (_97_x97).plus(_97_x97);
        let _99_x99;
        _99_x99 = (_98_x98).plus(_98_x98);
        let _100_x100;
        _100_x100 = (_99_x99).plus(_99_x99);
        let _101_x101;
        _101_x101 = (_100_x100).plus(_100_x100);
        let _102_x102;
        _102_x102 = (_101_x101).plus(_101_x101);
        let _103_x103;
        _103_x103 = (_102_x102).plus(_102_x102);
        let _104_x104;
        _104_x104 = (_103_x103).plus(_103_x103);
        let _105_x105;
        _105_x105 = (_104_x104).plus(_104_x104);
        let _106_x106;
        _106_x106 = (_105_x105).plus(_105_x105);
        let _107_x107;
        _107_x107 = (_106_x106).plus(_106_x106);
        let _108_x108;
        _108_x108 = (_107_x107).plus(_107_x107);
        let _109_x109;
        _109_x109 = (_108_x108).plus(_108_x108);
        let _110_x110;
        _110_x110 = (_109_x109).plus(_109_x109);
        let _111_x111;
        _111_x111 = (_110_x110).plus(_110_x110);
        let _112_x112;
        _112_x112 = (_111_x111).plus(_111_x111);
        let _113_x113;
        _113_x113 = (_112_x112).plus(_112_x112);
        let _114_x114;
        _114_x114 = (_113_x113).plus(_113_x113);
        let _115_x115;
        _115_x115 = (_114_x114).plus(_114_x114);
        let _116_x116;
        _116_x116 = (_115_x115).plus(_115_x115);
        let _117_x117;
        _117_x117 = (_116_x116).plus(_116_x116);
        let _118_x118;
        _118_x118 = (_117_x117).plus(_117_x117);
        let _119_x119;
        _119_x119 = (_118_x118).plus(_118_x118);
        let _120_x120;
        _120_x120 = (_119_x119).plus(_119_x119);
        let _121_x121;
        _121_x121 = (_120_x120).plus(_120_x120);
        let _122_x122;
        _122_x122 = (_121_x121).plus(_121_x121);
        let _123_x123;
        _123_x123 = (_122_x122).plus(_122_x122);
        let _124_x124;
        _124_x124 = (_123_x123).plus(_123_x123);
        let _125_x125;
        _125_x125 = (_124_x124).plus(_124_x124);
        let _126_x126;
        _126_x126 = (_125_x125).plus(_125_x125);
        let _127_x127;
        _127_x127 = (_126_x126).plus(_126_x126);
        let _128_x128;
        _128_x128 = (_127_x127).plus(_127_x127);
        let _129_x129;
        _129_x129 = (_128_x128).plus(_128_x128);
        let _130_x130;
        _130_x130 = (_129_x129).plus(_129_x129);
        let _131_x131;
        _131_x131 = (_130_x130).plus(_130_x130);
        let _132_x132;
        _132_x132 = (_131_x131).plus(_131_x131);
        let _133_x133;
        _133_x133 = (_132_x132).plus(_132_x132);
        let _134_x134;
        _134_x134 = (_133_x133).plus(_133_x133);
        let _135_x135;
        _135_x135 = (_134_x134).plus(_134_x134);
        let _136_x136;
        _136_x136 = (_135_x135).plus(_135_x135);
        let _137_x137;
        _137_x137 = (_136_x136).plus(_136_x136);
        let _138_x138;
        _138_x138 = (_137_x137).plus(_137_x137);
        let _139_x139;
        _139_x139 = (_138_x138).plus(_138_x138);
        let _140_x140;
        _140_x140 = (_139_x139).plus(_139_x139);
        let _141_x141;
        _141_x141 = (_140_x140).plus(_140_x140);
        let _142_x142;
        _142_x142 = (_141_x141).plus(_141_x141);
        let _143_x143;
        _143_x143 = (_142_x142).plus(_142_x142);
        let _144_x144;
        _144_x144 = (_143_x143).plus(_143_x143);
        let _145_x145;
        _145_x145 = (_144_x144).plus(_144_x144);
        let _146_x146;
        _146_x146 = (_145_x145).plus(_145_x145);
        let _147_x147;
        _147_x147 = (_146_x146).plus(_146_x146);
        let _148_x148;
        _148_x148 = (_147_x147).plus(_147_x147);
        let _149_x149;
        _149_x149 = (_148_x148).plus(_148_x148);
        let _150_x150;
        _150_x150 = (_149_x149).plus(_149_x149);
        let _151_x151;
        _151_x151 = (_150_x150).plus(_150_x150);
        let _152_x152;
        _152_x152 = (_151_x151).plus(_151_x151);
        let _153_x153;
        _153_x153 = (_152_x152).plus(_152_x152);
        let _154_x154;
        _154_x154 = (_153_x153).plus(_153_x153);
        let _155_x155;
        _155_x155 = (_154_x154).plus(_154_x154);
        let _156_x156;
        _156_x156 = (_155_x155).plus(_155_x155);
        let _157_x157;
        _157_x157 = (_156_x156).plus(_156_x156);
        let _158_x158;
        _158_x158 = (_157_x157).plus(_157_x157);
        let _159_x159;
        _159_x159 = (_158_x158).plus(_158_x158);
        let _160_x160;
        _160_x160 = (_159_x159).plus(_159_x159);
        let _161_x161;
        _161_x161 = (_160_x160).plus(_160_x160);
        let _162_x162;
        _162_x162 = (_161_x161).plus(_161_x161);
        let _163_x163;
        _163_x163 = (_162_x162).plus(_162_x162);
        let _164_x164;
        _164_x164 = (_163_x163).plus(_163_x163);
        let _165_x165;
        _165_x165 = (_164_x164).plus(_164_x164);
        let _166_x166;
        _166_x166 = (_165_x165).plus(_165_x165);
        let _167_x167;
        _167_x167 = (_166_x166).plus(_166_x166);
        let _168_x168;
        _168_x168 = (_167_x167).plus(_167_x167);
        let _169_x169;
        _169_x169 = (_168_x168).plus(_168_x168);
        let _170_x170;
        _170_x170 = (_169_x169).plus(_169_x169);
        let _171_x171;
        _171_x171 = (_170_x170).plus(_170_x170);
        let _172_x172;
        _172_x172 = (_171_x171).plus(_171_x171);
        let _173_x173;
        _173_x173 = (_172_x172).plus(_172_x172);
        let _174_x174;
        _174_x174 = (_173_x173).plus(_173_x173);
        let _175_x175;
        _175_x175 = (_174_x174).plus(_174_x174);
        let _176_x176;
        _176_x176 = (_175_x175).plus(_175_x175);
        let _177_x177;
        _177_x177 = (_176_x176).plus(_176_x176);
        let _178_x178;
        _178_x178 = (_177_x177).plus(_177_x177);
        let _179_x179;
        _179_x179 = (_178_x178).plus(_178_x178);
        let _180_x180;
        _180_x180 = (_179_x179).plus(_179_x179);
        let _181_x181;
        _181_x181 = (_180_x180).plus(_180_x180);
        let _182_x182;
        _182_x182 = (_181_x181).plus(_181_x181);
        let _183_x183;
        _183_x183 = (_182_x182).plus(_182_x182);
        let _184_x184;
        _184_x184 = (_183_x183).plus(_183_x183);
        let _185_x185;
        _185_x185 = (_184_x184).plus(_184_x184);
        let _186_x186;
        _186_x186 = (_185_x185).plus(_185_x185);
        let _187_x187;
        _187_x187 = (_186_x186).plus(_186_x186);
        let _188_x188;
        _188_x188 = (_187_x187).plus(_187_x187);
        let _189_x189;
        _189_x189 = (_188_x188).plus(_188_x188);
        let _190_x190;
        _190_x190 = (_189_x189).plus(_189_x189);
        let _191_x191;
        _191_x191 = (_190_x190).plus(_190_x190);
        let _192_x192;
        _192_x192 = (_191_x191).plus(_191_x191);
        let _193_x193;
        _193_x193 = (_192_x192).plus(_192_x192);
        let _194_x194;
        _194_x194 = (_193_x193).plus(_193_x193);
        let _195_x195;
        _195_x195 = (_194_x194).plus(_194_x194);
        let _196_x196;
        _196_x196 = (_195_x195).plus(_195_x195);
        let _197_x197;
        _197_x197 = (_196_x196).plus(_196_x196);
        let _198_x198;
        _198_x198 = (_197_x197).plus(_197_x197);
        let _199_x199;
        _199_x199 = (_198_x198).plus(_198_x198);
        let _200_x200;
        _200_x200 = (_199_x199).plus(_199_x199);
        let _201_x201;
        _201_x201 = (_200_x200).plus(_200_x200);
        let _202_x202;
        _202_x202 = (_201_x201).plus(_201_x201);
        let _203_x203;
        _203_x203 = (_202_x202).plus(_202_x202);
        let _204_x204;
        _204_x204 = (_203_x203).plus(_203_x203);
        let _205_x205;
        _205_x205 = (_204_x204).plus(_204_x204);
        let _206_x206;
        _206_x206 = (_205_x205).plus(_205_x205);
        let _207_x207;
        _207_x207 = (_206_x206).plus(_206_x206);
        let _208_x208;
        _208_x208 = (_207_x207).plus(_207_x207);
        let _209_x209;
        _209_x209 = (_208_x208).plus(_208_x208);
        let _210_x210;
        _210_x210 = (_209_x209).plus(_209_x209);
        let _211_x211;
        _211_x211 = (_210_x210).plus(_210_x210);
        let _212_x212;
        _212_x212 = (_211_x211).plus(_211_x211);
        let _213_x213;
        _213_x213 = (_212_x212).plus(_212_x212);
        let _214_x214;
        _214_x214 = (_213_x213).plus(_213_x213);
        let _215_x215;
        _215_x215 = (_214_x214).plus(_214_x214);
        let _216_x216;
        _216_x216 = (_215_x215).plus(_215_x215);
        let _217_x217;
        _217_x217 = (_216_x216).plus(_216_x216);
        let _218_x218;
        _218_x218 = (_217_x217).plus(_217_x217);
        let _219_x219;
        _219_x219 = (_218_x218).plus(_218_x218);
        let _220_x220;
        _220_x220 = (_219_x219).plus(_219_x219);
        let _221_x221;
        _221_x221 = (_220_x220).plus(_220_x220);
        let _222_x222;
        _222_x222 = (_221_x221).plus(_221_x221);
        let _223_x223;
        _223_x223 = (_222_x222).plus(_222_x222);
        let _224_x224;
        _224_x224 = (_223_x223).plus(_223_x223);
        let _225_x225;
        _225_x225 = (_224_x224).plus(_224_x224);
        let _226_x226;
        _226_x226 = (_225_x225).plus(_225_x225);
        let _227_x227;
        _227_x227 = (_226_x226).plus(_226_x226);
        let _228_x228;
        _228_x228 = (_227_x227).plus(_227_x227);
        let _229_x229;
        _229_x229 = (_228_x228).plus(_228_x228);
        let _230_x230;
        _230_x230 = (_229_x229).plus(_229_x229);
        let _231_x231;
        _231_x231 = (_230_x230).plus(_230_x230);
        let _232_x232;
        _232_x232 = (_231_x231).plus(_231_x231);
        let _233_x233;
        _233_x233 = (_232_x232).plus(_232_x232);
        let _234_x234;
        _234_x234 = (_233_x233).plus(_233_x233);
        let _235_x235;
        _235_x235 = (_234_x234).plus(_234_x234);
        let _236_x236;
        _236_x236 = (_235_x235).plus(_235_x235);
        let _237_x237;
        _237_x237 = (_236_x236).plus(_236_x236);
        let _238_x238;
        _238_x238 = (_237_x237).plus(_237_x237);
        let _239_x239;
        _239_x239 = (_238_x238).plus(_238_x238);
        let _240_x240;
        _240_x240 = (_239_x239).plus(_239_x239);
        let _241_x241;
        _241_x241 = (_240_x240).plus(_240_x240);
        let _242_x242;
        _242_x242 = (_241_x241).plus(_241_x241);
        let _243_x243;
        _243_x243 = (_242_x242).plus(_242_x242);
        let _244_x244;
        _244_x244 = (_243_x243).plus(_243_x243);
        let _245_x245;
        _245_x245 = (_244_x244).plus(_244_x244);
        let _246_x246;
        _246_x246 = (_245_x245).plus(_245_x245);
        let _247_x247;
        _247_x247 = (_246_x246).plus(_246_x246);
        let _248_x248;
        _248_x248 = (_247_x247).plus(_247_x247);
        let _249_x249;
        _249_x249 = (_248_x248).plus(_248_x248);
        let _250_x250;
        _250_x250 = (_249_x249).plus(_249_x249);
        let _251_x251;
        _251_x251 = (_250_x250).plus(_250_x250);
        let _252_x252;
        _252_x252 = (_251_x251).plus(_251_x251);
        let _253_x253;
        _253_x253 = (_252_x252).plus(_252_x252);
        let _254_x254;
        _254_x254 = (_253_x253).plus(_253_x253);
        let _255_x255;
        _255_x255 = (_254_x254).plus(_254_x254);
        let _256_x256;
        _256_x256 = (_255_x255).plus(_255_x255);
        let _257_x257;
        _257_x257 = (_256_x256).plus(_256_x256);
        let _258_x258;
        _258_x258 = (_257_x257).plus(_257_x257);
        let _259_x259;
        _259_x259 = (_258_x258).plus(_258_x258);
        let _260_x260;
        _260_x260 = (_259_x259).plus(_259_x259);
        let _261_x261;
        _261_x261 = (_260_x260).plus(_260_x260);
        let _262_x262;
        _262_x262 = (_261_x261).plus(_261_x261);
        let _263_x263;
        _263_x263 = (_262_x262).plus(_262_x262);
        let _264_x264;
        _264_x264 = (_263_x263).plus(_263_x263);
        let _265_x265;
        _265_x265 = (_264_x264).plus(_264_x264);
        let _266_x266;
        _266_x266 = (_265_x265).plus(_265_x265);
        let _267_x267;
        _267_x267 = (_266_x266).plus(_266_x266);
        let _268_x268;
        _268_x268 = (_267_x267).plus(_267_x267);
        let _269_x269;
        _269_x269 = (_268_x268).plus(_268_x268);
        let _270_x270;
        _270_x270 = (_269_x269).plus(_269_x269);
        let _271_x271;
        _271_x271 = (_270_x270).plus(_270_x270);
        let _272_x272;
        _272_x272 = (_271_x271).plus(_271_x271);
        let _273_x273;
        _273_x273 = (_272_x272).plus(_272_x272);
        let _274_x274;
        _274_x274 = (_273_x273).plus(_273_x273);
        let _275_x275;
        _275_x275 = (_274_x274).plus(_274_x274);
        let _276_x276;
        _276_x276 = (_275_x275).plus(_275_x275);
        let _277_x277;
        _277_x277 = (_276_x276).plus(_276_x276);
        let _278_x278;
        _278_x278 = (_277_x277).plus(_277_x277);
        let _279_x279;
        _279_x279 = (_278_x278).plus(_278_x278);
        let _280_x280;
        _280_x280 = (_279_x279).plus(_279_x279);
        let _281_x281;
        _281_x281 = (_280_x280).plus(_280_x280);
        let _282_x282;
        _282_x282 = (_281_x281).plus(_281_x281);
        let _283_x283;
        _283_x283 = (_282_x282).plus(_282_x282);
        let _284_x284;
        _284_x284 = (_283_x283).plus(_283_x283);
        let _285_x285;
        _285_x285 = (_284_x284).plus(_284_x284);
        let _286_x286;
        _286_x286 = (_285_x285).plus(_285_x285);
        let _287_x287;
        _287_x287 = (_286_x286).plus(_286_x286);
        let _288_x288;
        _288_x288 = (_287_x287).plus(_287_x287);
        let _289_x289;
        _289_x289 = (_288_x288).plus(_288_x288);
        let _290_x290;
        _290_x290 = (_289_x289).plus(_289_x289);
        let _291_x291;
        _291_x291 = (_290_x290).plus(_290_x290);
        let _292_x292;
        _292_x292 = (_291_x291).plus(_291_x291);
        let _293_x293;
        _293_x293 = (_292_x292).plus(_292_x292);
        let _294_x294;
        _294_x294 = (_293_x293).plus(_293_x293);
        let _295_x295;
        _295_x295 = (_294_x294).plus(_294_x294);
        let _296_x296;
        _296_x296 = (_295_x295).plus(_295_x295);
        let _297_x297;
        _297_x297 = (_296_x296).plus(_296_x296);
        let _298_x298;
        _298_x298 = (_297_x297).plus(_297_x297);
        let _299_x299;
        _299_x299 = (_298_x298).plus(_298_x298);
        let _300_x300;
        _300_x300 = (_299_x299).plus(_299_x299);
        let _301_x301;
        _301_x301 = (_300_x300).plus(_300_x300);
        let _302_x302;
        _302_x302 = (_301_x301).plus(_301_x301);
        let _303_x303;
        _303_x303 = (_302_x302).plus(_302_x302);
        let _304_x304;
        _304_x304 = (_303_x303).plus(_303_x303);
        let _305_x305;
        _305_x305 = (_304_x304).plus(_304_x304);
        let _306_x306;
        _306_x306 = (_305_x305).plus(_305_x305);
        let _307_x307;
        _307_x307 = (_306_x306).plus(_306_x306);
        let _308_x308;
        _308_x308 = (_307_x307).plus(_307_x307);
        let _309_x309;
        _309_x309 = (_308_x308).plus(_308_x308);
        let _310_x310;
        _310_x310 = (_309_x309).plus(_309_x309);
        let _311_x311;
        _311_x311 = (_310_x310).plus(_310_x310);
        let _312_x312;
        _312_x312 = (_311_x311).plus(_311_x311);
        let _313_x313;
        _313_x313 = (_312_x312).plus(_312_x312);
        let _314_x314;
        _314_x314 = (_313_x313).plus(_313_x313);
        let _315_x315;
        _315_x315 = (_314_x314).plus(_314_x314);
        let _316_x316;
        _316_x316 = (_315_x315).plus(_315_x315);
        let _317_x317;
        _317_x317 = (_316_x316).plus(_316_x316);
        let _318_x318;
        _318_x318 = (_317_x317).plus(_317_x317);
        let _319_x319;
        _319_x319 = (_318_x318).plus(_318_x318);
        let _320_x320;
        _320_x320 = (_319_x319).plus(_319_x319);
        let _321_x321;
        _321_x321 = (_320_x320).plus(_320_x320);
        let _322_x322;
        _322_x322 = (_321_x321).plus(_321_x321);
        let _323_x323;
        _323_x323 = (_322_x322).plus(_322_x322);
        let _324_x324;
        _324_x324 = (_323_x323).plus(_323_x323);
        let _325_x325;
        _325_x325 = (_324_x324).plus(_324_x324);
        let _326_x326;
        _326_x326 = (_325_x325).plus(_325_x325);
        let _327_x327;
        _327_x327 = (_326_x326).plus(_326_x326);
        let _328_x328;
        _328_x328 = (_327_x327).plus(_327_x327);
        let _329_x329;
        _329_x329 = (_328_x328).plus(_328_x328);
        let _330_x330;
        _330_x330 = (_329_x329).plus(_329_x329);
        let _331_x331;
        _331_x331 = (_330_x330).plus(_330_x330);
        let _332_x332;
        _332_x332 = (_331_x331).plus(_331_x331);
        let _333_x333;
        _333_x333 = (_332_x332).plus(_332_x332);
        let _334_x334;
        _334_x334 = (_333_x333).plus(_333_x333);
        let _335_x335;
        _335_x335 = (_334_x334).plus(_334_x334);
        let _336_x336;
        _336_x336 = (_335_x335).plus(_335_x335);
        let _337_x337;
        _337_x337 = (_336_x336).plus(_336_x336);
        let _338_x338;
        _338_x338 = (_337_x337).plus(_337_x337);
        let _339_x339;
        _339_x339 = (_338_x338).plus(_338_x338);
        let _340_x340;
        _340_x340 = (_339_x339).plus(_339_x339);
        let _341_x341;
        _341_x341 = (_340_x340).plus(_340_x340);
        let _342_x342;
        _342_x342 = (_341_x341).plus(_341_x341);
        let _343_x343;
        _343_x343 = (_342_x342).plus(_342_x342);
        let _344_x344;
        _344_x344 = (_343_x343).plus(_343_x343);
        let _345_x345;
        _345_x345 = (_344_x344).plus(_344_x344);
        let _346_x346;
        _346_x346 = (_345_x345).plus(_345_x345);
        let _347_x347;
        _347_x347 = (_346_x346).plus(_346_x346);
        let _348_x348;
        _348_x348 = (_347_x347).plus(_347_x347);
        let _349_x349;
        _349_x349 = (_348_x348).plus(_348_x348);
        let _350_x350;
        _350_x350 = (_349_x349).plus(_349_x349);
        let _351_x351;
        _351_x351 = (_350_x350).plus(_350_x350);
        let _352_x352;
        _352_x352 = (_351_x351).plus(_351_x351);
        let _353_x353;
        _353_x353 = (_352_x352).plus(_352_x352);
        let _354_x354;
        _354_x354 = (_353_x353).plus(_353_x353);
        let _355_x355;
        _355_x355 = (_354_x354).plus(_354_x354);
        let _356_x356;
        _356_x356 = (_355_x355).plus(_355_x355);
        let _357_x357;
        _357_x357 = (_356_x356).plus(_356_x356);
        let _358_x358;
        _358_x358 = (_357_x357).plus(_357_x357);
        let _359_x359;
        _359_x359 = (_358_x358).plus(_358_x358);
        let _360_x360;
        _360_x360 = (_359_x359).plus(_359_x359);
        let _361_x361;
        _361_x361 = (_360_x360).plus(_360_x360);
        let _362_x362;
        _362_x362 = (_361_x361).plus(_361_x361);
        let _363_x363;
        _363_x363 = (_362_x362).plus(_362_x362);
        let _364_x364;
        _364_x364 = (_363_x363).plus(_363_x363);
        let _365_x365;
        _365_x365 = (_364_x364).plus(_364_x364);
        let _366_x366;
        _366_x366 = (_365_x365).plus(_365_x365);
        let _367_x367;
        _367_x367 = (_366_x366).plus(_366_x366);
        let _368_x368;
        _368_x368 = (_367_x367).plus(_367_x367);
        let _369_x369;
        _369_x369 = (_368_x368).plus(_368_x368);
        let _370_x370;
        _370_x370 = (_369_x369).plus(_369_x369);
        let _371_x371;
        _371_x371 = (_370_x370).plus(_370_x370);
        let _372_x372;
        _372_x372 = (_371_x371).plus(_371_x371);
        let _373_x373;
        _373_x373 = (_372_x372).plus(_372_x372);
        let _374_x374;
        _374_x374 = (_373_x373).plus(_373_x373);
        let _375_x375;
        _375_x375 = (_374_x374).plus(_374_x374);
        let _376_x376;
        _376_x376 = (_375_x375).plus(_375_x375);
        let _377_x377;
        _377_x377 = (_376_x376).plus(_376_x376);
        let _378_x378;
        _378_x378 = (_377_x377).plus(_377_x377);
        let _379_x379;
        _379_x379 = (_378_x378).plus(_378_x378);
        let _380_x380;
        _380_x380 = (_379_x379).plus(_379_x379);
        let _381_x381;
        _381_x381 = (_380_x380).plus(_380_x380);
        let _382_x382;
        _382_x382 = (_381_x381).plus(_381_x381);
        let _383_x383;
        _383_x383 = (_382_x382).plus(_382_x382);
        let _384_x384;
        _384_x384 = (_383_x383).plus(_383_x383);
        let _385_x385;
        _385_x385 = (_384_x384).plus(_384_x384);
        let _386_x386;
        _386_x386 = (_385_x385).plus(_385_x385);
        let _387_x387;
        _387_x387 = (_386_x386).plus(_386_x386);
        let _388_x388;
        _388_x388 = (_387_x387).plus(_387_x387);
        let _389_x389;
        _389_x389 = (_388_x388).plus(_388_x388);
        let _390_x390;
        _390_x390 = (_389_x389).plus(_389_x389);
        let _391_x391;
        _391_x391 = (_390_x390).plus(_390_x390);
        let _392_x392;
        _392_x392 = (_391_x391).plus(_391_x391);
        let _393_x393;
        _393_x393 = (_392_x392).plus(_392_x392);
        let _394_x394;
        _394_x394 = (_393_x393).plus(_393_x393);
        let _395_x395;
        _395_x395 = (_394_x394).plus(_394_x394);
        let _396_x396;
        _396_x396 = (_395_x395).plus(_395_x395);
        let _397_x397;
        _397_x397 = (_396_x396).plus(_396_x396);
        let _398_x398;
        _398_x398 = (_397_x397).plus(_397_x397);
        let _399_x399;
        _399_x399 = (_398_x398).plus(_398_x398);
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

module.exports = { Refund, runtime: _dafny };

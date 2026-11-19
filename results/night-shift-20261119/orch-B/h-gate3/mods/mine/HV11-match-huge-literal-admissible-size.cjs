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
      let _rhs0 = Refund.Decision.create_Rejected();
      let _rhs1 = _dafny.Seq.of();
      decision = _rhs0;
      plan = _rhs1;
      let _source0 = ((((response).is_Candidate) ? ((response).dtor_amount) : (_dafny.ZERO))).mod(new BigNumber(1000));
      Lmatch0: {
        {
          if ((_source0).isEqualTo(_dafny.ZERO)) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(_dafny.ONE)) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(2))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(3))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(4))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(5))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(6))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(7))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(8))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(9))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(10))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(11))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(12))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(13))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(14))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(15))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(16))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(17))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(18))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(19))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(20))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(21))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(22))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(23))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(24))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(25))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(26))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(27))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(28))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(29))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(30))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(31))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(32))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(33))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(34))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(35))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(36))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(37))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(38))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(39))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(40))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(41))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(42))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(43))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(44))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(45))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(46))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(47))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(48))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(49))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(50))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(51))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(52))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(53))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(54))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(55))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(56))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(57))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(58))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(59))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(60))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(61))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(62))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(63))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(64))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(65))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(66))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(67))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(68))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(69))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(70))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(71))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(72))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(73))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(74))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(75))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(76))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(77))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(78))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(79))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(80))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(81))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(82))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(83))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(84))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(85))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(86))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(87))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(88))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(89))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(90))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(91))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(92))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(93))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(94))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(95))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(96))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(97))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(98))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(99))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(100))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(101))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(102))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(103))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(104))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(105))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(106))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(107))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(108))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(109))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(110))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(111))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(112))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(113))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(114))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(115))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(116))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(117))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(118))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(119))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(120))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(121))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(122))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(123))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(124))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(125))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(126))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(127))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(128))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(129))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(130))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(131))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(132))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(133))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(134))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(135))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(136))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(137))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(138))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(139))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(140))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(141))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(142))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(143))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(144))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(145))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(146))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(147))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(148))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(149))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(150))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(151))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(152))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(153))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(154))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(155))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(156))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(157))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(158))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(159))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(160))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(161))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(162))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(163))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(164))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(165))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(166))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(167))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(168))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(169))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(170))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(171))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(172))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(173))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(174))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(175))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(176))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(177))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(178))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(179))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(180))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(181))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(182))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(183))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(184))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(185))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(186))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(187))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(188))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(189))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(190))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(191))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(192))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(193))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(194))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(195))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(196))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(197))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(198))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(199))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(200))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(201))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(202))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(203))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(204))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(205))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(206))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(207))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(208))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(209))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(210))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(211))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(212))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(213))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(214))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(215))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(216))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(217))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(218))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(219))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(220))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(221))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(222))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(223))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(224))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(225))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(226))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(227))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(228))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(229))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(230))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(231))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(232))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(233))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(234))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(235))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(236))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(237))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(238))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(239))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(240))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(241))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(242))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(243))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(244))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(245))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(246))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(247))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(248))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(249))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(250))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(251))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(252))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(253))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(254))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(255))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(256))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(257))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(258))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(259))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(260))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(261))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(262))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(263))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(264))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(265))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(266))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(267))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(268))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(269))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(270))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(271))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(272))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(273))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(274))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(275))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(276))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(277))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(278))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(279))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(280))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(281))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(282))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(283))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(284))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(285))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(286))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(287))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(288))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(289))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(290))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(291))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(292))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(293))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(294))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(295))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(296))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(297))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(298))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(299))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          decision = Refund.Decision.create_Rejected();
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

module.exports = { Refund, runtime: _dafny };

// Dafny program IssueAuth.dfy compiled into JavaScript
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
let IssueBytes2 = (function() {
  let $module = {};

  $module.__default = class __default {
    constructor () {
      this._tname = "IssueBytes2._default";
    }
    _parentTraits() {
      return [];
    }
    static Nat(x) {
      if ((_dafny.ZERO).isLessThanOrEqualTo(x)) {
        return x;
      } else {
        return _dafny.ZERO;
      }
    };
    static StateOf(c) {
      return SerModel.ChargeState.create_ChargeState((c).dtor_chargeId, IssueBytes2.__default.Nat((c).dtor_original), IssueBytes2.__default.Nat((c).dtor_remaining), (c).dtor_refundEnabled);
    };
    static IntentOf(i) {
      return SerModel.Intent.create_Intent((i).dtor_chargeId, (i).dtor_requestId, IssueBytes2.__default.Nat((i).dtor_amount), (i).dtor_reason);
    };
    static BodyFor(specHex, checkerHex, preHashHex, t) {
      return SerModel.TokenBody.create_TokenBody(SerModel.__default.DOMAIN, specHex, checkerHex, preHashHex, ((t).dtor_request).dtor_requestId, IssueBytes2.__default.StateOf((t).dtor_post), IssueBytes2.__default.IntentOf((t).dtor_intent));
    };
    static NoClamp(t) {
      return (((_dafny.ZERO).isLessThanOrEqualTo(((t).dtor_post).dtor_original)) && ((_dafny.ZERO).isLessThanOrEqualTo(((t).dtor_post).dtor_remaining))) && ((_dafny.ZERO).isLessThanOrEqualTo(((t).dtor_intent).dtor_amount));
    };
    static TextExec(v) {
      return ((new BigNumber((v).length)).isLessThanOrEqualTo(SerModel.__default.MAX__TEXT)) && (SerModel.__default.Text(v));
    };
    static WfBodyExec(b) {
      return (((((((((((_dafny.areEqual((b).dtor_domain, SerModel.__default.DOMAIN)) && (SerModel.__default.Hex64((b).dtor_specLockSha256))) && (SerModel.__default.Hex64((b).dtor_checkerSha256))) && (SerModel.__default.Hex64((b).dtor_preStateSha256))) && (IssueBytes2.__default.TextExec((b).dtor_requestId))) && (IssueBytes2.__default.TextExec(((b).dtor_post).dtor_chargeId))) && (SerModel.__default.Money(((b).dtor_post).dtor_original))) && (SerModel.__default.Money(((b).dtor_post).dtor_remaining))) && (IssueBytes2.__default.TextExec(((b).dtor_intent).dtor_chargeId))) && (IssueBytes2.__default.TextExec(((b).dtor_intent).dtor_requestId))) && (SerModel.__default.Money(((b).dtor_intent).dtor_amount))) && (IssueBytes2.__default.TextExec(((b).dtor_intent).dtor_reason));
    };
    static Utf8Bytes(s) {
      let u = _dafny.Seq.of();
      u = _dafny.Seq.of();
      let _0_i;
      _0_i = _dafny.ZERO;
      while ((_0_i).isLessThan(new BigNumber((s).length))) {
        let _1_c;
        _1_c = SerModel.__default.Utf8Char((s)[_0_i]);
        let _2_cb;
        _2_cb = _dafny.Seq.Create(new BigNumber((_1_c).length), ((_3_c) => function (_4_k) {
          return ((_3_c)[_4_k]).toNumber();
        })(_1_c));
        u = _dafny.Seq.Concat(u, _2_cb);
        _0_i = (_0_i).plus(_dafny.ONE);
      }
      return u;
    }
    static IssueTokenBytes(pre, t, specHex, checkerHex, preHashHex) {
      let r = SerModel.Option.Default();
      let _0_verdict;
      let _1_plan;
      let _out0;
      let _out1;
      let _outcollector0 = RefundFinality.__default.Check(pre, preHashHex, t);
      _out0 = _outcollector0[0];
      _out1 = _outcollector0[1];
      _0_verdict = _out0;
      _1_plan = _out1;
      if (!((_0_verdict).is_Issue)) {
        r = SerModel.Option.create_None();
        return r;
      }
      let _2_tk;
      _2_tk = (_0_verdict).dtor_token;
      let _3_body;
      _3_body = SerModel.TokenBody.create_TokenBody(SerModel.__default.DOMAIN, specHex, checkerHex, (_2_tk).dtor_preStateHash, (_2_tk).dtor_requestId, IssueBytes2.__default.StateOf((_2_tk).dtor_post), IssueBytes2.__default.IntentOf((_2_tk).dtor_intent));
      if (!(IssueBytes2.__default.WfBodyExec(_3_body))) {
        r = SerModel.Option.create_None();
        return r;
      }
      let _4_bytes;
      let _out2;
      _out2 = IssueBytes2.__default.Utf8Bytes(SerModel.__default.SerBody(_3_body));
      _4_bytes = _out2;
      r = SerModel.Option.create_Some(_4_bytes);
      return r;
    }
    static T(pre, rq, amount) {
      let _pat_let_tv0 = pre;
      let _pat_let_tv1 = amount;
      return RefundFinality.Transition.create_Transition(RefundFinality.Request.create_Request(rq, amount, _dafny.Seq.UnicodeFromString("duplicate_charge")), function (_pat_let2_0) {
  return function (_0_dt__update__tmp_h0) {
    return function (_pat_let3_0) {
      return function (_1_dt__update_hremaining_h0) {
        return RefundFinality.Charge.create_Charge((_0_dt__update__tmp_h0).dtor_chargeId, (_0_dt__update__tmp_h0).dtor_original, _1_dt__update_hremaining_h0, (_0_dt__update__tmp_h0).dtor_refundEnabled);
      }(_pat_let3_0);
    }(((_pat_let_tv0).dtor_remaining).minus(_pat_let_tv1));
  }(_pat_let2_0);
}(pre), Refund.RefundIntent.create_Intent((pre).dtor_chargeId, rq, amount, _dafny.Seq.UnicodeFromString("duplicate_charge")));
    };
    static IssueWhen(pre, t, sh, ch, h) {
      let r = SerModel.Option.Default();
      let _out0;
      _out0 = IssueBytes2.__default.IssueTokenBytes(pre, t, sh, ch, h);
      r = _out0;
      return r;
    }
    static WitnessIssue() {
      let r = SerModel.Option.Default();
      let _out0;
      _out0 = IssueBytes2.__default.IssueWhen(IssueBytes2.__default.W__PRE, IssueBytes2.__default.T(IssueBytes2.__default.W__PRE, _dafny.Seq.UnicodeFromString("rq_1"), new BigNumber(40)), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      r = _out0;
      return r;
    }
    static WitnessZero() {
      let r = SerModel.Option.Default();
      let _out0;
      _out0 = IssueBytes2.__default.IssueWhen(IssueBytes2.__default.W__PRE, IssueBytes2.__default.T(IssueBytes2.__default.W__PRE, _dafny.Seq.UnicodeFromString("rq_0"), _dafny.ZERO), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      r = _out0;
      return r;
    }
    static WitnessUnauthorized() {
      let r = SerModel.Option.Default();
      let _out0;
      _out0 = IssueBytes2.__default.IssueTokenBytes(IssueBytes2.__default.W__PRE, IssueBytes2.__default.T(IssueBytes2.__default.W__PRE, _dafny.Seq.UnicodeFromString("rq_1"), new BigNumber(61)), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      r = _out0;
      return r;
    }
    static WitnessNul() {
      let r = SerModel.Option.Default();
      let _0_b;
      _0_b = IssueBytes2.__default.BodyFor(SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA, IssueBytes2.__default.T(IssueBytes2.__default.NUL__PRE, _dafny.Seq.UnicodeFromString("rq_1"), new BigNumber(40)));
      let _out0;
      _out0 = IssueBytes2.__default.IssueTokenBytes(IssueBytes2.__default.NUL__PRE, IssueBytes2.__default.T(IssueBytes2.__default.NUL__PRE, _dafny.Seq.UnicodeFromString("rq_1"), new BigNumber(40)), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      r = _out0;
      return r;
    }
    static get HEXA() {
      return _dafny.Seq.Create(new BigNumber(64), function (_0___v0) {
        return new _dafny.CodePoint('a'.codePointAt(0));
      });
    };
    static get W__PRE() {
      return RefundFinality.Charge.create_Charge(_dafny.Seq.UnicodeFromString("ch_1"), new BigNumber(100), new BigNumber(60), true);
    };
    static get NUL__PRE() {
      return RefundFinality.Charge.create_Charge(_dafny.Seq.Concat(_dafny.Seq.of(new _dafny.CodePoint((_dafny.ZERO).toNumber())), _dafny.Seq.UnicodeFromString("ch_1")), new BigNumber(100), new BigNumber(60), true);
    };
  };

  $module.uint8 = class uint8 {
    constructor () {
    }
    _parentTraits() {
      return [];
    }
    static *IntegerRange(lo, hi) {
      while (lo.isLessThan(hi)) {
        yield lo.toNumber();
        lo = lo.plus(1);
      }
    }
    static get Default() {
      return 0;
    }
    static _Is(__source) {
      let _0_x = new BigNumber(__source);
      return ((_dafny.ZERO).isLessThanOrEqualTo(_0_x)) && ((_0_x).isLessThan(new BigNumber(256)));
    }
  };
  return $module;
})(); // end of module IssueBytes2
let IssueAuth = (function() {
  let $module = {};

  $module.__default = class __default {
    constructor () {
      this._tname = "IssueAuth._default";
    }
    _parentTraits() {
      return [];
    }
    static KeyFor(a, pre, t, h) {
      if ((a).is_Store) {
        return IssueAuth.Key.create_Key((pre).dtor_chargeId, ((t).dtor_request).dtor_requestId, false, _dafny.Seq.UnicodeFromString(""));
      } else {
        return IssueAuth.Key.create_Key((pre).dtor_chargeId, ((t).dtor_request).dtor_requestId, true, h);
      }
    };
    static Admitted(a, pre) {
      return !((a).is_Store) || ((_dafny.areEqual((a).dtor_state, pre)) && (!((a).dtor_requestSettled)));
    };
    static Issue(m, a, pre, t, sh, ch, h) {
      let m2 = _dafny.Map.Empty;
      let o = IssueAuth.Outcome.Default();
      let _0_k;
      _0_k = IssueAuth.__default.KeyFor(a, pre, t, h);
      let _1_r;
      let _out0;
      _out0 = IssueBytes2.__default.IssueTokenBytes(pre, t, sh, ch, h);
      _1_r = _out0;
      if ((((_1_r).is_Some) && ((m).contains(_0_k))) && (((m).get(_0_k)).is_Signed)) {
        if (_dafny.areEqual(((m).get(_0_k)).dtor_bytes, (_1_r).dtor_value)) {
          let _rhs0 = m;
          let _rhs1 = IssueAuth.Outcome.create_Replayed(((m).get(_0_k)).dtor_bytes);
          m2 = _rhs0;
          o = _rhs1;
          return [m2, o];
        }
      }
      if (((a).is_Store) && (!_dafny.areEqual((a).dtor_state, pre))) {
        let _rhs2 = m;
        let _rhs3 = IssueAuth.Outcome.create_RefusedNotAuthoritative();
        m2 = _rhs2;
        o = _rhs3;
        return [m2, o];
      }
      if (((a).is_Store) && ((a).dtor_requestSettled)) {
        let _rhs4 = m;
        let _rhs5 = IssueAuth.Outcome.create_RefusedCompleted();
        m2 = _rhs4;
        o = _rhs5;
        return [m2, o];
      }
      if ((_1_r).is_None) {
        o = IssueAuth.Outcome.create_RefusedByCore();
        if ((m).contains(_0_k)) {
          m2 = m;
        } else {
          m2 = (m).update(_0_k, IssueAuth.Rec.create_Closed());
        }
        return [m2, o];
      }
      if ((m).contains(_0_k)) {
        if (((m).get(_0_k)).is_Closed) {
          let _rhs6 = m;
          let _rhs7 = IssueAuth.Outcome.create_RefusedClosed();
          m2 = _rhs6;
          o = _rhs7;
        } else {
          let _rhs8 = m;
          let _rhs9 = IssueAuth.Outcome.create_RefusedOtherCandidate();
          m2 = _rhs8;
          o = _rhs9;
        }
        return [m2, o];
      }
      let _rhs10 = (m).update(_0_k, IssueAuth.Rec.create_Signed((_1_r).dtor_value));
      let _rhs11 = IssueAuth.Outcome.create_Issued((_1_r).dtor_value);
      m2 = _rhs10;
      o = _rhs11;
      return [m2, o];
    }
    static KeyOfCall(c) {
      return IssueAuth.__default.KeyFor((c).dtor_a, (c).dtor_pre, (c).dtor_t, (c).dtor_h);
    };
    static RunSeq(m0, calls) {
      let m = _dafny.Map.Empty;
      let outs = _dafny.Seq.of();
      let _rhs0 = m0;
      let _rhs1 = _dafny.Seq.of();
      m = _rhs0;
      outs = _rhs1;
      while ((new BigNumber((outs).length)).isLessThan(new BigNumber((calls).length))) {
        let _0_c;
        _0_c = (calls)[new BigNumber((outs).length)];
        let _1_m2;
        let _2_o;
        let _out0;
        let _out1;
        let _outcollector0 = IssueAuth.__default.Issue(m, (_0_c).dtor_a, (_0_c).dtor_pre, (_0_c).dtor_t, (_0_c).dtor_sh, (_0_c).dtor_ch, (_0_c).dtor_h);
        _out0 = _outcollector0[0];
        _out1 = _outcollector0[1];
        _1_m2 = _out0;
        _2_o = _out1;
        let _rhs2 = _1_m2;
        let _rhs3 = _dafny.Seq.Concat(outs, _dafny.Seq.of(_2_o));
        m = _rhs2;
        outs = _rhs3;
      }
      return [m, outs];
    }
    static Live(m, state, t, sh, ch, h) {
      let m2 = _dafny.Map.Empty;
      let o = IssueAuth.Outcome.Default();
      let _out0;
      let _out1;
      let _outcollector0 = IssueAuth.__default.Issue(m, IssueAuth.Auth.create_Store(state, false), state, t, sh, ch, h);
      _out0 = _outcollector0[0];
      _out1 = _outcollector0[1];
      m2 = _out0;
      o = _out1;
      return [m2, o];
    }
    static SquatsThenVictim(m0, squats, v) {
      let outs = _dafny.Seq.of();
      let ov = IssueAuth.Outcome.Default();
      let _0_m;
      _0_m = m0;
      outs = _dafny.Seq.of();
      let _1_n;
      _1_n = _dafny.ZERO;
      while ((_1_n).isLessThan(new BigNumber((squats).length))) {
        let _2_s;
        _2_s = (squats)[_1_n];
        let _3_m2;
        let _4_o;
        let _out0;
        let _out1;
        let _outcollector0 = IssueAuth.__default.Issue(_0_m, (_2_s).dtor_a, (_2_s).dtor_pre, (_2_s).dtor_t, (_2_s).dtor_sh, (_2_s).dtor_ch, (_2_s).dtor_h);
        _out0 = _outcollector0[0];
        _out1 = _outcollector0[1];
        _3_m2 = _out0;
        _4_o = _out1;
        _0_m = _3_m2;
        outs = _dafny.Seq.Concat(outs, _dafny.Seq.of(_4_o));
        _1_n = (_1_n).plus(_dafny.ONE);
      }
      let _5_m3 = _dafny.Map.Empty;
      let _out2;
      let _out3;
      let _outcollector1 = IssueAuth.__default.Issue(_0_m, (v).dtor_a, (v).dtor_pre, (v).dtor_t, (v).dtor_sh, (v).dtor_ch, (v).dtor_h);
      _out2 = _outcollector1[0];
      _out3 = _outcollector1[1];
      _5_m3 = _out2;
      ov = _out3;
      return [outs, ov];
    }
    static NewKey(m, a, pre, t, sh, ch, h) {
      let m2 = _dafny.Map.Empty;
      let o = IssueAuth.Outcome.Default();
      let _out0;
      let _out1;
      let _outcollector0 = IssueAuth.__default.Issue(m, a, pre, t, sh, ch, h);
      _out0 = _outcollector0[0];
      _out1 = _outcollector0[1];
      m2 = _out0;
      o = _out1;
      return [m2, o];
    }
    static NotAdmitted(m, a, pre, t, sh, ch, h) {
      let m2 = _dafny.Map.Empty;
      let o = IssueAuth.Outcome.Default();
      let _out0;
      let _out1;
      let _outcollector0 = IssueAuth.__default.Issue(m, a, pre, t, sh, ch, h);
      _out0 = _outcollector0[0];
      _out1 = _outcollector0[1];
      m2 = _out0;
      o = _out1;
      return [m2, o];
    }
    static UsedKey(m, a, pre, t, sh, ch, h) {
      let m2 = _dafny.Map.Empty;
      let o = IssueAuth.Outcome.Default();
      let _out0;
      let _out1;
      let _outcollector0 = IssueAuth.__default.Issue(m, a, pre, t, sh, ch, h);
      _out0 = _outcollector0[0];
      _out1 = _outcollector0[1];
      m2 = _out0;
      o = _out1;
      return [m2, o];
    }
    static Replay(m, a, pre, t, sh, ch, h) {
      let m2 = _dafny.Map.Empty;
      let o = IssueAuth.Outcome.Default();
      let _out0;
      let _out1;
      let _outcollector0 = IssueAuth.__default.Issue(m, a, pre, t, sh, ch, h);
      _out0 = _outcollector0[0];
      _out1 = _outcollector0[1];
      m2 = _out0;
      o = _out1;
      return [m2, o];
    }
    static CoreRefused(m, a, pre, t, sh, ch, h) {
      let m2 = _dafny.Map.Empty;
      let o = IssueAuth.Outcome.Default();
      let _out0;
      let _out1;
      let _outcollector0 = IssueAuth.__default.Issue(m, a, pre, t, sh, ch, h);
      _out0 = _outcollector0[0];
      _out1 = _outcollector0[1];
      m2 = _out0;
      o = _out1;
      return [m2, o];
    }
    static WSquatStore() {
      let s = IssueAuth.Outcome.Default();
      let v = IssueAuth.Outcome.Default();
      let _0_m;
      _0_m = _dafny.Map.Empty.slice();
      let _1_a;
      _1_a = IssueAuth.Auth.create_Store(IssueAuth.__default.W__PRE, false);
      let _out0;
      let _out1;
      let _outcollector0 = IssueAuth.__default.NotAdmitted(_0_m, _1_a, IssueAuth.__default.W__FAKE, IssueBytes2.__default.T(IssueAuth.__default.W__FAKE, _dafny.Seq.UnicodeFromString("rq_v"), _dafny.ZERO), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueAuth.__default.HEXB);
      _out0 = _outcollector0[0];
      _out1 = _outcollector0[1];
      _0_m = _out0;
      s = _out1;
      let _out2;
      let _out3;
      let _outcollector1 = IssueAuth.__default.NewKey(_0_m, _1_a, IssueAuth.__default.W__PRE, IssueBytes2.__default.T(IssueAuth.__default.W__PRE, _dafny.Seq.UnicodeFromString("rq_v"), new BigNumber(40)), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      _out2 = _outcollector1[0];
      _out3 = _outcollector1[1];
      _0_m = _out2;
      v = _out3;
      return [s, v];
    }
    static WSquatNoStore() {
      let s = IssueAuth.Outcome.Default();
      let v = IssueAuth.Outcome.Default();
      let _0_m;
      _0_m = _dafny.Map.Empty.slice();
      let _out0;
      let _out1;
      let _outcollector0 = IssueAuth.__default.NewKey(_0_m, IssueAuth.Auth.create_NoStore(), IssueAuth.__default.W__FAKE, IssueBytes2.__default.T(IssueAuth.__default.W__FAKE, _dafny.Seq.UnicodeFromString("rq_v"), _dafny.ZERO), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueAuth.__default.HEXB);
      _out0 = _outcollector0[0];
      _out1 = _outcollector0[1];
      _0_m = _out0;
      s = _out1;
      let _out2;
      let _out3;
      let _outcollector1 = IssueAuth.__default.NewKey(_0_m, IssueAuth.Auth.create_NoStore(), IssueAuth.__default.W__PRE, IssueBytes2.__default.T(IssueAuth.__default.W__PRE, _dafny.Seq.UnicodeFromString("rq_v"), new BigNumber(40)), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      _out2 = _outcollector1[0];
      _out3 = _outcollector1[1];
      _0_m = _out2;
      v = _out3;
      return [s, v];
    }
    static WZeroZeroPositive() {
      let a = IssueAuth.Outcome.Default();
      let b = IssueAuth.Outcome.Default();
      let c = IssueAuth.Outcome.Default();
      let _0_m;
      _0_m = _dafny.Map.Empty.slice();
      let _1_st;
      _1_st = IssueAuth.Auth.create_Store(IssueAuth.__default.W__PRE, false);
      let _out0;
      let _out1;
      let _outcollector0 = IssueAuth.__default.NewKey(_0_m, _1_st, IssueAuth.__default.W__PRE, IssueBytes2.__default.T(IssueAuth.__default.W__PRE, _dafny.Seq.UnicodeFromString("rz_1"), _dafny.ZERO), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      _out0 = _outcollector0[0];
      _out1 = _outcollector0[1];
      _0_m = _out0;
      a = _out1;
      let _out2;
      let _out3;
      let _outcollector1 = IssueAuth.__default.NewKey(_0_m, _1_st, IssueAuth.__default.W__PRE, IssueBytes2.__default.T(IssueAuth.__default.W__PRE, _dafny.Seq.UnicodeFromString("rz_2"), _dafny.ZERO), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      _out2 = _outcollector1[0];
      _out3 = _outcollector1[1];
      _0_m = _out2;
      b = _out3;
      let _out4;
      let _out5;
      let _outcollector2 = IssueAuth.__default.NewKey(_0_m, _1_st, IssueAuth.__default.W__PRE, IssueBytes2.__default.T(IssueAuth.__default.W__PRE, _dafny.Seq.UnicodeFromString("rp_1"), new BigNumber(40)), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      _out4 = _outcollector2[0];
      _out5 = _outcollector2[1];
      _0_m = _out4;
      c = _out5;
      return [a, b, c];
    }
    static WRetry() {
      let a = IssueAuth.Outcome.Default();
      let a2 = IssueAuth.Outcome.Default();
      let b = IssueAuth.Outcome.Default();
      let b2 = IssueAuth.Outcome.Default();
      let _0_t;
      _0_t = IssueBytes2.__default.T(IssueAuth.__default.W__PRE, _dafny.Seq.UnicodeFromString("rq_r"), _dafny.ZERO);
      let _1_m;
      _1_m = _dafny.Map.Empty.slice();
      let _out0;
      let _out1;
      let _outcollector0 = IssueAuth.__default.NewKey(_1_m, IssueAuth.Auth.create_Store(IssueAuth.__default.W__PRE, false), IssueAuth.__default.W__PRE, _0_t, SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      _out0 = _outcollector0[0];
      _out1 = _outcollector0[1];
      _1_m = _out0;
      a = _out1;
      let _out2;
      let _out3;
      let _outcollector1 = IssueAuth.__default.UsedKey(_1_m, IssueAuth.Auth.create_Store(IssueAuth.__default.W__PRE, false), IssueAuth.__default.W__PRE, _0_t, SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      _out2 = _outcollector1[0];
      _out3 = _outcollector1[1];
      _1_m = _out2;
      a2 = _out3;
      let _2_n;
      _2_n = _dafny.Map.Empty.slice();
      let _out4;
      let _out5;
      let _outcollector2 = IssueAuth.__default.NewKey(_2_n, IssueAuth.Auth.create_NoStore(), IssueAuth.__default.W__PRE, _0_t, SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      _out4 = _outcollector2[0];
      _out5 = _outcollector2[1];
      _2_n = _out4;
      b = _out5;
      let _out6;
      let _out7;
      let _outcollector3 = IssueAuth.__default.UsedKey(_2_n, IssueAuth.Auth.create_NoStore(), IssueAuth.__default.W__PRE, _0_t, SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      _out6 = _outcollector3[0];
      _out7 = _outcollector3[1];
      _2_n = _out6;
      b2 = _out7;
      return [a, a2, b, b2];
    }
    static WStaleRetry() {
      let a = IssueAuth.Outcome.Default();
      let b = IssueAuth.Outcome.Default();
      let c = IssueAuth.Outcome.Default();
      let _0_b0;
      _0_b0 = IssueBytes2.__default.BodyFor(SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA, IssueBytes2.__default.T(IssueAuth.__default.W__PRE, _dafny.Seq.UnicodeFromString("rq_1"), new BigNumber(40)));
      let _1_b1;
      _1_b1 = IssueBytes2.__default.BodyFor(SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueAuth.__default.HEXB, IssueBytes2.__default.T(IssueAuth.__default.W__NEXT, _dafny.Seq.UnicodeFromString("rq_1"), new BigNumber(40)));
      let _2_m;
      _2_m = _dafny.Map.Empty.slice();
      let _out0;
      let _out1;
      let _outcollector0 = IssueAuth.__default.NewKey(_2_m, IssueAuth.Auth.create_Store(IssueAuth.__default.W__PRE, false), IssueAuth.__default.W__PRE, IssueBytes2.__default.T(IssueAuth.__default.W__PRE, _dafny.Seq.UnicodeFromString("rq_1"), new BigNumber(40)), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      _out0 = _outcollector0[0];
      _out1 = _outcollector0[1];
      _2_m = _out0;
      a = _out1;
      let _out2;
      let _out3;
      let _outcollector1 = IssueAuth.__default.UsedKey(_2_m, IssueAuth.Auth.create_Store(IssueAuth.__default.W__NEXT, false), IssueAuth.__default.W__NEXT, IssueBytes2.__default.T(IssueAuth.__default.W__NEXT, _dafny.Seq.UnicodeFromString("rq_1"), new BigNumber(40)), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueAuth.__default.HEXB);
      _out2 = _outcollector1[0];
      _out3 = _outcollector1[1];
      _2_m = _out2;
      b = _out3;
      let _out4;
      let _out5;
      let _outcollector2 = IssueAuth.__default.NewKey(_2_m, IssueAuth.Auth.create_Store(IssueAuth.__default.W__NEXT, false), IssueAuth.__default.W__NEXT, IssueBytes2.__default.T(IssueAuth.__default.W__NEXT, _dafny.Seq.UnicodeFromString("rq_1b"), new BigNumber(40)), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueAuth.__default.HEXB);
      _out4 = _outcollector2[0];
      _out5 = _outcollector2[1];
      _2_m = _out4;
      c = _out5;
      return [a, b, c];
    }
    static WClosed() {
      let a = IssueAuth.Outcome.Default();
      let b = IssueAuth.Outcome.Default();
      let c = IssueAuth.Outcome.Default();
      let _0_m;
      _0_m = _dafny.Map.Empty.slice();
      let _1_st;
      _1_st = IssueAuth.Auth.create_Store(IssueAuth.__default.W__PRE, false);
      let _out0;
      let _out1;
      let _outcollector0 = IssueAuth.__default.CoreRefused(_0_m, _1_st, IssueAuth.__default.W__PRE, IssueBytes2.__default.T(IssueAuth.__default.W__PRE, _dafny.Seq.UnicodeFromString("rq_c"), new BigNumber(61)), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      _out0 = _outcollector0[0];
      _out1 = _outcollector0[1];
      _0_m = _out0;
      a = _out1;
      let _out2;
      let _out3;
      let _outcollector1 = IssueAuth.__default.UsedKey(_0_m, _1_st, IssueAuth.__default.W__PRE, IssueBytes2.__default.T(IssueAuth.__default.W__PRE, _dafny.Seq.UnicodeFromString("rq_c"), new BigNumber(40)), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      _out2 = _outcollector1[0];
      _out3 = _outcollector1[1];
      _0_m = _out2;
      b = _out3;
      let _out4;
      let _out5;
      let _outcollector2 = IssueAuth.__default.NewKey(_0_m, _1_st, IssueAuth.__default.W__PRE, IssueBytes2.__default.T(IssueAuth.__default.W__PRE, _dafny.Seq.UnicodeFromString("rq_d"), new BigNumber(40)), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      _out4 = _outcollector2[0];
      _out5 = _outcollector2[1];
      _0_m = _out4;
      c = _out5;
      return [a, b, c];
    }
    static WRetryAfterMove() {
      let a = IssueAuth.Outcome.Default();
      let a2 = IssueAuth.Outcome.Default();
      let b = IssueAuth.Outcome.Default();
      let _0_t;
      _0_t = IssueBytes2.__default.T(IssueAuth.__default.W__PRE, _dafny.Seq.UnicodeFromString("rq_m"), new BigNumber(10));
      let _1_m;
      _1_m = _dafny.Map.Empty.slice();
      let _out0;
      let _out1;
      let _outcollector0 = IssueAuth.__default.NewKey(_1_m, IssueAuth.Auth.create_Store(IssueAuth.__default.W__PRE, false), IssueAuth.__default.W__PRE, _0_t, SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      _out0 = _outcollector0[0];
      _out1 = _outcollector0[1];
      _1_m = _out0;
      a = _out1;
      let _out2;
      let _out3;
      let _outcollector1 = IssueAuth.__default.Replay(_1_m, IssueAuth.Auth.create_Store(IssueAuth.__default.W__NEXT, true), IssueAuth.__default.W__PRE, _0_t, SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      _out2 = _outcollector1[0];
      _out3 = _outcollector1[1];
      _1_m = _out2;
      a2 = _out3;
      let _2_t2;
      _2_t2 = IssueBytes2.__default.T(IssueAuth.__default.W__NEXT, _dafny.Seq.UnicodeFromString("rq_m"), new BigNumber(5));
      let _3_b0;
      _3_b0 = IssueBytes2.__default.BodyFor(SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA, _0_t);
      let _4_b1;
      _4_b1 = IssueBytes2.__default.BodyFor(SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueAuth.__default.HEXB, _2_t2);
      let _out4;
      let _out5;
      let _outcollector2 = IssueAuth.__default.Issue(_1_m, IssueAuth.Auth.create_Store(IssueAuth.__default.W__NEXT, true), IssueAuth.__default.W__NEXT, _2_t2, SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueAuth.__default.HEXB);
      _out4 = _outcollector2[0];
      _out5 = _outcollector2[1];
      _1_m = _out4;
      b = _out5;
      return [a, a2, b];
    }
    static WCompleted() {
      let o = IssueAuth.Outcome.Default();
      let m2 = _dafny.Map.Empty;
      let _out0;
      let _out1;
      let _outcollector0 = IssueAuth.__default.NotAdmitted(_dafny.Map.Empty.slice(), IssueAuth.Auth.create_Store(IssueAuth.__default.W__PRE, true), IssueAuth.__default.W__PRE, IssueBytes2.__default.T(IssueAuth.__default.W__PRE, _dafny.Seq.UnicodeFromString("rq_s"), _dafny.ZERO), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      _out0 = _outcollector0[0];
      _out1 = _outcollector0[1];
      m2 = _out0;
      o = _out1;
      return [o, m2];
    }
    static WSquatRealState() {
      let s = IssueAuth.Outcome.Default();
      let v = IssueAuth.Outcome.Default();
      let _0_b0;
      _0_b0 = IssueBytes2.__default.BodyFor(SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA, IssueBytes2.__default.T(IssueAuth.__default.W__PRE, _dafny.Seq.UnicodeFromString("rq_v"), _dafny.ZERO));
      let _1_b1;
      _1_b1 = IssueBytes2.__default.BodyFor(SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA, IssueBytes2.__default.T(IssueAuth.__default.W__PRE, _dafny.Seq.UnicodeFromString("rq_v"), new BigNumber(40)));
      let _2_m;
      _2_m = _dafny.Map.Empty.slice();
      let _3_st;
      _3_st = IssueAuth.Auth.create_Store(IssueAuth.__default.W__PRE, false);
      let _out0;
      let _out1;
      let _outcollector0 = IssueAuth.__default.NewKey(_2_m, _3_st, IssueAuth.__default.W__PRE, IssueBytes2.__default.T(IssueAuth.__default.W__PRE, _dafny.Seq.UnicodeFromString("rq_v"), _dafny.ZERO), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      _out0 = _outcollector0[0];
      _out1 = _outcollector0[1];
      _2_m = _out0;
      s = _out1;
      let _out2;
      let _out3;
      let _outcollector1 = IssueAuth.__default.UsedKey(_2_m, _3_st, IssueAuth.__default.W__PRE, IssueBytes2.__default.T(IssueAuth.__default.W__PRE, _dafny.Seq.UnicodeFromString("rq_v"), new BigNumber(40)), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA);
      _out2 = _outcollector1[0];
      _out3 = _outcollector1[1];
      _2_m = _out2;
      v = _out3;
      return [s, v];
    }
    static WRunSeq() {
      let outs = _dafny.Seq.of();
      let _0_calls;
      _0_calls = _dafny.Seq.of(IssueAuth.Call.create_Call(IssueAuth.Auth.create_Store(IssueAuth.__default.W__PRE, false), IssueAuth.__default.W__FAKE, IssueBytes2.__default.T(IssueAuth.__default.W__FAKE, _dafny.Seq.UnicodeFromString("rq_w"), _dafny.ZERO), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueAuth.__default.HEXB), IssueAuth.Call.create_Call(IssueAuth.Auth.create_Store(IssueAuth.__default.W__PRE, false), IssueAuth.__default.W__PRE, IssueBytes2.__default.T(IssueAuth.__default.W__PRE, _dafny.Seq.UnicodeFromString("rq_w"), new BigNumber(40)), SerModel.__default.ZERO64, SerModel.__default.ZERO64, IssueBytes2.__default.HEXA));
      let _1_m = _dafny.Map.Empty;
      let _out0;
      let _out1;
      let _outcollector0 = IssueAuth.__default.RunSeq(_dafny.Map.Empty.slice(), _0_calls);
      _out0 = _outcollector0[0];
      _out1 = _outcollector0[1];
      _1_m = _out0;
      outs = _out1;
      return outs;
    }
    static get HEXB() {
      return _dafny.Seq.Create(new BigNumber(64), function (_0___v0) {
        return new _dafny.CodePoint('b'.codePointAt(0));
      });
    };
    static get W__PRE() {
      return IssueBytes2.__default.W__PRE;
    };
    static get W__FAKE() {
      return RefundFinality.Charge.create_Charge(_dafny.Seq.UnicodeFromString("ch_1"), new BigNumber(5), new BigNumber(5), true);
    };
    static get W__NEXT() {
      return RefundFinality.Charge.create_Charge(_dafny.Seq.UnicodeFromString("ch_1"), new BigNumber(100), new BigNumber(50), true);
    };
  };

  $module.Key = class Key {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Key(chargeId, requestId, scoped, scope) {
      let $dt = new Key(0);
      $dt.chargeId = chargeId;
      $dt.requestId = requestId;
      $dt.scoped = scoped;
      $dt.scope = scope;
      return $dt;
    }
    get is_Key() { return this.$tag === 0; }
    get dtor_chargeId() { return this.chargeId; }
    get dtor_requestId() { return this.requestId; }
    get dtor_scoped() { return this.scoped; }
    get dtor_scope() { return this.scope; }
    toString() {
      if (this.$tag === 0) {
        return "IssueAuth.Key.Key" + "(" + this.chargeId.toVerbatimString(true) + ", " + this.requestId.toVerbatimString(true) + ", " + _dafny.toString(this.scoped) + ", " + this.scope.toVerbatimString(true) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.chargeId, other.chargeId) && _dafny.areEqual(this.requestId, other.requestId) && this.scoped === other.scoped && _dafny.areEqual(this.scope, other.scope);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return IssueAuth.Key.create_Key(_dafny.Seq.UnicodeFromString(""), _dafny.Seq.UnicodeFromString(""), false, _dafny.Seq.UnicodeFromString(""));
    }
    static Rtd() {
      return class {
        static get Default() {
          return Key.Default();
        }
      };
    }
  }

  $module.Rec = class Rec {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Signed(bytes) {
      let $dt = new Rec(0);
      $dt.bytes = bytes;
      return $dt;
    }
    static create_Closed() {
      let $dt = new Rec(1);
      return $dt;
    }
    get is_Signed() { return this.$tag === 0; }
    get is_Closed() { return this.$tag === 1; }
    get dtor_bytes() { return this.bytes; }
    toString() {
      if (this.$tag === 0) {
        return "IssueAuth.Rec.Signed" + "(" + _dafny.toString(this.bytes) + ")";
      } else if (this.$tag === 1) {
        return "IssueAuth.Rec.Closed";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.bytes, other.bytes);
      } else if (this.$tag === 1) {
        return other.$tag === 1;
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return IssueAuth.Rec.create_Signed(_dafny.Seq.of());
    }
    static Rtd() {
      return class {
        static get Default() {
          return Rec.Default();
        }
      };
    }
  }

  $module.Auth = class Auth {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_NoStore() {
      let $dt = new Auth(0);
      return $dt;
    }
    static create_Store(state, requestSettled) {
      let $dt = new Auth(1);
      $dt.state = state;
      $dt.requestSettled = requestSettled;
      return $dt;
    }
    get is_NoStore() { return this.$tag === 0; }
    get is_Store() { return this.$tag === 1; }
    get dtor_state() { return this.state; }
    get dtor_requestSettled() { return this.requestSettled; }
    toString() {
      if (this.$tag === 0) {
        return "IssueAuth.Auth.NoStore";
      } else if (this.$tag === 1) {
        return "IssueAuth.Auth.Store" + "(" + _dafny.toString(this.state) + ", " + _dafny.toString(this.requestSettled) + ")";
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
        return other.$tag === 1 && _dafny.areEqual(this.state, other.state) && this.requestSettled === other.requestSettled;
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return IssueAuth.Auth.create_NoStore();
    }
    static Rtd() {
      return class {
        static get Default() {
          return Auth.Default();
        }
      };
    }
  }

  $module.Outcome = class Outcome {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Issued(bytes) {
      let $dt = new Outcome(0);
      $dt.bytes = bytes;
      return $dt;
    }
    static create_Replayed(bytes) {
      let $dt = new Outcome(1);
      $dt.bytes = bytes;
      return $dt;
    }
    static create_RefusedByCore() {
      let $dt = new Outcome(2);
      return $dt;
    }
    static create_RefusedOtherCandidate() {
      let $dt = new Outcome(3);
      return $dt;
    }
    static create_RefusedClosed() {
      let $dt = new Outcome(4);
      return $dt;
    }
    static create_RefusedNotAuthoritative() {
      let $dt = new Outcome(5);
      return $dt;
    }
    static create_RefusedCompleted() {
      let $dt = new Outcome(6);
      return $dt;
    }
    get is_Issued() { return this.$tag === 0; }
    get is_Replayed() { return this.$tag === 1; }
    get is_RefusedByCore() { return this.$tag === 2; }
    get is_RefusedOtherCandidate() { return this.$tag === 3; }
    get is_RefusedClosed() { return this.$tag === 4; }
    get is_RefusedNotAuthoritative() { return this.$tag === 5; }
    get is_RefusedCompleted() { return this.$tag === 6; }
    get dtor_bytes() { return this.bytes; }
    toString() {
      if (this.$tag === 0) {
        return "IssueAuth.Outcome.Issued" + "(" + _dafny.toString(this.bytes) + ")";
      } else if (this.$tag === 1) {
        return "IssueAuth.Outcome.Replayed" + "(" + _dafny.toString(this.bytes) + ")";
      } else if (this.$tag === 2) {
        return "IssueAuth.Outcome.RefusedByCore";
      } else if (this.$tag === 3) {
        return "IssueAuth.Outcome.RefusedOtherCandidate";
      } else if (this.$tag === 4) {
        return "IssueAuth.Outcome.RefusedClosed";
      } else if (this.$tag === 5) {
        return "IssueAuth.Outcome.RefusedNotAuthoritative";
      } else if (this.$tag === 6) {
        return "IssueAuth.Outcome.RefusedCompleted";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.bytes, other.bytes);
      } else if (this.$tag === 1) {
        return other.$tag === 1 && _dafny.areEqual(this.bytes, other.bytes);
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
      return IssueAuth.Outcome.create_Issued(_dafny.Seq.of());
    }
    static Rtd() {
      return class {
        static get Default() {
          return Outcome.Default();
        }
      };
    }
    Signs() {
      let _this = this;
      return ((_this).is_Issued) || ((_this).is_Replayed);
    };
  }

  $module.Call = class Call {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Call(a, pre, t, sh, ch, h) {
      let $dt = new Call(0);
      $dt.a = a;
      $dt.pre = pre;
      $dt.t = t;
      $dt.sh = sh;
      $dt.ch = ch;
      $dt.h = h;
      return $dt;
    }
    get is_Call() { return this.$tag === 0; }
    get dtor_a() { return this.a; }
    get dtor_pre() { return this.pre; }
    get dtor_t() { return this.t; }
    get dtor_sh() { return this.sh; }
    get dtor_ch() { return this.ch; }
    get dtor_h() { return this.h; }
    toString() {
      if (this.$tag === 0) {
        return "IssueAuth.Call.Call" + "(" + _dafny.toString(this.a) + ", " + _dafny.toString(this.pre) + ", " + _dafny.toString(this.t) + ", " + this.sh.toVerbatimString(true) + ", " + this.ch.toVerbatimString(true) + ", " + this.h.toVerbatimString(true) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.a, other.a) && _dafny.areEqual(this.pre, other.pre) && _dafny.areEqual(this.t, other.t) && _dafny.areEqual(this.sh, other.sh) && _dafny.areEqual(this.ch, other.ch) && _dafny.areEqual(this.h, other.h);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return IssueAuth.Call.create_Call(IssueAuth.Auth.Default(), RefundFinality.Charge.Default(), RefundFinality.Transition.Default(), _dafny.Seq.UnicodeFromString(""), _dafny.Seq.UnicodeFromString(""), _dafny.Seq.UnicodeFromString(""));
    }
    static Rtd() {
      return class {
        static get Default() {
          return Call.Default();
        }
      };
    }
  }
  return $module;
})(); // end of module IssueAuth
let _module = (function() {
  let $module = {};

  return $module;
})(); // end of module _module

module.exports = { IssueAuth, IssueBytes2, RefundFinality, Refund, SerModel, runtime: _dafny };

// another build of the same core

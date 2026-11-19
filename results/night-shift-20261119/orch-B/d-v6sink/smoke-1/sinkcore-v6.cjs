// Dafny program ShellCoreV6.dfy compiled into JavaScript
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
let ShellCoreV3 = (function() {
  let $module = {};

  $module.__default = class __default {
    constructor () {
      this._tname = "ShellCoreV3._default";
    }
    _parentTraits() {
      return [];
    }
    static Full(t, pre) {
      return SinkCoreV3.SinkToken.create_SinkToken((t).dtor_specId, (t).dtor_checkerId, pre, (t).dtor_requestId, (t).dtor_post, (t).dtor_intent, (t).dtor_sig);
    };
    static ChargeOkP(stored, t) {
      return (_dafny.areEqual((stored).dtor_chargeId, ((t).dtor_intent).dtor_chargeId)) && (_dafny.areEqual(((t).dtor_post).dtor_chargeId, ((t).dtor_intent).dtor_chargeId));
    };
    static StepP(core, t, sigOk, preOk) {
      if ((!((t).dtor_specId).isEqualTo(SinkCoreV3.__default.PINNED__SPEC)) || (!((t).dtor_checkerId).isEqualTo(SinkCoreV3.__default.PINNED__CHK))) {
        return SinkCoreV3.StepResult.create_StepResult(core, SinkCoreV3.Outcome.create_Rejected(SinkCoreV3.Why.create_IdsNotPinned()));
      } else if (!(sigOk)) {
        return SinkCoreV3.StepResult.create_StepResult(core, SinkCoreV3.Outcome.create_Rejected(SinkCoreV3.Why.create_SignatureInvalid()));
      } else if (!_dafny.areEqual(((t).dtor_intent).dtor_requestId, (t).dtor_requestId)) {
        return SinkCoreV3.StepResult.create_StepResult(core, SinkCoreV3.Outcome.create_Rejected(SinkCoreV3.Why.create_ReqIdMismatch()));
      } else if (((core).dtor_settled).contains((t).dtor_requestId)) {
        return SinkCoreV3.StepResult.create_StepResult(core, SinkCoreV3.Outcome.create_Rejected(SinkCoreV3.Why.create_RequestSettled()));
      } else if (!(preOk)) {
        return SinkCoreV3.StepResult.create_StepResult(core, SinkCoreV3.Outcome.create_Rejected(SinkCoreV3.Why.create_PreStateMismatch()));
      } else if (!(ShellCoreV3.__default.ChargeOkP((core).dtor_charge, t))) {
        return SinkCoreV3.StepResult.create_StepResult(core, SinkCoreV3.Outcome.create_Rejected(SinkCoreV3.Why.create_ChargeIdMismatch()));
      } else {
        return SinkCoreV3.StepResult.create_StepResult(SinkCoreV3.Core.create_Core((t).dtor_post, ((core).dtor_settled).Union(_dafny.Set.fromElements((t).dtor_requestId)), _dafny.Seq.Concat((core).dtor_outbox, _dafny.Seq.of((t).dtor_intent))), SinkCoreV3.Outcome.create_Committed());
      }
    };
    static AuditStart(core) {
      return SinkCoreV3.__default.AuditStart(core);
    };
  };

  $module.ShellToken = class ShellToken {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_ShellToken(specId, checkerId, requestId, post, intent, sig) {
      let $dt = new ShellToken(0);
      $dt.specId = specId;
      $dt.checkerId = checkerId;
      $dt.requestId = requestId;
      $dt.post = post;
      $dt.intent = intent;
      $dt.sig = sig;
      return $dt;
    }
    get is_ShellToken() { return this.$tag === 0; }
    get dtor_specId() { return this.specId; }
    get dtor_checkerId() { return this.checkerId; }
    get dtor_requestId() { return this.requestId; }
    get dtor_post() { return this.post; }
    get dtor_intent() { return this.intent; }
    get dtor_sig() { return this.sig; }
    toString() {
      if (this.$tag === 0) {
        return "ShellCoreV3.ShellToken.ShellToken" + "(" + _dafny.toString(this.specId) + ", " + _dafny.toString(this.checkerId) + ", " + this.requestId.toVerbatimString(true) + ", " + _dafny.toString(this.post) + ", " + _dafny.toString(this.intent) + ", " + this.sig.toVerbatimString(true) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.specId, other.specId) && _dafny.areEqual(this.checkerId, other.checkerId) && _dafny.areEqual(this.requestId, other.requestId) && _dafny.areEqual(this.post, other.post) && _dafny.areEqual(this.intent, other.intent) && _dafny.areEqual(this.sig, other.sig);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return ShellCoreV3.ShellToken.create_ShellToken(_dafny.ZERO, _dafny.ZERO, _dafny.Seq.UnicodeFromString(""), RefundFinality.Charge.Default(), Refund.RefundIntent.Default(), _dafny.Seq.UnicodeFromString(""));
    }
    static Rtd() {
      return class {
        static get Default() {
          return ShellToken.Default();
        }
      };
    }
  }
  return $module;
})(); // end of module ShellCoreV3
let ShellCoreV4 = (function() {
  let $module = {};

  $module.__default = class __default {
    constructor () {
      this._tname = "ShellCoreV4._default";
    }
    _parentTraits() {
      return [];
    }
    static StepQ(charge, t, sigOk, preOk, alreadySettled) {
      if ((!((t).dtor_specId).isEqualTo(SinkCoreV3.__default.PINNED__SPEC)) || (!((t).dtor_checkerId).isEqualTo(SinkCoreV3.__default.PINNED__CHK))) {
        return ShellCoreV4.StepResultQ.create_Reject(SinkCoreV3.Why.create_IdsNotPinned());
      } else if (!(sigOk)) {
        return ShellCoreV4.StepResultQ.create_Reject(SinkCoreV3.Why.create_SignatureInvalid());
      } else if (!_dafny.areEqual(((t).dtor_intent).dtor_requestId, (t).dtor_requestId)) {
        return ShellCoreV4.StepResultQ.create_Reject(SinkCoreV3.Why.create_ReqIdMismatch());
      } else if (alreadySettled) {
        return ShellCoreV4.StepResultQ.create_Reject(SinkCoreV3.Why.create_RequestSettled());
      } else if (!(preOk)) {
        return ShellCoreV4.StepResultQ.create_Reject(SinkCoreV3.Why.create_PreStateMismatch());
      } else if (!(ShellCoreV3.__default.ChargeOkP(charge, t))) {
        return ShellCoreV4.StepResultQ.create_Reject(SinkCoreV3.Why.create_ChargeIdMismatch());
      } else {
        return ShellCoreV4.StepResultQ.create_Commit((t).dtor_post, (t).dtor_requestId, (t).dtor_intent);
      }
    };
    static Apply(core, q) {
      let _source0 = q;
      {
        if (_source0.is_Commit) {
          let _0_nc = (_source0).newCharge;
          let _1_rid = (_source0).addId;
          let _2_i = (_source0).intent;
          return SinkCoreV3.StepResult.create_StepResult(SinkCoreV3.Core.create_Core(_0_nc, ((core).dtor_settled).Union(_dafny.Set.fromElements(_1_rid)), _dafny.Seq.Concat((core).dtor_outbox, _dafny.Seq.of(_2_i))), SinkCoreV3.Outcome.create_Committed());
        }
      }
      {
        let _3_w = (_source0).why;
        return SinkCoreV3.StepResult.create_StepResult(core, SinkCoreV3.Outcome.create_Rejected(_3_w));
      }
    };
    static AInit() {
      return ShellCoreV4.AState.create_AState(true, _dafny.ZERO);
    };
    static AuditStep(cid, st, row) {
      return ShellCoreV4.AState.create_AState((((st).dtor_ok) && ((row).dtor_hit)) && (_dafny.areEqual(((row).dtor_intent).dtor_chargeId, cid)), ((st).dtor_count).plus(_dafny.ONE));
    };
    static AuditEnd(charge, initId, st, nSettled, outboxDistinct) {
      return ((((st).dtor_ok) && (((st).dtor_count).isEqualTo(nSettled))) && (outboxDistinct)) && (_dafny.areEqual((charge).dtor_chargeId, initId));
    };
    static AuditStartBound(core, initId) {
      return (SinkCoreV3.__default.AuditStart(core)) && (_dafny.areEqual(((core).dtor_charge).dtor_chargeId, initId));
    };
  };

  $module.StepResultQ = class StepResultQ {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Commit(newCharge, addId, intent) {
      let $dt = new StepResultQ(0);
      $dt.newCharge = newCharge;
      $dt.addId = addId;
      $dt.intent = intent;
      return $dt;
    }
    static create_Reject(why) {
      let $dt = new StepResultQ(1);
      $dt.why = why;
      return $dt;
    }
    get is_Commit() { return this.$tag === 0; }
    get is_Reject() { return this.$tag === 1; }
    get dtor_newCharge() { return this.newCharge; }
    get dtor_addId() { return this.addId; }
    get dtor_intent() { return this.intent; }
    get dtor_why() { return this.why; }
    toString() {
      if (this.$tag === 0) {
        return "ShellCoreV4.StepResultQ.Commit" + "(" + _dafny.toString(this.newCharge) + ", " + this.addId.toVerbatimString(true) + ", " + _dafny.toString(this.intent) + ")";
      } else if (this.$tag === 1) {
        return "ShellCoreV4.StepResultQ.Reject" + "(" + _dafny.toString(this.why) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.newCharge, other.newCharge) && _dafny.areEqual(this.addId, other.addId) && _dafny.areEqual(this.intent, other.intent);
      } else if (this.$tag === 1) {
        return other.$tag === 1 && _dafny.areEqual(this.why, other.why);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return ShellCoreV4.StepResultQ.create_Commit(RefundFinality.Charge.Default(), _dafny.Seq.UnicodeFromString(""), Refund.RefundIntent.Default());
    }
    static Rtd() {
      return class {
        static get Default() {
          return StepResultQ.Default();
        }
      };
    }
  }

  $module.ARow = class ARow {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_ARow(intent, hit) {
      let $dt = new ARow(0);
      $dt.intent = intent;
      $dt.hit = hit;
      return $dt;
    }
    get is_ARow() { return this.$tag === 0; }
    get dtor_intent() { return this.intent; }
    get dtor_hit() { return this.hit; }
    toString() {
      if (this.$tag === 0) {
        return "ShellCoreV4.ARow.ARow" + "(" + _dafny.toString(this.intent) + ", " + _dafny.toString(this.hit) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.intent, other.intent) && this.hit === other.hit;
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return ShellCoreV4.ARow.create_ARow(Refund.RefundIntent.Default(), false);
    }
    static Rtd() {
      return class {
        static get Default() {
          return ARow.Default();
        }
      };
    }
  }

  $module.AState = class AState {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_AState(ok, count) {
      let $dt = new AState(0);
      $dt.ok = ok;
      $dt.count = count;
      return $dt;
    }
    get is_AState() { return this.$tag === 0; }
    get dtor_ok() { return this.ok; }
    get dtor_count() { return this.count; }
    toString() {
      if (this.$tag === 0) {
        return "ShellCoreV4.AState.AState" + "(" + _dafny.toString(this.ok) + ", " + _dafny.toString(this.count) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && this.ok === other.ok && _dafny.areEqual(this.count, other.count);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return ShellCoreV4.AState.create_AState(false, _dafny.ZERO);
    }
    static Rtd() {
      return class {
        static get Default() {
          return AState.Default();
        }
      };
    }
  }
  return $module;
})(); // end of module ShellCoreV4
let ShellCoreV5 = (function() {
  let $module = {};

  $module.__default = class __default {
    constructor () {
      this._tname = "ShellCoreV5._default";
    }
    _parentTraits() {
      return [];
    }
    static TransOf(t) {
      return RefundFinality.Transition.create_Transition(RefundFinality.Request.create_Request((t).dtor_requestId, ((t).dtor_intent).dtor_amount, ((t).dtor_intent).dtor_reason), (t).dtor_post, (t).dtor_intent);
    };
    static AuthorizesX(cur, t) {
      let _pat_let_tv0 = cur;
      let _pat_let_tv1 = t;
      return ((Refund.__default.Eligible(RefundFinality.__default.ContextOf(cur, (t).dtor_requestId), Refund.ModelResponse.create_Candidate(((t).dtor_intent).dtor_amount, ((t).dtor_intent).dtor_reason))) && (_dafny.areEqual((t).dtor_post, function (_pat_let2_0) {
        return function (_0_dt__update__tmp_h0) {
          return function (_pat_let3_0) {
            return function (_1_dt__update_hremaining_h0) {
              return RefundFinality.Charge.create_Charge((_0_dt__update__tmp_h0).dtor_chargeId, (_0_dt__update__tmp_h0).dtor_original, _1_dt__update_hremaining_h0, (_0_dt__update__tmp_h0).dtor_refundEnabled);
            }(_pat_let3_0);
          }(((_pat_let_tv0).dtor_remaining).minus(((_pat_let_tv1).dtor_intent).dtor_amount));
        }(_pat_let2_0);
      }(cur)))) && (_dafny.areEqual((t).dtor_intent, Refund.RefundIntent.create_Intent((cur).dtor_chargeId, (t).dtor_requestId, ((t).dtor_intent).dtor_amount, ((t).dtor_intent).dtor_reason)));
    };
    static RowOk(initId, cur, r) {
      return ((((((((((((r).dtor_tok).dtor_specId).isEqualTo(SinkCoreV3.__default.PINNED__SPEC)) && ((((r).dtor_tok).dtor_checkerId).isEqualTo(SinkCoreV3.__default.PINNED__CHK))) && ((r).dtor_sigOk)) && ((r).dtor_preOk)) && (_dafny.areEqual((((r).dtor_tok).dtor_intent).dtor_requestId, ((r).dtor_tok).dtor_requestId))) && (_dafny.areEqual((r).dtor_settledId, ((r).dtor_tok).dtor_requestId))) && (_dafny.areEqual((r).dtor_outIntent, ((r).dtor_tok).dtor_intent))) && (_dafny.areEqual((((r).dtor_tok).dtor_intent).dtor_chargeId, initId))) && (ShellCoreV3.__default.ChargeOkP(cur, (r).dtor_tok))) && (ShellCoreV5.__default.AuthorizesX(cur, (r).dtor_tok));
    };
    static AInit(init) {
      return ShellCoreV5.AState.create_AState(init, _dafny.ZERO, true);
    };
    static AuditStep(initId, st, r) {
      return ShellCoreV5.AState.create_AState(((r).dtor_tok).dtor_post, ((st).dtor_count).plus(_dafny.ONE), ((st).dtor_ok) && (ShellCoreV5.__default.RowOk(initId, (st).dtor_cur, r)));
    };
    static AuditEnd(init, stored, st, nSettled, nOutbox, nDistinct) {
      return ((((((st).dtor_ok) && (_dafny.areEqual((st).dtor_cur, stored))) && (((st).dtor_count).isEqualTo(nSettled))) && (((st).dtor_count).isEqualTo(nOutbox))) && (((st).dtor_count).isEqualTo(nDistinct))) && (((_dafny.ZERO).isLessThanOrEqualTo((init).dtor_remaining)) && (((init).dtor_remaining).isLessThanOrEqualTo((init).dtor_original)));
    };
    static AuditLoop(init, stored, rows, nSettled, nOutbox, nDistinct) {
      let b = false;
      let _0_st;
      _0_st = ShellCoreV5.__default.AInit(init);
      let _1_i;
      _1_i = _dafny.ZERO;
      while ((_1_i).isLessThan(new BigNumber((rows).length))) {
        _0_st = ShellCoreV5.__default.AuditStep((init).dtor_chargeId, _0_st, (rows)[_1_i]);
        _1_i = (_1_i).plus(_dafny.ONE);
      }
      b = ShellCoreV5.__default.AuditEnd(init, stored, _0_st, nSettled, nOutbox, nDistinct);
      return b;
    }
    static Core0(init) {
      return SinkCoreV3.Core.create_Core(init, _dafny.Set.fromElements(), _dafny.Seq.of());
    };
    static Ch(rem) {
      return RefundFinality.Charge.create_Charge(_dafny.Seq.UnicodeFromString("ch_1"), new BigNumber(1000), rem, true);
    };
    static Tk(rid, pre, amount) {
      let _pat_let_tv0 = pre;
      let _pat_let_tv1 = amount;
      return ShellCoreV3.ShellToken.create_ShellToken(SinkCoreV3.__default.PINNED__SPEC, SinkCoreV3.__default.PINNED__CHK, rid, function (_pat_let4_0) {
  return function (_0_dt__update__tmp_h0) {
    return function (_pat_let5_0) {
      return function (_1_dt__update_hremaining_h0) {
        return RefundFinality.Charge.create_Charge((_0_dt__update__tmp_h0).dtor_chargeId, (_0_dt__update__tmp_h0).dtor_original, _1_dt__update_hremaining_h0, (_0_dt__update__tmp_h0).dtor_refundEnabled);
      }(_pat_let5_0);
    }(((_pat_let_tv0).dtor_remaining).minus(_pat_let_tv1));
  }(_pat_let4_0);
}(pre), Refund.RefundIntent.create_Intent((pre).dtor_chargeId, rid, amount, _dafny.Seq.UnicodeFromString("duplicate_charge")), _dafny.Seq.UnicodeFromString(""));
    };
    static RowT(t, s, p) {
      return ShellCoreV5.Row.create_Row((t).dtor_requestId, t, s, p, (t).dtor_intent);
    };
  };

  $module.Row = class Row {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Row(settledId, tok, sigOk, preOk, outIntent) {
      let $dt = new Row(0);
      $dt.settledId = settledId;
      $dt.tok = tok;
      $dt.sigOk = sigOk;
      $dt.preOk = preOk;
      $dt.outIntent = outIntent;
      return $dt;
    }
    get is_Row() { return this.$tag === 0; }
    get dtor_settledId() { return this.settledId; }
    get dtor_tok() { return this.tok; }
    get dtor_sigOk() { return this.sigOk; }
    get dtor_preOk() { return this.preOk; }
    get dtor_outIntent() { return this.outIntent; }
    toString() {
      if (this.$tag === 0) {
        return "ShellCoreV5.Row.Row" + "(" + this.settledId.toVerbatimString(true) + ", " + _dafny.toString(this.tok) + ", " + _dafny.toString(this.sigOk) + ", " + _dafny.toString(this.preOk) + ", " + _dafny.toString(this.outIntent) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.settledId, other.settledId) && _dafny.areEqual(this.tok, other.tok) && this.sigOk === other.sigOk && this.preOk === other.preOk && _dafny.areEqual(this.outIntent, other.outIntent);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return ShellCoreV5.Row.create_Row(_dafny.Seq.UnicodeFromString(""), ShellCoreV3.ShellToken.Default(), false, false, Refund.RefundIntent.Default());
    }
    static Rtd() {
      return class {
        static get Default() {
          return Row.Default();
        }
      };
    }
  }

  $module.AState = class AState {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_AState(cur, count, ok) {
      let $dt = new AState(0);
      $dt.cur = cur;
      $dt.count = count;
      $dt.ok = ok;
      return $dt;
    }
    get is_AState() { return this.$tag === 0; }
    get dtor_cur() { return this.cur; }
    get dtor_count() { return this.count; }
    get dtor_ok() { return this.ok; }
    toString() {
      if (this.$tag === 0) {
        return "ShellCoreV5.AState.AState" + "(" + _dafny.toString(this.cur) + ", " + _dafny.toString(this.count) + ", " + _dafny.toString(this.ok) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.cur, other.cur) && _dafny.areEqual(this.count, other.count) && this.ok === other.ok;
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return ShellCoreV5.AState.create_AState(RefundFinality.Charge.Default(), _dafny.ZERO, false);
    }
    static Rtd() {
      return class {
        static get Default() {
          return AState.Default();
        }
      };
    }
  }

  $module.Del = class Del {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Del(tok, sigOk, preOk) {
      let $dt = new Del(0);
      $dt.tok = tok;
      $dt.sigOk = sigOk;
      $dt.preOk = preOk;
      return $dt;
    }
    get is_Del() { return this.$tag === 0; }
    get dtor_tok() { return this.tok; }
    get dtor_sigOk() { return this.sigOk; }
    get dtor_preOk() { return this.preOk; }
    toString() {
      if (this.$tag === 0) {
        return "ShellCoreV5.Del.Del" + "(" + _dafny.toString(this.tok) + ", " + _dafny.toString(this.sigOk) + ", " + _dafny.toString(this.preOk) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.tok, other.tok) && this.sigOk === other.sigOk && this.preOk === other.preOk;
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return ShellCoreV5.Del.create_Del(ShellCoreV3.ShellToken.Default(), false, false);
    }
    static Rtd() {
      return class {
        static get Default() {
          return Del.Default();
        }
      };
    }
  }
  return $module;
})(); // end of module ShellCoreV5
let ShellCoreV6 = (function() {
  let $module = {};

  $module.__default = class __default {
    constructor () {
      this._tname = "ShellCoreV6._default";
    }
    _parentTraits() {
      return [];
    }
    static StepQ6(charge, t, sigOk, preOk, alreadySettled) {
      if ((!((t).dtor_specId).isEqualTo(SinkCoreV3.__default.PINNED__SPEC)) || (!((t).dtor_checkerId).isEqualTo(SinkCoreV3.__default.PINNED__CHK))) {
        return ShellCoreV6.StepResult6.create_Reject(SinkCoreV3.Why.create_IdsNotPinned());
      } else if (!(sigOk)) {
        return ShellCoreV6.StepResult6.create_Reject(SinkCoreV3.Why.create_SignatureInvalid());
      } else if (!_dafny.areEqual(((t).dtor_intent).dtor_requestId, (t).dtor_requestId)) {
        return ShellCoreV6.StepResult6.create_Reject(SinkCoreV3.Why.create_ReqIdMismatch());
      } else if (alreadySettled) {
        return ShellCoreV6.StepResult6.create_Reject(SinkCoreV3.Why.create_RequestSettled());
      } else if (!(preOk)) {
        return ShellCoreV6.StepResult6.create_Reject(SinkCoreV3.Why.create_PreStateMismatch());
      } else if (!(ShellCoreV3.__default.ChargeOkP(charge, t))) {
        return ShellCoreV6.StepResult6.create_Reject(SinkCoreV3.Why.create_ChargeIdMismatch());
      } else if (!(ShellCoreV5.__default.AuthorizesX(charge, t))) {
        return ShellCoreV6.StepResult6.create_RejectNotAuthorized();
      } else {
        return ShellCoreV6.StepResult6.create_Commit((t).dtor_post, (t).dtor_requestId, (t).dtor_intent);
      }
    };
    static Apply6(core, q) {
      if ((q).is_Commit) {
        return SinkCoreV3.Core.create_Core((q).dtor_newCharge, ((core).dtor_settled).Union(_dafny.Set.fromElements((q).dtor_addId)), _dafny.Seq.Concat((core).dtor_outbox, _dafny.Seq.of((q).dtor_intent)));
      } else {
        return core;
      }
    };
    static IssueThenStep(stored, preStateHash, tr) {
      let v = RefundFinality.Verdict.Default();
      let q = ShellCoreV6.StepResult6.Default();
      let _0_plan = _dafny.Seq.of();
      let _out0;
      let _out1;
      let _outcollector0 = RefundFinality.__default.Check(stored, preStateHash, tr);
      _out0 = _outcollector0[0];
      _out1 = _outcollector0[1];
      v = _out0;
      _0_plan = _out1;
      if ((v).is_Issue) {
        let _1_t;
        _1_t = ShellCoreV3.ShellToken.create_ShellToken(SinkCoreV3.__default.PINNED__SPEC, SinkCoreV3.__default.PINNED__CHK, ((v).dtor_token).dtor_requestId, ((v).dtor_token).dtor_post, ((v).dtor_token).dtor_intent, _dafny.Seq.UnicodeFromString(""));
        q = ShellCoreV6.__default.StepQ6(stored, _1_t, true, true, false);
      } else {
        q = ShellCoreV6.StepResult6.create_RejectNotAuthorized();
      }
      return [v, q];
    }
    static Ch(rem) {
      return ShellCoreV5.__default.Ch(rem);
    };
    static Tk(rid, pre, amount) {
      return ShellCoreV5.__default.Tk(rid, pre, amount);
    };
  };

  $module.StepResult6 = class StepResult6 {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Commit(newCharge, addId, intent) {
      let $dt = new StepResult6(0);
      $dt.newCharge = newCharge;
      $dt.addId = addId;
      $dt.intent = intent;
      return $dt;
    }
    static create_Reject(why) {
      let $dt = new StepResult6(1);
      $dt.why = why;
      return $dt;
    }
    static create_RejectNotAuthorized() {
      let $dt = new StepResult6(2);
      return $dt;
    }
    get is_Commit() { return this.$tag === 0; }
    get is_Reject() { return this.$tag === 1; }
    get is_RejectNotAuthorized() { return this.$tag === 2; }
    get dtor_newCharge() { return this.newCharge; }
    get dtor_addId() { return this.addId; }
    get dtor_intent() { return this.intent; }
    get dtor_why() { return this.why; }
    toString() {
      if (this.$tag === 0) {
        return "ShellCoreV6.StepResult6.Commit" + "(" + _dafny.toString(this.newCharge) + ", " + this.addId.toVerbatimString(true) + ", " + _dafny.toString(this.intent) + ")";
      } else if (this.$tag === 1) {
        return "ShellCoreV6.StepResult6.Reject" + "(" + _dafny.toString(this.why) + ")";
      } else if (this.$tag === 2) {
        return "ShellCoreV6.StepResult6.RejectNotAuthorized";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.newCharge, other.newCharge) && _dafny.areEqual(this.addId, other.addId) && _dafny.areEqual(this.intent, other.intent);
      } else if (this.$tag === 1) {
        return other.$tag === 1 && _dafny.areEqual(this.why, other.why);
      } else if (this.$tag === 2) {
        return other.$tag === 2;
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return ShellCoreV6.StepResult6.create_Commit(RefundFinality.Charge.Default(), _dafny.Seq.UnicodeFromString(""), Refund.RefundIntent.Default());
    }
    static Rtd() {
      return class {
        static get Default() {
          return StepResult6.Default();
        }
      };
    }
  }
  return $module;
})(); // end of module ShellCoreV6
let _module = (function() {
  let $module = {};

  return $module;
})(); // end of module _module
module.exports = { Shell6: ShellCoreV6, Shell: ShellCoreV3, C: SinkCoreV3, F: RefundFinality, R: Refund, rt: _dafny, BigNumber, SinkCore: SinkCoreV3, RefundFinality, Refund, runtime: _dafny };

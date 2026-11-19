#!/usr/bin/env node
'use strict';
// js_bound_check.cjs (Orchestrator B, h-gate, 2026-11-19). PROTOTYPE. A refusal checker over the JavaScript that the
// pinned Dafny 4.11.0 generates for impl/Refund.dfy. It parses the generated module with the TypeScript parser (real
// syntax tree, real scopes), checks the module shape, and then runs an ABSTRACT INTERPRETER from Refund.__default.Assess:
//   - every call is resolved to a known function of the module or to an allow-listed runtime primitive (else refuse);
//   - loops and recursion are unfolded abstractly; integers carry exact intervals when the code makes them exact;
//     a loop or recursion whose exit is not established within TRIP_MAX / DEPTH_MAX unfoldings is refused;
//   - every value carries a size bound a*N + b (N = input size; ints: bits; sequences, sets, tuples, datatypes:
//     tree nodes with sharing counted as COPIES); a value over the caps is refused (this bounds equality on shared
//     nested displays, string and sequence growth, and BigNumber growth);
//   - the abstract step count of one Assess call is capped by OPS_MAX;
//   - finally a LOAD CHECK runs the module once under hard limits and requires Refund.__default.Assess.
// Usage: node js_bound_check.cjs [--mutant=no-loop|no-recursion|no-load|no-shape|no-cost] [--no-load] FILE.js...
// FILE.js is either a gate build (runtime prefix + modules) or a `dafny translate js` output (modules only).
// One JSON line per file: {"file", "verdict": "ACCEPT"|"REFUSE", "code", "detail", "steps", "maxB", "maxA"}.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const childProcess = require('child_process');
const os = require('os');
const ts = require('typescript'); // resolved from the repository node_modules (pinned by package-lock.json)

// B_MAX 2^15: below the argument-spread limits of V8 (Seq.of(...a) in Concat). D_MAX: nesting depth of values,
// so that areEqual/equals recursion stays far below the V8 stack limit.
const LIMITS = { OPS_MAX: 1000000, TRIP_MAX: 4096, DEPTH_MAX: 64, A_MAX: 16, B_MAX: 1 << 15, D_MAX: 64,
  // Weighted cost of one Assess call: c0 + c1*N + c2*N^2 unit operations of the runtime primitives (see COST).
  C0_MAX: 2 ** 30, C1_MAX: 2 ** 20, C2_MAX: 2 ** 12,
  // Fail-closed input bounds (C-GATE-02): user modules at most 1 MiB; syntax nesting at most 200 levels.
  // Parsing and the nesting scan are linear in the input; the abstract run is bounded by OPS_MAX.
  USER_BYTES_MAX: 1 << 20, NEST_MAX: 200 };
// Cost class of each allow-listed runtime primitive, in the sizes of its operands (receiver first):
// L = linear in the sum of the operand sizes; Q = product of the receiver size and the other operand sizes
// (quadratic); S = square of the sum (Set.fromElements: deduplication by areEqual); C = constant (a step).
const COST = {
  '_dafny.Seq.of': 'L', '_dafny.Tuple.of': 'L', '_dafny.Set.fromElements': 'S', '_dafny.Seq.UnicodeFromString': 'L',
  '_dafny.areEqual': 'L', '_dafny.Seq.contains': 'Q', '_dafny.Seq.IsPrefixOf': 'L', '_dafny.Seq.IsProperPrefixOf': 'L',
  '_dafny.Seq.Concat': 'L', '_dafny.EuclideanDivision': 'Q', '_dafny.EuclideanModulo': 'Q',
  plus: 'L', minus: 'L', negated: 'L', multipliedBy: 'Q', mod: 'Q', isLessThan: 'L', isLessThanOrEqualTo: 'L',
  isEqualTo: 'L', contains: 'Q', toNumber: 'C', slice: 'L', Union: 'Q', Intersect: 'Q', Difference: 'Q',
  IsSubsetOf: 'Q', IsProperSubsetOf: 'Q', IsDisjointFrom: 'Q', equals: 'L', updateUnsafe: 'Q', update: 'Q', get: 'Q',
};
const INPUT = { a: 1, b: 64, d: 3 }; // the bound of one Assess argument: at most N + 64
const PIN = {
  // Lines 1-1188 of the gate build `dafny build --target js` output: Dafny 4.11.0 runtime and _System.
  prefix: '39aa8ff111c6b83497a1a3c69d4a47bb13f8f1d3f843c950d9c45943c2ed25ce',
  // The four approved spec datatypes, as compiled into module Refund (text of the `$module.X = class X` statement).
  Context: 'a7bbad6e528449bd7cf72d2aa3394edee11653305ba122ee885f5f7ade658f1a',
  ModelResponse: '001bffaa63a6f5b5673e5b0f65b4716c04238d57ceb1f9b74fcb8146f96ab7f1',
  Decision: '24496ff4d8e7c28548e913bf0f9d57fd227542cb15cc590a511d49a3ae85eaf2',
  RefundIntent: '253bd76fa91c1f207b9204c0a248f10ca80df57fc4d360ebcbc015fa8cce861f',
};
const PREFIX_FILE = path.join(__dirname, 'runtime-prefix.js'); // copy of the pinned prefix (checked by digest)
const NODE = process.execPath; // the pinned Node that runs this checker

class Refuse extends Error { constructor(code, detail) { super(code + ': ' + detail); this.code = code; this.detail = detail; } }
const refuse = (code, detail) => { throw new Refuse(code, detail); };
const sha = (s) => crypto.createHash('sha256').update(s).digest('hex');

// JavaScript and runtime names that no compiled user name (module, member, datatype field) may take.
const DENY = new Set(('prototype constructor __proto__ __defineGetter__ __defineSetter__ __lookupGetter__ ' +
  '__lookupSetter__ hasOwnProperty isPrototypeOf propertyIsEnumerable toLocaleString toString valueOf length name ' +
  'caller arguments apply call bind then equals $tag _tname _parentTraits Default Rtd ' +
  'require module exports __filename __dirname globalThis eval Function Object Array Symbol Proxy Reflect Promise ' +
  'BigNumber _dafny _System Refund Math JSON Number String Boolean Error process undefined NaN Infinity').split(' '));

// ---------- abstract values ----------
// {a, b}: size <= a*N + b. lo/hi: BigInt interval (ints). bool: true/false/undefined. len: [lo, hi] (sequences).
// elems: AV[] (arrays/tuples). fields: {name: AV} (datatype values). fn: function node (lambda value).
const AV = (a, b, extra) => Object.assign({ a, b }, extra || {});
const BOOL = (v) => AV(0, 1, { bool: v });
const BOTTOM = AV(0, 0, { bottom: true });
const bits = (x) => { const v = x < 0n ? -x : x; return v === 0n ? 1 : v.toString(2).length + 1; };
const intLit = (v) => AV(0, bits(v), { lo: v, hi: v });
function join(x, y, d = 0) { // d: nesting depth; element and field facts are kept to depth 3 only
  if (!x || x.bottom) return y; if (!y || y.bottom) return x;
  const r = AV(Math.max(x.a, y.a), Math.max(x.b, y.b), { d: Math.max(x.d || 0, y.d || 0) });
  if (x.lo !== undefined && y.lo !== undefined) { r.lo = x.lo < y.lo ? x.lo : y.lo; r.hi = x.hi > y.hi ? x.hi : y.hi; }
  if (x.bool !== undefined && x.bool === y.bool) r.bool = x.bool;
  if (x.len && y.len) r.len = [Math.min(x.len[0], y.len[0]), Math.max(x.len[1], y.len[1])];
  if (d < 3 && x.elems && y.elems && x.elems.length === y.elems.length) r.elems = x.elems.map((e, i) => join(e, y.elems[i], d + 1));
  if (x.fields && y.fields) {
    const k = Object.keys(x.fields);
    if (d < 3 && k.length === Object.keys(y.fields).length && k.every((f) => f in y.fields)) {
      r.fields = {}; for (const f of k) r.fields[f] = join(x.fields[f], y.fields[f], d + 1);
    }
  }
  if (x.fn && x.fn === y.fn) r.fn = x.fn;
  return r;
}
const sumAV = (list, extra) => AV(list.reduce((s, v) => s + v.a, 0), 1 + list.reduce((s, v) => s + v.b, 0),
  Object.assign({ d: 1 + list.reduce((m, v) => Math.max(m, v.d || 0), 0) }, extra || {}));
const depthOf = (...l) => ({ d: l.reduce((m, v) => Math.max(m, (v && v.d) || 0), 0) });

// ---------- module shape ----------
function splitInput(text) {
  const marker = text.indexOf('let _dafny = (function()');
  let user = text; let prefix = null;
  if (marker >= 0) {
    const at = text.indexOf('\nlet Refund = (function()');
    if (at < 0) refuse('SHAPE', 'module Refund not found after the runtime');
    if (sha(text.slice(0, at + 1)) !== PIN.prefix) refuse('RUNTIME', 'runtime prefix differs from the pinned Dafny 4.11.0 prefix');
    user = text.slice(at + 1); prefix = text.slice(0, at + 1);
  } else {
    user = user.replace(/^\/\/ Dafny program Refund\.dfy compiled into JavaScript\r?\n/, '');
  }
  return { user, prefix };
}
const iife = (e) => {
  // (function() { ... })()
  if (!e || !ts.isCallExpression(e) || e.arguments.length) return null;
  let f = e.expression; while (ts.isParenthesizedExpression(f)) f = f.expression;
  return ts.isFunctionExpression(f) && f.parameters.length === 0 ? f : null;
};
function checkShape(sf, text) {
  if (sf.parseDiagnostics && sf.parseDiagnostics.length) refuse('PARSE', ts.flattenDiagnosticMessageText(sf.parseDiagnostics[0].messageText, ' '));
  const modules = {};
  for (const st of sf.statements) {
    if (!ts.isVariableStatement(st) || st.declarationList.declarations.length !== 1 ||
        !(st.declarationList.flags & ts.NodeFlags.Let)) refuse('SHAPE', 'top-level statement is not a module: ' + st.getText(sf).slice(0, 60));
    const d = st.declarationList.declarations[0];
    const f = iife(d.initializer);
    if (!ts.isIdentifier(d.name) || !f) refuse('SHAPE', 'top-level declaration is not a module function');
    const name = d.name.text;
    if (name in modules) refuse('SHAPE', 'module declared twice: ' + name);
    const body = f.body.statements;
    const first = body[0], last = body[body.length - 1];
    if (!first || first.getText(sf) !== 'let $module = {};' || !last || last.getText(sf) !== 'return $module;') refuse('SHAPE', 'module ' + name + ' has an unknown frame');
    modules[name] = body.slice(1, -1);
  }
  if (!modules.Refund) refuse('SHAPE', 'no module Refund');
  for (const [name, inner] of Object.entries(modules)) {
    if (name === 'Refund') continue;
    if (inner.length) refuse('SHAPE', 'module ' + name + ' has compiled content (only Refund may)');
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(name) || DENY.has(name) || (name in globalThis && name !== '_module'))
      refuse('NAME', 'module name ' + name + ' is a JavaScript, runtime or global name');
  }
  const classes = {};
  for (const st of modules.Refund) {
    const t = st.getText(sf);
    const m = /^\$module\.([A-Za-z_$][\w$]*) = class ([A-Za-z_$][\w$]*) \{/.exec(t);
    if (!ts.isExpressionStatement(st) || !m || m[1] !== m[2] || !ts.isBinaryExpression(st.expression) ||
        !ts.isClassExpression(st.expression.right)) refuse('SHAPE', 'module Refund holds a non-class statement: ' + t.slice(0, 60));
    const cls = st.expression.right;
    if (cls.heritageClauses && cls.heritageClauses.length) refuse('SHAPE', 'class ' + m[1] + ' extends another class');
    if (m[1] in classes) refuse('SHAPE', 'class declared twice: ' + m[1]);
    if (PIN[m[1]] && m[1] !== 'prefix') {
      if (sha(t) !== PIN[m[1]]) refuse('SPEC_TYPE', 'spec datatype ' + m[1] + ' differs from the approved compiled text');
      classes[m[1]] = { kind: 'spec', node: cls, ctors: datatypeCtors(cls, sf, true) };
    } else if (m[1] === '__default') {
      classes[m[1]] = { kind: 'default', node: cls, members: defaultMembers(cls, sf) };
    } else {
      if (DENY.has(m[1])) refuse('NAME', 'class name ' + m[1]);
      classes[m[1]] = { kind: 'user', node: cls, ctors: datatypeCtors(cls, sf, false) };
    }
  }
  for (const k of ['__default', 'Context', 'ModelResponse', 'Decision', 'RefundIntent'])
    if (!classes[k]) refuse('SHAPE', 'class ' + k + ' missing');
  const assess = classes.__default.members.Assess;
  if (!assess || assess.kind !== 'method' || assess.node.parameters.length !== 2) refuse('SHAPE', 'no static Assess(context, response)');
  return classes;
}
function memberName(m) { return m.name && ts.isIdentifier(m.name) ? m.name.text : null; }
const isStatic = (m) => (ts.getCombinedModifierFlags(m) & ts.ModifierFlags.Static) !== 0;
function defaultMembers(cls, sf) {
  const out = {};
  for (const m of cls.members) {
    const n = memberName(m); const t = m.getText(sf);
    if (ts.isSemicolonClassElement(m)) continue;
    if (ts.isConstructorDeclaration(m) && /^constructor \(\) \{\s*this\._tname = "Refund\._default";\s*\}$/.test(t)) continue;
    if (ts.isMethodDeclaration(m) && n === '_parentTraits' && /^_parentTraits\(\) \{\s*return \[\];\s*\}$/.test(t)) continue;
    if (!n || !isStatic(m)) refuse('SHAPE', 'class __default member is not a static named member: ' + t.slice(0, 50));
    // Dafny renames a member whose name is reserved in JavaScript to `_$$_name`; such a name cannot collide.
    if (!/^([A-Za-z][A-Za-z0-9_]*|_\$\$_[A-Za-z0-9_]+)$/.test(n) || (DENY.has(n) && n !== 'prototype')) refuse('NAME', 'member name ' + n);
    // `prototype` is left to the load check (a static method with this name is a JavaScript SyntaxError).
    if (n in out) refuse('NAME', 'member declared twice: ' + n);
    if (ts.isMethodDeclaration(m) && !m.asteriskToken && !m.questionToken && m.body) out[n] = { kind: 'method', node: m, name: n };
    else if (ts.isGetAccessorDeclaration(m) && m.body && m.parameters.length === 0) out[n] = { kind: 'const', node: m, name: n };
    else refuse('SHAPE', 'class __default member kind: ' + t.slice(0, 50));
    for (const p of m.parameters) if (!ts.isIdentifier(p.name) || p.initializer || p.dotDotDotToken) refuse('SHAPE', 'parameter form in ' + n);
  }
  return out;
}
// A datatype class may hold only the members that Dafny generates for a datatype. Their bodies are checked by form.
function datatypeCtors(cls, sf, trusted) {
  const ctors = {}; let tag = 0;
  for (const m of cls.members) {
    const n = memberName(m); const t = m.getText(sf).replace(/\s+/g, ' ');
    if (ts.isSemicolonClassElement(m)) continue;
    if (ts.isConstructorDeclaration(m)) { if (t !== 'constructor(tag) { this.$tag = tag; }') refuse('DATATYPE', 'constructor form'); continue; }
    if (!n) refuse('DATATYPE', 'computed member name');
    if (ts.isMethodDeclaration(m) && isStatic(m) && n.startsWith('create_')) {
      const ps = m.parameters.map((p) => p.name.text);
      for (const p of ps) if (DENY.has(p) || !/^[A-Za-z][A-Za-z0-9_]*$/.test(p)) refuse('NAME', 'datatype field name ' + p);
      const want = 'static ' + n + '(' + ps.join(', ') + ') { let $dt = new ' + cls.name.text + '(' + tag + '); ' +
        ps.map((p) => '$dt.' + p + ' = ' + p + '; ').join('') + 'return $dt; }';
      if (!trusted && t !== want) refuse('DATATYPE', 'constructor function form of ' + n);
      ctors[n] = { fields: ps, tag: tag++ };
      continue;
    }
    if (trusted) continue;
    if (ts.isGetAccessorDeclaration(m) && /^get is_[A-Za-z0-9_]+\(\) \{ return this\.\$tag === \d+; \}$/.test(t)) continue;
    const g = /^get dtor_([A-Za-z0-9_]+)\(\) \{ return this\.([A-Za-z0-9_]+); \}$/.exec(t);
    if (ts.isGetAccessorDeclaration(m) && g && g[1] === g[2]) continue;
    if (ts.isMethodDeclaration(m) && (n === 'toString' || n === 'equals')) { checkDatatypeAux(m, sf, n); continue; }
    // Enumeration helpers of a datatype with only nullary constructors (not reachable from compiled user code).
    if (ts.isGetAccessorDeclaration(m) && t === 'static get AllSingletonConstructors() { return this.AllSingletonConstructors_(); }') continue;
    if (ts.isMethodDeclaration(m) && n === 'AllSingletonConstructors_' && m.asteriskToken &&
        new RegExp('^static \\*AllSingletonConstructors_\\(\\) \\{( yield ' + cls.name.text + '\\.create_[A-Za-z0-9_]+\\(\\);)+ \\}$').test(t)) continue;
    if (ts.isMethodDeclaration(m) && isStatic(m) && (n === 'Default' || n === 'Rtd')) { checkDatatypeAux(m, sf, n); continue; }
    refuse('DATATYPE', 'unknown datatype member ' + n);
  }
  return ctors;
}
// toString/equals/Default/Rtd of a user datatype: no loop, no call except the allowed runtime and constructor calls.
function checkDatatypeAux(m, sf, n) {
  const okCall = /^(_dafny\.areEqual|_dafny\.toString|this\.[A-Za-z0-9_]+\.toVerbatimString|Refund\.[A-Za-z0-9_]+\.(create_[A-Za-z0-9_]+|Default)|[A-Za-z0-9_]+\.Default|_dafny\.Seq\.(of|UnicodeFromString)|_dafny\.Tuple\.of|_dafny\.Set\.fromElements|_dafny\.Map\.Empty\.slice)$/;
  const visit = (x) => {
    if (ts.isIterationStatement(x, false) || ts.isThrowStatement(x) || ts.isNewExpression(x) && x.expression.getText(sf) !== 'BigNumber')
      refuse('DATATYPE', n + ' holds a loop, throw or new');
    if (ts.isCallExpression(x) && !okCall.test(x.expression.getText(sf))) refuse('DATATYPE', n + ' calls ' + x.expression.getText(sf).slice(0, 40));
    ts.forEachChild(x, visit);
  };
  visit(m.body);
}

// ---------- abstract interpreter ----------
class Interp {
  constructor(classes, sf, mutant) {
    this.classes = classes; this.sf = sf; this.mutant = mutant; this.steps = 0; this.cost = [0, 0, 0]; this.maxB = 0; this.maxA = 0; this.stack = [];
  }
  fieldNames() {
    if (!this._fields) { this._fields = new Set(); for (const c of Object.values(this.classes)) for (const k of Object.values(c.ctors || {})) for (const f of k.fields) this._fields.add(f); }
    return this._fields;
  }
  tick(n) { this.steps += n || 1; if (this.steps > LIMITS.OPS_MAX && this.mutant !== 'no-cost') refuse('COST', 'more than ' + LIMITS.OPS_MAX + ' abstract steps for one Assess call'); }
  check(v, where) {
    if (v.a > this.maxA) this.maxA = v.a; if (v.b > this.maxB && v.b !== Infinity) this.maxB = v.b;
    if ((v.d || 0) > LIMITS.D_MAX && this.mutant !== 'no-shape') refuse('SIZE', 'value nesting depth ' + v.d + ' over ' + LIMITS.D_MAX + ' at ' + where);
    if (v.a > LIMITS.A_MAX || v.b > LIMITS.B_MAX) {
      if (this.mutant !== 'no-shape') refuse('SIZE', 'value bound ' + v.a + '*N + ' + v.b + ' over the caps at ' + where);
      return AV(Math.min(v.a, LIMITS.A_MAX), Math.min(v.b, LIMITS.B_MAX), v.lo !== undefined ? { lo: v.lo, hi: v.hi } : {}); // mutant: forget the shape
    }
    return v;
  }
  txt(n) { return n.getText(this.sf).replace(/\s+/g, ' ').slice(0, 70); }
  // env: array of Maps (scope chain). Cloned at branches.
  // A dead env (after return, break or continue) is the identity of join. Jump states may be deeper: trimmed.
  clone(env) { const r = env.map((m) => new Map(m)); r.dead = !!env.dead; return r; }
  joinEnv(x, y) {
    if (y.dead) return this.clone(x);
    if (x.dead) { const r = this.clone(y).slice(0, x.length); r.dead = false; return r; }
    const r = x.map((m, i) => { const q = new Map(m); for (const [k, v] of y[i]) q.set(k, join(q.get(k), v)); return q; });
    r.dead = false; return r;
  }
  setEnv(env, j) { const c = j.slice(); env.length = 0; env.push(...c); env.dead = !!j.dead; }
  lookup(env, name) { for (let i = env.length - 1; i >= 0; i--) if (env[i].has(name)) return env[i].get(name); return undefined; }
  assign(env, name, v) { for (let i = env.length - 1; i >= 0; i--) if (env[i].has(name)) { env[i].set(name, v); return; } refuse('NAME', 'assignment to an undeclared name ' + name); }

  run() {
    const assess = this.classes.__default.members.Assess;
    return this.call(assess, [AV(INPUT.a, INPUT.b, { d: INPUT.d }), AV(INPUT.a, INPUT.b, { d: INPUT.d })]);
  }
  call(fn, args, outer) {
    this.tick();
    const depth = this.stack.filter((f) => f === fn.node).length;
    if (depth > 0) {
      if (this.mutant === 'no-recursion') return args.reduce((s, v) => join(s, v), AV(0, 1));
      if (depth >= LIMITS.DEPTH_MAX) refuse('RECURSION', 'recursion through ' + fn.name + ' not bounded within ' + LIMITS.DEPTH_MAX + ' unfoldings');
    }
    if (this.stack.length > 4 * LIMITS.DEPTH_MAX) refuse('RECURSION', 'call depth over ' + 4 * LIMITS.DEPTH_MAX);
    // Mutant no-cost: a call is analysed once per abstract argument tuple (no unfolding per call site).
    const memoKey = this.mutant === 'no-cost' && !outer ? fn.node.pos + ':' + JSON.stringify(args, (k, v) => (typeof v === 'bigint' ? String(v) : v)) : null;
    if (memoKey && this.memo && this.memo.has(memoKey)) return this.memo.get(memoKey);
    this.stack.push(fn.node);
    const env = (outer ? outer.slice() : []).concat([new Map()]);
    const top = env.length - 1;
    const params = fn.node.parameters || [];
    if (params.length !== args.length) refuse('CALL', 'arity of ' + (fn.name || 'lambda'));
    params.forEach((p, i) => { if (!ts.isIdentifier(p.name) || p.initializer || p.dotDotDotToken) refuse('SHAPE', 'parameter form'); env[top].set(p.name.text, args[i]); });
    const ctx = { ret: BOTTOM, breaks: [], conts: [], labels: [] };
    this.block(fn.node.body.statements, env, ctx);
    this.stack.pop();
    if (memoKey) { this.memo = this.memo || new Map(); this.memo.set(memoKey, ctx.ret); }
    return ctx.ret;
  }
  block(stmts, env, ctx) {
    env.push(new Map());
    for (const s of stmts) { if (env.dead) break; this.stmt(s, env, ctx); }
    env.pop();
  }
  stmt(s, env, ctx) {
    this.tick();
    if (ts.isVariableStatement(s)) {
      const fl = s.declarationList.flags;
      if (!(fl & (ts.NodeFlags.Let | ts.NodeFlags.Const))) refuse('SHAPE', '`var` declaration');
      this.declare(s.declarationList, env);
      return;
    }
    if (ts.isExpressionStatement(s)) {
      const e = s.expression;
      if (ts.isBinaryExpression(e) && e.operatorToken.kind === ts.SyntaxKind.EqualsToken) {
        if (!ts.isIdentifier(e.left)) refuse('SHAPE', 'assignment target ' + this.txt(e.left));
        this.assign(env, e.left.text, this.expr(e.right, env));
        return;
      }
      if (ts.isCallExpression(e)) { this.expr(e, env); return; }
      refuse('SHAPE', 'expression statement ' + this.txt(e));
    }
    if (ts.isBlock(s)) return this.block(s.statements, env, ctx);
    if (ts.isEmptyStatement(s)) return;
    if (ts.isIfStatement(s)) {
      const c = this.expr(s.expression, env);
      if (c.bool === true) return this.branch(s.thenStatement, env, ctx);
      if (c.bool === false) return s.elseStatement ? this.branch(s.elseStatement, env, ctx) : undefined;
      const e2 = this.clone(env);
      this.branch(s.thenStatement, env, ctx);
      if (s.elseStatement) this.branch(s.elseStatement, e2, ctx);
      this.setEnv(env, this.joinEnv(env, e2));
      return;
    }
    if (ts.isReturnStatement(s)) {
      ctx.ret = join(ctx.ret, s.expression ? this.expr(s.expression, env) : AV(0, 0));
      env.dead = true; return;
    }
    if (ts.isLabeledStatement(s)) {
      const l = s.label.text;
      if (ctx.labels.includes(l)) refuse('SHAPE', 'label reused');
      ctx.labels.push(l);
      const before = ctx.breaks.length;
      if (ts.isWhileStatement(s.statement) || ts.isForStatement(s.statement)) this.loop(s.statement, env, ctx, l);
      else this.branch(s.statement, env, ctx);
      ctx.labels.pop();
      this.collect(ctx.breaks, before, l, env, false);
      return;
    }
    if (ts.isBreakStatement(s) || ts.isContinueStatement(s)) {
      const l = s.label ? s.label.text : '';
      if (l && !ctx.labels.includes(l)) refuse('SHAPE', 'jump to an unknown label');
      (ts.isBreakStatement(s) ? ctx.breaks : ctx.conts).push({ label: l, env: this.clone(env) });
      env.dead = true; return;
    }
    if (ts.isWhileStatement(s) || ts.isForStatement(s)) return this.loop(s, env, ctx, null);
    if (ts.isThrowStatement(s)) refuse('HALT', '`throw` in compiled code (a run-time halt): ' + this.txt(s));
    refuse('STATEMENT', ts.SyntaxKind[s.kind] + ' is outside the admitted statements: ' + this.txt(s));
  }
  // Joins into env the jump states recorded after index `before` that target `label` ('' = innermost loop).
  collect(list, before, label, env, alsoUnlabeled) {
    const keep = [];
    for (const b of list.splice(before)) {
      if ((label !== null && b.label === label) || (alsoUnlabeled && b.label === '')) this.setEnv(env, this.joinEnv(env, b.env));
      else keep.push(b);
    }
    list.push(...keep);
  }
  declare(list, env) {
    for (const d of list.declarations) {
      if (!ts.isIdentifier(d.name)) refuse('SHAPE', 'destructuring declaration');
      const n = d.name.text;
      if (!/^[A-Za-z_$][A-Za-z0-9_$]*$/.test(n) || DENY.has(n)) refuse('NAME', 'local name ' + n);
      env[env.length - 1].set(n, d.initializer ? this.expr(d.initializer, env) : BOTTOM);
    }
  }
  branch(s, env, ctx) { if (ts.isBlock(s)) this.block(s.statements, env, ctx); else this.stmt(s, env, ctx); }
  // Loops: unfold while the condition is not definitely false and the body can reach the next iteration.
  // Exit state = join of the states where the condition may be false and of the break states.
  loop(s, env, ctx, label) {
    env.push(new Map());
    if (ts.isForStatement(s) && s.initializer) {
      if (!ts.isVariableDeclarationList(s.initializer) || !(s.initializer.flags & ts.NodeFlags.Let)) refuse('LOOP', 'for-initializer form');
      this.declare(s.initializer, env);
    }
    const condNode = ts.isWhileStatement(s) ? s.expression : s.condition;
    const exit = this.clone(env); exit.dead = true;
    let trips = 0;
    while (!env.dead) {
      const c = condNode ? this.expr(condNode, env) : BOOL(true);
      if (c.bool !== true) this.setEnv(exit, this.joinEnv(exit, env));
      if (c.bool === false) break;
      if (this.mutant === 'no-loop' && trips >= 1) { this.setEnv(exit, this.joinEnv(exit, env)); break; }
      if (++trips > LIMITS.TRIP_MAX) refuse('LOOP', 'loop exit not established within ' + LIMITS.TRIP_MAX + ' unfoldings: ' + this.txt(s).slice(0, 50));
      const b0 = ctx.breaks.length, c0 = ctx.conts.length;
      ctx.labels.push('');
      this.branch(s.statement, env, ctx);
      ctx.labels.pop();
      this.collect(ctx.conts, c0, label, env, true);  // continue: next iteration
      this.collect(ctx.breaks, b0, label, exit, true); // break: loop exit
      if (!env.dead && ts.isForStatement(s) && s.incrementor) {
        const inc = s.incrementor;
        if (!ts.isBinaryExpression(inc) || inc.operatorToken.kind !== ts.SyntaxKind.EqualsToken || !ts.isIdentifier(inc.left)) refuse('LOOP', 'for-incrementor form');
        this.assign(env, inc.left.text, this.expr(inc.right, env));
      }
    }
    this.setEnv(env, exit);
    env.pop();
  }

  // ---------- expressions ----------
  expr(e, env) {
    this.tick();
    const v = this.expr0(e, env);
    return this.check(v, this.txt(e).slice(0, 40));
  }
  expr0(e, env) {
    const K = ts.SyntaxKind;
    if (ts.isParenthesizedExpression(e)) return this.expr(e.expression, env);
    if (e.kind === K.TrueKeyword) return BOOL(true);
    if (e.kind === K.FalseKeyword) return BOOL(false);
    if (ts.isNumericLiteral(e)) return intLit(BigInt(e.text));
    if (ts.isStringLiteral(e)) return AV(0, e.text.length + 1);
    if (ts.isIdentifier(e)) {
      const v = this.lookup(env, e.text);
      if (v === undefined) refuse('NAME', 'free identifier ' + e.text);
      if (v.bottom) return AV(0, 0);
      return v;
    }
    if (ts.isPrefixUnaryExpression(e) && e.operator === K.ExclamationToken) {
      const v = this.expr(e.operand, env); return BOOL(v.bool === undefined ? undefined : !v.bool);
    }
    if (ts.isBinaryExpression(e)) {
      const op = e.operatorToken.kind;
      if (op === K.AmpersandAmpersandToken || op === K.BarBarToken) {
        const l = this.expr(e.left, env);
        const and = op === K.AmpersandAmpersandToken;
        if (l.bool === !and) return BOOL(!and);
        const r = this.expr(e.right, env);
        if (l.bool === and) return BOOL(r.bool);
        return BOOL(r.bool === !and ? !and : undefined);
      }
      if (op === K.EqualsEqualsEqualsToken || op === K.ExclamationEqualsEqualsToken) {
        const l = this.expr(e.left, env), r = this.expr(e.right, env);
        if (l.bool !== undefined && r.bool !== undefined) return BOOL((l.bool === r.bool) === (op === K.EqualsEqualsEqualsToken));
        return BOOL(undefined);
      }
      refuse('EXPR', 'binary operator ' + e.operatorToken.getText(this.sf));
    }
    if (ts.isConditionalExpression(e)) {
      const c = this.expr(e.condition, env);
      if (c.bool === true) return this.expr(e.whenTrue, env);
      if (c.bool === false) return this.expr(e.whenFalse, env);
      return join(this.expr(e.whenTrue, env), this.expr(e.whenFalse, env));
    }
    if (ts.isArrayLiteralExpression(e)) {
      const el = e.elements.map((x) => { if (ts.isSpreadElement(x)) refuse('EXPR', 'spread'); return this.expr(x, env); });
      return sumAV(el, { elems: el, len: [el.length, el.length] });
    }
    if (ts.isElementAccessExpression(e)) {
      const base = this.expr(e.expression, env);
      const ix = e.argumentExpression;
      if (ts.isNumericLiteral(ix)) { const i = Number(ix.text); if (base.elems && i < base.elems.length) return base.elems[i]; return AV(base.a, base.b, depthOf(base)); }
      this.expr(ix, env);
      return AV(base.a, base.b, depthOf(base));
    }
    if (ts.isNewExpression(e)) {
      // A character literal: new _dafny.CodePoint('c'.codePointAt(0))
      if (/^new _dafny\.CodePoint\(('(?:[^'\\]|\\.){1,12}'|"(?:[^"\\]|\\.){1,12}")\.codePointAt\(0\)\)$/.test(e.getText(this.sf))) return AV(0, 1);
      if (e.expression.getText(this.sf) !== 'BigNumber' || !e.arguments || e.arguments.length !== 1) refuse('EXPR', '`new` other than BigNumber: ' + this.txt(e));
      const x = e.arguments[0];
      if (ts.isNumericLiteral(x) || ts.isStringLiteral(x)) {
        if (!/^-?[0-9]+$/.test(x.text)) refuse('EXPR', 'BigNumber literal form ' + x.text);
        return intLit(BigInt(x.text));
      }
      // new BigNumber((s).length)
      if (ts.isPropertyAccessExpression(x) && x.name.text === 'length') {
        const s = this.expr(x.expression, env);
        if (s.len) return AV(0, 64, { lo: BigInt(s.len[0]), hi: BigInt(s.len[1]) });
        return AV(0, 64, { lo: 0n, hi: BigInt(Number.MAX_SAFE_INTEGER) });
      }
      refuse('EXPR', 'BigNumber argument form ' + this.txt(x));
    }
    if (ts.isPropertyAccessExpression(e)) return this.property(e, env);
    if (ts.isCallExpression(e)) return this.callExpr(e, env);
    refuse('EXPR', ts.SyntaxKind[e.kind] + ' is outside the admitted expressions: ' + this.txt(e));
  }
  property(e, env) {
    const t = e.getText(this.sf);
    if (t === '_dafny.ZERO') return intLit(0n);
    if (t === '_dafny.ONE') return intLit(1n);
    if (t === '_dafny.Map.Empty') return AV(0, 1, { len: [0, 0] }); // C
    const m = /^Refund\.__default\.([A-Za-z0-9_]+)$/.exec(t);
    if (m) {
      const f = this.classes.__default.members[m[1]];
      if (!f || f.kind !== 'const') refuse('CALL', 'unresolved member value ' + t);
      return this.call(f, []);
    }
    const name = e.name.text;
    const base = this.expr(e.expression, env);
    if (name.startsWith('dtor_')) { const f = name.slice(5); return base.fields && base.fields[f] ? base.fields[f] : AV(base.a, base.b, depthOf(base)); }
    if (name.startsWith('is_')) return BOOL(undefined);
    if (name === 'length') return AV(0, 64);
    if (this.fieldNames().has(name)) return base.fields && base.fields[name] ? base.fields[name] : AV(base.a, base.b, depthOf(base)); // a datatype field
    refuse('EXPR', 'property ' + name + ' is not allow-listed');
  }
  // Runtime primitives. Cost class in comments: C = constant; L = linear in the operand sizes; Q = quadratic.
  callExpr(e, env) {
    this._ops = null;
    const r = this.callExpr0(e, env);
    let callee = e.expression; while (ts.isParenthesizedExpression(callee)) callee = callee.expression;
    const key = ts.isPropertyAccessExpression(callee) && !/^_dafny\./.test(callee.getText(this.sf)) ? callee.name.text : callee.getText(this.sf);
    if (COST[key] && this._ops) this.charge(COST[key], this._ops, key);
    return r;
  }
  charge(cls, ops, key) {
    const add = (k, x) => { this.cost[k] += x; };
    if (cls === 'L') for (const o of ops) { add(1, o.a); add(0, o.b); }
    else if (cls === 'S') { const a = ops.reduce((p, o) => p + o.a, 0), b = ops.reduce((p, o) => p + o.b, 0); add(2, a * a); add(1, 2 * a * b); add(0, b * b); }
    else if (cls === 'Q') {
      const [x, ...rest] = ops; const a = rest.reduce((p, o) => p + o.a, 0), b = rest.reduce((p, o) => p + o.b, 0);
      add(2, x.a * a); add(1, x.a * b + x.b * a); add(0, x.b * b + x.b + b);
    }
    if (this.mutant !== 'no-cost' && (this.cost[0] > LIMITS.C0_MAX || this.cost[1] > LIMITS.C1_MAX || this.cost[2] > LIMITS.C2_MAX))
      refuse('COST', 'weighted cost ' + this.cost.join('/') + ' (c0/c1/c2) over the caps at ' + key);
  }
  callExpr0(e, env) {
    const sf = this.sf; const args = e.arguments;
    let callee = e.expression; while (ts.isParenthesizedExpression(callee)) callee = callee.expression;
    // Immediately invoked lambda (Dafny let- and match-expressions).
    if (ts.isFunctionExpression(callee) || ts.isArrowFunction(callee)) {
      const vals = args.map((a) => this.expr(a, env));
      if (!ts.isBlock(callee.body)) refuse('EXPR', 'expression-bodied lambda');
      return this.call({ node: callee, name: 'lambda' }, vals, env);
    }
    const t = callee.getText(sf);
    let m;
    if ((m = /^Refund\.__default\.([A-Za-z0-9_]+)$/.exec(t))) {
      const f = this.classes.__default.members[m[1]];
      if (!f || f.kind !== 'method') refuse('CALL', 'unresolved call ' + t);
      const vals = args.map((a) => this.expr(a, env));
      return this.call(f, vals);
    }
    if ((m = /^Refund\.([A-Za-z0-9_]+)\.(create_[A-Za-z0-9_]+|Default)$/.exec(t))) {
      const c = this.classes[m[1]];
      if (!c || !c.ctors) refuse('CALL', 'unresolved datatype ' + t);
      if (m[2] === 'Default') { // C: the default value; user datatypes: interpret the generated Default body
        if (args.length) refuse('CALL', 'Default arity');
        if (c.kind === 'spec') return AV(0, 32, { d: 3 });
        const d = c.node.members.find((x) => ts.isMethodDeclaration(x) && memberName(x) === 'Default' && isStatic(x));
        if (!d) refuse('CALL', 'no Default in ' + m[1]);
        return this.call({ node: d, name: m[1] + '.Default' }, []);
      }
      const k = c.ctors[m[2]];
      if (!k || k.fields.length !== args.length) refuse('CALL', 'unresolved constructor ' + t);
      const vals = args.map((a) => this.expr(a, env));
      const fields = {}; k.fields.forEach((f, i) => { fields[f] = vals[i]; });
      return sumAV(vals, { fields }); // C
    }
    const vals = () => { const r = args.map((a) => this.expr(a, env)); this._ops = r; return r; };
    switch (t) {
      case '_dafny.Seq.of': { const v = vals(); return sumAV(v, { len: [v.length, v.length] }); } // L
      case '_dafny.Tuple.of': { const v = vals(); return sumAV(v, { elems: v }); } // L
      case '_dafny.Set.fromElements': { const v = vals(); return sumAV(v); } // Q (dedup by areEqual)
      case '_dafny.Seq.UnicodeFromString': {
        if (args.length !== 1 || !ts.isStringLiteral(args[0])) refuse('EXPR', 'UnicodeFromString of a non-literal');
        const n = [...args[0].text].length; return AV(0, n + 1, { len: [n, n] }); // L
      }
      case '_dafny.areEqual': { vals(); return BOOL(undefined); } // L in the operand tree sizes
      case '_dafny.Seq.contains': case '_dafny.Seq.IsPrefixOf': case '_dafny.Seq.IsProperPrefixOf': { vals(); return BOOL(undefined); } // Q
      case '_dafny.Seq.Concat': { // L
        const [x, y] = vals();
        return AV(x.a + y.a, x.b + y.b, Object.assign(depthOf(x, y), x.len && y.len ? { len: [x.len[0] + y.len[0], x.len[1] + y.len[1]] } : {}));
      }
      case '_dafny.EuclideanDivision': case '_dafny.EuclideanModulo': { const [x] = vals(); return AV(x.a, x.b); } // Q
      case '_dafny.Seq.Create': { // n calls of a lambda; n must be bounded by the interval
        const n = this.expr(args[0], env); const fn = args[1];
        if (!fn || !(ts.isFunctionExpression(fn) || ts.isArrowFunction(fn)) || !ts.isBlock(fn.body)) refuse('EXPR', 'Seq.Create without a lambda');
        if (n.hi === undefined || n.hi > BigInt(LIMITS.TRIP_MAX)) {
          if (this.mutant !== 'no-loop') refuse('LOOP', 'sequence comprehension length not bounded by ' + LIMITS.TRIP_MAX);
        }
        const k = this.mutant === 'no-loop' ? 1 : Number(n.hi < 0n ? 0n : n.hi);
        let r = AV(0, 1, { len: [0, k], d: 1 });
        for (let i = 0; i < k; i++) { const v = this.call({ node: fn, name: 'lambda' }, [AV(0, 64, { lo: 0n, hi: BigInt(k) })], env); r = AV(r.a + v.a, r.b + v.b, { len: [0, k], d: Math.max(r.d, 1 + (v.d || 0)) }); this.check(r, 'Seq.Create'); }
        return r;
      }
    }
    // Methods on values (BigNumber, Seq, Set). The receiver type is fixed by the Dafny type of the expression.
    if (ts.isPropertyAccessExpression(callee)) {
      const name = callee.name.text;
      const recv = this.expr(callee.expression, env);
      const v = args.map((a) => this.expr(a, env));
      this._ops = [recv, ...v];
      const y = v[0];
      const iv = (f) => (recv.lo !== undefined && y && y.lo !== undefined ? f() : {});
      const exact = (r) => { if (r.lo !== undefined) { r.a = 0; r.b = Math.max(bits(r.lo), bits(r.hi)); } return r; };
      switch (name) {
        case 'plus': return exact(AV(Math.max(recv.a, y.a), Math.max(recv.b, y.b) + 1, iv(() => ({ lo: recv.lo + y.lo, hi: recv.hi + y.hi })))); // L
        case 'minus': return exact(AV(Math.max(recv.a, y.a), Math.max(recv.b, y.b) + 1, iv(() => ({ lo: recv.lo - y.hi, hi: recv.hi - y.lo })))); // L
        case 'multipliedBy': { // Q; bits add
          const extra = iv(() => { const c = [recv.lo * y.lo, recv.lo * y.hi, recv.hi * y.lo, recv.hi * y.hi]; return { lo: c.reduce((p, q) => (q < p ? q : p)), hi: c.reduce((p, q) => (q > p ? q : p)) }; });
          return exact(AV(recv.a + y.a, recv.b + y.b, extra));
        }
        case 'negated': return AV(recv.a, recv.b, recv.lo !== undefined ? { lo: -recv.hi, hi: -recv.lo } : {}); // L
        case 'mod': return AV(Math.min(recv.a, y.a), Math.min(recv.b, y.b)); // Q
        case 'isLessThan': return BOOL(recv.lo !== undefined && y.lo !== undefined ? (recv.hi < y.lo ? true : recv.lo >= y.hi ? false : undefined) : undefined);
        case 'isLessThanOrEqualTo': return BOOL(recv.lo !== undefined && y.lo !== undefined ? (recv.hi <= y.lo ? true : recv.lo > y.hi ? false : undefined) : undefined);
        case 'isEqualTo': return BOOL(recv.lo !== undefined && y.lo !== undefined ? (recv.lo === recv.hi && y.lo === y.hi && recv.lo === y.lo ? true : (recv.hi < y.lo || y.hi < recv.lo) ? false : undefined) : undefined);
        case 'contains': return BOOL(undefined); // Q (Set: linear scan with areEqual)
        case 'toNumber': return AV(0, 64, recv.lo !== undefined ? { lo: recv.lo, hi: recv.hi } : {}); // C
        case 'slice': { // L: a part of the receiver
          const r = AV(recv.a, recv.b, depthOf(recv));
          if (recv.len && v.length >= 1 && v[0].lo !== undefined && (v.length === 1)) r.len = [Math.max(0, recv.len[0] - Number(v[0].hi)), Math.max(0, recv.len[1] - Number(v[0].lo))];
          else if (recv.len) r.len = [0, recv.len[1]];
          return r;
        }
        case 'Union': return AV(recv.a + y.a, recv.b + y.b, depthOf(recv, y)); // Q
        case 'updateUnsafe': case 'update': { if (v.length !== 2) refuse('CALL', 'map update arity'); return AV(recv.a + v[0].a + v[1].a, recv.b + v[0].b + v[1].b + 1, { d: Math.max(recv.d || 0, 1 + Math.max(v[0].d || 0, v[1].d || 0)) }); } // Q (key search by areEqual)
        case 'get': return AV(recv.a, recv.b, depthOf(recv)); // Q: a value stored in the map
        case 'Intersect': case 'Difference': return AV(recv.a, recv.b, depthOf(recv)); // Q
        case 'IsSubsetOf': case 'IsProperSubsetOf': case 'IsDisjointFrom': case 'equals': return BOOL(undefined); // Q
      }
      refuse('CALL', 'method ' + name + ' is not an allow-listed runtime primitive');
    }
    refuse('CALL', 'unresolved call target ' + t.slice(0, 50));
  }
}

// ---------- load check ----------
function loadCheck(user, prefixIn, workRoot) {
  let prefix = prefixIn;
  if (prefix === null) {
    try { prefix = fs.readFileSync(PREFIX_FILE, 'utf8'); } catch (e) { refuse('LOAD', 'runtime prefix copy missing'); }
  }
  if (sha(prefix) !== PIN.prefix) refuse('LOAD', 'runtime prefix differs from the pin');
  fs.mkdirSync(workRoot, { recursive: true });
  const dir = fs.mkdtempSync(path.join(workRoot, 'load-')); // inside the repository: bignumber.js resolves upwards
  const mod = path.join(dir, 'model.cjs');
  fs.writeFileSync(mod, prefix + user + '\nmodule.exports = { Refund, runtime: _dafny };\n');
  const probe = "const m = require(process.argv[1]); const A = m && m.Refund && m.Refund.__default && " +
    "Object.getOwnPropertyDescriptor(m.Refund.__default, 'Assess'); " +
    "if (!A || typeof A.value !== 'function' || A.value.length !== 2) { console.log('NO_ASSESS'); process.exit(3); } console.log('LOADED');";
  // Hard limits: scrubbed environment, 2 s wall clock (SIGKILL), 200 MB heap. Loading runs only module frames
  // and class definitions: the shape check above admits no other top-level code.
  const r = childProcess.spawnSync(NODE, ['--max-old-space-size=200', '-e', probe, mod],
    { env: { PATH: path.dirname(NODE) + ':/usr/bin:/bin', HOME: dir }, cwd: dir, encoding: 'utf8', timeout: 2000, killSignal: 'SIGKILL' });
  fs.rmSync(dir, { recursive: true, force: true });
  if (r.status !== 0 || !/LOADED/.test(r.stdout)) {
    const why = (r.stderr || '').split('\n').find((l) => /Error/.test(l)) || ('status ' + r.status + ' signal ' + r.signal);
    refuse('LOAD', 'module does not load or export Assess(context, response): ' + why.slice(0, 100));
  }
}

// Linear scan, before parsing: bracket nesting depth outside strings and comments (a crude, fail-closed bound:
// a deeper file is refused, so the recursive parser and interpreter never see deep nesting).
function nestingScan(t) {
  let d = 0, max = 0, q = null;
  for (let i = 0; i < t.length; i++) {
    const c = t[i];
    if (q) { if (c === '\\') i++; else if (c === q) q = null; continue; }
    if (c === '"' || c === "'" || c === '`') { q = c; continue; }
    if (c === '/' && t[i + 1] === '/') { while (i < t.length && t[i] !== '\n') i++; continue; }
    if (c === '/' && t[i + 1] === '*') { const e = t.indexOf('*/', i + 2); if (e < 0) refuse('INPUT', 'unterminated comment'); i = e + 1; continue; }
    if (c === '(' || c === '[' || c === '{') { d++; if (d > max) max = d; if (d > LIMITS.NEST_MAX) refuse('INPUT', 'syntax nesting deeper than ' + LIMITS.NEST_MAX); }
    else if (c === ')' || c === ']' || c === '}') d--;
  }
}
function checkFile(file, opts) {
  const res = { file: path.basename(file), verdict: 'REFUSE', code: '', detail: '', steps: 0, maxA: 0, maxB: 0 };
  let it = null;
  try {
    const text = fs.readFileSync(file, 'utf8');
    const { user, prefix } = splitInput(text);
    if (Buffer.byteLength(user) > LIMITS.USER_BYTES_MAX) refuse('INPUT', 'compiled modules larger than ' + LIMITS.USER_BYTES_MAX + ' bytes');
    nestingScan(user);
    const sf = ts.createSourceFile('model.js', user, ts.ScriptTarget.ES2022, true, ts.ScriptKind.JS);
    const classes = checkShape(sf, user);
    it = new Interp(classes, sf, opts.mutant);
    it.run();
    if (!opts.noLoad && opts.mutant !== 'no-load') loadCheck(user, prefix, opts.work);
    res.verdict = 'ACCEPT'; res.code = 'BOUNDED';
    res.detail = 'steps<=' + it.steps + ' size<=' + it.maxA + '*N+' + it.maxB + ' cost<=' + it.cost[0] + '+' + it.cost[1] + '*N+' + it.cost[2] + '*N^2';
  } catch (err) {
    if (!(err instanceof Refuse)) { res.code = err instanceof RangeError ? 'CHECKER_DEPTH' : 'CHECKER_ERROR'; res.detail = String(err && err.stack || err).split('\n').slice(0, 2).join(' | '); }
    else { res.code = err.code; res.detail = err.detail; }
  }
  if (it) { res.steps = it.steps; res.maxA = it.maxA; res.maxB = it.maxB; }
  return res;
}

if (require.main === module) {
  const argv = process.argv.slice(2);
  const opts = { mutant: null, noLoad: false, work: path.join(os.tmpdir(), 'js-bound-check') };
  const files = [];
  for (const a of argv) {
    if (a.startsWith('--mutant=')) opts.mutant = a.slice(9);
    else if (a === '--no-load') opts.noLoad = true;
    else if (a.startsWith('--work=')) opts.work = path.resolve(a.slice(7));
    else files.push(a);
  }
  let refused = 0;
  for (const f of files) { const r = checkFile(f, opts); if (r.verdict !== 'ACCEPT') refused++; console.log(JSON.stringify(r)); }
  process.exit(files.length === 1 ? (refused ? 1 : 0) : 0);
}
module.exports = { checkFile, LIMITS, PIN };

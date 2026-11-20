'use strict';
// booking_check.cjs: the inventory airlock's call of the Dafny-compiled Slice 3 checker (Goal 20).
//
// Usage: node booking_check.cjs <model.cjs>   (or `node -e <this source> -- <model.cjs>`: the engine embeds this
//        file at compile time and runs it that way; it reads no helper file at run time)
//   stdin : one JSON object with exactly the keys A, c, w, x, y, z, alpha_bps (at most 1 MiB).
//   stdout: "ACCEPT\n", exit 0, only when the compiled method VerifyCertifiedBooking returns true.
//           "REJECT\n", exit 1, only when it returns false.
//   exit 2: malformed input, a wrong model file, or any exception. A message goes to stderr. Nothing goes to stdout.
//
// Label: PROVED CORE source (proposals/forge2-pillar3-dual-certificate/BookingDualCert.dfy, method
// VerifyCertifiedBooking, ensures ok == Accepts(A, c, w, x, y, z, alpha_bps)). This file decides NOTHING itself.
// It parses, converts to Dafny values (BigNumber integers, Dafny sequences) and calls the compiled method.
// Dimension mismatches, negative duals, non-binary x, alpha_bps > 10000: all go to the compiled method, which
// rejects them. This file refuses only input that it cannot convert (exit 2).
//
// Model pin: the module must have the SHA-256 below, the module_sha256 of the tracked record
// proposals/forge2-pillar3-dual-certificate/benchmark/records/build-record.json. Build it with
// src/airlock/node/build_checker.py (output build/airlock/checker/model.cjs). The file is opened once with
// O_NOFOLLOW, hashed, and the SAME bytes are compiled. There is no second read by path.
//
// Trusted (not proved): the Dafny 4.11.0 JavaScript compiler, the Dafny JavaScript runtime inside the module,
// bignumber.js 9.3.1 (the runtime's dependency, pinned in package-lock.json; it is loaded from node_modules and
// is NOT covered by the pin), Node 24.3.0 (including the internal Module._compile), and the conversion code here.
//
// Input grammar (strict; stricter than JSON):
//   - ASCII only. Whitespace between tokens: space, tab, LF, CR.
//   - Strings contain only [A-Za-z0-9_-]. No escapes. Numbers, true, false, null are refused.
//   - Keys: exactly A, c, w, x, y, z, alpha_bps; each once (a duplicate key is refused).
//   - A: array of arrays of integer strings. c, w, x, y, z: arrays of integer strings. alpha_bps: a nat string.
//   - Integer string: 0 or -?[1-9][0-9]* (no "-0", no leading zeros, no "+"), at most 64 characters.
//     alpha_bps: 0 or [1-9][0-9]* (the Dafny type is nat), at most 64 characters.
// Bounds: input <= 1048576 bytes; each vector and each row of A <= 4096 entries; A <= 4096 rows; A <= 65536
// entries in total. Empty arrays are allowed and go to the compiled method.

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const Module = require('node:module');

const PINNED_MODEL_SHA256 = 'e705ec490e30572cc783da2d7f927d5b4201f6bec0bc0a64c9cde507384b85f4';
const MAX_INPUT = 1048576;
const MAX_MODEL = 4194304;
const MAX_INT_CHARS = 64;
const MAX_VEC = 4096;
const MAX_CELLS = 65536;
const KEYS = ['A', 'c', 'w', 'x', 'y', 'z', 'alpha_bps'];
const INT_RE = /^(0|-?[1-9][0-9]*)$/;
const NAT_RE = /^(0|[1-9][0-9]*)$/;

let finished = false;

function finish(code, out, err) {
  if (finished) return;
  finished = true;
  try {
    if (err) fs.writeSync(2, 'booking_check: ' + err + '\n');
    if (out) fs.writeSync(1, out);
  } catch (e) {
    code = 2;
  }
  process.exit(code);
}

function fail(message) {
  finish(2, null, message);
}

class InputError extends Error {}

// A strict scanner for the grammar above. It returns {key: value} with string leaves.
function parseInput(buf) {
  let i = 0;
  const n = buf.length;
  const bad = (what) => { throw new InputError(what + ' at byte ' + i); };
  const ws = () => { while (i < n && (buf[i] === 0x20 || buf[i] === 0x09 || buf[i] === 0x0a || buf[i] === 0x0d)) i++; };
  const expect = (ch) => { ws(); if (i >= n || buf[i] !== ch.charCodeAt(0)) bad('expected ' + JSON.stringify(ch)); i++; };
  const str = () => {
    ws();
    if (i >= n || buf[i] !== 0x22) bad('expected a string');
    i++;
    const start = i;
    while (i < n && buf[i] !== 0x22) {
      const b = buf[i];
      const ok = (b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5a) || (b >= 0x61 && b <= 0x7a) || b === 0x5f || b === 0x2d;
      if (!ok) bad('character not allowed in a string');
      if (i - start >= MAX_INT_CHARS) bad('string too long');
      i++;
    }
    if (i >= n) bad('unterminated string');
    const s = buf.toString('latin1', start, i);
    i++;
    return s;
  };
  const peek = () => { ws(); return i < n ? buf[i] : -1; };
  const list = (item, limit) => {
    expect('[');
    const out = [];
    if (peek() === 0x5d) { i++; return out; }
    for (;;) {
      if (out.length >= limit) bad('array too long');
      out.push(item());
      const p = peek();
      if (p === 0x2c) { i++; continue; }
      if (p === 0x5d) { i++; return out; }
      bad('expected "," or "]"');
    }
  };
  let cells = 0;
  const intStr = () => {
    const s = str();
    if (!INT_RE.test(s)) bad('not a canonical integer string');
    return s;
  };
  const row = () => {
    const r = list(intStr, MAX_VEC);
    cells += r.length;
    if (cells > MAX_CELLS) bad('A has too many entries');
    return r;
  };
  const result = Object.create(null);
  expect('{');
  for (;;) {
    const key = str();
    if (!KEYS.includes(key)) bad('unknown key ' + JSON.stringify(key));
    if (key in result) bad('duplicate key ' + JSON.stringify(key));
    expect(':');
    if (key === 'A') result[key] = list(row, MAX_VEC);
    else if (key === 'alpha_bps') {
      const s = str();
      if (!NAT_RE.test(s)) bad('alpha_bps is not a canonical nat string');
      result[key] = s;
    } else result[key] = list(intStr, MAX_VEC);
    const p = peek();
    if (p === 0x2c) { i++; continue; }
    if (p === 0x7d) { i++; break; }
    bad('expected "," or "}"');
  }
  ws();
  if (i !== n) bad('trailing bytes');
  for (const k of KEYS) if (!(k in result)) throw new InputError('missing key ' + JSON.stringify(k));
  return result;
}

// Reads the model once through one descriptor, checks the pin, compiles the same bytes.
function loadModel(file) {
  const abs = path.resolve(file);
  const fd = fs.openSync(abs, fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW | fs.constants.O_NONBLOCK);
  let bytes;
  try {
    const st = fs.fstatSync(fd);
    if (!st.isFile()) throw new Error('model is not a regular file');
    if (st.size > MAX_MODEL) throw new Error('model is too large');
    bytes = Buffer.alloc(st.size);
    let got = 0;
    while (got < st.size) {
      const r = fs.readSync(fd, bytes, got, st.size - got, got);
      if (r === 0) throw new Error('model file became shorter while read');
      got += r;
    }
  } finally {
    fs.closeSync(fd);
  }
  const digest = crypto.createHash('sha256').update(bytes).digest('hex');
  if (digest !== PINNED_MODEL_SHA256) throw new Error('model SHA-256 ' + digest + ' is not the pinned ' + PINNED_MODEL_SHA256);
  const m = new Module(abs, null);
  m.filename = abs;
  m.paths = Module._nodeModulePaths(path.dirname(abs));
  m._compile(bytes.toString('utf8'), abs);
  const ex = m.exports;
  const D = ex && ex.BookingDualCert && ex.BookingDualCert.__default;
  const rt = ex && ex.runtime;
  if (!D || typeof D.VerifyCertifiedBooking !== 'function') throw new Error('model has no VerifyCertifiedBooking');
  if (!rt || !rt.Seq || typeof rt.Seq.of !== 'function' || !rt.ZERO) throw new Error('model has no Dafny runtime');
  return { verify: D.VerifyCertifiedBooking, Seq: rt.Seq, BigNumber: rt.ZERO.constructor };
}

function decide(model, input) {
  const { BigNumber, Seq } = model;
  const int = (s) => {
    const v = new BigNumber(s, 10);
    if (!v.isInteger() || v.toFixed() !== s) throw new Error('integer conversion is not exact for ' + s);
    return v;
  };
  const seq = (a) => Seq.of(...a.map(int));
  const A = Seq.of(...input.A.map(seq));
  const ok = model.verify(A, seq(input.c), seq(input.w), seq(input.x), seq(input.y), seq(input.z), int(input.alpha_bps));
  if (ok === true) return true;
  if (ok === false) return false;
  throw new Error('the compiled method returned a value that is not a boolean');
}

function main() {
  process.on('uncaughtException', (e) => fail('exception: ' + (e && e.message)));
  // As a file: argv [node, file, model]. From source (`node -e <source> -- <model>`, as the engine runs it): [node, model].
  const args = process.argv.slice(module.id === '[eval]' ? 1 : 2);
  if (args.length !== 1) return fail('usage: node booking_check.cjs <model.cjs>');
  let model;
  try {
    model = loadModel(args[0]);
  } catch (e) {
    return fail('model: ' + (e && e.message));
  }
  const chunks = [];
  let size = 0;
  process.stdin.on('data', (chunk) => {
    if (finished) return;
    size += chunk.length;
    if (size > MAX_INPUT) {
      process.stdin.destroy();
      return fail('input is larger than ' + MAX_INPUT + ' bytes');
    }
    chunks.push(chunk);
  });
  process.stdin.on('error', (e) => fail('stdin: ' + (e && e.message)));
  process.stdin.on('end', () => {
    if (finished) return;
    let accepted;
    try {
      const input = parseInput(Buffer.concat(chunks));
      accepted = decide(model, input);
    } catch (e) {
      return fail((e instanceof InputError ? 'malformed input: ' : 'exception: ') + (e && e.message));
    }
    if (accepted === true) return finish(0, 'ACCEPT\n', null);
    if (accepted === false) return finish(1, 'REJECT\n', null);
    return fail('no decision');
  });
}

main();

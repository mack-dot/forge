// harness.cjs SET MODULE.cjs... : runs supervise.cjs on every module x every input of the battery, one run at a time.
// Never loads a module under test. The SPEC answer comes from the pinned core (reference Refund.Assess, proved R1-R5).
// Per run: one JSON line {set, mod, inp, spec, exit, cause, wall_ms, pg_alive, unsafe}. Must-be-zero: unsafe, pg_alive, over.
'use strict';
const fs = require('fs'), path = require('path'), cp = require('child_process');
const HERE = __dirname, NODE = '/opt/homebrew/Cellar/node/24.3.0/bin/node';
const core = require(path.join(HERE, 'core/model.cjs')), R = core.Refund, D = core.runtime, BN = require('bignumber.js');
const MAX = '9223372036854775807';
const ctx = (o) => ({ chargeId: 'ch_1', requestId: 'rq_1', original: '1000', remaining: '1000', refundEnabled: true, requestOpen: true, ...o });
const cand = (amount, reason) => ({ kind: 'Candidate', amount, reason });
const BATTERY = {
  elig5: [ctx(), cand('5', 'duplicate_charge')], zero: [ctx(), cand('0', 'returned_item')],
  full1000: [ctx(), cand('1000', 'service_not_delivered')], over: [ctx(), cand('1001', 'duplicate_charge')],
  badreason: [ctx(), cand('5', 'free_money')], closed: [ctx({ requestOpen: false }), cand('5', 'duplicate_charge')],
  failed: [ctx(), { kind: 'Failed' }], key123456789: [ctx({ original: MAX, remaining: MAX }), cand('123456789', 'duplicate_charge')],
  cr: [ctx(), cand('5', 'x\ry')], big200k: [ctx({ chargeId: 'c'.repeat(200000) }), cand('5', 'duplicate_charge')],
  maxmoney: [ctx({ original: MAX, remaining: MAX }), cand(MAX, 'duplicate_charge')], negrem: [ctx({ remaining: '-1' }), cand('0', 'duplicate_charge')],
  len3: [ctx({ chargeId: 'abc', original: MAX, remaining: MAX }), cand('5', 'duplicate_charge')], disabled: [ctx({ refundEnabled: false }), cand('5', 'duplicate_charge')],
};
const text = (s) => { const q = new D.Seq(); for (const ch of s) q.push(new D.CodePoint(ch.codePointAt(0))); return q; };
function spec([c, r]) {
  const C = R.Context.create_ChargeContext(text(c.chargeId), text(c.requestId), new BN(c.original), new BN(c.remaining), c.refundEnabled, c.requestOpen);
  const M = r.kind === 'Candidate' ? R.ModelResponse.create_Candidate(new BN(r.amount), text(r.reason)) : R.ModelResponse['create_' + r.kind]();
  return R.__default.Assess(C, M)[0].is_Authorized ? 'Authorized' : 'Rejected';
}
const SPEC = Object.fromEntries(Object.entries(BATTERY).map(([k, v]) => [k, spec(v)]));
const only = process.env.ONLY ? process.env.ONLY.split(',') : null;
const [set, ...mods] = process.argv.slice(2);
for (const mod of mods) {
  for (const [inp, [context, response]] of Object.entries(BATTERY)) {
    if (only && !only.includes(inp)) continue;
    const t = Date.now();
    const r = cp.spawnSync(NODE, [path.join(HERE, 'supervise.cjs'), mod, '--stdin'], {
      input: JSON.stringify({ context, response }), env: { PATH: '/usr/bin:/bin' }, encoding: 'utf8', timeout: 15000, killSignal: 'SIGKILL', maxBuffer: 1 << 20 });
    const wall = Date.now() - t;
    let o = {}; try { o = JSON.parse(r.stdout.trim().split('\n').pop()); } catch { o = { exit: 'NO-JSON', cause: String(r.stdout).slice(0, 80) }; }
    const pid = o.pid;
    const alive = pid ? cp.spawnSync('/bin/ps', ['-o', 'pid=', '-g', String(pid)], { encoding: 'utf8' }).stdout.trim() : '';
    const unsafe = r.status === 0 && SPEC[inp] !== 'Authorized';
    const match = (SPEC[inp] === 'Authorized' && r.status === 0) || (SPEC[inp] === 'Rejected' && r.status === 10);
    console.log(JSON.stringify({ set, mod: path.basename(mod, '.cjs'), inp, spec: SPEC[inp], exit: r.status, cause: o.cause, sup_ms: o.ms,
      wall_ms: wall, pg_alive: alive !== '', unsafe, match, detail: String(o.detail || o.stderr || '').slice(0, 100) }));
  }
}

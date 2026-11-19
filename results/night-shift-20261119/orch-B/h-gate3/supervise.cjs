// supervise.cjs MODULE.cjs CONTEXT.json RESPONSE.json   (or: supervise.cjs MODULE.cjs --stdin  with {context,response})
// Runs ONE Assess call of an UNTRUSTED compiled refund module in a confined child and fails closed.
// Safety does not depend on the module: an authorization is reported only after the PINNED, separately proved
// checker RefundFinality.Check (impl/RefundFinality.dfy, core module sha256 below) issues for the INPUT's candidate.
// Exit: 0 authorized-and-checked; 10 refused by the module; 20 timeout; 21 memory; 22 crash; 23 throw;
// 24 output contract; 25 check failed; 26 confinement violation; 27 bad input or supervisor configuration.
// One JSON line on stdout. Test prototype (night shift 2026-11-19, h-gate3). NOT gate code. NOT proved.
'use strict';
const fs = require('fs'), path = require('path'), cp = require('child_process'), crypto = require('crypto');
const HERE = __dirname;
const NODE = process.env.SUPERVISE_NODE || '/opt/homebrew/Cellar/node/24.3.0/bin/node';
const CORE = process.env.SUPERVISE_CORE || path.join(HERE, 'core/model.cjs');
const CORE_SHA = 'e6d5f5e54405f2767de59e054c329b86fc5d769c873c055c08780e89fbd906ce'; // proposals/forge2-slice1-refund-finality/records/evidence.json
const PROFILE = path.join(HERE, 'child.sb');
const BN_DIR = path.join(HERE, '../../../../node_modules/bignumber.js');
const WALL_MS = Number(process.env.SUPERVISE_WALL_MS || 2000), HEAP_MB = 64, RSS_KB = 120 * 1024, ERR_MAX = 65536;
const t0 = process.hrtime.bigint();
const ms = () => Number(process.hrtime.bigint() - t0) / 1e6;
let childPid = null;
const done = (code, cause, extra) => { process.stdout.write(JSON.stringify({ exit: code, cause, ms: Math.round(ms()), pid: childPid, ...extra }) + '\n'); process.exit(code); };

// ---- Inputs: data only. Integers are decimal texts (mathematical integers of the spec). ----
const INT = /^-?(0|[1-9][0-9]{0,99})$/, KINDS = ['Missing', 'TimedOut', 'Failed', 'Malformed', 'Oversized', 'Unsupported'];
function inputs() {
  const a = process.argv.slice(2);
  const raw = a[1] === '--stdin' ? JSON.parse(fs.readFileSync(0, 'utf8')) :
    { context: JSON.parse(fs.readFileSync(a[1], 'utf8')), response: JSON.parse(fs.readFileSync(a[2], 'utf8')) };
  const c = raw.context, r = raw.response, keys = (o) => Object.keys(o).sort().join(',');
  if (keys(c) !== 'chargeId,original,refundEnabled,remaining,requestId,requestOpen' || typeof c.chargeId !== 'string' ||
      typeof c.requestId !== 'string' || !INT.test(c.original) || !INT.test(c.remaining) ||
      typeof c.refundEnabled !== 'boolean' || typeof c.requestOpen !== 'boolean') throw new Error('context shape');
  if (!(r.kind === 'Candidate' ? keys(r) === 'amount,kind,reason' && INT.test(r.amount) && typeof r.reason === 'string'
                               : keys(r) === 'kind' && KINDS.includes(r.kind))) throw new Error('response shape');
  return { module: a[0], context: c, response: r };
}
let input; try { input = inputs(); } catch (e) { done(27, 'input', { detail: String(e.message) }); }
const OUT_MAX = 2 * JSON.stringify(input).length + 65536;   // the answer echoes the caller-bound ids once

// ---- The trusted checker: the pinned compiled core, loaded in THIS process only after its digest matches. ----
let F, R, D, BN;
try {
  const bytes = fs.readFileSync(CORE);
  if (crypto.createHash('sha256').update(bytes).digest('hex') !== CORE_SHA) throw new Error('core digest differs');
  const core = require(CORE); F = core.RefundFinality; R = core.Refund; D = core.runtime; BN = require(path.join(BN_DIR, 'bignumber.js'));
} catch (e) { done(27, 'supervisor-config', { detail: String(e.message) }); }
const text = (s) => { const q = new D.Seq(); for (const ch of s) q.push(new D.CodePoint(ch.codePointAt(0))); return q; }; // no spread
// Safety check of a claimed authorization. true only if Check issues a token for the INPUT's own candidate
// and the module's answer equals that checked transition exactly (spec R4: amount, reason, caller-bound intent).
function checkAuthorized(c, r, ans) {
  if (r.kind !== 'Candidate' || c.requestOpen !== true) return false;           // ContextOf fixes requestOpen := true
  if (ans.amount !== r.amount || ans.reason !== r.reason || ans.plan.length !== 1) return false;
  const want = { chargeId: c.chargeId, requestId: c.requestId, amount: r.amount, reason: r.reason }, got = ans.plan[0];
  if (Object.keys(got).sort().join(',') !== 'amount,chargeId,reason,requestId' || Object.keys(want).some((k) => got[k] !== want[k])) return false;
  const pre = F.Charge.create_Charge(text(c.chargeId), new BN(c.original), new BN(c.remaining), c.refundEnabled);
  const post = F.Charge.create_Charge(text(c.chargeId), new BN(c.original), new BN(c.remaining).minus(new BN(r.amount)), c.refundEnabled);
  const t = F.Transition.create_Transition(F.Request.create_Request(text(c.requestId), new BN(r.amount), text(r.reason)), post,
    R.RefundIntent.create_Intent(text(c.chargeId), text(c.requestId), new BN(r.amount), text(r.reason)));
  const [verdict, plan] = F.__default.Check(pre, text(''), t);
  return verdict.is_Issue === true && plan.length === 1;
}

// ---- The child: a fresh directory D holding only the module, the runner and bignumber.js; read-only. ----
const RUNNER = `'use strict';
const fs = require('fs'), write = fs.writeSync, exit = process.exit.bind(process), stringify = JSON.stringify;
const out = (code, o) => { write(1, stringify(o) + '\\n'); exit(code); };
const denied = (e) => e && (e.code === 'ERR_ACCESS_DENIED' || e.code === 'EPERM');
const input = JSON.parse(fs.readFileSync(0, 'utf8'));
let m; try { m = require('./model.cjs'); } catch (e) { out(denied(e) ? 4 : 3, { thrown: 'load: ' + String(e && e.message).slice(0, 200) }); }
try {
  const R = m.Refund, D = m.runtime, BN = require('bignumber.js'), c = input.context, r = input.response;
  const text = (s) => { const q = new D.Seq(); for (const ch of s) q.push(new D.CodePoint(ch.codePointAt(0))); return q; };
  const ctx = R.Context.create_ChargeContext(text(c.chargeId), text(c.requestId), new BN(c.original), new BN(c.remaining), c.refundEnabled, c.requestOpen);
  const resp = r.kind === 'Candidate' ? R.ModelResponse.create_Candidate(new BN(r.amount), text(r.reason)) : R.ModelResponse['create_' + r.kind]();
  const res = R.__default.Assess(ctx, resp);
  if (!Array.isArray(res) || res.length !== 2) out(5, { contract: 'Assess did not return [decision, plan]' });
  const num = (x) => { if (!BN.isBigNumber(x) || !x.isInteger()) throw new TypeError('not an integer'); return x.toFixed(); };
  const str = (x) => { const v = x.toVerbatimString(false); if (typeof v !== 'string') throw new TypeError('not a text'); return v; };
  const d = res[0], p = Array.from(res[1]);
  if (p.length > 4) out(5, { contract: 'plan too long' });
  const plan = p.map((i) => ({ chargeId: str(i.dtor_chargeId), requestId: str(i.dtor_requestId), amount: num(i.dtor_amount), reason: str(i.dtor_reason) }));
  if (d.is_Rejected === true && d.is_Authorized !== true) out(0, { decision: 'Rejected', plan });
  if (d.is_Authorized === true && d.is_Rejected !== true) out(0, { decision: 'Authorized', amount: num(d.dtor_amount), reason: str(d.dtor_reason), plan });
  out(5, { contract: 'decision is neither Rejected nor Authorized' });
} catch (e) { out(denied(e) ? 4 : 3, { thrown: String(e && e.name) + ': ' + String(e && e.message).slice(0, 200) }); }
`;
const FILES = ['model.cjs', 'node_modules', 'runner.cjs'];
let dir;
try {
  dir = fs.realpathSync(fs.mkdtempSync(path.join(process.env.SUPERVISE_TMP || path.join(HERE, 'work'), 'supervise-')));
  fs.copyFileSync(input.module, path.join(dir, 'model.cjs'));
  fs.mkdirSync(path.join(dir, 'node_modules/bignumber.js'), { recursive: true });
  for (const f of ['bignumber.js', 'package.json']) fs.copyFileSync(path.join(BN_DIR, f), path.join(dir, 'node_modules/bignumber.js', f));
  fs.writeFileSync(path.join(dir, 'runner.cjs'), RUNNER);
} catch (e) { done(27, 'supervisor-config', { detail: String(e.message) }); }
const argv = ['-D', 'D=' + dir, '-f', PROFILE, NODE, '--no-warnings', '--permission', '--allow-fs-read=' + dir,
  '--disallow-code-generation-from-strings', '--max-old-space-size=' + HEAP_MB, '--max-semi-space-size=8', 'runner.cjs'];
const child = cp.spawn('/usr/bin/sandbox-exec', argv, { cwd: dir, env: {}, detached: true, stdio: ['pipe', 'pipe', 'pipe'] });
childPid = child.pid;
const killGroup = () => { try { process.kill(-child.pid, 'SIGKILL'); } catch { /* group already gone */ } };
let stdout = Buffer.alloc(0), stderr = Buffer.alloc(0), killed = null;
const kill = (why) => { if (!killed) killed = why; killGroup(); };
child.stdout.on('data', (b) => { stdout = Buffer.concat([stdout, b]); if (stdout.length > OUT_MAX) kill('contract'); });
child.stderr.on('data', (b) => { stderr = Buffer.concat([stderr, b]); if (stderr.length > ERR_MAX) kill('contract'); });
child.stdin.on('error', () => {});
child.stdin.end(JSON.stringify({ context: input.context, response: input.response }));
const wall = setTimeout(() => kill('timeout'), WALL_MS);
const rss = setInterval(() => {            // resident memory of the child (V8 heap cap does not cover buffers)
  const r = cp.spawnSync('/bin/ps', ['-o', 'rss=', '-p', String(child.pid)], { encoding: 'utf8' });
  if (Number(r.stdout) > RSS_KB) kill('memory');
}, 100);
child.on('close', (code, signal) => {
  clearTimeout(wall); clearInterval(rss); killGroup();
  let extra = []; try { extra = fs.readdirSync(dir).filter((f) => !FILES.includes(f)); fs.rmSync(dir, { recursive: true, force: true }); } catch { /* fail closed below */ }
  const err = stderr.toString('utf8'), info = { child_exit: code, signal, stderr: err.slice(0, 160) };
  if (extra.length) done(26, 'confinement', { ...info, detail: 'new files in D: ' + extra.join(',') });
  if (killed === 'timeout') done(20, 'timeout', info);
  if (killed === 'memory' || /heap out of memory|Reached heap limit/.test(err)) done(21, 'memory', info);
  if (killed === 'contract') done(24, 'contract', { ...info, detail: 'output over ' + OUT_MAX + ' bytes' });
  const lines = stdout.toString('utf8').split('\n');
  let ans = null; try { ans = lines.length === 2 && lines[1] === '' ? JSON.parse(lines[0]) : null; } catch { ans = null; }
  if (code === 4) done(26, 'confinement', { ...info, detail: ans && ans.thrown });
  if (code === 3) done(23, 'throw', { ...info, detail: ans && ans.thrown });
  if (code !== 0 || signal) done(code === 5 ? 24 : 22, code === 5 ? 'contract' : 'crash', { ...info, detail: ans && ans.contract });
  if (err !== '' || ans === null || typeof ans !== 'object') done(24, 'contract', { ...info, detail: 'not exactly one JSON line, or stderr output' });
  const okPlan = Array.isArray(ans.plan) && ans.plan.every((i) => i && typeof i === 'object');
  if (ans.decision === 'Rejected' && okPlan && ans.plan.length === 0 && Object.keys(ans).length === 2) done(10, 'refused-by-module', {});
  let ok = false;
  try { ok = ans.decision === 'Authorized' && okPlan && Object.keys(ans).length === 4 && checkAuthorized(input.context, input.response, ans); }
  catch (e) { ok = false; }
  if (!ok) done(25, 'check-failed', { detail: JSON.stringify(ans).slice(0, 160) });
  done(0, 'authorized-and-checked', { amount: ans.amount, reason: ans.reason });
});

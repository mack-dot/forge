// ts_part.ts: the TypeScript half of the unbreakable_store demo, and the TS driver of tests/airlock/test_sdk.py.
// Node built-ins + sdk/ts/forge_airlock.ts only. Run: node examples/unbreakable_store/ts_part.ts <plan.json>
//
// It runs a plan of steps through ONE sdk/ts Store (one `serve` child) and prints ONE JSON line: what the SDK
// returned for each step (typed code or error class). It decides nothing and checks nothing; the Python caller
// compares the answers with the store's WAL (`replay`). (It lives here, not under tests/, because tsconfig.json
// type-checks tests/**/*.ts with the TypeScript compiler and this file uses CommonJS `require`.)
//
// Plan: {"store": DIR, "node": PATH, "python": PATH (runs bin/forge-airlock), "engine_dir": DIR, "serve_argv": [..] (optional; a labelled
//        STAND-IN engine for protocol tests),
//        "timeout_ms": N, "steps": [STEP...]}
// STEP: {"do": "get"|"commit"|"read"|"lease"|"sweep"|"state"|"replay"|"kill"|"raw", ...}; a string "$name" in
//       fields is replaced by a value saved earlier with "save": "name" (the state hash of a get or commit).

const fs = require('node:fs');
const pathMod = require('node:path');
const fa = require(pathMod.join(__dirname, '..', '..', 'sdk', 'ts', 'forge_airlock.ts'));

type Step = Record<string, any>;
type Out = Record<string, unknown>;

function subst(v: any, saved: Record<string, string>): any {
  if (typeof v === 'string' && v.startsWith('$') && v.slice(1) in saved) return saved[v.slice(1)];
  if (Array.isArray(v)) return v.map((x) => subst(x, saved));
  if (v && typeof v === 'object') {
    const o: Record<string, any> = {};
    for (const k of Object.keys(v)) o[k] = subst(v[k], saved);
    return o;
  }
  return v;
}

function describe(r: any): Out {
  return { code: r.code, detail: r.detail, committed: r.committed, state_hash: r.stateHash, lease_closed: r.leaseClosed,
    rows: r.rows ? r.rows.length : 0, rows_bytes: r.rows && r.rows.length ? Buffer.byteLength(JSON.stringify(r.rows)) : 0,
    dropped: r.dropped, fields: r.fields };
}

function describeError(e: any): Out {
  return { error: e && e.name ? e.name : String(e), code: e && e.code, detail: e && e.detail, outcome_known: e && e.outcomeKnown,
    message: e && e.message ? String(e.message).slice(0, 300) : '' };
}

// The webhook handlers of the demo app. Each one gets the open lease.
async function handler(kind: string, lease: any, store: any, step: Step, saved: Record<string, string>): Promise<Out> {
  if (kind === 'commit') {
    const r = await lease.commit(step.op, subst(step.fields, saved));
    return describe(r);
  }
  if (kind === 'typeerror_before_sink') {
    const webhookEvent: any = JSON.parse(step.event || 'null');
    // the bug: the event has no `data` object; reading a field of undefined throws a real TypeError
    const amountCents: number = webhookEvent.data.object.amount;
    await lease.commit('refund', Object.assign({}, subst(step.fields, saved), { amount: amountCents }));
    return { unreachable: true };
  }
  if (kind === 'return_without_sink') {
    return { returned: true };
  }
  throw new Error('unknown handler kind ' + kind);
}

async function runStep(store: any, step: Step, saved: Record<string, string>): Promise<Out> {
  const d = step.do;
  if (d === 'get') {
    const r = await store.get(step.tenant, step.key);
    if (step.save && r.stateHash) saved[step.save] = r.stateHash;
    return describe(r);
  }
  if (d === 'commit') {
    const r = await store.commit(step.op, subst(step.fields, saved));
    if (step.save && r.stateHash) saved[step.save] = r.stateHash;
    return describe(r);
  }
  if (d === 'read') return describe(await store.readScoped(step.tenant, step.rows));
  if (d === 'lease') {
    try {
      const inner = await store.withLease(step.request_id, step.deadline_ms, (lease: any) => handler(step.handler, lease, store, step, saved));
      return { handler_returned: inner };
    } catch (e: any) {
      return Object.assign({ handler_threw: true, is_type_error: e instanceof TypeError }, describeError(e));
    }
  }
  if (d === 'sweep') return describe(await store.sweep(step.now_ms));
  if (d === 'state') return describe(await store.state());
  if (d === 'replay') return { effects: await store.replay() };
  if (d === 'kill') { process.kill(store.pid, 'SIGKILL'); await new Promise((r) => setTimeout(r, 200)); return { killed: true }; }
  if (d === 'raw') return { answer: await store.raw(Buffer.from(step.line, 'latin1')) };
  throw new Error('unknown step ' + d);
}

async function main(): Promise<void> {
  const plan = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const opts: Record<string, unknown> = { node: plan.node, timeoutMs: plan.timeout_ms ?? 60000 };
  if (plan.serve_argv) opts.serveArgv = plan.serve_argv;
  if (plan.python) opts.python = plan.python;
  if (plan.engine_dir) opts.engineDir = plan.engine_dir;
  const store = new fa.Store(plan.store, opts);
  const saved: Record<string, string> = {};
  const outs: Out[] = [];
  const lat: number[] = [];
  for (const step of plan.steps) {
    const t0 = process.hrtime.bigint();
    let o: Out;
    try {
      o = await runStep(store, step, saved);
    } catch (e) {
      o = describeError(e);
    }
    lat.push(Number(process.hrtime.bigint() - t0) / 1e6);
    o.step = step.name ?? step.do;
    outs.push(o);
  }
  await store.close();
  process.stdout.write(JSON.stringify({ steps: outs, latency_ms: lat, peak_rss_bytes: process.resourceUsage().maxRSS * 1024 }) + '\n');
}

main().catch((e) => { process.stdout.write(JSON.stringify({ fatal: String(e && e.stack || e) }) + '\n'); process.exitCode = 1; });

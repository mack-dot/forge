// forge_airlock.ts: TypeScript SDK for the forge-airlock engine (Goal 20). Node built-ins only. end_to_end=false.
//
// Run with Node 24.3.0's built-in type stripping: `node your-file.ts` (no flag needed in 24.3.0). Only erasable
// syntax is used (no enum, no namespace, no parameter property). The file is CommonJS (the repository's
// package.json has "type": "commonjs"): load it with `const fa = require('<path>/sdk/ts/forge_airlock.ts')`.
//
// The SDK decides NO write. Same surface and rules as sdk/py/forge_airlock.py:
//   * one long-lived `forge-airlock serve <dir>` child per Store, over its pipes; the API is async (Promises);
//     requests go one at a time in call order (a queue). No spawnSync per call.
//   * typed results: COMMITTED, REJECTED_POLICY, REQUIRE_HUMAN_COSIGN, STALE_STATE_HASH, DUPLICATE_REQUEST_ID,
//     TENANT_ISOLATION_BREACH (readScoped only), DROPPED_OBLIGATION (from sweep), and OK for get/read/state.
//     Keys, request ids and leases are per tenant (review D3): a key of another tenant is UNKNOWN_KEY (an
//     EngineRefusal), exactly like a key that nobody opened.
//   * every other outcome REJECTS with an AirlockError subclass (LocalRefusal, EngineRefusal, EngineFault,
//     ProtocolError, EngineDead, EngineTimeout, LeaseNotOpened); never a commit. After ProtocolError, EngineDead,
//     EngineTimeout or EngineFault the Store is closed (fail closed).
//   * readScoped serializes each row ONCE (by index; a hole or an undefined entry is refused), sends exactly
//     those lines, and only after the engine answered exactly `OK <n>` returns NEW objects parsed from exactly
//     those lines (never the caller's objects: no toJSON, getter or later change can reach the result). The
//     engine checks only the TOP-LEVEL tenant_id. More than 100000 rows: LocalRefusal, nothing sent. Any answer
//     other than `OK <n>` or TENANT_ISOLATION_BREACH closes the client (the stream may be out of step).
//   * withLease(requestId, deadlineMs, tenant, key, handler) opens a durable lease bound to (request id, tenant,
//     key) before the handler runs and never closes it; only a terminal verdict for the same id on the same
//     tenant and key closes it; a throwing handler leaves it open. Only handlers that opened a lease are covered.
// Trust boundary (src/airlock/PROTOCOL.md section 11): every rule holds only against a caller that reaches the
// store THROUGH the engine. A process that can write the store folder can append records itself; a process that
// can start its own engine on the folder can ignore every check. The opener of a key is trusted for its tenant,
// `original` and facts; the tenant field is not authenticated. "The agent cannot self-cosign" needs BOTH the
// private key outside the agent's reach AND an agent that cannot write the store folder or run another engine on
// it (for example `serve` runs under another OS user and the agent holds only its pipe).
// Cosign: cosignMessage(action) returns the six-line message (`forge-airlock-cosign-v3`); the human signs it with
// `bin/forge-airlock cosign-sign <key-file>` (OpenSSH ssh-keygen; no Node) and passes the printed token as the
// `signature` of refund(). The engine verifies it with /usr/bin/ssh-keygen (a trusted assumption).
// Label: not trusted for a write decision; not proved. FINITE TEST only.

const childProcess = require('node:child_process');
const pathMod = require('node:path');

const ROOT: string = pathMod.resolve(__dirname, '..', '..');
const DISPATCHER: string = pathMod.join(ROOT, 'bin', 'forge-airlock');
const MAX_ANSWER = 1 << 17;
const ID_RE = /^[A-Za-z0-9_-]{1,24}$/;
const HASH_RE = /^[0-9a-f]{32}$/;
// A cosign signature token: the base64 body of one SSHSIG armor without line breaks (src/airlock/PROTOCOL.md section 7):
// 256 characters, canonical (the last data character carries no unused bit), ending with "==". The engine checks the rest.
const SIG_RE = /^[A-Za-z0-9+/]{253}[AQgw]==$/;
const DIGITS_RE = /^(0|[1-9][0-9]*)$/;
const MAX_READ_ROWS = 100000;
const REFUSALS = ['MALFORMED_REQUEST', 'UNKNOWN_KEY', 'HELPER_FAILED', 'BAD_FRAME'];
const FAULTS = ['EPOCH_REGRESSION', 'CORRUPT_WAL', 'IO_ERROR', 'OUTCOME_UNKNOWN', 'DISPATCH_FAILED'];
const COMMIT_TYPED = ['REJECTED_POLICY', 'REQUIRE_HUMAN_COSIGN', 'STALE_STATE_HASH', 'DUPLICATE_REQUEST_ID'];
const VERBS: Record<string, string> = {
  open_money: 'OPEN_MONEY', refund: 'REFUND', open_saga: 'OPEN_SAGA', saga: 'SAGA',
  open_inventory: 'OPEN_INVENTORY', book: 'BOOK',
};
const FIELDS: Record<string, string[]> = {
  open_money: ['tenant', 'key', 'request_id', 'policy', 'original', 'facts'],
  refund: ['tenant', 'key', 'request_id', 'pre_state_hash', 'reason', 'amount', 'signature'],
  open_saga: ['tenant', 'key', 'request_id', 'policy'],
  saga: ['tenant', 'key', 'request_id', 'pre_state_hash', 'to_state', 'processor', 'idempotency_key'],
  open_inventory: ['tenant', 'key', 'request_id', 'policy', 'capacities'],
  book: ['tenant', 'key', 'request_id', 'pre_state_hash', 'certificate'],
};

type Code = 'COMMITTED' | 'REJECTED_POLICY' | 'REQUIRE_HUMAN_COSIGN' | 'STALE_STATE_HASH' | 'DUPLICATE_REQUEST_ID'
  | 'TENANT_ISOLATION_BREACH' | 'DROPPED_OBLIGATION' | 'OK';
type Amount = number | bigint | string;
type Fields = Record<string, unknown>;

// ------------------------------------------------------------------------------------------------ errors

class AirlockError extends Error {
  code: string;
  detail: string;
  line: string | null;
  outcomeKnown: boolean;
  constructor(code: string, detail: string, line: string | null, outcomeKnown: boolean) {
    super(detail ? code + ' ' + detail : code);
    this.name = new.target.name;
    this.code = code;
    this.detail = detail;
    this.line = line;
    this.outcomeKnown = outcomeKnown;
  }
}
class LocalRefusal extends AirlockError {
  constructor(detail: string) { super('LOCAL_REFUSED', detail, null, true); }
}
class EngineRefusal extends AirlockError {
  constructor(code: string, detail: string, line: string | null) { super(code, detail, line, true); }
}
class EngineFault extends AirlockError {
  constructor(code: string, detail: string, line: string | null) {
    super(code, detail, line, code !== 'OUTCOME_UNKNOWN' && code !== 'DISPATCH_FAILED');
  }
}
class ProtocolError extends AirlockError {
  constructor(detail: string, line: string | null) { super('BAD_ANSWER', detail, line, false); }
}
class EngineDead extends AirlockError {
  constructor(detail: string) { super('ENGINE_DEAD', detail, null, false); }
}
class EngineTimeout extends AirlockError {
  constructor(detail: string) { super('TIMEOUT', detail, null, false); }
}
class LeaseNotOpened extends AirlockError {
  result: Result;
  constructor(result: Result) { super(result.code, result.detail, result.line, true); this.result = result; }
}

// ------------------------------------------------------------------------------------------------ results

class Result {
  code: Code;
  detail: string;
  line: string;
  requestId: string | null = null;
  epoch: number | null = null;
  stateHash: string | null = null;
  payload: string | null = null;
  leaseClosed: number | null = null;
  kind: string | null = null;
  fields: Record<string, string> = {};
  rows: unknown[] = [];
  dropped: Array<[string, string, string, string]> = [];
  constructor(code: Code, detail: string, line: string) {
    this.code = code;
    this.detail = detail;
    this.line = line;
  }
  get committed(): boolean { return this.code === 'COMMITTED'; }
}

// A lease bound to (requestId, tenant, key). commit() uses its request id, and its tenant and key unless given.
class Lease {
  store: Store;
  requestId: string;
  epoch: number;
  deadlineMs: string;
  tenant: string;
  key: string;
  constructor(store: Store, requestId: string, epoch: number, deadlineMs: string, tenant: string, key: string) {
    this.store = store;
    this.requestId = requestId;
    this.epoch = epoch;
    this.deadlineMs = deadlineMs;
    this.tenant = tenant;
    this.key = key;
  }
  commit(op: string, fields: Fields): Promise<Result> {
    return this.store.commit(op, Object.assign({ tenant: this.tenant, key: this.key }, fields, { request_id: this.requestId }));
  }
}

// ------------------------------------------------------------------------------------------------ field checks

function printable(name: string, s: unknown, allowSpace: boolean): string {
  const lo = allowSpace ? 0x20 : 0x21;
  if (typeof s !== 'string' || s.length === 0) throw new LocalRefusal(name + ': empty or not a string');
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    if (c < lo || c > 0x7e) throw new LocalRefusal(name + ': holds a byte outside 0x21..0x7e (LF, CR, NUL, space, non-ASCII)');
  }
  return s;
}
function id(name: string, v: unknown): string {
  if (typeof v !== 'string' || !ID_RE.test(v)) throw new LocalRefusal(name + ': not a canonical id [A-Za-z0-9_-]{1,24}');
  return v;
}
function hash(name: string, v: unknown): string {
  if (typeof v !== 'string' || !HASH_RE.test(v)) throw new LocalRefusal(name + ': not 32 lowercase hex digits');
  return v;
}
// A number must be a safe integer; a bigint or a string is sent as its text. The ENGINE checks the range.
function amount(name: string, v: unknown): string {
  if (typeof v === 'bigint') return v.toString();
  if (typeof v === 'number') {
    if (!Number.isSafeInteger(v)) throw new LocalRefusal(name + ': a number that is not a safe integer (use a bigint or a string)');
    return String(v);
  }
  return printable(name, v, false);
}
function jsonText(name: string, v: unknown): string {
  let text: string | undefined;
  try {
    text = JSON.stringify(v, (_k, x) => (typeof x === 'bigint' ? x.toString() : x));
  } catch (e) {
    throw new LocalRefusal(name + ': not JSON (' + (e as Error).message + ')');
  }
  if (typeof text !== 'string') throw new LocalRefusal(name + ': not JSON');
  // escape every non-ASCII code unit (lone surrogates included) so the line is printable ASCII
  text = text.replace(/[\u007f-￿]/g, (ch) => '\\u' + ch.charCodeAt(0).toString(16).padStart(4, '0'));
  for (let i = 0; i < text.length; i++) {
    const c = text.charCodeAt(i);
    if (c < 0x20 || c > 0x7e) throw new LocalRefusal(name + ': JSON text is not printable ASCII');
  }
  return text;
}

function refundAction(tenant: string, key: string, requestId: string, preStateHash: string, reason: string, amt: Amount): string {
  return ['REFUND', id('tenant', tenant), id('key', key), id('request_id', requestId), hash('pre_state_hash', preStateHash),
    id('reason', reason), amount('amount', amt)].join(' ');
}

function buildLine(op: string, f: Fields): string {
  const allowed = FIELDS[op];
  if (!allowed) throw new TypeError('unknown op ' + op);
  for (const k of Object.keys(f)) if (!allowed.includes(k) && f[k] !== undefined) throw new TypeError(op + ': unknown field ' + k);
  const t = [VERBS[op], id('tenant', f.tenant), id('key', f.key), id('request_id', f.request_id)];
  if (op === 'open_money') {
    t.push(id('policy', f.policy), amount('original', f.original));
    const facts = (f.facts || {}) as Record<string, unknown>;
    if (typeof facts !== 'object' || Array.isArray(facts)) throw new LocalRefusal('facts: not an object');
    for (const k of Object.keys(facts).sort()) t.push(id('fact', k) + '=' + amount('fact ' + k, facts[k]));
  } else if (op === 'refund') {
    t.push(hash('pre_state_hash', f.pre_state_hash), id('reason', f.reason), amount('amount', f.amount));
    if (f.signature !== undefined && f.signature !== null) {
      if (typeof f.signature !== 'string' || !SIG_RE.test(f.signature)) throw new LocalRefusal('signature: not one SSHSIG token (256 characters of canonical base64; see cosign-sign)');
      t.push(f.signature);
    }
  } else if (op === 'open_saga') {
    t.push(id('policy', f.policy));
  } else if (op === 'saga') {
    t.push(hash('pre_state_hash', f.pre_state_hash), id('to_state', f.to_state));
    const p = f.processor ?? null, k = f.idempotency_key ?? null;
    if ((p === null) !== (k === null)) throw new LocalRefusal('processor and idempotency_key go together');
    if (p !== null) t.push(id('processor', p), id('idempotency_key', k));
  } else if (op === 'open_inventory') {
    const caps = f.capacities;
    if (!Array.isArray(caps) || caps.length === 0) throw new LocalRefusal('capacities: a non-empty array');
    t.push(id('policy', f.policy), caps.map((c) => amount('capacity', c)).join(','));
  } else if (op === 'book') {
    t.push(hash('pre_state_hash', f.pre_state_hash), jsonText('certificate', f.certificate));
  }
  return t.join(' ');
}

// ------------------------------------------------------------------------------------------------ answer parsing

function refusal(line: string, t: string[], typed: string[]): Result {
  const code = t[0];
  const detail = t.slice(1).join(' ');
  if (typed.includes(code)) {
    // a bare code (no detail) is a valid answer form (PROTOCOL.md section 10)
    const r = new Result(code as Code, detail, line);
    const i = t.indexOf('LEASE_CLOSED');
    if (i >= 0) {
      if (i + 2 !== t.length || !DIGITS_RE.test(t[i + 1]) || (code !== 'REJECTED_POLICY' && code !== 'REQUIRE_HUMAN_COSIGN')) {
        throw new ProtocolError('bad LEASE_CLOSED part', line);
      }
      r.leaseClosed = Number(t[i + 1]);
    }
    if (code === 'STALE_STATE_HASH') {
      if (t.length < 2 || !HASH_RE.test(t[1])) throw new ProtocolError('STALE_STATE_HASH without a hash', line);
      r.stateHash = t[1];
    }
    return r;
  }
  if (REFUSALS.includes(code)) throw new EngineRefusal(code, detail, line);
  if (FAULTS.includes(code)) throw new EngineFault(code, detail, line);
  throw new ProtocolError('first token ' + JSON.stringify(code.slice(0, 40)) + ' is not an answer code for this request', line);
}

function parseCommitAnswer(line: string, verb: string, tenant: string, key: string, requestId: string): Result {
  const t = line.split(' ');
  if (t[0] === 'COMMITTED') {
    const ok = t.length >= 8 && t[1] === requestId && DIGITS_RE.test(t[2]) && HASH_RE.test(t[3]) && t[4] === verb
      && t[5] === tenant && t[6] === key && t[7] === requestId;
    if (!ok) throw new ProtocolError('a COMMITTED line that does not name this request', line);
    const r = new Result('COMMITTED', '', line);
    r.requestId = t[1];
    r.epoch = Number(t[2]);
    r.stateHash = t[3];
    r.payload = t.slice(4).join(' ');
    return r;
  }
  return refusal(line, t, COMMIT_TYPED);
}

// ------------------------------------------------------------------------------------------------ the store client

interface StoreOptions {
  node?: string;
  timeoutMs?: number;
  serveArgv?: string[];
  env?: Record<string, string>;
  python?: string;
  engineDir?: string;   // a folder with airlock-engine (and checker/model.cjs); default build/airlock (dispatcher)
}

class Store {
  storeDir: string;
  timeoutMs: number;
  pid: number;
  private opts: StoreOptions;
  private child: any;
  private buf: Buffer = Buffer.alloc(0);
  private closedWhy: string | null = null;
  private exited = false;
  private stderrTail = '';
  private tail: Promise<unknown> = Promise.resolve();
  private waiter: ((err: AirlockError | null, line: string | null) => void) | null = null;

  constructor(storeDir: string, opts: StoreOptions = {}) {
    this.storeDir = storeDir;
    this.opts = opts;
    this.timeoutMs = opts.timeoutMs ?? 60000;
    const python = opts.python ?? 'python3';
    const argv = opts.serveArgv ?? [python, DISPATCHER, 'serve', storeDir].concat(opts.node ? ['--node', opts.node] : [], this.engineOpt());
    this.child = childProcess.spawn(argv[0], argv.slice(1), { stdio: ['pipe', 'pipe', 'pipe'], env: opts.env ?? process.env });
    this.pid = this.child.pid;
    this.child.stdin.on('error', () => { /* EPIPE: reported through exit / close */ });
    this.child.stderr.on('data', (d: Buffer) => { this.stderrTail = (this.stderrTail + d.toString('utf8')).slice(-2000); });
    this.child.stdout.on('data', (d: Buffer) => this.onData(d));
    this.child.stdout.on('close', () => this.onGone());
    this.child.on('error', (e: Error) => { this.stderrTail += ' spawn error: ' + e.message; this.onGone(); });
  }

  private engineOpt(): string[] {
    return this.opts.engineDir ? ['--engine-dir', this.opts.engineDir] : [];
  }

  private onData(d: Buffer): void {
    this.buf = Buffer.concat([this.buf, d]);
    if (!this.waiter) {
      if (this.buf.length > 0) this.closeWith('an answer line with no request');
      return;
    }
    const nl = this.buf.indexOf(10);
    if (nl < 0) {
      if (this.buf.length > MAX_ANSWER) this.finish(new ProtocolError('answer longer than ' + MAX_ANSWER + ' bytes', null), null);
      return;
    }
    const line = this.buf.subarray(0, nl);
    const rest = this.buf.subarray(nl + 1);
    this.buf = Buffer.alloc(0);
    if (rest.length > 0) { this.finish(new ProtocolError('more than one answer line for one request', null), null); return; }
    for (const b of line) {
      if (b < 0x20 || b > 0x7e) { this.finish(new ProtocolError('empty or unprintable answer', null), null); return; }
    }
    if (line.length === 0) { this.finish(new ProtocolError('empty answer', null), null); return; }
    this.finish(null, line.toString('ascii'));
  }

  private onGone(): void {
    if (this.exited) return;
    this.exited = true;
    const why = this.buf.length ? 'short read (' + this.buf.length + ' bytes, no line end)' : 'no answer';
    if (this.closedWhy === null) this.closedWhy = 'serve process ended';
    if (this.waiter) this.finish(new EngineDead(why + '; serve ended; ' + this.stderrTail.trim().slice(-300)), null);
  }

  private closeWith(why: string): void {
    if (this.closedWhy === null) this.closedWhy = why;
    try { this.child.kill('SIGKILL'); } catch { /* already gone */ }
  }

  private finish(err: AirlockError | null, line: string | null): void {
    const w = this.waiter;
    this.waiter = null;
    if (err) this.closeWith(err.name + ': ' + err.message);
    if (w) w(err, line);
  }

  // Send bytes (complete lines); resolve with ONE answer line. Requests run one at a time, in call order.
  private exchange(data: Buffer): Promise<string> {
    const run = (): Promise<string> => new Promise<string>((resolve, reject) => {
      if (this.closedWhy !== null) { reject(new EngineDead('store client is closed (' + this.closedWhy + ')')); return; }
      const timer = setTimeout(() => this.finish(new EngineTimeout('no answer in ' + this.timeoutMs + ' ms'), null), this.timeoutMs);
      this.waiter = (err, line) => {
        clearTimeout(timer);
        if (err) { reject(err); return; }
        const first = (line as string).split(' ')[0];
        if (FAULTS.includes(first)) this.closedWhy = 'engine fault ' + (line as string).slice(0, 80);
        resolve(line as string);
      };
      this.child.stdin.write(data);
    });
    const p = this.tail.then(run, run);
    this.tail = p.catch(() => undefined);
    return p;
  }

  private send(line: string): Promise<string> {
    try { printable('request line', line, true); } catch (e) { return Promise.reject(e); }
    return this.exchange(Buffer.from(line + '\n', 'ascii'));
  }

  private guard<T>(fn: () => T): T {
    try {
      return fn();
    } catch (e) {
      if (e instanceof ProtocolError) this.closeWith('protocol error');
      throw e;
    }
  }

  // TESTING ONLY (fuzz-like tests): send one raw line (no LF in it); resolve with the raw answer.
  raw(line: Buffer): Promise<string> {
    if (line.includes(10)) return Promise.reject(new LocalRefusal('raw line holds LF'));
    return this.exchange(Buffer.concat([line, Buffer.from('\n')]));
  }

  async commit(op: string, fields: Fields): Promise<Result> {
    const line = buildLine(op, fields);
    const answer = await this.send(line);
    return this.guard(() => parseCommitAnswer(answer, VERBS[op], fields.tenant as string, fields.key as string, fields.request_id as string));
  }

  openMoney(tenant: string, key: string, requestId: string, policy: string, original: Amount, facts: Record<string, Amount> = {}): Promise<Result> {
    return this.commit('open_money', { tenant, key, request_id: requestId, policy, original, facts });
  }
  refund(tenant: string, key: string, requestId: string, preStateHash: string, reason: string, amt: Amount, signature?: string): Promise<Result> {
    return this.commit('refund', { tenant, key, request_id: requestId, pre_state_hash: preStateHash, reason, amount: amt, signature });
  }
  openSaga(tenant: string, key: string, requestId: string, policy: string): Promise<Result> {
    return this.commit('open_saga', { tenant, key, request_id: requestId, policy });
  }
  saga(tenant: string, key: string, requestId: string, preStateHash: string, toState: string, processor?: string, idempotencyKey?: string): Promise<Result> {
    return this.commit('saga', { tenant, key, request_id: requestId, pre_state_hash: preStateHash, to_state: toState, processor, idempotency_key: idempotencyKey });
  }
  openInventory(tenant: string, key: string, requestId: string, policy: string, capacities: Amount[]): Promise<Result> {
    return this.commit('open_inventory', { tenant, key, request_id: requestId, policy, capacities });
  }
  book(tenant: string, key: string, requestId: string, preStateHash: string, certificate: unknown): Promise<Result> {
    return this.commit('book', { tenant, key, request_id: requestId, pre_state_hash: preStateHash, certificate });
  }

  async get(tenant: string, key: string): Promise<Result> {
    const a = await this.send('GET ' + id('tenant', tenant) + ' ' + id('key', key));
    return this.guard(() => {
      const t = a.split(' ');
      if (t[0] === 'OK') {
        if (t.length < 3 || !HASH_RE.test(t[1]) || t.slice(3).some((x) => !x.includes('='))) throw new ProtocolError('bad GET answer', a);
        const r = new Result('OK', '', a);
        r.stateHash = t[1];
        r.kind = t[2];
        for (const x of t.slice(3)) { const i = x.indexOf('='); r.fields[x.slice(0, i)] = x.slice(i + 1); }
        return r;
      }
      return refusal(a, t, []);
    });
  }

  async state(): Promise<Result> {
    const a = await this.send('STATE');
    return this.guard(() => {
      const t = a.split(' ');
      if (t[0] !== 'STATE' || t.length !== 7) return refusal(a, t, []);
      const r = new Result('OK', '', a);
      r.epoch = Number(t[1]);
      r.stateHash = t[2];
      for (const x of t.slice(4)) { const i = x.indexOf('='); r.fields[x.slice(0, i)] = x.slice(i + 1); }
      return r;
    });
  }

  // Release `rows` only if the engine answers exactly `OK <rows.length>`; else 0 rows + TENANT_ISOLATION_BREACH.
  // Limit: the engine sees only the rows passed here.
  async readScoped(tenantId: unknown, callerRows: unknown[]): Promise<Result> {
    if (!Array.isArray(callerRows)) throw new LocalRefusal('readScoped: rows is not an array');
    const n = callerRows.length;  // read once: a later change of the caller's array does not count
    if (n > MAX_READ_ROWS) throw new LocalRefusal('readScoped: ' + n + ' rows; the engine takes at most ' + MAX_READ_ROWS);
    if (typeof tenantId !== 'string' || !ID_RE.test(tenantId)) return new Result('TENANT_ISOLATION_BREACH', 'LOCAL TENANT_NOT_CANONICAL', '');
    // each row serialized ONCE, by index (a sparse hole or an undefined entry is refused before anything is sent);
    // from here on only these texts exist: what the engine checks is what is released
    const rows: string[] = [];
    try {
      for (let i = 0; i < n; i++) {
        if (!Object.prototype.hasOwnProperty.call(callerRows, i) || callerRows[i] === undefined) throw new LocalRefusal('row ' + i + ': a hole or undefined');
        rows.push(jsonText('row ' + i, callerRows[i]));
      }
    } catch (e) {
      if (!(e instanceof LocalRefusal)) throw e;
      return new Result('TENANT_ISOLATION_BREACH', 'LOCAL ' + e.detail, '');
    }
    const a = await this.exchange(Buffer.from('READ ' + tenantId + ' ' + rows.length + '\n' + rows.map((x) => x + '\n').join(''), 'ascii'));
    return this.guard(() => {
      if (a === 'OK ' + rows.length) { const r = new Result('OK', '', a); r.rows = rows.map((x) => JSON.parse(x)); return r; }
      const t = a.split(' ');
      if (t[0] !== 'OK' && t[0] !== 'TENANT_ISOLATION_BREACH') this.closeWith('READ answered ' + t[0].slice(0, 40) + '; the stream may be out of step');
      if (t[0] === 'OK') throw new ProtocolError('OK for another row count', a);
      return refusal(a, t, ['TENANT_ISOLATION_BREACH']);
    });
  }

  // Open a durable lease bound to (requestId, tenant, key), then run handler(lease). The SDK never closes the
  // lease. deadlineMs: absolute ms since the Unix epoch. Resolves with the handler's value; a handler error
  // propagates and the lease stays open. One lease per request id and tenant, ever (DUPLICATE_REQUEST_ID LEASE_USED).
  async withLease<T>(requestId: string, deadlineMs: Amount, tenant: string, key: string, handler: (lease: Lease) => T | Promise<T>): Promise<T> {
    const dl = amount('deadline_ms', deadlineMs);
    const a = await this.send('OPEN_LEASE ' + id('request_id', requestId) + ' ' + dl + ' ' + id('tenant', tenant) + ' ' + id('key', key));
    const t = a.split(' ');
    if (t[0] === 'LEASE_OPENED') {
      if (t.length !== 6 || t[1] !== requestId || !DIGITS_RE.test(t[2]) || t[3] !== dl || t[4] !== tenant || t[5] !== key) {
        this.closeWith('protocol error');
        throw new ProtocolError('LEASE_OPENED for another lease', a);
      }
      return await handler(new Lease(this, requestId, Number(t[2]), dl, tenant, key));
    }
    const r = this.guard(() => refusal(a, t, ['DUPLICATE_REQUEST_ID']));
    throw new LeaseNotOpened(r);
  }

  // One-shot engine subcommands (separate short processes).
  private sub(args: string[]): Promise<{ code: number; out: string }> {
    const python = this.opts.python ?? 'python3';
    return new Promise((resolve) => {
      childProcess.execFile(python, [DISPATCHER].concat(args, this.engineOpt()), { env: this.opts.env ?? process.env, timeout: this.timeoutMs * 2, maxBuffer: 64 << 20 },
        (err: any, stdout: string) => resolve({ code: err ? (typeof err.code === 'number' ? err.code : -1) : 0, out: String(stdout) }));
    });
  }

  async cosignMessage(action: string): Promise<Buffer> {
    const r = await this.sub(['cosign-message', this.storeDir, printable('action', action, true)]);
    if (r.code !== 0) throw new EngineRefusal(r.out.split(' ')[0] || 'COSIGN_MESSAGE', r.out.trim(), null);
    return Buffer.from(r.out, 'ascii');
  }

  async replay(): Promise<Array<[number, string]>> {
    const r = await this.sub(['replay', this.storeDir]);
    const lines = r.out.split('\n');
    if (r.code !== 0 || !lines[0].startsWith('REPLAY ')) throw new EngineFault(lines[0].split(' ')[0] || 'REPLAY_FAILED', r.out.slice(0, 200), null);
    const n = Number(lines[0].split(' ')[1]);
    const effects: Array<[number, string]> = [];
    for (const ln of lines.slice(1, 1 + n)) {
      const m = /^EFFECT ([0-9]+) (.+)$/.exec(ln);
      if (!m) throw new ProtocolError('bad replay line', ln);
      effects.push([Number(m[1]), m[2]]);
    }
    if (effects.length !== n) throw new ProtocolError('replay: ' + effects.length + ' of ' + n + ' lines', null);
    return effects;
  }

  async sweep(nowMs?: Amount): Promise<Result> {
    const args = ['leases', this.storeDir, '--sweep'].concat(nowMs === undefined ? [] : ['--now', amount('now_ms', nowMs)]);
    const r = await this.sub(args);
    const lines = r.out.split('\n').filter((x) => x);
    if (!lines.length || !lines[0].startsWith('SWEEP ') || (r.code !== 0 && r.code !== 24)) {
      throw new EngineFault(lines.length ? lines[0].split(' ')[0] : 'SWEEP_FAILED', r.out.slice(0, 200), null);
    }
    const dropLines = lines.slice(1).filter((x) => x.startsWith('DROPPED_OBLIGATION ')).map((x) => x.split(' '));
    if (dropLines.some((x) => x.length !== 5)) throw new ProtocolError('bad DROPPED_OBLIGATION line', r.out);
    const dropped: Array<[string, string, string, string]> = dropLines.map((x) => [x[1], x[2], x[3], x[4]]);
    if ((r.code === 24) !== (dropped.length > 0)) throw new ProtocolError('sweep exit code and lines disagree', r.out);
    const res = new Result(dropped.length ? 'DROPPED_OBLIGATION' : 'OK', lines[0], r.out);
    res.dropped = dropped;
    return res;
  }

  // Close the input; wait for the serve process to end (kill after 10 s).
  close(): Promise<void> {
    return new Promise((resolve) => {
      if (this.closedWhy === null) this.closedWhy = 'closed by the caller';
      if (this.exited || this.child.exitCode !== null || this.child.signalCode !== null) { resolve(); return; }
      const t = setTimeout(() => { try { this.child.kill('SIGKILL'); } catch { /* gone */ } }, 10000);
      this.child.once('exit', () => { clearTimeout(t); resolve(); });
      this.child.stdin.end();
    });
  }
}

module.exports = {
  Store, Result, Lease, AirlockError, LocalRefusal, EngineRefusal, EngineFault, ProtocolError, EngineDead, EngineTimeout,
  LeaseNotOpened, refundAction, buildLine, MAX_MONEY: 9223372036854775807n,
};

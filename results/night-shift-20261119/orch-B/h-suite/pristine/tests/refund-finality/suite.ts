// Slice 1 (F2.3): controls for the token issuer, the sink and the dispatcher of the refund finality boundary.
// Real processes, real Ed25519, real SQLite files. This is a FINITE TEST. It proves nothing universal.
// Run: node --import tsx tests/refund-finality/suite.ts <fresh-out-dir> <compiled core module>
// The report has no key, signature, path or time in it: two runs must give the same bytes.
//
// "Effects" of one attempt = changed state (0 or 1) + new settled rows + new outbox rows + new outbound
// emissions of the dispatcher. A rejection control passes only if the sink answers as expected AND the
// effects are 0. The column uncheckedSinkEffects shows that the attempt ASKS for an effect: a sink
// without checks (UncheckedSink) would apply it. That column describes the input, not the sink.
// The sink takes TEXT. In the rows below a token object stands for its canonical text; a value that is
// handed over as it is (not as text) is wrapped in AsIs.
import { spawn } from "node:child_process";
import { createPrivateKey, generateKeyPairSync, sign, verify, createPublicKey, KeyObject } from "node:crypto";
import { appendFileSync, existsSync, mkdirSync, readFileSync, symlinkSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { DatabaseSync } from "node:sqlite";
import {
  ChargeState, DOMAIN, RefundRequest, Token, TokenBody, Transition, canon, checkerSha256Of, sha256hex, signedBytes, stateSha256, tokenText,
} from "../../ts/refund-finality/encoding";
import { Dispatcher, DispatcherConfig, Effect, FlushResult } from "../../ts/refund-finality/dispatcher";
import { MinterClient, Minted, propose } from "../../ts/refund-finality/proposer";
import { CommitResult, Sink, SinkConfig, genesisOf } from "../../ts/refund-finality/sink";

const ROOT = resolve(__dirname, "../..");
const GLUE = join(ROOT, "ts/refund-finality");
const SPEC_LOCK = join(ROOT, "spec/refund/spec.lock");
const outDir = resolve(process.argv[2] ?? "");
const CORE = resolve(process.argv[3] ?? "");
if (process.argv.length !== 4) throw new Error("usage: suite.ts <fresh-out-dir> <compiled core module>");
if (existsSync(outDir)) throw new Error("output directory is not fresh");
mkdirSync(outDir, { recursive: true });

const REASON = "duplicate_charge";
const MAX_MONEY = 9223372036854775807n;
const ALLOWED = new Set(["duplicate_charge", "service_not_delivered", "returned_item"]);

type Row = { control: string; name: string; expected: string; observed: string; pass: boolean; effects: number; uncheckedSinkEffects: number | null };
const rows: Row[] = [];
const add = (control: string, name: string, expected: string, observed: string, pass: boolean, effects = 0, uncheckedSinkEffects: number | null = null) =>
  rows.push({ control, name, expected, observed, pass, effects, uncheckedSinkEffects });

// TEST ORACLE ONLY: the approved eligibility rule written again in plain arithmetic, to compare the
// issuer's answers with. It is not used by the issuer, the sink or the dispatcher.
function oracle(pre: ChargeState, r: RefundRequest): boolean {
  const original = BigInt(pre.original), remaining = BigInt(pre.remaining), amount = BigInt(r.amount);
  return pre.chargeId !== "" && r.requestId !== "" && pre.refundEnabled && original <= MAX_MONEY &&
    remaining <= original && amount <= remaining && ALLOWED.has(r.reason);
}

// A value that is handed to the sink as it is.
class AsIs { constructor(readonly value: unknown) {} }
// The text that stands for a value: its canonical text, or plain JSON text if it has no canonical text.
const textOf = (value: unknown): string => {
  try { return canon(value); } catch { return JSON.stringify(value) ?? "undefined"; }
};
const parsed = (input: unknown): unknown => {
  if (typeof input !== "string") return input;
  try { return JSON.parse(input); } catch { return undefined; }
};

// CONTROL ONLY: a sink without checks. It applies every body that has a post-state and an intent.
class UncheckedSink {
  private state: string; private outbox = 0;
  constructor(stateBlob: string) { this.state = stateBlob; }
  commit(token: unknown): number | null {
    const body = (token as { body?: { post?: unknown; intent?: unknown } } | null | undefined)?.body;
    if (!body || typeof body.post !== "object" || body.post === null || typeof body.intent !== "object" || body.intent === null) return null;
    let post: string;
    try { post = canon(body.post); canon(body.intent); } catch { post = JSON.stringify(body.post); }
    const changed = post !== this.state ? 1 : 0;
    this.state = post; this.outbox++;
    return changed + 1;
  }
}

const verifies = (key: KeyObject, m: Minted): boolean => {
  try { return !!m.ok && !!m.token && verify(null, signedBytes(m.token.body), key, Buffer.from(m.token.signature, "base64")); } catch { return false; }
};
// Waits until the condition holds, at most `ms` milliseconds. Returns false at the time limit.
async function until(condition: () => boolean, ms: number): Promise<boolean> {
  const end = Date.now() + ms;
  while (!condition()) {
    if (Date.now() > end) return false;
    await new Promise(done => setTimeout(done, 20));
  }
  return true;
}
function run(args: string[]): Promise<{ code: number | null; stdout: string }> {
  return new Promise(done => {
    const child = spawn(process.execPath, ["--import", "tsx", ...args], { cwd: ROOT, stdio: ["ignore", "pipe", "ignore"] });
    let stdout = "";
    child.stdout.on("data", chunk => { stdout += String(chunk); });
    child.on("close", code => done({ code, stdout }));
  });
}

// A run that ends before the report is written must not look like a pass: the exit code is 2 until
// the last line of main sets it. (A process whose last pending work disappears ends with its exit code.)
process.exitCode = 2;

async function main() {
  const minter = await MinterClient.start(ROOT, CORE, SPEC_LOCK, "off");
  const pem = minter.ready.publicKeyPem, key = createPublicKey(pem);
  const checkerSha256 = checkerSha256Of(readFileSync(CORE), readFileSync(join(GLUE, "encoding.ts")), readFileSync(join(GLUE, "minter.ts")));
  const specLockSha256 = sha256hex(readFileSync(SPEC_LOCK));
  const idsEqual = minter.ready.checkerSha256 === checkerSha256 && minter.ready.specLockSha256 === specLockSha256 && minter.ready.singleUse === false;
  add("setup", "the issuer reports the ids that the operator computes from the files", "equal", String(idsEqual), idsEqual);
  {
    // Key isolation: code that loads the issuer module in its own process gets no key and no signing function.
    const probe = await run([join(__dirname, "issuer_exports_probe.ts"), CORE, SPEC_LOCK, "off"]);
    const lines = probe.stdout.split("\n").filter(l => l.length > 0).map(l => { try { return JSON.parse(l); } catch { return {}; } });
    const names = lines.find(l => l.probe === true)?.exportedNames, ready = lines.find(l => l.ready === true) ?? {};
    const publicOnly = canon(Object.keys(ready).sort()) === canon(["checkerSha256", "publicKeyPem", "ready", "singleUse", "specLockSha256"]) &&
      String(ready.publicKeyPem).includes("BEGIN PUBLIC KEY") && !JSON.stringify(lines).includes("PRIVATE");
    add("issuer", "code that loads the issuer module gets no key and no signing function", "0 exported names; the ready message holds a public key only",
      `${Array.isArray(names) ? names.length : "NO ANSWER"} exported names; ${publicOnly ? "the ready message holds a public key only" : "THE READY MESSAGE HAS OTHER FIELDS"}`,
      Array.isArray(names) && names.length === 0 && publicOnly);
  }

  const state = (id: string, remaining = "1000", refundEnabled = true, original = "1000"): ChargeState => ({ chargeId: "ch_" + id, original, remaining, refundEnabled });
  const req = (id: string, amount: string, reason = REASON): RefundRequest => ({ requestId: "rq_" + id, amount, reason });
  const expectedBody = (pre: ChargeState, t: Transition): TokenBody =>
    ({ domain: DOMAIN, specLockSha256, checkerSha256, preStateSha256: stateSha256(pre), requestId: t.request.requestId, post: t.post, intent: t.intent });
  async function mustMint(m: MinterClient, pre: ChargeState, request: RefundRequest): Promise<Token> {
    const answer = await m.mint(pre, propose(pre, request));
    if (!verifies(createPublicKey(m.ready.publicKeyPem), answer)) throw new Error("setup: the issuer refused " + request.requestId + ": " + answer.reason);
    return answer.token!;
  }

  // ---------------- Issuer: it signs exactly what the proved core issues. ----------------
  {
    let grid = 0, bad = 0, signed = 0, byCore = 0, byShape = 0;
    const pairs: [ChargeState, RefundRequest][] = [];
    for (const remaining of ["0", "500", "1000"]) for (const enabled of [true, false])
      for (const reason of [REASON, "service_not_delivered", "returned_item", "goodwill", ""])
        for (const amount of ["0", "1", "100", "500", "501", "1000", "1001"]) {
          const id = `g${pairs.length}`;
          pairs.push([state(id, remaining, enabled), req(id, amount, reason)]);
        }
    const big = "9223372036854775807", over = "9223372036854775808", p53 = "9007199254740993", p53less = "9007199254740992";
    pairs.push([{ chargeId: "", original: "1000", remaining: "1000", refundEnabled: true }, req("e1", "10")]);
    pairs.push([state("e2"), { requestId: "", amount: "10", reason: REASON }]);
    pairs.push([state("e3", big, true, big), req("e3", big)]);
    pairs.push([state("e4", over, true, over), req("e4", "1")]);
    pairs.push([state("e5", "1500", true, "1000"), req("e5", "1200")]);
    pairs.push([state("e6", p53, true, big), req("e6", p53)]);
    pairs.push([state("e7", p53less, true, big), req("e7", p53)]);
    for (const [pre, r] of pairs) {
      grid++;
      // An amount above the remaining amount gives a negative post-state, which the shape check refuses.
      // Post-state remaining 0 is used in its place, so that the core judges that candidate.
      const honest = propose(pre, r);
      const candidate = honest.post.remaining.startsWith("-") ? { ...honest, post: { ...honest.post, remaining: "0" } } : honest;
      const answer = await minter.mint(pre, candidate), want = oracle(pre, r);
      const exact = !answer.ok || (verifies(key, answer) && canon(answer.token!.body) === canon(expectedBody(pre, candidate)));
      if (answer.ok !== want || !exact) bad++;
      if (answer.ok) signed++; else if (answer.reason === "core: Refuse") byCore++; else byShape++;
    }
    add("issuer", `differential grid: ${grid} (pre-state, request) pairs with the proposer's candidate, against the test oracle`,
      "0 disagreements; some signed, some refused by the core",
      `${bad} disagreements; ${signed} signed; ${byCore} refused by the core; ${byShape} refused by the shape check`, bad === 0 && signed > 0 && byCore > 0);

    const pre = state("m2", "600"), r = req("m2", "400"), honest = propose(pre, r);
    const wrong: [string, Transition][] = [
      ["post-state keeps the remaining amount", { ...honest, post: pre }],
      ["post-state reduced by one unit less", { ...honest, post: { ...honest.post, remaining: "201" } }],
      ["post-state with another original amount", { ...honest, post: { ...honest.post, original: "2000" } }],
      ["post-state of another charge", { ...honest, post: { ...honest.post, chargeId: "ch_other" } }],
      ["post-state with refunds switched off", { ...honest, post: { ...honest.post, refundEnabled: false } }],
      ["intent with another amount", { ...honest, intent: { ...honest.intent, amount: "600" } }],
      ["intent with another allowed reason", { ...honest, intent: { ...honest.intent, reason: "returned_item" } }],
      ["intent for another charge", { ...honest, intent: { ...honest.intent, chargeId: "ch_other" } }],
      ["intent with another request id", { ...honest, intent: { ...honest.intent, requestId: "rq_other" } }],
    ];
    for (const [name, candidate] of wrong) {
      const answer = await minter.mint(pre, candidate);
      add("issuer", "wrong candidate for an eligible request: " + name, "no token", answer.ok ? "SIGNED" : "refused: " + answer.reason, !answer.ok);
    }
    {
      // Beyond 2^53: a double cannot tell these two amounts apart. The core must.
      const near: ChargeState = { chargeId: "ch_m2big", original: "9223372036854775807", remaining: "9007199254740992", refundEnabled: true };
      const request = req("m2big", "9007199254740993");
      const answer = await minter.mint(near, { request, post: { ...near, remaining: "0" }, intent: { chargeId: near.chargeId, requestId: request.requestId, amount: request.amount, reason: REASON } });
      add("issuer", "wrong candidate: amount 2^53+1 for remaining 2^53, with post-state remaining 0", "no token", answer.ok ? "SIGNED" : "refused: " + answer.reason, !answer.ok);
    }
    const first = await minter.mint(pre, honest), second = await minter.mint(pre, honest);
    add("issuer", "the honest candidate for the same request, sent twice", "a token each time, equal bytes",
      first.ok && second.ok ? (canon(first.token) === canon(second.token) ? "equal tokens" : "DIFFERENT") : "REFUSED", !!first.ok && !!second.ok && canon(first.token) === canon(second.token));

    const long = "x".repeat(257);
    const shapes: [string, Record<string, unknown>][] = [
      ["extra key in the pre-state", { pre: { ...pre, admin: true }, transition: honest }],
      ["amount is a JSON number", { pre, transition: { ...honest, request: { ...r, amount: 400 } } }],
      ["negative amount", { pre, transition: propose(pre, req("m3", "-5")) }],
      ["amount with 25 digits", { pre, transition: { ...honest, request: { ...r, amount: "1".repeat(25) } } }],
      ["amount with a leading zero", { pre, transition: { ...honest, request: { ...r, amount: "0400" } } }],
      ["transition missing", { pre }],
      ["pre-state is an array", { pre: [], transition: honest }],
      ["charge id longer than 256 characters", { pre: { ...pre, chargeId: long }, transition: propose({ ...pre, chargeId: long }, r) }],
      ["lone surrogate in the request id", { pre, transition: propose(pre, { ...r, requestId: "rq_\ud800" }) }],
      ["U+0000 in the request id", { pre, transition: propose(pre, { ...r, requestId: "rq_\u0000A" }) }],
      ["U+0000 in the charge id", { pre: { ...pre, chargeId: "ch\u0000" }, transition: propose({ ...pre, chargeId: "ch\u0000" }, r) }],
      ["extra key in the message", { pre, transition: honest, token: { body: expectedBody(pre, honest), signature: "A".repeat(86) + "==" } }],
      ["caller supplies a pre-state hash", { pre, transition: honest, preStateSha256: "0".repeat(64) }],
      ["extra key in the transition", { pre, transition: { ...honest, plan: [honest.intent] } }],
    ];
    for (const [name, body] of shapes) {
      const answer = await minter.send(body);
      add("issuer", "refused message: " + name, "no token", answer.ok ? "SIGNED" : "refused: " + answer.reason, !answer.ok);
    }
    // A message whose id is 10,000 nested arrays ended the first version of the issuer process.
    const seen = minter.unmatched.length;
    minter.raw('{"id":' + "[".repeat(10000) + "]".repeat(10000) + ',"pre":1,"transition":2}');
    const after = await minter.mint(pre, honest), answer = minter.unmatched[seen];
    add("issuer", "a message whose id is 10,000 nested arrays", "refused: message id; the issuer answers the next request",
      `${answer && !answer.ok ? "refused: " + answer.reason : "NO REFUSAL"}; ${after.ok ? "the issuer answers the next request" : "THE NEXT REQUEST FAILED"}`,
      !!answer && !answer.ok && answer.reason === "message id" && !!after.ok);
    {
      // Finding of the repair check: a line with no end ended the issuer inside Node's line reader. The issuer
      // must refuse a line over its limit BEFORE the line ends, once, and go on.
      const before = minter.unmatched.length, block = "a".repeat(100000);
      minter.write(block + block + block);
      const early = await until(() => minter.unmatched.length > before, 5000);
      minter.write(block + block);
      minter.raw("");
      const next = await minter.mint(pre, honest), refusals = minter.unmatched.slice(before);
      add("issuer", "a line of 500,000 bytes: 300,000 bytes are sent, then 200,000 more, then the line end",
        "refused before the line ends: message too long; 1 answer for that line; the issuer answers the next request",
        `${early ? "refused before the line ends" : "NO ANSWER BEFORE THE LINE END"}: ${refusals[0]?.reason ?? "-"}; ${refusals.length} answer for that line; ${next.ok ? "the issuer answers the next request" : "THE NEXT REQUEST FAILED"}`,
        early && refusals.length === 1 && refusals[0].reason === "message too long" && !!next.ok);
    }
  }

  // ---------------- Worlds: one sink database, one dispatcher ledger, one list of outbound effects. ----------------
  type World = { id: string; dir: string; db: string; sinkCfg: SinkConfig; dispCfg: DispatcherConfig; initial: ChargeState; effects: Effect[];
    committed: Token[]; sink: () => Sink; flush: (emit?: (e: Effect) => void) => FlushResult; current: () => ChargeState; raw: () => DatabaseSync };
  async function world(id: string, m: MinterClient = minter, amounts: string[] = ["100"], initial: ChargeState = state(id)): Promise<World> {
    const dir = join(outDir, id); mkdirSync(dir);
    const db = join(dir, "sink.sqlite");
    const sinkCfg: SinkConfig = { publicKeyPem: m.ready.publicKeyPem, specLockSha256, checkerSha256, initialState: initial };
    const dispCfg: DispatcherConfig = { ...sinkCfg, initialStateSha256: stateSha256(initial), newLedgerH0: genesisOf(canon(initial), specLockSha256, checkerSha256, m.ready.publicKeyPem) };
    writeFileSync(join(dir, "sink-config.json"), JSON.stringify(sinkCfg));
    const w: World = { id, dir, db, sinkCfg, dispCfg, initial, effects: [], committed: [],
      sink: () => new Sink(db, sinkCfg),
      flush: emit => new Dispatcher(db, join(dir, "dispatch-ledger.jsonl"), dispCfg, emit ?? (e => { w.effects.push(e); })).flush(),
      current: () => { const s = w.sink(); try { return JSON.parse(s.stateBlob()) as ChargeState; } finally { s.close(); } },
      raw: () => new DatabaseSync(db) };
    const s = w.sink(); s.init(initial); s.close();
    let n = 0;
    for (const amount of amounts) {
      const token = await mustMint(m, w.current(), req(`${id}_setup${++n}`, amount));
      const sink = w.sink(); const result = sink.commit(tokenText(token)); sink.close();
      if (result.status !== "committed") throw new Error("setup commit failed in " + id + ": " + result.reason);
      w.committed.push(token);
    }
    w.flush();
    if (w.effects.length !== amounts.length) throw new Error("setup dispatch failed in " + id);
    return w;
  }
  type Snap = { state: string; settled: string[]; outbox: string[]; emitted: number };
  const snap = (w: World): Snap => {
    const s = w.sink();
    try { return { state: s.stateBlob(), settled: s.settled().map(r => canon([String(r.seq), r.request_id, r.token, r.token_sha256])),
      outbox: s.outbox().map(r => canon([String(r.seq), r.request_id, r.intent])), emitted: w.effects.length }; } finally { s.close(); }
  };
  // Number of effects between two snapshots. Any changed or removed old row counts as an effect too.
  const effectsBetween = (a: Snap, b: Snap): number =>
    (a.state !== b.state ? 1 : 0) + (b.emitted - a.emitted) +
    b.settled.filter(x => !a.settled.includes(x)).length + a.settled.filter(x => !b.settled.includes(x)).length +
    b.outbox.filter(x => !a.outbox.includes(x)).length + a.outbox.filter(x => !b.outbox.includes(x)).length;
  // One attempt at the sink, then a dispatcher run. Records one row.
  function attempt(w: World, control: string, name: string, token: unknown, want: CommitResult["status"], wantReason: string | null, wantEffects: number, needUnchecked = true): CommitResult {
    const input = token instanceof AsIs ? token.value : textOf(token);
    const before = snap(w), unchecked = new UncheckedSink(before.state).commit(parsed(input));
    const s = w.sink(); const result = s.commit(input); s.close();
    w.flush();
    const effects = effectsBetween(before, snap(w));
    const pass = result.status === want && (wantReason === null || result.reason === wantReason) && effects === wantEffects &&
      (wantEffects !== 0 || !needUnchecked || (unchecked !== null && unchecked > 0));
    add(control, name, `${want}${wantReason ? ": " + wantReason : ""}; effects ${wantEffects}`,
      `${result.status}${result.reason ? ": " + result.reason : ""}; effects ${effects}`, pass, effects, unchecked);
    return result;
  }
  const auditRow = (w: World, control: string, name: string) => {
    const s = w.sink(); const problems = s.audit(); s.close();
    add(control, name, "problems found: 0", `problems found: ${problems.length}${problems.length ? ": " + problems.join("; ") : ""}`, problems.length === 0);
  };
  const attacker = generateKeyPairSync("ed25519");
  const signWith = (privateKey: KeyObject, body: TokenBody): Token => ({ body, signature: sign(null, signedBytes(body), privateKey).toString("base64") });
  const SHAPE = "token shape", SIG = "signature does not verify", STALE = "stored state is not the token's pre-state",
    USED = "request id is already settled with another token", NOTEXT = "token is not a text", NONCANON = "token text is not canonical";
  // Processes of one race wait for a common start time. A process that is ready too late makes the row fail.
  const START_DELAY_MS = 5000;
  type Answer = { status?: string; reason?: string; emitted?: number; stopped?: string; onTime?: boolean };
  const answers = (results: { stdout: string }[]): Answer[] => results.map(r => { try { return JSON.parse(r.stdout) as Answer; } catch { return { status: "process failed" }; } });

  // ---------------- Control (a): missing, forged or tampered token -> 0 effects. ----------------
  {
    const w = await world("a");
    const pre = w.current(), good = await mustMint(minter, pre, req("a_good", "200"));
    const body = good.body, earlier = w.committed[0];
    const zeros = Buffer.alloc(64).toString("base64");
    const spki = createPublicKey(pem).export({ type: "spki", format: "der" });
    const fromPublic = createPrivateKey({ key: Buffer.concat([Buffer.from("302e020100300506032b657004220420", "hex"), spki.subarray(spki.length - 32)]), format: "der", type: "pkcs8" });
    const other = await MinterClient.start(ROOT, CORE, SPEC_LOCK, "off");
    const otherToken = await mustMint(other, pre, req("a_good", "200"));
    other.stop();
    // The last base64 character of 64 bytes carries 2 data bits. Another character with the same 2 bits decodes to the same bytes.
    const nonCanonical = good.signature.slice(0, 85) + ({ A: "B", Q: "R", g: "h", w: "x" } as Record<string, string>)[good.signature[85]] + "==";
    if (!Buffer.from(nonCanonical, "base64").equals(Buffer.from(good.signature, "base64")) || nonCanonical === good.signature) throw new Error("setup: non-canonical signature text");
    const evil: TokenBody = { ...body, post: { ...body.post, remaining: "0" }, intent: { ...body.intent, amount: "900" } };
    const nul: TokenBody = { ...body, requestId: "rq_a\u0000X", intent: { ...body.intent, requestId: "rq_a\u0000X" } };
    const cases: [string, unknown, string, boolean][] = [
      ["missing token: undefined", new AsIs(undefined), NOTEXT, false],
      ["missing token: null", new AsIs(null), NOTEXT, false],
      ["missing token: an empty object", new AsIs({}), NOTEXT, false],
      ["missing token: the text of an empty object", {}, SHAPE, false],
      ["missing token: a text that is not JSON", new AsIs("token"), SHAPE, false],
      ["a valid token handed over as an object, not as its text", new AsIs(good), NOTEXT, true],
      ["a valid token as JSON text with other spacing", new AsIs(JSON.stringify(good, null, 1)), NONCANON, true],
      ["a valid token as JSON text with the keys in another order", new AsIs(JSON.stringify({ signature: good.signature, body: good.body })), NONCANON, true],
      ["JSON text with the key `body` twice: an attacker's body first, the signed body last", new AsIs(`{"body":${canon(evil)},"body":${canon(body)},"signature":"${good.signature}"}`), NONCANON, true],
      ["JSON text with the key `body` twice: the signed body first, an attacker's body last", new AsIs(`{"body":${canon(body)},"body":${canon(evil)},"signature":"${good.signature}"}`), NONCANON, true],
      ["direct call with an intent and a post-state, no signature field", { body }, SHAPE, true],
      ["direct call with the intent only", { intent: body.intent }, SHAPE, false],
      ["empty signature", { body, signature: "" }, SHAPE, true],
      ["signature of 63 bytes", { body, signature: Buffer.alloc(63, 7).toString("base64") }, SHAPE, true],
      ["signature text that is not canonical base64 (same 64 bytes)", { body, signature: nonCanonical }, SHAPE, true],
      ["signature of 64 zero bytes", { body, signature: zeros }, SIG, true],
      ["forged: the body of a valid token, signed with the attacker's key", signWith(attacker.privateKey, body), SIG, true],
      ["forged: signed with a key made from the public key bytes", signWith(fromPublic, body), SIG, true],
      ["forged: an attacker's body (remaining 0, amount 900), signed with the attacker's key", signWith(attacker.privateKey, evil), SIG, true],
      ["forged: an attacker's body with the signature of the valid token", { body: evil, signature: good.signature }, SIG, true],
      ["forged: the valid body with the signature of an earlier committed token", { body, signature: earlier.signature }, SIG, true],
      ["a token of a second issuer process (same files, another key)", otherToken, SIG, true],
      ["tampered: post-state remaining 700 -> 0", { body: { ...body, post: { ...body.post, remaining: "0" } }, signature: good.signature }, SIG, true],
      ["tampered: intent amount 200 -> 900", { body: { ...body, intent: { ...body.intent, amount: "900" } }, signature: good.signature }, SIG, true],
      ["tampered: intent reason", { body: { ...body, intent: { ...body.intent, reason: "returned_item" } }, signature: good.signature }, SIG, true],
      ["tampered: intent charge id", { body: { ...body, intent: { ...body.intent, chargeId: "ch_other" } }, signature: good.signature }, SIG, true],
      ["tampered: request id", { body: { ...body, requestId: "rq_a_other" }, signature: good.signature }, SIG, true],
      ["tampered: pre-state hash", { body: { ...body, preStateSha256: "0".repeat(64) }, signature: good.signature }, SIG, true],
      ["tampered: domain text", { body: { ...body, domain: DOMAIN + "X" }, signature: good.signature }, SHAPE, true],
      ["tampered: another spec lock hash (the signature does not fit either)", { body: { ...body, specLockSha256: "1".repeat(64) }, signature: good.signature }, "spec lock is not the pinned one", true],
      ["tampered: another checker id (the signature does not fit either)", { body: { ...body, checkerSha256: "2".repeat(64) }, signature: good.signature }, "checker is not the pinned one", true],
      ["tampered: extra field in the body", { body: { ...body, note: "x" }, signature: good.signature }, SHAPE, true],
      ["tampered: extra field beside the body", { ...good, admin: "true" }, SHAPE, true],
      ["tampered: intent amount as a JSON number", { body: { ...body, intent: { ...body.intent, amount: 200 } }, signature: good.signature }, SHAPE, true],
      ["tampered: post-state remaining beyond 19 digits", { body: { ...body, post: { ...body.post, remaining: "9".repeat(20) } }, signature: good.signature }, SHAPE, true],
      ["a body whose request id holds U+0000, signed with the attacker's key", signWith(attacker.privateKey, nul), SHAPE, true],
    ];
    for (const [name, token, reason, needUnchecked] of cases) {
      attempt(w, "a", name, token, "rejected", reason, 0, needUnchecked);
    }
    {
      // A proxy over the valid token counts every operation on it. The sink must not touch it.
      let touched = 0;
      const count = <T>(value: T): T => { touched++; return value; };
      const hostile = new Proxy(good as object, {
        get: (target, key) => count(Reflect.get(target, key)), has: (target, key) => count(Reflect.has(target, key)),
        ownKeys: target => count(Reflect.ownKeys(target)), getPrototypeOf: target => count(Reflect.getPrototypeOf(target)),
        getOwnPropertyDescriptor: (target, key) => count(Reflect.getOwnPropertyDescriptor(target, key)),
      });
      const before = snap(w), s = w.sink(), result = s.commit(hostile); s.close(); w.flush();
      const effects = effectsBetween(before, snap(w));
      add("a", "hostile object: a proxy over a valid token that counts every operation on it", `rejected: ${NOTEXT}; 0 operations on the object; effects 0`,
        `${result.status}${result.reason ? ": " + result.reason : ""}; ${touched} operations on the object; effects ${effects}`,
        result.status === "rejected" && result.reason === NOTEXT && touched === 0 && effects === 0, effects, 1);
    }
    attempt(w, "a", "positive control: the untampered token of this group, as its canonical text", good, "committed", null, 4);
    auditRow(w, "a", "audit after the group");

    // A VALID signature of the trusted key, but another spec lock or another checker id in the body.
    const otherLock = join(outDir, "other-spec.lock"), otherCore = join(outDir, "other-core.cjs");
    writeFileSync(otherLock, Buffer.concat([readFileSync(SPEC_LOCK), Buffer.from("\n")]));
    writeFileSync(otherCore, Buffer.concat([readFileSync(CORE), Buffer.from("\n// another build of the same core\n")]));
    for (const [label, corePath, lockPath, reason] of [
      ["another spec lock", CORE, otherLock, "spec lock is not the pinned one"], ["another checker id", otherCore, SPEC_LOCK, "checker is not the pinned one"]] as const) {
      const issuer = await MinterClient.start(ROOT, corePath, lockPath, "off");
      const wOther = await world("a_" + label.replace(/ /g, "_"), issuer, []);
      const token = await mustMint(issuer, wOther.current(), req("a_ids", "100"));
      const differs = label === "another spec lock" ? token.body.specLockSha256 !== specLockSha256 && token.body.checkerSha256 === checkerSha256
        : token.body.checkerSha256 !== checkerSha256 && token.body.specLockSha256 === specLockSha256;
      if (!differs) throw new Error("setup: the second issuer has the pinned ids");
      attempt(wOther, "a", `a token with a VALID signature of the trusted key, issued with ${label}`, token, "rejected", reason, 0);
      issuer.stop();
    }

    const empty = join(outDir, "no_state"); mkdirSync(empty);
    const none = state("no_state"), token = await mustMint(minter, none, req("no_state", "100"));
    const s = new Sink(join(empty, "sink.sqlite"), { publicKeyPem: pem, specLockSha256, checkerSha256, initialState: none });
    const result = s.commit(tokenText(token)), rowsAfter = s.settled().length + s.outbox().length; s.close();
    add("a", "a valid token for a sink that has no stored state", "rejected; 0 rows written", `${result.status}${result.reason ? ": " + result.reason : ""}; ${rowsAfter} rows written`,
      result.status === "rejected" && rowsAfter === 0);
  }

  // ---------------- Control (b): stale pre-state hash -> 0 effects. ----------------
  {
    const w = await world("b");
    const s0 = w.current();
    const first = await mustMint(minter, s0, req("b_first", "100")), second = await mustMint(minter, s0, req("b_second", "200"));
    attempt(w, "b", "two tokens for one pre-state: the first commit", second, "committed", null, 4);
    attempt(w, "b", "the other token for the old pre-state (fresh request id)", first, "rejected", STALE, 0);
    const invented = { ...w.current(), remaining: "1000" };
    const forOld = await mustMint(minter, invented, req("b_invented", "900"));
    attempt(w, "b", "a token for a pre-state that the caller invented (remaining 1000; stored 700)", forOld, "rejected", STALE, 0);
    const third = await mustMint(minter, w.current(), req("b_third", "50"));
    attempt(w, "b", "a token for the current state", third, "committed", null, 4);
    attempt(w, "b", "the first token again after two more commits", first, "rejected", STALE, 0);
    auditRow(w, "b", "audit after the group");

    const race = await world("b_race");
    const start = race.current(), before = snap(race), N = 6;
    const tokens: Token[] = [];
    for (let i = 0; i < N; i++) tokens.push(await mustMint(minter, start, req(`b_race_${i}`, String(10 * (i + 1)))));
    tokens.forEach((t, i) => writeFileSync(join(race.dir, `token-${i}.txt`), tokenText(t)));
    const startAt = String(Date.now() + START_DELAY_MS);
    const results = answers(await Promise.all(tokens.map((_, i) => run([join(__dirname, "commit_cli.ts"), race.db, join(race.dir, "sink-config.json"), join(race.dir, `token-${i}.txt`), startAt]))));
    race.flush();
    const committed = results.filter(r => r.status === "committed").length, stale = results.filter(r => r.status === "rejected" && r.reason === STALE).length;
    const onTime = results.every(r => r.onTime === true);
    const effects = effectsBetween(before, snap(race)), winner = tokens.find(t => canon(t.body.post) === snap(race).state);
    add("b", `race: ${N} valid tokens for one pre-state, committed by ${N} processes that wait for one common start time`,
      `all processes ready in time; 1 committed; ${N - 1} rejected: ${STALE}; effects 4; the state is the post-state of the committed token`,
      `${onTime ? "all processes ready in time" : "A PROCESS WAS LATE"}; ${committed} committed; ${stale} rejected: ${STALE}; effects ${effects}; ${winner ? "the state is the post-state of the committed token" : "THE STATE IS NO TOKEN'S POST-STATE"}`,
      onTime && committed === 1 && stale === N - 1 && effects === 4 && !!winner, effects, N);
    auditRow(race, "b", "audit after the race");
  }

  // ---------------- Control (c): duplicate request id -> 0 effects. ----------------
  {
    const w = await world("c");
    const t1 = w.committed[0];
    attempt(w, "c", "replay of the committed token", t1, "replayed", null, 0);
    const t2 = await mustMint(minter, w.current(), req("c_2", "200"));
    attempt(w, "c", "a second valid transition", t2, "committed", null, 4);
    attempt(w, "c", "replay of the first token after another commit", t1, "replayed", null, 0);
    attempt(w, "c", "replay of the second token", t2, "replayed", null, 0);
    const reuse = await mustMint(minter, w.current(), { requestId: t1.body.requestId, amount: "300", reason: REASON });
    attempt(w, "c", "a new signed token for the CURRENT state that uses a settled request id again", reuse, "rejected", USED, 0);
    const zero = await mustMint(minter, w.current(), req("c_zero", "0"));
    const hashBefore = sha256hex(snap(w).state);
    attempt(w, "c", "a refund of amount 0 (the approved relation allows it): the state does not change", zero, "committed", null, 3);
    add("c", "after the amount-0 commit the stored state hash is the same as before", "same hash", sha256hex(snap(w).state) === hashBefore ? "same hash" : "DIFFERENT", sha256hex(snap(w).state) === hashBefore);
    attempt(w, "c", "replay of the amount-0 token: its pre-state hash still matches the store", zero, "replayed", null, 0);
    const zeroAgain = await mustMint(minter, w.current(), { requestId: zero.body.requestId, amount: "0", reason: "returned_item" });
    attempt(w, "c", "another signed amount-0 token with the same request id: the pre-state hash matches, the request id is not fresh", zeroAgain, "rejected", USED, 0);
    const again = w.flush();
    add("c", "a second dispatcher run on the same outbox", "0 new outbound effects", `${again.emitted.length} new outbound effects; ${again.alreadyDispatched} already dispatched`, again.emitted.length === 0 && again.alreadyDispatched === 3);
    auditRow(w, "c", "audit after the group");

    const race = await world("c_race");
    const before = snap(race), N = 6, token = await mustMint(minter, race.current(), req("c_race", "250"));
    writeFileSync(join(race.dir, "token.txt"), tokenText(token));
    const startAt = String(Date.now() + START_DELAY_MS);
    const results = answers(await Promise.all(Array.from({ length: N }, () => run([join(__dirname, "commit_cli.ts"), race.db, join(race.dir, "sink-config.json"), join(race.dir, "token.txt"), startAt]))));
    race.flush();
    const committed = results.filter(r => r.status === "committed").length, replayed = results.filter(r => r.status === "replayed").length;
    const onTime = results.every(r => r.onTime === true), effects = effectsBetween(before, snap(race));
    add("c", `race: one valid token committed by ${N} processes that wait for one common start time`, `all processes ready in time; 1 committed; ${N - 1} replayed; effects 4`,
      `${onTime ? "all processes ready in time" : "A PROCESS WAS LATE"}; ${committed} committed; ${replayed} replayed; effects ${effects}`, onTime && committed === 1 && replayed === N - 1 && effects === 4, effects, N);
    auditRow(race, "c", "audit after the race");
  }

  // ---------------- Control (d): valid transition -> exactly one effect. ----------------
  {
    const initial = state("d");
    const w = await world("d", minter, [], initial);
    const request = req("d_1", "100"), candidate = propose(initial, request), token = await mustMint(minter, initial, request);
    attempt(w, "d", "one valid transition", token, "committed", null, 4);
    const s = w.sink(); const out = s.outbox(), settled = s.settled(), blob = s.stateBlob(); s.close();
    const exact = blob === canon(candidate.post) && settled.length === 1 && out.length === 1 && out[0].request_id === request.requestId &&
      out[0].intent === canon(candidate.intent) && w.effects.length === 1 && w.effects[0].requestId === request.requestId && w.effects[0].intent === canon(candidate.intent);
    add("d", "the one effect is exactly the checked one: state = post-state, 1 settled row, 1 outbox row and 1 outbound effect with the checked intent",
      "exact", exact ? "exact" : "DIFFERENT", exact);
    const amounts = ["200", "0", "300", "400"];
    for (const [i, amount] of amounts.entries()) {
      const next = await mustMint(minter, w.current(), req(`d_${i + 2}`, amount));
      attempt(w, "d", `valid transition ${i + 2} of 5 (amount ${amount})`, next, "committed", null, amount === "0" ? 3 : 4);
    }
    const sum = w.effects.reduce((n, e) => n + BigInt(JSON.parse(e.intent).amount), 0n), end = w.current();
    const order = canon(w.effects.map(e => e.requestId)) === canon(["rq_d_1", "rq_d_2", "rq_d_3", "rq_d_4", "rq_d_5"]);
    add("d", "five valid transitions: five outbound effects in order; their sum is original minus remaining", "5 effects in order; sum 1000; remaining 0",
      `${w.effects.length} effects ${order ? "in order" : "OUT OF ORDER"}; sum ${sum}; remaining ${end.remaining}`, w.effects.length === 5 && order && sum === 1000n && end.remaining === "0");
    const last = req("d_6", "1");
    const none = await minter.mint(end, { request: last, post: end, intent: { chargeId: end.chargeId, requestId: last.requestId, amount: "1", reason: REASON } });
    add("d", "after remaining 0: a candidate for amount 1 that keeps remaining 0", "no token: the core refuses", none.ok ? "SIGNED" : "refused: " + none.reason, !none.ok && none.reason === "core: Refuse");
    auditRow(w, "d", "audit after the group");
  }

  // ---------------- Dispatcher: raw changes of the database file (outside the sink's interface), crash, overlap. ----------------
  {
    const judge = (w: World, name: string, expectIds: string[], expectNote: string) => {
      const before = w.effects.length;
      let stopped = "", refused: string[] = [];
      try { refused = w.flush().refused.map(r => r.reason); } catch (error) { stopped = String((error as Error).message); }
      const ids = w.effects.slice(before).map(e => e.requestId);
      const note = stopped ? "stopped: " + stopped : refused.length ? "refused: " + refused.join("; ") : "nothing refused";
      add("dispatcher", name, `new outbound effects [${expectIds.join(", ")}]; ${expectNote}`, `new outbound effects [${ids.join(", ")}]; ${note}`,
        canon(ids) === canon(expectIds) && note === expectNote, ids.length);
    };
    const insert = (db: DatabaseSync, requestId: string, token: Token) => {
      db.prepare("INSERT INTO settled(request_id, token, token_sha256) VALUES (?, ?, ?)").run(requestId, tokenText(token), sha256hex(tokenText(token)));
      db.prepare("INSERT INTO outbox(request_id, intent) VALUES (?, ?)").run(requestId, canon(token.body.intent));
    };
    { const w = await world("x1"); const db = w.raw();
      db.prepare("INSERT INTO outbox(request_id, intent) VALUES (?, ?)").run("rq_x1_ghost", canon({ chargeId: "ch_x1", requestId: "rq_x1_ghost", amount: "700", reason: REASON })); db.close();
      judge(w, "raw INSERT: an outbox row without a settled row", [], "refused: no settled row"); }
    { const w = await world("x2", minter, []); const token = await mustMint(minter, w.current(), req("x2_1", "100"));
      const s = w.sink(); s.commit(tokenText(token)); s.close(); const db = w.raw();
      db.prepare(`UPDATE outbox SET intent = replace(intent, '"amount":"100"', '"amount":"900"') WHERE request_id = ?`).run("rq_x2_1"); db.close();
      judge(w, "raw UPDATE before dispatch: outbox amount 100 changed to 900 (availability is lost, no wrong effect)", [], "refused: outbox intent is not the signed intent"); }
    { const w = await world("x3"); const pre = w.current(), db = w.raw();
      const evil = signWith(attacker.privateKey, expectedBody(pre, propose(pre, req("x3_evil", "900"))));
      insert(db, evil.body.requestId, evil);
      db.prepare("UPDATE state SET blob = ? WHERE id = 1").run(canon(evil.body.post)); db.close();
      judge(w, "raw INSERT and UPDATE: a consistent token for the current state, signed with the attacker's key", [], "refused: signature does not verify");
      const s = w.sink(); const problems = s.audit(); s.close();
      add("dispatcher", "the public-key audit of that changed database", "problems found: more than 0", `problems found: ${problems.length}`, problems.length > 0); }
    { const w = await world("x4"); const db = w.raw();
      const out = db.prepare("SELECT request_id, intent FROM outbox ORDER BY seq").all() as { request_id: string; intent: string }[];
      db.exec("DELETE FROM outbox"); out.forEach(o => db.prepare("INSERT INTO outbox(request_id, intent) VALUES (?, ?)").run(o.request_id, o.intent)); db.close();
      judge(w, "replay after dispatch: outbox rows deleted and inserted again as new rows (nothing is sent twice)", [], "nothing refused"); }
    { const w = await world("x5", minter, []);
      for (const n of ["1", "2"]) { const token = await mustMint(minter, w.current(), req(`x5_${n}`, "100")); const s = w.sink(); s.commit(tokenText(token)); s.close(); }
      let first = true, crashed = "";
      try { w.flush(e => { if (first) { first = false; throw new Error("simulated crash before the effect left"); } w.effects.push(e); }); } catch (error) { crashed = String((error as Error).message); }
      judge(w, `crash between the ledger line and the effect (${crashed}), then a new run: the first effect is lost and never sent twice`, ["rq_x5_2"], "nothing refused"); }
    { // Check 4 (chain): a token with a valid signature for the OLD state, written into the database beside the sink.
      const w = await world("x6"); const stale = await mustMint(minter, w.initial, req("x6_stale", "900")), db = w.raw();
      insert(db, stale.body.requestId, stale); db.close();
      judge(w, "raw INSERT: a validly signed token for an earlier state", [], "refused: token does not continue the dispatched chain"); }
    { // Check 3 (request id): a committed, validly signed token copied under a new request id.
      const w = await world("x7"); const db = w.raw();
      insert(db, "rq_x7_copy", w.committed[0]); db.close();
      judge(w, "raw INSERT: a copy of a committed token under a new request id", [], "refused: request id is not the signed one"); }
    { const w = await world("x8", minter, []); const token = await mustMint(minter, w.current(), req("x8_1", "100"));
      const s = w.sink(); s.commit(tokenText(token)); s.close();
      appendFileSync(join(w.dir, "dispatch-ledger.jsonl"), JSON.stringify({ requestId: "x", tokenSha256: "0", preStateSha256: "not-the-head", postStateSha256: "0", intentSha256: "0" }) + "\n");
      judge(w, "the dispatcher's own ledger is not one chain: fail closed", [], "stopped: dispatcher ledger is not one chain"); }
    { // Review finding F2: runs that overlap. Four processes start one run each at a common start time.
      const w = await world("x9", minter, []), N = 4;
      for (const n of ["1", "2", "3", "4"]) { const token = await mustMint(minter, w.current(), req(`x9_${n}`, "100")); const s = w.sink(); s.commit(tokenText(token)); s.close(); }
      const cfg = join(w.dir, "dispatcher-config.json"), effectsFile = join(w.dir, "effects.jsonl"), ledger = join(w.dir, "dispatch-ledger.jsonl");
      writeFileSync(cfg, JSON.stringify(w.dispCfg)); writeFileSync(effectsFile, "");
      const startAt = String(Date.now() + START_DELAY_MS);
      const results = answers(await Promise.all(Array.from({ length: N }, () => run([join(__dirname, "dispatch_cli.ts"), w.db, ledger, cfg, effectsFile, startAt]))));
      const sent = readFileSync(effectsFile, "utf8").split("\n").filter(l => l.length > 0).map(l => (JSON.parse(l) as Effect).requestId).sort();
      const ran = results.filter(r => r.emitted === 4).length, stopped = results.filter(r => typeof r.stopped === "string" && r.stopped.startsWith("dispatcher lock is held")).length;
      const onTime = results.every(r => r.onTime === true);
      let later = -1;
      try { later = w.flush().emitted.length; } catch { /* a broken ledger: the row fails with -1 */ }
      add("dispatcher", `overlap: ${N} dispatcher processes start at one common time on 4 pending refunds`,
        `all processes ready in time; 1 run sent 4; ${N - 1} runs stopped at the lock; each refund sent once; a later run sends 0`,
        `${onTime ? "all processes ready in time" : "A PROCESS WAS LATE"}; ${ran} run sent 4; ${stopped} runs stopped at the lock; ${canon(sent) === canon(["rq_x9_1", "rq_x9_2", "rq_x9_3", "rq_x9_4"]) ? "each refund sent once" : "SENT: " + sent.join(", ")}; a later run sends ${later}`,
        onTime && ran === 1 && stopped === N - 1 && canon(sent) === canon(["rq_x9_1", "rq_x9_2", "rq_x9_3", "rq_x9_4"]) && later === 0, sent.length); }
  }

  { // Finding of the repair check: one ledger file under two names had two locks. Six runs at a common start time:
    // two name the ledger file, two name a symbolic link to it (the ledger does not exist yet), two reach it
    // through a symbolic link to its folder.
    const w = await world("x10", minter, []), N = 6;
    for (const n of ["1", "2", "3", "4"]) { const token = await mustMint(minter, w.current(), req(`x10_${n}`, "100")); const s = w.sink(); s.commit(tokenText(token)); s.close(); }
    const cfg = join(w.dir, "dispatcher-config.json"), effectsFile = join(w.dir, "effects.jsonl"), ledger = join(w.dir, "dispatch-ledger.jsonl");
    writeFileSync(cfg, JSON.stringify(w.dispCfg)); writeFileSync(effectsFile, "");
    const fileLink = join(w.dir, "ledger-link.jsonl"), folderLink = join(outDir, "x10-folder-link");
    symlinkSync(ledger, fileLink); symlinkSync(w.dir, folderLink);
    const names = [ledger, ledger, fileLink, fileLink, join(folderLink, "dispatch-ledger.jsonl"), join(folderLink, "dispatch-ledger.jsonl")];
    const startAt = String(Date.now() + START_DELAY_MS);
    const results = answers(await Promise.all(names.map(name => run([join(__dirname, "dispatch_cli.ts"), w.db, name, cfg, effectsFile, startAt]))));
    const sent = readFileSync(effectsFile, "utf8").split("\n").filter(l => l.length > 0).map(l => (JSON.parse(l) as Effect).requestId).sort();
    const want = ["rq_x10_1", "rq_x10_2", "rq_x10_3", "rq_x10_4"];
    const ran = results.filter(r => r.emitted === 4).length, stopped = results.filter(r => typeof r.stopped === "string" && r.stopped.startsWith("dispatcher lock is held")).length;
    const onTime = results.every(r => r.onTime === true);
    let later = -1;
    try { later = w.flush().emitted.length; } catch { /* a broken ledger: the row fails with -1 */ }
    add("dispatcher", `overlap through three names of one ledger file: ${N} dispatcher processes start at one common time on 4 pending refunds`,
      `all processes ready in time; 1 run sent 4; ${N - 1} runs stopped at the lock; each refund sent once; a later run sends 0`,
      `${onTime ? "all processes ready in time" : "A PROCESS WAS LATE"}; ${ran} run sent 4; ${stopped} runs stopped at the lock; ${canon(sent) === canon(want) ? "each refund sent once" : "SENT: " + sent.join(", ")}; a later run sends ${later}`,
      onTime && ran === 1 && stopped === N - 1 && canon(sent) === canon(want) && later === 0, sent.length);
  }

  // ---------------- Option: the issuer rule "one signed transition per pre-state". ----------------
  {
    const strict = await MinterClient.start(ROOT, CORE, SPEC_LOCK, "on");
    const pre = state("opt"), a = await strict.mint(pre, propose(pre, req("opt_a", "100"))), again = await strict.mint(pre, propose(pre, req("opt_a", "100")));
    const b = await strict.mint(pre, propose(pre, req("opt_b", "200")));
    add("option", "single-use on: the same transition again for one pre-state", "the same token", a.ok && again.ok && canon(a.token) === canon(again.token) ? "the same token" : "DIFFERENT OR REFUSED",
      !!a.ok && !!again.ok && canon(a.token) === canon(again.token));
    add("option", "single-use on: another transition for a pre-state that has a signed token", "no token", b.ok ? "SIGNED" : "refused: " + b.reason, strict.ready.singleUse === true && !b.ok);
    strict.stop();
  }

  minter.stop();
  const failed = rows.filter(r => !r.pass);
  const of = (control: string) => rows.filter(r => r.control === control);
  const rejections = rows.filter(r => ["a", "b", "c"].includes(r.control) && r.expected.includes("effects 0"));
  const report = {
    suite: "refund finality, slice 1", kind: "FINITE TEST", method: "unit_tested", end_to_end: false,
    counts: {
      rows: rows.length, failed: failed.length,
      control_a_rows: of("a").length, control_b_rows: of("b").length, control_c_rows: of("c").length, control_d_rows: of("d").length,
      issuer_rows: of("issuer").length, dispatcher_rows: of("dispatcher").length,
      rejection_attempts: rejections.length, effects_of_rejection_attempts: rejections.reduce((n, r) => n + r.effects, 0),
      rejection_attempts_that_ask_for_an_effect: rejections.filter(r => (r.uncheckedSinkEffects ?? 0) > 0).length,
    },
    ids: { core_module_sha256: sha256hex(readFileSync(CORE)), spec_lock_sha256: specLockSha256, checker_sha256: checkerSha256 },
    rows,
  };
  writeFileSync(join(outDir, "report.json"), JSON.stringify(report, null, 1) + "\n");
  for (const r of rows) console.log(`${r.pass ? "PASS" : "FAIL"} | ${r.control} | ${r.name} | ${r.observed}`);
  console.log(JSON.stringify(report.counts));
  process.exit(failed.length === 0 ? 0 : 1);
}
main().catch(error => { console.error(error); process.exit(2); });

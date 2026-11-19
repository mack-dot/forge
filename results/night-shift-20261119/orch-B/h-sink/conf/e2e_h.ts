// p-adopt2 (copy of p-adopt/conf/e2e.ts; v6: cfg.initialState = s0 is REQUIRED): end-to-end check in the scratch export. New minter -> new sink -> patched dispatcher.
// Usage (cwd = export): node --import tsx e2e.ts <export root> <issuer module .cjs> <work dir>
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
const [root, corePath, work] = process.argv.slice(2);
// eslint-disable-next-line @typescript-eslint/no-require-imports
const E = require(join(root, "ts/refund-finality/encoding.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { Sink } = require(join(root, "ts/refund-finality/sink.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { Dispatcher } = require(join(root, "ts/refund-finality/dispatcher.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { MinterClient, propose } = require(join(root, "ts/refund-finality/proposer.ts"));
(async () => {
  rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
  const m = await MinterClient.start(root, corePath, join(root, "spec/refund/spec.lock"), "off");
  const ids = { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 };
  const db = join(work, "sink.sqlite"), s0 = { chargeId: "ch_e2e", original: "1000", remaining: "1000", refundEnabled: true };
  const cfg = { ...ids, initialState: s0 };
  const r: Record<string, unknown> = {};
  let sink = new Sink(db, cfg); sink.init(s0);
  const mint = async (pre: any, rid: string, amount: string) => {
    const a = await m.mint(pre, propose(pre, { requestId: rid, amount, reason: "duplicate_charge" }));
    if (!a.ok) throw new Error("mint refused: " + a.reason); return E.tokenText(a.token);
  };
  const t1 = await mint(s0, "rq_e2e_1", "100");
  r.c1 = sink.commit(t1); r.c1again = sink.commit(t1);
  const s1 = JSON.parse(sink.stateBlob());
  const t0 = await mint(s1, "rq_e2e_zero", "0");
  r.c0 = sink.commit(t0); r.c0again = sink.commit(t0);
  r.stateAfterZeroUnchanged = sink.stateBlob() === E.canon(s1);
  r.audit = sink.audit(); sink.close();
  sink = new Sink(db, cfg); r.restartOk = true; sink.close();       // the start-up audit passes on an honest store
  const effects: unknown[] = [];
  const dcfg = { ...ids, initialStateSha256: E.stateSha256(s0), newLedgerH0: require(join(root, "ts/refund-finality/sink.ts")).genesisOf(E.canon(s0), ids.specLockSha256, ids.checkerSha256, ids.publicKeyPem) };   // h-sink: explicit new ledger
  const d1 = new Dispatcher(db, join(work, "ledger.jsonl"), dcfg, (e: unknown) => effects.push(e)).flush();
  const d2 = new Dispatcher(db, join(work, "ledger.jsonl"), dcfg, (e: unknown) => effects.push(e)).flush();
  r.flush1 = { emitted: d1.emitted.length, refused: d1.refused }; r.flush2 = { emitted: d2.emitted.length, already: d2.alreadyDispatched };
  r.effects = effects;
  m.stop?.();
  const ok = (r.c1 as any).status === "committed" && (r.c1again as any).status === "replayed" && (r.c0 as any).status === "committed" &&
    (r.c0again as any).status === "replayed" && r.stateAfterZeroUnchanged === true && (r.audit as string[]).length === 0 &&
    d1.emitted.length === 2 && d1.refused.length === 0 && d2.emitted.length === 0;
  writeFileSync(join(work, "result.json"), JSON.stringify({ ok, ...r }, null, 1));
  process.stdout.write(JSON.stringify({ ok, c1: r.c1, c1again: r.c1again, c0: r.c0, c0again: r.c0again, flush1: r.flush1, flush2: r.flush2 }) + "\n");
  process.exit(ok ? 0 : 1);
})().catch(e => { process.stderr.write(String(e && e.stack) + "\n"); process.exit(3); });

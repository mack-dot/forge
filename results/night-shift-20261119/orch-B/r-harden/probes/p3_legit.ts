// r-harden probe P3: the legitimate side of the hardened sink (branch 608b5165). Standalone, one short run, test keys only.
// usage (cwd = tree): node --import tsx p3_legit.ts <treeRoot> <scratch dir> [N commits, default 1000]
// Exit 1 if a legitimate transaction is refused or a safety row fails; exit 0 otherwise; exit 3 harness broke.
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdirSync, rmSync } from "node:fs";
import { join, resolve } from "node:path";
const [TREE0, OUT0, N0] = process.argv.slice(2);
const TREE = resolve(TREE0), OUT = resolve(OUT0), N = Number(N0 ?? "1000");
rmSync(OUT, { recursive: true, force: true }); mkdirSync(OUT, { recursive: true });
/* eslint-disable @typescript-eslint/no-require-imports */
const E = require(join(TREE, "ts/refund-finality/encoding.ts"));
const HM = require(join(TREE, "ts/refund-finality/sink.ts"));
const { Dispatcher } = require(join(TREE, "ts/refund-finality/dispatcher.ts"));
/* eslint-enable @typescript-eslint/no-require-imports */
const { canon, signedBytes, stateSha256, DOMAIN } = E;
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
const pem = publicKey.export({ type: "spki", format: "pem" }) as string;
const st = (remaining: string, original = "1000") => ({ chargeId: "ch_1", original, remaining, refundEnabled: true });
const mk = (S0: any) => ({ publicKeyPem: pem, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), initialState: S0 });
const tok = (pre: any, rid: string, amount: string) => {
  const body = { domain: DOMAIN, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), preStateSha256: stateSha256(pre), requestId: rid,
    post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() }, intent: { chargeId: "ch_1", requestId: rid, amount, reason: "duplicate_charge" } };
  return canon({ body, signature: sign(null, signedBytes(body), privateKey).toString("base64") });
};
let bad = 0; const out: any[] = [];
const check = (name: string, got: string, want: string) => { const ok = got === want; if (!ok) bad++; out.push({ name, got, want, ok }); };
// L1 legitimate sequence on one charge
{
  const S0 = st("1000"), cfg = mk(S0), p = join(OUT, "l1.sqlite");
  const s = new HM.Sink(p, cfg); s.init(S0);
  check("zero-amount first", s.commit(tok(S0, "z_a", "0")).status, "committed");
  check("second zero-amount, other id, same pre", s.commit(tok(S0, "z_b", "0")).status, "committed");
  check("replay of z_a (same token)", s.commit(tok(S0, "z_a", "0")).status, "replayed");
  check("refund > remaining", s.commit(tok(S0, "big", "1001")).status, "rejected");
  check("refund equal to remaining (1000)", s.commit(tok(S0, "all", "1000")).status, "committed");
  check("zero-amount on remaining 0", s.commit(tok(st("0"), "z_c", "0")).status, "committed");
  check("1 on remaining 0", s.commit(tok(st("0"), "one", "1")).status, "rejected");
  check("stored state", s.stateBlob(), canon(st("0")));
  check("audit", JSON.stringify(s.audit()), "[]");
  s.close();
  const s2 = new HM.Sink(p, cfg); check("restart head count", String(s2.head().count), "4"); s2.close();
  const eff: string[] = [];
  const r = new Dispatcher(p, join(OUT, "l1.ledger"), { ...cfg, initialStateSha256: stateSha256(S0), newLedgerH0: HM.genesisOf(canon(S0), cfg.specLockSha256, cfg.checkerSha256, pem) }, (e: any) => eff.push(e.requestId)).flush();
  check("dispatcher effects", eff.join(","), "z_a,z_b,all,z_c");
  check("dispatcher second flush emits none", String(new Dispatcher(p, join(OUT, "l1.ledger"), { ...cfg, initialStateSha256: stateSha256(S0) }, () => undefined).flush().emitted.length), "0");
}
// L2 two Sink instances on ONE file, interleaved deterministically in one process (not a race run)
{
  const S0 = st("1000"), cfg = mk(S0), p = join(OUT, "l2.sqlite");
  const a = new HM.Sink(p, cfg); a.init(S0); const b = new HM.Sink(p, cfg);
  const t1 = tok(S0, "rq_1", "100");
  check("A commits rq_1", a.commit(t1).status, "committed");
  check("B gets rq_1 (same token)", b.commit(t1).status, "replayed");
  const t2 = tok(st("900"), "rq_2", "50"), t2b = tok(st("900"), "rq_2", "60");
  check("B commits rq_2", b.commit(t2).status, "committed");
  check("A: rq_2 other token", a.commit(t2b).status, "rejected");
  check("A: rq_2 same token", a.commit(t2).status, "replayed");
  check("A commits rq_3", a.commit(tok(st("850"), "rq_3", "0")).status, "committed");
  check("B commits rq_4", b.commit(tok(st("850"), "rq_4", "5")).status, "committed");
  check("A sees B's state", a.stateBlob(), canon(st("845")));
  check("A audit", JSON.stringify(a.audit()), "[]");
  a.close(); b.close();
}
// L3 N commits: time
{
  const S0 = st(String(N), String(N)), cfg = mk(S0), p = join(OUT, "l3.sqlite");
  const toks: string[] = []; let rem = N;
  for (let i = 0; i < N; i++) { const amt = i % 3 === 0 ? "0" : "1"; toks.push(tok(st(String(rem), String(N)), "rq_" + i, amt)); rem -= Number(amt); }
  const s = new HM.Sink(p, cfg); s.init(S0);
  const t0 = process.hrtime.bigint(); let okc = 0;
  for (const t of toks) if (s.commit(t).status === "committed") okc++;
  const ms = Number(process.hrtime.bigint() - t0) / 1e6; s.close();
  check(`${N} commits all committed`, String(okc), String(N));
  const t1 = process.hrtime.bigint(); const s2 = new HM.Sink(p, cfg); const c = s2.head().count; s2.close();
  const ms2 = Number(process.hrtime.bigint() - t1) / 1e6;
  check("restart audit count", String(c), String(N));
  out.push({ name: "timing", commitsMs: Math.round(ms), perCommitMs: +(ms / N).toFixed(2), restartAuditMs: Math.round(ms2) });
}
for (const r of out) console.log(JSON.stringify(r));
rmSync(OUT, { recursive: true, force: true });
console.log(bad ? "FAIL" : "PASS"); process.exit(bad ? 1 : 0);

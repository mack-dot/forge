// Regression for red team C-ATT-05 under OWNER DECISION D-1 (d), task h-key: a minter RESTART with the same key file
// yields tokens that the SAME sink accepts; the sink's pin never changes.
// Minter #1 (key file K, mode 0600) -> the sink is pinned ONCE from its ready line (the config text is kept and hashed).
// rq_1 (100) committed. Minter #1 stops (killed). Minter #2 starts with the same key file: the same publicKeyPem and
// keyId. rq_2 (0, a zero-amount refund) from minter #2 -> committed by the SAME sink object. The sink is then closed and
// reopened from the SAME config text: rq_3 (50) from minter #2 -> committed. The config text hash is unchanged.
// SAFE = exit 0. FAILS on f67c5c16 (C-ATT-05: a new key per process; the sink pinned to the old key rejects rq_2).
import { createHash } from "node:crypto";
import { join } from "node:path";
import { argv, guard, makeKeyFile, sinkKit, startMinter, verdict } from "./kf_lib";

guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_kfr", original: "1000", remaining: "1000", refundEnabled: true };
  const K = sinkKit(root, S0), key = makeKeyFile();
  const m1 = await startMinter(root, core, [key.path]);
  if (m1.ready === null) { m1.stop(); verdict(false, { minter1: "did not start", stderr: m1.stderr.slice(-200) }); }
  const cfgText = JSON.stringify({ publicKeyPem: m1.ready.publicKeyPem, specLockSha256: m1.ready.specLockSha256, checkerSha256: m1.ready.checkerSha256, initialState: S0 });
  const cfgSha = createHash("sha256").update(cfgText).digest("hex");
  const db = join(K.dir(), "s.sqlite");
  let s = new K.SK.Sink(db, JSON.parse(cfgText)); s.init(S0);
  const text = (a: any) => a.ok ? K.E.tokenText(a.token) : "MINT REFUSED: " + a.reason;
  const c = (t: string) => t.startsWith("MINT") ? t : s.commit(t).status;
  const r: any = {};
  r.rq1 = c(text(await m1.mint(S0, "rq_1", "100")));
  m1.stop();
  await new Promise(res => setTimeout(res, 300));
  const m2 = await startMinter(root, core, [key.path]);
  r.minter2 = { ready: m2.ready !== null, samePublicKey: m2.ready?.publicKeyPem === m1.ready.publicKeyPem, sameKeyId: m2.ready?.keyId !== undefined && m2.ready?.keyId === m1.ready.keyId };
  const s1 = JSON.parse(s.stateBlob());
  r.rq2 = m2.ready === null ? "MINTER 2 DID NOT START" : c(text(await m2.mint(s1, "rq_2", "0")));
  s.close();
  s = new K.SK.Sink(db, JSON.parse(cfgText));
  const s2 = JSON.parse(s.stateBlob());
  r.rq3AfterSinkReopen = m2.ready === null ? "MINTER 2 DID NOT START" : c(text(await m2.mint(s2, "rq_3", "50")));
  r.rows = K.rows(db); s.close(); m2.stop();
  r.pinUnchanged = createHash("sha256").update(cfgText).digest("hex") === cfgSha;
  verdict(r.rq1 === "committed" && r.minter2.ready && r.minter2.samePublicKey && r.minter2.sameKeyId && r.rq2 === "committed" &&
    r.rq3AfterSinkReopen === "committed" && r.rows.join() === "rq_1,rq_2,rq_3" && r.pinUnchanged, r);
})());

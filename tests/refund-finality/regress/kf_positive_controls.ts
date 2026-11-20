// POSITIVE CONTROLS for OWNER DECISION D-1, task h-key: legitimate refunds still commit with the key-file minter and the
// key-id allowlist. Real minter process (memory rule "on", key FILE mode 0600), real sink, real dispatcher.
// Charge: original = remaining = 9223372036854775807 (MaxMoney). Sink pin: issuerKeys [the file's key, active], key id
// computed by the test (kf_lib testKeyIdOf), and it must equal the ready line's keyId.
// z1 amount 0 -> committed; z2 amount 0 -> committed (two zero-amount refunds); the z2 token again -> replayed;
// the LARGEST refund (amount = remaining = MaxMoney) -> committed; the dispatcher sends z1, z2, max once each.
// A second store pinned the OLD way ({publicKeyPem} only): a zero-amount token of the same minter commits there too.
// PASS = exit 0. On f67c5c16: the minter does not take a key file -> FAIL.
import { join } from "node:path";
import { active, argv, guard, makeKeyFile, sinkKit, startMinter, verdict } from "./kf_lib";

guard((async () => {
  const { root, core } = argv();
  const MAX = "9223372036854775807";
  const S0 = { chargeId: "ch_kfp", original: MAX, remaining: MAX, refundEnabled: true };
  const K = sinkKit(root, S0), key = makeKeyFile();
  const m = await startMinter(root, core, [key.path]);
  const r: any = { ready: m.ready !== null, keyIdMatches: m.ready?.keyId === key.keyId };
  if (m.ready === null) { m.stop(); verdict(false, { ...r, stderr: m.stderr.slice(-200) }); }
  const ids = { specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 };
  const pin = { issuerKeys: [active(key)] };
  const mk = (db: string, p: any): any => new K.SK.Sink(db, { ...p, ...ids, initialState: S0 });
  const db = join(K.dir(), "s.sqlite"), s = mk(db, pin); s.init(S0);
  const text = (a: any) => a.ok ? K.E.tokenText(a.token) : "MINT REFUSED: " + a.reason;
  const c = (t: string) => t.startsWith("MINT") ? t : s.commit(t).status;
  const z1 = text(await m.mint(S0, "rq_z1", "0")); r.z1 = c(z1);
  const z2 = text(await m.mint(S0, "rq_z2", "0")); r.z2 = c(z2);
  r.z2Again = c(z2);
  const big = text(await m.mint(S0, "rq_max", MAX)); r.largest = c(big);
  r.state = JSON.parse(s.stateBlob()).remaining;
  s.close();
  const effects: string[] = [];
  const dcfg = { ...pin, ...ids, initialStateSha256: K.E.stateSha256(S0), newLedgerH0: K.SK.genesisOf(K.E.canon(S0), ids.specLockSha256, ids.checkerSha256, key.publicKeyPem) };
  const f = new K.D.Dispatcher(db, join(K.dir(), "l.jsonl"), dcfg, (e: any) => effects.push(e.requestId)).flush();
  r.dispatched = effects; r.refused = f.refused.length;
  const db2 = join(K.dir(), "legacy.sqlite"), s2 = mk(db2, { publicKeyPem: m.ready.publicKeyPem }); s2.init(S0);
  r.legacyPinZero = s2.commit(text(await m.mint(S0, "rq_legacy_zero", "0"))).status; s2.close();
  m.stop();
  verdict(r.keyIdMatches && r.z1 === "committed" && r.z2 === "committed" && r.z2Again === "replayed" && r.largest === "committed" && r.state === "0" &&
    effects.join() === "rq_z1,rq_z2,rq_max" && r.refused === 0 && r.legacyPinZero === "committed", r);
})());
